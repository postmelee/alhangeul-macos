import AppKit
import SwiftUI
import WebKit
import ScreenCaptureKit

// 실제 CoreText 환경을 계측한다. 이름/경로를 바꾸거나 가상 목록을 공급하지 않는다.
private final class AcceptanceMeter: @unchecked Sendable {
    private let lock = NSLock()
    private var scans: [Double] = []
    private var reads: [[String: Any]] = []
    private var active = 0
    private var maximum = 0
    private var held = false
    func hold(_ value: Bool) { lock.lock(); defer { lock.unlock() }; held = value }
    func beginRead() -> Bool {
        lock.lock(); defer { lock.unlock() }; active += 1; maximum = max(maximum, active); return held
    }
    func endRead(_ ps: String, _ milliseconds: Double, _ hash: String?, _ failure: String?) {
        lock.lock(); defer { lock.unlock() }; active -= 1
        reads.append(["ps": ps, "milliseconds": milliseconds, "sha256": hash as Any? ?? NSNull(), "failure": failure as Any? ?? NSNull()])
    }
    func scan(_ milliseconds: Double) { lock.lock(); defer { lock.unlock() }; scans.append(milliseconds) }
    func snapshot() -> [String: Any] {
        lock.lock(); defer { lock.unlock() }
        return ["scanMS": scans, "scanCount": scans.count, "reads": reads, "readCount": reads.count, "maximumConcurrentReads": maximum]
    }
}

@main
private struct AcceptanceMain {
    @MainActor static func main() {
        let app = NSApplication.shared, delegate = AcceptanceProbe()
        app.setActivationPolicy(.regular); app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
private final class AcceptanceProbe: NSObject, NSApplicationDelegate {
    private let meter = AcceptanceMeter()
    private var window: NSWindow?
    private var settings: NSWindow?
    private var web: WKWebView?
    private var coordinator: RhwpStudioWebView.Coordinator?
    private var session: RhwpStudioEditorSession?
    private var errors: [String] = []
    private var checks: [String] = []
    private var faceResponses: [[String: String]] = []
    private var nativeSaves: [RhwpStudioSavedDocument] = []
    private var measurements: [String: Any] = [:]
    private var output: URL!
    private var installedModel: InstalledFontSettingsModel?
    private var libraryModel: FontLibrarySettingsModel?
    private var launchStart = ProcessInfo.processInfo.systemUptime
    private var catalog: InstalledFontCatalogService?
    private let text = "한글 가나다 ABC 0123 고운바탕 글꼴 확인"
    struct Failure: Error { let message: String }
    private func now() -> TimeInterval { ProcessInfo.processInfo.systemUptime }
    private func check(_ value: Bool, _ message: String) throws {
        guard value else { throw Failure(message: message) }
        checks.append(message); print("PASS: \(message)")
    }
    private func js(_ code: String) async throws -> Any? {
        try await web!.callAsyncJavaScript(code, arguments: [:], in: nil, contentWorld: .page)
    }
    private func wait(_ message: String, _ predicate: () async throws -> Bool) async throws {
        let deadline = now() + 40
        while !(try await predicate()) {
            guard now() < deadline else { throw Failure(message: "timeout: \(message); \(errors)") }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        launchStart = now()
        Task { @MainActor in
            do { try await run(); finish(nil) }
            catch { finish(String(describing: error)) }
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    private func run() async throws {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("StudioFontAcceptanceProbe")
        let label = CommandLine.arguments.first(where: { $0.hasPrefix("--run=") })?.dropFirst(6) ?? "manual"
        output = root.appendingPathComponent("runs/\(label)")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let system = InstalledFontSystem().environment, meter = meter
        let environment = InstalledFontEnvironment(scan: { grants in
            let start = ProcessInfo.processInfo.systemUptime
            defer { meter.scan((ProcessInfo.processInfo.systemUptime - start) * 1000) }
            return try system.scan(grants)
        }, read: { record, grants in
            let hold = meter.beginRead()
            // 동시 요청 도착을 겹치게 하는 검증용 지연. 실제 readMS에는 포함하지 않는다.
            var start = ProcessInfo.processInfo.systemUptime
            do {
                if hold { try await Task.sleep(nanoseconds: 150_000_000) }
                start = ProcessInfo.processInfo.systemUptime
                let result = try await system.read(record, grants)
                meter.endRead(record.postScriptName, (ProcessInfo.processInfo.systemUptime - start) * 1000, result.face.id.objectHash, nil)
                return result
            } catch {
                meter.endRead(record.postScriptName, (ProcessInfo.processInfo.systemUptime - start) * 1000, nil, String(describing: error)); throw error
            }
        }, makeBookmark: system.makeBookmark)
        let persistence = InstalledFontPersistence.file(at: root.appendingPathComponent("installed"))
        let service = try await Task.detached {
            try InstalledFontCatalogService(persistence: persistence, environment: environment, observeChanges: false)
        }.value
        catalog = service
        let before = await service.snapshot()
        measurements["restoredEnabled"] = before.enabled
        measurements["savedMetadataPresent"] = !before.records.isEmpty
        let prepareStart = now(), activationAt = now()
        // 여러 문서/설정의 최초 호출은 같은 actor의 prepare를 공유한다.
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<8 { group.addTask { _ = try await service.prepare() } }
            try await group.waitForAll()
        }
        measurements["prepareMS"] = (now() - prepareStart) * 1000
        await service.scheduleRefreshForActivation(at: activationAt)
        try await Task.sleep(nanoseconds: 350_000_000)
        var state = await service.snapshot()
        try check(meter.snapshot()["scanCount"] as? Int == 1, "동시 최초 준비 8회·최초 활성화가 실제 metadata 탐색 1회 공유")
        try check(meter.snapshot()["readCount"] as? Int == 0, "전체 목록 준비는 font bytes를 읽지 않음")
        measurements["faceCount"] = state.records.count
        measurements["familyCount"] = Set(state.records.map(\.family)).count
        measurements["metadataFailureCount"] = state.records.filter { $0.failure != nil }.count
        measurements["variableFaceCount"] = state.records.filter { !$0.axes.isEmpty }.count
        measurements["omittedFaceCount"] = state.omittedFaceCount
        if CommandLine.arguments.contains("--reopen") {
            try check(before.enabled, "새 프로세스에서 사용 설정 자동 복원")
        }
        state = try await service.setEnabled(true)
        guard let regular = state.records.first(where: { $0.postScriptName == "NanumSquareR" && $0.failure == nil }),
              let bold = state.records.first(where: { $0.postScriptName == "NanumSquareB" && $0.failure == nil }) else {
            throw Failure(message: "실제 설치된 NanumSquare Regular/Bold가 필요함")
        }
        measurements["testFamily"] = regular.family
        measurements["testPS"] = [regular.postScriptName, bold.postScriptName]
        meter.hold(true)
        let generation = state.generation
        let copies = try await withThrowingTaskGroup(of: String.self) { group -> [String] in
            for _ in 0..<8 {
                group.addTask { try await service.readResource(regular.id, expectedGeneration: generation).face.id.objectHash }
            }
            var result: [String] = []; for try await hash in group { result.append(hash) }; return result
        }
        meter.hold(false)
        try check(Set(copies).count == 1 && meter.snapshot()["readCount"] as? Int == 1,
            "같은 실제 face의 동시 요청 8개가 native 읽기 1회 병합")
        _ = try await service.readResource(regular.id, expectedGeneration: generation)
        try check(meter.snapshot()["readCount"] as? Int == 2, "완료 bytes를 native 영구 캐시하지 않고 원본 재검증")
        meter.hold(true)
        try await withThrowingTaskGroup(of: Void.self) { group in
            for record in [regular, bold] {
                group.addTask { _ = try await service.readResource(record.id, expectedGeneration: generation) }
            }
            try await group.waitForAll()
        }
        meter.hold(false)
        try check(meter.snapshot()["readCount"] as? Int == 4 && meter.snapshot()["maximumConcurrentReads"] as? Int == 2,
            "서로 다른 실제 Regular/Bold 요청은 native 두 slot에서 공급")
        measurements["nativeDirectReads"] = meter.snapshot()
        let provider = InstalledFontServiceProvider(factory: { service })
        let library = FontLibraryService(store: .init(rootURL: root.appendingPathComponent("managed")))
        installedModel = InstalledFontSettingsModel(makeService: { service })
        libraryModel = FontLibrarySettingsModel(makeClient: { .init(service: library) })
        await installedModel!.prepare(); await libraryModel!.prepare()
        let handler = StudioFontMessageHandler(installed: provider, library: { library }, onFaceRead: { [weak self] _, ps, hash in
            self?.faceResponses.append(["ps": ps, "sha256": hash])
        })
        let coordinator = RhwpStudioWebView.Coordinator(fontMessageHandler: handler)
        coordinator.onEditorSessionChange = { self.session = $0 }
        coordinator.onError = { if let message = $0 { self.errors.append(message) } }
        coordinator.onOpenFontSettings = { [weak self] in self?.showSettings(); return true }
        // 저장 위치/변환 확인만 테스트 입력으로 준다. bytes 생성·검증·쓰기·완료 동기화는 제품 경로다.
        coordinator.chooseSaveDestination = { format, _, _ in root.appendingPathComponent("saved.\(format.rawValue)") }
        coordinator.confirmSaveTransformation = { _, _, _ in true }
        coordinator.onDocumentSaved = { self.nativeSaves.append($0) }
        self.coordinator = coordinator
        let web = coordinator.makeWebView(); self.web = web
        let window = NSWindow(contentRect: NSRect(x: 160, y: 120, width: 1100, height: 800),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "알한글 — 실제 Mac 글꼴 · sandbox 검증"
        window.isReleasedWhenClosed = false; window.contentView = web; self.window = window
        window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        let reopened = CommandLine.arguments.contains("--reopen")
        for (index, item) in [("hwp", "canvas2d"), ("hwpx", "canvaskit")].enumerated() {
            let (ext, backend) = item
            let source = reopened ? root.appendingPathComponent("saved.\(ext)") :
                Bundle.main.resourceURL!.appendingPathComponent("nanum-document.\(ext)")
            let payload = RhwpStudioDocumentPayload(data: try Data(contentsOf: source), filename: "nanum-document.\(ext)",
                revision: index + 1, sourceProtection: .plain)
            let counts = meter.snapshot()["readCount"] as! Int, start = now()
            let responseStart = faceResponses.count
            session = nil
            coordinator.update(document: payload, sourceDocument: nil, reloadToken: 0, loadID: index + 1, in: web)
            web.configuration.userContentController.addUserScript(WKUserScript(source: """
            window.__fontPaints=[];
            const original=CanvasRenderingContext2D.prototype.fillText;
            CanvasRenderingContext2D.prototype.fillText=function(...a){if(this.font.includes('__rhwp_host_face_'))window.__fontPaints.push(this.font);return original.apply(this,a);};
            """, injectionTime: .atDocumentStart, forMainFrameOnly: true))
            if backend == "canvaskit" {
                var url = URLComponents(url: try RhwpStudioResourceLocator.loadURL(for: payload), resolvingAgainstBaseURL: false)!
                url.queryItems = (url.queryItems ?? []) + [.init(name: "renderer", value: "canvaskit"), .init(name: "canvaskitSurface", value: "webgl")]
                web.load(URLRequest(url: url.url!))
            }
            try await wait("Studio ready") { self.session?.snapshot.ready == true }
            measurements["\(ext)-documentReadyMS"] = (now() - start) * 1000
            _ = try await js("""
            const a=window.rhwpStudio.automation;
            a.registerCommand({id:'ext:acceptance-services',label:'probe',execute(s){window.__probeWasm=s.wasm;window.__probeState=s.documentState;window.__probeInput=s.getInputHandler();}});
            a.execute('ext:acceptance-services');a.unregisterCommand('ext:acceptance-services');
            """)
            try await wait("실제 Regular/Bold bytes·renderer 완료") {
                let responses = Array(self.faceResponses.dropFirst(responseStart))
                guard Set(responses.compactMap { $0["ps"] }).isSuperset(of: [regular.postScriptName, bold.postScriptName]) else { return false }
                if backend == "canvas2d" {
                    let fonts = try await self.js("return window.__probeWasm.getHostCanvasFontDiagnostics();") as? [String: Any] ?? [:]
                    let paints = try await self.js("return window.__fontPaints.length;") as? Int ?? 0
                    return (fonts["loaded"] as? Int ?? 0) >= 2 && fonts["pending"] as? Int == 0 && paints > 0
                }
                let diag = try await self.diagnostics(), page = (diag["page"] as? [String: Any])?["canvaskit"] as? [String: Any] ?? [:]
                return diag["effectiveBackend"] as? String == "canvaskit" && (page["localTypefaceCount"] as? Int ?? 0) >= 2 &&
                    page["localTypefacePendingCount"] as? Int == 0 && page["localTypefaceLoadFailureCount"] as? Int == 0 &&
                    page["lastRenderCompleted"] as? Bool == true && page["lastRenderError"] is NSNull
            }
            measurements["\(ext)-exactFontReadyMS"] = (now() - start) * 1000
            measurements["\(ext)-newNativeReads"] = (meter.snapshot()["readCount"] as! Int) - counts
            try check(true, "\(ext)/\(backend): 실제 설치 Regular/Bold 검증 bytes와 정확한 renderer 적용")
            try JSONSerialization.data(withJSONObject: try await diagnostics(), options: [.prettyPrinted, .sortedKeys])
                .write(to: output.appendingPathComponent("\(ext)-diagnostics.json"))
            if backend == "canvas2d" {
                measurements["canvas2dFonts"] = try await js("return window.__probeWasm.getHostCanvasFontDiagnostics();")
                measurements["canvas2dPaintFonts"] = try await js("return [...new Set(window.__fontPaints)];")
            }
            try await capture(window, "document-\(ext).png")
            let warm = meter.snapshot()["readCount"] as! Int
            try check(try await js("for(let i=0;i<10;i++)window.__probeWasm.renderPageSvg(0);const a=window.rhwpStudio.automation;return a.execute('view:zoom-in').ok && a.execute('view:zoom-out').ok;") as? Bool == true,
                "\(ext): 기존 확대/축소 명령 실행")
            try await Task.sleep(nanoseconds: 400_000_000)
            try check(meter.snapshot()["readCount"] as? Int == warm, "\(ext): 반복 표시·확대/축소에서 준비한 face 재사용")
        }
        measurements["launchToAcceptanceMS"] = (now() - launchStart) * 1000
        let menuReads = meter.snapshot()["readCount"] as! Int
        try await openMenu()
        let menu = try await js("return [...document.querySelectorAll('.font-picker-option')].map(n=>n.textContent);") as? [String] ?? []
        try check(menu.count > 20 && menu.filter { $0 == regular.family }.count == 1,
            "기존 시스템 글꼴 목록에 실제 Mac family 20개 이상·NanumSquare 한 번 표시")
        measurements["systemMenuFamilyCount"] = menu.count
        try check(meter.snapshot()["readCount"] as? Int == menuReads, "기존 글꼴 목록 열기는 전체 bytes를 읽지 않음")
        try await capture(window, "actual-font-menu.png")
        _ = try await js("document.dispatchEvent(new KeyboardEvent('keydown',{key:'Escape',bubbles:true}));")
        if !reopened {
            _ = try await js("window.rhwpStudio.automation.execute('edit:select-all');")
            try await openMenu()
            let name = String(data: try JSONSerialization.data(withJSONObject: [regular.family]), encoding: .utf8)!
            _ = try await js("document.querySelectorAll('.font-picker-option').forEach(n=>{if(n.textContent===\(name)[0])n.click();});")
            try check(try await js("return window.__probeState.isDirty();") as? Bool == true, "기존 글꼴 메뉴 선택으로 실제 문서 편집")
            _ = try await js("""
            window.__probeInput.moveCursorTo({sectionIndex:0,paragraphIndex:0,charOffset:\(text.count)});
            window.__probeInput.focus();const input=document.querySelector('[aria-label="문서 편집 입력"]');
            input.value=' 입력';input.dispatchEvent(new InputEvent('input',{bubbles:true,inputType:'insertText',data:' 입력'}));
            """)
            try await wait("입력 반영") { try await self.js("return window.__probeWasm.getTextRange(0,0,0,window.__probeWasm.getParagraphLength(0,0)).endsWith(' 입력');") as? Bool == true }
            let savedURL: URL = try await withCheckedThrowingContinuation { continuation in
                guard RhwpStudioNativeCommandDispatcher.saveDocument(in: window, completion: { result in
                    switch result {
                    case .saved(let url): continuation.resume(returning: url)
                    case .cancelled: continuation.resume(throwing: Failure(message: "native save cancelled"))
                    case .failed(let message): continuation.resume(throwing: Failure(message: message))
                    }
                }) else { continuation.resume(throwing: Failure(message: "native save unavailable")); return }
            }
            try check(savedURL.pathExtension == "hwpx", "native 저장 bridge·payload 검증·실제 HWPX 파일 쓰기·완료 동기화")
            try check(RhwpStudioNativeCommandDispatcher.run(DocumentSaveCommand.saveAsHwp.rawValue, in: window), "기존 HWP로 다른 이름 저장 명령")
            try await wait("native HWP write") { self.nativeSaves.contains { $0.url.pathExtension == "hwp" } }
            for ext in ["hwp", "hwpx"] {
                let data = try Data(contentsOf: root.appendingPathComponent("saved.\(ext)"))
                try check(!data.isEmpty && nativeSaves.contains { $0.url.pathExtension == ext }, "한글 입력 후 native \(ext) 저장 성공")
                try data.write(to: output.appendingPathComponent("saved.\(ext)"))
            }
        } else {
            try check(try await js("return window.__probeWasm.getTextRange(0,0,0,window.__probeWasm.getParagraphLength(0,0)).endsWith(' 입력');") as? Bool == true,
                "새 프로세스에서 저장 문서의 한글 입력 복원")
        }
        let original = try await js("const s=await window.__alhangeulHostBridgeReadSession();return JSON.stringify([s.documentEpoch,s.changeSeq,s.dirty]);") as? String
        showSettings()
        try await capture(settings!, "actual-font-settings.png")
        try check(try await js("const s=await window.__alhangeulHostBridgeReadSession();return JSON.stringify([s.documentEpoch,s.changeSeq,s.dirty]);") as? String == original,
            "실제 Mac 목록 설정 창을 열어도 문서 상태 보존")
        try check(errors.isEmpty, "Studio/native 오류 없음")
        measurements["finalMeter"] = meter.snapshot()
        measurements["faceResponses"] = faceResponses
        measurements["os"] = ProcessInfo.processInfo.operatingSystemVersionString
        measurements["pid"] = ProcessInfo.processInfo.processIdentifier
    }
    private func openMenu() async throws {
        _ = try await js("""
        const select=document.querySelector('#font-name');
        if(!document.querySelector('.font-picker-menu'))select.dispatchEvent(new PointerEvent('pointerdown',{bubbles:true,cancelable:true}));
        document.querySelector('.font-picker-category[data-category=system]').click();
        """)
        try await wait("실제 시스템 목록") { (try await self.js("return document.querySelectorAll('.font-picker-option').length;") as? Int ?? 0) > 20 }
    }
    private func diagnostics() async throws -> [String: Any] {
        try await js("""
        return await new Promise((resolve,reject)=>{const id='acceptance-diag';const t=setTimeout(()=>reject(Error('renderer timeout')),10000);
        const f=e=>{if(e.data?.type==='rhwp-response'&&e.data.id===id){clearTimeout(t);window.removeEventListener('message',f);e.data.error?reject(Error(e.data.error)):resolve(e.data.result);}};
        window.addEventListener('message',f);window.postMessage({type:'rhwp-request',id,method:'getRendererDiagnostics',params:{pageIndex:0}},'*');});
        """) as? [String: Any] ?? [:]
    }
    private func showSettings() {
        if let settings { settings.makeKeyAndOrderFront(nil); return }
        let settings = NSWindow(contentRect: NSRect(x: 100, y: 140, width: 720, height: 560), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        settings.title = "알한글 — 실제 Mac 글꼴 설정 · sandbox 테스트"
        settings.isReleasedWhenClosed = false
        settings.contentView = NSHostingView(rootView: InstalledFontSettingsView(model: installedModel!, library: libraryModel!).frame(width: 720, height: 560))
        self.settings = settings; settings.center(); settings.makeKeyAndOrderFront(nil)
    }
    private func capture(_ window: NSWindow, _ name: String) async throws {
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        try await Task.sleep(nanoseconds: 300_000_000)
        guard #available(macOS 14.4, *) else { throw Failure(message: "capture requires macOS 14.4") }
        let content = try await SCShareableContent.currentProcess
        guard let owned = content.windows.first(where: { $0.windowID == CGWindowID(window.windowNumber) }) else { throw Failure(message: "own window missing") }
        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width * 2); config.height = Int(window.frame.height * 2)
        config.showsCursor = false; config.ignoreShadowsSingleWindow = true
        let cg = try await SCScreenshotManager.captureImage(contentFilter: SCContentFilter(desktopIndependentWindow: owned), configuration: config)
        guard let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else { throw Failure(message: "PNG") }
        try png.write(to: output.appendingPathComponent(name))
    }
    private func finish(_ error: String?) {
        let result: [String: Any] = ["passed": error == nil, "checks": checks, "measurements": measurements, "error": error as Any? ?? NSNull()]
        if let output {
            try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys, .prettyPrinted]).write(to: output.appendingPathComponent("result.json"))
        }
        if let error { print("FAIL: \(error)") }
        if error == nil && CommandLine.arguments.contains("--interactive") { NSApp.activate(ignoringOtherApps: true); return }
        exit(error == nil ? 0 : 1)
    }
}

@MainActor final class DocumentWindowPresenter {
    static let shared = DocumentWindowPresenter()
    func openDocument(_ url: URL) { fatalError("external open outside probe") }
}
