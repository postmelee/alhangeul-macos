import AppKit
import UniformTypeIdentifiers

enum DocumentSavePanel {
    @MainActor
    static func chooseDestinationURL(
        format: DocumentSaveFormat,
        suggestedFilename: String,
        presentingWindow: NSWindow?
    ) async -> URL? {
        let panel = makePanel(format: format, suggestedFilename: suggestedFilename)
        guard let presentingWindow else {
            guard panel.runModal() == .OK, let url = panel.url else {
                return nil
            }
            return format.normalizedDestinationURL(url)
        }

        return await SavePanelPresenter.chooseURL(panel, presentingWindow: presentingWindow)
            .map(format.normalizedDestinationURL)
    }

    @MainActor
    static func chooseDestinationURL(
        format: DocumentSaveFormat,
        suggestedFilename: String
    ) -> URL? {
        let panel = makePanel(format: format, suggestedFilename: suggestedFilename)
        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }
        return format.normalizedDestinationURL(url)
    }

    @MainActor
    private static func makePanel(
        format: DocumentSaveFormat,
        suggestedFilename: String
    ) -> NSSavePanel {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.allowsOtherFileTypes = false
        panel.isExtensionHidden = false
        panel.title = format.panelTitle
        panel.message = "저장할 위치를 선택하세요."
        panel.nameFieldStringValue = format.normalizedFilename(suggestedFilename)

        if let documentType = UTType(format.uniformTypeIdentifier) {
            panel.allowedContentTypes = [documentType]
        } else if let documentType = UTType(filenameExtension: format.fileExtension) {
            panel.allowedContentTypes = [documentType]
        }

        return panel
    }

    static func write(data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }

    @MainActor
    static func save(
        data: Data,
        format: DocumentSaveFormat,
        suggestedFilename: String
    ) throws -> URL? {
        guard let url = chooseDestinationURL(
            format: format,
            suggestedFilename: suggestedFilename
        ) else {
            return nil
        }

        try write(data: data, to: url)
        return url
    }
}

@MainActor
enum SavePanelPresenter {
    private static let visibilityCheckNanoseconds: UInt64 = 1_500_000_000

    static func chooseURL(_ panel: NSSavePanel, presentingWindow: NSWindow) async -> URL? {
        await withCheckedContinuation { continuation in
            let state = SavePanelPresentationState(continuation: continuation)

            panel.beginSheetModal(for: presentingWindow) { response in
                state.resume(returning: response == .OK ? panel.url : nil)
            }

            Task { @MainActor [weak panel] in
                try? await Task.sleep(nanoseconds: Self.visibilityCheckNanoseconds)
                guard let panel, !panel.isVisible else {
                    return
                }
                state.resume(returning: nil)
            }
        }
    }
}

@MainActor
private final class SavePanelPresentationState {
    private var continuation: CheckedContinuation<URL?, Never>?

    init(continuation: CheckedContinuation<URL?, Never>) {
        self.continuation = continuation
    }

    func resume(returning url: URL?) {
        guard let continuation else {
            return
        }

        self.continuation = nil
        continuation.resume(returning: url)
    }
}
