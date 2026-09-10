import AppKit
import UniformTypeIdentifiers

enum DocumentHTMLExportPanel {
    @MainActor
    static func chooseDestinationURL(
        format: DocumentHTMLExportFormat, suggestedFilename: String, presentingWindow: NSWindow?
    ) async -> URL? {
        let panel = NSSavePanel()
        panel.title = format.title
        panel.message = "내보낼 파일을 저장할 위치를 선택하세요."
        panel.nameFieldStringValue = format.filename(for:suggestedFilename)
        panel.canCreateDirectories = true
        panel.allowsOtherFileTypes = false
        panel.isExtensionHidden = false
        if let type = UTType(filenameExtension:format.rawValue) { panel.allowedContentTypes = [type] }
        let url: URL?
        if let presentingWindow {
            url = await SavePanelPresenter.chooseURL(panel, presentingWindow:presentingWindow)
        } else {
            url = panel.runModal() == .OK ? panel.url : nil
        }
        return url.map { $0.deletingPathExtension().appendingPathExtension(format.rawValue) }
    }
}
