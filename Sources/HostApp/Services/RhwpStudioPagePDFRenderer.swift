import AppKit
import PDFKit
import WebKit

@MainActor
final class RhwpStudioPagePDFRenderer: NSObject, WKNavigationDelegate {
    private let webView: WKWebView
    private var completion: ((Result<PDFDocument, Error>) -> Void)?
    private var payload: RhwpStudioPagePayload?
    private var renderedDocument = PDFDocument()
    private var renderingPageIndex = 0
    private var didFinish = true

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        if #available(macOS 11.0, *) {
            configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        }

        webView = WKWebView(
            frame: NSRect(origin: .zero, size: RhwpStudioPagePDFMetrics.initialPageSize),
            configuration: configuration
        )
        super.init()
        webView.navigationDelegate = self
    }

    func render(
        payload: RhwpStudioPagePayload,
        completion: @escaping (Result<PDFDocument, Error>) -> Void
    ) {
        guard self.completion == nil else {
            completion(.failure(RhwpStudioPagePDFRenderError.renderingInProgress))
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
        finish(.failure(error))
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        finish(.failure(error))
    }

    private func renderNextPage() {
        guard !didFinish, let payload else {
            return
        }

        guard renderingPageIndex < payload.pageCount else {
            guard renderedDocument.pageCount == payload.pageCount else {
                finish(.failure(
                    RhwpStudioPagePDFRenderError.finalPageCountMismatch(
                        expected: payload.pageCount,
                        actual: renderedDocument.pageCount
                    )
                ))
                return
            }
            finish(.success(renderedDocument))
            return
        }

        webView.frame = NSRect(
            origin: .zero,
            size: RhwpStudioPagePDFMetrics.initialPageSize
        )
        webView.loadHTMLString(
            RhwpStudioPagePDFHTML.pageHTML(for: payload.pages[renderingPageIndex]),
            baseURL: nil
        )
    }

    private func renderCurrentPagePDF() {
        guard !didFinish else {
            return
        }

        webView.evaluateJavaScript(RhwpStudioPagePDFHTML.pageMetricsScript) { [weak self] result, error in
            guard let self, !self.didFinish else {
                return
            }
            if let error {
                self.finish(.failure(error))
                return
            }

            let pageNumber = self.renderingPageIndex + 1
            let pageSize: NSSize
            do {
                pageSize = try RhwpStudioPagePDFMetrics.size(
                    fromMetrics: result,
                    pageNumber: pageNumber
                )
            } catch {
                self.finish(.failure(error))
                return
            }

            self.webView.frame = NSRect(origin: .zero, size: pageSize)
            self.webView.layoutSubtreeIfNeeded()

            let configuration = WKPDFConfiguration()
            configuration.rect = NSRect(origin: .zero, size: pageSize)
            self.webView.createPDF(configuration: configuration) { [weak self] result in
                guard let self, !self.didFinish else {
                    return
                }

                switch result {
                case .success(let data):
                    self.appendPDFPage(data)
                case .failure(let error):
                    self.finish(.failure(error))
                }
            }
        }
    }

    private func appendPDFPage(_ data: Data) {
        let pageNumber = renderingPageIndex + 1
        guard let pageDocument = PDFDocument(data: data) else {
            finish(.failure(RhwpStudioPagePDFRenderError.pdfEncodingFailed(pageNumber)))
            return
        }
        guard pageDocument.pageCount == 1 else {
            finish(.failure(
                RhwpStudioPagePDFRenderError.unexpectedPDFPageCount(
                    page: pageNumber,
                    actual: pageDocument.pageCount
                )
            ))
            return
        }
        guard let page = pageDocument.page(at: 0) else {
            finish(.failure(RhwpStudioPagePDFRenderError.pdfEncodingFailed(pageNumber)))
            return
        }

        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width.isFinite,
              bounds.height.isFinite,
              bounds.width > 0,
              bounds.height > 0
        else {
            finish(.failure(RhwpStudioPagePDFRenderError.invalidPDFPageBounds(pageNumber)))
            return
        }

        renderedDocument.insert(page, at: renderedDocument.pageCount)
        renderingPageIndex += 1
        renderNextPage()
    }

    private func finish(_ result: Result<PDFDocument, Error>) {
        guard !didFinish else {
            return
        }

        didFinish = true
        webView.stopLoading()
        let completion = completion
        self.completion = nil
        payload = nil
        renderedDocument = PDFDocument()
        renderingPageIndex = 0
        completion?(result)
    }
}

enum RhwpStudioPagePDFHTML {
    static let pageMetricsScript = """
    (() => {
      const svg = document.querySelector("svg");
      if (!svg) {
        return null;
      }
      const rect = svg?.getBoundingClientRect();
      const viewBox = svg.viewBox?.baseVal;
      const dimension = (name, rectValue, viewBoxValue) => {
        const attribute = svg.getAttribute(name)?.trim() || "";
        const resolved = svg[name]?.baseVal?.value;
        if (attribute && !attribute.endsWith("%") && Number.isFinite(resolved) && resolved > 0) {
          return resolved;
        }
        if (Number.isFinite(viewBoxValue) && viewBoxValue > 0) {
          return viewBoxValue;
        }
        return Number.isFinite(rectValue) && rectValue > 0 ? rectValue : 0;
      };
      const width = Math.ceil(dimension("width", rect?.width, viewBox?.width));
      const height = Math.ceil(dimension("height", rect?.height, viewBox?.height));
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

enum RhwpStudioPagePDFMetrics {
    static let initialPageSize = NSSize(width: 794, height: 1123)

    static func size(fromMetrics value: Any?, pageNumber: Int) throws -> NSSize {
        guard let dictionary = value as? [String: Any],
              let width = number(dictionary["width"]),
              let height = number(dictionary["height"]),
              width.isFinite,
              height.isFinite,
              width > 0,
              height > 0
        else {
            throw RhwpStudioPagePDFRenderError.invalidPageMetrics(pageNumber)
        }

        return NSSize(width: width, height: height)
    }

    private static func number(_ value: Any?) -> CGFloat? {
        switch value {
        case let number as NSNumber:
            CGFloat(truncating: number)
        case let double as Double:
            CGFloat(double)
        case let int as Int:
            CGFloat(int)
        default:
            nil
        }
    }
}

enum RhwpStudioPagePDFRenderError: LocalizedError {
    case renderingInProgress
    case invalidPageMetrics(Int)
    case pdfEncodingFailed(Int)
    case unexpectedPDFPageCount(page: Int, actual: Int)
    case invalidPDFPageBounds(Int)
    case finalPageCountMismatch(expected: Int, actual: Int)

    var errorDescription: String? {
        switch self {
        case .renderingInProgress:
            "PDF 페이지 변환이 이미 진행 중입니다."
        case .invalidPageMetrics(let page):
            "\(page)페이지 크기를 확인할 수 없습니다."
        case .pdfEncodingFailed(let page):
            "\(page)페이지를 PDF로 변환할 수 없습니다."
        case .unexpectedPDFPageCount(let page, let actual):
            "\(page)페이지 PDF 결과가 한 페이지가 아닙니다: actual=\(actual)"
        case .invalidPDFPageBounds(let page):
            "\(page)페이지 PDF 크기가 올바르지 않습니다."
        case .finalPageCountMismatch(let expected, let actual):
            "PDF 페이지 수가 일치하지 않습니다: expected=\(expected), actual=\(actual)"
        }
    }
}
