import AppKit
import SwiftUI
import WebKit
import ScreenCaptureKit

// 제품과 같은 Settings Scene/openSettings를 격리 저장소에서 검증한다.
@main
private struct StudioFontSettingsProbe: App {
    @NSApplicationDelegateAdaptor(NavigationLaunchDelegate.self) private var delegate
    @StateObject private var runner = NavigationRunner()
    var body: some Scene {
        WindowGroup("알한글 — 글꼴 설정 연결 · 격리 테스트") {
            NavigationDocument(runner: runner)
                .frame(minWidth: 1100, minHeight: 800)
                .background(AppSettingsOpener())
                .task { await runner.run() }
        }
        Settings {
            AppSettingsView(analytics: runner.analytics, fonts: runner.library, installedFonts: runner.installed)
        }
    }
}

private final class NavigationLaunchDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { true }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            if NSApp.windows.isEmpty { _ = NSApp.delegate?.applicationOpenUntitledFile?(NSApp) }
            NSApp.windows.forEach { $0.makeKeyAndOrderFront(nil) }
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

private struct NavigationDocument: NSViewRepresentable {
    let runner: NavigationRunner
    func makeCoordinator() -> RhwpStudioWebView.Coordinator {
        let handler = StudioFontMessageHandler(installed: runner.provider, library: { runner.libraryService })
        let coordinator = RhwpStudioWebView.Coordinator(fontMessageHandler: handler)
        coordinator.onEditorSessionChange = { runner.session = $0 }
        coordinator.onError = { runner.failure = $0 }
        runner.coordinator = coordinator
        return coordinator
    }
    func makeNSView(context: Context) -> WKWebView {
        let web = context.coordinator.makeWebView(); runner.web = web
        return web
    }
    func updateNSView(_ web: WKWebView, context: Context) {
        context.coordinator.update(document: runner.document, sourceDocument: nil, reloadToken: 0, loadID: 1, in: web)
    }
}

@MainActor
private final class NavigationRunner: ObservableObject {
    let output = URL(fileURLWithPath: Bundle.main.object(forInfoDictionaryKey: "ProbeOutputRoot") as! String)
    let provider: InstalledFontServiceProvider
    let libraryService: FontLibraryService
    let installed: InstalledFontSettingsModel
    let library: FontLibrarySettingsModel
    let analytics = AppExecutionAnalyticsSettingsModel()
    let document: RhwpStudioDocumentPayload
    private let fixture: FontChangeFixture
    var web: WKWebView?
    var coordinator: RhwpStudioWebView.Coordinator?
    var session: RhwpStudioEditorSession?
    var failure: String?
    private var started = false
    private var checks: [String] = []
    private var settingsWindow: NSWindow?
    struct Failure: Error { let message: String }

    init() {
        let root = output.appendingPathComponent("private-state")
        fixture = try! FontChangeFixture(repository: URL(fileURLWithPath:
            Bundle.main.object(forInfoDictionaryKey: "ProbeRepositoryRoot") as! String),
            directory: root.appendingPathComponent("sources"), create: true)
        let catalog = try! InstalledFontCatalogService(persistence: .file(at: root.appendingPathComponent("installed")),
            environment: fixture.environment, observeChanges: false)
        provider = InstalledFontServiceProvider(factory: { catalog })
        installed = InstalledFontSettingsModel(makeService: { catalog })
        let service = FontLibraryService(store: .init(rootURL: root.appendingPathComponent("library")))
        libraryService = service
        library = FontLibrarySettingsModel(makeClient: { .init(service: service) })
        let url = output.appendingPathComponent("gowun-document.hwpx")
        document = .init(data: try! Data(contentsOf: url), filename: url.lastPathComponent, revision: 1, sourceProtection: .plain)
    }
    private func check(_ value: Bool, _ message: String) throws {
        guard value else { throw Failure(message: message) }
        checks.append(message); print("PASS: \(message)")
    }
    private func wait(_ message: String, _ predicate: () async throws -> Bool) async throws {
        let deadline = Date().addingTimeInterval(30)
        while !(try await predicate()) {
            guard Date() < deadline else { throw Failure(message: "timeout: \(message); \(failure ?? "")") }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
    }
    private func js(_ code: String) async throws -> Any? {
        try await web!.callAsyncJavaScript(code, arguments: [:], in: nil, contentWorld: .page)
    }
    private func editorState() async throws -> String? {
        try await js("const s=await window.__alhangeulHostBridgeReadSession();return JSON.stringify([s.documentEpoch,s.changeSeq,s.dirty]);") as? String
    }
    private func capture(_ window: NSWindow, _ name: String) async throws {
        try await Task.sleep(nanoseconds: 300_000_000)
        guard #available(macOS 14.4, *) else { throw Failure(message: "capture requires macOS 14.4") }
        let content = try await SCShareableContent.currentProcess
        guard let owned = content.windows.first(where: { $0.windowID == CGWindowID(window.windowNumber) }) else {
            throw Failure(message: "own window missing")
        }
        let configuration = SCStreamConfiguration()
        // 화면 전환/Stage Manager의 SCWindow 표시 크기 대신 실제 AppKit 창 크기를 쓴다.
        configuration.width = Int(window.frame.width * 2); configuration.height = Int(window.frame.height * 2)
        configuration.showsCursor = false; configuration.ignoreShadowsSingleWindow = true
        let cg = try await SCScreenshotManager.captureImage(contentFilter: SCContentFilter(desktopIndependentWindow: owned), configuration: configuration)
        guard let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else { throw Failure(message: "PNG") }
        try png.write(to: output.appendingPathComponent(name))
    }
    func run() async {
        guard !started else { return }; started = true
        do {
            await installed.prepare(); await library.prepare()
            try await wait("document and Settings opener") { self.session?.snapshot.ready == true && self.web?.window != nil }
            let documentWindow = web!.window!
            documentWindow.center(); documentWindow.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
            let original = try await editorState()
            try check(try await js("return window.rhwpStudio.automation.execute('tool:options', undefined, {allowDialog:true}).ok;") as? Bool == true,
                "기존 도구→환경설정 명령으로 대화상자 열기")
            try await wait("native font section") { try await self.js("return !!document.querySelector('[data-alhangeul-font-settings]');") as? Bool == true }
            try check(try await js("const p=document.querySelector('.opt-body');return p.textContent.includes('Mac 글꼴') && !p.textContent.includes('Chrome/Edge') && !p.textContent.includes('이 브라우저') && p.querySelectorAll('[data-alhangeul-font-settings] button').length===1 && !!p.querySelector('#opt-show-recent') && !!p.querySelector('[data-tab=file]');") as? Bool == true,
                "Mac 안내·단일 설정 버튼, 최근/대표/파일 설정 보존")
            try await capture(documentWindow, "studio-preferences.png")
            AppSettingsNavigation.shared.selectedTab = .privacy
            _ = try await js("document.querySelector('[data-alhangeul-font-settings] button').click();")
            try await wait("real Settings Scene") {
                self.settingsWindow = NSApp.windows.first { $0 !== documentWindow && $0.isVisible && !$0.isSheet }
                return self.settingsWindow != nil && AppSettingsNavigation.shared.selectedTab == .fonts
            }
            try await capture(settingsWindow!, "native-font-settings.png")
            try check(true, "Studio 버튼→native bridge→공개 openSettings→실제 Settings Scene 글꼴 탭")
            // 가져오기 버튼과 동일한 기존 product model action. 변경하지 않은 버튼의
            // 물리 클릭을 시험했다고 주장하지 않고 새 Settings Scene의 sheet 결합을 확인한다.
            library.beginImport()
            try await wait("one import sheet") { self.settingsWindow?.attachedSheet != nil }
            try check(settingsWindow!.sheets.count == 1, "보관함 창 없이 가져오기 sheet 하나로 진입")
            try await capture(settingsWindow!.attachedSheet!, "native-font-import.png")
            library.dismissImport()
            try await wait("import dismissed") { self.settingsWindow?.attachedSheet == nil }
            settingsWindow!.close()
            // 같은 origin의 iframe도 native 설정 진입을 허용하지 않는다.
            AppSettingsNavigation.shared.selectedTab = .privacy
            _ = try await js("await new Promise(resolve=>{const f=document.createElement('iframe');f.onload=()=>{f.contentWindow.webkit.messageHandlers.alhangeulHost.postMessage({type:'command',command:'app:font-settings'});setTimeout(()=>{f.remove();resolve();},300);};f.srcdoc='<html></html>';document.body.append(f);});")
            try check(AppSettingsNavigation.shared.selectedTab == .privacy && settingsWindow!.isVisible == false,
                "같은 origin iframe의 설정 명령 거부")
            _ = try await js("document.querySelector('[data-alhangeul-font-settings] button').click();")
            try await wait("settings reopened on fonts tab") {
                self.settingsWindow = NSApp.windows.first { $0 !== documentWindow && $0.isVisible && !$0.isSheet }
                return AppSettingsNavigation.shared.selectedTab == .fonts && self.settingsWindow != nil
            }
            try check(true, "설정 재열기에서도 글꼴 탭 선택")
            try check(try await editorState() == original, "설정·가져오기 왕복에서 문서 epoch/changeSeq/dirty 보존")
            try check(failure == nil, "native/Studio 오류 없음")
            finish(nil)
        } catch { finish(String(describing: error)) }
    }
    private func finish(_ error: String?) {
        let result: [String: Any] = ["passed": error == nil, "checks": checks, "error": error as Any? ?? NSNull()]
        try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("settings-navigation-result.json"))
        if let error { print("FAIL: \(error)") }
        if error == nil && CommandLine.arguments.contains("--interactive") {
            settingsWindow?.close()
            web?.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            print("직접 조작: Studio 환경설정의 글꼴 설정 열기… → 글꼴 가져오기…"); return
        }
        exit(error == nil ? 0 : 1)
    }
}

@MainActor final class DocumentWindowPresenter {
    static let shared = DocumentWindowPresenter()
    func openDocument(_ url: URL) { fatalError("external open outside probe") }
}
