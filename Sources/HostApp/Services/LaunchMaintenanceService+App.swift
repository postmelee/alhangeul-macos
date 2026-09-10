import Foundation

extension LaunchMaintenanceService {
    /// 앱 진입점의 시스템 의존만 연결한다. 순서 정책은 주입 가능한 overload에서 검증한다.
    @discardableResult
    static func runIfNeeded(userDefaults: UserDefaults = .standard) -> LaunchMaintenanceResult {
        runIfNeeded(
            userDefaults: userDefaults,
            appBundleURL: Bundle.main.bundleURL,
            buildIdentifier: BuildInfo.launchMaintenanceBuildIdentifier,
            refreshRegistration: { ExtensionSystemRegistrationRefresher.refreshCurrentBundle() },
            refreshThumbnails: {
                let result = RecentDocumentThumbnailRefresher.refreshRecentDocuments()
                return (result.refreshedCount, result.skippedCount)
            }
        )
    }
}
