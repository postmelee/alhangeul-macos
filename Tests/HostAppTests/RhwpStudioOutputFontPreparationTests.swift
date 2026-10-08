import AppKit
import PDFKit
import WebKit
import XCTest

private actor PreparationMeter {
    var reads = 0, releases = 0
    func read() { reads += 1 }
    func release() { releases += 1 }
}

@MainActor
final class RhwpStudioOutputFontPreparationTests: XCTestCase {
    override func setUp() { super.setUp(); _ = NSApplication.shared }

    private func makeJob(_ filename: String, meter: PreparationMeter,
                         current: @escaping @MainActor () async throws -> Bool = { true }) throws -> RhwpStudioOutputFontJob {
        let folder = try XCTUnwrap(Bundle(for:Self.self).url(forResource:"Fixtures",withExtension:nil))
        let bytes = try Data(contentsOf:folder.appendingPathComponent(filename))
        let face = try XCTUnwrap(FontFileInspector().inspect(bytes, filename:filename).faces.first)
        let row = StudioFontFace(id:"fixture", source:"managed", postScriptName:face.postScriptName,
            family:"OutputFixture", fullName:"OutputFixture Regular", style:"Regular", aliases:[],
            weight:400, traits:0, limitation:nil)
        let snapshot = StudioFontSupplySnapshot(identity:"fixture", faces:[row], omitted:0,failure:nil,
            read:{ _ in await meter.read(); return .init(data:bytes,face:face) }, current:{true},
            release:{await meter.release()})
        return .init(document:.init(loadToken:"doc",epoch:1,revision:1), snapshot:snapshot, documentIsCurrent:current,
            resolve:{ requests in
                .init(identity:"fixture",revision:"r1",generation:1,selections:requests.map {
                    let selected = $0.family == "OutputFixture"
                    return .init(key:$0.key,status:selected ? "selected" : "absent",id:selected ? "fixture" : nil,
                        postscriptName:selected ? face.postScriptName : nil,weight:selected ? 400 : nil,slant:selected ? "normal" : nil)
                })
            })
    }
    private func provider() -> RhwpStudioPDFFontDirectoryResourceProvider {
        let root = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return .init(directoryURL:root.appendingPathComponent("Sources/HostApp/Resources/rhwp-studio/fonts"))
    }
    private func payload() throws -> RhwpStudioPagePayload {
        try .init(fileName:"fixture.hwpx",pageCount:1,pages:["""
          <svg xmlns="http://www.w3.org/2000/svg" width="300" height="150">
            <text x="20" y="50" font-family="OutputFixture" font-size="24"><tspan>가A</tspan></text>
            <text x="20" y="110" font-family="OutputFixture" font-size="24" data-probe-owned="true">가A</text>
          </svg>
          """])
    }
    func testProductionPreparationEmbedsTTFAndCFFWithoutOverwritingTspanOrLease() async throws {
        for filename in ["regular.ttf","regular.otf"] {
            let meter = PreparationMeter(), job = try makeJob(filename,meter:meter)
            var renderer: RhwpStudioPagePDFRenderer? = .init(fontResourceProvider:provider(),outputFonts:job)
            let payload = try payload()
            let pdf: PDFDocument = try await withCheckedThrowingContinuation { done in
                renderer?.render(payload:payload) { done.resume(with:$0) }
            }
            XCTAssertEqual(pdf.findString("가A",withOptions:[]).count,2)
            let records = CGPDFFontResourceInspector.records(in:pdf)
            XCTAssertTrue(records.contains {$0.baseFont.contains("Fixture")},"\(records)")
            XCTAssertFalse(records.contains {$0.baseFont.contains("Noto")},"custom face overwritten")
            let reads = await meter.reads; XCTAssertEqual(reads,1)
            renderer = nil; await Task.yield()
            try await job.validate()
            let held = await meter.releases; XCTAssertEqual(held,0)
            await job.close()
            let released = await meter.releases; XCTAssertEqual(released,1)
        }
    }
    func testDocumentChangeAfterCreatePDFCallbackRejectsCompletion() async throws {
        var current = true
        let job = try makeJob("regular.ttf",meter:.init(),current:{current})
        let live = RhwpStudioPagePDFWebKitOperations.live(outputFonts:job)
        let operations = RhwpStudioPagePDFWebKitOperations(preparePage:live.preparePage,
            createPDF:{ view,config,done in
                live.createPDF(view,config) { result in current = false; done(result) }
            },cancelPreparation:live.cancelPreparation)
        let renderer = RhwpStudioPagePDFRenderer(fontResourceProvider:provider(),outputFonts:job,webKitOperations:operations)
        let result: Result<PDFDocument,Error> = await withCheckedContinuation { done in
            renderer.render(payload:try! payload()) { done.resume(returning:$0) }
        }
        if case .failure(let error) = result { XCTAssertEqual(error as? RhwpStudioOutputFontError,.stale) }
        else { XCTFail("stale PDF delivered") }
        await job.close()
    }
}
