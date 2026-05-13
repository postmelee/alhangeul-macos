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
    static func runIfNeeded(userDefaults: UserDefaults = .standard) -> LaunchMaintenanceResult {
        let buildIdentifier = BuildInfo.launchMaintenanceBuildIdentifier
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

        let registrationStatus = ExtensionSystemRegistrationRefresher.refreshCurrentBundle()
        let refreshResult = RecentDocumentThumbnailRefresher.refreshRecentDocuments()
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
