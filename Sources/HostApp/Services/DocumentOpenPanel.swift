import AppKit
import UniformTypeIdentifiers

enum DocumentOpenPanel {
    @MainActor
    static func chooseDocumentURL() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.resolvesAliases = true
        panel.title = "HWP 문서 열기"
        panel.message = "HWP 또는 HWPX 문서를 선택하세요."
        panel.allowedContentTypes = supportedContentTypes

        return panel.runModal() == .OK ? panel.url : nil
    }

    private static var supportedContentTypes: [UTType] {
        var types: [UTType] = [.data]
        [
            "com.postmelee.alhangeulmac.hwp",
            "com.postmelee.alhangeulmac.hwpx",
            "com.hancom.hwp",
            "com.hancom.hwpx",
            "com.haansoft.hancomofficeviewer.mac.hwp",
            "com.haansoft.hancomofficeviewer.mac.hwpx"
        ].forEach { identifier in
            if let type = UTType(identifier) {
                types.append(type)
            }
        }
        return types
    }
}
