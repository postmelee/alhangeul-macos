import AppKit
import PDFKit
import WebKit

@MainActor
final class RhwpStudioPagePDFRenderer: NSObject, WKNavigationDelegate {
    private let webView: WKWebView
    private let pdfFontSchemeHandler: RhwpStudioPDFFontSchemeHandler
    private let pageRenderTimeoutNanoseconds: UInt64
    private var completion: ((Result<PDFDocument, Error>) -> Void)?
    private var payload: RhwpStudioPagePayload?
    private var renderedDocument = PDFDocument()
    private var renderingPageIndex = 0
    private var didFinish = true
    private var isInitialMainFrameLoadPending = false
    private var pageRenderTimeoutTask: Task<Void, Never>?

    init(
        pageRenderTimeoutNanoseconds: UInt64 = 30_000_000_000,
        fontResourceProvider: RhwpStudioPDFFontResourceProviding =
            RhwpStudioPDFFontBundleResourceProvider()
    ) {
        self.pageRenderTimeoutNanoseconds = pageRenderTimeoutNanoseconds
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let pdfFontSchemeHandler = RhwpStudioPDFFontSchemeHandler(
            resourceProvider: fontResourceProvider
        )
        configuration.setURLSchemeHandler(
            pdfFontSchemeHandler,
            forURLScheme: RhwpStudioPDFFontRoute.scheme
        )
        self.pdfFontSchemeHandler = pdfFontSchemeHandler

        webView = WKWebView(
            frame: NSRect(origin: .zero, size: RhwpStudioPagePDFMetrics.initialPageSize),
            configuration: configuration
        )
        super.init()
        webView.navigationDelegate = self
    }

    deinit {
        pageRenderTimeoutTask?.cancel()
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
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        let shouldAllow = RhwpStudioPagePDFNavigationPolicy.allowsNavigation(
            to: navigationAction.request.url,
            targetFrameIsMainFrame: navigationAction.targetFrame?.isMainFrame,
            initialMainFrameLoadPending: isInitialMainFrameLoadPending
        )
        if shouldAllow {
            isInitialMainFrameLoadPending = false
            decisionHandler(.allow)
        } else {
            decisionHandler(.cancel)
        }
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

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        finish(.failure(RhwpStudioPagePDFRenderError.webContentProcessTerminated))
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
        startPageRenderTimeout(pageNumber: renderingPageIndex + 1)
        isInitialMainFrameLoadPending = true
        webView.loadHTMLString(
            RhwpStudioPagePDFHTML.pageHTML(for: payload.pages[renderingPageIndex]),
            baseURL: nil
        )
    }

    private func renderCurrentPagePDF() {
        guard !didFinish else {
            return
        }

        webView.callAsyncJavaScript(
            RhwpStudioPagePDFHTML.pagePreparationScript,
            arguments: [:],
            in: nil,
            in: .defaultClient
        ) { [weak self] result in
            guard let self, !self.didFinish else {
                return
            }

            let preparation: Any?
            switch result {
            case .success(let value):
                preparation = value
            case .failure(let error):
                self.finish(.failure(
                    RhwpStudioPagePDFRenderError.fontPreparationFailed(
                        page: self.renderingPageIndex + 1,
                        reason: error.localizedDescription
                    )
                ))
                return
            }

            let pageNumber = self.renderingPageIndex + 1
            let pageSize: NSSize
            do {
                pageSize = try RhwpStudioPagePDFPreparation.pageSize(
                    from: preparation,
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

    private func startPageRenderTimeout(pageNumber: Int) {
        pageRenderTimeoutTask?.cancel()
        let expectedPageIndex = renderingPageIndex
        let timeoutNanoseconds = pageRenderTimeoutNanoseconds
        pageRenderTimeoutTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
            } catch {
                return
            }

            guard !Task.isCancelled,
                  let self,
                  !self.didFinish,
                  self.renderingPageIndex == expectedPageIndex
            else {
                return
            }

            self.finish(.failure(
                RhwpStudioPagePDFRenderError.pageRenderTimedOut(pageNumber)
            ))
        }
    }

    private func finish(_ result: Result<PDFDocument, Error>) {
        guard !didFinish else {
            return
        }

        didFinish = true
        pageRenderTimeoutTask?.cancel()
        pageRenderTimeoutTask = nil
        webView.stopLoading()
        let completion = completion
        self.completion = nil
        payload = nil
        renderedDocument = PDFDocument()
        renderingPageIndex = 0
        isInitialMainFrameLoadPending = false
        completion?(result)
    }
}

enum RhwpStudioPagePDFNavigationPolicy {
    static func allowsNavigation(
        to url: URL?,
        targetFrameIsMainFrame: Bool?,
        initialMainFrameLoadPending: Bool
    ) -> Bool {
        guard initialMainFrameLoadPending,
              targetFrameIsMainFrame == true,
              url?.absoluteString.lowercased() == "about:blank"
        else {
            return false
        }

        return true
    }
}

enum RhwpStudioPagePDFHTML {
    static let contentSecurityPolicy = [
        "default-src 'none'",
        "script-src 'none'",
        "connect-src 'none'",
        "frame-src 'none'",
        "object-src 'none'",
        "media-src 'none'",
        "worker-src 'none'",
        "manifest-src 'none'",
        "base-uri 'none'",
        "form-action 'none'",
        "style-src 'unsafe-inline'",
        "img-src data:",
        "font-src \(RhwpStudioPDFFontRoute.scheme):"
    ].joined(separator: "; ") + ";"

    static let pagePreparationScript = #"""
    await document.fonts.ready;
    const ownedFamilies = \#(RhwpStudioPDFFontStyle.ownedFamilyNamesJSON);
    const hangulPattern = /[\u1100-\u11ff\u3130-\u318f\ua960-\ua97f\uac00-\ud7af\ud7b0-\ud7ff]/;
    const normalizeFamily = value => value.trim().replace(/^['"]|['"]$/g, "");
    const ownedFallbackFamily = families => {
      const normalized = families.map(family => family.toLowerCase());
      if (normalized.includes("serif")) {
        return "Noto Serif KR";
      }
      if (normalized.includes("sans-serif")) {
        return "Noto Sans KR";
      }
      return null;
    };
    const requiredFaces = new Map();
    const unmappedHangulFamilies = new Set();
    for (const textNode of document.querySelectorAll("svg text")) {
      const sample = (textNode.textContent || "").match(hangulPattern)?.[0];
      if (!sample) {
        continue;
      }
      let style = getComputedStyle(textNode);
      let families = style.fontFamily.split(",").map(normalizeFamily);
      let family = families.find(candidate => ownedFamilies.includes(candidate));
      if (!family) {
        const fallbackFamily = ownedFallbackFamily(families);
        if (!fallbackFamily) {
          unmappedHangulFamilies.add(style.fontFamily || "(empty)");
          continue;
        }
        textNode.style.setProperty(
          "font-family",
          `"${fallbackFamily}", ${style.fontFamily}`,
          "important"
        );
        style = getComputedStyle(textNode);
        families = style.fontFamily.split(",").map(normalizeFamily);
        family = families.find(candidate => ownedFamilies.includes(candidate));
      }
      if (!family) {
        unmappedHangulFamilies.add(style.fontFamily || "(empty)");
        continue;
      }
      const numericWeight = Number.parseInt(style.fontWeight, 10);
      const isBold = style.fontWeight === "bold"
        || (Number.isFinite(numericWeight) && numericWeight >= 500);
      requiredFaces.set(`${family}|${isBold ? "bold" : "regular"}`, {
        family,
        isBold,
        sample
      });
    }

    await Promise.all(Array.from(requiredFaces.values()).map(required => {
      const cssWeight = required.isBold ? 700 : 400;
      const escapedFamily = required.family.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
      return document.fonts.load(
        `${cssWeight} 12px "${escapedFamily}"`,
        required.sample
      ).catch(() => []);
    }));
    await document.fonts.ready;

    const loadedFaces = Array.from(document.fonts).filter(face => face.status === "loaded");
    const faceIsBold = face => {
      const weights = (face.weight || "").match(/\d+/g)?.map(Number) || [];
      return weights.length > 0 && weights[0] >= 500;
    };
    const unresolvedFaces = Array.from(requiredFaces.values()).filter(required => {
      const hasLoadedFace = loadedFaces.some(face =>
        normalizeFamily(face.family) === required.family
          && faceIsBold(face) === required.isBold
      );
      const cssWeight = required.isBold ? 700 : 400;
      const escapedFamily = required.family.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
      return !hasLoadedFace
        || !document.fonts.check(`${cssWeight} 12px "${escapedFamily}"`, required.sample);
    });

    let fontFailureReason = null;
    if (document.fonts.status !== "loaded") {
      fontFailureReason = `document.fonts.status=${document.fonts.status}`;
    } else if (unmappedHangulFamilies.size > 0) {
      fontFailureReason = `unmapped Hangul families: ${Array.from(unmappedHangulFamilies).join(", ")}`;
    } else if (unresolvedFaces.length > 0) {
      fontFailureReason = `unresolved PDF fonts: ${unresolvedFaces
        .map(face => `${face.family}/${face.isBold ? "bold" : "regular"}`)
        .join(", ")}`;
    }

      const svg = document.querySelector("svg");
      const rect = svg?.getBoundingClientRect();
      const viewBox = svg?.viewBox?.baseVal;
      const dimension = (name, rectValue, viewBoxValue) => {
        const attribute = svg?.getAttribute(name)?.trim() || "";
        const resolved = svg?.[name]?.baseVal?.value;
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
    return JSON.stringify({ width, height, fontFailureReason });
    """#

    static func pageHTML(for svg: String) -> String {
        """
        <!doctype html>
        <html lang="ko">
        <head>
          <meta charset="utf-8">
          <meta http-equiv="Content-Security-Policy" content="\(contentSecurityPolicy)">
          <style>
            \(RhwpStudioPDFFontStyle.fontFaceCSS)
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

enum RhwpStudioPagePDFPreparation {
    static func pageSize(from value: Any?, pageNumber: Int) throws -> NSSize {
        guard let json = value as? String,
              let data = json.data(using: .utf8),
              let dictionary = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else {
            throw RhwpStudioPagePDFRenderError.fontPreparationFailed(
                page: pageNumber,
                reason: "글꼴 준비 결과를 해석할 수 없습니다."
            )
        }

        if let reason = dictionary["fontFailureReason"] as? String,
           !reason.isEmpty {
            throw RhwpStudioPagePDFRenderError.fontPreparationFailed(
                page: pageNumber,
                reason: reason
            )
        }

        return try RhwpStudioPagePDFMetrics.size(
            fromMetrics: dictionary,
            pageNumber: pageNumber
        )
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

enum RhwpStudioPagePDFRenderError: LocalizedError, Equatable {
    case renderingInProgress
    case pageRenderTimedOut(Int)
    case webContentProcessTerminated
    case fontPreparationFailed(page: Int, reason: String)
    case invalidPageMetrics(Int)
    case pdfEncodingFailed(Int)
    case unexpectedPDFPageCount(page: Int, actual: Int)
    case invalidPDFPageBounds(Int)
    case finalPageCountMismatch(expected: Int, actual: Int)

    var errorDescription: String? {
        switch self {
        case .renderingInProgress:
            "PDF 페이지 변환이 이미 진행 중입니다."
        case .pageRenderTimedOut(let page):
            "\(page)페이지 PDF 변환 시간이 초과됐습니다."
        case .webContentProcessTerminated:
            "PDF 페이지 변환 중 WebKit 프로세스가 종료됐습니다."
        case .fontPreparationFailed(let page, let reason):
            "\(page)페이지 PDF 글꼴을 준비할 수 없습니다: \(reason)"
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
