import XCTest

final class QuickLookConflictNoticePolicyTests: XCTestCase {
    private var suiteName: String!
    private var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "QuickLookConflictNoticePolicyTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testKnownPreferAlhangeulSnapshotIsPresentedInitially() {
        XCTAssertTrue(
            QuickLookConflictNoticePolicy.shouldPresent(
                snapshot: makeSnapshot(guidance: .preferAlhangeul, fingerprint: "known"),
                dismissedFingerprint: nil
            )
        )
    }

    func testSameDismissedFingerprintIsNotPresentedAgain() {
        XCTAssertFalse(
            QuickLookConflictNoticePolicy.shouldPresent(
                snapshot: makeSnapshot(guidance: .preferAlhangeul, fingerprint: "known"),
                dismissedFingerprint: "known"
            )
        )
    }

    func testChangedFingerprintIsPresentedAgain() {
        XCTAssertTrue(
            QuickLookConflictNoticePolicy.shouldPresent(
                snapshot: makeSnapshot(guidance: .preferAlhangeul, fingerprint: "changed"),
                dismissedFingerprint: "known"
            )
        )
    }

    func testUnknownComparisonDoesNotPresentLaunchNotice() {
        XCTAssertFalse(
            QuickLookConflictNoticePolicy.shouldPresent(
                snapshot: makeSnapshot(
                    guidance: .overlappingProvider,
                    fingerprint: "unknown-comparison"
                ),
                dismissedFingerprint: nil
            )
        )
    }

    func testNoConflictDoesNotPresentLaunchNotice() {
        XCTAssertFalse(
            QuickLookConflictNoticePolicy.shouldPresent(
                snapshot: makeSnapshot(guidance: .none, fingerprint: nil),
                dismissedFingerprint: nil
            )
        )
    }

    func testOpenSettingsKeepsNoticeActive() {
        XCTAssertFalse(QuickLookConflictNoticeAction.openSettings.completesNotice)
    }

    func testLaterAndDetailsCompleteNotice() {
        XCTAssertTrue(QuickLookConflictNoticeAction.later.completesNotice)
        XCTAssertTrue(QuickLookConflictNoticeAction.showDetails.completesNotice)
    }

    func testDismissalStorePersistsAndReadsFingerprint() {
        let store = QuickLookConflictDismissalStore(userDefaults: userDefaults)

        XCTAssertNil(store.dismissedFingerprint)

        store.recordDismissal(fingerprint: "fixture-fingerprint")

        XCTAssertEqual(store.dismissedFingerprint, "fixture-fingerprint")
        XCTAssertEqual(
            userDefaults.string(forKey: QuickLookConflictDismissalStore.defaultsKey),
            "fixture-fingerprint"
        )
    }

    private func makeSnapshot(
        guidance: QuickLookConflictSnapshot.Guidance,
        fingerprint: String?
    ) -> QuickLookConflictSnapshot {
        QuickLookConflictSnapshot(
            hop: guidance == .none
                ? nil
                : HopQuickLookInstallation(
                    appBundleURL: URL(fileURLWithPath: "/Applications/HOP.app"),
                    app: nil,
                    preview: nil
                ),
            alhangeul: AlhangeulQuickLookInstallation(
                app: nil,
                preview: nil,
                rhwp: nil
            ),
            hopRhwpReleaseTag: guidance == .preferAlhangeul ? "v0.7.13" : nil,
            guidance: guidance,
            fingerprint: fingerprint
        )
    }
}
