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

enum HwpDocumentFallbackReason: Equatable {
    case fileTooLarge
    case emptyOrInvalid
    case unsupportedOrCorrupt
    case renderUnavailable
    case encodingFailed
    case fileAccessFailed
}

enum HwpDocumentFallbackClassifier {
    static func reason(for error: Error) -> HwpDocumentFallbackReason? {
        if let inputError = error as? HwpDocumentInputError {
            switch inputError {
            case .emptyDocument:
                return .emptyOrInvalid
            case .unsupportedOrCorrupt:
                return .unsupportedOrCorrupt
            }
        }

        if let renderError = error as? HwpRenderError {
            switch renderError {
            case .fileTooLarge:
                return .fileTooLarge
            case .emptyDocument:
                return .emptyOrInvalid
            case .pageOutOfRange, .renderTreeUnavailable, .invalidPageSize:
                return .unsupportedOrCorrupt
            case .bitmapContextUnavailable, .imageUnavailable:
                return .renderUnavailable
            case .pngEncodingFailed, .pdfEncodingFailed:
                return .encodingFailed
            }
        }

        if let rhwpError = error as? RhwpError {
            switch rhwpError {
            case .invalidData:
                return .emptyOrInvalid
            case .parseFailure:
                return .unsupportedOrCorrupt
            case .fileReadFailure, .accessDenied:
                return .fileAccessFailed
            }
        }

        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain, (256...264).contains(nsError.code) {
            return .fileAccessFailed
        }
        if nsError.domain == NSPOSIXErrorDomain {
            return .fileAccessFailed
        }

        return nil
    }

    static func quickLookMessage(for reason: HwpDocumentFallbackReason) -> String {
        switch reason {
        case .fileTooLarge:
            return "이 파일은 50 MB보다 커서 미리보기를 만들지 않습니다."
        case .emptyOrInvalid, .unsupportedOrCorrupt:
            return "이 파일은 HWP/HWPX 형식이 아니거나 손상되어 미리보기를 만들 수 없습니다."
        case .renderUnavailable, .encodingFailed:
            return "이 문서의 미리보기를 만들 수 없습니다. 알한글 앱에서 열어 확인해 주세요."
        case .fileAccessFailed:
            return "문서를 읽을 수 없습니다. 파일 접근 권한 또는 위치를 확인한 뒤 다시 시도해 주세요."
        }
    }

    static func shouldUseThumbnailFallback(for error: Error) -> Bool {
        reason(for: error) != nil
    }
}
