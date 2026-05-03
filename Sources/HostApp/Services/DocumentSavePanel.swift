import AppKit
import UniformTypeIdentifiers

enum DocumentSavePanel {
    @MainActor
    static func chooseDestinationURL(
        suggestedFilename: String,
        presentingWindow: NSWindow?
    ) async -> URL? {
        let panel = makePanel(suggestedFilename: suggestedFilename)
        guard let presentingWindow else {
            return panel.runModal() == .OK ? panel.url : nil
        }

        return await SavePanelPresenter.chooseURL(panel, presentingWindow: presentingWindow)
    }

    @MainActor
    static func chooseDestinationURL(suggestedFilename: String) -> URL? {
        let panel = makePanel(suggestedFilename: suggestedFilename)
        return panel.runModal() == .OK ? panel.url : nil
    }

    @MainActor
    private static func makePanel(suggestedFilename: String) -> NSSavePanel {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.title = "HWP 문서 저장"
        panel.message = "저장할 위치를 선택하세요."
        panel.nameFieldStringValue = normalizedFilename(suggestedFilename)

        if let hwpType = UTType(filenameExtension: "hwp") {
            panel.allowedContentTypes = [hwpType]
        }

        return panel
    }

    static func write(data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }

    @MainActor
    static func save(data: Data, suggestedFilename: String) throws -> URL? {
        guard let url = chooseDestinationURL(suggestedFilename: suggestedFilename) else {
            return nil
        }

        try write(data: data, to: url)
        return url
    }

    private static func normalizedFilename(_ filename: String) -> String {
        let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "document.hwp"
        }
        if trimmed.lowercased().hasSuffix(".hwp") {
            return trimmed
        }
        return "\(trimmed).hwp"
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
