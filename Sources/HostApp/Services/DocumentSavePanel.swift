import AppKit
import UniformTypeIdentifiers

enum DocumentSavePanel {
    @MainActor
    static func save(data: Data, suggestedFilename: String) throws -> URL? {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.title = "HWP 문서 저장"
        panel.message = "저장할 위치를 선택하세요."
        panel.nameFieldStringValue = normalizedFilename(suggestedFilename)

        if let hwpType = UTType(filenameExtension: "hwp") {
            panel.allowedContentTypes = [hwpType]
        }

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }

        try data.write(to: url, options: .atomic)
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
