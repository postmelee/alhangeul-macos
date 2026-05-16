import Foundation

@MainActor
enum DocumentOpenRouter {
    private struct WeakStore {
        weak var store: DocumentViewerStore?
    }

    private static var stores: [WeakStore] = []
    private static var pendingURLs: [URL] = []

    static func register(_ store: DocumentViewerStore) {
        cleanupStores()
        guard !stores.contains(where: { $0.store === store }) else {
            return
        }
        stores.append(WeakStore(store: store))
    }

    @discardableResult
    static func openPendingURL(in store: DocumentViewerStore) -> Bool {
        guard !pendingURLs.isEmpty else {
            return false
        }

        let url = pendingURLs.removeFirst()
        store.loadDocument(from: url)

        let deferredURLs = pendingURLs
        pendingURLs = []
        deferredURLs.forEach(requestOpen)
        return true
    }

    static func unregister(_ store: DocumentViewerStore) {
        stores.removeAll { $0.store == nil || $0.store === store }
    }

    static func requestOpen(_ url: URL) {
        cleanupStores()

        let liveStores = stores.compactMap(\.store)
        guard !liveStores.isEmpty else {
            pendingURLs.append(url)
            return
        }

        let hasOpenDocument = liveStores.contains { $0.hasDocument }
        if !hasOpenDocument, let emptyStore = liveStores.first(where: { !$0.hasDocument }) {
            emptyStore.loadDocument(from: url)
            return
        }

        DocumentWindowPresenter.shared.openDocument(url)
    }

    static func shouldCloseRedundantEmptyWindow(for store: DocumentViewerStore) -> Bool {
        cleanupStores()
        guard !store.hasDocument, pendingURLs.isEmpty else {
            return false
        }

        return stores.compactMap(\.store).contains { candidate in
            candidate !== store && candidate.hasDocument
        }
    }

    private static func cleanupStores() {
        stores.removeAll { $0.store == nil }
    }
}
