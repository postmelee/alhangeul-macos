import XCTest

final class AppExecutionAnalyticsStateTests: XCTestCase {
    private let fixedDate = ISO8601DateFormatter().date(from: "2026-08-03T03:00:00Z")!
    private let fixedEventID = UUID(uuidString: "12345678-1234-4abc-8def-1234567890ab")!

    private var suiteName: String!
    private var userDefaults: UserDefaults!
    private var stateStore: AppExecutionAnalyticsStateStore!

    override func setUp() {
        super.setUp()
        suiteName = "AppExecutionAnalyticsStateTests.\(UUID().uuidString)"
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

    func testFreshStateCreatesFirstLaunchAndPersistsObservationAtomically() {
        let event = makeObserver().observe(currentVersion: "0.1.9")
        let state = stateStore.load()

        XCTAssertEqual(event?.eventType, .firstLaunch)
        XCTAssertEqual(event?.toVersion, "0.1.9")
        XCTAssertEqual(event?.occurredDate, "2026-08-03")
        XCTAssertEqual(event?.updateChannel, .unknown)
        XCTAssertEqual(state.lastObservedVersion, "0.1.9")
        XCTAssertNil(state.lastAcceptedVersion)
        XCTAssertEqual(state.outbox.map(\.event), [event].compactMap { $0 })
    }

    func testEachAllowlistedLegacyKeyCreatesExistingBaseline() {
        for key in AppExecutionLegacyEvidenceResolver.defaultKeys {
            userDefaults.removePersistentDomain(forName: suiteName)
            userDefaults.set("evidence", forKey: key)

            let event = makeObserver().observe(currentVersion: "0.1.9")

            XCTAssertEqual(event?.eventType, .existingBaseline, "key=\(key)")
        }
    }

    func testUnrelatedDefaultsDoNotCreateExistingBaseline() {
        userDefaults.set("not-app-evidence", forKey: "SUHasLaunchedBefore")

        let event = makeObserver().observe(currentVersion: "0.1.9")

        XCTAssertEqual(event?.eventType, .firstLaunch)
    }

    func testSameVersionDoesNotCreateDuplicateEvent() {
        _ = makeObserver().observe(currentVersion: "0.1.9")

        let secondEvent = makeObserver(
            eventID: UUID(uuidString: "87654321-4321-4abc-8def-abcdef123456")!
        ).observe(currentVersion: "0.1.9")

        XCTAssertNil(secondEvent)
        XCTAssertEqual(stateStore.load().outbox.count, 1)
    }

    func testUnknownVersionTransitionCreatesUnknownUpdate() {
        _ = makeObserver().observe(currentVersion: "0.1.8")

        let update = makeObserver(
            eventID: UUID(uuidString: "87654321-4321-4abc-8def-abcdef123456")!
        ).observe(currentVersion: "0.1.9")

        XCTAssertEqual(update?.eventType, .update)
        XCTAssertEqual(update?.fromVersion, "0.1.8")
        XCTAssertEqual(update?.toVersion, "0.1.9")
        XCTAssertEqual(update?.updateChannel, .unknown)
        XCTAssertEqual(stateStore.load().lastObservedVersion, "0.1.9")
    }

    func testMatchingPendingSparkleTransitionCreatesSparkleUpdate() throws {
        try seedObservedVersion("0.1.8")
        let pending = try XCTUnwrap(
            AppExecutionPendingSparkleUpdate.make(
                fromVersion: "0.1.8",
                toVersion: "0.1.9",
                recordedAt: fixedDate
            )
        )
        XCTAssertTrue(stateStore.update { $0.pendingSparkleUpdate = pending })

        let update = makeObserver().observe(currentVersion: "0.1.9")

        XCTAssertEqual(update?.updateChannel, .sparkle)
        XCTAssertNil(stateStore.load().pendingSparkleUpdate)
    }

    func testMismatchedPendingTransitionFallsBackToUnknownAndClearsPending() throws {
        try seedObservedVersion("0.1.8")
        let pending = try XCTUnwrap(
            AppExecutionPendingSparkleUpdate.make(
                fromVersion: "0.1.8",
                toVersion: "0.2.0",
                recordedAt: fixedDate
            )
        )
        XCTAssertTrue(stateStore.update { $0.pendingSparkleUpdate = pending })

        let update = makeObserver().observe(currentVersion: "0.1.9")

        XCTAssertEqual(update?.updateChannel, .unknown)
        XCTAssertNil(stateStore.load().pendingSparkleUpdate)
    }

    func testUninstalledPendingTransitionDoesNotCreateUpdateAndIsCleared() throws {
        try seedObservedVersion("0.1.8")
        let pending = try XCTUnwrap(
            AppExecutionPendingSparkleUpdate.make(
                fromVersion: "0.1.8",
                toVersion: "0.1.9",
                recordedAt: fixedDate
            )
        )
        XCTAssertTrue(stateStore.update { $0.pendingSparkleUpdate = pending })

        let event = makeObserver().observe(currentVersion: "0.1.8")

        XCTAssertNil(event)
        XCTAssertNil(stateStore.load().pendingSparkleUpdate)
        XCTAssertTrue(stateStore.load().outbox.isEmpty)
    }

    func testClearedOutboxDoesNotRegenerateAlreadyObservedVersion() {
        _ = makeObserver().observe(currentVersion: "0.1.9")
        XCTAssertTrue(stateStore.update { $0.outbox.removeAll() })

        let event = makeObserver(
            eventID: UUID(uuidString: "87654321-4321-4abc-8def-abcdef123456")!
        ).observe(currentVersion: "0.1.9")

        XCTAssertNil(event)
        XCTAssertTrue(stateStore.load().outbox.isEmpty)
    }

    func testInvalidCurrentVersionDoesNotChangeState() {
        let event = makeObserver().observe(currentVersion: "version 1")

        XCTAssertNil(event)
        XCTAssertNil(stateStore.load().lastObservedVersion)
        XCTAssertTrue(stateStore.load().outbox.isEmpty)
    }

    func testInvalidEventIDDoesNotChangeState() {
        let event = makeObserver(
            eventID: UUID(uuidString: "12345678-1234-1abc-8def-1234567890ab")!
        ).observe(currentVersion: "0.1.9")

        XCTAssertNil(event)
        XCTAssertNil(stateStore.load().lastObservedVersion)
        XCTAssertTrue(stateStore.load().outbox.isEmpty)
    }

    func testCorruptedAndUnknownStateRecoverWithoutCrash() throws {
        userDefaults.set(Data("not-json".utf8), forKey: AppExecutionAnalyticsStateStore.stateDefaultsKey)
        XCTAssertEqual(stateStore.load(), AppExecutionAnalyticsState())

        let futureState = AppExecutionAnalyticsState(schemaVersion: 999)
        userDefaults.set(
            try JSONEncoder().encode(futureState),
            forKey: AppExecutionAnalyticsStateStore.stateDefaultsKey
        )
        XCTAssertEqual(stateStore.load(), AppExecutionAnalyticsState())

        let invalidVersionState = AppExecutionAnalyticsState(
            lastObservedVersion: "not-a-version"
        )
        userDefaults.set(
            try JSONEncoder().encode(invalidVersionState),
            forKey: AppExecutionAnalyticsStateStore.stateDefaultsKey
        )
        XCTAssertEqual(stateStore.load(), AppExecutionAnalyticsState())
    }

    func testAnalyticsDefaultsToEnabledAndOptOutPreventsObservation() {
        XCTAssertTrue(stateStore.isEnabled)

        stateStore.setEnabled(false)
        let event = makeObserver().observe(currentVersion: "0.1.9")

        XCTAssertFalse(stateStore.isEnabled)
        XCTAssertNil(event)
        XCTAssertEqual(stateStore.load().lastObservedVersion, "0.1.9")
        XCTAssertTrue(stateStore.load().outbox.isEmpty)
    }

    func testOptOutClearsDeliveryStateButKeepsObservedVersionBaseline() throws {
        _ = makeObserver().observe(currentVersion: "0.1.8")
        let pending = try XCTUnwrap(
            AppExecutionPendingSparkleUpdate.make(
                fromVersion: "0.1.8",
                toVersion: "0.1.9",
                recordedAt: fixedDate
            )
        )
        XCTAssertTrue(
            stateStore.update {
                $0.lastAcceptedVersion = "0.1.7"
                $0.pendingSparkleUpdate = pending
            }
        )

        XCTAssertTrue(stateStore.setEnabled(false))

        let state = stateStore.load()
        XCTAssertFalse(stateStore.isEnabled)
        XCTAssertEqual(state.lastObservedVersion, "0.1.8")
        XCTAssertNil(state.lastAcceptedVersion)
        XCTAssertTrue(state.outbox.isEmpty)
        XCTAssertNil(state.pendingSparkleUpdate)
    }

    func testReenableDoesNotBackfillVersionObservedWhileDisabled() {
        _ = makeObserver().observe(currentVersion: "0.1.8")
        stateStore.setEnabled(false)

        XCTAssertNil(makeObserver().observe(currentVersion: "0.1.9"))
        XCTAssertEqual(stateStore.load().lastObservedVersion, "0.1.9")
        XCTAssertTrue(stateStore.load().outbox.isEmpty)

        stateStore.setEnabled(true)
        XCTAssertNil(makeObserver().observe(currentVersion: "0.1.9"))

        let nextUpdate = makeObserver(
            eventID: UUID(uuidString: "87654321-4321-4abc-8def-abcdef123456")!
        ).observe(currentVersion: "0.2.0")
        XCTAssertEqual(nextUpdate?.eventType, .update)
        XCTAssertEqual(nextUpdate?.fromVersion, "0.1.9")
        XCTAssertEqual(nextUpdate?.toVersion, "0.2.0")
    }

    func testSparkleObserverStoresValidatedPendingWithoutCreatingEvent() {
        let observer = AppExecutionSparkleUpdateObserver(
            stateStore: stateStore,
            dependencies: .init(now: { self.fixedDate })
        )

        let pending = observer.willInstallUpdate(
            fromVersion: "v0.1.8",
            displayVersion: "0.1.9"
        )

        XCTAssertEqual(pending?.fromVersion, "0.1.8")
        XCTAssertEqual(pending?.toVersion, "0.1.9")
        XCTAssertEqual(pending?.recordedAt, fixedDate)
        XCTAssertEqual(stateStore.load().pendingSparkleUpdate, pending)
        XCTAssertTrue(stateStore.load().outbox.isEmpty)
    }

    func testSparkleObserverIgnoresInvalidOrDisabledTransition() {
        let observer = AppExecutionSparkleUpdateObserver(
            stateStore: stateStore,
            dependencies: .init(now: { self.fixedDate })
        )

        XCTAssertNil(
            observer.willInstallUpdate(
                fromVersion: "0.1.9",
                displayVersion: "0.1.9"
            )
        )
        XCTAssertNil(stateStore.load().pendingSparkleUpdate)

        stateStore.setEnabled(false)
        XCTAssertNil(
            observer.willInstallUpdate(
                fromVersion: "0.1.9",
                displayVersion: "0.2.0"
            )
        )
        XCTAssertNil(stateStore.load().pendingSparkleUpdate)
    }

    private func makeObserver(
        eventID: UUID? = nil
    ) -> AppExecutionAnalyticsObserver {
        AppExecutionAnalyticsObserver(
            stateStore: stateStore,
            legacyEvidenceResolver: AppExecutionLegacyEvidenceResolver(
                userDefaults: userDefaults
            ),
            dependencies: .init(
                now: { self.fixedDate },
                makeEventID: { eventID ?? self.fixedEventID }
            )
        )
    }

    private func seedObservedVersion(_ version: String) throws {
        XCTAssertTrue(
            stateStore.update {
                $0.lastObservedVersion = version
            }
        )
    }
}
