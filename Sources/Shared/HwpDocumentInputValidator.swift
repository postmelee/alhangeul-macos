import Foundation

enum HwpDocumentInputError: LocalizedError, Equatable {
    case emptyDocument
    case unsupportedOrCorrupt

    var errorDescription: String? {
        switch self {
        case .emptyDocument:
            return "비어 있는 문서는 열 수 없습니다."
        case .unsupportedOrCorrupt:
            return "이 파일은 HWP/HWPX 형식이 아니거나 손상되었습니다."
        }
    }
}

enum HwpDocumentInputValidator {
    private static let hwpMagic: [UInt8] = [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]
    private static let hwpxMagics: [[UInt8]] = [
        [0x50, 0x4B, 0x03, 0x04],
        [0x50, 0x4B, 0x05, 0x06],
        [0x50, 0x4B, 0x07, 0x08]
    ]

    static func validateOpeningData(_ data: Data) throws {
        guard !data.isEmpty else {
            throw HwpDocumentInputError.emptyDocument
        }
        guard isSupportedDocumentSignature(data) else {
            throw HwpDocumentInputError.unsupportedOrCorrupt
        }
    }

    static func isSupportedDocumentSignature(_ data: Data) -> Bool {
        data.starts(with: hwpMagic) || hwpxMagics.contains { data.starts(with: $0) }
    }
}
