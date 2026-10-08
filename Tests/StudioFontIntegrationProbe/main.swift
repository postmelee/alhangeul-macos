import AppKit
import WebKit
import SwiftUI
import ScreenCaptureKit

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
    private var settingsWindow: NSWindow?
    private var faceResponses: [[String: String]] = []
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
    private func openFontMenu(_ category: String) async throws {
        _ = try await js("""
        const select=document.querySelector('#font-name');
        if(!document.querySelector('.font-picker-menu'))select.dispatchEvent(new PointerEvent('pointerdown',{bubbles:true,cancelable:true}));
        document.querySelector('.font-picker-category[data-category="\(category)"]').click();
        """)
        try await wait("existing font menu ready") {
            try await self.js("return [...document.querySelectorAll('.font-picker-option')].some(n=>n.textContent==='Gowun Batang');") as? Bool == true
        }
    }
    private func chooseFont(_ name: String) async throws {
        let quoted = String(data: try JSONSerialization.data(withJSONObject: [name]), encoding: .utf8)!
        _ = try await js("""
        const option=[...document.querySelectorAll('.font-picker-option')].find(n=>n.textContent===\(quoted)[0]);
        if(!option)throw Error('Missing existing menu font');option.click();return true;
        """)
    }
    private func run() async throws {
        if CommandLine.arguments.contains("--changes") { try await runChanges(); return }
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
            a.registerCommand({id:'ext:font-probe-services',label:'probe',execute(s){window.__fontProbeWasm=s.wasm;window.__fontProbeState=s.documentState;window.__fontProbeInput=s.getInputHandler();}});
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
        let menuReads = await reads.snapshot()
        try await openFontMenu("system")
        try check(await reads.snapshot() == menuReads, "opening existing font menu does not read all font bytes")
        try check(try await js("return document.querySelectorAll('.font-picker-option').length === 1;") as? Bool == true,
            "existing system menu deduplicates Regular/Bold into one family")
        try await screenshot("local-font-dropdown.png")
        try await openFontMenu("all")
        try check(try await js("return [...document.querySelectorAll('.font-picker-option')].filter(n=>n.textContent==='Gowun Batang').length===1;") as? Bool == true,
            "existing all menu includes host family once")
        try check(try await js("return !window.rhwpStudio.automation.execute('ext:alhangeul-local-font-picker',{}, {allowDialog:true}).ok && !document.querySelector('.alhangeul-local-font-overlay');") as? Bool == true,
            "separate local font dialog/menu removed")
        _ = try await js("window.__alhangeulFontConnection.refresh();return true;")
        try check(try await js("return !document.querySelector('.font-picker-menu');") as? Bool == true,
            "catalog invalidation discards open stale menu")
        try await openFontMenu("system")
        try check(try await js("return !!window.__fontProbeInput.getSelection();") as? Bool == true,
            "catalog refresh preserves document text selection")
        documentRevisionBeforePicker = ((try await rendererDiagnostics())["selection"] as? [String: Any])?["documentRevision"] as? Int ?? 0
        try await chooseFont("Gowun Batang")
        try check(try await js("return !document.querySelector('.font-picker-menu');") as? Bool == true,
            "existing menu selection closes dropdown")
        try check(try await js("return window.__fontProbeState.isDirty();") as? Bool == true, "toolbar font edit marks actual document dirty")
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
        try check(true, "toolbar font edit triggers completed CanvasKit repaint")
        _ = try await js("""
        return window.__fontProbeInput.moveCursorTo({sectionIndex:0,paragraphIndex:0,charOffset:'한글 가나다 ABC 0123 고운바탕 글꼴 확인'.length});
        """)
        try await openFontMenu("all")
        try await chooseFont("돋움")
        try await openFontMenu("system")
        try await chooseFont("Gowun Batang")
        try check(try await js("return !window.__fontProbeInput.getSelection();") as? Bool == true,
            "host family can be selected at caret without text range")
        let revisionBeforeTyping = ((try await rendererDiagnostics())["selection"] as? [String: Any])?["documentRevision"] as? Int ?? 0
        _ = try await js("""
        window.__fontProbeInput.focus();
        const input=document.querySelector('[aria-label="문서 편집 입력"]');
        input.value=' 입력';input.dispatchEvent(new InputEvent('input',{bubbles:true,inputType:'insertText',data:' 입력'}));
        return true;
        """)
        try await wait("caret input font") {
            try await self.js("return window.__fontProbeWasm.getCharPropertiesAt(0,0,'한글 가나다 ABC 0123 고운바탕 글꼴 확인'.length+1).fontFamily==='Gowun Batang';") as? Bool == true
        }
        try check(true, "newly typed text uses chosen local family through existing input handler")
        try await wait("typed text render completed") {
            let diagnostics = try await self.rendererDiagnostics()
            let page = self.canvasKitPage(diagnostics)
            let revision = (diagnostics["selection"] as? [String: Any])?["documentRevision"] as? Int ?? 0
            return revision > revisionBeforeTyping && page["lastRenderCompleted"] as? Bool == true && page["lastRenderError"] is NSNull
        }
        try check(true, "typed text triggers completed CanvasKit repaint")
        let saved = try await js("return Array.from(window.__fontProbeWasm.exportHwp());") as? [UInt8] ?? []
        try check(!saved.isEmpty, "HWP export after toolbar selection and typing")
        try Data(saved).write(to: out.appendingPathComponent("picker-result.hwp"))
        let savedHwpx = try await js("return Array.from(window.__fontProbeWasm.exportHwpx());") as? [UInt8] ?? []
        try check(!savedHwpx.isEmpty, "HWPX export after toolbar selection and typing")
        try Data(savedHwpx).write(to: out.appendingPathComponent("picker-result.hwpx"))
        try await screenshot("studio-after-dropdown.png")
    }
    private func fontGeneration() async throws -> Int {
        try await js("return window.rhwpStudio.fonts.getState().generation;") as? Int ?? -1
    }
    private func resourceGeneration() async throws -> Int {
        (try await rendererDiagnostics()["selection"] as? [String: Any])?["resourceGeneration"] as? Int ?? -1
    }
    private func waitForFonts(_ count: Int, backend: String, after generation: Int = -1, resources: Int = -1) async throws {
        try await wait("\(backend) current font state \(count)") {
            let state = try await self.js("return window.rhwpStudio.fonts.getState();") as? [String: Any] ?? [:]
            guard state["count"] as? Int == count, (state["generation"] as? Int ?? -1) > generation else { return false }
            let diagnostics = try await self.rendererDiagnostics()
            guard diagnostics["effectiveBackend"] as? String == backend,
                  ((diagnostics["selection"] as? [String: Any])?["resourceGeneration"] as? Int ?? -1) > resources else { return false }
            if backend == "canvas2d" {
                let fonts = try await self.js("return window.__fontProbeWasm.getHostCanvasFontDiagnostics();") as? [String: Any] ?? [:]
                return fonts["loaded"] as? Int == count && fonts["pending"] as? Int == 0
            }
            let page = self.canvasKitPage(diagnostics)
            return page["localTypefaceCount"] as? Int == count && page["localTypefacePendingCount"] as? Int == 0 &&
                page["lastRenderCompleted"] as? Bool == true && page["lastRenderError"] is NSNull
        }
    }
    private func showSettings(_ model: InstalledFontSettingsModel, library: FontLibrarySettingsModel) {
        let settings = NSWindow(contentRect: NSRect(x: 100, y: 180, width: 720, height: 560),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        settings.title = "알한글 — 글꼴 설정 · 격리 테스트"
        settings.isReleasedWhenClosed = false; settings.appearance = NSAppearance(named: .aqua)
        settings.contentView = NSHostingView(rootView: InstalledFontSettingsView(model: model, library: library).frame(width: 720, height: 560))
        settingsWindow = settings; settings.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    private func screenshotSettings(_ name: String) async throws {
        try await Task.sleep(nanoseconds: 300_000_000)
        guard #available(macOS 14.4, *) else { throw Failure(message: "settings capture requires macOS 14.4") }
        // 현재 프로세스의 창만 조회/캡처한다. 다른 앱 화면이나 전역 화면 권한은 요구하지 않는다.
        let content = try await SCShareableContent.currentProcess
        guard let owned = content.windows.first(where: { $0.windowID == CGWindowID(settingsWindow!.windowNumber) }) else {
            throw Failure(message: "own settings window not found")
        }
        let config = SCStreamConfiguration()
        config.width = Int(owned.frame.width * 2); config.height = Int(owned.frame.height * 2)
        config.showsCursor = false; config.ignoreShadowsSingleWindow = true
        let cg = try await SCScreenshotManager.captureImage(contentFilter: SCContentFilter(desktopIndependentWindow: owned), configuration: config)
        guard let data = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else { throw Failure(message: "settings PNG") }
        try data.write(to: out.appendingPathComponent(name))
    }
    private func runChanges() async throws {
        let repository = URL(fileURLWithPath: CommandLine.arguments[2])
        guard let index = CommandLine.arguments.firstIndex(of: "--state-dir"), index + 1 < CommandLine.arguments.count else { throw Failure(message: "state directory") }
        let state = URL(fileURLWithPath: CommandLine.arguments[index + 1])
        let installedReopen = CommandLine.arguments.contains("--installed-reopen")
        let reopening = CommandLine.arguments.contains("--reopen") || installedReopen
        let fixture = try FontChangeFixture(repository: repository, directory: state.appendingPathComponent("sources"), create: !reopening)
        defer { try? fixture.setReadable(true); Task { await fixture.gate.open() } }
        let catalog = try InstalledFontCatalogService(persistence: .file(at: state.appendingPathComponent("installed")),
            environment: fixture.environment, observeChanges: false)
        let provider = InstalledFontServiceProvider(factory: { catalog })
        let library = FontLibraryService(store: .init(rootURL: state.appendingPathComponent("library")))
        let model = InstalledFontSettingsModel(makeService: { try await provider.service() })
        let libraryModel = FontLibrarySettingsModel(makeClient: { .init(service: library) })
        await model.prepare(); await libraryModel.prepare()
        let initial = await catalog.snapshot()
        try check(initial.enabled == installedReopen, installedReopen ? "new process restores enabled installed-font setting" :
            reopening ? "new process restores disabled setting" : "new installation keeps approved false default")
        showSettings(model, library: libraryModel)
        try await screenshotSettings(reopening ? "settings-reopen.png" : "settings-default.png")
        let handler = StudioFontMessageHandler(installed: provider, library: { library }, onFaceRead: { [weak self] id, ps, hash in
            self?.faceResponses.append(["source": id, "ps": ps, "sha256": hash])
        })
        let coordinator = RhwpStudioWebView.Coordinator(fontMessageHandler: handler)
        self.coordinator = coordinator; coordinator.onEditorSessionChange = { self.session = $0 }
        coordinator.onOpenFontSettings = { [weak self] in
            guard let window = self?.settingsWindow else { return false }
            window.makeKeyAndOrderFront(nil)
            return true
        }
        let web = coordinator.makeWebView(); self.web = web
        let window = NSWindow(contentRect: NSRect(x: 180, y: 100, width: 1100, height: 800),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "알한글 — 글꼴 변경 연동 검증"; window.delegate = self
        window.isReleasedWhenClosed = false; window.contentView = web; self.window = window
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        func beginVisibleImport() async throws {
            try await wait("managed UI ready") { libraryModel.ready && !libraryModel.busy }
            libraryModel.beginImport()
            try await wait("native import sheet presented") { self.settingsWindow?.attachedSheet != nil }
        }
        func dismissVisibleImport() async throws {
            libraryModel.dismissImport()
            try await wait("native import sheet dismissed") { self.settingsWindow?.attachedSheet == nil }
        }
        func load(_ backend: String, id: Int) async throws {
            if id == 2 {
                await fixture.gate.arm()
                await model.setEnabled(true)
                try await wait("old document read entered") { await fixture.gate.entered }
                for hop in 11...13 {
                    let old = RhwpStudioDocumentPayload(data: try Data(contentsOf: out.appendingPathComponent("gowun-document.hwp")),
                        filename: "font-switch-\(hop).hwp", revision: hop, sourceProtection: .plain)
                    coordinator.update(document: old, sourceDocument: nil, reloadToken: 0, loadID: hop, in: web)
                }
                await model.setEnabled(false)
                await fixture.gate.open()
                faceResponses.removeAll()
            }
            session = nil
            let url = out.appendingPathComponent("gowun-document.hwpx")
            let payload = RhwpStudioDocumentPayload(data: try Data(contentsOf: url), filename: url.lastPathComponent,
                revision: id, sourceProtection: .plain)
            coordinator.update(document: payload, sourceDocument: nil, reloadToken: 0, loadID: id, in: web)
            var components = URLComponents(url: try RhwpStudioResourceLocator.loadURL(for: payload), resolvingAgainstBaseURL: false)!
            components.queryItems = (components.queryItems ?? []) + [.init(name: "renderer", value: backend), .init(name: "canvaskitSurface", value: "webgl")]
            web.load(URLRequest(url: components.url!))
            try await wait("change document ready") { self.session?.snapshot.ready == true }
            try await wait("change provider connected") { try await self.js("return window.__alhangeulFontConnection?.getState().status==='connected';") as? Bool == true }
            _ = try await js("""
            const a=window.rhwpStudio.automation;
            a.registerCommand({id:'ext:change-probe-services',label:'probe',execute(s){window.__fontProbeWasm=s.wasm;window.__fontProbeState=s.documentState;}});
            a.execute('ext:change-probe-services');a.unregisterCommand('ext:change-probe-services');return true;
            """)
        }
        if reopening {
            try check(fixture.sourceExists == installedReopen, installedReopen ? "new process rechecks original source copies" : "new process has no original source copies")
            try check(try await library.list().entries.count == (installedReopen ? 0 : 2),
                installedReopen ? "installed automatic use is verified without managed substitutes" : "new process restores managed Regular/Bold copies")
            try await load("canvaskit", id: 101)
            try await waitForFonts(2, backend: "canvaskit")
            let prefix = installedReopen ? "installed:" : "managed:"
            try check(faceResponses.count >= 2 && faceResponses.allSatisfy { $0["source"]?.hasPrefix(prefix) == true },
                installedReopen ? "enabled setting automatically supplies exact installed bytes on new process" : "new process automatically renders exact managed bytes without source or new import")
            try await screenshot(installedReopen ? "studio-installed-reopen.png" : "studio-reopen.png")
            if !installedReopen {
                let generation = try await fontGeneration(), resources = try await resourceGeneration()
                try fixture.restore(); await model.refresh(); await model.setEnabled(true)
                for entry in try await library.list().entries {
                    _ = try await library.remove(objectHash: entry.object.sha256, expectedGeneration: try await library.list().generation)
                }
                await libraryModel.prepare()
                try await waitForFonts(2, backend: "canvaskit", after: generation, resources: resources)
                try check(faceResponses.suffix(2).allSatisfy { $0["source"]?.hasPrefix("installed:") == true },
                    "managed substitutes removed before independent installed relaunch")
            }
            try await screenshotSettings("settings-enabled.png")
            return
        }
        for (index, backend) in ["canvas2d", "canvaskit"].enumerated() {
            await model.setEnabled(false)
            try await load(backend, id: index + 1)
            try await waitForFonts(0, backend: backend)
            if index == 1 {
                try check(faceResponses.isEmpty, "rapid document changes reject gated previous replies and restore final fallback")
            }
            let original = try await js("return JSON.stringify([0,3,25].map(p=>window.__fontProbeWasm.getCharPropertiesAt(0,0,p)));") as? String
            var generation = try await fontGeneration(), resources = try await resourceGeneration()
            await model.setEnabled(true)
            try await waitForFonts(2, backend: backend, after: generation, resources: resources)
            try check(true, "\(backend): enabling saved setting loads both exact installed faces in open document")
            generation = try await fontGeneration(); resources = try await resourceGeneration()
            await model.setEnabled(false)
            try await waitForFonts(0, backend: backend, after: generation, resources: resources)
            try check(true, "\(backend): disabling removes local face/measurement resources and renders fallback")
            generation = try await fontGeneration(); resources = try await resourceGeneration()
            await model.setEnabled(true)
            try await waitForFonts(2, backend: backend, after: generation, resources: resources)
            try check(true, "\(backend): re-enabling recovers without reopening document")
            generation = try await fontGeneration(); resources = try await resourceGeneration()
            try fixture.setReadable(false); await model.refresh()
            // 목록 무효화 중의 일시적인 count=0을 두 face의 실패 완료로 오인하지 않는다.
            try await wait("both fixture permission failures published") {
                let records = await catalog.snapshot().records
                return records.count == 2 && records.allSatisfy { $0.failure == .permissionDenied }
            }
            try await waitForFonts(0, backend: backend, after: generation, resources: resources)
            try check((await catalog.snapshot()).records.allSatisfy { $0.failure == .permissionDenied },
                "\(backend): actual fixture read denial is published and stale faces are discarded")
            if backend == "canvaskit" { try await screenshotSettings("settings-permission.png") }
            generation = try await fontGeneration(); resources = try await resourceGeneration()
            try fixture.setReadable(true); await model.refresh()
            try await waitForFonts(2, backend: backend, after: generation, resources: resources)
            try check(true, "\(backend): restored permission and manual refresh clear failure caches")
            generation = try await fontGeneration(); resources = try await resourceGeneration()
            faceResponses.removeAll()
            let changedHash = try fixture.replaceBytes(); await model.refresh()
            try await waitForFonts(2, backend: backend, after: generation, resources: resources)
            try check(faceResponses.contains { $0["ps"] == "GowunBatang-Regular" && $0["sha256"] == changedHash },
                "\(backend): same PostScript name reloads changed verified content hash")
            generation = try await fontGeneration(); resources = try await resourceGeneration()
            try fixture.removeSources(); await model.refresh()
            try await waitForFonts(0, backend: backend, after: generation, resources: resources)
            try check(true, "\(backend): removed installed candidates fall back without retaining old faces")
            generation = try await fontGeneration(); resources = try await resourceGeneration()
            try fixture.restore(); await model.refresh()
            try await waitForFonts(2, backend: backend, after: generation, resources: resources)
            try check(true, "\(backend): reappearing candidates recover in current document")
            generation = try await fontGeneration(); resources = try await resourceGeneration()
            await model.setEnabled(false)
            try await waitForFonts(0, backend: backend, after: generation, resources: resources)
            generation = try await fontGeneration(); resources = try await resourceGeneration()
            try await beginVisibleImport(); libraryModel.scan(.selected([fixture.directory]))
            try await wait("managed UI discovery") { libraryModel.phase == .candidates }
            libraryModel.importSelected()
            try await wait("managed UI import") { libraryModel.phase == .results }
            try await dismissVisibleImport()
            try check(libraryModel.results.filter { $0.status == .added }.count == 2, "\(backend): real UI model imports Regular/Bold through shared service")
            try await waitForFonts(2, backend: backend, after: generation, resources: resources)
            try check(faceResponses.suffix(2).count == 2 && faceResponses.suffix(2).allSatisfy { $0["source"]?.hasPrefix("managed:") == true },
                "\(backend): managed import observer updates exact bytes while installed use is disabled")
            try fixture.removeSources(); await model.refresh()
            try check(!fixture.sourceExists, "\(backend): own source files removed; managed copies remain independent")
            if backend == "canvas2d" {
                generation = try await fontGeneration(); resources = try await resourceGeneration()
                for entry in try await library.list().entries {
                    _ = try await library.remove(objectHash: entry.object.sha256, expectedGeneration: try await library.list().generation)
                }
                try await waitForFonts(0, backend: backend, after: generation, resources: resources)
                try check(true, "\(backend): managed removal publishes and clears old face resources")
                try fixture.restore(); await model.refresh()
            } else {
                generation = try await fontGeneration(); resources = try await resourceGeneration()
                for entry in try await library.list().entries {
                    _ = try await library.remove(objectHash: entry.object.sha256, expectedGeneration: try await library.list().generation)
                }
                try await waitForFonts(0, backend: backend, after: generation, resources: resources)
                try check(true, "\(backend): managed removal publishes and clears old face resources")
                try fixture.restore(); await model.refresh()
                generation = try await fontGeneration(); resources = try await resourceGeneration()
                try await beginVisibleImport(); libraryModel.scan(.selected([fixture.directory]))
                try await wait("managed reimport discovery") { libraryModel.phase == .candidates }
                libraryModel.importSelected()
                try await wait("managed reimport") { libraryModel.phase == .results }
                try await dismissVisibleImport()
                try await waitForFonts(2, backend: backend, after: generation, resources: resources)
                try fixture.removeSources(); await model.refresh()
                try check(true, "\(backend): managed reimport clears failure cache and survives source removal")
            }
            try check(try await js("return window.__fontProbeState.isDirty()===false;") as? Bool == true,
                "\(backend): font changes preserve clean document state")
            try check(try await js("return JSON.stringify([0,3,25].map(p=>window.__fontProbeWasm.getCharPropertiesAt(0,0,p)));") as? String == original,
                "\(backend): font changes preserve document original names and styles")
            try await screenshot("studio-changes-\(backend).png")
        }
        for ext in ["hwp", "hwpx"] {
            let method = ext == "hwp" ? "exportHwp" : "exportHwpx"
            let data = try await js("return Array.from(window.__fontProbeWasm.\(method)());") as? [UInt8] ?? []
            try Data(data).write(to: out.appendingPathComponent("changes-result.\(ext)"))
        }
        try JSONSerialization.data(withJSONObject: faceResponses, options: [.prettyPrinted, .sortedKeys])
            .write(to: out.appendingPathComponent("change-face-proof.json"))
    }
    private func finish(_ error: String?) {
        let result: [String: Any] = ["checks": checks, "error": error as Any? ?? NSNull()]
        if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) {
            let filename = CommandLine.arguments.contains("--changes")
                ? (CommandLine.arguments.contains("--installed-reopen") ? "installed-reopen-result.json" :
                    CommandLine.arguments.contains("--reopen") ? "reopen-result.json" : "changes-result.json") : "integration-result.json"
            try? data.write(to: out.appendingPathComponent(filename))
        }
        print(error.map { "FAIL: \($0)" } ?? "PASS: product Studio integration")
        if error == nil && CommandLine.arguments.contains("--interactive") {
            window?.title = CommandLine.arguments.contains("--changes") ? "알한글 — 글꼴 변경 연동 · 격리 테스트 문서" : "알한글 — 고운바탕 연결 체험 · 테스트 문서"
            Task { @MainActor in
                _ = try? await js("return window.rhwpStudio.automation.execute('edit:select-all');")
                try? await openFontMenu("system")
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
