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
    @Published var webViewFailure: RhwpStudioWebViewFailure?
    @Published var isWebViewLoading = false
    @Published private(set) var documentRevision: Int = 0
    @Published private(set) var webViewReloadToken: Int = 0

    var hasDocument: Bool {
        rhwpStudioDocument != nil
    }

    var canRevealInFinder: Bool {
        sourceDocument != nil
    }

    var canRunWebViewCommands: Bool {
        hasDocument && !isWebViewLoading && webViewFailure == nil
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
        webViewFailure = nil
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
            errorMessage = Self.openingErrorMessage(for: error)
            clearCurrentDocument()
        }

        isLoading = false
    }

    func loadDroppedDocument(data: Data, filename: String) {
        isLoading = true
        errorMessage = nil
        webViewErrorMessage = nil
        webViewFailure = nil
        isWebViewLoading = false

        do {
            try loadDocument(
                data: data,
                filename: Self.sanitizedFilename(filename),
                sourceDocument: nil
            )
        } catch {
            webViewErrorMessage = "끌어놓은 문서를 열 수 없습니다: \(Self.openingErrorMessage(for: error))"
            clearCurrentDocument()
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
            webViewErrorMessage = "최근 문서를 읽을 수 없습니다. 파일 접근 권한 또는 위치를 확인한 뒤 다시 열어 주세요."
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

    func setWebViewFailure(_ failure: RhwpStudioWebViewFailure?) {
        webViewFailure = failure
        if failure != nil {
            webViewErrorMessage = nil
            isWebViewLoading = false
        }
    }

    func retryWebViewLoad() {
        webViewFailure = nil
        webViewErrorMessage = nil
        isWebViewLoading = false
        webViewReloadToken += 1
    }

    private func loadDocument(
        data: Data,
        filename: String,
        sourceDocument: RecentDocumentItem?
    ) throws {
        try HwpDocumentInputValidator.validateOpeningData(data)

        self.filename = filename
        self.sourceDocument = sourceDocument
        documentRevision += 1
        rhwpStudioDocument = RhwpStudioDocumentPayload(
            data: data,
            filename: filename,
            revision: documentRevision
        )
        webViewErrorMessage = nil
        webViewFailure = nil
        isWebViewLoading = false

        if let sourceDocument {
            recentDocuments = RecentDocumentStore.record(sourceDocument)
        }
    }

    private func clearCurrentDocument() {
        rhwpStudioDocument = nil
        sourceDocument = nil
        filename = ""
        isWebViewLoading = false
        webViewFailure = nil
    }

    private static func sanitizedFilename(_ filename: String) -> String {
        let trimmedFilename = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        let lastPathComponent = URL(fileURLWithPath: trimmedFilename).lastPathComponent
        return lastPathComponent.isEmpty ? "document.hwp" : lastPathComponent
    }

    private static func openingErrorMessage(for error: Error) -> String {
        if let inputError = error as? HwpDocumentInputError {
            return inputError.localizedDescription
        }
        return "문서를 읽을 수 없습니다. 파일 접근 권한 또는 위치를 확인한 뒤 다시 열어 주세요."
    }
}
