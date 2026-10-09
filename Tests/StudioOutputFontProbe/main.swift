// Task #568 Stage 1. 제품 renderer 기준선과 준비 script 후보의 격리 실험.
import AppKit
import WebKit
import PDFKit
import CoreText
import CryptoKit

func fontSHA256(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
func writeJSON(_ value: Any, _ url: URL) throws {
    try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .prettyPrinted]).write(to: url)
}
func problem(_ code: Int) -> Error { NSError(domain: "StudioOutputFontProbe", code: code) }

final class ProbeResources: NSObject, WKURLSchemeHandler {
    let fonts: URL
    let metadata: [[String: Any]]
    let bundleProvider: RhwpStudioPDFFontDirectoryResourceProvider
    let token = UUID().uuidString
    let missing: Bool
    var cached: [String: Data] = [:]
    var events: [[String: Any]] = []
    var reads = 0
    init(root: URL, fonts: URL, metadata: [[String: Any]], missing: Bool) {
        self.fonts = fonts; self.metadata = metadata; self.missing = missing
        bundleProvider = .init(directoryURL: root.appendingPathComponent("Sources/HostApp/Resources/rhwp-studio/fonts"))
    }
    func url(_ id: String) -> String { "alhangeul-pdf-font://snapshot/\(token)/\(id)" }
    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        do {
            guard let url = task.request.url else { throw problem(400) }
            let data: Data
            let mime: String
            if let resource = try? RhwpStudioPDFFontRoute.resource(for: url) {
                data = try bundleProvider.data(for: resource); mime = "font/woff2"
                events.append(["source": "noto", "id": resource.rawValue])
            } else {
                guard let row = metadata.first(where: { self.url($0["id"] as! String) == url.absoluteString }),
                      let id = row["id"] as? String else { throw problem(403) }
                if missing && id == "bold" { throw problem(404) }
                if let previous = cached[id] { data = previous }
                else {
                    let value = try Data(contentsOf: fonts.appendingPathComponent(row["file"] as! String))
                    let inspected = try FontFileInspector().inspect(value, filename: row["file"] as! String)
                    guard fontSHA256(value) == row["sha256"] as? String,
                          inspected.faces.first?.postScriptName == row["postscriptName"] as? String,
                          inspected.faces.first?.embeddingFlags == 0 else { throw problem(409) }
                    reads += 1; cached[id] = value; data = value
                }
                mime = "font/ttf"
                events.append(["source": "custom", "id": id, "sha256": fontSHA256(data), "bytes": data.count])
            }
            task.didReceive(URLResponse(url: url, mimeType: mime, expectedContentLength: data.count, textEncodingName: nil))
            task.didReceive(data); task.didFinish()
        } catch {
            events.append(["source": "rejected", "code": (error as NSError).code])
            task.didFailWithError(error)
        }
    }
    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}

@MainActor
final class Probe: NSObject, NSApplicationDelegate {
    let root: URL
    let output: URL
    let mode: String
    let resources: ProbeResources
    var renderer: RhwpStudioPagePDFRenderer!
    var preparation: [String: Any] = [:]
    var window: NSWindow?
    private var started = false
    init(root: URL, fonts: URL, output: URL, mode: String, metadata: [[String: Any]]) {
        self.root = root; self.output = output; self.mode = mode
        resources = ProbeResources(root: root, fonts: fonts, metadata: metadata, missing: mode == "missing")
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        start()
    }
    func start() {
        guard !started else { return }
        started = true
        fputs("probe 시작: \(mode)\n", stderr)
        let operations = RhwpStudioPagePDFWebKitOperations(preparePage: { [weak self] view, done in
            guard let self else { done(.failure(problem(410))); return }
            var body = RhwpStudioPagePDFHTML.pagePreparationScript
            if self.mode != "baseline" {
                if self.mode != "naive" {
                    let anchor = "document.querySelectorAll(\"svg text\")"
                    precondition(body.components(separatedBy: anchor).count == 2)
                    body = body.replacingOccurrences(of: anchor,
                        with: "Array.from(document.querySelectorAll(\"svg text\")).filter(node => !node.dataset.probeOwned)")
                }
                body = self.prefix + "\n" + body
            }
            let anchor = "return JSON.stringify({ width, height, fontFailureReason });"
            precondition(body.components(separatedBy: anchor).count == 2)
            body = body.replacingOccurrences(of: anchor, with: """
            return JSON.stringify({ width, height, fontFailureReason,
              loaded: Array.from(document.fonts).filter(f => f.status === 'loaded').map(f => ({family:f.family, weight:f.weight})),
              customComputed: Array.from(document.querySelectorAll('[data-face]')).map(n => ({face:n.dataset.face, family:getComputedStyle(n).fontFamily, weight:getComputedStyle(n).fontWeight,
                descendantFamilies:Array.from(n.querySelectorAll('tspan')).map(s => getComputedStyle(s).fontFamily)})) });
            """)
            let regularURL = self.resources.url("regular")
            let boldURL = self.mode == "wrong-token" ? self.resources.url("bold").replacingOccurrences(of: self.resources.token, with: "wrong") : self.resources.url("bold")
            view.callAsyncJavaScript(body, arguments: ["regularURL": regularURL, "boldURL": boldURL],
                                     in: nil, in: .defaultClient) { value in
                if case .success(let text as String) = value, let data = text.data(using: .utf8),
                   let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    self.preparation = parsed
                }
                done(value)
            }
        }, createPDF: { view, config, done in view.createPDF(configuration: config, completionHandler: done) })
        renderer = RhwpStudioPagePDFRenderer(fontResourceProvider: resources.bundleProvider,
            webKitOperations: operations, webViewFactory: { [weak self] config in
                guard let self else { fatalError() }
                precondition(!config.websiteDataStore.isPersistent && !config.defaultWebpagePreferences.allowsContentJavaScript)
                let effective: WKWebViewConfiguration
                if self.mode == "baseline" {
                    effective = config
                } else {
                    // WebKit은 등록 handler 교체를 허용하지 않는다. 제품 설정 3종을
                    // 같은 값으로 쓰는 시험 configuration에 격리 handler를 등록한다.
                    effective = WKWebViewConfiguration()
                    effective.websiteDataStore = config.websiteDataStore
                    effective.preferences = config.preferences
                    effective.defaultWebpagePreferences = config.defaultWebpagePreferences
                    effective.setURLSchemeHandler(self.resources, forURLScheme: RhwpStudioPDFFontRoute.scheme)
                }
                let view = WKWebView(frame: NSRect(x:0,y:0,width:794,height:1123), configuration: effective)
                let window = NSWindow(contentRect:view.frame, styleMask:[.titled], backing:.buffered, defer:false)
                window.title = "알한글 — PDF 글꼴 계약 · \(self.mode) 격리 실험"
                window.contentView = view; window.orderFront(nil); self.window = window
                return view
            })
        do {
            let svg = try String(contentsOf: output.deletingLastPathComponent().appendingPathComponent("sample.svg"), encoding:.utf8)
            let payload = try RhwpStudioPagePayload(fileName:"합성 글꼴 출력.hwp",pageCount:1,pages:[svg])
            renderer.render(payload:payload) { [weak self] value in self?.finish(value) }
        } catch { finish(.failure(error)) }
        DispatchQueue.main.asyncAfter(deadline:.now()+45) { [weak self] in self?.finish(.failure(problem(408))) }
    }
    var prefix: String {
        """
        const faces = [new FontFace('Stage568Regular', `url("${regularURL}")`, {weight:'400'}),
                       new FontFace('Stage568Bold', `url("${boldURL}")`, {weight:'700'})];
        for (const face of faces) document.fonts.add(face);
        await Promise.all(faces.map(f => f.load()));
        if (faces.some(f => f.status !== 'loaded')) throw new Error('custom face unavailable');
        for (const node of document.querySelectorAll('[data-face]')) {
          const name = node.dataset.face === 'bold' ? 'Stage568Bold' : 'Stage568Regular';
          node.style.setProperty('font-family', `"${name}"`, 'important');
          node.style.setProperty('font-synthesis', 'none');
          node.dataset.probeOwned = 'true';
        }
        """
    }
    func finish(_ value: Result<PDFDocument, Error>) {
        var report: [String: Any] = ["mode":mode,"os":ProcessInfo.processInfo.operatingSystemVersionString,
            "contentJS":false,"sourceReads":resources.reads,"residentBytes":resources.cached.values.reduce(0){$0+$1.count},
            "events":resources.events,"preparation":preparation]
        do {
            switch value {
            case .success(let pdf):
                guard mode != "missing" && mode != "wrong-token", let bytes = pdf.dataRepresentation() else { throw problem(422) }
                try bytes.write(to:output.appendingPathComponent("sample.pdf"))
                let text = pdf.string ?? ""
                let page = pdf.page(at:0)!
                report["status"] = "rendered"; report["pages"] = pdf.pageCount
                report["text"] = text; report["pdfSHA256"] = fontSHA256(bytes)
                report["selectionText"] = page.selection(for:page.bounds(for:.mediaBox))?.string ?? ""
                report["matches"] = pdf.findString("한글", withOptions:[]).count
                report["fontResources"] = CGPDFFontResourceInspector.records(in:pdf).map {
                    ["baseFont":$0.baseFont,"subtype":$0.subtype,"toUnicode":$0.hasToUnicode] as [String: Any]
                }
            case .failure(let error):
                guard mode == "missing" || mode == "wrong-token" else { throw error }
                report["status"] = "expected-rejection"; report["error"] = String(describing:error)
            }
            try writeJSON(report, output.appendingPathComponent("result.json"))
            window?.close(); exit(0)
        } catch {
            report["status"] = "failed"; report["errorCode"] = (error as NSError).code
            try? writeJSON(report,output.appendingPathComponent("result.json"))
            fputs("출력 probe 실패: \(error)\n",stderr); exit(1)
        }
    }
}

@main struct Main {
    @MainActor static func main() throws {
        let args = CommandLine.arguments
        guard args.count == 5 else { throw problem(400) }
        let root = URL(fileURLWithPath:args[1]), fonts = URL(fileURLWithPath:args[2]), output = URL(fileURLWithPath:args[3])
        let mode = args[4]
        if mode == "metadata" {
            var values: [[String: Any]] = []
            let names = Set(CTFontManagerCopyAvailablePostScriptNames() as? [String] ?? [])
            for (id,file) in [("regular","GowunBatang-Regular.ttf"),("bold","GowunBatang-Bold.ttf")] {
                let data = try Data(contentsOf:fonts.appendingPathComponent(file))
                let inspected = try FontFileInspector().inspect(data,filename:file), face = inspected.faces[0]
                values.append(["id":id,"file":file,"family":face.familyName ?? "","fullName":face.fullName ?? "",
                    "style":face.subfamilyName ?? "","postscriptName":face.postScriptName,"weight":Int(face.weightClass),
                    "sha256":fontSHA256(data),"bytes":data.count,"embeddingFlags":Int(face.embeddingFlags),
                    "aliases":Array(Set(face.names.filter { [1,4,6,16].contains($0.nameID) }.compactMap(\.value))).sorted(),
                    "systemPresent":names.contains(face.postScriptName)])
            }
            try writeJSON(["faces":values,"nanumPresent":["NanumSquareR","NanumSquareB"].filter(names.contains)],output)
            return
        }
        guard ["baseline","naive","custom","missing","wrong-token","job"].contains(mode) else { throw problem(400) }
        let data = try Data(contentsOf:output.deletingLastPathComponent().appendingPathComponent("metadata.json"))
        let metadata = try JSONSerialization.jsonObject(with:data) as! [String: Any]
        if mode == "job" {
            let probe = JobProbe(root:root,fonts:fonts,output:output,metadata:metadata["faces"] as! [[String:Any]])
            let app = NSApplication.shared; app.setActivationPolicy(.accessory); app.delegate = probe
            app.finishLaunching(); probe.start()
            withExtendedLifetime(probe) { app.run() }
            return
        }
        let probe = Probe(root:root,fonts:fonts,output:output,mode:mode,metadata:metadata["faces"] as! [[String:Any]])
        let app = NSApplication.shared; app.setActivationPolicy(.accessory); app.delegate = probe
        // accessory executable의 windowless launch 대기를 피한다. 시작은 멱등이다.
        app.finishLaunching()
        probe.start()
        withExtendedLifetime(probe) { app.run() }
    }
}
