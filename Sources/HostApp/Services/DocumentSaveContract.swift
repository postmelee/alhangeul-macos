import Foundation

enum DocumentSourceFormatIdentity: Equatable {
    private static let hwp3MagicPrefix = Data("HWP Document File".utf8)

    case hwp3
    case other

    static func identify(_ data: Data) -> Self {
        data.starts(with: hwp3MagicPrefix) ? .hwp3 : .other
    }
}

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

enum DocumentSaveConversionIntent: Equatable {
    case none
    case hwp3ToHwp5
    case hwp3ToHwpx

    static func resolve(
        sourceFormat: DocumentSourceFormatIdentity,
        outputFormat: DocumentSaveFormat
    ) -> Self {
        guard sourceFormat == .hwp3 else {
            return .none
        }

        switch outputFormat {
        case .hwp:
            return .hwp3ToHwp5
        case .hwpx:
            return .hwp3ToHwpx
        }
    }

    var requiresNewDestination: Bool {
        self != .none
    }
}

enum DocumentSaveWarningIntent: Equatable {
    case none
    case conversionCopy
    case plainCopy
    case plainConversionCopy

    static func resolve(
        sourceProtection: DocumentSourceProtection,
        conversionIntent: DocumentSaveConversionIntent
    ) -> Self {
        switch (
            sourceProtection.requiresPlainCopyWarning,
            conversionIntent != .none
        ) {
        case (false, false):
            return .none
        case (false, true):
            return .conversionCopy
        case (true, false):
            return .plainCopy
        case (true, true):
            return .plainConversionCopy
        }
    }

    var requiresConfirmation: Bool {
        self != .none
    }
}

enum DocumentSaveWritePolicy {
    static func options(allowOverwrite: Bool) -> Data.WritingOptions {
        if allowOverwrite {
            return .atomic
        }
        // Foundation은 atomic과 withoutOverwriting 동시 사용 시 중단하므로,
        // HWP3 변환은 기존 파일 보존을 우선해 배타적 신규 쓰기를 사용한다.
        return .withoutOverwriting
    }
}

enum DocumentSaveProtectionPolicyError: Error, Equatable, LocalizedError {
    case documentChanged
    case protectedSourceRequiresPlainCopy(DocumentSourceProtection)
    case plainSourceRequiresPreserveIntent
    case plainCopyMustUseDifferentDestination
    case plainCopyRequiresNewDestination
    case conversionIntentMismatch
    case hwp3ConversionMustUseDifferentDestination
    case hwp3ConversionRequiresNewDestination

    var errorDescription: String? {
        switch self {
        case .documentChanged:
            return "저장 요청 뒤 다른 문서가 열렸거나 보호 상태 또는 원본 형식이 변경되었습니다."
        case .protectedSourceRequiresPlainCopy:
            return "보호된 문서는 현재 원본 보호를 유지한 채 저장할 수 없습니다."
        case .plainSourceRequiresPreserveIntent:
            return "평문 문서의 저장 보호 의도가 올바르지 않습니다."
        case .plainCopyMustUseDifferentDestination:
            return "보호를 해제한 복사본은 원본과 다른 위치에 저장해야 합니다."
        case .plainCopyRequiresNewDestination:
            return "원본 위치를 확인할 수 없는 보호 문서는 기존 파일을 덮어쓸 수 없습니다. 새 파일 이름을 선택해 주세요."
        case .conversionIntentMismatch:
            return "원본 형식과 저장 형식의 변환 상태가 일치하지 않습니다."
        case .hwp3ConversionMustUseDifferentDestination:
            return "HWP3 변환 복사본은 원본과 다른 새 파일에 저장해야 합니다."
        case .hwp3ConversionRequiresNewDestination:
            return "HWP3 변환 복사본은 기존 파일을 덮어쓸 수 없습니다. 새 파일 이름을 선택해 주세요."
        }
    }
}

enum DocumentSaveProtectionPolicy {
    static func validateCurrentDocument(
        requestRevision: Int,
        requestProtection: DocumentSourceProtection,
        requestSourceFormat: DocumentSourceFormatIdentity,
        currentRevision: Int?,
        currentProtection: DocumentSourceProtection?,
        currentSourceFormat: DocumentSourceFormatIdentity?
    ) throws {
        guard currentRevision == requestRevision,
              currentProtection == requestProtection,
              currentSourceFormat == requestSourceFormat
        else {
            throw DocumentSaveProtectionPolicyError.documentChanged
        }
    }

    static func allowsInPlaceSave(
        sourceProtection: DocumentSourceProtection,
        sourceFormat: DocumentSourceFormatIdentity
    ) -> Bool {
        sourceProtection == .plain && sourceFormat != .hwp3
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
        sourceFormat: DocumentSourceFormatIdentity = .other,
        outputFormat: DocumentSaveFormat = .hwp,
        conversionIntent: DocumentSaveConversionIntent,
        sourceURL: URL?,
        destinationURL: URL
    ) throws {
        guard conversionIntent == DocumentSaveConversionIntent.resolve(
            sourceFormat: sourceFormat,
            outputFormat: outputFormat
        ) else {
            throw DocumentSaveProtectionPolicyError.conversionIntentMismatch
        }

        switch (sourceProtection, outputIntent) {
        case (.plain, .preserveSourceProtection):
            break
        case (.plain, .plainCopy):
            throw DocumentSaveProtectionPolicyError.plainSourceRequiresPreserveIntent
        case (_, .preserveSourceProtection):
            throw DocumentSaveProtectionPolicyError.protectedSourceRequiresPlainCopy(
                sourceProtection
            )
        case (_, .plainCopy):
            break
        }

        if conversionIntent.requiresNewDestination {
            if let sourceURL, sameFile(sourceURL, destinationURL) {
                throw DocumentSaveProtectionPolicyError
                    .hwp3ConversionMustUseDifferentDestination
            }
            guard !FileManager.default.fileExists(atPath: destinationURL.path) else {
                throw DocumentSaveProtectionPolicyError.hwp3ConversionRequiresNewDestination
            }
            return
        }

        if outputIntent == .plainCopy {
            guard let sourceURL else {
                guard !FileManager.default.fileExists(atPath: destinationURL.path) else {
                    throw DocumentSaveProtectionPolicyError.plainCopyRequiresNewDestination
                }
                return
            }
            if sameFile(sourceURL, destinationURL) {
                throw DocumentSaveProtectionPolicyError.plainCopyMustUseDifferentDestination
            }
        }
    }

    static func suggestedFilename(
        for filename: String,
        format: DocumentSaveFormat,
        outputIntent: DocumentSaveOutputProtectionIntent,
        conversionIntent: DocumentSaveConversionIntent
    ) -> String {
        let normalizedFilename = format.normalizedFilename(filename)
        let suffix: String? = switch (
            outputIntent,
            conversionIntent.requiresNewDestination
        ) {
        case (.preserveSourceProtection, false):
            nil
        case (.preserveSourceProtection, true):
            "변환 복사본"
        case (.plainCopy, false):
            "평문 복사본"
        case (.plainCopy, true):
            "평문 변환 복사본"
        }
        guard let suffix else {
            return normalizedFilename
        }

        let stem = (normalizedFilename as NSString).deletingPathExtension
        return format.normalizedFilename("\(stem) (\(suffix))")
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
