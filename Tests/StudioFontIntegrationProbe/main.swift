import AppKit
import WebKit

private actor Reads {
    var counts: [String: Int] = [:]
    func record(_ name: String) { counts[name, default: 0] += 1 }
    func snapshot() -> [String: Int] { counts }
}

@main
private struct Main {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = Probe()
        app.setActivationPolicy(.regular); app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
private final class Probe: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow?
    private var web: WKWebView?
    private var coordinator: RhwpStudioWebView.Coordinator?
    private var session: RhwpStudioEditorSession?
    private var checks: [String] = []
    private var documentRevisionBeforePicker = 0
    private let reads = Reads()
    private let out = URL(fileURLWithPath: CommandLine.arguments[1])
    struct Failure: Error { let message: String }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            do { try await run(); finish(nil) }
            catch { finish(String(describing: error)) }
        }
    }
    private func check(_ condition: Bool, _ description: String) throws {
        guard condition else { throw Failure(message: description) }
        checks.append(description); print("PASS: \(description)")
    }
    private func js(_ source: String) async throws -> Any? {
        try await web!.callAsyncJavaScript(source, arguments: [:], in: nil, contentWorld: .page)
    }
    private func wait(_ description: String, _ predicate: () async throws -> Bool) async throws {
        let deadline = Date().addingTimeInterval(30)
        while !(try await predicate()) {
            guard Date() < deadline else { throw Failure(message: "timeout: \(description)") }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
    }
    private func screenshot(_ name: String) async throws {
        let image: NSImage = try await withCheckedThrowingContinuation { continuation in
            web!.takeSnapshot(with: nil) { image, error in
                if let image { continuation.resume(returning: image) }
                else { continuation.resume(throwing: error ?? Failure(message: "snapshot")) }
            }
        }
        guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { throw Failure(message: "PNG") }
        try png.write(to: out.appendingPathComponent(name))
    }
    private func rendererDiagnostics() async throws -> [String: Any] {
        try await js("""
        return await new Promise((resolve,reject)=>{
          const id='font-probe-renderer';
          const timeout=setTimeout(()=>reject(new Error('renderer timeout')),10000);
          const receive=event=>{if(event.data?.type==='rhwp-response'&&event.data.id===id){
            clearTimeout(timeout);window.removeEventListener('message',receive);
            event.data.error?reject(new Error(event.data.error)):resolve(event.data.result);
          }};
          window.addEventListener('message',receive);
          window.postMessage({type:'rhwp-request',id,method:'getRendererDiagnostics',params:{pageIndex:0}},'*');
        });
        """) as? [String: Any] ?? [:]
    }
    private func canvasKitPage(_ diagnostics: [String: Any]) -> [String: Any] {
        (diagnostics["page"] as? [String: Any])?["canvaskit"] as? [String: Any] ?? [:]
    }
    private func run() async throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[2])
        var assets: [String: StudioFontBytes] = [:]
        var rows: [StudioFontFace] = []
        for style in ["Regular", "Bold"] {
            let url = root.appendingPathComponent("build.noindex/task567/fonts/gowun-batang/GowunBatang-\(style).ttf")
            let data = try Data(contentsOf: url)
            guard let face = try FontFileInspector().inspect(data, filename: url.lastPathComponent).faces.first else {
                throw Failure(message: "missing approved face")
            }
            assets[face.postScriptName] = .init(data: data, face: face)
            rows.append(.init(id: face.postScriptName, source: "managed", postScriptName: face.postScriptName,
                family: face.familyName ?? "", fullName: face.fullName ?? "", style: style,
                aliases: Array(Set(face.names.filter { [1,4,6,16].contains($0.nameID) }.compactMap(\.value))),
                weight: Int(face.weightClass), traits: UInt32(face.selectionFlags), limitation: nil))
        }
        let catalog = rows, files = assets, reads = reads
        let supply = StudioFontSupply(snapshot: {
            .init(identity: "approved-gowun-fixture", faces: catalog, omitted: 0, failure: nil,
                read: { id in
                    guard let bytes = files[id] else { throw StudioFontError.unavailable }
                    await reads.record(id); return bytes
                }, current: { true }, release: {})
        })
        let handler = StudioFontMessageHandler(session: StudioFontSession(supply: supply), observeLiveChanges: false)
        let coordinator = RhwpStudioWebView.Coordinator(fontMessageHandler: handler)
        self.coordinator = coordinator
        coordinator.onEditorSessionChange = { self.session = $0 }
        coordinator.onFailure = { print("LOAD FAILURE: \($0)") }
        let view = coordinator.makeWebView(); web = view
        let window = NSWindow(contentRect: NSRect(x: 140, y: 160, width: 1100, height: 800),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "알한글 — 로컬 글꼴 연결 검증 (고운바탕)"
        window.delegate = self
        window.isReleasedWhenClosed = false; window.contentView = view
        self.window = window; window.makeKeyAndOrderFront(nil)
        for (index, ext) in ["hwp", "hwpx", "hwpx"].enumerated() {
            let backend = index == 2 ? "canvaskit" : "canvas2d"
            let label = "\(ext)-\(backend)"
            let previousReads = await reads.snapshot()
            session = nil
            let url = out.appendingPathComponent("gowun-document.\(ext)")
            let payload = RhwpStudioDocumentPayload(data: try Data(contentsOf: url), filename: url.lastPathComponent,
                revision: index + 1, sourceProtection: .plain)
            coordinator.update(document: payload, sourceDocument: nil, reloadToken: 0, loadID: index + 1, in: view)
            view.configuration.userContentController.addUserScript(WKUserScript(source: """
            window.__fontPaints = [];
            window.__glContexts = [];
            const originalGetContext = HTMLCanvasElement.prototype.getContext;
            HTMLCanvasElement.prototype.getContext = function(type, ...args) {
              const result = originalGetContext.call(this, type, ...args);
              if (result && (type === 'webgl2' || type === 'webgl')) window.__glContexts.push(result);
              return result;
            };
            const originalFillText = CanvasRenderingContext2D.prototype.fillText;
            CanvasRenderingContext2D.prototype.fillText = function(...args) {
              if (this.font.includes('__rhwp_host_face_') && window.__fontPaints.length < 200) window.__fontPaints.push(this.font);
              return originalFillText.apply(this, args);
            };
            """, injectionTime: .atDocumentStart, forMainFrameOnly: true))
            if index == 2 {
                var components = URLComponents(url: try RhwpStudioResourceLocator.loadURL(for: payload), resolvingAgainstBaseURL: false)!
                components.queryItems = (components.queryItems ?? []) + [.init(name: "renderer", value: "canvaskit"), .init(name: "canvaskitSurface", value: "webgl")]
                view.load(URLRequest(url: components.url!))
            }
            try await wait("\(ext) Studio ready") { self.session?.snapshot.ready == true }
            try await wait("\(ext) provider") {
                let state = try await self.js("return window.__alhangeulFontConnection?.getState();") as? [String: Any]
                return state?["status"] as? String == "connected" && state?["count"] as? Int == 2
            }
            try check(true, "\(ext): actual product Coordinator + v0.8.7 Studio provider connected")
            _ = try await js("""
            const a=window.rhwpStudio.automation;
            a.registerCommand({id:'ext:font-probe-services',label:'probe',execute(s){window.__fontProbeWasm=s.wasm;window.__fontProbeState=s.documentState;}});
            a.execute('ext:font-probe-services');a.unregisterCommand('ext:font-probe-services');
            return true;
            """)
            if backend == "canvas2d" {
                try await wait("exact Regular/Bold paint") {
                    (try await self.js("return window.__fontProbeWasm.getHostCanvasFontDiagnostics().loaded;") as? Int ?? 0) >= 2
                }
            } else {
                let diagnostics = try await rendererDiagnostics()
                try check(diagnostics["effectiveBackend"] as? String == "canvaskit", "actual CanvasKit backend, no Canvas2D fallback")
                try JSONSerialization.data(withJSONObject: diagnostics, options: [.prettyPrinted, .sortedKeys])
                    .write(to: out.appendingPathComponent("canvaskit-diagnostics.json"))
                let gpu = try await js("""
                const gl=window.__glContexts.find(c=>!c.isContextLost());
                if(!gl)return null;
                const debug=gl.getExtension('WEBGL_debug_renderer_info');
                return {version:gl.getParameter(gl.VERSION),renderer:debug?gl.getParameter(debug.UNMASKED_RENDERER_WEBGL):null};
                """) as? [String: Any] ?? [:]
                try check(gpu["version"] as? String != nil, "CanvasKit actual WebGL context")
                try JSONSerialization.data(withJSONObject: gpu, options: [.prettyPrinted, .sortedKeys])
                    .write(to: out.appendingPathComponent("canvaskit-gpu.json"))
            }
            let counts = await reads.snapshot()
            try check((counts["GowunBatang-Regular"] ?? 0) > (previousReads["GowunBatang-Regular"] ?? 0) &&
                (counts["GowunBatang-Bold"] ?? 0) > (previousReads["GowunBatang-Bold"] ?? 0),
                "\(label): exact Regular/Bold bytes requested in this document generation")
            if backend == "canvas2d" {
                try await wait("actual host face paint") { try await self.js("return window.__fontPaints.length > 0;") as? Bool == true }
                try check(true, "\(ext): Canvas2D fillText uses document-owned host face alias")
            }
            let svg = try await js("return window.__fontProbeWasm.renderPageSvg(0);") as? String ?? ""
            try check(svg.contains("Gowun Batang") && !svg.contains("__rhwp_host_face_"), "\(ext): portable SVG original font name")
            try await screenshot("studio-\(label).png")
        }
        _ = try await js("return window.rhwpStudio.automation.execute('edit:select-all');")
        let result = try await js("return window.rhwpStudio.automation.execute('ext:alhangeul-local-font-picker',{}, {allowDialog:true});") as? [String: Any]
        try check(result?["ok"] as? Bool == true, "public extension font picker enabled")
        try await wait("font picker list") {
            try await self.js("return document.querySelector('.alhangeul-local-font-dialog select')?.options.length > 0;") as? Bool == true
        }
        try await screenshot("local-font-picker.png")
        documentRevisionBeforePicker = ((try await rendererDiagnostics())["selection"] as? [String: Any])?["documentRevision"] as? Int ?? 0
        _ = try await js("""
        const select=document.querySelector('.alhangeul-local-font-dialog select');
        select.value='Gowun Batang';select.dispatchEvent(new Event('change'));
        document.querySelectorAll('.alhangeul-local-font-actions button')[1].click();
        """)
        try await wait("font picker apply") { try await self.js("return !document.querySelector('.alhangeul-local-font-overlay');") as? Bool == true }
        try check(true, "actual picker apply uses public command path")
        try check(try await js("return window.__fontProbeState.isDirty();") as? Bool == true, "picker edit marks actual document dirty")
        do {
            try await wait("picker edit render completed") {
                let diagnostics = try await self.rendererDiagnostics()
                let page = self.canvasKitPage(diagnostics)
                let revision = (diagnostics["selection"] as? [String: Any])?["documentRevision"] as? Int ?? 0
                return revision > self.documentRevisionBeforePicker &&
                    page["lastRenderCompleted"] as? Bool == true && page["lastRenderError"] is NSNull
            }
        } catch {
            try JSONSerialization.data(withJSONObject: try await rendererDiagnostics(), options: [.prettyPrinted, .sortedKeys])
                .write(to: out.appendingPathComponent("picker-render-failure.json"))
            try await screenshot("picker-render-failure.png")
            throw error
        }
        try check(true, "picker edit triggers completed CanvasKit repaint")
        let saved = try await js("return Array.from(window.__fontProbeWasm.exportHwp());") as? [UInt8] ?? []
        try check(!saved.isEmpty, "HWP export after picker apply")
        try Data(saved).write(to: out.appendingPathComponent("picker-result.hwp"))
        let savedHwpx = try await js("return Array.from(window.__fontProbeWasm.exportHwpx());") as? [UInt8] ?? []
        try check(!savedHwpx.isEmpty, "HWPX export after picker apply")
        try Data(savedHwpx).write(to: out.appendingPathComponent("picker-result.hwpx"))
        try await screenshot("studio-after-picker.png")
    }
    private func finish(_ error: String?) {
        let result: [String: Any] = ["checks": checks, "error": error as Any? ?? NSNull()]
        if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: out.appendingPathComponent("integration-result.json"))
        }
        print(error.map { "FAIL: \($0)" } ?? "PASS: product Studio integration")
        if error == nil && CommandLine.arguments.contains("--interactive") {
            window?.title = "알한글 — 고운바탕 연결 체험 · 테스트 문서"
            Task { @MainActor in
                _ = try? await js("window.rhwpStudio.automation.execute('edit:select-all'); return window.rhwpStudio.automation.execute('ext:alhangeul-local-font-picker',{}, {allowDialog:true});")
            }
            return
        }
        cleanUp()
        exit(error == nil ? 0 : 1)
    }
    private func cleanUp() {
        if let web { coordinator?.disposeFontProvider(in: web) }
        coordinator?.fontMessageHandler.reset(); web?.stopLoading()
        if CommandLine.arguments.contains("--interactive") {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister")
            process.arguments = ["-u", Bundle.main.bundleURL.path]
            try? process.run()
        }
    }
    func windowWillClose(_ notification: Notification) { cleanUp() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@MainActor final class DocumentWindowPresenter {
    static let shared = DocumentWindowPresenter()
    func openDocument(_ url: URL) { fatalError("external open outside probe") }
}
