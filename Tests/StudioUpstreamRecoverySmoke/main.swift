import AppKit
import SwiftUI
import WebKit

/// 공개 확장 명령으로 실제 upstream snapshot 실패를 주입하고 WK transport를 검증한다.
@main struct StudioUpstreamRecoverySmoke {
    struct Failure: Error, CustomStringConvertible { let description: String }
    @MainActor static var checks = 0
    @MainActor static func check(_ value: Bool, _ name: String) throws {
        guard value else { throw Failure(description: name) }
        checks += 1; print("PASS \(name)")
    }
    @MainActor static func wait(_ name: String, timeout: TimeInterval = 20, _ predicate: () async -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !(await predicate()) {
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
    @MainActor static func emit(_ web: WKWebView, id: Int, recovery: String = "restored") async throws {
        _ = try await js(web, """
        if (!window.rhwpCommandErrors) throw Error('actual producer missing');
        if (window.__lastRecoveryID === id) {
          window.dispatchEvent(new CustomEvent('rhwp-command-error', {detail:window.__lastRecoveryPayload}));
          return;
        }
        window.__lastRecoveryID = id;
        const automation = window.rhwpStudio.automation;
        const command = 'ext:alhangeul-recovery-smoke';
        automation.registerCommand({id:command, label:'failure injection', execute(services) {
          const handler = services.getInputHandler();
          try {
            handler.executeOperation({kind:'snapshot', operationType:'recovery-smoke', operation(wasm) {
              const p = handler.cursor.getPosition();
              wasm.insertText(p.sectionIndex, p.paragraphIndex, p.charOffset, 'TEMP');
              throw recovery === 'restored' ? Error('injected failure') : new WebAssembly.RuntimeError('injected trap');
            }});
          } catch (error) {
            window.__recoveryReport = error.report.then(payload => {window.__lastRecoveryPayload = payload; return payload;});
            if (id === 2) Promise.reject(error); else setTimeout(() => {throw error;}, 0);
          }
        }});
        await automation.execute(command);
        automation.unregisterCommand(command);
        const result = await window.__recoveryReport;
        if (result.recovery !== (recovery === 'restored' ? 'succeeded' : 'unknown')) throw Error(JSON.stringify(result));
        """, ["id": id, "recovery": recovery])
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
        let supported = support == .upstreamVersion1
        let name = "\(supported ? "actual-v1" : "production-default")-\(format.rawValue)"
        let store = DocumentViewerStore()
        let window = NSWindow(contentRect: .init(x: 100, y: 100, width: 940, height: 700),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.title = "명령 오류 계약 검증 \(name)"
        window.contentView = NSHostingView(rootView: DocumentViewerView(store: store, commandFailureSupport: support))
        window.makeKeyAndOrderFront(nil)
        defer { window.orderOut(nil) }
        store.loadDocument(from: fixture)
        let initializationStart = Date()
        do {
            // navigation 완료와 WASM/편집기 준비는 다른 경계다. 복구 timeout은 제품의 12초 그대로다.
            try await wait("fixture ready", timeout: 60) {
                if store.webViewFailure != nil || (store.hasDocument && !store.isWebViewLoading && !store.isLoading) { return true }
                // 공식 Studio가 글꼴 선택을 요청하면 이 복구 검사에서는 대체 글꼴로 문서를 연다.
                if let current = web(in: window.contentView!), !current.isLoading {
                    let selected = try? await js(current, """
                    const button = Array.from(document.querySelectorAll('.modal-overlay .dialog-footer button'))
                      .find(b => b.offsetWidth > 0 && ['대체 글꼴로 보기', 'View with substitute fonts'].includes(b.textContent.trim()));
                    if (!button) return false;
                    button.click(); return true;
                    """)
                    if selected as? Bool == true { print("FONT_CHOICE substitute") }
                }
                return false
            }
        } catch {
            print("FIXTURE_STATE loading=\(store.isLoading) webLoading=\(store.isWebViewLoading) session=\(String(describing:store.editorSession)) failure=\(String(describing:store.webViewFailure))")
            if let current = web(in:window.contentView!) {
                let detail = try? await js(current, "return {fontTrace:window.__fontTrace, resources:performance.getEntriesByType('resource').map(r=>({name:r.name,duration:r.duration})), ready:document.readyState, studio:!!window.rhwpStudio, state:window.rhwpCommandErrors?.getState(), bridge:typeof window.__alhangeulHostBridgeReadSession, status:document.querySelector('#sb-message')?.textContent, body:document.body.innerText.slice(-1200)};")
                print("FIXTURE_JS \(String(describing:detail))")
            }
            throw error
        }
        print("INITIALIZATION_SECONDS \(Date().timeIntervalSince(initializationStart))")
        try check(store.webViewFailure == nil, "fixture failure: \(String(describing: store.webViewFailure))")
        let original = web(in: window.contentView!)!
        print("FONT_TRACE \(String(describing: try await js(original, "return window.__fontTrace || [];")))")
        if try await js(original, "return window.__fontStallInjected === true;") as? Bool == true {
            let bounded = try await js(original, """
            const stalled = window.__fontTrace.filter(row => row.kind === 'fetch' || row.status === 'injected-pending');
            const css = document.getElementById('rhwp-web-font-faces')?.textContent || '';
            return stalled.length > 0 && stalled.every(row => row.kind === 'fetch'
              ? row.status === 'aborted' && !css.includes(row.url) : !css.includes(row.family));
            """) as? Bool
            try check(bounded == true, "stalled CDN fonts removed from CSS before editor readiness")
            try check(Date().timeIntervalSince(initializationStart) < 15, "stalled fonts do not block initialization beyond deadline")
        }
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
        _ = try await js(original, """
        const a = window.rhwpStudio.automation, id = 'ext:alhangeul-delayed-recovery';
        a.registerCommand({id, label:'delay injection', execute(services) {
          const h = services.getInputHandler(), options = h.commandErrors.options;
          const refresh = options.refresh;
          options.refresh = () => new Promise(resolve => {
            window.__releaseRecovery = async () => { options.refresh = refresh; await refresh(); resolve(); };
          });
          try { h.executeOperation({kind:'snapshot', operationType:'delay-smoke', operation(){throw Error('delayed failure');}}); }
          catch(error) { window.__delayedReport = error.report; setTimeout(() => {throw error;},0); }
        }});
        await a.execute(id); a.unregisterCommand(id);
        """)
        try await Task.sleep(nanoseconds: 400_000_000)
        let blocked = try await js(original, """
        try { await window.__alhangeulHostBridgeReadSession(); return false; } catch { return true; }
        """) as? Bool
        try check(blocked == true, "recovering refuses output session")
        let blockedDestination = output.appendingPathComponent("blocked-\(format.rawValue).hwp")
        coordinator.chooseSaveDestination = { _, _, _ in blockedDestination }
        _ = RhwpStudioNativeCommandDispatcher.run("file:save-as-hwp", in:window)
        try await Task.sleep(nanoseconds: 200_000_000)
        try check(!FileManager.default.fileExists(atPath:blockedDestination.path), "recovering does not publish save")
        _ = try await js(original, "await window.__releaseRecovery(); return await window.__delayedReport;")
        try await wait("delayed notice") { store.commandFailurePresentation.failure?.operation == "delay-smoke" }
        try check(store.webViewFailure == nil && web(in:window.contentView!) === original,
                  "delayed recovery keeps live WebView")
        // 다른 문서의 실제 이전 보고를 이벤트로 다시 보내도 현재 문서를 중단하지 않는다.
        _ = try await js(original, """
        const old = window.__lastRecoveryPayload;
        await window.rhwpStudio.automation.execute('file:new-doc');
        window.dispatchEvent(new CustomEvent('rhwp-command-error', {detail:old}));
        """)
        try await Task.sleep(nanoseconds: 1300_000_000)
        try check(store.webViewFailure == nil && web(in:window.contentView!) === original, "late old report ignored after document replacement")
        if supported {
            // 실제 snapshot 복원 뒤 trap을 unknown으로 보고하는 경로다.
            if format == .hwpx {
                // 실제 WK bridge가 ready=false metadata를 먼저 전달하게 한 뒤 실제 복구 보고를 보낸다.
                _ = try await js(original, "document.documentElement.classList.add('rhwp-busy'); return true;")
                try await emit(original, id: 3)
            } else {
                try await emit(original, id: 3, recovery: "failed")
            }
            try await wait("fatal") { store.webViewFailure != nil }
            if format == .hwpx {
                try check(String(describing: store.webViewFailure).contains("COMMAND_REPORT_NOT_READY"),
                          "unready native report reaches fatal protection through WK transport")
            }
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
                for support: RhwpStudioCommandFailureSupport in [.upstreamVersion1] {
                    for format: DocumentSaveFormat in [.hwp, .hwpx] {
                        try await run(support: support, format: format, fixture: fixture, output: output)
                    }
                }
                try check(try Data(contentsOf: fixture) == before, "fixture bytes unchanged")
                print("PASS \(checks) command failure checks (actual upstream producer / injected operation failure)")
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
