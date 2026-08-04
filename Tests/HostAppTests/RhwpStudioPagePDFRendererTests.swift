import AppKit
import PDFKit
import XCTest

@MainActor
final class RhwpStudioPagePDFRendererTests: XCTestCase {
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
}
