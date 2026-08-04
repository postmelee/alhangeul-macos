import Foundation

enum AppExecutionTransportFailure: Equatable {
    case network
    case timeout
    case other
}

enum AppExecutionTransportResult: Equatable {
    case response(statusCode: Int)
    case failure(AppExecutionTransportFailure)
}

protocol AppExecutionEventTransport {
    func send(_ event: AppExecutionEvent) async -> AppExecutionTransportResult
}

enum AppExecutionDeliveryDisposition: Equatable {
    case accepted
    case retry
    case discard
}

enum AppExecutionDeliveryPolicy {
    static func disposition(
        for result: AppExecutionTransportResult
    ) -> AppExecutionDeliveryDisposition {
        switch result {
        case .response(statusCode: 202):
            return .accepted
        case .response(statusCode: 429):
            return .retry
        case let .response(statusCode) where (500...599).contains(statusCode):
            return .retry
        case let .response(statusCode) where (400...499).contains(statusCode):
            return .discard
        case .response, .failure:
            return .retry
        }
    }

    static func shouldStopPass(after result: AppExecutionTransportResult) -> Bool {
        switch result {
        case .response(statusCode: 429):
            return true
        case let .response(statusCode) where (500...599).contains(statusCode):
            return true
        case .failure(.network), .failure(.timeout):
            return true
        case .response, .failure(.other):
            return false
        }
    }
}

enum AppExecutionOutboxPolicy {
    static let maximumEntryCount = 64
    static let unattemptedRetentionDays = 30
    static let attemptedRetryDays = 6

    static func enqueue(
        _ entry: AppExecutionOutboxEntry,
        into entries: inout [AppExecutionOutboxEntry],
        now: Date
    ) {
        pruneAndLimit(&entries, now: now)
        guard !entries.contains(where: { $0.id == entry.id }) else {
            return
        }

        entries.append(entry)
        trimToMaximumCount(&entries)
    }

    static func pruneAndLimit(
        _ entries: inout [AppExecutionOutboxEntry],
        now: Date
    ) {
        entries.removeAll { isExpired($0, now: now) }
        trimToMaximumCount(&entries)
    }

    static func isExpired(
        _ entry: AppExecutionOutboxEntry,
        now: Date
    ) -> Bool {
        if let firstAttemptedAt = entry.firstAttemptedAt {
            return elapsedUTCDays(from: firstAttemptedAt, to: now)
                > attemptedRetryDays
        }

        return elapsedUTCDays(from: entry.createdAt, to: now)
            > unattemptedRetentionDays
    }

    static func elapsedUTCDays(from start: Date, to end: Date) -> Int {
        let startOfStartDay = calendar.startOfDay(for: start)
        let startOfEndDay = calendar.startOfDay(for: end)
        return calendar.dateComponents(
            [.day],
            from: startOfStartDay,
            to: startOfEndDay
        ).day ?? 0
    }

    private static func trimToMaximumCount(
        _ entries: inout [AppExecutionOutboxEntry]
    ) {
        let overflow = entries.count - maximumEntryCount
        if overflow > 0 {
            entries.removeFirst(overflow)
        }
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}

struct AppExecutionOutbox {
    private let stateStore: AppExecutionAnalyticsStateStore
    private let now: () -> Date

    init(
        stateStore: AppExecutionAnalyticsStateStore,
        now: @escaping () -> Date = Date.init
    ) {
        self.stateStore = stateStore
        self.now = now
    }

    func prepareSnapshot() -> [AppExecutionOutboxEntry] {
        var snapshot: [AppExecutionOutboxEntry] = []
        let didCommit = stateStore.update { state in
            AppExecutionOutboxPolicy.pruneAndLimit(
                &state.outbox,
                now: now()
            )
            snapshot = state.outbox
        }
        return didCommit ? snapshot : []
    }

    func markAttemptStarted(eventID: UUID) -> AppExecutionOutboxEntry? {
        var attemptedEntry: AppExecutionOutboxEntry?
        let didCommit = stateStore.update { state in
            let attemptDate = now()
            AppExecutionOutboxPolicy.pruneAndLimit(
                &state.outbox,
                now: attemptDate
            )
            guard let index = state.outbox.firstIndex(where: { $0.id == eventID })
            else {
                return
            }

            if state.outbox[index].firstAttemptedAt == nil {
                state.outbox[index].firstAttemptedAt = attemptDate
            }
            attemptedEntry = state.outbox[index]
        }
        return didCommit ? attemptedEntry : nil
    }

    @discardableResult
    func apply(
        _ result: AppExecutionTransportResult,
        to eventID: UUID
    ) -> Bool {
        var didFindEvent = false
        let disposition = AppExecutionDeliveryPolicy.disposition(for: result)
        let didCommit = stateStore.update { state in
            guard let index = state.outbox.firstIndex(where: { $0.id == eventID })
            else {
                return
            }
            didFindEvent = true

            switch disposition {
            case .accepted:
                let acceptedVersion = state.outbox[index].event.toVersion
                state.outbox.remove(at: index)
                state.lastAcceptedVersion = acceptedVersion
            case .discard:
                state.outbox.remove(at: index)
            case .retry:
                AppExecutionOutboxPolicy.pruneAndLimit(
                    &state.outbox,
                    now: now()
                )
            }
        }
        return didCommit && didFindEvent
    }
}

struct AppExecutionOutboxProcessor {
    private let outbox: AppExecutionOutbox
    private let transport: AppExecutionEventTransport

    init(
        outbox: AppExecutionOutbox,
        transport: AppExecutionEventTransport
    ) {
        self.outbox = outbox
        self.transport = transport
    }

    func processCurrentSnapshot() async {
        let snapshot = outbox.prepareSnapshot()
        for entry in snapshot {
            guard !Task.isCancelled else {
                return
            }
            guard let attemptedEntry = outbox.markAttemptStarted(eventID: entry.id)
            else {
                continue
            }
            guard !Task.isCancelled else {
                return
            }

            let result = await transport.send(attemptedEntry.event)
            outbox.apply(result, to: attemptedEntry.id)
            if AppExecutionDeliveryPolicy.shouldStopPass(after: result) {
                return
            }
        }
    }
}
