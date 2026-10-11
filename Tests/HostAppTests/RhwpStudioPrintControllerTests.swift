import AppKit
import PDFKit
import XCTest

private actor PrintLeaseMeter {
    var releases = 0
    func release() { releases += 1 }
}

@MainActor
final class RhwpStudioPrintControllerTests: XCTestCase {
    override func setUp() { super.setUp(); _ = NSApplication.shared }
    private func payload() throws -> RhwpStudioPagePayload {
        try .init(fileName:"print.hwpx",pageCount:1,pages:["""
        <svg xmlns="http://www.w3.org/2000/svg" width="200" height="300"><text x="20" y="50" font-family="sans-serif" font-size="20">print ABC</text></svg>
        """])
    }
    private func job(_ meter: PrintLeaseMeter,current: @escaping @MainActor () async throws -> Bool = {true}) -> RhwpStudioOutputFontJob {
        .init(document:.init(loadToken:"test",epoch:1,revision:1),snapshot:.init(identity:"empty",faces:[],omitted:0,failure:nil,
            read:{ _ in XCTFail("absent font read"); throw RhwpStudioOutputFontError.unavailable },
            current:{true},release:{await meter.release()}),documentIsCurrent:current,resolve:{ requests in
                .init(identity:"empty",revision:"r1",generation:1,selections:requests.map {
                    .init(key:$0.key,status:"absent",id:nil,postscriptName:nil,weight:nil,slant:nil)
                })
            })
    }
    private func renderer(_ job: RhwpStudioOutputFontJob? = nil) -> RhwpStudioPagePDFRenderer {
        let root = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return .init(fontResourceProvider:RhwpStudioPDFFontDirectoryResourceProvider(directoryURL:root.appendingPathComponent("Sources/HostApp/Resources/rhwp-studio/fonts")),outputFonts:job)
    }
    func testSealReleasesEditorFenceButRetainsLeaseUntilOperationReturns() async throws {
        let meter = PrintLeaseMeter(); var current = true, operationCalls = 0, leaseBeforePanel = -1
        let job = job(meter,current:{current})
        var result: RhwpStudioPrintResult?
        let controller = RhwpStudioPrintController(renderer:renderer(job),outputFonts:job,onSealed:{
            leaseBeforePanel = await meter.releases
            current = false // 패널 이후의 문서 변화는 확정 PDF를 교체하지 않는다.
        },runOperation:{ pdf,_ in
            operationCalls += 1
            XCTAssertTrue(pdf.string?.contains("print ABC") == true)
            return true
        },onResult:{result = $0},presentError:{XCTFail("unexpected \($0)")})
        await withCheckedContinuation { done in controller.print(payload:try! payload()) { done.resume() } }
        XCTAssertEqual(operationCalls,1); XCTAssertEqual(leaseBeforePanel,0)
        let released = await meter.releases; XCTAssertEqual(released,1)
        if case .completed = result {} else { XCTFail("sealed output did not complete") }
        XCTAssertEqual(job.residentBytes,0)
    }
    func testPanelCancellationAndUnavailableOperationHaveDifferentResults() async throws {
        for available in [true,false] {
            var result: RhwpStudioPrintResult?, errors = 0
            let controller = RhwpStudioPrintController(renderer:renderer(),runOperation:{_,_ in available ? false : nil},
                onResult:{result = $0},presentError:{_ in errors += 1})
            await withCheckedContinuation { done in controller.print(payload:try! payload()) { done.resume() } }
            if available {
                if case .cancelledOrFailed = result {} else { XCTFail("false operation reported success") }
                XCTAssertEqual(errors,0)
            } else {
                if case .failed = result {} else { XCTFail("nil operation not failed") }
                XCTAssertEqual(errors,1)
            }
        }
    }
    func testCancelBeforePanelSuppressesLateRenderAndClosesLeaseOnce() async throws {
        let meter = PrintLeaseMeter(), job = job(meter); var operations = 0, results = 0
        let controller = RhwpStudioPrintController(renderer:renderer(job),outputFonts:job,runOperation:{_,_ in operations += 1; return true},
            onResult:{ result in
                results += 1
                if case .cancelledBeforePanel = result {} else { XCTFail("unexpected cancellation result") }
            },presentError:{XCTFail("unexpected \($0)")})
        let done = expectation(description:"cancel completes once")
        controller.print(payload:try payload()) { done.fulfill() }
        controller.cancel(); controller.cancel()
        await fulfillment(of:[done],timeout:5)
        try await Task.sleep(nanoseconds:150_000_000)
        XCTAssertEqual(operations,0); XCTAssertEqual(results,1)
        let released = await meter.releases; XCTAssertEqual(released,1)
    }
    func testStaleDocumentNeverOpensPanelAndReleasesLease() async throws {
        let meter = PrintLeaseMeter(), job = job(meter,current:{false}); var operations = 0, error: Error?
        let controller = RhwpStudioPrintController(renderer:renderer(job),outputFonts:job,runOperation:{_,_ in operations += 1; return true},
            presentError:{error = $0})
        await withCheckedContinuation { done in controller.print(payload:try! payload()) { done.resume() } }
        XCTAssertEqual(error as? RhwpStudioOutputFontError,.stale); XCTAssertEqual(operations,0)
        let released = await meter.releases; XCTAssertEqual(released,1)
    }
}
