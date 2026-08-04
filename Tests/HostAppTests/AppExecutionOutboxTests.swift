import XCTest

final class AppExecutionOutboxTests: XCTestCase {
    private var suiteName: String!
    private var userDefaults: UserDefaults!
    private var stateStore: AppExecutionAnalyticsStateStore!

    override func setUp() {
        super.setUp()
        suiteName = "AppExecutionOutboxTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
        stateStore = AppExecutionAnalyticsStateStore(userDefaults: userDefaults)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        stateStore = nil
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testUnattemptedEntryIsKeptThroughDay30AndExpiresOnDay31() {
        let entry = makeEntry(index: 1, createdAt: date("2026-07-01T23:59:59Z"))

        XCTAssertFalse(
            AppExecutionOutboxPolicy.isExpired(
                entry,
                now: date("2026-07-31T00:00:00Z")
            )
        )
        XCTAssertTrue(
            AppExecutionOutboxPolicy.isExpired(
                entry,
                now: date("2026-08-01T00:00:00Z")
            )
        )
    }

    func testAttemptedEntryIsKeptThroughDay6AndExpiresOnDay7() {
        var entry = makeEntry(index: 1, createdAt: date("2026-07-01T00:00:00Z"))
        entry.firstAttemptedAt = date("2026-07-25T23:59:59Z")

        XCTAssertFalse(
            AppExecutionOutboxPolicy.isExpired(
                entry,
                now: date("2026-07-31T00:00:00Z")
            )
        )
        XCTAssertTrue(
            AppExecutionOutboxPolicy.isExpired(
                entry,
                now: date("2026-08-01T00:00:00Z")
            )
        )
    }

    func testAttemptOnRetentionDay30CanRetryThroughOccurredDateDay36() {
        var entry = makeEntry(index: 1, createdAt: date("2026-06-28T12:00:00Z"))
        entry.firstAttemptedAt = date("2026-07-28T12:00:00Z")

        XCTAssertFalse(
            AppExecutionOutboxPolicy.isExpired(
                entry,
                now: date("2026-08-03T23:59:59Z")
            )
        )
        XCTAssertTrue(
            AppExecutionOutboxPolicy.isExpired(
                entry,
                now: date("2026-08-04T00:00:00Z")
            )
        )
    }

    func testUTCDayCalculationDoesNotUseElapsedHours() {
        XCTAssertEqual(
            AppExecutionOutboxPolicy.elapsedUTCDays(
                from: date("2026-08-01T23:59:59Z"),
                to: date("2026-08-02T00:00:01Z")
            ),
            1
        )
        XCTAssertEqual(
            AppExecutionOutboxPolicy.elapsedUTCDays(
                from: date("2026-08-02T00:00:01Z"),
                to: date("2026-08-01T23:59:59Z")
            ),
            -1
        )
    }

    func testEnqueueDropsOldestEntryAfterSixtyFour() {
        let now = date("2026-08-03T00:00:00Z")
        var entries: [AppExecutionOutboxEntry] = []

        for index in 0...64 {
            AppExecutionOutboxPolicy.enqueue(
                makeEntry(index: index, createdAt: now),
                into: &entries,
                now: now
            )
        }

        XCTAssertEqual(entries.count, 64)
        XCTAssertEqual(entries.first?.id, eventID(index: 1))
        XCTAssertEqual(entries.last?.id, eventID(index: 64))
    }

    func testEnqueuePrunesExpiredEntriesBeforeApplyingCapacity() {
        let now = date("2026-08-03T00:00:00Z")
        var entries = (0..<64).map {
            makeEntry(index: $0, createdAt: date("2026-06-01T00:00:00Z"))
        }

        AppExecutionOutboxPolicy.enqueue(
            makeEntry(index: 100, createdAt: now),
            into: &entries,
            now: now
        )

        XCTAssertEqual(entries.map(\.id), [eventID(index: 100)])
    }

    func testDuplicateEventIDIsNotEnqueued() {
        let now = date("2026-08-03T00:00:00Z")
        let entry = makeEntry(index: 1, createdAt: now)
        var entries = [entry]

        AppExecutionOutboxPolicy.enqueue(entry, into: &entries, now: now)

        XCTAssertEqual(entries, [entry])
    }

    func testMarkAttemptPersistsOriginalFirstAttemptBeforeTransport() {
        var now = date("2026-08-03T03:00:00Z")
        let entry = makeEntry(index: 1, createdAt: date("2026-08-01T00:00:00Z"))
        seed(entries: [entry])
        let outbox = AppExecutionOutbox(stateStore: stateStore, now: { now })

        let first = outbox.markAttemptStarted(eventID: entry.id)
        now = date("2026-08-04T03:00:00Z")
        let retry = outbox.markAttemptStarted(eventID: entry.id)

        XCTAssertEqual(first?.firstAttemptedAt, date("2026-08-03T03:00:00Z"))
        XCTAssertEqual(retry?.firstAttemptedAt, first?.firstAttemptedAt)
        XCTAssertEqual(stateStore.load().outbox.first?.firstAttemptedAt, first?.firstAttemptedAt)
    }

    func testDeliveryDispositionMatchesCollectorContract() {
        XCTAssertEqual(
            AppExecutionDeliveryPolicy.disposition(for: .response(statusCode: 202)),
            .accepted
        )
        XCTAssertEqual(
            AppExecutionDeliveryPolicy.disposition(for: .response(statusCode: 429)),
            .retry
        )
        XCTAssertEqual(
            AppExecutionDeliveryPolicy.disposition(for: .response(statusCode: 503)),
            .retry
        )
        XCTAssertEqual(
            AppExecutionDeliveryPolicy.disposition(for: .failure(.network)),
            .retry
        )
        XCTAssertEqual(
            AppExecutionDeliveryPolicy.disposition(for: .failure(.timeout)),
            .retry
        )
        XCTAssertEqual(
            AppExecutionDeliveryPolicy.disposition(for: .response(statusCode: 400)),
            .discard
        )
        XCTAssertEqual(
            AppExecutionDeliveryPolicy.disposition(for: .response(statusCode: 404)),
            .discard
        )
        XCTAssertEqual(
            AppExecutionDeliveryPolicy.disposition(for: .response(statusCode: 200)),
            .retry
        )
        XCTAssertEqual(
            AppExecutionDeliveryPolicy.disposition(for: .response(statusCode: 302)),
            .retry
        )
        XCTAssertTrue(
            AppExecutionDeliveryPolicy.shouldStopPass(
                after: .response(statusCode: 429)
            )
        )
        XCTAssertTrue(
            AppExecutionDeliveryPolicy.shouldStopPass(
                after: .response(statusCode: 503)
            )
        )
        XCTAssertTrue(
            AppExecutionDeliveryPolicy.shouldStopPass(after: .failure(.network))
        )
        XCTAssertTrue(
            AppExecutionDeliveryPolicy.shouldStopPass(after: .failure(.timeout))
        )
        XCTAssertFalse(
            AppExecutionDeliveryPolicy.shouldStopPass(
                after: .response(statusCode: 202)
            )
        )
        XCTAssertFalse(
            AppExecutionDeliveryPolicy.shouldStopPass(
                after: .response(statusCode: 422)
            )
        )
    }

    func testAcceptedResponseRemovesEventAndRecordsAcceptedVersion() {
        let now = date("2026-08-03T03:00:00Z")
        let entry = makeEntry(index: 1, createdAt: now, toVersion: "0.1.9")
        seed(entries: [entry])
        let outbox = AppExecutionOutbox(stateStore: stateStore, now: { now })

        XCTAssertTrue(outbox.apply(.response(statusCode: 202), to: entry.id))

        XCTAssertTrue(stateStore.load().outbox.isEmpty)
        XCTAssertEqual(stateStore.load().lastAcceptedVersion, "0.1.9")
    }

    func testClientErrorDiscardsWithoutChangingAcceptedVersion() {
        let now = date("2026-08-03T03:00:00Z")
        let entry = makeEntry(index: 1, createdAt: now)
        seed(entries: [entry], lastAcceptedVersion: "0.1.7")
        let outbox = AppExecutionOutbox(stateStore: stateStore, now: { now })

        XCTAssertTrue(outbox.apply(.response(statusCode: 422), to: entry.id))

        XCTAssertTrue(stateStore.load().outbox.isEmpty)
        XCTAssertEqual(stateStore.load().lastAcceptedVersion, "0.1.7")
    }

    func testDuplicateCompletionIsIgnoredAfterAcceptedEventWasRemoved() {
        let now = date("2026-08-03T03:00:00Z")
        let entry = makeEntry(index: 1, createdAt: now, toVersion: "0.1.9")
        seed(entries: [entry])
        let outbox = AppExecutionOutbox(stateStore: stateStore, now: { now })

        XCTAssertTrue(outbox.apply(.response(statusCode: 202), to: entry.id))
        XCTAssertFalse(outbox.apply(.response(statusCode: 202), to: entry.id))

        XCTAssertTrue(stateStore.load().outbox.isEmpty)
        XCTAssertEqual(stateStore.load().lastAcceptedVersion, "0.1.9")
    }

    func testInfrastructureRetryStopsPassAndLeavesRemainingEntriesUnattempted() async {
        let now = date("2026-08-03T03:00:00Z")
        let entries = (1...4).map { makeEntry(index: $0, createdAt: now) }
        seed(entries: entries)
        let outbox = AppExecutionOutbox(stateStore: stateStore, now: { now })
        let transport = FakeAppExecutionTransport(
            results: [.failure(.timeout)]
        )

        await AppExecutionOutboxProcessor(
            outbox: outbox,
            transport: transport
        ).processCurrentSnapshot()

        XCTAssertEqual(transport.sentEventIDs, [entries[0].id])
        XCTAssertEqual(stateStore.load().outbox.map(\.id), entries.map(\.id))
        XCTAssertEqual(stateStore.load().outbox[0].firstAttemptedAt, now)
        XCTAssertTrue(
            stateStore.load().outbox.dropFirst().allSatisfy {
                $0.firstAttemptedAt == nil
            }
        )
    }

    func testProcessorUsesFIFOAndPersistsAttemptBeforeSend() async {
        let now = date("2026-08-03T03:00:00Z")
        let entries = (1...3).map { makeEntry(index: $0, createdAt: now) }
        seed(entries: entries)
        let outbox = AppExecutionOutbox(stateStore: stateStore, now: { now })
        var wereAttemptsPersisted = true
        let transport = FakeAppExecutionTransport(
            results: Array(repeating: .response(statusCode: 202), count: 3),
            onSend: { [stateStore] event in
                let storedEntry = stateStore?.load().outbox.first {
                    $0.id == event.id
                }
                wereAttemptsPersisted = wereAttemptsPersisted
                    && storedEntry?.firstAttemptedAt == now
            }
        )

        await AppExecutionOutboxProcessor(
            outbox: outbox,
            transport: transport
        ).processCurrentSnapshot()

        XCTAssertEqual(transport.sentEventIDs, entries.map(\.id))
        XCTAssertTrue(wereAttemptsPersisted)
        XCTAssertTrue(stateStore.load().outbox.isEmpty)
        XCTAssertEqual(stateStore.load().lastAcceptedVersion, entries.last?.event.toVersion)
    }

    func testProcessorDoesNotSendEventAddedAfterSnapshot() async {
        let now = date("2026-08-03T03:00:00Z")
        let initialEntry = makeEntry(index: 1, createdAt: now)
        let laterEntry = makeEntry(index: 2, createdAt: now)
        seed(entries: [initialEntry])
        let outbox = AppExecutionOutbox(stateStore: stateStore, now: { now })
        var didAddLaterEntry = false
        let transport = FakeAppExecutionTransport(
            results: [.response(statusCode: 202)],
            onSend: { [stateStore] _ in
                guard !didAddLaterEntry else {
                    return
                }
                didAddLaterEntry = true
                _ = stateStore?.update {
                    AppExecutionOutboxPolicy.enqueue(
                        laterEntry,
                        into: &$0.outbox,
                        now: now
                    )
                }
            }
        )

        await AppExecutionOutboxProcessor(
            outbox: outbox,
            transport: transport
        ).processCurrentSnapshot()

        XCTAssertEqual(transport.sentEventIDs, [initialEntry.id])
        XCTAssertEqual(stateStore.load().outbox.map(\.id), [laterEntry.id])
    }

    func testRetryResultDropsEntryWhenRetryWindowHasExpired() {
        let now = date("2026-08-03T00:00:00Z")
        var entry = makeEntry(index: 1, createdAt: date("2026-07-01T00:00:00Z"))
        entry.firstAttemptedAt = date("2026-07-27T00:00:00Z")
        seed(entries: [entry])
        let outbox = AppExecutionOutbox(stateStore: stateStore, now: { now })

        XCTAssertTrue(outbox.apply(.failure(.network), to: entry.id))

        XCTAssertTrue(stateStore.load().outbox.isEmpty)
    }

    private func seed(
        entries: [AppExecutionOutboxEntry],
        lastAcceptedVersion: String? = nil
    ) {
        XCTAssertTrue(
            stateStore.update {
                $0.outbox = entries
                $0.lastAcceptedVersion = lastAcceptedVersion
            }
        )
    }

    private func makeEntry(
        index: Int,
        createdAt: Date,
        toVersion: String? = nil
    ) -> AppExecutionOutboxEntry {
        let event = AppExecutionEvent.make(
            eventID: eventID(index: index),
            eventType: .firstLaunch,
            occurredAt: createdAt,
            fromVersion: nil,
            toVersion: toVersion ?? "0.1.\(index)",
            updateChannel: .unknown
        )!
        return AppExecutionOutboxEntry(
            event: event,
            createdAt: createdAt,
            firstAttemptedAt: nil
        )
    }

    private func eventID(index: Int) -> UUID {
        UUID(
            uuidString: String(
                format: "00000000-0000-4000-8000-%012llx",
                UInt64(index)
            )
        )!
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}

private final class FakeAppExecutionTransport: AppExecutionEventTransport {
    private var results: [AppExecutionTransportResult]
    private let onSend: ((AppExecutionEvent) -> Void)?

    private(set) var sentEventIDs: [UUID] = []

    init(
        results: [AppExecutionTransportResult],
        onSend: ((AppExecutionEvent) -> Void)? = nil
    ) {
        self.results = results
        self.onSend = onSend
    }

    func send(_ event: AppExecutionEvent) async -> AppExecutionTransportResult {
        sentEventIDs.append(event.id)
        onSend?(event)
        guard !results.isEmpty else {
            return .failure(.other)
        }
        return results.removeFirst()
    }
}
