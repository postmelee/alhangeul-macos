import AppKit
import WebKit

struct RhwpStudioPrintPayload {
    let fileName: String
    let pages: [String]
}

final class RhwpStudioPrintController: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var completion: (() -> Void)?

    @MainActor
    func print(payload: RhwpStudioPrintPayload, completion: @escaping () -> Void) {
        self.completion = completion

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 1100))
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadHTMLString(RhwpStudioPrintHTML.documentHTML(for: payload), baseURL: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let printInfo = NSPrintInfo.shared.copy() as? NSPrintInfo ?? NSPrintInfo()
        printInfo.jobDisposition = .spool
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic

        let operation = webView.printOperation(with: printInfo)
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        operation.run()

        finish()
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        finish()
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        finish()
    }

    private func finish() {
        webView?.navigationDelegate = nil
        webView = nil
        completion?()
        completion = nil
    }
}

enum RhwpStudioPrintHTML {
    static func documentHTML(for payload: RhwpStudioPrintPayload) -> String {
        let escapedTitle = escapeHTML(payload.fileName)
        let pages = payload.pages.map { svg in
            "<section class=\"page\">\(svg)</section>"
        }.joined(separator: "\n")

        return """
        <!doctype html>
        <html lang="ko">
        <head>
          <meta charset="utf-8">
          <title>\(escapedTitle)</title>
          <style>
            * { box-sizing: border-box; }
            html, body { margin: 0; padding: 0; background: #fff; }
            .page {
              page-break-after: always;
              break-after: page;
              width: 100%;
              overflow: hidden;
            }
            .page:last-child {
              page-break-after: auto;
              break-after: auto;
            }
            .page svg {
              display: block;
              width: 100%;
              height: auto;
            }
          </style>
        </head>
        <body>
        \(pages)
        </body>
        </html>
        """
    }

    private static func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
