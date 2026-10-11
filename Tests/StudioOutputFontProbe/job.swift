// Stage 2 제품 job·scheme·준비 검증. 실제 editor 진입은 Stage 3에서 연결한다.
import AppKit
import PDFKit
import WebKit

private actor JobMeter {
    var reads = 0, releases = 0
    func read() { reads += 1 }
    func release() { releases += 1 }
}

@MainActor
final class JobProbe: NSObject, NSApplicationDelegate {
    let root: URL, fonts: URL, output: URL
    let metadata: [[String: Any]]
    private let meter = JobMeter()
    private var started = false, finished = false
    private var renderer: RhwpStudioPagePDFRenderer?
    private var job: RhwpStudioOutputFontJob?
    private var window: NSWindow?
    init(root: URL, fonts: URL, output: URL, metadata: [[String: Any]]) {
        self.root = root; self.fonts = fonts; self.output = output; self.metadata = metadata
    }
    func applicationDidFinishLaunching(_ notification: Notification) { start() }
    func start() {
        guard !started else { return }; started = true
        do {
            let data = try Data(contentsOf: output.deletingLastPathComponent().appendingPathComponent("output-resolutions.json"))
            let table = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            let requests = try JSONDecoder().decode([RhwpStudioOutputFontRequest].self,
                from: JSONSerialization.data(withJSONObject: table["requests"]!))
            let selections = try JSONDecoder().decode([RhwpStudioOutputFontSelection].self,
                from: JSONSerialization.data(withJSONObject: table["selections"]!))
            let faces = metadata.map { row in
                StudioFontFace(id: row["id"] as! String, source: "managed", postScriptName: row["postscriptName"] as! String,
                    family: row["family"] as! String, fullName: row["fullName"] as! String, style: row["style"] as! String,
                    aliases: row["aliases"] as! [String], weight: row["weight"] as? Int, traits: 0, limitation: nil)
            }
            let fonts = fonts, metadata = metadata, meter = meter
            let snapshot = StudioFontSupplySnapshot(identity: "stage2-fixture", faces: faces, omitted: 0, failure: nil,
                read: { id in
                    await meter.read()
                    return try await Task.detached {
                        guard let row = metadata.first(where: { $0["id"] as? String == id }) else { throw problem(404) }
                        let bytes = try Data(contentsOf: fonts.appendingPathComponent(row["file"] as! String))
                        guard fontSHA256(bytes) == row["sha256"] as? String else { throw problem(409) }
                        let face = try FontFileInspector().inspect(bytes, filename: row["file"] as! String).faces[0]
                        return StudioFontBytes(data: bytes, face: face)
                    }.value
                }, current: { true }, release: { await meter.release() })
            let job = RhwpStudioOutputFontJob(document: .init(loadToken: "fixture", epoch: 1, revision: 1),
                snapshot: snapshot, documentIsCurrent: { true }, resolve: { input in
                    let result = try input.map { r -> RhwpStudioOutputFontSelection in
                        guard let index = requests.firstIndex(where: { $0.family == r.family && $0.weight == r.weight && $0.slant == r.slant })
                        else { throw problem(422) }
                        let s = selections[index]
                        return .init(key: r.key, status: s.status, id: s.id, postscriptName: s.postscriptName, weight: s.weight, slant: s.slant)
                    }
                    return .init(identity: snapshot.identity, revision: table["revision"] as! String,
                                 generation: table["generation"] as! Int, selections: result)
                })
            self.job = job
            let provider = RhwpStudioPDFFontDirectoryResourceProvider(directoryURL: root.appendingPathComponent("Sources/HostApp/Resources/rhwp-studio/fonts"))
            renderer = RhwpStudioPagePDFRenderer(fontResourceProvider: provider, outputFonts: job,
                webViewFactory: { [weak self] config in
                    precondition(!config.websiteDataStore.isPersistent && !config.defaultWebpagePreferences.allowsContentJavaScript)
                    let view = WKWebView(frame: NSRect(x:0,y:0,width:794,height:1123), configuration: config)
                    let window = NSWindow(contentRect: view.frame, styleMask:[.titled], backing:.buffered, defer:false)
                    window.title = "알한글 — 출력 글꼴 공급 · Stage 2 격리 검증"
                    window.contentView = view; window.orderFront(nil); self?.window = window
                    return view
                })
            let svg = try String(contentsOf: output.deletingLastPathComponent().appendingPathComponent("sample.svg"), encoding:.utf8)
            renderer?.render(payload: try .init(fileName:"합성 출력.hwpx", pageCount:1, pages:[svg])) { [weak self] result in
                Task { await self?.finish(result) }
            }
            DispatchQueue.main.asyncAfter(deadline:.now()+45) { [weak self] in
                Task { await self?.finish(.failure(problem(408))) }
            }
        } catch { Task { await finish(.failure(error)) } }
    }
    private func finish(_ result: Result<PDFDocument, Error>) async {
        guard !finished else { return }; finished = true
        do {
            let pdf = try result.get()
            try await job?.validate()
            let bytes = pdf.dataRepresentation()!, page = pdf.page(at:0)!
            try bytes.write(to: output.appendingPathComponent("sample.pdf"))
            var report: [String: Any] = ["mode":"job", "status":"rendered", "pages":pdf.pageCount,
                "text":pdf.string ?? "", "selectionText":page.selection(for:page.bounds(for:.mediaBox))?.string ?? "",
                "matches":pdf.findString("한글",withOptions:[]).count, "pdfSHA256":fontSHA256(bytes),
                "sourceReads":await meter.reads, "residentBytes":job?.residentBytes ?? 0,
                "productionPreparation":true, "editorBinding":"fixture resolver with actual adapted module results",
                "events":[], "preparation":[:]]
            await job?.close()
            report["releases"] = await meter.releases; report["residentAfterClose"] = job?.residentBytes ?? -1
            try writeJSON(report, output.appendingPathComponent("result.json"))
            window?.close(); exit(0)
        } catch {
            await job?.close()
            try? writeJSON(["status":"failed","error":String(describing:error)], output.appendingPathComponent("result.json"))
            fputs("Stage 2 출력 검증 실패: \(error)\n",stderr); window?.close(); exit(1)
        }
    }
}
