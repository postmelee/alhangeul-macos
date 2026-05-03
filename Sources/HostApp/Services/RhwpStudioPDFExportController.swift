import AppKit
import WebKit

final class RhwpStudioPDFExportController: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var destinationURL: URL?
    private var completion: ((Result<URL?, Error>) -> Void)?

    @MainActor
    func export(
        payload: RhwpStudioPrintPayload,
        completion: @escaping (Result<URL?, Error>) -> Void
    ) {
        guard let destinationURL = DocumentPDFExportPanel.chooseDestinationURL(
            suggestedFilename: payload.fileName
        ) else {
            completion(.success(nil))
            return
        }

        self.destinationURL = destinationURL
        self.completion = completion

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 1100))
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadHTMLString(RhwpStudioPrintHTML.documentHTML(for: payload), baseURL: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let destinationURL else {
            finish(.failure(RhwpStudioPDFExportError.missingDestination))
            return
        }

        let printInfo = NSPrintInfo.shared.copy() as? NSPrintInfo ?? NSPrintInfo()
        printInfo.jobDisposition = .save
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = destinationURL

        let operation = webView.printOperation(with: printInfo)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = true

        guard operation.run() else {
            finish(.failure(RhwpStudioPDFExportError.exportFailed))
            return
        }

        finish(.success(destinationURL))
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        finish(.failure(error))
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        finish(.failure(error))
    }

    private func finish(_ result: Result<URL?, Error>) {
        webView?.navigationDelegate = nil
        webView = nil
        destinationURL = nil
        completion?(result)
        completion = nil
    }
}

private enum RhwpStudioPDFExportError: LocalizedError {
    case missingDestination
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .missingDestination:
            return "PDF 저장 위치를 찾을 수 없습니다."
        case .exportFailed:
            return "PDF를 저장할 수 없습니다."
        }
    }
}
