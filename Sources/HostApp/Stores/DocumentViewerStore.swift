import AppKit
import Foundation

@MainActor
final class DocumentViewerStore: ObservableObject {
    @Published private(set) var rhwpStudioDocument: RhwpStudioDocumentPayload?
    @Published private(set) var sourceDocument: RecentDocumentItem?
    @Published private(set) var recentDocuments: [RecentDocumentItem] = RecentDocumentStore.load()
    @Published var filename: String = ""
    @Published private var documentOpenRecoveryState = DocumentOpenRecoveryState()
    @Published private(set) var webViewErrorMessage: String?
    @Published private(set) var webViewFailure: RhwpStudioWebViewFailure?
    @Published var isWebViewLoading = false
    @Published private(set) var documentRevision: Int = 0
    @Published private(set) var webViewReloadToken: Int = 0
    @Published private(set) var webViewLoadID: Int = 0
    @Published private(set) var editorSession: RhwpStudioEditorSession?
    @Published private(set) var hasUnsavedChanges = false
    private(set) var suspendedSnapshot: RhwpStudioEditorSnapshot?
    @Published private(set) var commandFailurePresentation = RhwpStudioCommandFailurePresentation()

    @Published private(set) var lastEditorImage: NSImage?
    @Published private(set) var isRecoveryExporting = false
    @Published private(set) var isConfirmingRecovery = false
    @Published private(set) var recoveryMessage: String?
    @Published private(set) var recoveryErrorDetail: String?
    let recoveryOwner = UUID()
    let recoveryCopies: DocumentRecoveryCopies
    weak var documentWindow: NSWindow?
    private var clearRecoveryOnReady = false
    var confirmRecoveryTransition: (String, NSWindow?) async -> Bool = { action, window in
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = action
        alert.informativeText = "저장되지 않은 변경사항이 사라질 수 있습니다."
        alert.addButton(withTitle: "계속")
        alert.addButton(withTitle: "취소")
        if let window {
            return await withCheckedContinuation { done in
                alert.beginSheetModal(for: window) { done.resume(returning: $0 == .alertFirstButtonReturn) }
            }
        }
        return alert.runModal() == .alertFirstButtonReturn
    }
    var chooseRecoveryDestination: (DocumentSaveFormat, String, NSWindow?) async -> URL? = {
        await DocumentSavePanel.chooseDestinationURL(format: $0, suggestedFilename: $1, presentingWindow: $2)
    }
    var writeRecoveryCopy: (DocumentRecoveryCopies.Copy, URL, URL?) throws -> Void = {
        try DocumentRecoveryExport.write($0, to: $1, currentSource: $2)
    }

    private static let webViewErrorAutoDismissDelayNanoseconds: UInt64 = 5_000_000_000

    private let classifyDocumentProtection: @Sendable (Data) -> RhwpDocumentProtection
    private var webViewErrorDismissTask: Task<Void, Never>?
    private var webViewErrorDismissToken = 0
    private var webViewErrorDedupeKey: String?
    private var documentLoadTask: Task<Void, Never>?

    init(
        recoveryCopies: DocumentRecoveryCopies? = nil,
        classifyDocumentProtection: @escaping @Sendable (Data) -> RhwpDocumentProtection = {
            RhwpDocumentProtection.classify(data: $0)
        }
    ) {
        self.recoveryCopies = recoveryCopies ?? .shared
        self.classifyDocumentProtection = classifyDocumentProtection
    }

    deinit {
        webViewErrorDismissTask?.cancel()
        documentLoadTask?.cancel()
        let pool = recoveryCopies, owner = recoveryOwner
        Task { @MainActor in pool.remove(owner: owner) }
    }

    var hasDocument: Bool {
        editorSession?.snapshot.ready == true
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
        guard !isRecoveryExporting, !isConfirmingRecovery else { return }
        guard let url = DocumentOpenPanel.chooseDocumentURL() else {
            return
        }
        loadDocument(from: url, source: .filePanel)
    }

    func loadDocument(from url: URL, source: DocumentOpenSource = .externalOpen) {
        Task { @MainActor in
            guard await permitRecoveryTransition("다른 문서를 여시겠습니까?") else { return }
            let loadID = beginDocumentLoad()
            loadDocument(from: url, source: source, loadID: loadID)
        }
    }

    func loadDroppedDocument(data: Data, filename: String) {
        guard webViewFailure == nil, !isConfirmingRecovery, !isRecoveryExporting else { return }
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
        do { loadDocument(from: try document.resolvedURL(), source: .recentDocument) }
        catch {
            let loadID = beginDocumentLoad()
            failDocumentLoad(loadID: loadID, source: .recentDocument, filename: document.displayName, error: error)
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
        guard webViewFailure == nil, let current = editorSession,
              savedDocument.session.snapshot.loadID == webViewLoadID,
              savedDocument.session.snapshot.documentEpoch == current.snapshot.documentEpoch
        else { return }
        let snapshot = current.snapshot.sequence > savedDocument.session.snapshot.sequence
            ? current.snapshot : savedDocument.session.snapshot
        editorSession = RhwpStudioEditorSession(snapshot:snapshot, sourceBinding:.nativeLoad)
        let url = savedDocument.url
        let source = RecentDocumentItem.make(for:url)
        filename = url.lastPathComponent
        sourceDocument = source
        recentDocuments = RecentDocumentStore.record(source)
        rhwpStudioDocument = RhwpStudioDocumentPayload(
            data:savedDocument.data, filename:filename,
            revision:rhwpStudioDocument?.revision ?? documentRevision,
            sourceProtection:savedDocument.sourceProtection
        )
        hasUnsavedChanges = snapshot.dirty
        if savedDocument.recoveryEligible {
            _ = recoveryCopies.admit(owner: recoveryOwner, data: savedDocument.data,
                format: savedDocument.format, sourceURL: url, sourceProtection: .plain,
                conversion: .none, parserValidated: true, sessionIsCurrent: true,
                savedAt: savedDocument.savedAt, loadID: snapshot.loadID, epoch: snapshot.documentEpoch,
                revision: savedDocument.session.snapshot.changeSeq)
        }
    }

    func updateEditorSession(_ reported: RhwpStudioEditorSession) {
        guard webViewFailure == nil,
              let session = RhwpStudioEditorSession.accepting(
                reported.snapshot, after: editorSession, loadID: webViewLoadID,
                hasNativeDocument: rhwpStudioDocument != nil
              )
        else { return }
        let hadSession = editorSession != nil
        let isReplacement = editorSession?.snapshot.documentEpoch != session.snapshot.documentEpoch
        if (hadSession && isReplacement) || clearRecoveryOnReady {
            recoveryCopies.remove(owner: recoveryOwner)
        }
        clearRecoveryOnReady = false
        suspendedSnapshot = nil
        lastEditorImage = nil
        editorSession = session
        if isReplacement { commandFailurePresentation.clear() }
        hasUnsavedChanges = session.snapshot.dirty
        if session.sourceBinding != .nativeLoad {
            rhwpStudioDocument = nil
            sourceDocument = nil
            if isReplacement {
                filename = "새 문서.\(session.snapshot.format)"
            }
        }
    }

    func clearUnsavedChanges() {
        hasUnsavedChanges = false
        recoveryCopies.remove(owner: recoveryOwner)
    }

    func releaseRecoveryResources() {
        recoveryCopies.remove(owner: recoveryOwner)
        suspendedSnapshot = nil
        lastEditorImage = nil
    }

    func preserveEditorImage(_ image: NSImage?) { lastEditorImage = image }
    var previousSave: DocumentRecoveryCopies.Copy? { recoveryCopies.copy(for: recoveryOwner) }
    var recoveryDescription: String {
        if let copy = previousSave {
            return "이전 저장본: \(copy.savedAt.formatted(date: .omitted, time: .standard)). 이후의 미저장 편집은 포함되지 않습니다."
        }
        if rhwpStudioDocument?.sourceProtection != .plain, rhwpStudioDocument != nil {
            return "보호 상태를 유지할 수 없어 자동 복구본을 보관하지 않았습니다. 미저장 편집 복구본이 없습니다."
        }
        return "사용 가능한 이전 저장본이 없습니다. 미저장 편집은 복구할 수 없습니다. 이전 저장본은 정상 저장 후 최대 30분 동안만 보관합니다."
    }

    @discardableResult
    func exportPreviousSave() async -> Bool {
        guard webViewFailure != nil, !isRecoveryExporting, !isConfirmingRecovery else { return false }
        guard let lease = recoveryCopies.acquire(for: recoveryOwner) else {
            recoveryMessage = "보관 기간이 지났거나 사용 가능한 이전 저장본이 없습니다."
            return false
        }
        isRecoveryExporting = true
        recoveryMessage = nil
        recoveryErrorDetail = nil
        defer { recoveryCopies.release(lease); isRecoveryExporting = false }
        let loadID = webViewLoadID
        let stem = (lease.copy.sourceURL.lastPathComponent as NSString).deletingPathExtension
        guard let url = await chooseRecoveryDestination(lease.copy.format,
            "\(stem) (이전 저장본).\(lease.copy.format.rawValue)", documentWindow) else { return false }
        guard webViewFailure != nil, webViewLoadID == loadID else { return false }
        do {
            try writeRecoveryCopy(lease.copy, url, sourceDocument?.url)
            recoveryMessage = "저장본을 새 파일로 복사했습니다."
            return true
        } catch {
            recoveryMessage = "저장본을 복사하지 못했습니다. 다시 시도해 주세요."
            recoveryErrorDetail = error.localizedDescription
            return false
        }
    }

    private func permitRecoveryTransition(_ action: String) async -> Bool {
        guard webViewFailure != nil else { return !isConfirmingRecovery && !isRecoveryExporting }
        guard !isConfirmingRecovery, !isRecoveryExporting else { return false }
        isConfirmingRecovery = true
        let loadID = webViewLoadID
        let permitted = await confirmRecoveryTransition(action, documentWindow)
        isConfirmingRecovery = false
        return permitted && webViewFailure != nil && webViewLoadID == loadID
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
        // 늦은 비치명적/해제 알림으로 fatal 상태를 풀지 않는다. 재시작/새 load만 허용한다.
        guard let failure, webViewFailure == nil else { return }

        isWebViewLoading = false

        if failure.isFatal {
            if let snapshot = editorSession?.snapshot { suspendedSnapshot = snapshot }
            editorSession = nil
            commandFailurePresentation.clear()
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

    func presentCommandFailure(_ failure: RhwpStudioCommandFailure) {
        guard failure.isRecovered, webViewFailure == nil, hasDocument else { return }
        dismissWebViewError()
        commandFailurePresentation.present(failure)
    }

    func dismissCommandFailure() { commandFailurePresentation.dismiss() }
    func showCommandFailure() { commandFailurePresentation.show() }

    func retryWebViewLoad() {
        Task { @MainActor in
            guard webViewFailure != nil,
                  await permitRecoveryTransition(rhwpStudioDocument == nil ? "편집기를 다시 시작하시겠습니까?" : "이전 원본을 다시 여시겠습니까?") else { return }
            commandFailurePresentation.clear()
            webViewFailure = nil
            recoveryMessage = nil
            recoveryErrorDetail = nil
            dismissWebViewError()
            isWebViewLoading = false
            webViewReloadToken += 1
            webViewLoadID += 1
            editorSession = nil
        }
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

        clearRecoveryOnReady = self.sourceDocument?.url != sourceDocument?.url || sourceDocument == nil
        self.filename = filename
        self.sourceDocument = sourceDocument
        documentRevision += 1
        webViewLoadID += 1
        editorSession = nil
        commandFailurePresentation.clear()
        if webViewFailure == nil { hasUnsavedChanges = false }
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
        // 새 저장/출력 오류가 이전 명령 알림 뒤에 가려지지 않게 한다. 진단은 보존한다.
        commandFailurePresentation.dismiss()
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
