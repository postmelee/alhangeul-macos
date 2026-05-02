import Foundation

@MainActor
final class DocumentViewerStore: ObservableObject {
    @Published private(set) var rhwpStudioDocument: RhwpStudioDocumentPayload?
    @Published var filename: String = ""
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var webViewErrorMessage: String?
    @Published var isWebViewLoading = false
    @Published private(set) var documentRevision: Int = 0

    var hasDocument: Bool {
        rhwpStudioDocument != nil
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
            let data = try Data(contentsOf: url)
            try loadDocument(data: data, filename: url.lastPathComponent)
        } catch {
            errorMessage = "문서를 열 수 없습니다: \(error.localizedDescription)"
            rhwpStudioDocument = nil
            filename = ""
        }

        isLoading = false
    }

    func setWebViewLoading(_ isLoading: Bool) {
        isWebViewLoading = isLoading
    }

    func setWebViewError(_ message: String?) {
        webViewErrorMessage = message
    }

    private func loadDocument(data: Data, filename: String) throws {
        guard !data.isEmpty else {
            throw DocumentViewerStoreError.emptyDocument
        }

        self.filename = filename
        documentRevision += 1
        rhwpStudioDocument = RhwpStudioDocumentPayload(
            data: data,
            filename: filename,
            revision: documentRevision
        )
        webViewErrorMessage = nil
        isWebViewLoading = false
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
