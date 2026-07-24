import Foundation

enum QuickLookConflictNoticePolicy {
    static func shouldPresent(
        snapshot: QuickLookConflictSnapshot,
        dismissedFingerprint: String?
    ) -> Bool {
        guard snapshot.guidance == .preferAlhangeul,
              let fingerprint = snapshot.fingerprint
        else {
            return false
        }

        return fingerprint != dismissedFingerprint
    }
}

struct QuickLookConflictDismissalStore {
    static let defaultsKey = "alhangeul.quickLookConflict.dismissedFingerprint.v1"

    private let userDefaults: UserDefaults
    private let key: String

    init(
        userDefaults: UserDefaults = .standard,
        key: String = Self.defaultsKey
    ) {
        self.userDefaults = userDefaults
        self.key = key
    }

    var dismissedFingerprint: String? {
        userDefaults.string(forKey: key)
    }

    func recordDismissal(fingerprint: String) {
        userDefaults.set(fingerprint, forKey: key)
    }
}
