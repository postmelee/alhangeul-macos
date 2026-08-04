import Foundation
import PDFKit
import XCTest

@MainActor
final class RhwpStudioPDFExportControllerTests: XCTestCase {
    func testExportWritesSearchablePDFAndPreservesPageGeometry() async throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("rhwp-pdf-export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        let destinationURL = temporaryDirectory.appendingPathComponent("output.pdf")
        let payload = try RhwpStudioPagePayload(
            fileName: "mixed.hwpx",
            pageCount: 2,
            pages: [
                svg(width: 200, height: 300, text: "Portrait export"),
                svg(width: 300, height: 200, text: "Landscape export")
            ]
        )

        let exportedURL = try await export(payload: payload, to: destinationURL)
        XCTAssertEqual(exportedURL, destinationURL)

        let data = try Data(contentsOf: destinationURL)
        XCTAssertTrue(data.starts(with: Data("%PDF".utf8)))
        let document = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertEqual(document.pageCount, 2)
        XCTAssertTrue(document.page(at: 0)?.string?.contains("Portrait export") == true)
        XCTAssertTrue(document.page(at: 1)?.string?.contains("Landscape export") == true)

        let portraitBounds = try XCTUnwrap(document.page(at: 0)?.bounds(for: .mediaBox))
        let landscapeBounds = try XCTUnwrap(document.page(at: 1)?.bounds(for: .mediaBox))
        XCTAssertLessThan(portraitBounds.width, portraitBounds.height)
        XCTAssertGreaterThan(landscapeBounds.width, landscapeBounds.height)
    }

    func testSecondExportIsRejectedWhileRenderingIsInProgress() throws {
        let controller = RhwpStudioPDFExportController()
        let payload = try RhwpStudioPagePayload(
            fileName: "duplicate.hwp",
            pageCount: 1,
            pages: [svg(width: 200, height: 300, text: "First export")]
        )
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("rhwp-pdf-duplicate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let firstCompletion = expectation(description: "first export completion")
        let duplicateCompletion = expectation(description: "duplicate export rejection")
        controller.export(
            payload: payload,
            destinationURL: directory.appendingPathComponent("first.pdf")
        ) { result in
            if case .failure(let error) = result {
                XCTFail("첫 번째 PDF 내보내기가 실패했습니다: \(error)")
            }
            firstCompletion.fulfill()
        }
        controller.export(
            payload: payload,
            destinationURL: directory.appendingPathComponent("duplicate.pdf")
        ) { result in
            switch result {
            case .success:
                XCTFail("중복 PDF 내보내기가 성공했습니다.")
            case .failure(let error):
                XCTAssertEqual(
                    error as? RhwpStudioPDFExportError,
                    .exportInProgress
                )
            }
            duplicateCompletion.fulfill()
        }

        wait(for: [duplicateCompletion, firstCompletion], timeout: 5)
    }

    private func export(
        payload: RhwpStudioPagePayload,
        to destinationURL: URL
    ) async throws -> URL {
        let controller = RhwpStudioPDFExportController()
        return try await withCheckedThrowingContinuation { continuation in
            controller.export(payload: payload, destinationURL: destinationURL) { [controller] result in
                _ = controller
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
