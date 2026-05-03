import AppKit
import PDFKit
import WebKit

struct RhwpStudioPrintPayload {
    let fileName: String
    let pages: [String]
}

final class RhwpStudioPrintController: NSObject, WKNavigationDelegate {
    private let webView: WKWebView
    private var completion: (() -> Void)?
    private var payload: RhwpStudioPrintPayload?
    private var renderedDocument = PDFDocument()
    private var renderingPageIndex = 0
    private var printOperation: NSPrintOperation?
    private var didFinish = false

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        if #available(macOS 11.0, *) {
            configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        }

        webView = WKWebView(
            frame: NSRect(origin: .zero, size: RhwpStudioPrintPageSize.defaultPageSize),
            configuration: configuration
        )
        super.init()
        webView.navigationDelegate = self
    }

    @MainActor
    func print(payload: RhwpStudioPrintPayload, completion: @escaping () -> Void) {
        guard !payload.pages.isEmpty else {
            RhwpStudioPrintErrorPresenter.present(RhwpStudioPrintError.emptyDocument)
            completion()
            return
        }

        self.completion = completion
        self.payload = payload
        renderedDocument = PDFDocument()
        renderingPageIndex = 0
        didFinish = false
        renderNextPage()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        renderCurrentPagePDF()
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        finish(error: error)
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        finish(error: error)
    }

    private func renderNextPage() {
        guard let payload else {
            finish(error: RhwpStudioPrintError.emptyDocument)
            return
        }

        guard renderingPageIndex < payload.pages.count else {
            runPrintOperation(fileName: payload.fileName)
            return
        }

        webView.frame = NSRect(origin: .zero, size: RhwpStudioPrintPageSize.defaultPageSize)
        webView.loadHTMLString(
            RhwpStudioPrintHTML.pageHTML(for: payload.pages[renderingPageIndex]),
            baseURL: nil
        )
    }

    private func renderCurrentPagePDF() {
        webView.evaluateJavaScript(RhwpStudioPrintHTML.pageMetricsScript) { [weak self] result, error in
            guard let self else {
                return
            }
            if let error {
                self.finish(error: error)
                return
            }

            let pageSize = RhwpStudioPrintPageSize.size(fromMetrics: result)
            self.webView.frame = NSRect(origin: .zero, size: pageSize)

            let configuration = WKPDFConfiguration()
            configuration.rect = NSRect(origin: .zero, size: pageSize)
            self.webView.createPDF(configuration: configuration) { [weak self] result in
                guard let self else {
                    return
                }

                switch result {
                case .success(let data):
                    self.appendPDFPage(data)
                case .failure(let error):
                    self.finish(error: error)
                }
            }
        }
    }

    private func appendPDFPage(_ data: Data) {
        guard let pageDocument = PDFDocument(data: data),
              pageDocument.pageCount > 0
        else {
            finish(error: RhwpStudioPrintError.pdfEncodingFailed(renderingPageIndex + 1))
            return
        }

        for index in 0..<pageDocument.pageCount {
            guard let page = pageDocument.page(at: index) else {
                continue
            }
            renderedDocument.insert(page, at: renderedDocument.pageCount)
        }

        renderingPageIndex += 1
        renderNextPage()
    }

    private func runPrintOperation(fileName: String) {
        guard renderedDocument.pageCount > 0 else {
            finish(error: RhwpStudioPrintError.emptyDocument)
            return
        }

        let printInfo = NSPrintInfo.shared.copy() as? NSPrintInfo ?? NSPrintInfo()
        printInfo.jobDisposition = .spool
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .fit

        guard let operation = renderedDocument.printOperation(
            for: printInfo,
            scalingMode: .pageScaleDownToFit,
            autoRotate: true
        ) else {
            finish(error: RhwpStudioPrintError.printOperationUnavailable)
            return
        }

        operation.jobTitle = fileName
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        printOperation = operation
        operation.run()
        printOperation = nil
        finish(error: nil)
    }

    private func finish(error: Error?) {
        guard !didFinish else {
            return
        }

        didFinish = true
        webView.stopLoading()
        webView.navigationDelegate = nil
        if let error {
            RhwpStudioPrintErrorPresenter.present(error)
        }
        let completion = completion
        self.completion = nil
        payload = nil
        printOperation = nil
        completion?()
    }
}

enum RhwpStudioPrintHTML {
    static let pageMetricsScript = """
    (() => {
      const svg = document.querySelector("svg");
      const rect = svg?.getBoundingClientRect();
      const width = Math.ceil(Math.max(
        rect?.width || 0,
        document.documentElement.scrollWidth,
        document.body?.scrollWidth || 0
      ));
      const height = Math.ceil(Math.max(
        rect?.height || 0,
        document.documentElement.scrollHeight,
        document.body?.scrollHeight || 0
      ));
      return { width, height };
    })()
    """

    static func pageHTML(for svg: String) -> String {
        """
        <!doctype html>
        <html lang="ko">
        <head>
          <meta charset="utf-8">
          <style>
            * { box-sizing: border-box; }
            html, body {
              margin: 0;
              padding: 0;
              background: #fff;
              overflow: hidden;
            }
            svg {
              display: block;
            }
          </style>
        </head>
        <body>
        \(svg)
        </body>
        </html>
        """
    }
}

enum RhwpStudioPrintPageSize {
    static let defaultPageSize = NSSize(width: 794, height: 1123)

    static func size(fromMetrics value: Any?) -> NSSize {
        guard let dictionary = value as? [String: Any] else {
            return defaultPageSize
        }

        let width = number(dictionary["width"]) ?? defaultPageSize.width
        let height = number(dictionary["height"]) ?? defaultPageSize.height
        return NSSize(width: max(width, 1), height: max(height, 1))
    }

    private static func number(_ value: Any?) -> CGFloat? {
        switch value {
        case let number as NSNumber:
            return CGFloat(truncating: number)
        case let double as Double:
            return CGFloat(double)
        case let int as Int:
            return CGFloat(int)
        default:
            return nil
        }
    }
}

enum RhwpStudioPrintError: LocalizedError {
    case emptyDocument
    case pdfEncodingFailed(Int)
    case printOperationUnavailable

    var errorDescription: String? {
        switch self {
        case .emptyDocument:
            "인쇄할 페이지가 없습니다."
        case .pdfEncodingFailed(let page):
            "\(page)페이지 인쇄 데이터를 PDF로 변환할 수 없습니다."
        case .printOperationUnavailable:
            "PDF 인쇄 작업을 만들 수 없습니다."
        }
    }
}

enum RhwpStudioPrintErrorPresenter {
    @MainActor
    static func present(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "인쇄할 수 없습니다."
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "확인")
        alert.runModal()
    }
}
