import XCTest

final class RhwpStudioPagePayloadTests: XCTestCase {
    func testSingleAndMultiplePagePayloadsAreAccepted() throws {
        let singlePage = try RhwpStudioPagePayload(
            fileName: "single.hwp",
            pageCount: 1,
            pages: ["<svg>single</svg>"]
        )
        XCTAssertEqual(singlePage.fileName, "single.hwp")
        XCTAssertEqual(singlePage.pageCount, 1)
        XCTAssertEqual(singlePage.pages, ["<svg>single</svg>"])

        let multiplePages = try RhwpStudioPagePayload(
            fileName: "multiple.hwpx",
            pageCount: 2,
            pages: ["<svg>first</svg>", "<svg>second</svg>"]
        )
        XCTAssertEqual(multiplePages.pageCount, 2)
        XCTAssertEqual(multiplePages.pages.count, 2)
    }

    func testNonPositivePageCountIsRejected() {
        XCTAssertThrowsError(
            try RhwpStudioPagePayload(fileName: "empty.hwp", pageCount: 0, pages: [])
        ) { error in
            XCTAssertEqual(error as? RhwpStudioPagePayloadError, .invalidPageCount(0))
        }
    }

    func testPageCountMismatchIsRejected() {
        XCTAssertThrowsError(
            try RhwpStudioPagePayload(
                fileName: "mismatch.hwp",
                pageCount: 2,
                pages: ["<svg>only</svg>"]
            )
        ) { error in
            XCTAssertEqual(
                error as? RhwpStudioPagePayloadError,
                .pageCountMismatch(expected: 2, actual: 1)
            )
        }
    }

    func testWhitespaceOnlySVGIsRejectedWithOneBasedPageNumber() {
        XCTAssertThrowsError(
            try RhwpStudioPagePayload(
                fileName: "empty-page.hwpx",
                pageCount: 2,
                pages: ["<svg>first</svg>", " \n\t "]
            )
        ) { error in
            XCTAssertEqual(error as? RhwpStudioPagePayloadError, .emptyPage(2))
        }
    }
}
