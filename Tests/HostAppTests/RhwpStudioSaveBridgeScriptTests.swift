import JavaScriptCore
import XCTest

@MainActor
final class RhwpStudioSaveBridgeScriptTests: XCTestCase {
    private func context() throws -> JSContext {
        let context = try XCTUnwrap(JSContext())
        context.exceptionHandler = { _, error in XCTFail(error?.toString() ?? "JavaScript error") }
        context.evaluateScript("""
        var window = {__alhangeulSaveLock:null}, document = {documentElement:{classList:{contains:()=>false}}};
        var state={documentEpoch:1,changeSeq:2,dirty:true,pageCount:1,format:'hwp',documentSha256:'hash-2'};
        var sessionLoad={loadID:1,token:'page-1'}, sessionReadVersion=0,sessionSnapshot=null,sessionSequence=0;
        var messages=[],notifyCalls=0,changeAfterExport=false;
        function postNative(message){messages.push(message)}
        function setTimeout(){return 1} function clearTimeout(){}
        function scheduleEditorSessionCheck(){} function rememberCurrentFileName(){}
        function showTemporaryStatusMessage(){} function fileNameForSaveFormat(){return 'new.hwp'}
        async function settleEditorState(){}
        async function requestRhwp(method){return {...state}}
        async function requestSaveExportPayload(){
          if(changeAfterExport){state.changeSeq++;state.documentSha256='changed'}
          return {base64:'AA==',byteCount:1};
        }
        async function documentPages(){return {pageCount:1,pages:['<svg/>']}}
        window.rhwpStudio={automation:{execute:async()=>({ok:true})},notifySaved:async()=>{
          notifyCalls++;state.dirty=false;return {ok:true};
        }};
        \(RhwpStudioSaveBridgeScript.source)
        """)
        return context
    }

    private func run(_ script: String, in context: JSContext) async {
        let done = expectation(description:"save bridge")
        let callback: @convention(block) () -> Void = { done.fulfill() }
        context.setObject(callback, forKeyedSubscript:"testDone" as NSString)
        context.evaluateScript("(async()=>{\(script)})().then(testDone,e=>{testError=String(e);testDone()});")
        await fulfillment(of:[done],timeout:3)
        XCTAssertTrue(context.evaluateScript("typeof testError === 'undefined'")?.toBool() == true)
    }

    func testSaveIsRequestBoundAndCleanOnlyAfterFinish() async throws {
        let context=try context()
        await run("""
        result=await window.__alhangeulHostBridgeSave.begin('save-1','page-1',1,'hwp');
        dirtyAfterExport=state.dirty;
        blocked=await window.rhwpStudio.automation.execute('file:new-doc');
        await window.__alhangeulHostBridgeSave.finish('save-1','new.hwp','10:00');
        window.__alhangeulHostBridgeSave.release('old-request');
        oldReleaseKeptLock=!!window.__alhangeulSaveLock;
        window.__alhangeulHostBridgeSave.release('save-1');
        """,in:context)
        XCTAssertTrue(context.evaluateScript("dirtyAfterExport && blocked.ok===false && oldReleaseKeptLock && !window.__alhangeulSaveLock")?.toBool() == true)
        XCTAssertTrue(context.evaluateScript("result.requestID==='save-1' && result.token==='page-1' && !state.dirty && notifyCalls===1")?.toBool() == true)
    }

    func testChangedDocumentCannotBeExportedOrMarkedClean() async throws {
        let context=try context()
        await run("""
        changeAfterExport=true;
        rejected=false;
        try {await window.__alhangeulHostBridgeSave.begin('save-1','page-1',1,'hwp')}catch {rejected=true}
        """,in:context)
        XCTAssertTrue(context.evaluateScript("rejected && state.dirty && notifyCalls===0 && !window.__alhangeulSaveLock")?.toBool() == true)
    }

    func testWrongEpochAndStaleCompletionAreRejected() async throws {
        let context=try context()
        await run("""
        wrongEpoch=false;staleFinish=false;
        try {await window.__alhangeulHostBridgeSave.begin('save-1','page-1',2,'hwp')}catch {wrongEpoch=true}
        await window.__alhangeulHostBridgeSave.begin('save-2','page-1',1,'hwp');
        try {await window.__alhangeulHostBridgeSave.finish('save-1','bad.hwp','10:00')}catch {staleFinish=true}
        window.__alhangeulHostBridgeSave.release('save-2');
        """,in:context)
        XCTAssertTrue(context.evaluateScript("wrongEpoch && staleFinish && notifyCalls===0 && state.dirty")?.toBool() == true)
    }

    func testPDFSnapshotDoesNotMarkDocumentClean() async throws {
        let context=try context()
        await run("""
        result=await window.__alhangeulHostBridgeSave.begin('pdf-1','page-1',1,'pdf');
        window.__alhangeulHostBridgeSave.release('pdf-1');
        """,in:context)
        XCTAssertTrue(context.evaluateScript("result.pages.length===1 && state.dirty && notifyCalls===0 && !window.__alhangeulSaveLock")?.toBool() == true)
    }

    func testOlderForegroundReadCannotOverwriteSavedState() async throws {
        let context = try context()
        await run("""
        const originalRequest = requestRhwp;
        let releaseOldFence;
        let oldFenceStarted;
        const waiting = new Promise(resolve => { oldFenceStarted = resolve });
        requestRhwp = async method => {
          if (method === 'getSelectionContext' && !releaseOldFence) {
            return await new Promise(resolve => {
              releaseOldFence = resolve;
              oldFenceStarted();
            });
          }
          return await originalRequest(method);
        };
        let oldRejected = false;
        const oldRead = window.__alhangeulHostBridgeReadSession().catch(() => {oldRejected = true});
        await waiting;
        state.dirty = false;
        await window.__alhangeulHostBridgeReadSession();
        releaseOldFence({...state});
        await oldRead;
        foregroundRaceSafe = oldRejected && messages.length === 1 && messages[0].dirty === false;
        """, in:context)
        XCTAssertTrue(context.evaluateScript("foregroundRaceSafe")?.toBool() == true)
    }
}
