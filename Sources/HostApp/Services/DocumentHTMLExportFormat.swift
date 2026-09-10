import Foundation

/// upstream Word 출력은 HTML 기반 .doc이며 binary DOC/DOCX가 아니다.
enum DocumentHTMLExportFormat: String, CaseIterable {
    case doc, html

    var command: String { "file:export-\(rawValue)" }
    var mimeType: String { self == .doc ? "application/msword" : "text/html" }
    var title: String { self == .doc ? "Word 문서(.doc)로 내보내기" : "HTML로 내보내기" }

    func filename(for source: String) -> String {
        guard !source.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { return "새 문서.\(rawValue)" }
        let stem = URL(fileURLWithPath:source).deletingPathExtension().lastPathComponent
        return "\(stem.isEmpty ? "새 문서" : stem).\(rawValue)"
    }

    func validateResponse(mime: String?, filename: String) throws {
        guard mime?.lowercased().split(separator:";").first.map(String.init) == mimeType,
              URL(fileURLWithPath:filename).pathExtension.lowercased() == rawValue
        else { throw DocumentHTMLExportError.invalidDownload }
    }

    func validate(data: Data, destination: URL, source: URL?) throws {
        guard destination.isFileURL, destination.pathExtension.lowercased() == rawValue,
              let html = String(data:data, encoding:.utf8)?.lowercased(),
              html.contains("<html"), html.contains("<body"), html.contains("</html>")
        else { throw DocumentHTMLExportError.invalidDownload }
        if let source {
            let sourcePath = source.standardizedFileURL.resolvingSymlinksInPath().path
            let destinationPath = destination.standardizedFileURL.resolvingSymlinksInPath().path
            guard sourcePath.compare(destinationPath, options:.caseInsensitive) != .orderedSame else {
                throw DocumentHTMLExportError.sourceDestination
            }
            let manager = FileManager.default
            if let a = try? manager.attributesOfItem(atPath:sourcePath),
               let b = try? manager.attributesOfItem(atPath:destinationPath),
               let inodeA = a[.systemFileNumber] as? NSNumber,
               let inodeB = b[.systemFileNumber] as? NSNumber,
               inodeA == inodeB, (a[.systemNumber] as? NSNumber) == (b[.systemNumber] as? NSNumber) {
                throw DocumentHTMLExportError.sourceDestination
            }
        }
    }
}

enum DocumentHTMLExportError: LocalizedError {
    case invalidDownload, sourceDestination, cancelled, timedOut

    var errorDescription: String? {
        switch self {
        case .invalidDownload: "내보낸 파일의 형식 또는 다운로드 요청이 올바르지 않습니다."
        case .sourceDestination: "원본 문서와 다른 위치로 내보내 주세요."
        case .cancelled: "내보내기가 취소되었거나 문서가 변경되었습니다."
        case .timedOut: "내보내기 다운로드 시간이 초과되었습니다. 다시 시도해 주세요."
        }
    }
}
