import AppKit
import Foundation
import OSLog

struct RecentDocumentThumbnailRefreshResult: Equatable {
    let refreshedCount: Int
    let skippedCount: Int
}

enum RecentDocumentThumbnailRefresher {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.postmelee.alhangeul",
        category: "RecentDocumentThumbnailRefresh"
    )

    @MainActor
    static func refreshRecentDocuments() -> RecentDocumentThumbnailRefreshResult {
        let candidates = recentDocumentCandidates(
            storedDocuments: RecentDocumentStore.load(),
            documentControllerURLs: NSDocumentController.shared.recentDocumentURLs
        )

        var refreshedCount = 0
        var skippedCount = candidates.skippedCount

        for url in candidates.urls {
            if refreshThumbnailCandidate(url) {
                refreshedCount += 1
            } else {
                skippedCount += 1
            }
        }

        logger.debug("Recent thumbnail refresh completed refreshed=\(refreshedCount, privacy: .public) skipped=\(skippedCount, privacy: .public)")
        return RecentDocumentThumbnailRefreshResult(
            refreshedCount: refreshedCount,
            skippedCount: skippedCount
        )
    }

    static func isSupportedDocumentURL(_ url: URL) -> Bool {
        guard url.isFileURL else {
            return false
        }

        switch url.pathExtension.lowercased() {
        case "hwp", "hwpx":
            return true
        default:
            return false
        }
    }

    private static func recentDocumentCandidates(
        storedDocuments: [RecentDocumentItem],
        documentControllerURLs: [URL]
    ) -> (urls: [URL], skippedCount: Int) {
        var urls: [URL] = []
        var seenPaths = Set<String>()
        var skippedCount = 0

        func append(_ url: URL) {
            let standardizedURL = url.standardizedFileURL
            guard isSupportedDocumentURL(standardizedURL) else {
                return
            }

            let path = standardizedURL.path
            guard seenPaths.insert(path).inserted else {
                return
            }

            urls.append(standardizedURL)
        }

        for document in storedDocuments {
            do {
                append(try document.resolvedURL())
            } catch {
                skippedCount += 1
                logger.warning("Skipping unresolved recent document file=\(document.displayName, privacy: .public)")
            }
        }

        documentControllerURLs.forEach(append)
        return (urls, skippedCount)
    }

    private static func refreshThumbnailCandidate(_ url: URL) -> Bool {
        guard isSupportedDocumentURL(url) else {
            return false
        }

        let didStartSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if didStartSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            logger.warning("Skipping missing recent document file=\(url.lastPathComponent, privacy: .public)")
            return false
        }

        NSWorkspace.shared.noteFileSystemChanged(url.path)
        logger.debug("Noted recent document for thumbnail refresh file=\(url.lastPathComponent, privacy: .public)")
        return true
    }
}
