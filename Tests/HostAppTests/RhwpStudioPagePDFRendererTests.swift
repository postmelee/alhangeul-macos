import AppKit
import Network
import PDFKit
import WebKit
import XCTest

@MainActor
final class RhwpStudioPagePDFRendererTests: XCTestCase {
    func testPageHTMLPlacesStrictCSPBeforeDocumentSVG() throws {
        let expectedPolicy = [
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
            "font-src alhangeul-pdf-font:"
        ].joined(separator: "; ") + ";"
        XCTAssertEqual(RhwpStudioPagePDFHTML.contentSecurityPolicy, expectedPolicy)
        XCTAssertFalse(RhwpStudioPagePDFHTML.contentSecurityPolicy.contains("font-src data:"))
        XCTAssertFalse(RhwpStudioPagePDFHTML.contentSecurityPolicy.contains("http:"))
        XCTAssertFalse(RhwpStudioPagePDFHTML.contentSecurityPolicy.contains("https:"))
        XCTAssertFalse(RhwpStudioPagePDFHTML.contentSecurityPolicy.contains("blob:"))
        XCTAssertFalse(RhwpStudioPagePDFHTML.contentSecurityPolicy.contains("file:"))

        let svg = "<svg id=\"document-svg\" xmlns=\"http://www.w3.org/2000/svg\"></svg>"
        let html = RhwpStudioPagePDFHTML.pageHTML(for: svg)
        let cspRange = try XCTUnwrap(
            html.range(of: "<meta http-equiv=\"Content-Security-Policy\"")
        )
        let fontFaceRange = try XCTUnwrap(html.range(of: "@font-face"))
        let svgRange = try XCTUnwrap(html.range(of: "<svg id=\"document-svg\""))
        XCTAssertLessThan(cspRange.lowerBound, svgRange.lowerBound)
        XCTAssertLessThan(fontFaceRange.lowerBound, svgRange.lowerBound)
        XCTAssertTrue(html.contains("content=\"\(expectedPolicy)\""))
        XCTAssertTrue(html.contains(RhwpStudioPDFFontStyle.hangulUnicodeRange))
        XCTAssertTrue(html.contains("U+3200-321E"))
        XCTAssertTrue(html.contains("U+3260-327F"))
        XCTAssertTrue(RhwpStudioPagePDFHTML.pagePreparationScript.contains(
            "const hangulPattern = /[\(RhwpStudioPDFFontStyle.hangulJavaScriptCharacterClass)]/;"
        ))
        XCTAssertTrue(html.contains(
            "alhangeul-pdf-font://bundle/NotoSansKR-Regular.woff2"
        ))
        XCTAssertTrue(html.contains(
            "alhangeul-pdf-font://bundle/NotoSerifKR-Bold.woff2"
        ))
        XCTAssertFalse(html.contains("LatinModernMath-Regular.woff2"))
    }

    func testPDFFontRouteAllowsOnlyExactAllowlistedBundleURLs() throws {
        for resource in RhwpStudioPDFFontResource.allCases {
            let url = try XCTUnwrap(URL(string:
                "alhangeul-pdf-font://bundle/\(resource.rawValue)"
            ))
            XCTAssertEqual(try RhwpStudioPDFFontRoute.resource(for: url), resource)
        }

        let rejectedValues: [String?] = [
            nil,
            "alhangeul-pdf-font://bundle/Unknown.woff2",
            "alhangeul-pdf-font://bundle/fonts/NotoSansKR-Regular.woff2",
            "alhangeul-pdf-font://bundle/%4eotoSansKR-Regular.woff2",
            "alhangeul-pdf-font://bundle/NotoSansKR-Regular.woff2?cache=1",
            "alhangeul-pdf-font://bundle/NotoSansKR-Regular.woff2#fragment",
            "alhangeul-pdf-font://user@bundle/NotoSansKR-Regular.woff2",
            "alhangeul-pdf-font://bundle:443/NotoSansKR-Regular.woff2",
            "alhangeul-pdf-font://other/NotoSansKR-Regular.woff2",
            "https://bundle/NotoSansKR-Regular.woff2"
        ]

        for value in rejectedValues {
            XCTAssertThrowsError(try RhwpStudioPDFFontRoute.resource(
                for: value.flatMap(URL.init(string:))
            ), "URL이 거부되어야 합니다: \(value ?? "nil")")
        }
    }

    func testPDFFontProviderResolvesOnlyRegularFilesWithinSizeLimit() throws {
        let provider = fontResourceProvider()
        for resource in RhwpStudioPDFFontResource.allCases {
            let data = try provider.data(for: resource)
            XCTAssertFalse(data.isEmpty)
            XCTAssertLessThanOrEqual(
                data.count,
                RhwpStudioPDFFontResource.maximumByteCount
            )
        }

        let fixtureDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("rhwp-pdf-font-provider-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: fixtureDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: fixtureDirectory) }

        let oversizedURL = fixtureDirectory.appendingPathComponent(
            RhwpStudioPDFFontResource.notoSansKRRegular.rawValue
        )
        try Data(
            repeating: 0,
            count: RhwpStudioPDFFontResource.maximumByteCount + 1
        ).write(to: oversizedURL)

        let invalidDirectoryURL = fixtureDirectory.appendingPathComponent(
            RhwpStudioPDFFontResource.notoSansKRBold.rawValue,
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: invalidDirectoryURL,
            withIntermediateDirectories: false
        )
        let invalidFormatURL = fixtureDirectory.appendingPathComponent(
            RhwpStudioPDFFontResource.notoSerifKRBold.rawValue
        )
        try Data([0x00, 0x01, 0x02, 0x03]).write(to: invalidFormatURL)

        let invalidProvider = RhwpStudioPDFFontDirectoryResourceProvider(
            directoryURL: fixtureDirectory
        )
        XCTAssertThrowsError(try invalidProvider.data(for: .notoSansKRRegular)) { error in
            guard case .resourceTooLarge = error as? RhwpStudioPDFFontResourceError else {
                XCTFail("과대 글꼴 오류가 아닙니다: \(error)")
                return
            }
        }
        XCTAssertThrowsError(try invalidProvider.data(for: .notoSansKRBold)) { error in
            XCTAssertEqual(
                error as? RhwpStudioPDFFontResourceError,
                .invalidResourceFile(RhwpStudioPDFFontResource.notoSansKRBold.rawValue)
            )
        }
        XCTAssertThrowsError(try invalidProvider.data(for: .notoSerifKRRegular)) { error in
            XCTAssertEqual(
                error as? RhwpStudioPDFFontResourceError,
                .missingResource(RhwpStudioPDFFontResource.notoSerifKRRegular.rawValue)
            )
        }
        XCTAssertThrowsError(try invalidProvider.data(for: .notoSerifKRBold)) { error in
            XCTAssertEqual(
                error as? RhwpStudioPDFFontResourceError,
                .invalidResourceFormat(RhwpStudioPDFFontResource.notoSerifKRBold.rawValue)
            )
        }

        try FileManager.default.removeItem(at: invalidDirectoryURL)
        try FileManager.default.createSymbolicLink(
            at: invalidDirectoryURL,
            withDestinationURL: oversizedURL
        )
        XCTAssertThrowsError(try invalidProvider.data(for: .notoSansKRBold)) { error in
            XCTAssertEqual(
                error as? RhwpStudioPDFFontResourceError,
                .invalidResourceFile(RhwpStudioPDFFontResource.notoSansKRBold.rawValue)
            )
        }
    }

    func testPDFFontBundleProviderResolvesAllProductionResources() throws {
        let fileManager = FileManager.default
        let bundleURL = fileManager.temporaryDirectory
            .appendingPathComponent("RhwpStudioPDFFonts-\(UUID().uuidString).bundle")
        let contentsURL = bundleURL.appendingPathComponent("Contents", isDirectory: true)
        let resourceDirectoryURL = contentsURL
            .appendingPathComponent("Resources/rhwp-studio/fonts", isDirectory: true)
        try fileManager.createDirectory(
            at: resourceDirectoryURL,
            withIntermediateDirectories: true
        )
        defer { try? fileManager.removeItem(at: bundleURL) }

        let infoData = try PropertyListSerialization.data(
            fromPropertyList: [
                "CFBundleIdentifier": "com.postmelee.alhangeul.tests.pdf-fonts.\(UUID().uuidString)",
                "CFBundleName": "RhwpStudioPDFFonts",
                "CFBundlePackageType": "BNDL",
                "CFBundleVersion": "1"
            ],
            format: .xml,
            options: 0
        )
        try infoData.write(to: contentsURL.appendingPathComponent("Info.plist"))

        let sourceProvider = fontResourceProvider()
        for resource in RhwpStudioPDFFontResource.allCases {
            try sourceProvider.data(for: resource).write(
                to: resourceDirectoryURL.appendingPathComponent(resource.rawValue)
            )
        }

        let bundle = try XCTUnwrap(Bundle(url: bundleURL))
        let provider = RhwpStudioPDFFontBundleResourceProvider(bundle: bundle)
        for resource in RhwpStudioPDFFontResource.allCases {
            XCTAssertEqual(
                try provider.data(for: resource),
                try sourceProvider.data(for: resource)
            )
        }
    }

    func testNavigationPolicyAllowsOnlyPendingInitialAboutBlankMainFrame() {
        XCTAssertTrue(
            RhwpStudioPagePDFNavigationPolicy.allowsNavigation(
                to: URL(string: "about:blank"),
                targetFrameIsMainFrame: true,
                initialMainFrameLoadPending: true
            )
        )

        let blockedCases: [(url: URL?, isMainFrame: Bool?, isPending: Bool)] = [
            (URL(string: "about:blank"), true, false),
            (URL(string: "about:blank"), false, true),
            (URL(string: "about:blank"), nil, true),
            (URL(string: "http://127.0.0.1/resource"), true, true),
            (URL(string: "https://127.0.0.1/resource"), true, true),
            (URL(fileURLWithPath: "/tmp/resource"), true, true),
            (URL(string: "blob:https://example.invalid/resource"), true, true),
            (URL(string: "alhangeul-pdf-font://bundle/NotoSansKR-Regular.woff2"), true, true),
            (URL(string: "custom:resource"), true, true),
            (nil, true, true)
        ]

        for blockedCase in blockedCases {
            XCTAssertFalse(
                RhwpStudioPagePDFNavigationPolicy.allowsNavigation(
                    to: blockedCase.url,
                    targetFrameIsMainFrame: blockedCase.isMainFrame,
                    initialMainFrameLoadPending: blockedCase.isPending
                )
            )
        }
    }

    func testRenderLifecycleTracksPageAndNavigationIdentityWithinGeneration() throws {
        var lifecycle = RhwpStudioPagePDFRenderLifecycle()
        let generation = try XCTUnwrap(lifecycle.beginRender())
        let firstPage = try XCTUnwrap(lifecycle.beginPage(at: 0))
        let firstNavigation = NSObject()

        XCTAssertEqual(firstPage.generation, generation)
        XCTAssertEqual(firstPage.pageIndex, 0)
        XCTAssertTrue(lifecycle.isCurrent(firstPage))
        XCTAssertNil(lifecycle.beginRender())
        XCTAssertEqual(lifecycle.latestGeneration, generation)
        XCTAssertTrue(lifecycle.isInitialMainFrameLoadPending)
        XCTAssertTrue(
            lifecycle.registerNavigation(ObjectIdentifier(firstNavigation), for: firstPage)
        )
        XCTAssertEqual(
            lifecycle.token(forNavigation: ObjectIdentifier(firstNavigation)),
            firstPage
        )

        let secondPage = try XCTUnwrap(lifecycle.beginPage(at: 1))
        let secondNavigation = NSObject()

        XCTAssertEqual(secondPage.generation, generation)
        XCTAssertEqual(secondPage.pageIndex, 1)
        XCTAssertFalse(lifecycle.isCurrent(firstPage))
        XCTAssertNil(lifecycle.token(forNavigation: ObjectIdentifier(firstNavigation)))
        XCTAssertFalse(
            lifecycle.registerNavigation(ObjectIdentifier(firstNavigation), for: firstPage)
        )
        XCTAssertTrue(
            lifecycle.registerNavigation(ObjectIdentifier(secondNavigation), for: secondPage)
        )
        XCTAssertEqual(
            lifecycle.token(forNavigation: ObjectIdentifier(secondNavigation)),
            secondPage
        )
    }

    func testRenderLifecycleRejectsStaleTokenAcrossRenderGenerations() throws {
        var lifecycle = RhwpStudioPagePDFRenderLifecycle()
        let firstGeneration = try XCTUnwrap(lifecycle.beginRender())
        let firstToken = try XCTUnwrap(lifecycle.beginPage(at: 0))

        XCTAssertTrue(lifecycle.invalidate(firstToken))
        let secondGeneration = try XCTUnwrap(lifecycle.beginRender())
        let secondToken = try XCTUnwrap(lifecycle.beginPage(at: 0))

        XCTAssertGreaterThan(secondGeneration, firstGeneration)
        XCTAssertNotEqual(secondToken, firstToken)
        XCTAssertFalse(lifecycle.isCurrent(firstToken))
        XCTAssertFalse(lifecycle.invalidate(firstToken))
        XCTAssertTrue(lifecycle.isCurrent(secondToken))
        XCTAssertEqual(lifecycle.currentPageToken, secondToken)
    }

    func testRenderLifecycleScopesInitialMainFrameLoadToCurrentPage() throws {
        var lifecycle = RhwpStudioPagePDFRenderLifecycle()
        _ = try XCTUnwrap(lifecycle.beginRender())
        _ = try XCTUnwrap(lifecycle.beginPage(at: 0))

        XCTAssertTrue(lifecycle.isInitialMainFrameLoadPending)
        XCTAssertTrue(lifecycle.consumeInitialMainFrameLoad())
        XCTAssertFalse(lifecycle.isInitialMainFrameLoadPending)
        XCTAssertFalse(lifecycle.consumeInitialMainFrameLoad())

        _ = try XCTUnwrap(lifecycle.beginPage(at: 1))
        XCTAssertTrue(lifecycle.isInitialMainFrameLoadPending)
    }

    func testRendererPreservesPortraitAndLandscapePageOrientation() async throws {
        let payload = try RhwpStudioPagePayload(
            fileName: "orientation.hwp",
            pageCount: 2,
            pages: [
                svg(width: 200, height: 300, text: "Portrait"),
                svg(width: 300, height: 200, text: "Landscape")
            ]
        )

        let document = try await render(payload)
        XCTAssertEqual(document.pageCount, 2)

        let portraitBounds = try XCTUnwrap(document.page(at: 0)?.bounds(for: .mediaBox))
        let landscapeBounds = try XCTUnwrap(document.page(at: 1)?.bounds(for: .mediaBox))
        XCTAssertEqual(portraitBounds.width, 200, accuracy: 0.01)
        XCTAssertEqual(portraitBounds.height, 300, accuracy: 0.01)
        XCTAssertEqual(landscapeBounds.width, 300, accuracy: 0.01)
        XCTAssertEqual(landscapeBounds.height, 200, accuracy: 0.01)
        XCTAssertLessThan(portraitBounds.width, portraitBounds.height)
        XCTAssertGreaterThan(landscapeBounds.width, landscapeBounds.height)
        XCTAssertNil(RhwpStudioPrintOrientationPolicy.orientation(for: document))

        for pageIndex in 0..<document.pageCount {
            let page = try XCTUnwrap(document.page(at: pageIndex))
            let blueFraction = try pixelFraction(on: page) { color in
                color.blueComponent > 0.5
                    && color.redComponent < 0.5
                    && color.greenComponent < 0.7
            }
            XCTAssertGreaterThan(blueFraction, 0.001)
        }

        let data = try XCTUnwrap(document.dataRepresentation())
        XCTAssertTrue(data.starts(with: Data("%PDF".utf8)))
        XCTAssertTrue(document.page(at: 0)?.string?.contains("Portrait") == true)
        XCTAssertTrue(document.page(at: 1)?.string?.contains("Landscape") == true)

        let printInfo = NSPrintInfo()
        XCTAssertNotNil(
            document.printOperation(
                for: printInfo,
                scalingMode: .pageScaleDownToFit,
                autoRotate: true
            )
        )
    }

    func testRendererEmbedsSelectableKoreanFontsWithToUnicode() async throws {
        let payload = try RhwpStudioPagePayload(
            fileName: "korean-math.hwp",
            pageCount: 1,
            pages: [koreanMathSVG()]
        )

        let document = try await render(payload)
        let page = try XCTUnwrap(document.page(at: 0))
        let pageText = try XCTUnwrap(page.string)
        let fullSelection = try XCTUnwrap(
            page.selection(for: page.bounds(for: .mediaBox))?.string
        )

        for sentinel in ["문1", "함수", "값은"] {
            XCTAssertTrue(pageText.contains(sentinel), "PDFPage.string 누락: \(sentinel)")
            XCTAssertTrue(fullSelection.contains(sentinel), "영역 선택 누락: \(sentinel)")
            XCTAssertGreaterThan(
                document.findString(sentinel, withOptions: []).count,
                0,
                "PDF 검색 누락: \(sentinel)"
            )
        }
        XCTAssertTrue(pageText.contains("f(x)"))
        XCTAssertTrue(fullSelection.contains("f(x)"))
        XCTAssertGreaterThan(document.findString("f(x)", withOptions: []).count, 0)

        let fontRecords = CGPDFFontResourceInspector.records(in: document)
        let koreanFontRecords = fontRecords.filter {
            $0.baseFont.contains("NotoSansKR") || $0.baseFont.contains("NotoSerifKR")
        }
        XCTAssertFalse(koreanFontRecords.isEmpty, "Noto 한글 PDF font resource가 없습니다.")
        XCTAssertTrue(
            koreanFontRecords.allSatisfy(\.hasToUnicode),
            "ToUnicode 없는 Noto resource: \(koreanFontRecords)"
        )
        XCTAssertTrue(koreanFontRecords.contains { $0.baseFont.contains("NotoSansKR") })
        XCTAssertTrue(koreanFontRecords.contains { $0.baseFont.contains("NotoSerifKR") })
    }

    func testRendererMapsHangulInsideMathSerifStackWithoutChangingMathText() async throws {
        let payload = try RhwpStudioPagePayload(
            fileName: "mixed-hangul-math-stack.hwp",
            pageCount: 1,
            pages: [
                """
                <svg xmlns="http://www.w3.org/2000/svg" width="500" height="200" viewBox="0 0 500 200">
                  <rect width="500" height="200" fill="white" />
                  <text x="40" y="80"
                        font-family="'Latin Modern Math','STIX Two Text','STIX Two Math','Times New Roman',Times,serif"
                        font-size="24">문2 함수 f(x)=x²+2x+1</text>
                </svg>
                """
            ]
        )

        let document = try await render(payload)
        let page = try XCTUnwrap(document.page(at: 0))
        let pageText = try XCTUnwrap(page.string)
        let fullSelection = try XCTUnwrap(
            page.selection(for: page.bounds(for: .mediaBox))?.string
        )

        for sentinel in ["문2", "함수", "f(x)=x²+2x+1"] {
            XCTAssertTrue(pageText.contains(sentinel), "PDFPage.string 누락: \(sentinel)")
            XCTAssertTrue(fullSelection.contains(sentinel), "영역 선택 누락: \(sentinel)")
            XCTAssertGreaterThan(document.findString(sentinel, withOptions: []).count, 0)
        }

        let serifKoreanFonts = CGPDFFontResourceInspector.records(in: document).filter {
            $0.baseFont.contains("NotoSerifKR")
        }
        XCTAssertFalse(serifKoreanFonts.isEmpty)
        XCTAssertTrue(serifKoreanFonts.allSatisfy(\.hasToUnicode))
    }

    func testRendererMapsUnclassifiedAndEnclosedHangulWithOwnedSansFallback() async throws {
        let payload = try RhwpStudioPagePayload(
            fileName: "unclassified-hangul-family.hwp",
            pageCount: 1,
            pages: [
                """
                <svg xmlns="http://www.w3.org/2000/svg" width="500" height="300" viewBox="0 0 500 300">
                  <rect width="500" height="300" fill="white" />
                  <text x="250" y="50" text-anchor="middle" fill="#666666"
                        font-size="20">[외부: sample.png]</text>
                  <text x="20" y="110" font-family="monospace"
                        font-size="20">모노스페이스 한글</text>
                  <text x="20" y="170" font-family="'Unknown Hangul Family'"
                        font-size="20">미등록 글꼴 한글</text>
                  <text x="20" y="230" font-size="20">㈀ 원문자 ㉠ 한글</text>
                </svg>
                """
            ]
        )

        let document = try await render(payload)
        let page = try XCTUnwrap(document.page(at: 0))
        let pageText = try XCTUnwrap(page.string)
        let fullSelection = try XCTUnwrap(
            page.selection(for: page.bounds(for: .mediaBox))?.string
        )

        for sentinel in ["외부", "모노스페이스", "미등록", "㈀", "㉠"] {
            XCTAssertTrue(pageText.contains(sentinel), "PDFPage.string 누락: \(sentinel)")
            XCTAssertTrue(fullSelection.contains(sentinel), "영역 선택 누락: \(sentinel)")
            XCTAssertGreaterThan(document.findString(sentinel, withOptions: []).count, 0)
        }

        let sansKoreanFonts = CGPDFFontResourceInspector.records(in: document).filter {
            $0.baseFont.contains("NotoSansKR")
        }
        XCTAssertFalse(sansKoreanFonts.isEmpty)
        XCTAssertTrue(sansKoreanFonts.allSatisfy(\.hasToUnicode))
    }

    func testRendererFailsWhenRequiredKoreanFontCannotLoadExactlyOnce() async throws {
        let payload = try RhwpStudioPagePayload(
            fileName: "missing-bold-font.hwp",
            pageCount: 1,
            pages: [
                """
                <svg xmlns="http://www.w3.org/2000/svg" width="200" height="300" viewBox="0 0 200 300">
                  <rect width="200" height="300" fill="white" />
                  <text x="20" y="50" font-family="'Haansoft Dotum','Noto Sans KR',sans-serif"
                        font-size="20" font-weight="bold">문1 함수의 값은</text>
                </svg>
                """
            ]
        )
        let provider = RejectingPDFFontResourceProvider(
            wrapped: fontResourceProvider(),
            rejectedResources: [.notoSansKRBold]
        )
        let renderer = RhwpStudioPagePDFRenderer(fontResourceProvider: provider)
        var completionCount = 0

        let result: Result<PDFDocument, Error> = await withCheckedContinuation { continuation in
            renderer.render(payload: payload) { [renderer] result in
                _ = renderer
                completionCount += 1
                if completionCount == 1 {
                    continuation.resume(returning: result)
                }
            }
        }

        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(completionCount, 1)
        guard case .failure(let error) = result,
              case .fontPreparationFailed(let page, let reason) =
                error as? RhwpStudioPagePDFRenderError
        else {
            XCTFail("필수 한글 글꼴 누락이 typed error로 완료되지 않았습니다: \(result)")
            return
        }
        XCTAssertEqual(page, 1)
        XCTAssertTrue(reason.contains("Haansoft Dotum/bold"), reason)
    }

    func testCGPDFFontInspectorTraversalRejectsCyclesAndExcessDepth() {
        var traversal = CGPDFResourceTraversalState(maximumDepth: 2)
        XCTAssertTrue(traversal.shouldVisit(dictionaryAddress: 1, depth: 0))
        XCTAssertFalse(traversal.shouldVisit(dictionaryAddress: 1, depth: 1))
        XCTAssertTrue(traversal.shouldVisit(dictionaryAddress: 2, depth: 2))
        XCTAssertFalse(traversal.shouldVisit(dictionaryAddress: 3, depth: 3))
    }

    func testRendererDoesNotExecuteDocumentScriptsOrEventHandlers() async throws {
        let dataImage = try dataPNGDataURI(color: .red)
        let payload = try RhwpStudioPagePayload(
            fileName: "script-blocking.hwp",
            pageCount: 1,
            pages: [
                """
                <svg xmlns="http://www.w3.org/2000/svg" width="200" height="300" viewBox="0 0 200 300"
                     onload="document.getElementById('sentinel').textContent='ROOT-EVENT-EXECUTED'">
                  <rect width="200" height="300" fill="white" />
                  <text id="sentinel" x="20" y="40" font-size="20" fill="black">SAFE-SENTINEL</text>
                  <script>
                    document.getElementById('sentinel').textContent = 'SCRIPT-EXECUTED';
                  </script>
                  <image href="\(dataImage)" x="20" y="60" width="20" height="20"
                         onload="document.getElementById('sentinel').textContent='IMAGE-EVENT-EXECUTED'" />
                  <a href="javascript:document.getElementById('sentinel').textContent='URL-EXECUTED'">
                    <text x="20" y="110" font-size="16" fill="black">JSURL-INERT</text>
                  </a>
                </svg>
                """
            ]
        )

        let document = try await render(payload)
        let pageText = try XCTUnwrap(document.page(at: 0)?.string)
        XCTAssertTrue(pageText.contains("SAFE-SENTINEL"))
        XCTAssertTrue(pageText.contains("JSURL-INERT"))
        XCTAssertFalse(pageText.contains("EXECUTED"))
    }

    func testRendererPreservesEmbeddedDataPNG() async throws {
        let dataImage = try dataPNGDataURI(color: .red)
        let payload = try RhwpStudioPagePayload(
            fileName: "data-image.hwp",
            pageCount: 1,
            pages: [
                """
                <svg xmlns="http://www.w3.org/2000/svg" width="200" height="300" viewBox="0 0 200 300">
                  <image href="\(dataImage)" width="200" height="300" preserveAspectRatio="none" />
                </svg>
                """
            ]
        )

        let document = try await render(payload)
        let page = try XCTUnwrap(document.page(at: 0))
        let redFraction = try pixelFraction(on: page) { color in
            color.redComponent > 0.7 && color.greenComponent < 0.3 && color.blueComponent < 0.3
        }
        XCTAssertGreaterThan(redFraction, 0.5)
    }

    func testRendererPreservesNestedDataSVGWithoutExecutingItsScript() async throws {
        let nestedSVG = """
        <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 20 20"
             onload="document.getElementById('nested-sentinel').setAttribute('fill', '#ff0000')">
          <rect id="nested-sentinel" width="20" height="20" fill="#00ff00" />
          <script>
            document.getElementById('nested-sentinel').setAttribute('fill', '#ff0000');
          </script>
        </svg>
        """
        let dataImage = "data:image/svg+xml;base64,\(Data(nestedSVG.utf8).base64EncodedString())"
        let payload = try RhwpStudioPagePayload(
            fileName: "nested-data-svg.hwp",
            pageCount: 1,
            pages: [
                """
                <svg xmlns="http://www.w3.org/2000/svg" width="200" height="300" viewBox="0 0 200 300">
                  <image href="\(dataImage)" width="200" height="300" preserveAspectRatio="none" />
                </svg>
                """
            ]
        )

        let document = try await render(payload)
        let page = try XCTUnwrap(document.page(at: 0))
        let greenFraction = try pixelFraction(on: page) { color in
            color.greenComponent > 0.8 && color.redComponent < 0.6 && color.blueComponent < 0.5
        }
        let redFraction = try pixelFraction(on: page) { color in
            color.redComponent > 0.8 && color.greenComponent < 0.4 && color.blueComponent < 0.4
        }
        XCTAssertGreaterThan(greenFraction, 0.5)
        XCTAssertLessThan(redFraction, 0.05)
    }

    func testRendererBlocksExternalResourcesAndNavigationWithoutRequests() async throws {
        let controlProbe = try LoopbackRequestProbe()
        try await controlProbe.start()
        defer { controlProbe.stop() }

        let controlPort = try XCTUnwrap(controlProbe.port)
        let controlBaseURL = "http://127.0.0.1:\(controlPort.rawValue)"
        let controlConfiguration = WKWebViewConfiguration()
        controlConfiguration.websiteDataStore = .nonPersistent()
        let controlWebView = WKWebView(frame: .zero, configuration: controlConfiguration)
        controlWebView.loadHTMLString(
            "<img src=\"\(controlBaseURL)/positive-control.png\">",
            baseURL: nil
        )
        try await controlProbe.waitForAcceptedConnection()
        controlWebView.stopLoading()
        controlProbe.stop()
        XCTAssertGreaterThan(controlProbe.acceptedConnectionCount, 0)

        let probe = try LoopbackRequestProbe()
        try await probe.start()
        defer { probe.stop() }

        let port = try XCTUnwrap(probe.port)
        let httpBaseURL = "http://127.0.0.1:\(port.rawValue)"
        let httpsBaseURL = "https://127.0.0.1:\(port.rawValue)"

        let payload = try RhwpStudioPagePayload(
            fileName: "external-resource-blocking.hwp",
            pageCount: 1,
            pages: [
                """
                <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
                     width="200" height="300" viewBox="0 0 200 300">
                  <style>
                    @import url("\(httpBaseURL)/import.css");
                    @font-face { font-family: probe; src: url(\(httpBaseURL)/font.woff2); }
                    @font-face {
                      font-family: rejected-custom-probe;
                      src: url(alhangeul-pdf-font://bundle/NotAllowed.woff2);
                    }
                    .external-fill {
                      fill: url(\(httpsBaseURL)/paint.svg#paint);
                      font-family: probe, rejected-custom-probe;
                    }
                  </style>
                  <rect width="200" height="300" fill="white" />
                  <text x="20" y="40" font-size="18" fill="black" class="external-fill">NETWORK-BLOCKED</text>
                  <image href="\(httpBaseURL)/image.png" x="0" y="60" width="100" height="100" />
                  <image xlink:href="\(httpBaseURL)/legacy-image.png" x="0" y="160" width="100" height="100" />
                  <use href="\(httpsBaseURL)/sprite.svg#shape" x="100" y="60" width="100" height="100" />
                </svg>
                <link rel="stylesheet" href="\(httpBaseURL)/style.css">
                <img src="\(httpsBaseURL)/html-image.png">
                <iframe src="\(httpBaseURL)/frame.html"></iframe>
                <object data="\(httpsBaseURL)/object.svg"></object>
                <meta http-equiv="refresh" content="0;url=\(httpBaseURL)/redirected.html">
                <a href="\(httpsBaseURL)/new-window.html" target="_blank">NEW-WINDOW-BLOCKED</a>
                """
            ]
        )

        var completionCount = 0
        let document = try await withCheckedThrowingContinuation { continuation in
            let renderer = makeRenderer()
            renderer.render(payload: payload) { [renderer] result in
                _ = renderer
                completionCount += 1
                if completionCount == 1 {
                    continuation.resume(with: result)
                }
            }
        }

        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(document.pageCount, 1)
        XCTAssertTrue(document.page(at: 0)?.string?.contains("NETWORK-BLOCKED") == true)
        XCTAssertEqual(completionCount, 1)
        XCTAssertEqual(probe.acceptedConnectionCount, 0)
    }

    func testRendererBlocksFileImageAndStylesheetResources() async throws {
        let fixtureDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: fixtureDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: fixtureDirectory) }

        let imageURL = fixtureDirectory.appendingPathComponent("blocked.png")
        try pngData(color: .red).write(to: imageURL)
        let stylesheetURL = fixtureDirectory.appendingPathComponent("blocked.css")
        try ".file-import { fill: #ff0000; }".write(
            to: stylesheetURL,
            atomically: true,
            encoding: .utf8
        )

        let payload = try RhwpStudioPagePayload(
            fileName: "file-resource-blocking.hwp",
            pageCount: 1,
            pages: [
                """
                <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
                     width="200" height="300" viewBox="0 0 200 300">
                  <style>@import url("\(stylesheetURL.absoluteString)");</style>
                  <rect class="file-import" width="200" height="300" fill="#00ff00" />
                  <image href="\(imageURL.absoluteString)" width="100" height="150" />
                  <image xlink:href="\(imageURL.absoluteString)" y="150" width="100" height="150" />
                </svg>
                """
            ]
        )

        let document = try await render(payload)
        let page = try XCTUnwrap(document.page(at: 0))
        let redFraction = try pixelFraction(on: page) { color in
            color.redComponent > 0.8 && color.greenComponent < 0.4 && color.blueComponent < 0.4
        }
        let greenFraction = try pixelFraction(on: page) { color in
            color.greenComponent > 0.8 && color.redComponent < 0.6 && color.blueComponent < 0.5
        }
        XCTAssertLessThan(redFraction, 0.05)
        XCTAssertGreaterThan(greenFraction, 0.5)
    }

    func testMetricsRejectMissingAndNonPositiveDimensions() {
        XCTAssertThrowsError(
            try RhwpStudioPagePDFMetrics.size(fromMetrics: nil, pageNumber: 1)
        )
        XCTAssertThrowsError(
            try RhwpStudioPagePDFMetrics.size(
                fromMetrics: ["width": 0, "height": 100],
                pageNumber: 1
            )
        )
    }

    func testRendererFinishesWhenWebContentProcessTerminates() throws {
        let payload = try RhwpStudioPagePayload(
            fileName: "terminated.hwp",
            pageCount: 1,
            pages: [svg(width: 200, height: 300, text: "Terminated")]
        )
        var ownedWebView: WKWebView?
        let renderer = makeRenderer(webViewObserver: { ownedWebView = $0 })
        var completionResult: Result<PDFDocument, Error>?

        renderer.render(payload: payload) { result in
            completionResult = result
        }
        renderer.webViewWebContentProcessDidTerminate(try XCTUnwrap(ownedWebView))

        guard case .failure(let error) = completionResult else {
            XCTFail("WebKit process 종료가 PDF 변환 실패로 완료되지 않았습니다.")
            return
        }
        XCTAssertEqual(
            error as? RhwpStudioPagePDFRenderError,
            .webContentProcessTerminated
        )
    }

    func testRendererIgnoresWebContentTerminationFromUnownedWebView() async throws {
        let payload = try RhwpStudioPagePayload(
            fileName: "foreign-termination.hwp",
            pageCount: 1,
            pages: [svg(width: 200, height: 300, text: "Foreign")]
        )
        let renderer = makeRenderer(pageRenderTimeoutNanoseconds: 0)
        var result: Result<PDFDocument, Error>?
        let completion = expectation(description: "current render timeout")

        renderer.render(payload: payload) {
            result = $0
            completion.fulfill()
        }
        renderer.webViewWebContentProcessDidTerminate(WKWebView())

        await fulfillment(of: [completion], timeout: 1)
        assertPageRenderTimedOut(try XCTUnwrap(result), page: 1)
    }

    func testRendererRejectsConcurrentRenderWithoutReplacingCurrentGeneration() async throws {
        let firstPayload = try RhwpStudioPagePayload(
            fileName: "first.hwp",
            pageCount: 1,
            pages: [svg(width: 200, height: 300, text: "First")]
        )
        let secondPayload = try RhwpStudioPagePayload(
            fileName: "second.hwp",
            pageCount: 1,
            pages: [svg(width: 200, height: 300, text: "Second")]
        )
        let renderer = makeRenderer(pageRenderTimeoutNanoseconds: 0)
        var firstResult: Result<PDFDocument, Error>?
        var secondResult: Result<PDFDocument, Error>?
        let firstCompletion = expectation(description: "first render timeout")

        renderer.render(payload: firstPayload) {
            firstResult = $0
            firstCompletion.fulfill()
        }
        renderer.render(payload: secondPayload) {
            secondResult = $0
        }

        guard case .failure(let concurrentError) = secondResult else {
            XCTFail("진행 중 두 번째 render가 즉시 거부되지 않았습니다.")
            return
        }
        XCTAssertEqual(
            concurrentError as? RhwpStudioPagePDFRenderError,
            .renderingInProgress
        )

        await fulfillment(of: [firstCompletion], timeout: 1)
        assertPageRenderTimedOut(try XCTUnwrap(firstResult), page: 1)
    }

    func testRendererPageTimeoutFinishesExactlyOnceAndAllowsRetry() async throws {
        let payload = try RhwpStudioPagePayload(
            fileName: "timeout.hwp",
            pageCount: 1,
            pages: [svg(width: 200, height: 300, text: "Timeout")]
        )
        let renderer = makeRenderer(pageRenderTimeoutNanoseconds: 0)
        var results: [Result<PDFDocument, Error>] = []

        let firstCompletion = expectation(description: "first timeout")
        renderer.render(payload: payload) { result in
            results.append(result)
            firstCompletion.fulfill()
        }
        await fulfillment(of: [firstCompletion], timeout: 1)
        renderer.webViewWebContentProcessDidTerminate(WKWebView())
        XCTAssertEqual(results.count, 1)
        assertPageRenderTimedOut(results[0], page: 1)

        let secondCompletion = expectation(description: "second timeout")
        renderer.render(payload: payload) { result in
            results.append(result)
            secondCompletion.fulfill()
        }
        await fulfillment(of: [secondCompletion], timeout: 1)
        XCTAssertEqual(results.count, 2)
        assertPageRenderTimedOut(results[1], page: 1)
    }

    private func render(_ payload: RhwpStudioPagePayload) async throws -> PDFDocument {
        try await withCheckedThrowingContinuation { continuation in
            let renderer = makeRenderer()
            renderer.render(payload: payload) { [renderer] result in
                _ = renderer
                continuation.resume(with: result)
            }
        }
    }

    private func makeRenderer(
        pageRenderTimeoutNanoseconds: UInt64? = nil,
        webViewObserver: ((WKWebView) -> Void)? = nil
    ) -> RhwpStudioPagePDFRenderer {
        let webViewFactory: @MainActor (WKWebViewConfiguration) -> WKWebView = { configuration in
            let webView = WKWebView(
                frame: NSRect(
                    origin: .zero,
                    size: RhwpStudioPagePDFMetrics.initialPageSize
                ),
                configuration: configuration
            )
            webViewObserver?(webView)
            return webView
        }
        if let pageRenderTimeoutNanoseconds {
            return RhwpStudioPagePDFRenderer(
                pageRenderTimeoutNanoseconds: pageRenderTimeoutNanoseconds,
                fontResourceProvider: fontResourceProvider(),
                webViewFactory: webViewFactory
            )
        }
        return RhwpStudioPagePDFRenderer(
            fontResourceProvider: fontResourceProvider(),
            webViewFactory: webViewFactory
        )
    }

    private func fontResourceProvider() -> RhwpStudioPDFFontDirectoryResourceProvider {
        RhwpStudioPDFFontDirectoryResourceProvider(
            directoryURL: repositoryRootURL
                .appendingPathComponent("Sources/HostApp/Resources/rhwp-studio/fonts", isDirectory: true)
        )
    }

    private var repositoryRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func koreanMathSVG() -> String {
        """
        <svg xmlns="http://www.w3.org/2000/svg" width="500" height="300" viewBox="0 0 500 300">
          <rect width="500" height="300" fill="white" />
          <text x="40" y="70"
                font-family="'Haansoft Dotum','Malgun Gothic','Noto Sans KR',sans-serif"
                font-size="28" font-weight="bold">문1 함수의 값은 다음과 같다</text>
          <text x="40" y="125"
                font-family="'Haansoft Batang','Batang','Noto Serif KR',serif"
                font-size="24">한글 본문과 선택지</text>
          <text x="40" y="180"
                font-family="'Latin Modern Math','STIX Two Math',serif"
                font-size="28">f(x)=x²+2x+1</text>
        </svg>
        """
    }

    private func svg(width: Int, height: Int, text: String) -> String {
        """
        <svg xmlns="http://www.w3.org/2000/svg" width="\(width)" height="\(height)" viewBox="0 0 \(width) \(height)">
          <rect width="\(width)" height="\(height)" fill="white" />
          <rect x="0" y="0" width="20" height="20" fill="#3366cc" />
          <text x="20" y="40" font-size="20" fill="black">\(text)</text>
        </svg>
        """
    }

    private func dataPNGDataURI(color: NSColor) throws -> String {
        "data:image/png;base64,\(try pngData(color: color).base64EncodedString())"
    }

    private func pngData(color: NSColor) throws -> Data {
        let image = NSImage(size: NSSize(width: 2, height: 2))
        image.lockFocus()
        color.setFill()
        NSRect(x: 0, y: 0, width: 2, height: 2).fill()
        image.unlockFocus()
        let tiffData = try XCTUnwrap(image.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: tiffData))
        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    }

    private func assertPageRenderTimedOut(
        _ result: Result<PDFDocument, Error>,
        page: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .failure(let error) = result else {
            XCTFail("PDF page timeout이 실패로 완료되지 않았습니다.", file: file, line: line)
            return
        }
        XCTAssertEqual(
            error as? RhwpStudioPagePDFRenderError,
            .pageRenderTimedOut(page),
            file: file,
            line: line
        )
    }

    private func pixelFraction(
        on page: PDFPage,
        matching predicate: (NSColor) -> Bool
    ) throws -> Double {
        let thumbnail = page.thumbnail(
            of: NSSize(width: 200, height: 300),
            for: .mediaBox
        )
        let representation = try XCTUnwrap(thumbnail.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: representation))
        var matchingPixels = 0
        let totalPixels = bitmap.pixelsWide * bitmap.pixelsHigh

        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
                    continue
                }
                if predicate(color) {
                    matchingPixels += 1
                }
            }
        }

        return Double(matchingPixels) / Double(totalPixels)
    }
}

private struct RejectingPDFFontResourceProvider: RhwpStudioPDFFontResourceProviding {
    let wrapped: RhwpStudioPDFFontDirectoryResourceProvider
    let rejectedResources: Set<RhwpStudioPDFFontResource>

    func data(for resource: RhwpStudioPDFFontResource) throws -> Data {
        guard !rejectedResources.contains(resource) else {
            throw RhwpStudioPDFFontResourceError.missingResource(resource.rawValue)
        }
        return try wrapped.data(for: resource)
    }
}

@MainActor
private final class LoopbackRequestProbe {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "com.postmelee.alhangeul.tests.pdf-network-probe")
    private var startContinuation: CheckedContinuation<Void, Error>?
    private var readinessTimeoutTask: Task<Void, Never>?
    private(set) var acceptedConnectionCount = 0

    var port: NWEndpoint.Port? {
        listener.port
    }

    init() throws {
        listener = try NWListener(using: .tcp, on: .any)
    }

    func start() async throws {
        try await withCheckedThrowingContinuation { continuation in
            startContinuation = continuation
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    self?.handleStateUpdate(state)
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                connection.cancel()
                Task { @MainActor in
                    self?.acceptedConnectionCount += 1
                }
            }
            listener.start(queue: queue)
            readinessTimeoutTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard !Task.isCancelled else {
                    return
                }
                self?.resolveStart(with: .failure(LoopbackRequestProbeError.readyTimedOut))
            }
        }
    }

    func stop() {
        readinessTimeoutTask?.cancel()
        readinessTimeoutTask = nil
        listener.cancel()
    }

    func waitForAcceptedConnection() async throws {
        for _ in 0..<100 {
            if acceptedConnectionCount > 0 {
                return
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        throw LoopbackRequestProbeError.connectionTimedOut
    }

    private func handleStateUpdate(_ state: NWListener.State) {
        switch state {
        case .ready:
            resolveStart(with: .success(()))
        case .failed(let error):
            resolveStart(with: .failure(error))
        case .cancelled:
            if startContinuation != nil {
                resolveStart(with: .failure(LoopbackRequestProbeError.cancelledBeforeReady))
            }
        case .setup, .waiting:
            break
        @unknown default:
            break
        }
    }

    private func resolveStart(with result: Result<Void, Error>) {
        readinessTimeoutTask?.cancel()
        readinessTimeoutTask = nil
        let continuation = startContinuation
        startContinuation = nil
        continuation?.resume(with: result)
    }
}

private enum LoopbackRequestProbeError: LocalizedError {
    case cancelledBeforeReady
    case connectionTimedOut
    case readyTimedOut

    var errorDescription: String? {
        switch self {
        case .cancelledBeforeReady:
            "loopback listener가 준비되기 전에 취소됐습니다."
        case .connectionTimedOut:
            "loopback listener 양성 대조 연결 시간이 초과됐습니다."
        case .readyTimedOut:
            "loopback listener 준비 시간이 초과됐습니다."
        }
    }
}
