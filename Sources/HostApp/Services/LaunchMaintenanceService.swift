import CoreServices
import Foundation
import OSLog

struct LaunchMaintenanceResult: Equatable {
    let didRun: Bool
    let buildIdentifier: String
    let registrationStatus: OSStatus?
    let refreshedDocumentCount: Int
    let skippedDocumentCount: Int
}

@MainActor
enum LaunchMaintenanceService {
    private static let completedBuildKey = "alhangeul.launchMaintenance.completedBuild"
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.postmelee.alhangeul",
        category: "LaunchMaintenance"
    )

    @discardableResult
    static func runIfNeeded(
        userDefaults: UserDefaults,
        appBundleURL: URL,
        buildIdentifier: String,
        startSpotlight: (URL, String, UserDefaults) -> Void = {
            SpotlightReindexService.start(appBundleURL: $0, buildIdentifier: $1, userDefaults: $2)
        },
        refreshRegistration: () -> OSStatus,
        refreshThumbnails: () -> (refreshedCount: Int, skippedCount: Int)
    ) -> LaunchMaintenanceResult {
        // 기존 Quick Look 유지보수 완료 기록과 Spotlight의 최초 재색인 요청을 분리한다.
        startSpotlight(appBundleURL, buildIdentifier, userDefaults)
        guard userDefaults.string(forKey: completedBuildKey) != buildIdentifier else {
            logger.debug("Launch maintenance skipped build=\(buildIdentifier, privacy: .public)")
            return LaunchMaintenanceResult(
                didRun: false,
                buildIdentifier: buildIdentifier,
                registrationStatus: nil,
                refreshedDocumentCount: 0,
                skippedDocumentCount: 0
            )
        }

        let registrationStatus = refreshRegistration()
        let refreshResult = refreshThumbnails()
        userDefaults.set(buildIdentifier, forKey: completedBuildKey)

        if registrationStatus == noErr {
            logger.debug("Launch maintenance completed build=\(buildIdentifier, privacy: .public) refreshed=\(refreshResult.refreshedCount, privacy: .public) skipped=\(refreshResult.skippedCount, privacy: .public)")
        } else {
            logger.warning("Launch maintenance completed with registration status=\(registrationStatus, privacy: .public) build=\(buildIdentifier, privacy: .public) refreshed=\(refreshResult.refreshedCount, privacy: .public) skipped=\(refreshResult.skippedCount, privacy: .public)")
        }

        return LaunchMaintenanceResult(
            didRun: true,
            buildIdentifier: buildIdentifier,
            registrationStatus: registrationStatus,
            refreshedDocumentCount: refreshResult.refreshedCount,
            skippedDocumentCount: refreshResult.skippedCount
        )
    }
}
