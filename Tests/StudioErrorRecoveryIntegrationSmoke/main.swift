import AppKit
import SwiftUI
import WebKit

/// 실제 JS 오류 이벤트와 제품 preflight를 사용한다. upstream rollback/OS process kill 검사는 아니다.
@main struct StudioErrorRecoveryIntegrationSmoke {
    struct Failure: Error, CustomStringConvertible { let description: String }
    @MainActor static var checks = 0
    @MainActor static func check(_ value: Bool, _ name: String) throws {
        guard value else { throw Failure(description: name) }
        checks += 1; print("PASS \(name)")
    }
    @MainActor static func wait(_ name: String, _ predicate: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(20)
        while !predicate() {
            guard Date() < deadline else { throw Failure(description: "timeout: \(name)") }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
    }
    @MainActor static func web(_ view: NSView) -> WKWebView? {
        if let value = view as? WKWebView { return value }
        return view.subviews.compactMap { web($0) }.first
    }
    @MainActor static func js(_ web: WKWebView, _ source: String, _ args: [String: Any] = [:]) async throws -> Any? {
        try await web.callAsyncJavaScript(source, arguments: args, in: nil, contentWorld: .page)
    }
    @MainActor static func ready(_ store: DocumentViewerStore) async throws {
        try await wait("ready") { store.canRunWebViewCommands && store.editorSession?.snapshot.ready == true }
        try await Task.sleep(nanoseconds: 400_000_000)
    }
    @MainActor static func openFixture(_ fixture: URL, _ store: DocumentViewerStore) async throws {
        let previousLoad = store.webViewLoadID
        store.loadDocument(from: fixture)
        // 이미 열린 빈 문서의 ready를 새 파일의 ready로 오인하지 않는다.
        try await wait("native fixture committed") {
            store.webViewLoadID > previousLoad && store.sourceDocument?.url == fixture && !store.isLoading
        }
        try await ready(store)
        try check(store.editorSession?.sourceBinding == .nativeLoad && store.editorSession?.snapshot.format == fixture.pathExtension,
            "ready belongs to requested native fixture and format")
    }
    @MainActor static func makeWindow(_ store: DocumentViewerStore) -> NSWindow {
        let window = NSWindow(contentRect: .init(x: 100, y: 100, width: 960, height: 800),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.title = "오류 복구 통합 검증"
        window.contentView = NSHostingView(rootView: DocumentViewerView(store: store))
        window.makeKeyAndOrderFront(nil)
        return window
    }
    @MainActor static func type(_ web: WKWebView, _ text: String) async throws {
        _ = try await js(web, """
        const input = document.querySelector('textarea'); input.focus();
        if (!document.execCommand('insertText', false, text)) throw Error('insert failed');
        """, ["text": text])
    }
    @MainActor static func elements(_ value: AnyObject) -> [AnyObject] {
        let children = value.accessibilityChildren?() ?? []
        return [value] + children.flatMap { elements($0 as AnyObject) }
    }
    @MainActor static func find(_ identifier: String, _ view: NSView) -> AnyObject? {
        elements(view).first { $0.accessibilityIdentifier?() == identifier }
    }
    @MainActor static func capture(_ window: NSWindow, _ url: URL) throws {
        let view = window.contentView!
        view.displayIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw Failure(description: "capture") }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw Failure(description: "PNG") }
        try png.write(to: url)
    }
    @MainActor static func verifyReportUI(_ store: DocumentViewerStore, _ window: NSWindow, _ output: URL) async throws {
        let view = window.contentView!
        try await Task.sleep(nanoseconds: 500_000_000)
        try check(find("copy-error-report", view) == nil, "actual fatal screen starts with details collapsed")
        try capture(window, output.appendingPathComponent("fatal-collapsed.png"))
        guard let disclosure = elements(view).first(where: {
            $0.accessibilityRole?() == .disclosureTriangle && $0.accessibilityLabel?() == "오류 세부정보"
        }) else { throw Failure(description: "actual fatal disclosure missing") }
        try check(disclosure.accessibilityPerformPress?() == true, "expand actual fatal details")
        try await Task.sleep(nanoseconds: 600_000_000)
        guard let text = find("error-report-text", view), let button = find("copy-error-report", view) else {
            throw Failure(description: "actual report controls missing")
        }
        let report = store.errorReport
        let visibleValue: String? = text.accessibilityValue?()
        try check((visibleValue ?? text.accessibilityLabel?()) == report,
            "displayed fatal report equals store report")
        // 일반 클립보드의 모든 즉시 읽기 가능한 형식을 메모리에서 보존하고 검사 후 복원한다.
        // 사용자가 도중에 새 내용을 복사했다면 그것을 덮어쓰지 않는다. 내용은 로그에 기록하지 않는다.
        let board = NSPasteboard.general
        let saved = (board.pasteboardItems ?? []).map { item -> NSPasteboardItem in
            let copy = NSPasteboardItem()
            for type in item.types { if let data = item.data(forType: type) { copy.setData(data, forType: type) } }
            return copy
        }
        var ownChange: Int?
        defer {
            if let ownChange, board.changeCount == ownChange {
                board.clearContents()
                if !saved.isEmpty { board.writeObjects(saved) }
            }
        }
        try check(button.accessibilityPerformPress?() == true, "press actual report copy button")
        ownChange = board.changeCount
        try check(board.string(forType: .string) == report, "actual general clipboard matches displayed report exactly")
        try await Task.sleep(nanoseconds: 150_000_000)
        try check(find("copy-error-report", view)?.accessibilityLabel?() == "복사됨", "successful copy feedback")
        try capture(window, output.appendingPathComponent("fatal-expanded.png"))
        try check(disclosure.accessibilityPerformPress?() == true, "collapse actual fatal details")
    }
    @MainActor static func run(fixture: URL, output: URL) async throws {
        let store = DocumentViewerStore(), otherStore = DocumentViewerStore()
        let window = makeWindow(store), other = makeWindow(otherStore)
        defer {
            for (value, store) in [(window, store), (other, otherStore)] {
                value.orderOut(nil); value.contentView = nil; store.releaseRecoveryResources()
            }
        }
        try await openFixture(fixture, store)
        try await openFixture(fixture, otherStore)
        let otherWeb = web(other.contentView!)!
        let otherEpoch = otherStore.editorSession!.snapshot.documentEpoch
        _ = try await js(otherWeb, "return await window.rhwpStudio.automation.execute('file:new-doc');")
        try await wait("other new document") { (otherStore.editorSession?.snapshot.documentEpoch ?? 0) > otherEpoch }
        try await Task.sleep(nanoseconds: 700_000_000)
        try await type(otherWeb, "독립된 창 alpha")
        try await wait("other dirty") { otherStore.hasUnsavedChanges }
        let otherSnapshot = otherStore.editorSession!.snapshot
        let original = web(window.contentView!)!
        let oldCoordinator = original.navigationDelegate as! RhwpStudioWebView.Coordinator
        let before = store.editorSession!.snapshot
        // 네이티브 메시지를 위조하지 않고 실제 비동기 uncaught exception을 발생시킨다.
        _ = try await js(original, "setTimeout(() => { throw Error('TASK594_REAL_UNCAUGHT ' + path); }, 0); return true;",
            ["path": fixture.path])
        try await wait("real uncaught fatal") { store.webViewFailure != nil && web(window.contentView!) == nil }
        try check(store.suspendedSnapshot == before && !store.canRunWebViewCommands && original.isHidden,
            "actual uncaught exception suspends and removes editor with metadata retained")
        let report = store.errorReport
        for required in ["errorID=", "occurredAt=", "appVersion=", "appBuild=", "rhwpRelease=v0.8.7",
                         "rhwpCommit=1a76570e833917d15817415a53c09ad61ab3203f", "category=runtime",
                         "sessionLoadID=", "documentEpoch=", "dirty=false", "TASK594_REAL_UNCAUGHT"] {
            try check(report.contains(required), "real diagnostic contains \(required)")
        }
        try check(!report.contains(fixture.path) && !report.contains(fixture.lastPathComponent) && !report.contains("=unknown"),
            "real report hides document identity and resolves bundle metadata")
        try await verifyReportUI(store, window, output)
        try check(store.errorReport == report, "report identity and timestamp stable across disclosure and copy")
        try check(web(other.contentView!) === otherWeb && otherStore.editorSession!.snapshot == otherSnapshot && otherStore.canRunWebViewCommands,
            "fatal in one window preserves other window session and dirty")
        NSApp.activate(ignoringOtherApps: true); other.makeKeyAndOrderFront(nil)
        try await wait("other window key") { NSApp.keyWindow === other }
        let otherCoordinator = otherWeb.navigationDelegate as! RhwpStudioWebView.Coordinator
        let destination = output.appendingPathComponent("independent-window.hwp")
        otherCoordinator.chooseSaveDestination = { _, _, _ in destination }
        try check(RhwpStudioNativeCommandDispatcher.run("edit:undo", in: other), "other window can undo after fatal")
        try await Task.sleep(nanoseconds: 300_000_000)
        try check(RhwpStudioNativeCommandDispatcher.run("edit:redo", in: other), "other window can redo after fatal")
        try await Task.sleep(nanoseconds: 300_000_000)
        try await type(otherWeb, " beta")
        _ = RhwpStudioNativeCommandDispatcher.run("file:save-as-hwp", in: other)
        try await wait("other window save") { otherStore.previousSave != nil && !otherStore.hasUnsavedChanges && !otherCoordinator.isSavingDocument }
        let parser = try RhwpDocument(data: Data(contentsOf: destination), filename: destination.lastPathComponent)
        try check(parser.pageCount > 0 && store.webViewFailure != nil, "independent window edits and saves while first stays suspended")
        store.confirmRecoveryTransition = { _, _ in true }
        for iteration in 1...3 {
            let loadID = store.webViewLoadID, token = store.webViewReloadToken
            store.retryWebViewLoad(); try await ready(store)
            let live = web(window.contentView!)!
            try check(store.webViewLoadID > loadID && store.webViewReloadToken > token && !store.hasUnsavedChanges && store.errorReport.isEmpty,
                "repeat \(iteration) ready uses a fresh load and clears old fatal report")
            oldCoordinator.webViewWebContentProcessDidTerminate(original)
            try await Task.sleep(nanoseconds: 150_000_000)
            try check(store.webViewFailure == nil && store.canRunWebViewCommands, "old suspended coordinator cannot relatch new load \(iteration)")
            // 실제 Promise rejection을 bridge가 포착한다. upstream 명령 실패 producer를 사용하지 않는다.
            _ = try await js(live, "setTimeout(() => { Promise.reject(Error('TASK594_REAL_REJECTION')); }, 0); return true;")
            try await wait("real rejection \(iteration)") { store.webViewFailure != nil && web(window.contentView!) == nil }
            try check(store.errorReport.contains("TASK594_REAL_REJECTION"), "repeat \(iteration) real rejection reaches report")
        }
        // 소유 진단 bundle만 일시 변경하여 실제 resource preflight와 명시적 retry를 통과시킨다.
        guard Bundle.main.bundleIdentifier?.hasPrefix("com.postmelee.studio-lifecycle.task594-integration-") == true else {
            throw Failure(description: "owned diagnostic bundle required")
        }
        let index = try RhwpStudioResourceLocator.resourceDirectoryURL().appendingPathComponent("index.html")
        let backup = index.appendingPathExtension("stage4-backup")
        let bytes = try Data(contentsOf: index)
        try FileManager.default.moveItem(at: index, to: backup)
        defer { if FileManager.default.fileExists(atPath: backup.path) { try? FileManager.default.moveItem(at: backup, to: index) } }
        store.retryWebViewLoad()
        try await wait("real resource preflight failure") { store.webViewFailure?.category == .resourcePreflight && web(window.contentView!) == nil }
        try check(store.errorReport.contains("index.html"), "real missing index is identified in diagnostic")
        try check(!store.canRunWebViewCommands && !store.errorReport.contains(index.path), "real missing asset stops editor and sanitizes diagnostic path")
        try FileManager.default.moveItem(at: backup, to: index)
        store.retryWebViewLoad(); try await ready(store)
        try check(try Data(contentsOf: index) == bytes && store.webViewFailure == nil && !store.hasUnsavedChanges,
            "restored diagnostic asset and explicit retry recover actual editor")
    }
    @MainActor static func main() {
        setbuf(stdout, nil)
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.accessibilitySetValue(true, forAttribute: .init(rawValue: "AXEnhancedUserInterface"))
        Task { @MainActor in
            do {
                let fixture = URL(fileURLWithPath: CommandLine.arguments[1])
                let output = URL(fileURLWithPath: CommandLine.arguments[2])
                let before = try Data(contentsOf: fixture)
                try await run(fixture: fixture, output: output)
                try check(try Data(contentsOf: fixture) == before, "read-only fixture unchanged")
                print("PASS \(checks) real runtime/init integration checks (no upstream rollback or OS process kill)")
                app.stop(nil); exit(0)
            } catch { print("FAIL \(error)"); app.stop(nil); exit(1) }
        }
        app.run()
    }
}

@MainActor final class DocumentWindowPresenter {
    static let shared = DocumentWindowPresenter()
    func openDocument(_ url: URL) { fatalError("unexpected external open") }
}
