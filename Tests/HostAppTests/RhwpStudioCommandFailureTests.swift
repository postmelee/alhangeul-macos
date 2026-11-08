import Foundation
import JavaScriptCore
import XCTest

final class RhwpStudioCommandFailureTests: XCTestCase {
    private let source = RhwpStudioCommandFailureSource(mainFrame: true, sameWebView: true,
        scheme: "alhangeul-studio", host: "app", port: 0,
        frameURL: URL(string: "alhangeul-studio://app/index.html?profile=embed"))

    private func body(_ id: Int = 1, recovery: String = "restored", changeSeq: Int = 4) -> [String: Any] {
        ["contractVersion": 1, "eventID": "event-\(id)", "eventSequence": id,
         "code": "DELETE_REJECTED", "operation": "deleteSelection", "loadToken": "load-token",
         "loadID": 2, "documentEpoch": 3, "changeSeq": changeSeq, "recovery": recovery,
         "checks": ["content": true, "cursorSelection": true, "history": true,
                    "dirtyState": true, "readyForNextCommand": true]]
    }

    private func session(sequence: Int = 1, epoch: Int = 3, changeSeq: Int = 4, ready: Bool = true) -> RhwpStudioEditorSnapshot {
        .init(loadID: 2, sequence: sequence, documentEpoch: epoch, changeSeq: changeSeq,
              dirty: true, ready: ready, pageCount: 2, format: "hwpx")
    }

    private func state(_ support: RhwpStudioCommandFailureSupport = .version1) -> RhwpStudioCommandFailureState {
        var value = RhwpStudioCommandFailureState(support: support)
        value.beginLoad(token: "load-token", loadID: 2)
        value.updateSession(session())
        return value
    }

    private func isFatal(_ value: RhwpStudioCommandFailureState.Decision) -> Bool {
        if case .fatal = value { return true }; return false
    }

    func testActualUpstreamContractAndSessionBinding() throws {
        var payload: [String: Any] = ["schemaVersion":1, "capability":"command-error-v1",
            "eventId":"opaque-event", "documentSessionId":"opaque-session", "operation":"deleteSelection",
            "code":"COMMAND_ROLLED_BACK", "recovery":"succeeded",
            "checks":["content":true,"editing":true,"history":true,"dirty":true,"ready":true]]
        let parsed = try XCTUnwrap(RhwpStudioCommandFailure.parseUpstream(payload))
        XCTAssertTrue(parsed.isRecovered)
        XCTAssertFalse(parsed.diagnostic.contains("changeSeq="))
        var value = state(.upstreamVersion1)
        XCTAssertFalse(value.usesStructuredContract) // old bundle keeps legacy policy
        var envelope: [String: Any] = ["type":"command-recovery-state", "loadToken":"load-token",
            "loadID":2, "documentEpoch":3, "documentSessionId":"opaque-session", "status":"recovering"]
        XCTAssertEqual(value.receiveUpstream(envelope, source:source), .ignored)
        XCTAssertTrue(value.blocksCommands)
        envelope["type"] = "upstream-command-failure"; envelope["payload"] = payload
        XCTAssertEqual(value.receiveUpstream(envelope, source:source), .recovered(parsed))
        XCTAssertFalse(value.blocksCommands)
        XCTAssertEqual(value.receiveUpstream(envelope, source:source), .ignored)
        var stale = envelope; stale["documentSessionId"] = "old"
        XCTAssertEqual(value.receiveUpstream(stale, source:source), .ignored)
        payload["code"] = "ROLLBACK_FAILED"; payload["recovery"] = "failed"
        payload["eventId"] = "different"
        envelope["payload"] = payload
        XCTAssertTrue(isFatal(value.receiveUpstream(envelope, source:source)))
        XCTAssertTrue(value.isSuspended)
        payload["recovery"] = "succeeded"
        XCTAssertNil(RhwpStudioCommandFailure.parseUpstream(payload))
    }

    func testFatalReportRetainsOperationEventAndChecksUntilNewLoad() {
        var value = state()
        XCTAssertTrue(isFatal(value.receive(body(recovery: "failed"), source: source)))
        XCTAssertTrue(value.fatalDiagnostic?.contains("operation=deleteSelection") == true)
        XCTAssertTrue(value.fatalDiagnostic?.contains("event=event-1") == true)
        XCTAssertTrue(value.fatalDiagnostic?.contains("recovery=failed") == true)
        XCTAssertTrue(value.fatalDiagnostic?.contains("checks.history=true") == true)
        value.beginLoad(token: "new", loadID: 3)
        XCTAssertNil(value.fatalDiagnostic)
    }

    func testProductionDefaultCannotBeEnabledByPageCapabilityOrRecoveredBoolean() {
        var value = state(.unavailable)
        var message = body()
        message["capability"] = "command-failure-v1"
        message["recovered"] = true
        XCTAssertEqual(value.receive(message, source: source), .ignored)
        XCTAssertFalse(value.isSuspended)
    }

    func testJavaScriptPayloadPreservesStrictBooleanAndIntegerTypes() throws {
        let context = try XCTUnwrap(JSContext())
        let json = String(data: try JSONSerialization.data(withJSONObject: body()), encoding: .utf8)!
        context.setObject(json, forKeyedSubscript: "payload" as NSString)
        let valid = try XCTUnwrap(context.evaluateScript("JSON.parse(payload)")?.toDictionary() as? [String: Any])
        XCTAssertNotNil(RhwpStudioCommandFailure.parse(valid))
        for edit in ["p.contractVersion = true", "p.eventSequence = false", "p.checks.history = 1"] {
            let invalid = try XCTUnwrap(context.evaluateScript("(() => {const p = JSON.parse(payload); \(edit); return p;})()")?.toDictionary() as? [String: Any])
            XCTAssertNil(RhwpStudioCommandFailure.parse(invalid))
        }
        XCTAssertNil(context.exception)
    }

    func testRecoveredAndUnchangedRequireEveryBooleanCheck() throws {
        for recovery in ["restored", "unchanged"] {
            var value = state()
            let event = try XCTUnwrap(RhwpStudioCommandFailure.parse(body(recovery: recovery)))
            XCTAssertEqual(value.receive(body(recovery: recovery), source: source), .recovered(event))
            XCTAssertFalse(value.isSuspended)
        }
        for key in ["content", "cursorSelection", "history", "dirtyState", "readyForNextCommand"] {
            for replacement: Any? in [nil, false, 1, "true"] {
                var value = state(); var message = body()
                var checks = message["checks"] as! [String: Any]; checks[key] = replacement
                message["checks"] = checks
                XCTAssertTrue(isFatal(value.receive(message, source: source)), "\(key): \(String(describing: replacement))")
                XCTAssertTrue(value.isSuspended)
            }
        }
    }

    func testMalformedCurrentContractSuspendsWithoutRawDiagnostics() {
        let changes: [(String, Any?)] = [
            ("contractVersion", 2), ("contractVersion", true), ("eventSequence", 1.5),
            ("eventSequence", true), ("eventSequence", 0), ("eventSequence", -1),
            ("eventSequence", 9_007_199_254_740_992 as UInt64), ("eventSequence", "1"),
            ("code", ""), ("code", "document /private/source.hwp"),
            ("eventID", String(repeating: "a", count: 129)), ("code", String(repeating: "가", count: 43)),
            ("operation", "delete\nsecret"), ("checks", nil), ("recovery", "success"),
            ("changeSeq", Double.infinity), ("diagnostic", String(repeating: "x", count: 2049))
        ]
        for (key, replacement) in changes {
            var value = state(); var message = body(); message[key] = replacement
            XCTAssertEqual(value.receive(message, source: source), .fatal("INVALID_COMMAND_FAILURE"), key)
        }
        var message = body(); message["diagnostic"] = "private source text"
        XCTAssertFalse(RhwpStudioCommandFailure.parse(message)!.diagnostic.contains("private source"))
    }

    func testUntrustedFramesAndOldIdentitiesCannotSuspendCurrentDocument() {
        let sources = [
            RhwpStudioCommandFailureSource(mainFrame: false, sameWebView: true, scheme: source.scheme,
                host: source.host, port: 0, frameURL: source.frameURL),
            RhwpStudioCommandFailureSource(mainFrame: true, sameWebView: false, scheme: source.scheme,
                host: source.host, port: 0, frameURL: source.frameURL),
            RhwpStudioCommandFailureSource(mainFrame: true, sameWebView: true, scheme: "https",
                host: "app", port: 0, frameURL: source.frameURL),
            RhwpStudioCommandFailureSource(mainFrame: true, sameWebView: true, scheme: source.scheme,
                host: "other", port: 0, frameURL: source.frameURL),
            RhwpStudioCommandFailureSource(mainFrame: true, sameWebView: true, scheme: source.scheme,
                host: source.host, port: 443, frameURL: source.frameURL),
            RhwpStudioCommandFailureSource(mainFrame: true, sameWebView: true, scheme: source.scheme,
                host: source.host, port: 0, frameURL: URL(string: "alhangeul-studio://app/other.html")),
            RhwpStudioCommandFailureSource(mainFrame: true, sameWebView: true, scheme: source.scheme,
                host: source.host, port: 0, frameURL: URL(string: "alhangeul-studio://user@app/index.html"))
        ]
        for source in sources {
            var value = state()
            XCTAssertEqual(value.receive(body(recovery: "failed"), source: source), .ignored)
            XCTAssertFalse(value.isSuspended)
        }
        for (key, replacement): (String, Any) in [("loadToken", "old"), ("loadID", 1),
                ("documentEpoch", 2), ("documentEpoch", true)] {
            var value = state(); var message = body(recovery: "failed"); message[key] = replacement
            XCTAssertEqual(value.receive(message, source: source), .ignored)
            XCTAssertFalse(value.isSuspended)
        }
        var loading = RhwpStudioCommandFailureState(support: .version1)
        loading.beginLoad(token: "load-token", loadID: 2)
        XCTAssertEqual(loading.receive(body(), source: source), .ignored)
        loading.updateSession(session(ready: false))
        XCTAssertEqual(loading.receive(body(), source: source), .ignored)
    }

    func testDuplicateConflictAndOutOfOrderEvents() {
        var value = state()
        _ = value.receive(body(2), source: source)
        XCTAssertEqual(value.receive(body(2), source: source), .ignored)
        XCTAssertEqual(value.receive(body(1), source: source), .ignored)
        var conflict = body(2); conflict["operation"] = "other"
        XCTAssertEqual(value.receive(conflict, source: source), .fatal("CONFLICTING_COMMAND_FAILURE"))
    }

    func testFatalLatchSurvivesSuccessSessionAndEpochUntilExplicitNewLoad() {
        var value = state()
        XCTAssertEqual(value.receive(body(10, recovery: "failed"), source: source), .fatal("DELETE_REJECTED"))
        XCTAssertEqual(value.receive(body(11), source: source), .ignored)
        value.updateSession(session(sequence: 2, epoch: 4))
        var newer = body(12); newer["documentEpoch"] = 4
        XCTAssertEqual(value.receive(newer, source: source), .ignored)
        XCTAssertTrue(value.isSuspended)
        value.beginLoad(token: "load-token", loadID: 2)
        value.updateSession(session(sequence: 3, epoch: 4))
        XCTAssertFalse(value.isSuspended)
        XCTAssertNotEqual(value.receive(newer, source: source), .ignored)
    }

    func testOlderRevisionSuccessIgnoredButIntegrityFailureNotHidden() {
        var value = state()
        XCTAssertEqual(value.receive(body(changeSeq: 2), source: source), .ignored)
        XCTAssertEqual(value.receive(body(2, recovery: "unknown", changeSeq: 1), source: source), .fatal("DELETE_REJECTED"))
        var sequence = state(); _ = sequence.receive(body(9), source: source)
        XCTAssertTrue(isFatal(sequence.receive(body(1, recovery: "failed"), source: source)))
    }

    func testBoundedDeduplicationAndDocumentEpochReset() {
        var value = state()
        for id in 1...100 { _ = value.receive(body(id), source: source) }
        XCTAssertEqual(value.retainedEventCount, 64)
        XCTAssertEqual(value.receive(body(1), source: source), .ignored)
        value.updateSession(session(sequence: 2, epoch: 4))
        XCTAssertEqual(value.retainedEventCount, 0)
        var message = body(); message["documentEpoch"] = 4
        XCTAssertNotEqual(value.receive(message, source: source), .ignored)
        value.updateSession(session(sequence: 3, epoch: 3)) // 이전 문서가 새 세대를 되돌리지 못한다.
        XCTAssertEqual(value.receive(body(recovery: "failed"), source: source), .ignored)
    }

    func testPresentationKeepsLastDiagnosticAndCoalescesOnlySameOperation() throws {
        var value = RhwpStudioCommandFailurePresentation()
        let first = try XCTUnwrap(RhwpStudioCommandFailure.parse(body()))
        value.present(first); value.dismiss()
        XCTAssertFalse(value.isVisible); XCTAssertEqual(value.failure, first)
        value.show(); XCTAssertTrue(value.isVisible)
        for id in 2...120 { value.present(try XCTUnwrap(RhwpStudioCommandFailure.parse(body(id)))) }
        XCTAssertEqual(value.occurrenceCount, 99)
        var other = body(121); other["operation"] = "undo"
        value.present(try XCTUnwrap(RhwpStudioCommandFailure.parse(other)))
        XCTAssertEqual(value.occurrenceCount, 1)
        value.clear(); XCTAssertNil(value.failure); XCTAssertFalse(value.isVisible)
    }
}
