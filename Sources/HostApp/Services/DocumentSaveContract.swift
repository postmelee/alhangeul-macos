import Foundation

enum DocumentSourceProtection: Equatable {
    case plain
    case passwordProtected
    case unsupportedProtection
    case invalidOrUnknown

    var requiresPlainCopyWarning: Bool {
        self != .plain
    }
}

enum DocumentSaveOutputProtectionIntent: Equatable {
    case preserveSourceProtection
    case plainCopy
}

enum DocumentSaveProtectionPolicyError: Error, Equatable, LocalizedError {
    case documentChanged
    case protectedSourceRequiresPlainCopy(DocumentSourceProtection)
    case plainSourceRequiresPreserveIntent
    case plainCopyMustUseDifferentDestination

    var errorDescription: String? {
        switch self {
        case .documentChanged:
            return "저장 요청 뒤 문서 또는 보호 상태가 변경되었습니다."
        case .protectedSourceRequiresPlainCopy:
            return "보호된 문서는 현재 원본 보호를 유지한 채 저장할 수 없습니다."
        case .plainSourceRequiresPreserveIntent:
            return "평문 문서의 저장 보호 의도가 올바르지 않습니다."
        case .plainCopyMustUseDifferentDestination:
            return "보호를 해제한 복사본은 원본과 다른 위치에 저장해야 합니다."
        }
    }
}

enum DocumentSaveProtectionPolicy {
    static func validateCurrentDocument(
        requestRevision: Int,
        requestProtection: DocumentSourceProtection,
        currentRevision: Int?,
        currentProtection: DocumentSourceProtection?
    ) throws {
        guard currentRevision == requestRevision,
              currentProtection == requestProtection
        else {
            throw DocumentSaveProtectionPolicyError.documentChanged
        }
    }

    static func allowsInPlaceSave(_ sourceProtection: DocumentSourceProtection) -> Bool {
        sourceProtection == .plain
    }

    static func outputIntent(
        for sourceProtection: DocumentSourceProtection
    ) -> DocumentSaveOutputProtectionIntent {
        sourceProtection == .plain ? .preserveSourceProtection : .plainCopy
    }

    static func resultingProtection(
        sourceProtection: DocumentSourceProtection,
        for outputIntent: DocumentSaveOutputProtectionIntent
    ) -> DocumentSourceProtection {
        switch outputIntent {
        case .preserveSourceProtection:
            return sourceProtection
        case .plainCopy:
            return .plain
        }
    }

    static func validateRequest(
        sourceProtection: DocumentSourceProtection,
        outputIntent: DocumentSaveOutputProtectionIntent,
        sourceURL: URL?,
        destinationURL: URL
    ) throws {
        switch (sourceProtection, outputIntent) {
        case (.plain, .preserveSourceProtection):
            return
        case (.plain, .plainCopy):
            throw DocumentSaveProtectionPolicyError.plainSourceRequiresPreserveIntent
        case (_, .preserveSourceProtection):
            throw DocumentSaveProtectionPolicyError.protectedSourceRequiresPlainCopy(
                sourceProtection
            )
        case (_, .plainCopy):
            guard let sourceURL else {
                return
            }
            guard !sameFile(sourceURL, destinationURL) else {
                throw DocumentSaveProtectionPolicyError.plainCopyMustUseDifferentDestination
            }
        }
    }

    private static func sameFile(_ lhs: URL, _ rhs: URL) -> Bool {
        let lhsURL = lhs.standardizedFileURL.resolvingSymlinksInPath()
        let rhsURL = rhs.standardizedFileURL.resolvingSymlinksInPath()
        return lhsURL.path.compare(rhsURL.path, options: .caseInsensitive) == .orderedSame
    }
}

enum DocumentSaveCommand: String, CaseIterable {
    case save = "file:save"
    case saveAs = "file:save-as"
    case saveAsHwp = "file:save-as-hwp"
    case saveAsHwpx = "file:save-as-hwpx"

    var usesSavePanel: Bool {
        self != .save
    }

    func resolveFormat(sourceURL: URL?, filename: String?) -> DocumentSaveFormat {
        switch self {
        case .save, .saveAs:
            return DocumentSaveFormat.resolve(sourceURL: sourceURL, filename: filename)
        case .saveAsHwp:
            return .hwp
        case .saveAsHwpx:
            return .hwpx
        }
    }
}

enum DocumentSaveContractError: Error, Equatable, LocalizedError {
    case missingBase64
    case invalidBase64
    case missingResponseFormat
    case unsupportedResponseFormat(String)
    case responseFormatMismatch(expected: DocumentSaveFormat, actual: DocumentSaveFormat)
    case missingByteCount
    case byteCountMismatch(expected: Int, actual: Int)
    case invalidPayloadSignature(DocumentSaveFormat)
    case destinationFormatMismatch(expected: DocumentSaveFormat, actualExtension: String)

    var errorDescription: String? {
        switch self {
        case .missingBase64:
            return "base64 데이터가 없습니다."
        case .invalidBase64:
            return "base64 데이터를 해석할 수 없습니다."
        case .missingResponseFormat:
            return "저장 응답 형식이 없습니다."
        case .unsupportedResponseFormat(let rawValue):
            return "지원하지 않는 저장 응답 형식입니다: \(rawValue)"
        case .responseFormatMismatch(let expected, let actual):
            return "요청 형식(\(expected.rawValue))과 응답 형식(\(actual.rawValue))이 일치하지 않습니다."
        case .missingByteCount:
            return "저장 응답의 데이터 크기가 없습니다."
        case .byteCountMismatch(let expected, let actual):
            return "저장 응답의 데이터 크기(\(expected))와 실제 크기(\(actual))가 일치하지 않습니다."
        case .invalidPayloadSignature(let format):
            return "payload signature가 \(format.rawValue.uppercased()) 형식과 일치하지 않습니다."
        case .destinationFormatMismatch(let expected, let actualExtension):
            let actual = actualExtension.isEmpty ? "확장자 없음" : ".\(actualExtension)"
            return "저장 위치의 형식(\(actual))이 요청 형식(.\(expected.fileExtension))과 일치하지 않습니다."
        }
    }
}

enum DocumentSaveContract {
    static func decodeAndValidate(
        base64: String?,
        responseFormatRawValue: String?,
        responseByteCount: Int?,
        requestFormat: DocumentSaveFormat,
        destinationURL: URL
    ) throws -> Data {
        guard let responseFormatRawValue else {
            throw DocumentSaveContractError.missingResponseFormat
        }
        guard let responseFormat = DocumentSaveFormat(rawValue: responseFormatRawValue) else {
            throw DocumentSaveContractError.unsupportedResponseFormat(responseFormatRawValue)
        }
        guard responseFormat == requestFormat else {
            throw DocumentSaveContractError.responseFormatMismatch(
                expected: requestFormat,
                actual: responseFormat
            )
        }
        guard let base64 else {
            throw DocumentSaveContractError.missingBase64
        }
        guard let data = Data(base64Encoded: base64) else {
            throw DocumentSaveContractError.invalidBase64
        }
        guard let responseByteCount else {
            throw DocumentSaveContractError.missingByteCount
        }
        guard responseByteCount == data.count else {
            throw DocumentSaveContractError.byteCountMismatch(
                expected: responseByteCount,
                actual: data.count
            )
        }
        guard requestFormat.matchesPayloadSignature(data) else {
            throw DocumentSaveContractError.invalidPayloadSignature(requestFormat)
        }
        guard DocumentSaveFormat(url: destinationURL) == requestFormat else {
            throw DocumentSaveContractError.destinationFormatMismatch(
                expected: requestFormat,
                actualExtension: destinationURL.pathExtension.lowercased()
            )
        }
        return data
    }
}
