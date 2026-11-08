import CoreFoundation
import Foundation

/// 합성 내부 계약과 실제 upstream 공개 계약을 분리한다. 구버전 번들은 capability 부재로 미지원이다.
enum RhwpStudioCommandFailureSupport {
    case unavailable
    case version1
    case upstreamVersion1
}

struct RhwpStudioCommandFailureSource {
    let mainFrame: Bool
    let sameWebView: Bool
    let scheme: String
    let host: String
    let port: Int
    let frameURL: URL?

    var isTrusted: Bool {
        mainFrame && sameWebView && scheme == "alhangeul-studio" && host == "app" && port == 0
            && frameURL?.scheme == scheme && frameURL?.host == host && frameURL?.port == nil
            && frameURL?.user == nil && frameURL?.password == nil && frameURL?.path == "/index.html"
    }
}

struct RhwpStudioCommandFailure: Equatable {
    enum Recovery: String { case restored, unchanged, failed, unknown }
    struct Checks: Equatable {
        let content, cursorSelection, history, dirtyState, readyForNextCommand: Bool
        var allPassed: Bool { content && cursorSelection && history && dirtyState && readyForNextCommand }
    }

    var documentSessionID: String? = nil
    let eventID: String
    let eventSequence: Int
    let code: String
    let operation: String
    let changeSeq: Int
    let recovery: Recovery
    let checks: Checks

    var isRecovered: Bool {
        (recovery == .restored || recovery == .unchanged) && checks.allPassed
    }

    /// 외부 stack/message/diagnostic은 보관하지 않는다. 진단에는 검증한 식별자만 사용한다.
    var diagnostic: String {
        if let documentSessionID {
            return "capability=command-error-v1\ndocumentSession=\(documentSessionID)\ncode=\(code)\noperation=\(operation)\nrecovery=\(recovery.rawValue)\nevent=\(eventID)\nchecks=\(checks)"
        }
        return "contractVersion=1\ncode=\(code)\noperation=\(operation)\nrecovery=\(recovery.rawValue)\nevent=\(eventID)\nsequence=\(eventSequence)\nchangeSeq=\(changeSeq)\nchecks.content=\(checks.content)\nchecks.cursorSelection=\(checks.cursorSelection)\nchecks.history=\(checks.history)\nchecks.dirtyState=\(checks.dirtyState)\nchecks.readyForNextCommand=\(checks.readyForNextCommand)"
    }

    static func parse(_ body: [String: Any]) -> Self? {
        guard integer(body["contractVersion"]) == 1,
              let eventID = identifier(body["eventID"]),
              let sequence = integer(body["eventSequence"]), sequence > 0,
              let code = identifier(body["code"]), let operation = identifier(body["operation"]),
              let changeSeq = integer(body["changeSeq"]),
              let raw = body["recovery"] as? String, let recovery = Recovery(rawValue: raw),
              let checks = body["checks"] as? [String: Any],
              let content = boolean(checks["content"]),
              let cursor = boolean(checks["cursorSelection"]),
              let history = boolean(checks["history"]),
              let dirty = boolean(checks["dirtyState"]),
              let ready = boolean(checks["readyForNextCommand"])
        else { return nil }
        if let diagnostic = body["diagnostic"] {
            guard let text = diagnostic as? String, text.utf8.count <= 2048 else { return nil }
        }
        return Self(eventID: eventID, eventSequence: sequence, code: code, operation: operation,
                    changeSeq: changeSeq, recovery: recovery,
                    checks: .init(content: content, cursorSelection: cursor, history: history,
                                  dirtyState: dirty, readyForNextCommand: ready))
    }

    /// 실제 공개 계약. ID의 내부 형식을 해석하거나 revision을 만들어 넣지 않는다.
    static func parseUpstream(_ body: [String: Any]) -> Self? {
        guard integer(body["schemaVersion"]) == 1,
              body["capability"] as? String == "command-error-v1",
              let event = identifier(body["eventId"]),
              let session = identifier(body["documentSessionId"]),
              let operation = identifier(body["operation"]),
              let code = body["code"] as? String,
              let result = body["recovery"] as? String,
              let checks = body["checks"] as? [String: Any],
              let content = boolean(checks["content"]), let editing = boolean(checks["editing"]),
              let history = boolean(checks["history"]), let dirty = boolean(checks["dirty"]),
              let ready = boolean(checks["ready"]) else { return nil }
        let recovery: Recovery
        switch (code, result) {
        case ("COMMAND_REJECTED", "succeeded"): recovery = .unchanged
        case ("COMMAND_ROLLED_BACK", "succeeded"): recovery = .restored
        case ("ROLLBACK_FAILED", "failed"): recovery = .failed
        case ("INTEGRITY_UNKNOWN", "unknown"): recovery = .unknown
        default: return nil
        }
        if result == "succeeded" && !(content && editing && history && dirty && ready) { return nil }
        // 0은 legacy 전용 저장 필드의 미사용 값이며 upstream 순서/revision으로 소비하지 않는다.
        return Self(documentSessionID: session, eventID: event, eventSequence: 0,
                    code: code, operation: operation, changeSeq: 0, recovery: recovery,
                    checks: .init(content: content, cursorSelection: editing, history: history,
                                  dirtyState: dirty, readyForNextCommand: ready))
    }

    static func integer(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let value = number.doubleValue
        guard value.isFinite, value >= 0, value <= 9_007_199_254_740_991,
              value.rounded(.towardZero) == value else { return nil }
        return Int(value)
    }

    private static func boolean(_ value: Any?) -> Bool? {
        guard let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else { return nil }
        return number.boolValue
    }

    private static func identifier(_ value: Any?) -> String? {
        guard let text = value as? String, !text.isEmpty, text.utf8.count <= 128,
              text.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0)
                || (97...122).contains($0) || [45, 46, 58, 95].contains($0) }) else { return nil }
        return text
    }
}

/// native 초기화에서만 지원을 지정한다. 페이지 메시지는 지원 여부를 변경하지 않는다.
struct RhwpStudioCommandFailureState {
    enum Decision: Equatable {
        case ignored
        case recovered(RhwpStudioCommandFailure)
        case fatal(String)
    }

    let support: RhwpStudioCommandFailureSupport
    private var token: String?
    private var loadID: Int?
    private var snapshot: RhwpStudioEditorSnapshot?
    private var recent: [RhwpStudioCommandFailure] = []
    private var lastSequence = 0
    private(set) var isRecovering = false
    var blocksCommands: Bool { isSuspended || isRecovering }
    private var upstreamSession: String?
    private(set) var isSuspended = false
    private(set) var fatalDiagnostic: String?
    var usesStructuredContract: Bool { support == .version1 || (support == .upstreamVersion1 && upstreamSession != nil) }
    var retainedEventCount: Int { recent.count }

    init(support: RhwpStudioCommandFailureSupport = .unavailable) { self.support = support }

    mutating func beginLoad(token: String, loadID: Int) {
        self.token = token; self.loadID = loadID; snapshot = nil
        recent.removeAll(); lastSequence = 0; isSuspended = false; fatalDiagnostic = nil
        upstreamSession = nil; isRecovering = false
    }

    mutating func updateSession(_ value: RhwpStudioEditorSnapshot) {
        guard !isSuspended, value.isValid, value.loadID == loadID else { return }
        if let previous = snapshot {
            guard value.documentEpoch >= previous.documentEpoch,
                  value.sequence > previous.sequence,
                  value.documentEpoch != previous.documentEpoch || value.changeSeq >= previous.changeSeq else { return }
            if value.documentEpoch != previous.documentEpoch {
                recent.removeAll(); lastSequence = 0; upstreamSession = nil; isRecovering = false
            }
        }
        snapshot = value
    }

    mutating func receiveUpstream(_ body: [String: Any], source: RhwpStudioCommandFailureSource) -> Decision {
        guard support == .upstreamVersion1, source.isTrusted, !isSuspended,
              let token, body["loadToken"] as? String == token,
              RhwpStudioCommandFailure.integer(body["loadID"]) == loadID,
              let snapshot,
              RhwpStudioCommandFailure.integer(body["documentEpoch"]) == snapshot.documentEpoch,
              let session = body["documentSessionId"] as? String, !session.isEmpty, session.utf8.count <= 128
        else { return .ignored }
        if body["type"] as? String == "command-recovery-state" {
            if upstreamSession != session { upstreamSession = session; recent.removeAll(); isRecovering = false }
            switch body["status"] as? String {
            case "recovering": isRecovering = true
            case "ready": break // 완료 보고만 pending을 해제한다.
            case "blocked": return reject("INTEGRITY_UNKNOWN")
            default: return reject("INVALID_COMMAND_STATE")
            }
            return .ignored
        }
        guard session == upstreamSession else { return .ignored }
        guard snapshot.ready else { return reject("COMMAND_REPORT_NOT_READY") }
        guard let payload = body["payload"] as? [String: Any],
              let failure = RhwpStudioCommandFailure.parseUpstream(payload),
              failure.documentSessionID == session else { return reject("INVALID_COMMAND_FAILURE") }
        if let old = recent.first(where: { $0.eventID == failure.eventID }) {
            return old == failure ? .ignored : reject("CONFLICTING_COMMAND_FAILURE")
        }
        guard failure.isRecovered else { return reject(failure.code, diagnostic: failure.diagnostic) }
        // opaque ID에는 순서가 없다. 보관 한도를 넘으면 성공 재처리를 허용하지 않는다.
        guard recent.count < 256 else { return reject("COMMAND_EVENT_LIMIT") }
        recent.append(failure); isRecovering = false
        return .recovered(failure)
    }

    mutating func suspend() { isSuspended = true }

    mutating func receive(_ body: [String: Any], source: RhwpStudioCommandFailureSource) -> Decision {
        guard support == .version1, source.isTrusted, !isSuspended,
              let token, body["loadToken"] as? String == token,
              RhwpStudioCommandFailure.integer(body["loadID"]) == loadID,
              let snapshot, snapshot.ready,
              RhwpStudioCommandFailure.integer(body["documentEpoch"]) == snapshot.documentEpoch
        else { return .ignored }
        guard let failure = RhwpStudioCommandFailure.parse(body) else { return reject("INVALID_COMMAND_FAILURE") }
        if let previous = recent.first(where: { $0.eventID == failure.eventID }) {
            return previous == failure ? .ignored : reject("CONFLICTING_COMMAND_FAILURE")
        }
        // 무결성 실패는 낮은 revision/sequence라도 현재 문서의 안전한 상태를 보증하지 못한다.
        guard failure.isRecovered else { return reject(failure.code, diagnostic: failure.diagnostic) }
        guard failure.eventSequence > lastSequence else { return .ignored }
        lastSequence = failure.eventSequence
        recent.append(failure)
        if recent.count > 64 { recent.removeFirst() }
        guard failure.changeSeq >= snapshot.changeSeq else { return .ignored }
        return .recovered(failure)
    }

    private mutating func reject(_ code: String, diagnostic: String? = nil) -> Decision {
        fatalDiagnostic = diagnostic
        isSuspended = true
        return .fatal(code)
    }
}

struct RhwpStudioCommandFailurePresentation: Equatable {
    private(set) var failure: RhwpStudioCommandFailure?
    private(set) var occurrenceCount = 0
    private(set) var isVisible = false

    var message: String {
        "요청한 작업을 완료하지 못했습니다. 문서 내용은 유지되었으며 계속 편집할 수 있습니다."
    }

    mutating func present(_ value: RhwpStudioCommandFailure) {
        if failure?.code == value.code && failure?.operation == value.operation {
            occurrenceCount = min(occurrenceCount + 1, 99)
        } else { occurrenceCount = 1 }
        failure = value; isVisible = true
    }

    mutating func dismiss() { isVisible = false }
    mutating func show() { isVisible = failure != nil }
    mutating func clear() { self = Self() }
}
