import AppKit
import PDFKit
import XCTest

final class RhwpStudioPrintOrientationPolicyTests: XCTestCase {
    func testUniformLandscapePagesUseLandscapeOrientation() {
        let document = document(pageSizes: [
            NSSize(width: 1123, height: 794),
            NSSize(width: 300, height: 200)
        ])

        XCTAssertEqual(
            RhwpStudioPrintOrientationPolicy.orientation(for: document),
            .landscape
        )
    }

    func testUniformPortraitPagesUsePortraitOrientation() {
        let document = document(pageSizes: [
            NSSize(width: 794, height: 1123),
            NSSize(width: 200, height: 300)
        ])

        XCTAssertEqual(
            RhwpStudioPrintOrientationPolicy.orientation(for: document),
            .portrait
        )
    }

    func testMixedPageOrientationsDoNotForceJobOrientation() {
        let document = document(pageSizes: [
            NSSize(width: 1123, height: 794),
            NSSize(width: 794, height: 1123)
        ])

        XCTAssertNil(RhwpStudioPrintOrientationPolicy.orientation(for: document))
    }

    func testSquarePagesDoNotOverrideUniformPageOrientation() {
        let document = document(pageSizes: [
            NSSize(width: 500, height: 500),
            NSSize(width: 1123, height: 794)
        ])

        XCTAssertEqual(
            RhwpStudioPrintOrientationPolicy.orientation(for: document),
            .landscape
        )
    }

    func testEmptyAndSquareOnlyDocumentsDoNotForceOrientation() {
        XCTAssertNil(
            RhwpStudioPrintOrientationPolicy.orientation(for: PDFDocument())
        )
        XCTAssertNil(
            RhwpStudioPrintOrientationPolicy.orientation(
                for: document(pageSizes: [NSSize(width: 500, height: 500)])
            )
        )
    }

    private func document(pageSizes: [NSSize]) -> PDFDocument {
        let document = PDFDocument()
        for pageSize in pageSizes {
            let page = PDFPage()
            page.setBounds(NSRect(origin: .zero, size: pageSize), for: .mediaBox)
            document.insert(page, at: document.pageCount)
        }
        return document
    }
}
