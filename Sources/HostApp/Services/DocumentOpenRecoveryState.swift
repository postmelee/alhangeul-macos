import Foundation

enum DocumentOpenSource: CaseIterable, Equatable {
    case filePanel
    case externalOpen
    case recentDocument
    case fileDrop
    case webViewDrop

    var failureTitle: String {
        switch self {
        case .recentDocument:
            return "최근 문서를 열 수 없습니다"
        case .fileDrop, .webViewDrop:
            return "끌어놓은 문서를 열 수 없습니다"
        case .filePanel, .externalOpen:
            return "문서를 열 수 없습니다"
        }
    }
}

struct RecoverableDocumentOpenFailure: Identifiable, Equatable {
    let id: UUID
    let source: DocumentOpenSource
    let filename: String?
    let title: String
    let message: String

    init(
        id: UUID = UUID(),
        source: DocumentOpenSource,
        filename: String?,
        reason: String
    ) {
        let sanitizedFilename = Self.sanitizedFilename(filename)
        self.id = id
        self.source = source
        self.filename = sanitizedFilename
        self.title = source.failureTitle
        self.message = Self.message(filename: sanitizedFilename, reason: reason)
    }

    private static func sanitizedFilename(_ filename: String?) -> String? {
        guard let filename else {
            return nil
        }

        let trimmedFilename = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFilename.isEmpty else {
            return nil
        }

        let lastPathComponent = URL(fileURLWithPath: trimmedFilename).lastPathComponent
        return lastPathComponent.isEmpty ? nil : lastPathComponent
    }

    private static func message(filename: String?, reason: String) -> String {
        guard let filename else {
            return reason
        }
        return "파일: \(filename)\n\(reason)"
    }
}

struct DocumentOpenRecoveryState: Equatable {
    private(set) var activeLoadID = 0
    private(set) var isLoading = false
    private(set) var failure: RecoverableDocumentOpenFailure?
    private(set) var isRetryPending = false

    mutating func beginLoad() -> Int {
        activeLoadID += 1
        isLoading = true
        failure = nil
        isRetryPending = false
        return activeLoadID
    }

    func isCurrent(loadID: Int) -> Bool {
        activeLoadID == loadID
    }

    @discardableResult
    mutating func failLoad(
        loadID: Int,
        failure: RecoverableDocumentOpenFailure
    ) -> Bool {
        guard isLoading, isCurrent(loadID: loadID) else {
            return false
        }

        isLoading = false
        self.failure = failure
        return true
    }

    @discardableResult
    mutating func completeLoad(loadID: Int) -> Bool {
        guard isLoading, isCurrent(loadID: loadID) else {
            return false
        }

        isLoading = false
        failure = nil
        isRetryPending = false
        return true
    }

    mutating func dismissFailure() {
        failure = nil
        isRetryPending = false
    }

    mutating func beginRetry() -> Bool {
        guard failure != nil, !isRetryPending else {
            return false
        }

        failure = nil
        isRetryPending = true
        return true
    }

    mutating func consumeRetry() -> Bool {
        guard isRetryPending else {
            return false
        }

        isRetryPending = false
        return true
    }
}
