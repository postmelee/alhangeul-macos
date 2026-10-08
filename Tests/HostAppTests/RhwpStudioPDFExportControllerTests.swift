import AppKit
import PDFKit
import XCTest

private actor PDFExportLeaseMeter {
    var releases = 0
    func release() { releases += 1 }
}

@MainActor
final class RhwpStudioPDFExportControllerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        _ = NSApplication.shared
    }

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
                svg(width: 200, height: 300, text: "세로 문1 함수"),
                svg(width: 300, height: 200, text: "가로 값은")
            ]
        )

        let exportedURL = try await export(payload: payload, to: destinationURL)
        XCTAssertEqual(exportedURL, destinationURL)

        let data = try Data(contentsOf: destinationURL)
        XCTAssertTrue(data.starts(with: Data("%PDF".utf8)))
        let document = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertEqual(document.pageCount, 2)
        XCTAssertTrue(document.page(at: 0)?.string?.contains("세로 문1 함수") == true)
        XCTAssertTrue(document.page(at: 1)?.string?.contains("가로 값은") == true)
        XCTAssertGreaterThan(document.findString("문1", withOptions: []).count, 0)
        XCTAssertGreaterThan(document.findString("함수", withOptions: []).count, 0)
        XCTAssertGreaterThan(document.findString("값은", withOptions: []).count, 0)

        let portraitBounds = try XCTUnwrap(document.page(at: 0)?.bounds(for: .mediaBox))
        let landscapeBounds = try XCTUnwrap(document.page(at: 1)?.bounds(for: .mediaBox))
        XCTAssertLessThan(portraitBounds.width, portraitBounds.height)
        XCTAssertGreaterThan(landscapeBounds.width, landscapeBounds.height)
    }

    func testSecondExportIsRejectedWhileRenderingIsInProgress() throws {
        let controller = makeController()
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

    func testCancelledFinalValidationCannotOverwriteDestinationOrFinishNextExport() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:folder) }
        let destination = folder.appendingPathComponent("existing.pdf"), original = Data("keep original".utf8)
        try original.write(to:destination)
        let controller = makeController(), payload = try RhwpStudioPagePayload(fileName:"a.hwpx",pageCount:1,pages:[svg(width:200,height:300,text:"문서")])
        let validating = expectation(description:"validation paused"), cancelled = expectation(description:"cancelled once")
        var resumeValidation: CheckedContinuation<Void,Never>?, firstCalls = 0
        controller.export(payload:payload,destinationURL:destination,validateBeforeWrite:{
            await withCheckedContinuation { resumeValidation = $0; validating.fulfill() }
        }) { result in
            firstCalls += 1
            if case .failure(let error) = result { XCTAssertEqual(error as? RhwpStudioOutputFontError,.cancelled) }
            else { XCTFail("cancel delivered success") }
            cancelled.fulfill()
        }
        await fulfillment(of:[validating],timeout:5)
        controller.cancel()
        await fulfillment(of:[cancelled],timeout:5)
        let next = expectation(description:"next export completes")
        controller.export(payload:payload,destinationURL:folder.appendingPathComponent("next.pdf")) {
            if case .failure(let error) = $0 { XCTFail("late old task cancelled new export: \(error)") }
            next.fulfill()
        }
        resumeValidation?.resume()
        await fulfillment(of:[next],timeout:5)
        XCTAssertEqual(try Data(contentsOf:destination),original)
        XCTAssertEqual(firstCalls,1)
    }

    func testFinalValidationAndAtomicWriteFailuresPreserveExistingDestination() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:folder) }
        let destination = folder.appendingPathComponent("existing.pdf"), original = Data("keep original".utf8)
        try original.write(to:destination)
        let controller = makeController(), payload = try RhwpStudioPagePayload(fileName:"a.hwpx",pageCount:1,pages:[svg(width:200,height:300,text:"문서")])
        let result: Result<URL,Error> = await withCheckedContinuation { done in
            controller.export(payload:payload,destinationURL:destination,validateBeforeWrite:{ throw RhwpStudioOutputFontError.stale }) { done.resume(returning:$0) }
        }
        if case .failure(let error) = result { XCTAssertEqual(error as? RhwpStudioOutputFontError,.stale) }
        else { XCTFail("stale output written") }
        XCTAssertEqual(try Data(contentsOf:destination),original)
        let failed: Result<URL,Error> = await withCheckedContinuation { done in
            controller.export(payload:payload,destinationURL:folder.appendingPathComponent("missing/out.pdf")) { done.resume(returning:$0) }
        }
        if case .success = failed { XCTFail("unwritable output succeeded") }
        XCTAssertEqual(try Data(contentsOf:destination),original)
    }

    func testWriteFailureClosesOutputLeaseBeforeCompletion() async throws {
        let meter = PDFExportLeaseMeter()
        let job = RhwpStudioOutputFontJob(document:.init(loadToken:"test",epoch:1,revision:1),
            snapshot:.init(identity:"empty",faces:[],omitted:0,failure:nil,
                read:{_ in throw RhwpStudioOutputFontError.unavailable},current:{true},release:{await meter.release()}),
            documentIsCurrent:{true},resolve:{requests in
                .init(identity:"empty",revision:"r1",generation:1,selections:requests.map {
                    .init(key:$0.key,status:"absent",id:nil,postscriptName:nil,weight:nil,slant:nil)
                })
            })
        let controller = makeController(outputFonts:job)
        let payload = try RhwpStudioPagePayload(fileName:"a.hwpx",pageCount:1,pages:[svg(width:200,height:300,text:"문서")])
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "/missing/out.pdf")
        let result: Result<URL,Error> = await withCheckedContinuation { done in
            controller.export(payload:payload,destinationURL:destination) { done.resume(returning:$0) }
        }
        if case .success = result { XCTFail("write failure succeeded") }
        let released = await meter.releases; XCTAssertEqual(released,1)
        XCTAssertEqual(job.residentBytes,0)
    }

    private func export(
        payload: RhwpStudioPagePayload,
        to destinationURL: URL
    ) async throws -> URL {
        let controller = makeController()
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
          <text x="20" y="40" font-family="'Haansoft Dotum','Noto Sans KR',sans-serif"
                font-size="20" fill="black">\(text)</text>
        </svg>
        """
    }

    private func makeController(outputFonts: RhwpStudioOutputFontJob? = nil) -> RhwpStudioPDFExportController {
        RhwpStudioPDFExportController(renderer: RhwpStudioPagePDFRenderer(
            fontResourceProvider: RhwpStudioPDFFontDirectoryResourceProvider(
                directoryURL: repositoryRootURL
                    .appendingPathComponent("Sources/HostApp/Resources/rhwp-studio/fonts", isDirectory: true)
            ),outputFonts:outputFonts
        ),outputFonts:outputFonts)
    }

    private var repositoryRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
