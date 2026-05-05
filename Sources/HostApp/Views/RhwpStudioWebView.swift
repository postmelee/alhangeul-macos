import AppKit
import SwiftUI
import WebKit

struct RhwpStudioDroppedDocument {
    let data: Data
    let fileName: String
}

struct RhwpStudioWebView: NSViewRepresentable {
    let document: RhwpStudioDocumentPayload?
    let sourceDocument: RecentDocumentItem?
    let onLoadStateChange: (Bool) -> Void
    let onError: (String?) -> Void
    let onOpenDocument: () -> Void
    let onDroppedDocument: (RhwpStudioDroppedDocument) -> Void
    let onDocumentSaved: (URL) -> Void

    init(
        document: RhwpStudioDocumentPayload?,
        sourceDocument: RecentDocumentItem? = nil,
        onLoadStateChange: @escaping (Bool) -> Void = { _ in },
        onError: @escaping (String?) -> Void = { _ in },
        onOpenDocument: @escaping () -> Void = {},
        onDroppedDocument: @escaping (RhwpStudioDroppedDocument) -> Void = { _ in },
        onDocumentSaved: @escaping (URL) -> Void = { _ in }
    ) {
        self.document = document
        self.sourceDocument = sourceDocument
        self.onLoadStateChange = onLoadStateChange
        self.onError = onError
        self.onOpenDocument = onOpenDocument
        self.onDroppedDocument = onDroppedDocument
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
        context.coordinator.onOpenDocument = onOpenDocument
        context.coordinator.onDroppedDocument = onDroppedDocument
        context.coordinator.onDocumentSaved = onDocumentSaved
        context.coordinator.update(document: document, sourceDocument: sourceDocument, in: webView)
    }
}

extension RhwpStudioWebView {
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var onLoadStateChange: (Bool) -> Void = { _ in }
        var onError: (String?) -> Void = { _ in }
        var onOpenDocument: () -> Void = {}
        var onDroppedDocument: (RhwpStudioDroppedDocument) -> Void = { _ in }
        var onDocumentSaved: (URL) -> Void = { _ in }

        private static let loadTimeoutNanoseconds: UInt64 = 15_000_000_000

        private enum LoadIdentity: Equatable {
            case empty
            case document(Int)
        }

        private enum SaveDestination {
            case source(RecentDocumentItem)
            case selected(URL)
        }

        private let documentProvider = RhwpStudioDocumentProvider()
        private let resourceSchemeHandler = RhwpStudioResourceSchemeHandler()
        private lazy var documentSchemeHandler = RhwpStudioDocumentSchemeHandler(
            documentProvider: documentProvider
        )
        private var loadedIdentity: LoadIdentity?
        private var currentDocument: RhwpStudioDocumentPayload?
        private var currentSourceDocument: RecentDocumentItem?
        private weak var commandWebView: WKWebView?
        private var printController: RhwpStudioPrintController?
        private var pdfExportController: RhwpStudioPDFExportController?
        private var pendingSaveDestination: SaveDestination?
        private var pendingPDFDestinationURL: URL?
        private var isChoosingSaveDestination = false
        private var isChoosingPDFDestination = false
        private var activeLoadID = 0
        private var loadTimeoutTask: Task<Void, Never>?

        deinit {
            loadTimeoutTask?.cancel()
        }

        func makeWebView() -> WKWebView {
            let configuration = WKWebViewConfiguration()
            configuration.userContentController.addUserScript(
                WKUserScript(
                    source: RhwpStudioHostBridgeScript.source,
                    injectionTime: .atDocumentEnd,
                    forMainFrameOnly: true
                )
            )
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

            if #available(macOS 11.0, *) {
                configuration.defaultWebpagePreferences.allowsContentJavaScript = true
            }

            let webView = RhwpStudioNativeCommandWebView(frame: .zero, configuration: configuration)
            commandWebView = webView
            webView.nativeCommandHandler = { [weak self, weak webView] command in
                guard let self, let webView else {
                    return false
                }
                self.runNativeCommand(command, in: webView)
                return true
            }
            RhwpStudioNativeCommandDispatcher.register(webView)
            webView.navigationDelegate = self
            webView.allowsBackForwardNavigationGestures = false
            return webView
        }

        func update(
            document: RhwpStudioDocumentPayload?,
            sourceDocument: RecentDocumentItem?,
            in webView: WKWebView
        ) {
            currentDocument = document
            currentSourceDocument = sourceDocument
            documentProvider.setDocument(document)

            let nextIdentity: LoadIdentity = if let document {
                .document(document.revision)
            } else {
                .empty
            }

            guard nextIdentity != loadedIdentity else {
                return
            }

            do {
                let loadURL = try RhwpStudioResourceLocator.loadURL(for: document)
                loadedIdentity = nextIdentity
                onError(nil)
                onLoadStateChange(true)
                activeLoadID += 1
                startLoadTimeout(activeLoadID, webView: webView)
                webView.load(URLRequest(url: loadURL))
            } catch {
                loadedIdentity = nil
                finishLoading()
                onError(error.localizedDescription)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            finishLoading()
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            handleNavigationError(error)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            finishLoading()
            onError("웹 viewer 프로세스가 종료되었습니다. 문서를 다시 열어 주세요.")
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            handleNavigationError(error)
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
                onError("허용되지 않은 rhwp-studio 탐색입니다: \(url.absoluteString)")
            }
        }

        private func handleNavigationError(_ error: Error) {
            finishLoading()
            guard !isIgnorableNavigationError(error) else {
                return
            }
            onError(error.localizedDescription)
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

                let loadingURL = webView?.url?.absoluteString ?? "unknown URL"
                self.finishLoading()
                self.onError("웹 viewer 로딩이 시간 초과되었습니다: \(loadingURL)")
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
                saveDocument(body)
            case "share-document":
                shareDocument(body)
            case "print-document":
                printDocument(body)
            case "export-pdf-document":
                exportPDFDocument(body)
            case "error":
                pendingSaveDestination = nil
                pendingPDFDestinationURL = nil
                onError(body["message"] as? String)
            default:
                break
            }
        }

        private func handleDroppedDocument(_ body: [String: Any]) {
            guard let fileName = body["fileName"] as? String,
                  Self.isSupportedDocumentFilename(fileName)
            else {
                onError("끌어놓은 문서를 열 수 없습니다: HWP/HWPX 파일만 지원합니다.")
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

        private func handleHostCommand(_ body: [String: Any]) {
            guard let command = body["command"] as? String else {
                return
            }

            switch command {
            case "file:open":
                onOpenDocument()
            case "file:save":
                guard let webView = commandWebView else {
                    onError("저장할 viewer를 찾을 수 없습니다.")
                    return
                }
                requestSaveDocument(
                    in: webView,
                    suggestedFilename: body["fileName"] as? String
                )
            case "file:save-as":
                guard let webView = commandWebView else {
                    onError("저장할 viewer를 찾을 수 없습니다.")
                    return
                }
                requestSaveAsDocument(
                    in: webView,
                    suggestedFilename: body["fileName"] as? String
                )
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

        private func saveDocument(_ body: [String: Any]) {
            let destination = pendingSaveDestination
            pendingSaveDestination = nil

            guard let payload = exportedDocumentPayload(
                from: body,
                missingMessage: "문서를 내보낼 수 없습니다"
            ) else {
                return
            }

            do {
                switch destination {
                case .some(.source(let sourceDocument)):
                    let savedURL = try writePayload(payload, to: sourceDocument)
                    recordSavedDocument(at: savedURL)
                case .some(.selected(let destinationURL)):
                    try DocumentSavePanel.write(data: payload.data, to: destinationURL)
                    recordSavedDocument(at: destinationURL)
                case .none:
                    try savePayloadWithPanel(payload)
                }
            } catch {
                switch destination {
                case .some(.source):
                    do {
                        try savePayloadWithPanel(payload)
                    } catch {
                        onError("문서를 저장할 수 없습니다: \(error.localizedDescription)")
                    }
                default:
                    onError("문서를 저장할 수 없습니다: \(error.localizedDescription)")
                }
            }
        }

        private func writePayload(
            _ payload: (data: Data, fileName: String),
            to sourceDocument: RecentDocumentItem
        ) throws -> URL {
            let url = try sourceDocument.resolvedURL()
            let didStartSecurityScope = url.startAccessingSecurityScopedResource()
            defer {
                if didStartSecurityScope {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            try DocumentSavePanel.write(data: payload.data, to: url)
            return url
        }

        private func savePayloadWithPanel(_ payload: (data: Data, fileName: String)) throws {
            if let savedURL = try DocumentSavePanel.save(
                data: payload.data,
                suggestedFilename: payload.fileName
            ) {
                recordSavedDocument(at: savedURL)
            }
        }

        private func recordSavedDocument(at url: URL) {
            currentSourceDocument = RecentDocumentItem.make(for: url)
            onDocumentSaved(url)
            showSaveCompletedStatus(for: url)
        }

        private func showSaveCompletedStatus(for url: URL) {
            guard let webView = commandWebView else {
                return
            }

            let timeText = Self.saveStatusTimeText()
            let script = """
            window.__alhangeulHostBridgeShowSaveCompletedStatus?.(
              \(Self.javaScriptStringLiteral(timeText)),
              \(Self.javaScriptStringLiteral(url.lastPathComponent))
            )
            """
            webView.evaluateJavaScript(script)
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
            guard let payload = printPayload(from: body, missingMessage: "인쇄 데이터를 만들 수 없습니다") else {
                return
            }

            let controller = RhwpStudioPrintController()
            printController = controller
            controller.print(
                payload: payload,
                completion: { [weak self] in
                    self?.printController = nil
                }
            )
        }

        private func exportPDFDocument(_ body: [String: Any]) {
            let destinationURL = pendingPDFDestinationURL
            pendingPDFDestinationURL = nil

            guard let payload = exportedDocumentPayload(
                from: body,
                missingMessage: "PDF 데이터를 만들 수 없습니다"
            ) else {
                return
            }

            let controller = RhwpStudioPDFExportController()
            pdfExportController = controller
            let completion: (Result<URL?, Error>) -> Void = { [weak self] result in
                guard let self else {
                    return
                }
                self.pdfExportController = nil
                switch result {
                case .success(let url):
                    if let url {
                        DocumentFileActions.revealInFinder(url)
                    }
                case .failure(let error):
                    self.onError("PDF를 내보낼 수 없습니다: \(error.localizedDescription)")
                }
            }

            if let destinationURL {
                controller.export(
                    data: payload.data,
                    filename: payload.fileName,
                    destinationURL: destinationURL,
                    completion: completion
                )
            } else {
                controller.export(
                    data: payload.data,
                    filename: payload.fileName,
                    completion: completion
                )
            }
        }

        private func printPayload(
            from body: [String: Any],
            missingMessage: String
        ) -> RhwpStudioPrintPayload? {
            guard let pageCount = intValue(body["pageCount"]),
                  let pages = body["pages"] as? [String],
                  pageCount > 0,
                  pages.count == pageCount
            else {
                onError("\(missingMessage): 페이지 데이터가 없습니다.")
                return nil
            }

            let fileName = body["fileName"] as? String
                ?? currentDocument?.filename
                ?? "document.hwp"
            return RhwpStudioPrintPayload(fileName: fileName, pages: pages)
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

        private func runNativeCommand(_ command: String, in webView: WKWebView) {
            let script: String
            switch command {
            case "file:open":
                script = "window.__alhangeulHostBridgeRunNativeCommand?.('file:open')"
            case "file:save":
                requestSaveDocument(in: webView)
                return
            case "file:save-as":
                requestSaveAsDocument(in: webView)
                return
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
            suggestedFilename: String? = nil
        ) {
            guard currentDocument != nil else {
                onError("저장할 문서가 없습니다.")
                return
            }

            guard !isChoosingSaveDestination,
                  pendingSaveDestination == nil
            else {
                return
            }

            guard let sourceDocument = currentSourceDocument,
                  canSaveInPlace(sourceDocument)
            else {
                requestSaveAsDocument(in: webView, suggestedFilename: suggestedFilename)
                return
            }

            pendingSaveDestination = .source(sourceDocument)
            evaluateHostBridgeAction(
                "window.__alhangeulHostBridgeExportHwpDocument?.('save-document')",
                in: webView,
                failureMessage: "문서를 내보낼 수 없습니다"
            ) { [weak self] in
                self?.pendingSaveDestination = nil
            }
        }

        private func requestSaveAsDocument(
            in webView: WKWebView,
            suggestedFilename: String? = nil
        ) {
            guard currentDocument != nil else {
                onError("저장할 문서가 없습니다.")
                return
            }

            guard !isChoosingSaveDestination,
                  pendingSaveDestination == nil
            else {
                return
            }

            let filename = suggestedFilename
                ?? currentSourceDocument?.displayName
                ?? currentDocument?.filename
                ?? "document.hwp"
            let presentingWindow = webView.window
            isChoosingSaveDestination = true

            Task { @MainActor [weak self, weak webView, weak presentingWindow] in
                guard let self else {
                    return
                }
                defer {
                    self.isChoosingSaveDestination = false
                }

                guard let webView else {
                    return
                }

                let destinationURL = await DocumentSavePanel.chooseDestinationURL(
                    suggestedFilename: filename,
                    presentingWindow: presentingWindow ?? webView.window
                )
                guard let destinationURL else {
                    return
                }

                self.pendingSaveDestination = .selected(destinationURL)
                self.evaluateHostBridgeAction(
                    "window.__alhangeulHostBridgeExportHwpDocument?.('save-document')",
                    in: webView,
                    failureMessage: "문서를 내보낼 수 없습니다"
                ) { [weak self] in
                    self?.pendingSaveDestination = nil
                }
            }
        }

        private func canSaveInPlace(_ sourceDocument: RecentDocumentItem) -> Bool {
            sourceDocument.url.pathExtension.lowercased() == "hwp"
        }

        private func requestPDFExport(
            in webView: WKWebView,
            suggestedFilename: String? = nil
        ) {
            guard !isChoosingPDFDestination,
                  pendingPDFDestinationURL == nil
            else {
                return
            }

            let filename = suggestedFilename ?? currentDocument?.filename ?? "document.hwp"
            let presentingWindow = webView.window
            isChoosingPDFDestination = true

            Task { @MainActor [weak self, weak webView, weak presentingWindow] in
                guard let self else {
                    return
                }
                defer {
                    self.isChoosingPDFDestination = false
                }

                guard let webView else {
                    return
                }

                let destinationURL = await DocumentPDFExportPanel.chooseDestinationURL(
                    suggestedFilename: filename,
                    presentingWindow: presentingWindow ?? webView.window
                )
                guard let destinationURL else {
                    return
                }

                self.pendingPDFDestinationURL = destinationURL
                self.evaluateHostBridgeAction(
                    "window.__alhangeulHostBridgeExportPDFDocument?.()",
                    in: webView,
                    failureMessage: "PDF 데이터를 만들 수 없습니다"
                ) { [weak self] in
                    self?.pendingPDFDestinationURL = nil
                }
            }
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

    @discardableResult
    func runNativeCommand(_ command: String) -> Bool {
        nativeCommandHandler?(command) ?? false
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

            if webView.runNativeCommand(command) {
                return true
            }
        }

        for webView in registeredWebViews.compactMap(\.webView) where webView.window?.isVisible == true {
            if webView.runNativeCommand(command) {
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
