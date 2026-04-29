import CoreGraphics
import Foundation

@MainActor
final class DocumentViewerStore: ObservableObject {
    @Published var document: RhwpDocument?
    @Published var filename: String = ""
    @Published var currentPage: Int = 0
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var pageTrees: [Int: RenderNode] = [:]
    @Published var zoomScale: Double = 0.8

    private let maxCachedPageTreeCount = 12
    private let protectedPageWindowRadius = 3
    private var visiblePages: Set<Int> = []
    private var pageAccessOrder: [Int: UInt64] = [:]
    private var nextPageAccessOrder: UInt64 = 0

    let minimumZoomScale = 0.25
    let maximumZoomScale = 3.0

    var pageCount: Int {
        document?.pageCount ?? 0
    }

    var hasDocument: Bool {
        document != nil && pageCount > 0
    }

    func openDocument() {
        guard let url = DocumentOpenPanel.chooseDocumentURL() else {
            return
        }
        loadDocument(from: url)
    }

    func loadDocument(from url: URL) {
        isLoading = true
        errorMessage = nil
        resetPageCache()
        currentPage = 0

        let didStartSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if didStartSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            try loadDocument(data: data, filename: url.lastPathComponent)
        } catch let error as RhwpError {
            errorMessage = error.errorDescription
            document = nil
            filename = ""
        } catch {
            errorMessage = "문서를 열 수 없습니다: \(error.localizedDescription)"
            document = nil
            filename = ""
        }

        isLoading = false
    }

    func pageSize(at page: Int) -> CGSize {
        guard let document else {
            return .zero
        }
        let size = document.pageSize(at: page)
        return CGSize(width: size.width, height: size.height)
    }

    func loadPage(_ page: Int) {
        guard page >= 0, page < pageCount, let document else {
            return
        }
        markPageAccessed(page)

        if pageTrees[page] == nil {
            guard let tree = document.renderPageTree(at: page) else {
                return
            }
            pageTrees[page] = tree
        }

        evictPageTreesIfNeeded(protecting: page)
    }

    func unloadPage(_ page: Int) {
        pageTrees.removeValue(forKey: page)
        pageAccessOrder.removeValue(forKey: page)
        visiblePages.remove(page)
    }

    func setCurrentPage(_ page: Int) {
        guard page >= 0, page < pageCount else {
            return
        }
        currentPage = page
        markPageAccessed(page)
    }

    func markPageVisible(_ page: Int) {
        guard page >= 0, page < pageCount else {
            return
        }
        visiblePages.insert(page)
        markPageAccessed(page)
    }

    func markPageNotVisible(_ page: Int) {
        visiblePages.remove(page)
    }

    func zoomIn() {
        zoomScale = min(maximumZoomScale, (zoomScale * 1.2).rounded(toPlaces: 2))
    }

    func zoomOut() {
        zoomScale = max(minimumZoomScale, (zoomScale / 1.2).rounded(toPlaces: 2))
    }

    func resetZoom() {
        zoomScale = 1.0
    }

    private func loadDocument(data: Data, filename: String) throws {
        guard !data.isEmpty else {
            throw RhwpError.invalidData
        }

        document = try RhwpDocument(data: data, filename: filename)
        self.filename = filename
        currentPage = 0
        zoomScale = 0.8
        preloadInitialPages()
    }

    private func preloadInitialPages() {
        let preloadCount = min(2, pageCount)
        guard preloadCount > 0 else {
            return
        }

        for page in 0..<preloadCount {
            loadPage(page)
        }
    }

    private func resetPageCache() {
        pageTrees.removeAll()
        visiblePages.removeAll()
        pageAccessOrder.removeAll()
        nextPageAccessOrder = 0
    }

    private func markPageAccessed(_ page: Int) {
        guard page >= 0, page < pageCount else {
            return
        }
        nextPageAccessOrder += 1
        pageAccessOrder[page] = nextPageAccessOrder
    }

    private func evictPageTreesIfNeeded(protecting recentPage: Int) {
        guard pageTrees.count > maxCachedPageTreeCount else {
            return
        }

        let protectedPages = protectedPages(including: recentPage)
        let removablePages = pageTrees.keys
            .filter { !protectedPages.contains($0) }
            .sorted {
                (pageAccessOrder[$0] ?? 0) < (pageAccessOrder[$1] ?? 0)
            }

        guard !removablePages.isEmpty else {
            return
        }

        var updatedPageTrees = pageTrees
        for page in removablePages {
            updatedPageTrees.removeValue(forKey: page)
            pageAccessOrder.removeValue(forKey: page)
            if updatedPageTrees.count <= maxCachedPageTreeCount {
                break
            }
        }
        pageTrees = updatedPageTrees
    }

    private func protectedPages(including recentPage: Int) -> Set<Int> {
        var pages = Set<Int>()

        insertInitialPages(into: &pages)
        insertWindow(around: currentPage, into: &pages)
        insertIfValid(recentPage, into: &pages)

        for page in visiblePages {
            insertWindow(around: page, into: &pages)
        }

        return pages
    }

    private func insertInitialPages(into pages: inout Set<Int>) {
        let preloadCount = min(2, pageCount)
        guard preloadCount > 0 else {
            return
        }

        for page in 0..<preloadCount {
            pages.insert(page)
        }
    }

    private func insertWindow(around page: Int, into pages: inout Set<Int>) {
        guard page >= 0, page < pageCount else {
            return
        }

        let lowerBound = max(0, page - protectedPageWindowRadius)
        let upperBound = min(pageCount - 1, page + protectedPageWindowRadius)
        for protectedPage in lowerBound...upperBound {
            pages.insert(protectedPage)
        }
    }

    private func insertIfValid(_ page: Int, into pages: inout Set<Int>) {
        guard page >= 0, page < pageCount else {
            return
        }
        pages.insert(page)
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
