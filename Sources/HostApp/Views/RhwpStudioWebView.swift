import AppKit
import SwiftUI
import WebKit

struct RhwpStudioWebView: NSViewRepresentable {
    let document: RhwpStudioDocumentPayload?
    let onLoadStateChange: (Bool) -> Void
    let onError: (String?) -> Void
    let onOpenDocument: () -> Void

    init(
        document: RhwpStudioDocumentPayload?,
        onLoadStateChange: @escaping (Bool) -> Void = { _ in },
        onError: @escaping (String?) -> Void = { _ in },
        onOpenDocument: @escaping () -> Void = {}
    ) {
        self.document = document
        self.onLoadStateChange = onLoadStateChange
        self.onError = onError
        self.onOpenDocument = onOpenDocument
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
        context.coordinator.update(document: document, in: webView)
    }
}

extension RhwpStudioWebView {
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var onLoadStateChange: (Bool) -> Void = { _ in }
        var onError: (String?) -> Void = { _ in }
        var onOpenDocument: () -> Void = {}

        private enum LoadIdentity: Equatable {
            case empty
            case document(Int)
        }

        private let documentProvider = RhwpStudioDocumentProvider()
        private let resourceSchemeHandler = RhwpStudioResourceSchemeHandler()
        private lazy var documentSchemeHandler = RhwpStudioDocumentSchemeHandler(
            documentProvider: documentProvider
        )
        private var loadedIdentity: LoadIdentity?
        private var currentDocument: RhwpStudioDocumentPayload?
        private var printController: RhwpStudioPrintController?

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
            webView.nativeCommandHandler = { [weak self, weak webView] command in
                guard let self, let webView else {
                    return false
                }
                self.runNativeCommand(command, in: webView)
                return true
            }
            webView.navigationDelegate = self
            webView.allowsBackForwardNavigationGestures = false
            return webView
        }

        func update(document: RhwpStudioDocumentPayload?, in webView: WKWebView) {
            currentDocument = document
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
                webView.load(URLRequest(url: loadURL))
            } catch {
                loadedIdentity = nil
                onLoadStateChange(false)
                onError(error.localizedDescription)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onLoadStateChange(false)
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            handleNavigationError(error)
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
            onLoadStateChange(false)
            guard !isIgnorableNavigationError(error) else {
                return
            }
            onError(error.localizedDescription)
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
            case "save-document":
                saveDocument(body)
            case "print-document":
                printDocument(body)
            case "error":
                onError(body["message"] as? String)
            default:
                break
            }
        }

        private func handleHostCommand(_ body: [String: Any]) {
            guard let command = body["command"] as? String else {
                return
            }

            switch command {
            case "file:open":
                onOpenDocument()
            default:
                break
            }
        }

        private func saveDocument(_ body: [String: Any]) {
            guard let values = body["bytes"] as? [NSNumber] else {
                onError("문서를 내보낼 수 없습니다: 저장 bytes가 없습니다.")
                return
            }

            let data = Data(values.map { UInt8(truncating: $0) })
            let suggestedFilename = body["fileName"] as? String
                ?? currentDocument?.filename
                ?? "document.hwp"

            do {
                _ = try DocumentSavePanel.save(data: data, suggestedFilename: suggestedFilename)
            } catch {
                onError("문서를 저장할 수 없습니다: \(error.localizedDescription)")
            }
        }

        private func printDocument(_ body: [String: Any]) {
            guard let pageCount = intValue(body["pageCount"]),
                  let pages = body["pages"] as? [String],
                  pageCount > 0,
                  pages.count == pageCount
            else {
                onError("인쇄 데이터를 만들 수 없습니다: 페이지 데이터가 없습니다.")
                return
            }

            let fileName = body["fileName"] as? String
                ?? currentDocument?.filename
                ?? "document.hwp"
            let controller = RhwpStudioPrintController()
            printController = controller
            controller.print(
                payload: RhwpStudioPrintPayload(fileName: fileName, pages: pages),
                completion: { [weak self] in
                    self?.printController = nil
                }
            )
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

        private func runNativeCommand(_ command: String, in webView: WKWebView) {
            let script: String
            switch command {
            case "file:open":
                script = "window.__alhangeulHostBridgeRunNativeCommand?.('file:open')"
            case "file:save":
                script = "window.__alhangeulHostBridgeRunNativeCommand?.('file:save')"
            case "file:print":
                script = "window.__alhangeulHostBridgeRunNativeCommand?.('file:print')"
            default:
                return
            }
            webView.evaluateJavaScript(script) { [weak self] _, error in
                if let error {
                    self?.onError("단축키 명령을 실행할 수 없습니다: \(error.localizedDescription)")
                }
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
        guard hasCommandModifier,
              !flags.contains(.option),
              !flags.contains(.shift)
        else {
            return nil
        }

        switch event.keyCode {
        case 31:
            return "file:open"
        case 1:
            return "file:save"
        case 35:
            return "file:print"
        default:
            return nil
        }
    }
}

@MainActor
enum RhwpStudioNativeCommandDispatcher {
    @discardableResult
    static func run(_ command: String) -> Bool {
        var seenWindowIDs = Set<ObjectIdentifier>()
        let candidateWindows = [NSApp.keyWindow, NSApp.mainWindow].compactMap { $0 } + NSApp.windows

        for window in candidateWindows {
            let windowID = ObjectIdentifier(window)
            guard !seenWindowIDs.contains(windowID) else {
                continue
            }
            seenWindowIDs.insert(windowID)

            guard let webView = window.contentView?.firstDescendant(
                ofType: RhwpStudioNativeCommandWebView.self
            ) else {
                continue
            }

            if webView.runNativeCommand(command) {
                return true
            }
        }

        return false
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
