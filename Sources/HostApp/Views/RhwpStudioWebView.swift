import AppKit
import SwiftUI
import WebKit

struct RhwpStudioDroppedDocument {
    let data: Data
    let fileName: String
}

struct RhwpStudioSavedDocument {
    let url: URL
    let data: Data
    let sourceProtection: DocumentSourceProtection
    let session: RhwpStudioEditorSession
}

enum RhwpStudioDocumentSaveResult {
    case saved(URL)
    case cancelled
    case failed(String)
}

struct RhwpStudioWebView: NSViewRepresentable {
    let document: RhwpStudioDocumentPayload?
    let sourceDocument: RecentDocumentItem?
    let reloadToken: Int
    let loadID: Int
    let onEditorSessionChange: (RhwpStudioEditorSession) -> Void
    let onLoadStateChange: (Bool) -> Void
    let onError: (String?) -> Void
    let onFailure: (RhwpStudioWebViewFailure) -> Void
    let onOpenDocument: () -> Void
    let onDroppedDocument: (RhwpStudioDroppedDocument) -> Void
    let onDroppedFileURL: (URL) -> Void
    let onDocumentSaved: (RhwpStudioSavedDocument) -> Void

    init(
        document: RhwpStudioDocumentPayload?,
        sourceDocument: RecentDocumentItem? = nil,
        reloadToken: Int = 0,
        loadID: Int,
        onEditorSessionChange: @escaping (RhwpStudioEditorSession) -> Void = { _ in },
        onLoadStateChange: @escaping (Bool) -> Void = { _ in },
        onError: @escaping (String?) -> Void = { _ in },
        onFailure: @escaping (RhwpStudioWebViewFailure) -> Void = { _ in },
        onOpenDocument: @escaping () -> Void = {},
        onDroppedDocument: @escaping (RhwpStudioDroppedDocument) -> Void = { _ in },
        onDroppedFileURL: @escaping (URL) -> Void = { _ in },
        onDocumentSaved: @escaping (RhwpStudioSavedDocument) -> Void = { _ in }
    ) {
        self.document = document
        self.sourceDocument = sourceDocument
        self.reloadToken = reloadToken
        self.loadID = loadID
        self.onEditorSessionChange = onEditorSessionChange
        self.onLoadStateChange = onLoadStateChange
        self.onError = onError
        self.onFailure = onFailure
        self.onOpenDocument = onOpenDocument
        self.onDroppedDocument = onDroppedDocument
        self.onDroppedFileURL = onDroppedFileURL
        self.onDocumentSaved = onDocumentSaved
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        context.coordinator.makeWebView()
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onLoadStateChange = onLoadStateChange
        context.coordinator.onError = onError
        context.coordinator.onFailure = onFailure
        context.coordinator.onOpenDocument = onOpenDocument
        context.coordinator.onDroppedDocument = onDroppedDocument
        context.coordinator.onDroppedFileURL = onDroppedFileURL
        context.coordinator.onDocumentSaved = onDocumentSaved
        context.coordinator.onEditorSessionChange = onEditorSessionChange
        context.coordinator.update(
            document: document,
            sourceDocument: sourceDocument,
            reloadToken: reloadToken,
            loadID: loadID,
            in: webView
        )
    }
}

extension RhwpStudioWebView {
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var onLoadStateChange: (Bool) -> Void = { _ in }
        var onError: (String?) -> Void = { _ in }
        var onFailure: (RhwpStudioWebViewFailure) -> Void = { _ in }
        var onOpenDocument: () -> Void = {}
        var onDroppedDocument: (RhwpStudioDroppedDocument) -> Void = { _ in }
        var onDroppedFileURL: (URL) -> Void = { _ in }
        var onDocumentSaved: (RhwpStudioSavedDocument) -> Void = { _ in }

        private static let loadTimeoutNanoseconds: UInt64 = 15_000_000_000
        private static let nativeDropSuppressionInterval: TimeInterval = 2
        private static let recoverableRuntimeMessages = [
            "지정된 컨트롤이 표, 글상자 또는 그림이 아닙니다",
            "컨트롤 인덱스 0 범위 초과"
        ]
        private static let recoverableRuntimeAssetPathPrefix = "/assets/index-"
        private static let recoverableRuntimeAssetLine = 1

        private enum SaveDestination {
            case source(RecentDocumentItem)
            case selected(URL)
        }

        private struct PendingSaveRequest {
            let id: String
            let token: String
            let loadID: Int
            let documentEpoch: Int
            let destination: SaveDestination
            let format: DocumentSaveFormat
            let documentRevision: Int
            let sourceProtection: DocumentSourceProtection
            let sourceFormat: DocumentSourceFormatIdentity
            let outputProtectionIntent: DocumentSaveOutputProtectionIntent
            let conversionIntent: DocumentSaveConversionIntent
            let sourceURL: URL?

            var destinationURL: URL {
                switch destination {
                case .source(let sourceDocument):
                    return sourceDocument.url
                case .selected(let url):
                    return url
                }
            }
        }

        private struct SavePayload {
            let data: Data
            let fileName: String
            let format: DocumentSaveFormat
        }

        private struct NativeDropMarker {
            let fileName: String
            let handledAt: Date
        }

        private let documentProvider = RhwpStudioDocumentProvider()
        private let resourceSchemeHandler = RhwpStudioResourceSchemeHandler()
        private lazy var documentSchemeHandler = RhwpStudioDocumentSchemeHandler(
            documentProvider: documentProvider
        )
        private var loadedIdentity: Int?
        private var editorLoadToken = UUID().uuidString
        private var editorSession: RhwpStudioEditorSession?
        var onEditorSessionChange: (RhwpStudioEditorSession) -> Void = { _ in }
        private var currentDocument: RhwpStudioDocumentPayload?
        private var currentSourceDocument: RecentDocumentItem?
        private weak var commandWebView: WKWebView?
        private let printLifecycle = RhwpStudioPrintLifecycle(
            controllerFactory: { RhwpStudioPrintController() }
        )
        private var pdfExportController: RhwpStudioPDFExportController?
        private var pendingSaveRequest: PendingSaveRequest?
        private var activeSaveID: String?
        private var activeSaveEpoch: Int?
        var chooseSaveDestination: (DocumentSaveFormat, String, NSWindow?) async -> URL? = {
            await DocumentSavePanel.chooseDestinationURL(format:$0, suggestedFilename:$1, presentingWindow:$2)
        }
        var confirmSaveTransformation: (DocumentSourceProtection, DocumentSaveConversionIntent, NSWindow?) async -> Bool = {
            await DocumentProtectionSaveAlert.confirmSaveTransformation(sourceProtection:$0, conversionIntent:$1, presentingWindow:$2)
        }
        var writeSaveData: (Data, URL, Bool) throws -> Void = {
            try DocumentSavePanel.write(data:$0, to:$1, allowOverwrite:$2)
        }
        private var pdfExportState: RhwpStudioPDFExportState = .idle
        private var nextPDFExportRequestID = 0
        private var isPDFPreparing = false
        var choosePDFDestination: (String, NSWindow?) async -> URL? = {
            await DocumentPDFExportPanel.chooseDestinationURL(suggestedFilename:$0, presentingWindow:$1)
        }
        var onPDFExported: (URL) -> Void = { DocumentFileActions.revealInFinder($0) }
        private var activeLoadID = 0
        private var loadTimeoutTask: Task<Void, Never>?
        private var recentNativeDrop: NativeDropMarker?
        private var currentReloadToken = 0
        private var hasCompletedCurrentLoad = false

        deinit {
            loadTimeoutTask?.cancel()
        }

        func makeWebView() -> WKWebView {
            let configuration = WKWebViewConfiguration()
            configuration.userContentController.add(
                self,
                name: RhwpStudioHostBridgeScript.messageHandlerName
            )
            configuration.setURLSchemeHandler(
                documentSchemeHandler,
                forURLScheme: RhwpStudioDocumentRoute.scheme
            )
            configuration.setURLSchemeHandler(
                resourceSchemeHandler,
                forURLScheme: RhwpStudioResourceRoute.scheme
            )
            configuration.preferences.javaScriptCanOpenWindowsAutomatically = false

            configuration.defaultWebpagePreferences.allowsContentJavaScript = true

            let webView = RhwpStudioNativeCommandWebView(frame: .zero, configuration: configuration)
            commandWebView = webView
            webView.nativeCommandHandler = { [weak self, weak webView] command in
                guard let self, let webView else {
                    return false
                }
                self.runNativeCommand(command, in: webView)
                return true
            }
            webView.saveDocumentHandler = { [weak self, weak webView] completion in
                guard let self, let webView else {
                    return false
                }
                self.requestSaveDocument(in: webView, completion: completion)
                return true
            }
            webView.refreshSessionHandler = { [weak self, weak webView] completion in
                guard let self, let webView else { return false }
                Task { @MainActor in
                    do { completion(try await self.readEditorSession(in:webView)) }
                    catch { completion(nil) }
                }
                return true
            }
            webView.droppedFileURLHandler = { [weak self] fileURL in
                self?.handleDroppedFileURL(fileURL)
            }
            RhwpStudioNativeCommandDispatcher.register(webView)
            webView.navigationDelegate = self
            webView.allowsBackForwardNavigationGestures = false
            return webView
        }

        func update(
            document: RhwpStudioDocumentPayload?,
            sourceDocument: RecentDocumentItem?,
            reloadToken: Int,
            loadID: Int,
            in webView: WKWebView
        ) {
            currentReloadToken = reloadToken
            // 명시적인 파일 열기·재시도 요청만 WebView를 reload한다.
            guard loadID != loadedIdentity else {
                // 내부 생성 후 늦게 도착한 SwiftUI의 이전 source를 복원하지 않는다.
                if editorSession?.sourceBinding != .editorOnly {
                    currentDocument = document
                    currentSourceDocument = sourceDocument
                    documentProvider.setDocument(document)
                }
                return
            }
            currentDocument = document
            currentSourceDocument = sourceDocument
            documentProvider.setDocument(document)
            editorSession = nil
            editorLoadToken = UUID().uuidString
            installUserScripts(in: webView, loadID: loadID)

            pdfExportState.invalidatePendingRequestForDocumentChange()
            activeSaveID = nil
            pendingSaveRequest = nil

            do {
                let loadURL = try RhwpStudioResourceLocator.loadURL(for: document)
                loadedIdentity = loadID
                hasCompletedCurrentLoad = false
                onError(nil)
                onLoadStateChange(true)
                activeLoadID += 1
                startLoadTimeout(activeLoadID, webView: webView)
                webView.load(URLRequest(url: loadURL))
            } catch let error as RhwpStudioResourceLocatorError {
                loadedIdentity = nil
                hasCompletedCurrentLoad = false
                finishLoading()
                reportFailure(.resourcePreflight(error))
            } catch let failure as RhwpStudioWebViewFailure {
                loadedIdentity = nil
                hasCompletedCurrentLoad = false
                finishLoading()
                reportFailure(failure)
            } catch {
                loadedIdentity = nil
                hasCompletedCurrentLoad = false
                finishLoading()
                reportFailure(.navigation(error: error, fallbackURL: webView.url))
            }
        }

        private func installUserScripts(in webView: WKWebView, loadID: Int) {
            let controller = webView.configuration.userContentController
            controller.removeAllUserScripts()
            let context = "window.__alhangeulEditorLoad = {loadID: \(loadID), token: \(Self.javaScriptStringLiteral(editorLoadToken))};"
            controller.addUserScript(WKUserScript(
                source: context + RhwpStudioSaveBridgeScript.guardSource + RhwpStudioHostBridgeScript.runtimeErrorSource,
                injectionTime: .atDocumentStart, forMainFrameOnly: true
            ))
            controller.addUserScript(WKUserScript(
                source: RhwpStudioHostBridgeScript.source,
                injectionTime: .atDocumentEnd, forMainFrameOnly: true
            ))
        }

        private func handleEditorSession(_ body: [String: Any]) {
            guard body["token"] as? String == editorLoadToken,
                  let loadID = loadedIdentity,
                  let data = try? JSONSerialization.data(withJSONObject: body),
                  let snapshot = try? JSONDecoder().decode(RhwpStudioEditorSnapshot.self, from: data),
                  let session = RhwpStudioEditorSession.accepting(
                    snapshot, after: editorSession, loadID: loadID,
                    hasNativeDocument: currentDocument != nil
                  )
            else { return }
            let previous = editorSession
            editorSession = session
            if session.sourceBinding == .editorOnly {
                currentDocument = nil
                currentSourceDocument = nil
                documentProvider.setDocument(nil)
            }
            if let previous, previous.snapshot.documentEpoch != snapshot.documentEpoch {
                pdfExportState.invalidatePendingRequestForDocumentChange()
                if let activeSaveEpoch, activeSaveEpoch != snapshot.documentEpoch {
                    activeSaveID = nil
                    pendingSaveRequest = nil
                }
            }
            onEditorSessionChange(session)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            hasCompletedCurrentLoad = true
            finishLoading()
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            handleNavigationError(error, webView: webView)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            pdfExportState.invalidatePendingRequestForDocumentChange()
            hasCompletedCurrentLoad = false
            finishLoading()
            reportFailure(
                .processTerminated(
                    lastURL: webView.url,
                    document: currentDocument,
                    reloadToken: currentReloadToken
                )
            )
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            handleNavigationError(error, webView: webView)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }

            if isAllowedNavigation(to: url) {
                decisionHandler(.allow)
            } else {
                decisionHandler(.cancel)
                hasCompletedCurrentLoad = false
                finishLoading()
                reportFailure(.blockedNavigation(to: url))
            }
        }

        private func handleNavigationError(_ error: Error, webView: WKWebView? = nil) {
            finishLoading()
            guard !isIgnorableNavigationError(error) else {
                return
            }
            hasCompletedCurrentLoad = false
            reportFailure(.from(error: error, fallbackURL: webView?.url))
        }

        private func startLoadTimeout(_ loadID: Int, webView: WKWebView) {
            loadTimeoutTask?.cancel()
            loadTimeoutTask = Task { @MainActor [weak self, weak webView] in
                try? await Task.sleep(nanoseconds: Self.loadTimeoutNanoseconds)
                guard !Task.isCancelled,
                      let self,
                      self.activeLoadID == loadID
                else {
                    return
                }

                let loadingURL = webView?.url
                self.hasCompletedCurrentLoad = false
                self.finishLoading()
                self.reportFailure(
                    .timeout(
                        loadingURL: loadingURL,
                        document: self.currentDocument,
                        reloadToken: self.currentReloadToken,
                        timeoutSeconds: Int(Self.loadTimeoutNanoseconds / 1_000_000_000)
                    )
                )
            }
        }

        private func finishLoading() {
            loadTimeoutTask?.cancel()
            loadTimeoutTask = nil
            onLoadStateChange(false)
        }

        private func isIgnorableNavigationError(_ error: Error) -> Bool {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
                return true
            }
            if nsError.domain == "WebKitErrorDomain", nsError.code == 102 {
                return true
            }
            return false
        }

        private func isAllowedNavigation(to url: URL) -> Bool {
            switch url.scheme?.lowercased() {
            case RhwpStudioResourceRoute.scheme:
                return RhwpStudioResourceRoute.isStudioResourceURL(url)
            case "about", "blob", "data":
                return true
            case RhwpStudioDocumentRoute.scheme:
                return RhwpStudioDocumentRoute.isCurrentDocumentURL(url)
            default:
                return false
            }
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == RhwpStudioHostBridgeScript.messageHandlerName,
                  let body = message.body as? [String: Any],
                  let type = body["type"] as? String
            else {
                return
            }

            switch type {
            case "command":
                handleHostCommand(body)
            case "dropped-document":
                handleDroppedDocument(body)
            case "save-document":
                break // 이전 비상관 응답으로 파일을 쓰지 않는다.
            case "share-document":
                shareDocument(body)
            case "print-document":
                printDocument(body)
            case "export-pdf-document":
                break // 요청에 연결된 async 결과만 처리한다.
            case "export-pdf-error":
                handlePDFExportError(body)
            case "error":
                let message = body["message"] as? String
                onError(message)
            case "save-sync-error":
                onError(body["message"] as? String)
            case "runtime-error":
                handleRuntimeError(body)
            case "document-load-error":
                handleDocumentLoadError(body)
            case "editor-session":
                if message.frameInfo.isMainFrame {
                    handleEditorSession(body)
                }
            default:
                break
            }
        }

        private func reportFailure(_ failure: RhwpStudioWebViewFailure) {
            if failure.isFatal {
                activeSaveID = nil
                pendingSaveRequest = nil
                editorSession = nil
                editorLoadToken = UUID().uuidString
            }
            onFailure(failure)
        }

        private func handleDocumentLoadError(_ body: [String: Any]) {
            hasCompletedCurrentLoad = false
            finishLoading()
            reportFailure(
                .documentLoadError(
                    message: body["message"] as? String,
                    document: currentDocument,
                    reloadToken: currentReloadToken
                )
            )
        }

        private func handleRuntimeError(_ body: [String: Any]) {
            let message = body["message"] as? String
            let sourceURL = body["sourceURL"] as? String
            let line = intValue(body["line"])
            let column = intValue(body["column"])
            let reason = body["reason"] as? String
            let isFatal = !isRecoverablePostLoadRuntimeError(
                message: message,
                sourceURL: sourceURL,
                line: line,
                column: column,
                reason: reason
            )

            finishLoading()
            reportFailure(
                .runtime(
                    message: message,
                    sourceURL: sourceURL,
                    line: line,
                    column: column,
                    reason: reason,
                    isFatal: isFatal
                )
            )
        }

        private func isRecoverablePostLoadRuntimeError(
            message: String?,
            sourceURL: String?,
            line: Int?,
            column: Int?,
            reason: String?
        ) -> Bool {
            guard currentDocument != nil,
                  hasCompletedCurrentLoad,
                  Self.hasRecoverableRuntimeMessage(message) || Self.hasRecoverableRuntimeMessage(reason),
                  Self.isRecoverableRuntimeSource(sourceURL: sourceURL, line: line, column: column, reason: reason)
            else {
                return false
            }
            return true
        }

        private static func hasRecoverableRuntimeMessage(_ value: String?) -> Bool {
            guard let value else {
                return false
            }
            return recoverableRuntimeMessages.contains { value.contains($0) }
        }

        private static func isRecoverableRuntimeSource(
            sourceURL: String?,
            line: Int?,
            column: Int?,
            reason: String?
        ) -> Bool {
            guard let sourceURL,
                  let url = URL(string: sourceURL),
                  RhwpStudioResourceRoute.isStudioResourceURL(url)
            else {
                return false
            }

            let path = url.path
            if path.hasPrefix(recoverableRuntimeAssetPathPrefix) && path.hasSuffix(".js") {
                return line == recoverableRuntimeAssetLine
            }

            if path == "/index.html", line == 0, column == 0 {
                return reason?.contains(recoverableRuntimeAssetPathPrefix) == true
                    && reason?.contains(":\(recoverableRuntimeAssetLine):") == true
            }

            return false
        }

        private func handleDroppedDocument(_ body: [String: Any]) {
            guard let fileName = body["fileName"] as? String,
                  Self.isSupportedDocumentFilename(fileName)
            else {
                onError("끌어놓은 문서를 열 수 없습니다: HWP/HWPX 파일만 지원합니다.")
                return
            }

            if shouldSuppressDroppedDocument(fileName: fileName) {
                return
            }

            guard let data = decodedData(
                from: body,
                missingMessage: "끌어놓은 문서를 읽을 수 없습니다"
            ) else {
                return
            }

            onDroppedDocument(
                RhwpStudioDroppedDocument(
                    data: data,
                    fileName: fileName
                )
            )
        }

        private func handleDroppedFileURL(_ fileURL: URL) {
            recentNativeDrop = NativeDropMarker(
                fileName: Self.normalizedFilename(fileURL.lastPathComponent),
                handledAt: Date()
            )
            onDroppedFileURL(fileURL)
        }

        private func shouldSuppressDroppedDocument(fileName: String) -> Bool {
            guard let recentNativeDrop else {
                return false
            }

            guard Date().timeIntervalSince(recentNativeDrop.handledAt) <= Self.nativeDropSuppressionInterval else {
                self.recentNativeDrop = nil
                return false
            }

            guard recentNativeDrop.fileName == Self.normalizedFilename(fileName) else {
                return false
            }

            self.recentNativeDrop = nil
            return true
        }

        private func handleHostCommand(_ body: [String: Any]) {
            guard let command = body["command"] as? String else {
                return
            }

            if let saveCommand = DocumentSaveCommand(rawValue: command) {
                guard let webView = commandWebView else {
                    onError("저장할 viewer를 찾을 수 없습니다.")
                    return
                }

                let suggestedFilename = body["fileName"] as? String
                let format: DocumentSaveFormat? = saveCommand == .saveAsHwp ? .hwp : saveCommand == .saveAsHwpx ? .hwpx : nil
                if saveCommand.usesSavePanel {
                    requestSaveAsDocument(
                        in: webView,
                        format: format,
                        suggestedFilename: suggestedFilename
                    )
                } else {
                    requestSaveDocument(
                        in: webView,
                        format: format,
                        suggestedFilename: suggestedFilename
                    )
                }
                return
            }

            switch command {
            case "file:open":
                onOpenDocument()
            case "file:export-pdf":
                guard let webView = commandWebView else {
                    onError("PDF로 내보낼 viewer를 찾을 수 없습니다.")
                    return
                }
                requestPDFExport(
                    in: webView,
                    suggestedFilename: body["fileName"] as? String
                )
            default:
                break
            }
        }

        private func validatedSavePayload(
            from body: [String: Any],
            request: PendingSaveRequest
        ) throws -> SavePayload {
            try validatePendingSaveRequest(request)
            let data = try DocumentSaveContract.decodeAndValidate(
                base64: body["base64"] as? String,
                responseFormatRawValue: body["format"] as? String,
                responseByteCount: intValue(body["byteCount"]),
                requestFormat: request.format,
                destinationURL: request.destinationURL
            )
            let responseFilename = body["fileName"] as? String
                ?? currentSourceDocument?.displayName
                ?? currentDocument?.filename
                ?? request.format.defaultFilename
            return SavePayload(
                data: data,
                fileName: request.format.normalizedFilename(responseFilename),
                format: request.format
            )
        }

        private func writePayload(
            _ payload: SavePayload,
            to sourceDocument: RecentDocumentItem
        ) throws -> URL {
            let url = try sourceDocument.resolvedURL()
            let didStartSecurityScope = url.startAccessingSecurityScopedResource()
            defer {
                if didStartSecurityScope {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            try writeSaveData(payload.data, url, true)
            return url
        }

        private func recordSavedDocument(at url: URL, payload: SavePayload, request: PendingSaveRequest) {
            guard let session = editorSession else { return }
            let bound = RhwpStudioEditorSession(snapshot:session.snapshot, sourceBinding:.nativeLoad)
            let protection = DocumentSaveProtectionPolicy.resultingProtection(
                sourceProtection:request.sourceProtection, for:request.outputProtectionIntent
            )
            editorSession = bound
            currentDocument = RhwpStudioDocumentPayload(
                data:payload.data, filename:url.lastPathComponent,
                revision:request.documentRevision, sourceProtection:protection
            )
            documentProvider.setDocument(currentDocument)
            currentSourceDocument = RecentDocumentItem.make(for:url)
            onDocumentSaved(.init(url:url, data:payload.data, sourceProtection:protection, session:bound))
        }

        private static func saveStatusTimeText() -> String {
            let components = Calendar.current.dateComponents([.hour, .minute], from: Date())
            return String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
        }

        private static func javaScriptStringLiteral(_ value: String) -> String {
            guard let data = try? JSONSerialization.data(withJSONObject: [value]),
                  let arrayLiteral = String(data: data, encoding: .utf8),
                  arrayLiteral.hasPrefix("["),
                  arrayLiteral.hasSuffix("]")
            else {
                return "\"\""
            }

            return String(arrayLiteral.dropFirst().dropLast())
        }

        private func shareDocument(_ body: [String: Any]) {
            guard let payload = exportedDocumentPayload(
                from: body,
                missingMessage: "공유 데이터를 만들 수 없습니다"
            ) else {
                return
            }

            do {
                try DocumentFileActions.share(
                    data: payload.data,
                    filename: payload.fileName
                )
            } catch {
                onError("공유할 수 없습니다: \(error.localizedDescription)")
            }
        }

        private func exportedDocumentPayload(
            from body: [String: Any],
            missingMessage: String
        ) -> (data: Data, fileName: String)? {
            guard let data = decodedData(
                from: body,
                missingMessage: missingMessage
            ) else {
                return nil
            }

            let fileName = body["fileName"] as? String
                ?? currentDocument?.filename
                ?? "document.hwp"
            return (data, fileName)
        }

        private func decodedData(
            from body: [String: Any],
            missingMessage: String
        ) -> Data? {
            let data: Data
            if let base64 = body["base64"] as? String {
                guard let decodedData = Data(base64Encoded: base64) else {
                    onError("\(missingMessage): base64 데이터를 해석할 수 없습니다.")
                    return nil
                }
                data = decodedData
            } else if let values = body["bytes"] as? [NSNumber] {
                var decodedData = Data()
                decodedData.reserveCapacity(values.count)
                for value in values {
                    decodedData.append(UInt8(truncating: value))
                }
                data = decodedData
            } else {
                onError("\(missingMessage): bytes가 없습니다.")
                return nil
            }

            if let expectedByteCount = intValue(body["byteCount"]),
               expectedByteCount != data.count {
                onError("\(missingMessage): 데이터 크기가 일치하지 않습니다.")
                return nil
            }

            return data
        }

        private func printDocument(_ body: [String: Any]) {
            guard let payload = pagePayload(from: body, missingMessage: "인쇄 데이터를 만들 수 없습니다") else {
                return
            }

            printLifecycle.start(
                payload: payload,
                onRejected: { [weak self] error in
                    self?.onError(error.localizedDescription)
                }
            )
        }

        private func pagePayload(
            from body: [String: Any],
            missingMessage: String
        ) -> RhwpStudioPagePayload? {
            guard let pageCount = intValue(body["pageCount"]),
                  let pages = body["pages"] as? [String]
            else {
                onError("\(missingMessage): 페이지 데이터가 없습니다.")
                return nil
            }

            let fileName = body["fileName"] as? String
                ?? currentDocument?.filename
                ?? "document.hwp"
            do {
                return try RhwpStudioPagePayload(
                    fileName: fileName,
                    pageCount: pageCount,
                    pages: pages
                )
            } catch {
                onError("\(missingMessage): \(error.localizedDescription)")
                return nil
            }
        }

        private func intValue(_ value: Any?) -> Int? {
            if let int = value as? Int {
                return int
            }
            if let number = value as? NSNumber {
                return number.intValue
            }
            return nil
        }

        private static func isSupportedDocumentFilename(_ fileName: String) -> Bool {
            let pathExtension = URL(fileURLWithPath: fileName).pathExtension.lowercased()
            return pathExtension == "hwp" || pathExtension == "hwpx"
        }

        private static func normalizedFilename(_ fileName: String) -> String {
            URL(fileURLWithPath: fileName).lastPathComponent.lowercased()
        }

        private func runNativeCommand(_ command: String, in webView: WKWebView) {
            if let saveCommand = DocumentSaveCommand(rawValue: command) {
                let format: DocumentSaveFormat? = saveCommand == .saveAsHwp ? .hwp : saveCommand == .saveAsHwpx ? .hwpx : nil
                if saveCommand.usesSavePanel {
                    requestSaveAsDocument(in: webView, format: format)
                } else {
                    requestSaveDocument(in: webView, format: format)
                }
                return
            }

            let script: String
            switch command {
            case "file:open":
                script = "window.__alhangeulHostBridgeRunNativeCommand?.('file:open')"
            case "file:print":
                script = "window.__alhangeulHostBridgeRunNativeCommand?.('file:print')"
            case "file:share":
                script = "window.__alhangeulHostBridgeRunNativeCommand?.('file:share')"
            case "file:export-pdf":
                requestPDFExport(in: webView)
                return
            default:
                return
            }
            webView.evaluateJavaScript(script) { [weak self] _, error in
                if let error {
                    self?.onError("단축키 명령을 실행할 수 없습니다: \(error.localizedDescription)")
                }
            }
        }

        private func requestSaveDocument(
            in webView: WKWebView,
            format requestedFormat: DocumentSaveFormat? = nil,
            suggestedFilename: String? = nil,
            completion: ((RhwpStudioDocumentSaveResult) -> Void)? = nil
        ) {
            requestSave(in: webView, format: requestedFormat, suggestedFilename: suggestedFilename,
                        forcePanel: false, completion: completion)
        }

        private func requestSaveAsDocument(
            in webView: WKWebView,
            format requestedFormat: DocumentSaveFormat? = nil,
            suggestedFilename: String? = nil,
            completion: ((RhwpStudioDocumentSaveResult) -> Void)? = nil
        ) {
            requestSave(in: webView, format: requestedFormat, suggestedFilename: suggestedFilename,
                        forcePanel: true, completion: completion)
        }

        private func requestSave(
            in webView: WKWebView,
            format requestedFormat: DocumentSaveFormat?,
            suggestedFilename: String?,
            forcePanel: Bool,
            completion: ((RhwpStudioDocumentSaveResult) -> Void)?
        ) {
            guard activeSaveID == nil, pdfExportState.isIdle, !isPDFPreparing else {
                completion?(.failed("이미 저장이 진행 중입니다."))
                return
            }
            let id = UUID().uuidString
            let token = editorLoadToken
            activeSaveID = id
            activeSaveEpoch = nil
            Task { @MainActor [weak self, weak webView] in
                guard let self, let webView else {
                    completion?(.failed("저장할 viewer를 찾을 수 없습니다."))
                    return
                }
                var result: RhwpStudioDocumentSaveResult = .cancelled
                do {
                    let session = try await self.readEditorSession(in: webView)
                    try self.requireSave(id, token: token, epoch: session.snapshot.documentEpoch)
                    self.activeSaveEpoch = session.snapshot.documentEpoch
                    // 첫 조회에서 오래된 원본 연결이 해제된 뒤 형식·destination을 결정한다.
                    let format = requestedFormat ?? DocumentSaveFormat.resolve(
                        sourceURL: self.currentSourceDocument?.url,
                        filename: suggestedFilename ?? self.currentDocument?.filename ?? "새 문서.\(session.snapshot.format)"
                    )
                    let protection = self.currentDocument?.sourceProtection ?? .invalidOrUnknown
                    let sourceFormat = self.currentDocument?.sourceFormatIdentity ?? .other
                    let outputIntent = DocumentSaveProtectionPolicy.outputIntent(for: protection)
                    let conversion = DocumentSaveConversionIntent.resolve(sourceFormat: sourceFormat, outputFormat: format)
                    let sourceURL = self.currentSourceDocument.map(self.resolvedSourceURL)
                    let destination: SaveDestination?
                    if !forcePanel, let source = self.currentSourceDocument,
                       DocumentSaveProtectionPolicy.allowsInPlaceSave(sourceProtection: protection, sourceFormat: sourceFormat),
                       DocumentSaveFormat(url: source.url) == format {
                        destination = .source(source)
                    } else {
                        let warning = DocumentSaveWarningIntent.resolve(sourceProtection: protection, conversionIntent: conversion)
                        if warning.requiresConfirmation,
                           !(await self.confirmSaveTransformation(protection, conversion, webView.window)) {
                            throw SaveOperationCancelled()
                        }
                        try self.requireSave(id, token: token, epoch: session.snapshot.documentEpoch)
                        let filename = DocumentSaveProtectionPolicy.suggestedFilename(
                            for: suggestedFilename ?? self.currentDocument?.filename ?? "새 문서.\(format.rawValue)",
                            format: format, outputIntent: outputIntent, conversionIntent: conversion
                        )
                        if let url = await self.chooseSaveDestination(format, filename, webView.window) {
                            destination = .selected(url)
                        } else {
                            destination = nil
                        }
                    }
                    guard let destination else { throw SaveOperationCancelled() }
                    let fresh = try await self.readEditorSession(in: webView)
                    try self.requireSave(id, token: token, epoch: session.snapshot.documentEpoch)
                    guard fresh.snapshot.documentEpoch == session.snapshot.documentEpoch else {
                        throw DocumentSaveProtectionPolicyError.documentChanged
                    }
                    let request = PendingSaveRequest(
                        id: id, token: token, loadID: session.snapshot.loadID,
                        documentEpoch: session.snapshot.documentEpoch,
                        destination: destination, format: format,
                        documentRevision: self.currentDocument?.revision ?? 0,
                        sourceProtection: protection, sourceFormat: sourceFormat,
                        outputProtectionIntent: outputIntent, conversionIntent: conversion, sourceURL: sourceURL
                    )
                    try self.validatePendingSaveRequest(request)
                    self.pendingSaveRequest = request
                    let body = try await self.bridgeObject(
                        "return await window.__alhangeulHostBridgeSave.begin(id, token, epoch, format);",
                        arguments: ["id":id, "token":token, "epoch":request.documentEpoch, "format":format.rawValue],
                        in: webView
                    )
                    try self.requireSave(id, token: token, epoch: request.documentEpoch)
                    guard body["requestID"] as? String == id, body["token"] as? String == token,
                          let snapshot = body["snapshot"] as? [String: Any],
                          self.intValue(snapshot["documentEpoch"]) == request.documentEpoch,
                          self.intValue(snapshot["loadID"]) == request.loadID
                    else { throw DocumentSaveProtectionPolicyError.documentChanged }
                    self.handleEditorSession(snapshot)
                    let payload = try self.validatedSavePayload(from: body, request: request)
                    _ = try await self.bridgeObject(
                        "return await window.__alhangeulHostBridgeSave.validate(id);", arguments:["id":id], in:webView
                    )
                    try self.requireSave(id, token: token, epoch: request.documentEpoch)
                    try self.validatePendingSaveRequest(request)
                    let url: URL
                    switch destination {
                    case .source(let source):
                        url = try self.writePayload(payload, to: source)
                    case .selected(let selected):
                        try self.writeSaveData(payload.data, selected, !conversion.requiresNewDestination &&
                            !(outputIntent == .plainCopy && sourceURL == nil))
                        url = selected
                    }
                    // 실제 파일 쓰기 성공 후에만 원본 metadata를 연결한다.
                    var syncError: Error?
                    do {
                        let savedState = try await self.bridgeObject(
                            "return await window.__alhangeulHostBridgeSave.finish(id, fileName, timeText);",
                            arguments:["id":id, "fileName":url.lastPathComponent, "timeText":Self.saveStatusTimeText()], in:webView
                        )
                        try self.requireSave(id, token: token, epoch: request.documentEpoch)
                        self.handleEditorSession(savedState)
                    } catch { syncError = error }
                    if self.activeSaveID == id, self.editorLoadToken == token,
                       self.editorSession?.snapshot.documentEpoch == request.documentEpoch {
                        self.recordSavedDocument(at:url, payload:payload, request:request)
                    }
                    if let syncError {
                        throw SaveSynchronizationError(detail: syncError.localizedDescription)
                    }
                    result = .saved(url)
                } catch is SaveOperationCancelled {
                    result = .cancelled
                } catch {
                    let message = "문서를 저장할 수 없습니다: \(error.localizedDescription)"
                    self.onError(message)
                    result = .failed(message)
                }
                // 성공·취소·오류 모두 요청별 lock을 해제한다. 새 page의 lock은 건드리지 않는다.
                if self.editorLoadToken == token {
                    _ = try? await webView.callAsyncJavaScript(
                        "window.__alhangeulHostBridgeSave?.release(id);", arguments:["id":id], in:nil, contentWorld:.page
                    )
                }
                if self.activeSaveID == id {
                    self.activeSaveID = nil
                    self.pendingSaveRequest = nil
                }
                completion?(result)
            }
        }

        private struct SaveOperationCancelled: Error {}
        private struct SaveSynchronizationError: LocalizedError {
            let detail: String
            var errorDescription: String? { "파일은 저장했지만 편집기 동기화가 실패했습니다. 창을 유지합니다: \(detail)" }
        }

        private func requireSave(_ id: String, token: String, epoch: Int) throws {
            guard activeSaveID == id, editorLoadToken == token,
                  editorSession?.snapshot.documentEpoch == epoch,
                  editorSession?.snapshot.ready == true
            else { throw DocumentSaveProtectionPolicyError.documentChanged }
        }

        private func bridgeObject(
            _ script: String, arguments: [String: Any] = [:], in webView: WKWebView
        ) async throws -> [String: Any] {
            do {
                guard let body = try await webView.callAsyncJavaScript(
                    script, arguments:arguments, in:nil, contentWorld:.page
                ) as? [String: Any] else { throw DocumentSaveProtectionPolicyError.documentChanged }
                return body
            } catch let error as NSError {
                if let detail = error.userInfo["WKJavaScriptExceptionMessage"] as? String {
                    throw SaveBridgeError(detail:detail)
                }
                throw error
            }
        }

        private struct SaveBridgeError: LocalizedError {
            let detail: String
            var errorDescription: String? { detail }
        }

        private func readEditorSession(in webView: WKWebView) async throws -> RhwpStudioEditorSession {
            let token = editorLoadToken
            let body = try await bridgeObject("return await window.__alhangeulHostBridgeReadSession();", in:webView)
            guard token == editorLoadToken, body["token"] as? String == token else {
                throw DocumentSaveProtectionPolicyError.documentChanged
            }
            handleEditorSession(body)
            guard let session = editorSession, session.snapshot.ready else {
                throw DocumentSaveProtectionPolicyError.documentChanged
            }
            return session
        }

        private func validatePendingSaveRequest(_ request: PendingSaveRequest) throws {
            try requireSave(request.id, token:request.token, epoch:request.documentEpoch)
            try DocumentSaveProtectionPolicy.validateCurrentDocument(
                requestRevision: request.documentRevision, requestProtection: request.sourceProtection,
                requestSourceFormat: request.sourceFormat, currentRevision: currentDocument?.revision ?? 0,
                currentProtection: currentDocument?.sourceProtection ?? .invalidOrUnknown,
                currentSourceFormat: currentDocument?.sourceFormatIdentity ?? .other
            )
            try DocumentSaveProtectionPolicy.validateRequest(
                sourceProtection:request.sourceProtection, outputIntent:request.outputProtectionIntent,
                sourceFormat:request.sourceFormat, outputFormat:request.format,
                conversionIntent:request.conversionIntent, sourceURL:request.sourceURL,
                destinationURL:request.destinationURL
            )
        }

        private func resolvedSourceURL(_ sourceDocument: RecentDocumentItem) -> URL {
            (try? sourceDocument.resolvedURL()) ?? sourceDocument.url
        }

        private func requestPDFExport(in webView: WKWebView, suggestedFilename: String? = nil) {
            guard !isPDFPreparing, pdfExportState.isIdle, activeSaveID == nil else {
                onError("저장 또는 PDF 내보내기가 이미 진행 중입니다.")
                return
            }
            isPDFPreparing = true
            nextPDFExportRequestID += 1
            let id = nextPDFExportRequestID
            let token = editorLoadToken
            let lockID = "pdf-\(token)-\(id)"
            Task { @MainActor [weak self, weak webView] in
                guard let self, let webView else { return }
                do {
                    let initial = try await self.readEditorSession(in:webView)
                    guard self.editorLoadToken == token else { throw DocumentSaveProtectionPolicyError.documentChanged }
                    let request = RhwpStudioPDFExportRequest(id:id, loadID:self.activeLoadID)
                    guard self.pdfExportState.beginChoosingDestination(for:request) else { throw SaveOperationCancelled() }
                    guard let url = await self.choosePDFDestination(
                        suggestedFilename ?? self.currentDocument?.filename ?? "새 문서.hwp", webView.window
                    ) else { throw SaveOperationCancelled() }
                    let fresh = try await self.readEditorSession(in:webView)
                    guard self.editorLoadToken == token,
                          initial.snapshot.documentEpoch == fresh.snapshot.documentEpoch,
                          self.pdfExportState.beginCollectingPages(for:request, destinationURL:url, currentLoadID:self.activeLoadID)
                    else { throw DocumentSaveProtectionPolicyError.documentChanged }
                    let body = try await self.bridgeObject(
                        "return await window.__alhangeulHostBridgeSave.begin(id, token, epoch, 'pdf');",
                        arguments:["id":lockID, "token":token, "epoch":initial.snapshot.documentEpoch], in:webView
                    )
                    guard body["requestID"] as? String == lockID, body["token"] as? String == token,
                          self.editorLoadToken == token,
                          self.editorSession?.snapshot.documentEpoch == initial.snapshot.documentEpoch,
                          let payload = self.pagePayload(from:body, missingMessage:"PDF 데이터를 만들 수 없습니다"),
                          self.pdfExportState.beginExporting(requestID:id) != nil
                    else { throw DocumentSaveProtectionPolicyError.documentChanged }
                    let controller = RhwpStudioPDFExportController()
                    self.pdfExportController = controller
                    let savedURL: URL = try await withCheckedThrowingContinuation { continuation in
                        controller.export(payload:payload, destinationURL:url, validateBeforeWrite: {
                            _ = try await self.bridgeObject(
                                "return await window.__alhangeulHostBridgeSave.validate(id);", arguments:["id":lockID], in:webView
                            )
                            guard self.editorLoadToken == token,
                                  self.editorSession?.snapshot.documentEpoch == initial.snapshot.documentEpoch
                            else { throw DocumentSaveProtectionPolicyError.documentChanged }
                        }, completion: { continuation.resume(with:$0) })
                    }
                    self.onPDFExported(savedURL)
                } catch is SaveOperationCancelled {
                    // 선택 취소는 원본 상태를 바꾸지 않는다.
                } catch {
                    self.onError("PDF를 내보낼 수 없습니다: \(error.localizedDescription)")
                }
                if self.editorLoadToken == token {
                    _ = try? await webView.callAsyncJavaScript(
                        "window.__alhangeulHostBridgeSave?.release(id);", arguments:["id":lockID], in:nil, contentWorld:.page
                    )
                }
                self.pdfExportState.cancelDestinationSelection(requestID:id)
                self.pdfExportState.failCollection(requestID:id)
                self.pdfExportState.finishExport(requestID:id)
                self.pdfExportController = nil
                self.isPDFPreparing = false
            }
        }

        private func handlePDFExportError(_ body: [String: Any]) {
            guard let requestID = intValue(body["requestID"]),
                  resetPendingPDFExportCollection(requestID: requestID)
            else {
                return
            }
            onError(body["message"] as? String ?? "PDF 데이터를 만들 수 없습니다.")
        }

        @discardableResult
        private func resetPendingPDFExportCollection(requestID: Int) -> Bool {
            pdfExportState.failCollection(requestID: requestID)
        }

        private func evaluateHostBridgeAction(
            _ script: String,
            in webView: WKWebView,
            failureMessage: String,
            onFailure: @escaping () -> Void
        ) {
            webView.evaluateJavaScript(script) { [weak self] result, error in
                if let error {
                    onFailure()
                    self?.onError("\(failureMessage): \(error.localizedDescription)")
                    return
                }

                if let didStart = result as? Bool, didStart {
                    return
                }
                if let didStart = result as? NSNumber, didStart.boolValue {
                    return
                }

                onFailure()
                self?.onError("\(failureMessage): viewer export bridge를 실행할 수 없습니다.")
            }
        }
    }
}

private final class RhwpStudioNativeCommandWebView: WKWebView {
    var nativeCommandHandler: ((String) -> Bool)?
    var saveDocumentHandler: ((@escaping (RhwpStudioDocumentSaveResult) -> Void) -> Bool)?
    var refreshSessionHandler: ((@escaping (RhwpStudioEditorSession?) -> Void) -> Bool)?
    var droppedFileURLHandler: ((URL) -> Void)?

    override init(frame: NSRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @discardableResult
    func runNativeCommand(_ command: String) -> Bool {
        nativeCommandHandler?(command) ?? false
    }

    @discardableResult
    func saveDocument(completion: @escaping (RhwpStudioDocumentSaveResult) -> Void) -> Bool {
        saveDocumentHandler?(completion) ?? false
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard canHandleDocumentDrop(from: sender) else {
            return super.draggingEntered(sender)
        }
        return acceptedDropOperation(for: sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard canHandleDocumentDrop(from: sender) else {
            return super.draggingUpdated(sender)
        }
        return acceptedDropOperation(for: sender)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard canHandleDocumentDrop(from: sender) else {
            return super.prepareForDragOperation(sender)
        }
        return droppedFileURLHandler != nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let droppedFileURLHandler,
              let fileURL = supportedDocumentFileURL(from: sender)
        else {
            return super.performDragOperation(sender)
        }

        droppedFileURLHandler(fileURL)
        return true
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if handleNativeCommandShortcut(event) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if handleNativeCommandShortcut(event) {
            return
        }
        super.keyDown(with: event)
    }

    private func handleNativeCommandShortcut(_ event: NSEvent) -> Bool {
        guard !event.isARepeat,
              let command = nativeCommand(for: event)
        else {
            return false
        }
        return runNativeCommand(command)
    }

    private func nativeCommand(for event: NSEvent) -> String? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let hasCommandModifier = flags.contains(.command) || flags.contains(.control)
        let hasShiftModifier = flags.contains(.shift)
        guard hasCommandModifier,
              !flags.contains(.option)
        else {
            return nil
        }

        switch event.keyCode {
        case 31:
            guard !hasShiftModifier else {
                return nil
            }
            return "file:open"
        case 1:
            return hasShiftModifier ? "file:save-as" : "file:save"
        case 35:
            guard !hasShiftModifier else {
                return nil
            }
            return "file:print"
        default:
            return nil
        }
    }

    private func canHandleDocumentDrop(from sender: NSDraggingInfo) -> Bool {
        droppedFileURLHandler != nil && supportedDocumentFileURL(from: sender) != nil
    }

    private func acceptedDropOperation(for sender: NSDraggingInfo) -> NSDragOperation {
        let sourceMask = sender.draggingSourceOperationMask
        if sourceMask.contains(.copy) {
            return .copy
        }
        if sourceMask.contains(.generic) {
            return .generic
        }
        return []
    }

    private func supportedDocumentFileURL(from sender: NSDraggingInfo) -> URL? {
        supportedDocumentFileURLs(from: sender.draggingPasteboard).first
    }

    private func supportedDocumentFileURLs(from pasteboard: NSPasteboard) -> [URL] {
        let objects = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        )

        return objects?
            .compactMap { object -> URL? in
                if let url = object as? URL {
                    return url
                }
                if let url = object as? NSURL {
                    return url as URL
                }
                return nil
            }
            .map(\.standardizedFileURL)
            .filter(Self.isSupportedDocumentFileURL) ?? []
    }

    private static func isSupportedDocumentFileURL(_ url: URL) -> Bool {
        guard url.isFileURL else {
            return false
        }

        let pathExtension = url.pathExtension.lowercased()
        return pathExtension == "hwp" || pathExtension == "hwpx"
    }
}

@MainActor
enum RhwpStudioNativeCommandDispatcher {
    private static var registeredWebViews: [WeakNativeCommandWebView] = []

    fileprivate static func register(_ webView: RhwpStudioNativeCommandWebView) {
        cleanupRegisteredWebViews()
        guard !registeredWebViews.contains(where: { $0.webView === webView }) else {
            return
        }
        registeredWebViews.append(WeakNativeCommandWebView(webView))
    }

    @discardableResult
    static func run(_ command: String) -> Bool {
        run(command, in: nil)
    }

    @discardableResult
    static func run(_ command: String, in preferredWindow: NSWindow?) -> Bool {
        perform(in: preferredWindow) { webView in
            webView.runNativeCommand(command)
        }
    }

    @discardableResult
    static func saveDocument(
        in preferredWindow: NSWindow?,
        completion: @escaping (RhwpStudioDocumentSaveResult) -> Void
    ) -> Bool {
        perform(in: preferredWindow) { webView in
            webView.saveDocument(completion: completion)
        }
    }

    @discardableResult
    static func refreshSession(
        in window: NSWindow?, completion: @escaping (RhwpStudioEditorSession?) -> Void
    ) -> Bool {
        perform(in:window) { $0.refreshSessionHandler?(completion) ?? false }
    }

    private static func perform(
        in preferredWindow: NSWindow?,
        action: (RhwpStudioNativeCommandWebView) -> Bool
    ) -> Bool {
        if let preferredWindow {
            guard let webView = preferredWindow.contentView?.firstDescendant(ofType:RhwpStudioNativeCommandWebView.self)
                    ?? registeredWebView(in:preferredWindow) else { return false }
            return action(webView)
        }
        let preferredWindows = [preferredWindow].compactMap { $0 }
        let activeWindows = [NSApp.keyWindow, NSApp.mainWindow].compactMap { $0 }
        let candidateWindows = preferredWindows + activeWindows + NSApp.windows
        var seenWindowIDs = Set<ObjectIdentifier>()

        for window in candidateWindows {
            let windowID = ObjectIdentifier(window)
            guard !seenWindowIDs.contains(windowID) else {
                continue
            }
            seenWindowIDs.insert(windowID)

            guard let webView = window.contentView?.firstDescendant(
                ofType: RhwpStudioNativeCommandWebView.self
            ) ?? registeredWebView(in: window) else {
                continue
            }

            if action(webView) {
                return true
            }
        }

        for webView in registeredWebViews.compactMap(\.webView) where webView.window?.isVisible == true {
            if action(webView) {
                return true
            }
        }

        return false
    }

    private static func registeredWebView(in window: NSWindow) -> RhwpStudioNativeCommandWebView? {
        cleanupRegisteredWebViews()
        return registeredWebViews
            .compactMap(\.webView)
            .first { $0.window === window }
    }

    private static func cleanupRegisteredWebViews() {
        registeredWebViews.removeAll { $0.webView == nil }
    }
}

private final class WeakNativeCommandWebView {
    weak var webView: RhwpStudioNativeCommandWebView?

    init(_ webView: RhwpStudioNativeCommandWebView) {
        self.webView = webView
    }
}

private extension NSView {
    func firstDescendant<T: NSView>(ofType type: T.Type) -> T? {
        if let view = self as? T {
            return view
        }

        for subview in subviews {
            if let view = subview.firstDescendant(ofType: type) {
                return view
            }
        }

        return nil
    }
}
