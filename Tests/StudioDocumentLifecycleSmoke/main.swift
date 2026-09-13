import AppKit
import SwiftUI
import WebKit

// 실제 SwiftUI 뷰와 제품 Store/Coordinator/종료 controller를 함께 실행한다.
// 문서 입력·저장 위치·NSAlert 응답은 테스트에서 주입하며 물리 UI 검증과 구분한다.
@main struct StudioDocumentLifecycleSmoke {
    struct Failure: Error, CustomStringConvertible { let description: String }
    @MainActor static var checks = 0
    @MainActor static func check(_ value: Bool, _ name: String) throws {
        guard value else { throw Failure(description: name) }
        checks += 1
        print("PASS \(name)")
    }
    @MainActor static func wait(_ name: String, _ predicate: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(15)
        while !predicate() {
            guard Date() < deadline else { throw Failure(description: "timeout: \(name)") }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
    }
    @MainActor static func web(in view: NSView) -> WKWebView? {
        if let result = view as? WKWebView { return result }
        return view.subviews.compactMap { web(in: $0) }.first
    }
    @MainActor static func js(_ web: WKWebView, _ source: String) async throws -> Any? {
        try await web.callAsyncJavaScript(source, arguments: [:], in: nil, contentWorld: .page)
    }
    @MainActor static func type(_ web: WKWebView, _ text: String) async throws {
        _ = try await web.callAsyncJavaScript("""
        const input = document.querySelector('textarea');
        input.focus();
        if (!document.execCommand('insertText', false, text)) throw new Error('insert failed');
        """, arguments: ["text": text], in: nil, contentWorld: .page)
    }
    @MainActor static func save(_ window: NSWindow) async -> RhwpStudioDocumentSaveResult {
        await withCheckedContinuation { continuation in
            if !RhwpStudioNativeCommandDispatcher.saveDocument(in: window, completion: {
                continuation.resume(returning: $0)
            }) { continuation.resume(returning: .failed("dispatcher unavailable")) }
        }
    }
    @MainActor static func answer(_ window: NSWindow, _ response: NSApplication.ModalResponse) async throws {
        try await wait("confirmation sheet") { window.attachedSheet != nil }
        window.endSheet(window.attachedSheet!, returnCode: response)
        try await wait("confirmation dismissed") { window.attachedSheet == nil }
        // beginSheet completion이 MainActor Task로 전달된다. 다음 종료 요청과 경합하지 않는다.
        try await Task.sleep(nanoseconds: 100_000_000)
    }
    static func verifyFile(_ url: URL, format: DocumentSaveFormat, text: String) throws {
        let data = try Data(contentsOf: url)
        guard format.matchesPayloadSignature(data) else { throw Failure(description: "wrong container") }
        let document = try RhwpDocument(data: data, filename: url.lastPathComponent)
        guard document.pageCount > 0, let svg = document.renderPageSVG(at: 0) else {
            throw Failure(description: "core roundtrip")
        }
        let rendered = svg.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .filter { !$0.isWhitespace }
        // 재열기 후 커서가 첫 위치로 복귀할 수 있으므로 입력 순서가 아니라 모든 표식을 확인한다.
        guard text.split(whereSeparator: { $0.isWhitespace }).allSatisfy({ rendered.contains($0) }) else {
            throw Failure(description: "saved Korean text missing")
        }
    }
    @MainActor static func run(format: DocumentSaveFormat, fixture: URL, output: URL) async throws {
        let store = DocumentViewerStore()
        let window = NSWindow(contentRect: NSRect(x: 150, y: 150, width: 920, height: 660),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.title = "저장·종료 회귀 \(format.rawValue)"
        window.contentView = NSHostingView(rootView: ContentView(store: store))
        window.makeKeyAndOrderFront(nil)
        let close = DocumentCloseConfirmationController()
        defer { close.detach(restorePreviousDelegate: true); window.orderOut(nil) }
        store.loadDocument(from: fixture)
        try await wait("fixture ready") { store.hasDocument && !store.isLoading && !store.isWebViewLoading }
        let original = web(in: window.contentView!)!
        let epoch = store.editorSession!.snapshot.documentEpoch
        _ = try await js(original, "return await window.rhwpStudio.automation.execute('file:new-doc');")
        try await wait("new editor document") { (store.editorSession?.snapshot.documentEpoch ?? 0) > epoch }
        // SwiftUI invalidation까지 기다려 단순 Coordinator 검증이 놓친 재생성을 잡는다.
        try await Task.sleep(nanoseconds: 700_000_000)
        let current = web(in: window.contentView!)!
        try check(original === current, "\(format.rawValue): new document preserves WKWebView")
        let actual = try await js(current, "return await window.__alhangeulHostBridgeReadSession();") as! [String: Any]
        try check(actual["documentEpoch"] as? Int == store.editorSession?.snapshot.documentEpoch,
            "\(format.rawValue): native and editor epoch agree")
        let coordinator = current.navigationDelegate as! RhwpStudioWebView.Coordinator
        let destination = output.appendingPathComponent("saved.\(format.rawValue)")
        let marker = "알한글 저장 검증"
        try await type(current, marker)
        try await wait("dirty") { store.hasUnsavedChanges }
        coordinator.chooseSaveDestination = { _, _, _ in nil }
        let cancelled = await save(window)
        if case .cancelled = cancelled {} else { throw Failure(description: "save cancellation") }
        try check(store.hasUnsavedChanges && store.sourceDocument == nil, "save cancellation preserves new document")
        coordinator.chooseSaveDestination = { _, _, _ in destination }
        coordinator.writeSaveData = { _, _, _ in throw Failure(description: "injected write failure") }
        let failed = await save(window)
        if case .failed = failed {} else { throw Failure(description: "write failure result") }
        try check(store.hasUnsavedChanges && store.sourceDocument == nil && !FileManager.default.fileExists(atPath: destination.path),
            "write failure keeps dirty and creates no destination")
        store.dismissWebViewError()
        coordinator.writeSaveData = { try DocumentSavePanel.write(data: $0, to: $1, allowOverwrite: $2) }
        try check(RhwpStudioNativeCommandDispatcher.run("file:save-as-\(format.rawValue)", in: window), "format save dispatched")
        try await wait("saved source and clean") { store.sourceDocument?.url == destination && !store.hasUnsavedChanges }
        try verifyFile(destination, format: format, text: marker)
        try check(store.filename == destination.lastPathComponent && web(in: window.contentView!) === original,
            "first save preserves editor and binds filename")
        let bound = store.editorSession!.snapshot
        try await type(current, " 반복")
        try await wait("repeat dirty") { store.hasUnsavedChanges }
        coordinator.chooseSaveDestination = { _, _, _ in nil }
        let repeated = await save(window)
        if case .saved(let url) = repeated { try check(url == destination, "repeat save same destination") }
        else { throw Failure(description: "repeat save failed") }
        try await wait("repeat clean") { !store.hasUnsavedChanges }
        try verifyFile(destination, format: format, text: marker + " 반복")
        try check(store.editorSession?.snapshot.documentEpoch == bound.documentEpoch,
            "repeat save preserves epoch")
        let previousLoad = store.webViewLoadID
        store.loadDocument(from: destination)
        try await wait("saved document reopened") {
            store.webViewLoadID > previousLoad && store.hasDocument && !store.isLoading && !store.isWebViewLoading
        }
        try check(web(in: window.contentView!) === current && store.sourceDocument?.url == destination,
            "explicit reopen uses new load in same WebView")
        try verifyFile(destination, format: format, text: marker + " 반복")
        try await type(current, " 종료")
        try await wait("close dirty") { store.hasUnsavedChanges }
        close.attach(window: window, store: store)
        window.performClose(nil)
        try await answer(window, .alertThirdButtonReturn)
        try check(window.isVisible && store.hasUnsavedChanges, "close cancellation preserves dirty window")
        coordinator.writeSaveData = { _, _, _ in throw Failure(description: "injected close save failure") }
        window.performClose(nil)
        try await answer(window, .alertFirstButtonReturn)
        try await wait("close save failure") { store.webViewErrorMessage != nil }
        try check(window.isVisible && store.hasUnsavedChanges, "close save failure keeps dirty window")
        store.dismissWebViewError()
        coordinator.writeSaveData = { try DocumentSavePanel.write(data: $0, to: $1, allowOverwrite: $2) }
        var reply: Bool?
        let termination = DocumentTerminationCoordinator { _, result in reply = result }
        _ = termination.applicationShouldTerminate(NSApp)
        try await answer(window, .alertThirdButtonReturn)
        try await wait("termination cancelled") { reply != nil }
        try check(reply == false && store.hasUnsavedChanges, "termination cancellation preserves document")
        reply = nil
        _ = termination.applicationShouldTerminate(NSApp)
        try await answer(window, .alertFirstButtonReturn)
        try await wait("termination saved") { reply != nil }
        try check(reply == true && !store.hasUnsavedChanges, "save permits app termination")
        try verifyFile(destination, format: format, text: marker + " 반복 종료")
        try await type(current, " 닫기")
        try await wait("final dirty") { store.hasUnsavedChanges }
        window.performClose(nil)
        try await answer(window, .alertFirstButtonReturn)
        try await wait("window closed after save") { !window.isVisible }
        try verifyFile(destination, format: format, text: marker + " 반복 종료 닫기")
        try check(!store.hasUnsavedChanges, "save closes real window and preserves final text")

        // 닫힌 window/controller는 재사용하지 않고 별도 창에서 버리기를 확인한다.
        let discardStore = DocumentViewerStore()
        let discardWindow = NSWindow(contentRect: window.frame, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        discardWindow.isReleasedWhenClosed = false
        discardWindow.contentView = NSHostingView(rootView: ContentView(store: discardStore))
        discardWindow.makeKeyAndOrderFront(nil)
        let discardClose = DocumentCloseConfirmationController()
        defer { discardClose.detach(restorePreviousDelegate: true); discardWindow.orderOut(nil) }
        let savedBytes = try Data(contentsOf: destination)
        discardStore.loadDocument(from: destination)
        try await wait("discard document ready") { discardStore.hasDocument && !discardStore.isLoading && !discardStore.isWebViewLoading }
        try await type(web(in: discardWindow.contentView!)!, " 버릴내용")
        try await wait("discard dirty") { discardStore.hasUnsavedChanges }
        discardClose.attach(window: discardWindow, store: discardStore)
        discardWindow.performClose(nil)
        try await answer(discardWindow, .alertSecondButtonReturn)
        try await wait("discard closed") { !discardWindow.isVisible }
        try check(try Data(contentsOf: destination) == savedBytes, "discard closes without changing saved bytes")
    }
    @MainActor static func main() {
        setbuf(stdout, nil)
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        Task { @MainActor in
            do {
                let fixture = URL(fileURLWithPath: CommandLine.arguments[1])
                let output = URL(fileURLWithPath: CommandLine.arguments[2])
                let before = try Data(contentsOf: fixture)
                for format in [DocumentSaveFormat.hwp, .hwpx] {
                    try await run(format: format, fixture: fixture, output: output)
                }
                try check(try Data(contentsOf: fixture) == before, "input unchanged")
                print("PASS TOTAL \(checks)")
                exit(0)
            } catch { print("FAIL \(error)"); exit(1) }
        }
        app.run()
    }
}

// HostApp.swift의 실제 창 생성은 이 smoke 범위 밖이다. 사용 시 즉시 실패한다.
@MainActor final class DocumentWindowPresenter {
    static let shared = DocumentWindowPresenter()
    func openDocument(_ url: URL) { fatalError("unexpected external document open") }
}
