import AppKit
import PDFKit
import WebKit

struct RhwpStudioPagePDFRenderToken: Equatable {
    let generation: UInt64
    let pageIndex: Int
}

struct RhwpStudioPagePDFRenderLifecycle {
    private(set) var latestGeneration: UInt64 = 0
    private(set) var activeGeneration: UInt64?
    private(set) var currentPageToken: RhwpStudioPagePDFRenderToken?
    private(set) var currentNavigationIdentity: ObjectIdentifier?
    private(set) var isInitialMainFrameLoadPending = false

    var isActive: Bool {
        activeGeneration != nil
    }

    mutating func beginRender() -> UInt64? {
        guard activeGeneration == nil else {
            return nil
        }

        latestGeneration += 1
        activeGeneration = latestGeneration
        currentPageToken = nil
        currentNavigationIdentity = nil
        isInitialMainFrameLoadPending = false
        return latestGeneration
    }

    mutating func beginPage(at pageIndex: Int) -> RhwpStudioPagePDFRenderToken? {
        guard pageIndex >= 0, let activeGeneration else {
            return nil
        }

        let token = RhwpStudioPagePDFRenderToken(
            generation: activeGeneration,
            pageIndex: pageIndex
        )
        currentPageToken = token
        currentNavigationIdentity = nil
        isInitialMainFrameLoadPending = true
        return token
    }

    mutating func registerNavigation(
        _ navigationIdentity: ObjectIdentifier,
        for token: RhwpStudioPagePDFRenderToken
    ) -> Bool {
        guard isCurrent(token) else {
            return false
        }

        currentNavigationIdentity = navigationIdentity
        return true
    }

    func token(
        forNavigation navigationIdentity: ObjectIdentifier
    ) -> RhwpStudioPagePDFRenderToken? {
        guard currentNavigationIdentity == navigationIdentity else {
            return nil
        }
        return currentPageToken
    }

    func isCurrent(_ token: RhwpStudioPagePDFRenderToken) -> Bool {
        currentPageToken == token && activeGeneration == token.generation
    }

    mutating func consumeInitialMainFrameLoad() -> Bool {
        guard currentPageToken != nil, isInitialMainFrameLoadPending else {
            return false
        }

        isInitialMainFrameLoadPending = false
        return true
    }

    mutating func invalidate(_ token: RhwpStudioPagePDFRenderToken) -> Bool {
        guard isCurrent(token) else {
            return false
        }

        activeGeneration = nil
        currentPageToken = nil
        currentNavigationIdentity = nil
        isInitialMainFrameLoadPending = false
        return true
    }
}

struct RhwpStudioPagePDFWebKitOperations {
    let preparePage: @MainActor (
        WKWebView,
        @escaping @MainActor @Sendable (Result<Any, Error>) -> Void
    ) -> Void
    let createPDF: @MainActor (
        WKWebView,
        WKPDFConfiguration,
        @escaping @MainActor @Sendable (Result<Data, Error>) -> Void
    ) -> Void
    let cancelPreparation: @MainActor () -> Void

    init(preparePage: @escaping @MainActor (WKWebView, @escaping @MainActor @Sendable (Result<Any, Error>) -> Void) -> Void,
         createPDF: @escaping @MainActor (WKWebView, WKPDFConfiguration, @escaping @MainActor @Sendable (Result<Data, Error>) -> Void) -> Void,
         cancelPreparation: @escaping @MainActor () -> Void = {}) {
        self.preparePage = preparePage; self.createPDF = createPDF; self.cancelPreparation = cancelPreparation
    }

    @MainActor
    static func live(outputFonts: RhwpStudioOutputFontJob? = nil) -> Self {
        let preparation = RhwpStudioOutputFontPreparation(fonts: outputFonts)
        return Self(
            preparePage: { webView, completion in
                preparation.prepare(webView, completion: completion)
            },
            createPDF: { webView, configuration, completion in
                webView.createPDF(
                    configuration: configuration,
                    completionHandler: completion
                )
            }, cancelPreparation: { preparation.cancel() }
        )
    }
}

@MainActor
final class RhwpStudioPagePDFRenderer: NSObject, WKNavigationDelegate {
    private let webView: WKWebView
    private let pdfFontSchemeHandler: RhwpStudioPDFFontSchemeHandler
    private let webKitOperations: RhwpStudioPagePDFWebKitOperations
    private let pageRenderTimeoutNanoseconds: UInt64
    private var completion: ((Result<PDFDocument, Error>) -> Void)?
    private var payload: RhwpStudioPagePayload?
    private var renderedDocument = PDFDocument()
    private var renderingPageIndex = 0
    private var didFinish = true
    private var renderLifecycle = RhwpStudioPagePDFRenderLifecycle()
    private var pageRenderTimeoutTask: Task<Void, Never>?
    private let outputFonts: RhwpStudioOutputFontJob?

    init(
        pageRenderTimeoutNanoseconds: UInt64 = 30_000_000_000,
        fontResourceProvider: RhwpStudioPDFFontResourceProviding =
            RhwpStudioPDFFontBundleResourceProvider(),
        outputFonts: RhwpStudioOutputFontJob? = nil,
        webKitOperations: RhwpStudioPagePDFWebKitOperations? = nil,
        webViewFactory: @MainActor (WKWebViewConfiguration) -> WKWebView = { configuration in
            WKWebView(
                frame: NSRect(
                    origin: .zero,
                    size: RhwpStudioPagePDFMetrics.initialPageSize
                ),
                configuration: configuration
            )
        }
    ) {
        self.pageRenderTimeoutNanoseconds = pageRenderTimeoutNanoseconds
        self.outputFonts = outputFonts
        self.webKitOperations = webKitOperations ?? .live(outputFonts: outputFonts)
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let pdfFontSchemeHandler = RhwpStudioPDFFontSchemeHandler(
            resourceProvider: fontResourceProvider, outputFonts: outputFonts
        )
        configuration.setURLSchemeHandler(
            pdfFontSchemeHandler,
            forURLScheme: RhwpStudioPDFFontRoute.scheme
        )
        self.pdfFontSchemeHandler = pdfFontSchemeHandler

        webView = webViewFactory(configuration)
        super.init()
    }

    deinit {
        pageRenderTimeoutTask?.cancel()
        // MainActor 정리는 해당 actor에서 한다. 출력 job은 single-use다.
        // 성공 후에는 저장/인쇄 소유자가 최종 검증·seal까지 lease를 유지한다.
        let fonts = didFinish ? nil : outputFonts, cancel = webKitOperations.cancelPreparation
        Task { @MainActor in cancel(); fonts?.cancel() }
    }

    func cancel() {
        guard let token = renderLifecycle.currentPageToken else { return }
        finish(.failure(RhwpStudioOutputFontError.cancelled), for: token)
    }

    func render(
        payload: RhwpStudioPagePayload,
        completion: @escaping (Result<PDFDocument, Error>) -> Void
    ) {
        guard self.completion == nil,
              renderLifecycle.beginRender() != nil
        else {
            completion(.failure(RhwpStudioPagePDFRenderError.renderingInProgress))
            return
        }

        webView.navigationDelegate = self
        self.completion = completion
        self.payload = payload
        renderedDocument = PDFDocument()
        renderingPageIndex = 0
        didFinish = false
        renderNextPage()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard webView === self.webView,
              let navigation,
              let token = renderLifecycle.token(
                forNavigation: ObjectIdentifier(navigation)
              )
        else {
            return
        }

        renderCurrentPagePDF(for: token)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard webView === self.webView else {
            decisionHandler(.cancel)
            return
        }

        let shouldAllow = RhwpStudioPagePDFNavigationPolicy.allowsNavigation(
            to: navigationAction.request.url,
            targetFrameIsMainFrame: navigationAction.targetFrame?.isMainFrame,
            initialMainFrameLoadPending: renderLifecycle.isInitialMainFrameLoadPending
        )
        if shouldAllow {
            _ = renderLifecycle.consumeInitialMainFrameLoad()
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
        guard webView === self.webView,
              let navigation,
              let token = renderLifecycle.token(
                forNavigation: ObjectIdentifier(navigation)
              )
        else {
            return
        }

        finish(.failure(error), for: token)
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        guard webView === self.webView,
              let navigation,
              let token = renderLifecycle.token(
                forNavigation: ObjectIdentifier(navigation)
              )
        else {
            return
        }

        finish(.failure(error), for: token)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard webView === self.webView,
              let token = renderLifecycle.currentPageToken
        else {
            return
        }

        finish(
            .failure(RhwpStudioPagePDFRenderError.webContentProcessTerminated),
            for: token
        )
    }

    private func renderNextPage() {
        guard !didFinish, renderLifecycle.isActive, let payload else {
            return
        }

        guard renderingPageIndex < payload.pageCount else {
            guard let token = renderLifecycle.currentPageToken else {
                assertionFailure("Active render completed without a current page token.")
                return
            }
            guard renderedDocument.pageCount == payload.pageCount else {
                finish(
                    .failure(
                        RhwpStudioPagePDFRenderError.finalPageCountMismatch(
                            expected: payload.pageCount,
                            actual: renderedDocument.pageCount
                        )
                    ),
                    for: token
                )
                return
            }
            finish(.success(renderedDocument), for: token)
            return
        }

        guard let token = renderLifecycle.beginPage(at: renderingPageIndex) else {
            assertionFailure("Active render could not begin the current page.")
            return
        }
        webView.frame = NSRect(
            origin: .zero,
            size: RhwpStudioPagePDFMetrics.initialPageSize
        )
        startPageRenderTimeout(for: token)
        let navigation = webView.loadHTMLString(
            RhwpStudioPagePDFHTML.pageHTML(for: payload.pages[renderingPageIndex]),
            baseURL: nil
        )
        if let navigation {
            _ = renderLifecycle.registerNavigation(
                ObjectIdentifier(navigation),
                for: token
            )
        }
    }

    private func renderCurrentPagePDF(for token: RhwpStudioPagePDFRenderToken) {
        guard !didFinish, renderLifecycle.isCurrent(token) else {
            return
        }

        webKitOperations.preparePage(webView) { [weak self] result in
            guard let self,
                  !self.didFinish,
                  self.renderLifecycle.isCurrent(token)
            else {
                return
            }

            let preparation: Any?
            switch result {
            case .success(let value):
                preparation = value
            case .failure(let error):
                if error is RhwpStudioOutputFontError || error is CancellationError {
                    self.finish(.failure(error), for:token)
                    return
                }
                self.finish(
                    .failure(
                        RhwpStudioPagePDFRenderError.fontPreparationFailed(
                            page: token.pageIndex + 1,
                            reason: error.localizedDescription
                        )
                    ),
                    for: token
                )
                return
            }

            let pageNumber = token.pageIndex + 1
            let pageSize: NSSize
            do {
                pageSize = try RhwpStudioPagePDFPreparation.pageSize(
                    from: preparation,
                    pageNumber: pageNumber
                )
            } catch {
                self.finish(.failure(error), for: token)
                return
            }

            self.webView.frame = NSRect(origin: .zero, size: pageSize)
            self.webView.layoutSubtreeIfNeeded()

            let configuration = WKPDFConfiguration()
            configuration.rect = NSRect(origin: .zero, size: pageSize)
            self.webKitOperations.createPDF(
                self.webView,
                configuration
            ) { [weak self] result in
                guard let self,
                      !self.didFinish,
                      self.renderLifecycle.isCurrent(token)
                else {
                    return
                }

                switch result {
                case .success(let data):
                    if let fonts = self.outputFonts {
                        Task { [weak self] in
                            do {
                                try await fonts.validate()
                                self?.appendPDFPage(data, for: token)
                            } catch { self?.finish(.failure(error), for: token) }
                        }
                    } else { self.appendPDFPage(data, for: token) }
                case .failure(let error):
                    self.finish(.failure(error), for: token)
                }
            }
        }
    }

    private func appendPDFPage(
        _ data: Data,
        for token: RhwpStudioPagePDFRenderToken
    ) {
        guard renderLifecycle.isCurrent(token),
              renderingPageIndex == token.pageIndex
        else {
            return
        }

        let pageNumber = token.pageIndex + 1
        guard let pageDocument = PDFDocument(data: data) else {
            finish(
                .failure(RhwpStudioPagePDFRenderError.pdfEncodingFailed(pageNumber)),
                for: token
            )
            return
        }
        guard pageDocument.pageCount == 1 else {
            finish(
                .failure(
                    RhwpStudioPagePDFRenderError.unexpectedPDFPageCount(
                        page: pageNumber,
                        actual: pageDocument.pageCount
                    )
                ),
                for: token
            )
            return
        }
        guard let page = pageDocument.page(at: 0) else {
            finish(
                .failure(RhwpStudioPagePDFRenderError.pdfEncodingFailed(pageNumber)),
                for: token
            )
            return
        }

        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width.isFinite,
              bounds.height.isFinite,
              bounds.width > 0,
              bounds.height > 0
        else {
            finish(
                .failure(RhwpStudioPagePDFRenderError.invalidPDFPageBounds(pageNumber)),
                for: token
            )
            return
        }

        renderedDocument.insert(page, at: renderedDocument.pageCount)
        renderingPageIndex += 1
        renderNextPage()
    }

    private func startPageRenderTimeout(for token: RhwpStudioPagePDFRenderToken) {
        pageRenderTimeoutTask?.cancel()
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
                  self.renderLifecycle.isCurrent(token)
            else {
                return
            }

            self.finish(.failure(
                RhwpStudioPagePDFRenderError.pageRenderTimedOut(token.pageIndex + 1)
            ), for: token)
        }
    }

    private func finish(
        _ result: Result<PDFDocument, Error>,
        for token: RhwpStudioPagePDFRenderToken
    ) {
        guard !didFinish, renderLifecycle.invalidate(token) else {
            return
        }

        didFinish = true
        webView.navigationDelegate = nil
        pageRenderTimeoutTask?.cancel()
        pageRenderTimeoutTask = nil
        webKitOperations.cancelPreparation()
        if case .failure = result { outputFonts?.cancel() }
        webView.stopLoading()
        let completion = completion
        self.completion = nil
        payload = nil
        renderedDocument = PDFDocument()
        renderingPageIndex = 0
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
    \#(RhwpStudioOutputFontPreparation.familyParser)
    const ownedFamilies = \#(RhwpStudioPDFFontStyle.ownedFamilyNamesJSON);
    const ownedByKey = new Map(ownedFamilies.map(name => [name.toLowerCase(),name]));
    const hangulPattern = /[\#(RhwpStudioPDFFontStyle.hangulJavaScriptCharacterClass)]/;
    const custom = globalThis.__alhangeulPDFOutput?.custom;
    const requiredFaces = new Map();
    const fallbackToken = Array.from(crypto.getRandomValues(new Uint32Array(4))).map(n => n.toString(16)).join('');
    let generatedRuns = 0;
    const outputNodes = [...document.querySelectorAll("svg text"), ...document.querySelectorAll("svg tspan")];
    for (const textNode of outputNodes) {
      if (custom?.has(textNode)) continue;
      const sample = directPDFText(textNode).match(hangulPattern)?.[0];
      if (!sample) continue;
      const style = getComputedStyle(textNode);
      const families = splitPDFFamilies(style.fontFamily);
      const owned = families.map(candidate => ownedByKey.get(candidate.toLowerCase())).find(Boolean);
      const serif = owned ? \#(RhwpStudioPDFFontStyle.serifAliasesJSON).includes(owned)
        : families.some(name => name.toLowerCase() === 'serif');
      const weight = Number.parseInt(style.fontWeight, 10) >= 500 ? 700 : 400;
      const alias = `Noto PDF ${serif ? 'Serif' : 'Sans'} ${weight} ${fallbackToken}`;
      if (!requiredFaces.has(alias)) {
        const filename = `Noto${serif ? 'Serif' : 'Sans'}KR-${weight === 700 ? 'Bold' : 'Regular'}.woff2`;
        const face = new FontFace(alias, `url("alhangeul-pdf-font://bundle/${filename}")`, {
          weight:String(weight), style:'normal',
          // 한글에만 적용한다. ASCII·수학·Hanja는 원래 fallback을 유지한다.
          unicodeRange:'\#(RhwpStudioPDFFontStyle.hangulUnicodeRange)'
        });
        document.fonts.add(face); requiredFaces.set(alias, {face, weight, sample});
      }
      const fallback = families.filter(name => !ownedByKey.has(name.toLowerCase()));
      const quoteFamily = name => ['serif','sans-serif','monospace','system-ui','cursive','fantasy','ui-serif','ui-sans-serif','ui-monospace','emoji','math','fangsong'].includes(name.toLowerCase()) ? name : '"' + name.replace(/\\/g, '\\\\').replace(/"/g, '\\"') + '"';
      const original = fallback.length ? fallback.map(quoteFamily).join(', ') : (serif ? 'serif' : 'sans-serif');
      // WebKit은 혼합 run의 공백/구두점을 한글 subset 코드로 잘못 매핑할 수 있다.
      // 원래 문자 순서·SVG 위치 속성을 유지한 채 script 경계에서만 run을 분리한다.
      for (const child of Array.from(textNode.childNodes)) {
        if (child.nodeType !== Node.TEXT_NODE || !hangulPattern.test(child.textContent || '')) continue;
        const parts = (child.textContent || '').match(/[\#(RhwpStudioPDFFontStyle.hangulJavaScriptCharacterClass)]+|[^\#(RhwpStudioPDFFontStyle.hangulJavaScriptCharacterClass)]+/gu) || [];
        generatedRuns += parts.length;
        if (generatedRuns > 65536) throw Error('PDF fallback run limit');
        const fragment = document.createDocumentFragment();
        for (const part of parts) {
          const span = document.createElementNS('http://www.w3.org/2000/svg','tspan');
          span.textContent = part;
          span.style.setProperty('font-family', hangulPattern.test(part) ? '"' + alias + '"' : original, 'important');
          fragment.appendChild(span);
        }
        child.replaceWith(fragment);
      }
    }
    await Promise.all(Array.from(requiredFaces.values()).map(required => required.face.load().catch(() => null)));
    await document.fonts.ready;
    const unresolvedFaces = Array.from(requiredFaces.entries()).filter(([alias, required]) =>
      required.face.status !== 'loaded' || !document.fonts.check(`${required.weight} 12px "${alias}"`, required.sample));
    let fontFailureReason = null;
    if (document.fonts.status !== 'loaded') fontFailureReason = `document.fonts.status=${document.fonts.status}`;
    else if (unresolvedFaces.length) fontFailureReason = `unresolved PDF fonts: ${unresolvedFaces.map(([name]) => name).join(', ')}`;

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
