import AppKit
import UniformTypeIdentifiers

enum DocumentPDFExportPanel {
    @MainActor
    static func chooseDestinationURL(suggestedFilename: String) -> URL? {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.title = "PDF로 내보내기"
        panel.message = "PDF를 저장할 위치를 선택하세요."
        panel.nameFieldStringValue = normalizedFilename(suggestedFilename)
        panel.allowedContentTypes = [.pdf]
        return panel.runModal() == .OK ? panel.url : nil
    }

    private static func normalizedFilename(_ filename: String) -> String {
        let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "document.pdf"
        }

        let url = URL(fileURLWithPath: trimmed)
        let baseName = url.deletingPathExtension().lastPathComponent
        if baseName.isEmpty {
            return "document.pdf"
        }
        return "\(baseName).pdf"
    }
}
