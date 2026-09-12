import JavaScriptCore
import XCTest

@MainActor
final class RhwpStudioEditorSessionScriptTests: XCTestCase {
    private func makeContext(ready: Bool) throws -> JSContext {
        let context = try XCTUnwrap(JSContext())
        context.exceptionHandler = { _, error in XCTFail(error?.toString() ?? "JavaScript error") }
        context.evaluateScript("""
        var messages = [], timers = [], documentReads = 0;
        var state = {documentEpoch: 1, changeSeq: 0, dirty: false, pageCount: 1, format: "hwp"};
        var ready = \(ready), busy = false, replaceDuringRead = false;
        var document = {documentElement: {classList: {contains: () => busy}}};
        var window = {
          __alhangeulEditorLoad: {loadID: 3, token: "test-token"},
          rhwpStudio: {automation: {getContext: () => ({hasDocument: ready, isDirty: state.dirty, sourceFormat: state.format})}},
          addEventListener: () => {}
        };
        function setTimeout(fn) { timers.push(fn); return timers.length; }
        function setInterval(fn) { return 1; }
        function clearInterval() {}
        function postNative(message) { messages.push(message); }
        function requestRhwp(method) {
          if (method === "getDocumentState") {
            documentReads++;
            const result = {...state};
            if (replaceDuringRead) { state.documentEpoch++; replaceDuringRead = false; }
            return Promise.resolve(result);
          }
          if (method === "pageCount") return Promise.resolve(state.pageCount);
          return Promise.resolve({documentEpoch: state.documentEpoch, changeSeq: state.changeSeq});
        }
        \(RhwpStudioEditorSessionScript.source)
        """)
        return context
    }

    private func runCheck(_ context: JSContext) async {
        let done = expectation(description: "session check")
        let callback: @convention(block) () -> Void = { done.fulfill() }
        context.setObject(callback, forKeyedSubscript: "testDone" as NSString)
        context.evaluateScript("timers = []; sessionCheckTimer = null; refreshEditorSession().then(testDone);")
        await fulfillment(of: [done], timeout: 3)
    }

    func testHandshakeBeforeAndAfterEditorCreationAndNoDuplicateRegistration() async throws {
        for alreadyReady in [true, false] {
            let context = try makeContext(ready: alreadyReady)
            await runCheck(context)
            if !alreadyReady {
                XCTAssertEqual(context.evaluateScript("messages.length")?.toInt32(), 0)
                context.evaluateScript("ready = true")
                await runCheck(context)
            }
            await runCheck(context)
            XCTAssertEqual(context.evaluateScript("messages.length")?.toInt32(), 1)
            XCTAssertEqual(context.evaluateScript("messages[0].loadID")?.toInt32(), 3)
        }
    }

    func testActualDirtyStateAndNoFullDocumentExportForTypingOrSelection() async throws {
        let context = try makeContext(ready: true)
        await runCheck(context)
        // 복사·선택·취소 등 context가 바뀌지 않는 조회는 dirty로 만들지 않는다.
        await runCheck(context)
        XCTAssertEqual(context.evaluateScript("messages.length")?.toInt32(), 1)
        context.evaluateScript("state.dirty = true; state.changeSeq = 1;")
        await runCheck(context)
        XCTAssertTrue(context.evaluateScript("messages[1].dirty")?.toBool() == true)
        XCTAssertEqual(context.evaluateScript("documentReads")?.toInt32(), 1)
        context.evaluateScript("state.documentEpoch = 2; state.changeSeq = 0; state.dirty = false;")
        await runCheck(context)
        XCTAssertEqual(context.evaluateScript("documentReads")?.toInt32(), 2)
        XCTAssertEqual(context.evaluateScript("messages[2].documentEpoch")?.toInt32(), 2)
    }

    func testRenderingTransitionIsNotReportedAsReady() async throws {
        let context = try makeContext(ready: true)
        context.evaluateScript("busy = true")
        await runCheck(context)
        XCTAssertFalse(context.evaluateScript("messages[0].ready")?.toBool() == true)
        context.evaluateScript("busy = false")
        await runCheck(context)
        XCTAssertTrue(context.evaluateScript("messages[1].ready")?.toBool() == true)
        XCTAssertEqual(context.evaluateScript("documentReads")?.toInt32(), 1)
    }

    func testReplacementDuringAsyncSnapshotRejectsMixedStateAndRetries() async throws {
        let context = try makeContext(ready: true)
        context.evaluateScript("replaceDuringRead = true;")
        await runCheck(context)
        XCTAssertEqual(context.evaluateScript("messages.length")?.toInt32(), 0)
        await runCheck(context)
        XCTAssertEqual(context.evaluateScript("messages[0].documentEpoch")?.toInt32(), 2)
    }
    func testCreationObserverDistinguishesCreateLoadCancelAndFailure() throws {
        let context = try XCTUnwrap(JSContext())
        context.exceptionHandler = { _, error in XCTFail(error?.toString() ?? "JavaScript error") }
        context.evaluateScript("""
        var window = {}, registered = new Map();
        var wasm = {documentGeneration: 1, fail: false, noOp: false,
          createNewDocument() {
            if (this.fail) throw new Error('create failed');
            if (!this.noOp) this.documentGeneration++;
            return {pageCount:1};
          }};
        \(RhwpStudioEditorSessionScript.provenanceSource)
        window.rhwpStudio = {};
        window.rhwpStudio.automation = {
          registerCommand(def) {registered.set(def.id,def)},
          execute(id) {registered.get(id).execute({wasm});return {ok:true}},
          unregisterCommand(id) {registered.delete(id)}
        };
        var before = window.__alhangeulDocumentOrigin();
        wasm.createNewDocument();
        var created = window.__alhangeulDocumentOrigin();
        // 파일/복구 로드는 이름과 무관하게 documentGeneration을 증가시킨다.
        wasm.documentGeneration++;
        var loaded = window.__alhangeulDocumentOrigin();
        wasm.fail = true;try {wasm.createNewDocument()} catch {}
        var failed = window.__alhangeulDocumentOrigin();
        wasm.fail = false;wasm.noOp = true;wasm.createNewDocument();
        var cancelled = window.__alhangeulDocumentOrigin();
        wasm.noOp = false;wasm.createNewDocument();
        var second = window.__alhangeulDocumentOrigin();
        """)
        for name in ["before", "loaded", "failed", "cancelled"] {
            XCTAssertFalse(context.evaluateScript("\(name).createdByEditor")?.toBool() == true, name)
        }
        for name in ["created", "second"] {
            XCTAssertTrue(context.evaluateScript("\(name).createdByEditor")?.toBool() == true, name)
        }
        XCTAssertEqual(context.evaluateScript("registered.size")?.toInt32(), 0)
    }

}
