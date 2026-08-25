import Foundation

@MainActor
final class DocumentViewerStore: ObservableObject {
    @Published private(set) var rhwpStudioDocument: RhwpStudioDocumentPayload?
    @Published private(set) var sourceDocument: RecentDocumentItem?
    @Published private(set) var recentDocuments: [RecentDocumentItem] = RecentDocumentStore.load()
    @Published var filename: String = ""
    @Published private var documentOpenRecoveryState = DocumentOpenRecoveryState()
    @Published private(set) var webViewErrorMessage: String?
    @Published var webViewFailure: RhwpStudioWebViewFailure?
    @Published var isWebViewLoading = false
    @Published private(set) var documentRevision: Int = 0
    @Published private(set) var webViewReloadToken: Int = 0
    @Published private(set) var hasUnsavedChanges = false

    private static let webViewErrorAutoDismissDelayNanoseconds: UInt64 = 5_000_000_000

    private let classifyDocumentProtection: @Sendable (Data) -> RhwpDocumentProtection
    private let chooseDocumentURL: @MainActor () -> URL?
    private var webViewErrorDismissTask: Task<Void, Never>?
    private var webViewErrorDismissToken = 0
    private var webViewErrorDedupeKey: String?
    private var documentLoadTask: Task<Void, Never>?

    init(
        classifyDocumentProtection: @escaping @Sendable (Data) -> RhwpDocumentProtection = {
            RhwpDocumentProtection.classify(data: $0)
        },
        chooseDocumentURL: @escaping @MainActor () -> URL? = {
            DocumentOpenPanel.chooseDocumentURL()
        }
    ) {
        self.classifyDocumentProtection = classifyDocumentProtection
        self.chooseDocumentURL = chooseDocumentURL
    }

    var hasDocument: Bool {
        rhwpStudioDocument != nil
    }

    var canRevealInFinder: Bool {
        sourceDocument != nil
    }

    var isLoading: Bool {
        documentOpenRecoveryState.isLoading
    }

    var recoverableDocumentOpenFailure: RecoverableDocumentOpenFailure? {
        documentOpenRecoveryState.failure
    }

    var canRunWebViewCommands: Bool {
        hasDocument && !isLoading && !isWebViewLoading && webViewFailure == nil
    }

    func openDocument() {
        guard let url = chooseDocumentURL() else {
            return
        }
        loadDocument(from: url, source: .filePanel)
    }

    func loadDocument(from url: URL, source: DocumentOpenSource = .externalOpen) {
        let loadID = beginDocumentLoad()
        loadDocument(from: url, source: source, loadID: loadID)
    }

    func loadDroppedDocument(data: Data, filename: String) {
        let loadID = beginDocumentLoad()

        do {
            try startDocumentLoad(
                data: data,
                filename: Self.sanitizedFilename(filename),
                sourceDocument: nil,
                loadID: loadID
            )
        } catch {
            failDocumentLoad(
                loadID: loadID,
                source: .webViewDrop,
                filename: filename,
                error: error
            )
        }
    }

    func openRecentDocument(_ document: RecentDocumentItem) {
        let loadID = beginDocumentLoad()

        do {
            let url = try document.resolvedURL()
            loadDocument(
                from: url,
                source: .recentDocument,
                loadID: loadID
            )
        } catch {
            failDocumentLoad(
                loadID: loadID,
                source: .recentDocument,
                filename: document.displayName,
                error: error
            )
        }
    }

    func dismissRecoverableDocumentOpenFailure() {
        documentOpenRecoveryState.dismissFailure()
    }

    func retryDocumentOpen() {
        _ = documentOpenRecoveryState.beginRetry()
    }

    func handleRecoverableDocumentOpenFailureDismissal() {
        guard documentOpenRecoveryState.consumeRetry() else {
            return
        }
        openDocument()
    }

    private func loadDocument(
        from url: URL,
        source: DocumentOpenSource,
        loadID: Int
    ) {
        let didStartSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if didStartSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let sourceDocument = RecentDocumentItem.make(for: url)
            let data = try Data(contentsOf: url)
            try startDocumentLoad(
                data: data,
                filename: url.lastPathComponent,
                sourceDocument: sourceDocument,
                loadID: loadID
            )
        } catch {
            failDocumentLoad(
                loadID: loadID,
                source: source,
                filename: url.lastPathComponent,
                error: error
            )
        }
    }

    func clearRecentDocuments() {
        RecentDocumentStore.clear()
        recentDocuments = []
    }

    func revealCurrentDocumentInFinder() {
        guard let sourceDocument else {
            presentWebViewError("Finder에서 표시할 원본 문서가 없습니다.")
            return
        }
        DocumentFileActions.revealInFinder(sourceDocument.url)
    }

    func recordSavedDocument(_ savedDocument: RhwpStudioSavedDocument) {
        let url = savedDocument.url
        let sourceDocument = RecentDocumentItem.make(for: url)
        filename = url.lastPathComponent
        self.sourceDocument = sourceDocument
        recentDocuments = RecentDocumentStore.record(sourceDocument)
        if let document = rhwpStudioDocument {
            rhwpStudioDocument = RhwpStudioDocumentPayload(
                data: savedDocument.data,
                filename: url.lastPathComponent,
                revision: document.revision,
                sourceProtection: savedDocument.sourceProtection
            )
        }
        clearUnsavedChanges()
    }

    func markDocumentEdited() {
        guard hasDocument, !hasUnsavedChanges else {
            return
        }
        hasUnsavedChanges = true
    }

    func clearUnsavedChanges() {
        hasUnsavedChanges = false
    }

    func setWebViewLoading(_ isLoading: Bool) {
        isWebViewLoading = isLoading
    }

    func setWebViewError(_ message: String?) {
        if let message {
            presentWebViewError(message)
        } else {
            dismissWebViewError()
        }
    }

    func setWebViewFailure(_ failure: RhwpStudioWebViewFailure?) {
        guard let failure else {
            webViewFailure = nil
            return
        }

        isWebViewLoading = false

        if failure.isFatal {
            webViewFailure = failure
            dismissWebViewError()
        } else {
            webViewFailure = nil
            presentWebViewError(
                failure.message,
                dedupeKey: Self.nonfatalRuntimeDedupeKey(for: failure)
            )
        }
    }

    func retryWebViewLoad() {
        webViewFailure = nil
        dismissWebViewError()
        isWebViewLoading = false
        webViewReloadToken += 1
    }

    func dismissWebViewError() {
        webViewErrorDismissToken += 1
        webViewErrorDismissTask?.cancel()
        webViewErrorDismissTask = nil
        webViewErrorDedupeKey = nil
        webViewErrorMessage = nil
    }

    private func beginDocumentLoad() -> Int {
        documentLoadTask?.cancel()
        documentLoadTask = nil
        let loadID = documentOpenRecoveryState.beginLoad()
        dismissWebViewError()
        isWebViewLoading = false
        return loadID
    }

    private func startDocumentLoad(
        data: Data,
        filename: String,
        sourceDocument: RecentDocumentItem?,
        loadID: Int
    ) throws {
        try HwpDocumentInputValidator.validateOpeningData(data)

        let classifyDocumentProtection = classifyDocumentProtection
        documentLoadTask = Task { [weak self] in
            let protection = await Task.detached(priority: .userInitiated) {
                classifyDocumentProtection(data)
            }.value

            guard let self,
                  !Task.isCancelled,
                  self.documentOpenRecoveryState.isCurrent(loadID: loadID)
            else {
                return
            }

            self.finishDocumentLoad(
                data: data,
                filename: filename,
                sourceDocument: sourceDocument,
                sourceProtection: Self.sourceProtection(from: protection),
                loadID: loadID
            )
        }
    }

    private func finishDocumentLoad(
        data: Data,
        filename: String,
        sourceDocument: RecentDocumentItem?,
        sourceProtection: DocumentSourceProtection,
        loadID: Int
    ) {
        guard documentOpenRecoveryState.completeLoad(loadID: loadID) else {
            return
        }

        self.filename = filename
        self.sourceDocument = sourceDocument
        documentRevision += 1
        hasUnsavedChanges = false
        rhwpStudioDocument = RhwpStudioDocumentPayload(
            data: data,
            filename: filename,
            revision: documentRevision,
            sourceProtection: sourceProtection
        )
        dismissWebViewError()
        webViewFailure = nil
        isWebViewLoading = false
        documentLoadTask = nil

        if let sourceDocument {
            recentDocuments = RecentDocumentStore.record(sourceDocument)
        }
    }

    private func failDocumentLoad(
        loadID: Int,
        source: DocumentOpenSource,
        filename: String?,
        error: Error
    ) {
        let failure = RecoverableDocumentOpenFailure(
            source: source,
            filename: filename,
            reason: Self.openingErrorMessage(for: error)
        )

        guard documentOpenRecoveryState.failLoad(
            loadID: loadID,
            failure: failure
        ) else {
            return
        }

        documentLoadTask = nil
    }

    private func presentWebViewError(_ message: String, dedupeKey: String? = nil) {
        if let dedupeKey,
           webViewErrorDedupeKey == dedupeKey,
           webViewErrorMessage != nil {
            return
        }

        webViewErrorDismissToken += 1
        let token = webViewErrorDismissToken
        let delay = Self.webViewErrorAutoDismissDelayNanoseconds

        webViewErrorDismissTask?.cancel()
        webViewErrorMessage = message
        webViewErrorDedupeKey = dedupeKey
        webViewErrorDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                guard let self, self.webViewErrorDismissToken == token else {
                    return
                }

                self.webViewErrorDismissTask = nil
                self.webViewErrorDedupeKey = nil
                self.webViewErrorMessage = nil
            }
        }
    }

    private static func nonfatalRuntimeDedupeKey(for failure: RhwpStudioWebViewFailure) -> String? {
        guard !failure.isFatal, failure.category == .runtime else {
            return nil
        }
        return "\(failure.category.rawValue)\n\(failure.diagnosticDetail)"
    }

    private static func sanitizedFilename(_ filename: String) -> String {
        let trimmedFilename = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        let lastPathComponent = URL(fileURLWithPath: trimmedFilename).lastPathComponent
        return lastPathComponent.isEmpty ? "document.hwp" : lastPathComponent
    }

    private static func sourceProtection(
        from protection: RhwpDocumentProtection
    ) -> DocumentSourceProtection {
        switch protection {
        case .plain:
            return .plain
        case .passwordProtected:
            return .passwordProtected
        case .unsupportedProtection:
            return .unsupportedProtection
        case .invalidOrUnknown:
            return .invalidOrUnknown
        }
    }

    private static func openingErrorMessage(for error: Error) -> String {
        if let inputError = error as? HwpDocumentInputError {
            return inputError.localizedDescription
        }
        return "문서를 읽을 수 없습니다. 파일 접근 권한 또는 위치를 확인한 뒤 다시 열어 주세요."
    }
}
