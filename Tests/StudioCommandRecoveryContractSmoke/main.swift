import Foundation
import JavaScriptCore

@main struct RecoveryContractSmoke {
    static func main() throws {
        var count = 0
        func check(_ condition: Bool, _ name: String) {
            precondition(condition, name); count += 1; print("PASS \(name)")
        }
        let source = RhwpStudioCommandFailureSource(mainFrame:true, sameWebView:true,
            scheme:"alhangeul-studio", host:"app", port:0, frameURL:URL(string:"alhangeul-studio://app/index.html"))
        var payload: [String:Any] = ["schemaVersion":1,"capability":"command-error-v1", "eventId":"e",
            "documentSessionId":"s","operation":"deleteSelection", "code":"COMMAND_ROLLED_BACK", "recovery":"succeeded",
            "checks":["content":true,"editing":true,"history":true,"dirty":true,"ready":true]]
        let failure = RhwpStudioCommandFailure.parseUpstream(payload)!
        check(failure.isRecovered, "real success decoded")
        check(!failure.diagnostic.contains("changeSeq="), "no fabricated producer revision")
        for key in ["content","editing","history","dirty","ready"] {
            for bad: Any in [false, 1, "true"] {
                var p = payload; var fields = p["checks"] as! [String:Any]; fields[key] = bad; p["checks"] = fields
                check(RhwpStudioCommandFailure.parseUpstream(p) == nil, "reject \(key) \(bad)")
            }
        }
        var state = RhwpStudioCommandFailureState(support:.upstreamVersion1)
        state.beginLoad(token:"t",loadID:1)
        state.updateSession(.init(loadID:1,sequence:1,documentEpoch:1,changeSeq:7,dirty:true,ready:true,pageCount:1,format:"hwp"))
        check(!state.usesStructuredContract, "legacy until actual binding")
        var envelope: [String:Any] = ["type":"command-recovery-state","loadToken":"t","loadID":1,
            "documentEpoch":1,"documentSessionId":"s","status":"recovering"]
        _ = state.receiveUpstream(envelope,source:source)
        check(state.blocksCommands, "pending blocks outputs")
        envelope["type"] = "upstream-command-failure"; envelope["payload"] = payload
        check(state.receiveUpstream(envelope,source:source) == .recovered(failure), "actual report unblocks")
        check(!state.blocksCommands, "ready after verified recovery")
        check(state.receiveUpstream(envelope,source:source) == .ignored, "duplicate ignored")
        var old = envelope; old["documentSessionId"] = "old"
        check(state.receiveUpstream(old,source:source) == .ignored, "old session ignored")
        state.updateSession(.init(loadID:1,sequence:2,documentEpoch:2,changeSeq:0,dirty:false,ready:true,pageCount:1,format:"hwp"))
        check(state.receiveUpstream(envelope,source:source) == .ignored, "old epoch ignored")
        envelope["documentEpoch"] = 2; envelope["type"] = "command-recovery-state"
        _ = state.receiveUpstream(envelope,source:source)
        payload["code"] = "INTEGRITY_UNKNOWN"; payload["recovery"] = "unknown"
        envelope["type"] = "upstream-command-failure"; envelope["payload"] = payload
        if case .fatal = state.receiveUpstream(envelope,source:source) { check(true,"unknown latches fatal") }
        else { check(false,"unknown must latch") }
        check(state.isSuspended,"fatal persists")
        var unready = RhwpStudioCommandFailureState(support:.upstreamVersion1)
        unready.beginLoad(token:"t",loadID:1)
        unready.updateSession(.init(loadID:1,sequence:1,documentEpoch:2,changeSeq:0,dirty:false,ready:false,pageCount:1,format:"hwp"))
        envelope["type"] = "command-recovery-state"
        _ = unready.receiveUpstream(envelope,source:source)
        envelope["type"] = "upstream-command-failure"
        check(unready.receiveUpstream(envelope,source:source) == .fatal("COMMAND_REPORT_NOT_READY"),
              "unready native binding cannot leave pending forever")
        let context = JSContext()!
        context.evaluateScript("function setInterval(){return 1;} var window = {addEventListener(){}}; var sessionLoad = {token:'t',loadID:1};")
        context.evaluateScript(RhwpStudioCommandRecoveryScript.source)
        check(context.exception == nil,"adapter JavaScript parses and installs")
        context.evaluateScript("window.__alhangeulAssertRecoveryReady()")
        check(context.exception == nil,"unsupported bundle remains usable")
        context.evaluateScript("""
        var posted = [], timeoutCallback, timerCount = 0;
        function postNative(value) { posted.push(value); }
        function setTimeout(callback, ms) { timeoutCallback = callback; timerCount++; return timerCount; }
        function clearTimeout() {}
        var currentState = {documentSessionId:'session',status:'ready'};
        window.__alhangeulEditorLoad = {commandRecovery:true};
        class OwnedError extends Error {}
        window.rhwpCommandErrors = {capability:'command-error-v1', getState:()=>currentState,
          isHandledError:e=>e instanceof OwnedError, inspect:()=> 'accept'};
        var owned = new OwnedError('owned'); owned.report = new Promise(()=>{});
        window.__alhangeulHandleCommandError(owned);
        window.__alhangeulHandleCommandError(owned);
        """)
        check(context.exception == nil, "owned error timeout setup")
        check(context.evaluateScript("timerCount === 1")!.toBool(), "repeat error cannot extend deadline")
        context.evaluateScript("timeoutCallback()")
        check(context.evaluateScript("posted.length === 1 && posted[0].reason === 'COMMAND_REPORT_TIMEOUT'")!.toBool(),
              "missing report fails closed even when engine already ready")
        context.evaluateScript("posted = []; currentState = {documentSessionId:'new',status:'ready'}; timeoutCallback()")
        check(context.evaluateScript("posted.length === 0")!.toBool(), "old timeout cannot suspend new document")
        print("PASS \(count) contract checks")
    }
}
