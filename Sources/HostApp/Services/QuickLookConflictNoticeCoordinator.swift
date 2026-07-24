import Foundation

@MainActor
final class QuickLookConflictNoticeCoordinator {
    static let shared = QuickLookConflictNoticeCoordinator()

    private let dismissalStore: QuickLookConflictDismissalStore
    private let settingsOpener: QuickLookSettingsOpener
    private var didStart = false

    init(
        dismissalStore: QuickLookConflictDismissalStore = QuickLookConflictDismissalStore(),
        settingsOpener: QuickLookSettingsOpener = QuickLookSettingsOpener()
    ) {
        self.dismissalStore = dismissalStore
        self.settingsOpener = settingsOpener
    }

    func startIfNeeded() {
        guard !didStart else {
            return
        }
        didStart = true

        let appBundleURL = Bundle.main.bundleURL
        Task {
            let snapshot = await Task.detached {
                QuickLookConflictDetector().detect(
                    alhangeulAppBundleURL: appBundleURL
                )
            }.value

            presentIfNeeded(snapshot)
        }
    }

    private func presentIfNeeded(_ snapshot: QuickLookConflictSnapshot) {
        guard QuickLookConflictNoticePolicy.shouldPresent(
            snapshot: snapshot,
            dismissedFingerprint: dismissalStore.dismissedFingerprint
        ),
        let fingerprint = snapshot.fingerprint,
        let presentation = QuickLookConflictPresentation(snapshot: snapshot)
        else {
            return
        }

        QuickLookConflictNoticePresenter.shared.show(
            presentation: presentation
        ) { [weak self] action in
            guard let self else {
                return
            }

            if action.completesNotice {
                dismissalStore.recordDismissal(fingerprint: fingerprint)
            }

            switch action {
            case .openSettings:
                _ = settingsOpener.open()
            case .showDetails:
                AboutWindowPresenter.shared.show(section: .quickLook)
            case .later:
                break
            }
        }
    }
}
