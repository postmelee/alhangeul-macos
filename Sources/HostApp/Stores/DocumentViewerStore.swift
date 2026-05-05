import Foundation

@MainActor
final class DocumentViewerStore: ObservableObject {
    @Published private(set) var rhwpStudioDocument: RhwpStudioDocumentPayload?
    @Published private(set) var sourceDocument: RecentDocumentItem?
    @Published private(set) var recentDocuments: [RecentDocumentItem] = RecentDocumentStore.load()
    @Published var filename: String = ""
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var webViewErrorMessage: String?
    @Published var isWebViewLoading = false
    @Published private(set) var documentRevision: Int = 0

    var hasDocument: Bool {
        rhwpStudioDocument != nil
    }

    var canRevealInFinder: Bool {
        sourceDocument != nil
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
        webViewErrorMessage = nil
        isWebViewLoading = false

        let didStartSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if didStartSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let sourceDocument = RecentDocumentItem.make(for: url)
            let data = try Data(contentsOf: url)
            try loadDocument(
                data: data,
                filename: url.lastPathComponent,
                sourceDocument: sourceDocument
            )
        } catch {
            errorMessage = "문서를 열 수 없습니다: \(error.localizedDescription)"
            rhwpStudioDocument = nil
            sourceDocument = nil
            filename = ""
        }

        isLoading = false
    }

    func loadDroppedDocument(data: Data, filename: String) {
        isLoading = true
        errorMessage = nil
        webViewErrorMessage = nil
        isWebViewLoading = false

        do {
            try loadDocument(
                data: data,
                filename: Self.sanitizedFilename(filename),
                sourceDocument: nil
            )
        } catch {
            webViewErrorMessage = "끌어놓은 문서를 열 수 없습니다: \(error.localizedDescription)"
            rhwpStudioDocument = nil
            sourceDocument = nil
            self.filename = ""
        }

        isLoading = false
    }

    func openRecentDocument(_ document: RecentDocumentItem) {
        do {
            let url = try document.resolvedURL()
            let didStartSecurityScope = url.startAccessingSecurityScopedResource()
            defer {
                if didStartSecurityScope {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            loadDocument(from: url)
        } catch {
            webViewErrorMessage = "최근 문서를 열 수 없습니다: \(error.localizedDescription)"
        }
    }

    func clearRecentDocuments() {
        RecentDocumentStore.clear()
        recentDocuments = []
    }

    func revealCurrentDocumentInFinder() {
        guard let sourceDocument else {
            webViewErrorMessage = "Finder에서 표시할 원본 문서가 없습니다."
            return
        }
        DocumentFileActions.revealInFinder(sourceDocument.url)
    }

    func recordSavedDocument(at url: URL) {
        let sourceDocument = RecentDocumentItem.make(for: url)
        filename = url.lastPathComponent
        self.sourceDocument = sourceDocument
        recentDocuments = RecentDocumentStore.record(sourceDocument)
    }

    func setWebViewLoading(_ isLoading: Bool) {
        isWebViewLoading = isLoading
    }

    func setWebViewError(_ message: String?) {
        webViewErrorMessage = message
    }

    private func loadDocument(
        data: Data,
        filename: String,
        sourceDocument: RecentDocumentItem?
    ) throws {
        guard !data.isEmpty else {
            throw DocumentViewerStoreError.emptyDocument
        }

        self.filename = filename
        self.sourceDocument = sourceDocument
        documentRevision += 1
        rhwpStudioDocument = RhwpStudioDocumentPayload(
            data: data,
            filename: filename,
            revision: documentRevision
        )
        webViewErrorMessage = nil
        isWebViewLoading = false

        if let sourceDocument {
            recentDocuments = RecentDocumentStore.record(sourceDocument)
        }
    }

    private static func sanitizedFilename(_ filename: String) -> String {
        let trimmedFilename = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        let lastPathComponent = URL(fileURLWithPath: trimmedFilename).lastPathComponent
        return lastPathComponent.isEmpty ? "document.hwp" : lastPathComponent
    }
}

private enum DocumentViewerStoreError: LocalizedError {
    case emptyDocument

    var errorDescription: String? {
        switch self {
        case .emptyDocument:
            return "비어 있는 문서는 열 수 없습니다."
        }
    }
}
