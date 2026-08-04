import Foundation

struct AppExecutionPendingSparkleUpdate: Codable, Equatable {
    let fromVersion: String
    let toVersion: String
    let recordedAt: Date

    static func make(
        fromVersion: String,
        toVersion: String,
        recordedAt: Date
    ) -> AppExecutionPendingSparkleUpdate? {
        guard let normalizedFromVersion = AppExecutionVersion.normalize(fromVersion),
              let normalizedToVersion = AppExecutionVersion.normalize(toVersion),
              normalizedFromVersion != normalizedToVersion
        else {
            return nil
        }

        return AppExecutionPendingSparkleUpdate(
            fromVersion: normalizedFromVersion,
            toVersion: normalizedToVersion,
            recordedAt: recordedAt
        )
    }
}

struct AppExecutionOutboxEntry: Codable, Equatable, Identifiable {
    let event: AppExecutionEvent
    let createdAt: Date
    var firstAttemptedAt: Date?

    var id: UUID {
        event.id
    }
}

struct AppExecutionAnalyticsState: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var lastObservedVersion: String?
    var lastAcceptedVersion: String?
    var pendingSparkleUpdate: AppExecutionPendingSparkleUpdate?
    var outbox: [AppExecutionOutboxEntry]

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        lastObservedVersion: String? = nil,
        lastAcceptedVersion: String? = nil,
        pendingSparkleUpdate: AppExecutionPendingSparkleUpdate? = nil,
        outbox: [AppExecutionOutboxEntry] = []
    ) {
        self.schemaVersion = schemaVersion
        self.lastObservedVersion = lastObservedVersion
        self.lastAcceptedVersion = lastAcceptedVersion
        self.pendingSparkleUpdate = pendingSparkleUpdate
        self.outbox = outbox
    }

    var isValidForCurrentSchema: Bool {
        guard schemaVersion == Self.currentSchemaVersion,
              isNormalizedVersion(lastObservedVersion),
              isNormalizedVersion(lastAcceptedVersion)
        else {
            return false
        }

        if let pendingSparkleUpdate {
            guard AppExecutionVersion.normalize(pendingSparkleUpdate.fromVersion)
                    == pendingSparkleUpdate.fromVersion,
                  AppExecutionVersion.normalize(pendingSparkleUpdate.toVersion)
                    == pendingSparkleUpdate.toVersion,
                  pendingSparkleUpdate.fromVersion != pendingSparkleUpdate.toVersion
            else {
                return false
            }
        }

        return Set(outbox.map(\.id)).count == outbox.count
    }

    private func isNormalizedVersion(_ version: String?) -> Bool {
        guard let version else {
            return true
        }
        return AppExecutionVersion.normalize(version) == version
    }
}

final class AppExecutionAnalyticsStateStore {
    static let enabledDefaultsKey = "alhangeul.analytics.enabled.v1"
    static let stateDefaultsKey = "alhangeul.analytics.state.v1"

    private let userDefaults: UserDefaults
    private let enabledKey: String
    private let stateKey: String
    private let lock = NSLock()

    init(
        userDefaults: UserDefaults = .standard,
        enabledKey: String = AppExecutionAnalyticsStateStore.enabledDefaultsKey,
        stateKey: String = AppExecutionAnalyticsStateStore.stateDefaultsKey
    ) {
        self.userDefaults = userDefaults
        self.enabledKey = enabledKey
        self.stateKey = stateKey
    }

    var isEnabled: Bool {
        withLock {
            isEnabledWithoutLock()
        }
    }

    @discardableResult
    func setEnabled(_ isEnabled: Bool) -> Bool {
        withLock {
            if !isEnabled {
                var state = loadWithoutLock()
                state.lastAcceptedVersion = nil
                state.pendingSparkleUpdate = nil
                state.outbox.removeAll()
                guard saveWithoutLock(state) else {
                    userDefaults.set(false, forKey: enabledKey)
                    userDefaults.removeObject(forKey: stateKey)
                    return false
                }
            }
            userDefaults.set(isEnabled, forKey: enabledKey)
            return true
        }
    }

    func load() -> AppExecutionAnalyticsState {
        withLock {
            loadWithoutLock()
        }
    }

    @discardableResult
    func update(_ mutation: (inout AppExecutionAnalyticsState) -> Void) -> Bool {
        withLock {
            var state = loadWithoutLock()
            mutation(&state)
            return saveWithoutLock(state)
        }
    }

    @discardableResult
    func updateForCurrentPreference(
        _ mutation: (Bool, inout AppExecutionAnalyticsState) -> Void
    ) -> Bool {
        withLock {
            var state = loadWithoutLock()
            mutation(isEnabledWithoutLock(), &state)
            return saveWithoutLock(state)
        }
    }

    private func isEnabledWithoutLock() -> Bool {
        guard userDefaults.object(forKey: enabledKey) != nil else {
            return true
        }
        return userDefaults.bool(forKey: enabledKey)
    }

    private func saveWithoutLock(_ state: AppExecutionAnalyticsState) -> Bool {
        guard state.isValidForCurrentSchema,
              let data = try? JSONEncoder().encode(state)
        else {
            return false
        }

        userDefaults.set(data, forKey: stateKey)
        return true
    }

    private func loadWithoutLock() -> AppExecutionAnalyticsState {
        guard let data = userDefaults.data(forKey: stateKey),
              let state = try? JSONDecoder().decode(
                AppExecutionAnalyticsState.self,
                from: data
              ),
              state.isValidForCurrentSchema
        else {
            return AppExecutionAnalyticsState()
        }
        return state
    }

    private func withLock<Result>(_ operation: () -> Result) -> Result {
        lock.lock()
        defer { lock.unlock() }
        return operation()
    }
}

struct AppExecutionLegacyEvidenceResolver {
    static let defaultKeys = [
        "alhangeul.launchMaintenance.completedBuild",
        "alhangeul.recentDocuments",
        "alhangeul.quickLookConflict.dismissedFingerprint.v1",
    ]

    private let userDefaults: UserDefaults
    private let keys: [String]

    init(
        userDefaults: UserDefaults = .standard,
        keys: [String] = Self.defaultKeys
    ) {
        self.userDefaults = userDefaults
        self.keys = keys
    }

    func hasEvidence() -> Bool {
        keys.contains { userDefaults.object(forKey: $0) != nil }
    }
}

enum AppExecutionEventPolicy {
    static func observe(
        currentVersion rawCurrentVersion: String,
        hasLegacyEvidence: Bool,
        eventID: UUID,
        occurredAt: Date,
        state: inout AppExecutionAnalyticsState
    ) -> AppExecutionEvent? {
        guard let currentVersion = AppExecutionVersion.normalize(rawCurrentVersion)
        else {
            return nil
        }

        let previousVersion = AppExecutionVersion.normalize(state.lastObservedVersion)
        guard previousVersion != currentVersion else {
            state.pendingSparkleUpdate = nil
            return nil
        }

        let event: AppExecutionEvent?
        if let previousVersion {
            let isConfirmedSparkleUpdate = state.pendingSparkleUpdate.map {
                $0.fromVersion == previousVersion && $0.toVersion == currentVersion
            } ?? false
            event = AppExecutionEvent.make(
                eventID: eventID,
                eventType: .update,
                occurredAt: occurredAt,
                fromVersion: previousVersion,
                toVersion: currentVersion,
                updateChannel: isConfirmedSparkleUpdate ? .sparkle : .unknown
            )
        } else {
            event = AppExecutionEvent.make(
                eventID: eventID,
                eventType: hasLegacyEvidence ? .existingBaseline : .firstLaunch,
                occurredAt: occurredAt,
                fromVersion: nil,
                toVersion: currentVersion,
                updateChannel: .unknown
            )
        }

        guard let event else {
            return nil
        }

        state.lastObservedVersion = currentVersion
        state.pendingSparkleUpdate = nil
        AppExecutionOutboxPolicy.enqueue(
            AppExecutionOutboxEntry(
                event: event,
                createdAt: occurredAt,
                firstAttemptedAt: nil
            ),
            into: &state.outbox,
            now: occurredAt
        )
        return event
    }
}

struct AppExecutionAnalyticsObserver {
    struct Dependencies {
        var now: () -> Date
        var makeEventID: () -> UUID

        static let live = Dependencies(
            now: Date.init,
            makeEventID: UUID.init
        )
    }

    private let stateStore: AppExecutionAnalyticsStateStore
    private let legacyEvidenceResolver: AppExecutionLegacyEvidenceResolver
    private let dependencies: Dependencies

    init(
        stateStore: AppExecutionAnalyticsStateStore,
        legacyEvidenceResolver: AppExecutionLegacyEvidenceResolver,
        dependencies: Dependencies = .live
    ) {
        self.stateStore = stateStore
        self.legacyEvidenceResolver = legacyEvidenceResolver
        self.dependencies = dependencies
    }

    @discardableResult
    func observe(currentVersion: String) -> AppExecutionEvent? {
        let hasLegacyEvidence = legacyEvidenceResolver.hasEvidence()
        let occurredAt = dependencies.now()
        let eventID = dependencies.makeEventID()
        var generatedEvent: AppExecutionEvent?
        let didCommit = stateStore.updateForCurrentPreference { isEnabled, state in
            guard isEnabled else {
                if let normalizedVersion = AppExecutionVersion.normalize(currentVersion) {
                    state.lastObservedVersion = normalizedVersion
                }
                state.pendingSparkleUpdate = nil
                state.outbox.removeAll()
                return
            }
            generatedEvent = AppExecutionEventPolicy.observe(
                currentVersion: currentVersion,
                hasLegacyEvidence: hasLegacyEvidence,
                eventID: eventID,
                occurredAt: occurredAt,
                state: &state
            )
        }

        return didCommit ? generatedEvent : nil
    }
}

struct AppExecutionSparkleUpdateObserver {
    struct Dependencies {
        var now: () -> Date

        static let live = Dependencies(now: Date.init)
    }

    private let stateStore: AppExecutionAnalyticsStateStore
    private let dependencies: Dependencies

    init(
        stateStore: AppExecutionAnalyticsStateStore,
        dependencies: Dependencies = .live
    ) {
        self.stateStore = stateStore
        self.dependencies = dependencies
    }

    @discardableResult
    func willInstallUpdate(
        fromVersion: String,
        displayVersion: String
    ) -> AppExecutionPendingSparkleUpdate? {
        guard let pendingUpdate = AppExecutionPendingSparkleUpdate.make(
            fromVersion: fromVersion,
            toVersion: displayVersion,
            recordedAt: dependencies.now()
        )
        else {
            return nil
        }

        var recordedUpdate: AppExecutionPendingSparkleUpdate?
        let didCommit = stateStore.updateForCurrentPreference { isEnabled, state in
            guard isEnabled else {
                return
            }
            state.pendingSparkleUpdate = pendingUpdate
            recordedUpdate = pendingUpdate
        }
        return didCommit ? recordedUpdate : nil
    }
}
