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
            try InstalledFontCatalogService(persistence: .file(at: root.appendingPathComponent(live ? "installed-live" : "installed-demo28")),
                environment: live ? InstalledFontSystem().environment : .init(scan: { _ in
                    .init(records: Self.demoRecords(), grantIssues: [])
                }, read: { _, _ in throw InstalledFontFailure.unsupported },
                makeBookmark: { _ in throw InstalledFontFailure.unsupported }), observeChanges: false)
        }.value
        let model = InstalledFontSettingsModel(makeService: { catalog })
        let library = FontLibrarySettingsModel(makeClient: {
            FontLibraryUIClient(service: .init(store: .init(rootURL: root.appendingPathComponent("library"))))
        })
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 560),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = live ? "알한글 글꼴 — 실제 Mac 목록 · 격리 테스트" : "알한글 글꼴 — 가상 글꼴 28개 · 테스트"
        window.appearance = NSAppearance(named: CommandLine.arguments.contains("--dark") ? .darkAqua : .aqua)
        window.contentView = NSHostingView(rootView: InstalledFontSettingsView(model: model, library: library).frame(width: 720, height: 560))
        window.setContentSize(NSSize(width: 720, height: 560))
        window.center(); window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    nonisolated static func demoRecords() -> [InstalledFontRecord] {
        let names = [
            "가상 가람고딕", "가상 나래명조", "가상 다온산스", "가상 라온바탕",
            "가상 마루고딕", "가상 바른돋움", "가상 새봄명조", "가상 아침고딕",
            "가상 여울손글씨", "가상 온유바탕", "가상 자람고딕", "가상 초록산스",
            "가상 하늘명조", "가상 한결돋움", "가상 한빛고딕", "가상 해솔바탕",
            "Demo Atlas Sans", "Demo Bloom Serif", "Demo Cedar Mono", "Demo Dawn Display",
            "Demo Echo Script", "Demo Fern Sans", "Demo Grove Serif", "Demo Harbor Mono",
            "가상 권한 확인 글꼴", "가상 같은 이름 충돌 글꼴", "가상 미지원 글꼴",
            "가상 긴 이름 확인용 글꼴 — 여러 언어와 다양한 스타일을 함께 표시하는 확장 패밀리"
        ]
        return names.enumerated().flatMap { index, family in
            ["Regular", "Bold", "Light"].map { style in
                let id = "demo-\(index)-\(style)"
                let failure: InstalledFontFailure? = index == 24 ? .permissionDenied
                    : index == 25 ? .conflict : index == 26 ? .unsupported : nil
                return InstalledFontRecord(id: id, sourceURL: URL(fileURLWithPath: "/fixture/\(id).ttf"),
                    postScriptName: id, family: family, fullName: "\(family) \(style)", style: style,
                    version: "1", traits: 0, axes: [], stamp: nil, failure: failure)
            }
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
