import AppKit
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
            "font-src 'none'"
        ].joined(separator: "; ") + ";"
        XCTAssertEqual(RhwpStudioPagePDFHTML.contentSecurityPolicy, expectedPolicy)
        XCTAssertFalse(RhwpStudioPagePDFHTML.contentSecurityPolicy.contains("font-src data:"))
        XCTAssertFalse(RhwpStudioPagePDFHTML.contentSecurityPolicy.contains("http:"))
        XCTAssertFalse(RhwpStudioPagePDFHTML.contentSecurityPolicy.contains("https:"))
        XCTAssertFalse(RhwpStudioPagePDFHTML.contentSecurityPolicy.contains("blob:"))

        let svg = "<svg id=\"document-svg\" xmlns=\"http://www.w3.org/2000/svg\"></svg>"
        let html = RhwpStudioPagePDFHTML.pageHTML(for: svg)
        let cspRange = try XCTUnwrap(
            html.range(of: "<meta http-equiv=\"Content-Security-Policy\"")
        )
        let svgRange = try XCTUnwrap(html.range(of: "<svg id=\"document-svg\""))
        XCTAssertLessThan(cspRange.lowerBound, svgRange.lowerBound)
        XCTAssertTrue(html.contains("content=\"\(expectedPolicy)\""))
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
        XCTAssertLessThan(portraitBounds.width, portraitBounds.height)
        XCTAssertGreaterThan(landscapeBounds.width, landscapeBounds.height)

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
        let renderer = RhwpStudioPagePDFRenderer()
        var completionResult: Result<PDFDocument, Error>?

        renderer.render(payload: payload) { result in
            completionResult = result
        }
        renderer.webViewWebContentProcessDidTerminate(WKWebView())

        guard case .failure(let error) = completionResult else {
            XCTFail("WebKit process 종료가 PDF 변환 실패로 완료되지 않았습니다.")
            return
        }
        XCTAssertEqual(
            error as? RhwpStudioPagePDFRenderError,
            .webContentProcessTerminated
        )
    }

    private func render(_ payload: RhwpStudioPagePayload) async throws -> PDFDocument {
        try await withCheckedThrowingContinuation { continuation in
            let renderer = RhwpStudioPagePDFRenderer()
            renderer.render(payload: payload) { [renderer] result in
                _ = renderer
                continuation.resume(with: result)
            }
        }
    }

    private func svg(width: Int, height: Int, text: String) -> String {
        """
        <svg xmlns="http://www.w3.org/2000/svg" width="\(width)" height="\(height)" viewBox="0 0 \(width) \(height)">
          <rect width="\(width)" height="\(height)" fill="white" />
          <text x="20" y="40" font-size="20" fill="black">\(text)</text>
        </svg>
        """
    }

    private func dataPNGDataURI(color: NSColor) throws -> String {
        let image = NSImage(size: NSSize(width: 2, height: 2))
        image.lockFocus()
        color.setFill()
        NSRect(x: 0, y: 0, width: 2, height: 2).fill()
        image.unlockFocus()
        let tiffData = try XCTUnwrap(image.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: tiffData))
        let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        return "data:image/png;base64,\(data.base64EncodedString())"
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
