import Foundation

enum DocumentSaveFormat: String, CaseIterable {
    case hwp
    case hwpx

    private static let hwpSignature: [UInt8] = [
        0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1
    ]

    private static let zipSignatures: [[UInt8]] = [
        [0x50, 0x4B, 0x03, 0x04],
        [0x50, 0x4B, 0x05, 0x06],
        [0x50, 0x4B, 0x07, 0x08]
    ]

    init?(filename: String) {
        let fileExtension = (filename as NSString).pathExtension.lowercased()
        self.init(rawValue: fileExtension)
    }

    init?(url: URL) {
        self.init(filename: url.lastPathComponent)
    }

    var fileExtension: String {
        rawValue
    }

    var panelTitle: String {
        switch self {
        case .hwp:
            return "HWP 문서 저장"
        case .hwpx:
            return "HWPX 문서 저장"
        }
    }

    var uniformTypeIdentifier: String {
        "com.postmelee.alhangeul.\(rawValue)"
    }

    var defaultFilename: String {
        "document.\(fileExtension)"
    }

    static func resolve(sourceURL: URL?, filename: String?) -> DocumentSaveFormat {
        if let sourceURL, let format = DocumentSaveFormat(url: sourceURL) {
            return format
        }
        if let filename, let format = DocumentSaveFormat(filename: filename) {
            return format
        }
        return .hwp
    }

    func normalizedFilename(_ filename: String) -> String {
        let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return defaultFilename
        }

        var stem = trimmed
        while DocumentSaveFormat(filename: stem) != nil {
            let nextStem = (stem as NSString).deletingPathExtension
            guard !nextStem.isEmpty, nextStem != stem else {
                break
            }
            stem = nextStem
        }

        return "\(stem).\(fileExtension)"
    }

    func normalizedDestinationURL(_ url: URL) -> URL {
        url.deletingLastPathComponent().appendingPathComponent(
            normalizedFilename(url.lastPathComponent),
            isDirectory: false
        )
    }

    func matchesPayloadSignature(_ data: Data) -> Bool {
        switch self {
        case .hwp:
            return data.starts(with: Self.hwpSignature)
        case .hwpx:
            return Self.zipSignatures.contains { data.starts(with: $0) }
        }
    }
}
