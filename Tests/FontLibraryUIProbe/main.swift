import AppKit
import SwiftUI

// 제품과 같은 View/모델을 자체 fixture·격리 저장소로 실행한다.
// 이 preview는 signed 제품 sandbox/NSOpenPanel 수용 검증을 대신하지 않는다.
@main
struct FontLibraryUIProbe {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = PreviewDelegate()
        app.delegate = delegate
        app.run()
        withExtendedLifetime(delegate) {}
    }
}

@MainActor
private final class PreviewDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var model: FontLibrarySettingsModel!

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task {
            do { try await run() }
            catch { print("UI preview failed: \(error)"); exit(1) }
        }
    }
    func run() async throws {
        guard let path = Bundle.main.object(forInfoDictionaryKey: "ProbeRepositoryRoot") as? String else {
            throw FontLibraryError.unsafePath
        }
        let repository = URL(fileURLWithPath: path)
        let temporary = repository.appendingPathComponent("build.noindex/task565-stage2/ui-data/\(UUID().uuidString)")
        let fonts = temporary.appendingPathComponent("예제 글꼴")
        try FileManager.default.createDirectory(at: fonts, withIntermediateDirectories: true)
        let fixtures = repository.appendingPathComponent("Tests/FontLibraryTests/Fixtures")
        for (input, name) in [("regular.ttf", "예제 글꼴 Regular.ttf"), ("bold.ttf", "예제 글꼴 Bold.ttf"), ("variable.ttf", "예제 가변 글꼴.ttf")] {
            try FileManager.default.copyItem(at: fixtures.appendingPathComponent(input), to: fonts.appendingPathComponent(name))
        }
        let client = FontLibraryUIClient(service: .init(store: .init(rootURL: temporary.appendingPathComponent("library"))))
        model = FontLibrarySettingsModel(makeClient: { client })
        await model.prepare()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 560),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "알한글 글꼴 화면 — 테스트 데이터"
        window.appearance = NSAppearance(named: .aqua)
        window.center(); window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.contentView = NSHostingView(rootView: FontLibrarySettingsView(model: model))
        window.setContentSize(NSSize(width: 720, height: 560))
        print("검증용 글꼴 폴더: \(fonts.path)")
        if CommandLine.arguments.contains("--interactive") { return }
        try await Task.sleep(nanoseconds: 400_000_000)
        model.beginImport()
        model.selectedLocations([fonts])
        try await waitFor { self.model.phase == .candidates }
        guard model.discovery.candidates.count == 3 else { throw FontLibraryError.corruptObject }
        model.importSelected()
        try await waitFor { self.model.phase == .results }
        guard model.results.count == 3, model.manifest.entries.count == 3 else { throw FontLibraryError.corruptObject }
        print("PASS: 실제 SwiftUI sheet·탐색·가져오기 3개 완료 (자체 fixture·격리 저장소)")
        model.dismissImport()
        try FileManager.default.removeItem(at: temporary)
        // sheet 애니메이션 중 AppKit의 종료 보류와 분리된 테스트 실행 종료.
        fflush(stdout)
        exit(0)
    }
    func waitFor(_ condition: () -> Bool) async throws {
        for _ in 0..<500 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        throw FontLibraryError.io(ETIMEDOUT)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
