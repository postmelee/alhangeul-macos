import AppKit
import SwiftUI

@main
struct InstalledFontUIProbe {
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
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task {
            do { try await show() }
            catch { print("FAIL: \(error)"); exit(1) }
        }
    }
    func show() async throws {
        let root = URL(fileURLWithPath: Bundle.main.object(forInfoDictionaryKey: "ProbeRepositoryRoot") as! String)
            .appendingPathComponent("build.noindex/task565-stage5/ui-data")
        let live = CommandLine.arguments.contains("--live")
        let catalog = try await Task.detached {
            try InstalledFontCatalogService(persistence: .file(at: root.appendingPathComponent(live ? "installed-live" : "installed")),
                environment: live ? InstalledFontSystem().environment : .init(scan: { _ in
                    .init(records: [
                        Self.record("regular", name: "나눔스퀘어 Regular"),
                        Self.record("bold", name: "나눔스퀘어 Bold"),
                        Self.record("long", name: "긴 이름 확인용 예제 글꼴 — 여러 언어와 스타일 이름을 함께 표시하는 설치 글꼴 Regular Extended", failure: .conflict),
                        Self.record("denied", name: "권한 복구 예제 글꼴", failure: .permissionDenied)
                    ], grantIssues: [])
                }, read: { _, _ in throw InstalledFontFailure.unsupported },
                makeBookmark: { _ in throw InstalledFontFailure.unsupported }), observeChanges: false)
        }.value
        let model = InstalledFontSettingsModel(makeService: { catalog })
        let library = FontLibrarySettingsModel(makeClient: {
            FontLibraryUIClient(service: .init(store: .init(rootURL: root.appendingPathComponent("library"))))
        })
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 560),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = live ? "알한글 글꼴 — 실제 Mac 목록 · 격리 테스트" : "알한글 글꼴 — 테스트 데이터"
        window.appearance = NSAppearance(named: CommandLine.arguments.contains("--dark") ? .darkAqua : .aqua)
        window.contentView = NSHostingView(rootView: InstalledFontSettingsView(model: model, library: library).frame(width: 720, height: 560))
        window.setContentSize(NSSize(width: 720, height: 560))
        window.center(); window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    nonisolated static func record(_ id: String, name: String, failure: InstalledFontFailure? = nil) -> InstalledFontRecord {
        .init(id: id, sourceURL: URL(fileURLWithPath: "/fixture/\(id).ttf"),
              postScriptName: id, family: id == "regular" || id == "bold" ? "나눔스퀘어" : name, fullName: name, style: id == "bold" ? "Bold" : "Regular",
              version: "1", traits: 0, axes: [], stamp: nil, failure: failure)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
