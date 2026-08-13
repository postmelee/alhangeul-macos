import Foundation

struct RhwpStudioPagePayload {
    let fileName: String
    let pageCount: Int
    let pages: [String]

    init(fileName: String, pageCount: Int, pages: [String]) throws {
        guard pageCount > 0 else {
            throw RhwpStudioPagePayloadError.invalidPageCount(pageCount)
        }
        guard pages.count == pageCount else {
            throw RhwpStudioPagePayloadError.pageCountMismatch(
                expected: pageCount,
                actual: pages.count
            )
        }
        if let emptyPageIndex = pages.firstIndex(where: {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) {
            throw RhwpStudioPagePayloadError.emptyPage(emptyPageIndex + 1)
        }

        self.fileName = fileName
        self.pageCount = pageCount
        self.pages = pages
    }
}

enum RhwpStudioPagePayloadError: LocalizedError, Equatable {
    case invalidPageCount(Int)
    case pageCountMismatch(expected: Int, actual: Int)
    case emptyPage(Int)

    var errorDescription: String? {
        switch self {
        case .invalidPageCount(let pageCount):
            "페이지 수가 올바르지 않습니다: \(pageCount)"
        case .pageCountMismatch(let expected, let actual):
            "페이지 수와 SVG 개수가 일치하지 않습니다: expected=\(expected), actual=\(actual)"
        case .emptyPage(let page):
            "\(page)페이지 SVG가 비어 있습니다."
        }
    }
}
