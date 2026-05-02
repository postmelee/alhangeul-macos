import SwiftUI
import WebKit

struct RhwpStudioWebView: NSViewRepresentable {
    let document: RhwpStudioDocumentPayload?
    let onLoadStateChange: (Bool) -> Void
    let onError: (String?) -> Void

    init(
        document: RhwpStudioDocumentPayload?,
        onLoadStateChange: @escaping (Bool) -> Void = { _ in },
        onError: @escaping (String?) -> Void = { _ in }
    ) {
        self.document = document
        self.onLoadStateChange = onLoadStateChange
        self.onError = onError
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
        context.coordinator.update(document: document, in: webView)
    }
}

extension RhwpStudioWebView {
    final class Coordinator: NSObject, WKNavigationDelegate {
        var onLoadStateChange: (Bool) -> Void = { _ in }
        var onError: (String?) -> Void = { _ in }

        private enum LoadIdentity: Equatable {
            case empty
            case document(Int)
        }

        private let documentProvider = RhwpStudioDocumentProvider()
        private lazy var documentSchemeHandler = RhwpStudioDocumentSchemeHandler(
            documentProvider: documentProvider
        )
        private var loadedIdentity: LoadIdentity?

        func makeWebView() -> WKWebView {
            let configuration = WKWebViewConfiguration()
            configuration.setURLSchemeHandler(
                documentSchemeHandler,
                forURLScheme: RhwpStudioDocumentRoute.scheme
            )
            configuration.preferences.javaScriptCanOpenWindowsAutomatically = false

            if #available(macOS 11.0, *) {
                configuration.defaultWebpagePreferences.allowsContentJavaScript = true
            }

            let webView = WKWebView(frame: .zero, configuration: configuration)
            webView.navigationDelegate = self
            webView.allowsBackForwardNavigationGestures = false
            return webView
        }

        func update(document: RhwpStudioDocumentPayload?, in webView: WKWebView) {
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
                let readAccessURL = try RhwpStudioResourceLocator.resourceDirectoryURL()
                loadedIdentity = nextIdentity
                onError(nil)
                onLoadStateChange(true)
                webView.loadFileURL(loadURL, allowingReadAccessTo: readAccessURL)
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
            onError(error.localizedDescription)
        }

        private func isAllowedNavigation(to url: URL) -> Bool {
            switch url.scheme?.lowercased() {
            case "file":
                return RhwpStudioResourceLocator.isBundledResourceURL(url)
            case "about", "blob", "data":
                return true
            case RhwpStudioDocumentRoute.scheme:
                return RhwpStudioDocumentRoute.isCurrentDocumentURL(url)
            default:
                return false
            }
        }
    }
}
