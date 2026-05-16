import AppKit
import Foundation

struct RecentDocumentItem: Codable, Equatable, Identifiable {
    let url: URL
    let bookmarkData: Data?

    var id: String {
        url.standardizedFileURL.path
    }

    var displayName: String {
        url.lastPathComponent
    }

    var displayPath: String {
        url.deletingLastPathComponent().path
    }

    static func make(for url: URL) -> RecentDocumentItem {
        let bookmarkData = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        return RecentDocumentItem(url: url.standardizedFileURL, bookmarkData: bookmarkData)
    }

    func resolvedURL() throws -> URL {
        guard let bookmarkData else {
            return url
        }

        var isStale = false
        let resolvedURL = try URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        return resolvedURL.standardizedFileURL
    }
}

enum RecentDocumentStore {
    private static let key = "alhangeul.recentDocuments"
    private static let maxCount = 8

    static func load() -> [RecentDocumentItem] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let documents = try? JSONDecoder().decode([RecentDocumentItem].self, from: data)
        else {
            return []
        }
        return documents
    }

    @discardableResult
    static func record(_ document: RecentDocumentItem) -> [RecentDocumentItem] {
        var documents = load().filter { $0.id != document.id }
        documents.insert(document, at: 0)
        documents = Array(documents.prefix(maxCount))
        save(documents)
        NSDocumentController.shared.noteNewRecentDocumentURL(document.url)
        return documents
    }

    static func clear() {
        save([])
        NSDocumentController.shared.clearRecentDocuments(nil)
    }

    private static func save(_ documents: [RecentDocumentItem]) {
        if let data = try? JSONEncoder().encode(documents) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
