import AppKit
import Foundation

enum DocumentFileActions {
    @MainActor
    static func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @MainActor
    static func share(data: Data, filename: String) throws {
        let fileURL = try prepareShareFile(data: data, filename: filename)
        try showSharePicker(fileURL: fileURL)
    }

    static func prepareShareFile(data: Data, filename: String) throws -> URL {
        try writeTemporaryShareFile(data: data, filename: filename)
    }

    @MainActor
    static func showSharePicker(fileURL: URL) throws {
        if let anchorView = SharePresentationAnchor.presentationView {
            let picker = NSSharingServicePicker(items: [fileURL])
            picker.show(
                relativeTo: anchorView.bounds,
                of: anchorView,
                preferredEdge: .minY
            )
            return
        }

        guard let contentView = NSApp.keyWindow?.contentView else {
            throw DocumentFileActionError.missingWindow
        }

        let picker = NSSharingServicePicker(items: [fileURL])
        let anchor = NSRect(
            x: contentView.bounds.maxX - 44,
            y: contentView.bounds.maxY - 44,
            width: 1,
            height: 1
        )
        picker.show(relativeTo: anchor, of: contentView, preferredEdge: .minY)
    }

    private static func writeTemporaryShareFile(data: Data, filename: String) throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AlhangeulMacShare", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let fileURL = directoryURL.appendingPathComponent(sanitizedFilename(filename))
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    private static func sanitizedFilename(_ filename: String) -> String {
        let lastPathComponent = URL(fileURLWithPath: filename).lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return lastPathComponent.isEmpty ? "document.hwp" : lastPathComponent
    }
}

private enum DocumentFileActionError: LocalizedError {
    case missingWindow

    var errorDescription: String? {
        switch self {
        case .missingWindow:
            return "공유 메뉴를 표시할 창을 찾을 수 없습니다."
        }
    }
}
