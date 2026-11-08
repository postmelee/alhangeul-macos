import AppKit
import SwiftUI
import WebKit

/// 합성 계약 이벤트를 실제 WK transport로 전달한다. upstream의 rollback 보증 검증은 아니다.
@main struct StudioCommandFailureSmoke {
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
    @MainActor static func web(in view: NSView) -> WKWebView? {
        if let web = view as? WKWebView { return web }
        return view.subviews.compactMap { web(in: $0) }.first
    }
    @MainActor static func js(_ web: WKWebView, _ source: String, _ args: [String:Any] = [:]) async throws -> Any? {
        try await web.callAsyncJavaScript(source, arguments: args, in: nil, contentWorld: .page)
    }
    @MainActor static func rpc(_ web: WKWebView, _ method: String) async throws -> String {
        let value = try await js(web, """
        return await new Promise((resolve, reject) => {
          const id = 'failure-smoke-' + Math.random();
          const timer = setTimeout(() => { window.removeEventListener('message', receive); reject(Error('RPC timeout')); }, 10000);
          function receive(event) {
            if (event.source !== window || event.data?.id !== id || event.data.type !== 'rhwp-response') return;
            clearTimeout(timer); window.removeEventListener('message', receive);
            if (event.data.error) reject(Error(String(event.data.error)));
            else resolve(JSON.stringify(event.data.result));
          }
          window.addEventListener('message', receive);
          window.postMessage({type:'rhwp-request', id, method}, '*');
        });
        """, ["method": method])
        return value as! String
    }
    @MainActor static func type(_ web: WKWebView, _ text: String) async throws {
        _ = try await js(web, """
        const input = document.querySelector('textarea'); input.focus();
        if (!document.execCommand('insertText', false, text)) throw Error('insert failed');
        """, ["text": text])
    }
    @MainActor static func emit(_ web: WKWebView, id: Int, recovery: String = "restored", oldToken: Bool = false) async throws {
        _ = try await js(web, """
        const state = await window.__alhangeulHostBridgeReadSession();
        window.webkit.messageHandlers.alhangeulHost.postMessage({
          type:'command-failure', contractVersion:1, eventID:'event-' + id, eventSequence:id,
          code:'DELETE_REJECTED', operation:'deleteSelection', loadToken: oldToken ? 'old' : state.token,
          loadID:state.loadID, documentEpoch:state.documentEpoch, changeSeq:state.changeSeq, recovery,
          checks:{content:true, cursorSelection:true, history:true, dirtyState:true, readyForNextCommand:true}
        });
        """, ["id": id, "recovery": recovery, "oldToken": oldToken])
    }
    @MainActor static func capture(_ window: NSWindow, to url: URL) throws {
        let view = window.contentView!
        view.displayIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            throw Failure(description: "native banner screenshot unavailable")
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw Failure(description: "native banner screenshot encoding")
        }
        try png.write(to: url)
    }
    @MainActor static func run(support: RhwpStudioCommandFailureSupport, format: DocumentSaveFormat,
                              fixture: URL, output: URL) async throws {
        let supported = support == .version1
        let name = "\(supported ? "synthetic-v1" : "production-default")-\(format.rawValue)"
        let store = DocumentViewerStore()
        let window = NSWindow(contentRect: .init(x: 100, y: 100, width: 940, height: 700),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.title = "명령 오류 계약 검증 \(name)"
        window.contentView = NSHostingView(rootView: DocumentViewerView(store: store, commandFailureSupport: support))
        window.makeKeyAndOrderFront(nil)
        defer { window.orderOut(nil) }
        store.loadDocument(from: fixture)
        try await wait("fixture ready") { store.hasDocument && !store.isWebViewLoading && !store.isLoading }
        let original = web(in: window.contentView!)!
        let epoch = store.editorSession!.snapshot.documentEpoch
        _ = try await js(original, "return await window.rhwpStudio.automation.execute('file:new-doc');")
        try await wait("new editor document") { (store.editorSession?.snapshot.documentEpoch ?? 0) > epoch && store.hasDocument }
        // 기존 lifecycle smoke와 같이 내부 문서 교체 뒤 SwiftUI/비동기 layout 완료를 기다린다.
        try await Task.sleep(nanoseconds: 700_000_000)
        try check(web(in: window.contentView!) === original, "new document preserves WebView")
        try await type(original, "오류 계약 검증 alpha")
        try await wait("dirty") { store.hasUnsavedChanges }
        _ = try await js(original, "return await window.rhwpStudio.automation.execute('edit:select-all');")
        let selection = try await rpc(original, "getSelectionContext")
        let state = try await rpc(original, "getDocumentState")
        let before = store.editorSession!.snapshot
        try await emit(original, id: 1, oldToken: true)
        try await Task.sleep(nanoseconds: 250_000_000)
        try check(store.commandFailurePresentation.failure == nil && store.webViewFailure == nil, "\(name): stale token ignored")
        try await emit(original, id: 1)
        if supported {
            try await wait("notice") { store.commandFailurePresentation.failure != nil }
            store.dismissCommandFailure()
            try check(!store.commandFailurePresentation.isVisible && store.commandFailurePresentation.failure != nil,
                      "dismiss retains diagnostic")
            store.showCommandFailure()
            try await emit(original, id: 2)
            try await wait("repeat count") { store.commandFailurePresentation.occurrenceCount == 2 }
            try await emit(original, id: 2)
        }
        try await Task.sleep(nanoseconds: 700_000_000)
        if supported {
            try check(store.commandFailurePresentation.occurrenceCount == 2, "same event not counted twice")
        } else {
            try check(store.commandFailurePresentation.failure == nil, "page cannot enable unsupported contract")
        }
        try check(store.webViewFailure == nil && web(in: window.contentView!) === original,
                  "\(name): SwiftUI preserves WKWebView")
        try check(store.editorSession?.snapshot.documentEpoch == before.documentEpoch
                  && store.editorSession?.sourceBinding == .newDocument
                  && store.hasUnsavedChanges && store.webViewLoadID == before.loadID,
                  "\(name): session, source binding, loadID and dirty preserved")
        try check(try await rpc(original, "getSelectionContext") == selection, "\(name): logical selection preserved")
        try check(try await rpc(original, "getDocumentState") == state, "\(name): actual content state preserved")
        if supported {
            try capture(window, to: output.appendingPathComponent("\(name)-banner.png"))
            store.setWebViewError("후속 저장 오류 진단")
            try check(!store.commandFailurePresentation.isVisible
                      && store.webViewErrorMessage == "후속 저장 오류 진단"
                      && store.commandFailurePresentation.failure != nil,
                      "new save error takes priority without losing command diagnostic")
            store.dismissWebViewError()
            store.showCommandFailure()
        }
        _ = try await js(original, "return await window.rhwpStudio.automation.execute('edit:undo');")
        try check(try await rpc(original, "getDocumentState") != state, "\(name): undo still changes content")
        _ = try await js(original, "return await window.rhwpStudio.automation.execute('edit:redo');")
        let afterRedo = try await rpc(original, "getDocumentState")
        let beforeJSON = try JSONSerialization.jsonObject(with: Data(state.utf8)) as! [String:Any]
        let redoJSON = try JSONSerialization.jsonObject(with: Data(afterRedo.utf8)) as! [String:Any]
        try check(beforeJSON["documentSha256"] as? String == redoJSON["documentSha256"] as? String,
                  "\(name): redo restores content hash")
        _ = try await js(original, "return await window.rhwpStudio.automation.execute('edit:select-all');")
        try await type(original, "후속 편집 beta")
        let destination = output.appendingPathComponent("\(name).\(format.rawValue)")
        let coordinator = original.navigationDelegate as! RhwpStudioWebView.Coordinator
        coordinator.chooseSaveDestination = { _, _, _ in destination }
        try check(RhwpStudioNativeCommandDispatcher.run("file:save-as-\(format.rawValue)", in: window), "subsequent save dispatched")
        try await wait("saved") { store.sourceDocument?.url == destination && !store.hasUnsavedChanges }
        let bytes = try Data(contentsOf: destination)
        let reopened = try RhwpDocument(data: bytes, filename: destination.lastPathComponent)
        try check(format.matchesPayloadSignature(bytes) && reopened.pageCount > 0, "\(name): subsequent save reopens in core")
        try check(web(in: window.contentView!) === original, "\(name): save preserves WebView")
        if supported {
            // 아직 실제 upstream producer가 없으므로 실패 선언도 합성 transport 검사다.
            try await emit(original, id: 3, recovery: "failed")
            try await wait("fatal") { store.webViewFailure != nil }
            store.setWebViewFailure(.runtime(message: "지정된 컨트롤이 표, 글상자 또는 그림이 아닙니다",
                sourceURL: nil, line: nil, column: nil, reason: nil, isFatal: false))
            try check(store.webViewFailure?.isFatal == true && !store.canRunWebViewCommands,
                      "fatal cannot be cleared by later legacy warning")
        }
        print("PASS \(name) complete")
    }
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        Task { @MainActor in
            do {
                let fixture = URL(fileURLWithPath: CommandLine.arguments[1])
                let output = URL(fileURLWithPath: CommandLine.arguments[2])
                let before = try Data(contentsOf: fixture)
                for support: RhwpStudioCommandFailureSupport in [.unavailable, .version1] {
                    for format: DocumentSaveFormat in [.hwp, .hwpx] {
                        try await run(support: support, format: format, fixture: fixture, output: output)
                    }
                }
                try check(try Data(contentsOf: fixture) == before, "fixture bytes unchanged")
                print("PASS \(checks) command failure checks (synthetic producer; upstream recovery not verified)")
                app.stop(nil); exit(0)
            } catch { print("FAIL \(error)"); app.stop(nil); exit(1) }
        }
        app.run()
    }
}

@MainActor final class DocumentWindowPresenter {
    static let shared = DocumentWindowPresenter()
    func openDocument(_ url: URL) { fatalError("unexpected external document open") }
}
