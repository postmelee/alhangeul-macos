import Foundation
import XCTest

final class DocumentSaveContractTests: XCTestCase {
    private let hwpData = Data([
        0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1, 0x00
    ])
    private let hwpxData = Data([0x50, 0x4B, 0x03, 0x04, 0x00])

    func testSourceFormatIdentityRecognizesHwp3Magic() {
        XCTAssertEqual(
            DocumentSourceFormatIdentity.identify(Data("HWP Document File V3.00".utf8)),
            .hwp3
        )
        XCTAssertEqual(
            DocumentSourceFormatIdentity.identify(Data("HWP Document".utf8)),
            .other
        )
        XCTAssertEqual(DocumentSourceFormatIdentity.identify(hwpData), .other)
        XCTAssertEqual(DocumentSourceFormatIdentity.identify(hwpxData), .other)
    }

    func testHwp3ConversionIntentUsesActualOutputFormat() {
        XCTAssertEqual(
            DocumentSaveConversionIntent.resolve(
                sourceFormat: .hwp3,
                outputFormat: .hwp
            ),
            .hwp3ToHwp5
        )
        XCTAssertEqual(
            DocumentSaveConversionIntent.resolve(
                sourceFormat: .hwp3,
                outputFormat: .hwpx
            ),
            .hwp3ToHwpx
        )
        XCTAssertEqual(
            DocumentSaveConversionIntent.resolve(
                sourceFormat: .other,
                outputFormat: .hwp
            ),
            .none
        )
    }

    func testRequestRejectsConversionIntentThatDoesNotMatchSourceAndOutput() {
        XCTAssertThrowsError(
            try DocumentSaveProtectionPolicy.validateRequest(
                sourceProtection: .plain,
                outputIntent: .preserveSourceProtection,
                sourceFormat: .hwp3,
                outputFormat: .hwp,
                conversionIntent: .none,
                sourceURL: URL(fileURLWithPath: "/tmp/original.hwp"),
                destinationURL: URL(fileURLWithPath: "/tmp/new-copy.hwp")
            )
        ) { error in
            XCTAssertEqual(
                error as? DocumentSaveProtectionPolicyError,
                .conversionIntentMismatch
            )
        }
    }

    func testGenericCommandsPreserveSourceFormat() {
        let sourceURL = URL(fileURLWithPath: "/tmp/source.hwpx")

        XCTAssertEqual(
            DocumentSaveCommand.save.resolveFormat(
                sourceURL: sourceURL,
                filename: "stale.hwp"
            ),
            .hwpx
        )
        XCTAssertEqual(
            DocumentSaveCommand.saveAs.resolveFormat(
                sourceURL: sourceURL,
                filename: "stale.hwp"
            ),
            .hwpx
        )
    }

    func testGenericCommandsUseFilenameThenHwpDefault() {
        XCTAssertEqual(
            DocumentSaveCommand.save.resolveFormat(sourceURL: nil, filename: "draft.hwpx"),
            .hwpx
        )
        XCTAssertEqual(
            DocumentSaveCommand.saveAs.resolveFormat(sourceURL: nil, filename: nil),
            .hwp
        )
    }

    func testExplicitCommandsOverrideSourceFormat() {
        XCTAssertEqual(
            DocumentSaveCommand.saveAsHwp.resolveFormat(
                sourceURL: URL(fileURLWithPath: "/tmp/source.hwpx"),
                filename: "source.hwpx"
            ),
            .hwp
        )
        XCTAssertEqual(
            DocumentSaveCommand.saveAsHwpx.resolveFormat(
                sourceURL: URL(fileURLWithPath: "/tmp/source.hwp"),
                filename: "source.hwp"
            ),
            .hwpx
        )
    }

    func testOnlyPlainSaveSkipsSavePanel() {
        XCTAssertFalse(DocumentSaveCommand.save.usesSavePanel)
        XCTAssertTrue(DocumentSaveCommand.saveAs.usesSavePanel)
        XCTAssertTrue(DocumentSaveCommand.saveAsHwp.usesSavePanel)
        XCTAssertTrue(DocumentSaveCommand.saveAsHwpx.usesSavePanel)
    }

    func testValidHwpAndHwpxResponsesAreDecoded() throws {
        XCTAssertEqual(
            try validate(data: hwpData, responseFormat: .hwp, requestFormat: .hwp),
            hwpData
        )
        XCTAssertEqual(
            try validate(data: hwpxData, responseFormat: .hwpx, requestFormat: .hwpx),
            hwpxData
        )
    }

    func testResponseFormatMismatchIsRejected() {
        XCTAssertThrowsError(
            try validate(data: hwpData, responseFormat: .hwp, requestFormat: .hwpx)
        ) { error in
            XCTAssertEqual(
                error as? DocumentSaveContractError,
                .responseFormatMismatch(expected: .hwpx, actual: .hwp)
            )
        }
    }

    func testResponseFormatIsValidatedBeforePayload() {
        XCTAssertThrowsError(
            try DocumentSaveContract.decodeAndValidate(
                base64: "%%%",
                responseFormatRawValue: DocumentSaveFormat.hwp.rawValue,
                responseByteCount: hwpData.count,
                requestFormat: .hwpx,
                destinationURL: URL(fileURLWithPath: "/tmp/document.hwpx")
            )
        ) { error in
            XCTAssertEqual(
                error as? DocumentSaveContractError,
                .responseFormatMismatch(expected: .hwpx, actual: .hwp)
            )
        }
    }

    func testInvalidSignatureIsRejected() {
        XCTAssertThrowsError(
            try DocumentSaveContract.decodeAndValidate(
                base64: hwpData.base64EncodedString(),
                responseFormatRawValue: DocumentSaveFormat.hwpx.rawValue,
                responseByteCount: hwpData.count,
                requestFormat: .hwpx,
                destinationURL: URL(fileURLWithPath: "/tmp/document.hwpx")
            )
        ) { error in
            XCTAssertEqual(
                error as? DocumentSaveContractError,
                .invalidPayloadSignature(.hwpx)
            )
        }
    }

    func testByteCountMismatchIsRejected() {
        XCTAssertThrowsError(
            try DocumentSaveContract.decodeAndValidate(
                base64: hwpData.base64EncodedString(),
                responseFormatRawValue: DocumentSaveFormat.hwp.rawValue,
                responseByteCount: hwpData.count + 1,
                requestFormat: .hwp,
                destinationURL: URL(fileURLWithPath: "/tmp/document.hwp")
            )
        ) { error in
            XCTAssertEqual(
                error as? DocumentSaveContractError,
                .byteCountMismatch(expected: self.hwpData.count + 1, actual: self.hwpData.count)
            )
        }
    }

    func testMissingMetadataAndInvalidBase64AreRejected() {
        XCTAssertThrowsError(
            try DocumentSaveContract.decodeAndValidate(
                base64: nil,
                responseFormatRawValue: "hwp",
                responseByteCount: hwpData.count,
                requestFormat: .hwp,
                destinationURL: URL(fileURLWithPath: "/tmp/document.hwp")
            )
        ) { error in
            XCTAssertEqual(error as? DocumentSaveContractError, .missingBase64)
        }

        XCTAssertThrowsError(
            try DocumentSaveContract.decodeAndValidate(
                base64: "%%%",
                responseFormatRawValue: "hwp",
                responseByteCount: hwpData.count,
                requestFormat: .hwp,
                destinationURL: URL(fileURLWithPath: "/tmp/document.hwp")
            )
        ) { error in
            XCTAssertEqual(error as? DocumentSaveContractError, .invalidBase64)
        }

        XCTAssertThrowsError(
            try DocumentSaveContract.decodeAndValidate(
                base64: hwpData.base64EncodedString(),
                responseFormatRawValue: nil,
                responseByteCount: hwpData.count,
                requestFormat: .hwp,
                destinationURL: URL(fileURLWithPath: "/tmp/document.hwp")
            )
        ) { error in
            XCTAssertEqual(error as? DocumentSaveContractError, .missingResponseFormat)
        }

        XCTAssertThrowsError(
            try DocumentSaveContract.decodeAndValidate(
                base64: hwpData.base64EncodedString(),
                responseFormatRawValue: "hwp",
                responseByteCount: nil,
                requestFormat: .hwp,
                destinationURL: URL(fileURLWithPath: "/tmp/document.hwp")
            )
        ) { error in
            XCTAssertEqual(error as? DocumentSaveContractError, .missingByteCount)
        }
    }

    func testDestinationFormatMismatchIsRejected() {
        XCTAssertThrowsError(
            try DocumentSaveContract.decodeAndValidate(
                base64: hwpxData.base64EncodedString(),
                responseFormatRawValue: DocumentSaveFormat.hwpx.rawValue,
                responseByteCount: hwpxData.count,
                requestFormat: .hwpx,
                destinationURL: URL(fileURLWithPath: "/tmp/document.hwp")
            )
        ) { error in
            XCTAssertEqual(
                error as? DocumentSaveContractError,
                .destinationFormatMismatch(expected: .hwpx, actualExtension: "hwp")
            )
        }
    }

    func testOnlyPlainNonHwp3DocumentsAllowInPlaceSave() {
        XCTAssertTrue(
            DocumentSaveProtectionPolicy.allowsInPlaceSave(
                sourceProtection: .plain,
                sourceFormat: .other
            )
        )
        XCTAssertFalse(
            DocumentSaveProtectionPolicy.allowsInPlaceSave(
                sourceProtection: .plain,
                sourceFormat: .hwp3
            )
        )

        for protection in [
            DocumentSourceProtection.passwordProtected,
            .unsupportedProtection,
            .invalidOrUnknown
        ] {
            XCTAssertFalse(
                DocumentSaveProtectionPolicy.allowsInPlaceSave(
                    sourceProtection: protection,
                    sourceFormat: .other
                )
            )
        }
    }

    func testWarningIntentCombinesProtectionRemovalAndHwp3Conversion() {
        XCTAssertEqual(
            DocumentSaveWarningIntent.resolve(
                sourceProtection: .plain,
                conversionIntent: .none
            ),
            .none
        )
        XCTAssertEqual(
            DocumentSaveWarningIntent.resolve(
                sourceProtection: .plain,
                conversionIntent: .hwp3ToHwp5
            ),
            .conversionCopy
        )
        XCTAssertEqual(
            DocumentSaveWarningIntent.resolve(
                sourceProtection: .passwordProtected,
                conversionIntent: .none
            ),
            .plainCopy
        )
        XCTAssertEqual(
            DocumentSaveWarningIntent.resolve(
                sourceProtection: .passwordProtected,
                conversionIntent: .hwp3ToHwpx
            ),
            .plainConversionCopy
        )
    }

    func testWritePolicyRefusesToOverwriteExistingConversionDestination() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let existingURL = directoryURL.appendingPathComponent("existing.hwp")
        let newURL = directoryURL.appendingPathComponent("new.hwp")
        let originalData = Data("original".utf8)
        let convertedData = Data("converted".utf8)
        let options = DocumentSaveWritePolicy.options(allowOverwrite: false)
        try originalData.write(to: existingURL)

        XCTAssertFalse(options.contains(.atomic))
        XCTAssertTrue(options.contains(.withoutOverwriting))
        XCTAssertThrowsError(try convertedData.write(to: existingURL, options: options))
        XCTAssertEqual(try Data(contentsOf: existingURL), originalData)

        XCTAssertNoThrow(try convertedData.write(to: newURL, options: options))
        XCTAssertEqual(try Data(contentsOf: newURL), convertedData)

        let overwriteOptions = DocumentSaveWritePolicy.options(allowOverwrite: true)
        XCTAssertTrue(overwriteOptions.contains(.atomic))
        XCTAssertFalse(overwriteOptions.contains(.withoutOverwriting))
    }

    func testNonPlainDocumentsRequirePlainCopyIntent() {
        let destinationURL = URL(fileURLWithPath: "/tmp/copy.hwp")

        for protection in [
            DocumentSourceProtection.passwordProtected,
            .unsupportedProtection,
            .invalidOrUnknown
        ] {
            XCTAssertEqual(
                DocumentSaveProtectionPolicy.outputIntent(for: protection),
                .plainCopy
            )
            XCTAssertThrowsError(
                try DocumentSaveProtectionPolicy.validateRequest(
                    sourceProtection: protection,
                    outputIntent: .preserveSourceProtection,
                    conversionIntent: .none,
                    sourceURL: URL(fileURLWithPath: "/tmp/original.hwp"),
                    destinationURL: destinationURL
                )
            ) { error in
                XCTAssertEqual(
                    error as? DocumentSaveProtectionPolicyError,
                    .protectedSourceRequiresPlainCopy(protection)
                )
            }
        }
    }

    func testPlainCopyMustUseDifferentDestination() throws {
        let sourceURL = URL(fileURLWithPath: "/tmp/folder/original.hwp")

        for destinationURL in [
            sourceURL,
            URL(fileURLWithPath: "/tmp/folder/./original.hwp"),
            URL(fileURLWithPath: "/TMP/FOLDER/original.hwp")
        ] {
            XCTAssertThrowsError(
                try DocumentSaveProtectionPolicy.validateRequest(
                    sourceProtection: .passwordProtected,
                    outputIntent: .plainCopy,
                    conversionIntent: .none,
                    sourceURL: sourceURL,
                    destinationURL: destinationURL
                )
            ) { error in
                XCTAssertEqual(
                    error as? DocumentSaveProtectionPolicyError,
                    .plainCopyMustUseDifferentDestination
                )
            }
        }

        XCTAssertNoThrow(
            try DocumentSaveProtectionPolicy.validateRequest(
                sourceProtection: .passwordProtected,
                outputIntent: .plainCopy,
                conversionIntent: .none,
                sourceURL: sourceURL,
                destinationURL: URL(fileURLWithPath: "/tmp/folder/plain-copy.hwp")
            )
        )
    }

    func testPlainCopyWithoutSourceURLRejectsExistingDestination() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let existingURL = directoryURL.appendingPathComponent("existing.hwp")
        try Data("original".utf8).write(to: existingURL)

        XCTAssertThrowsError(
            try DocumentSaveProtectionPolicy.validateRequest(
                sourceProtection: .passwordProtected,
                outputIntent: .plainCopy,
                conversionIntent: .none,
                sourceURL: nil,
                destinationURL: existingURL
            )
        ) { error in
            XCTAssertEqual(
                error as? DocumentSaveProtectionPolicyError,
                .plainCopyRequiresNewDestination
            )
        }

        XCTAssertNoThrow(
            try DocumentSaveProtectionPolicy.validateRequest(
                sourceProtection: .passwordProtected,
                outputIntent: .plainCopy,
                conversionIntent: .none,
                sourceURL: nil,
                destinationURL: directoryURL.appendingPathComponent("new-copy.hwp")
            )
        )
    }

    func testHwp3ConversionRejectsSourceEquivalentAndExistingDestinations() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let sourceURL = directoryURL.appendingPathComponent("original.hwp")
        let symlinkURL = directoryURL.appendingPathComponent("source-link.hwp")
        let existingURL = directoryURL.appendingPathComponent("existing.hwp")
        try Data("hwp3-source".utf8).write(to: sourceURL)
        try FileManager.default.createSymbolicLink(
            at: symlinkURL,
            withDestinationURL: sourceURL
        )
        try Data("existing".utf8).write(to: existingURL)

        for destinationURL in [
            sourceURL,
            directoryURL.appendingPathComponent("./original.hwp"),
            URL(fileURLWithPath: sourceURL.path.uppercased()),
            symlinkURL
        ] {
            XCTAssertThrowsError(
                try DocumentSaveProtectionPolicy.validateRequest(
                    sourceProtection: .plain,
                    outputIntent: .preserveSourceProtection,
                    sourceFormat: .hwp3,
                    outputFormat: .hwp,
                    conversionIntent: .hwp3ToHwp5,
                    sourceURL: sourceURL,
                    destinationURL: destinationURL
                )
            ) { error in
                XCTAssertEqual(
                    error as? DocumentSaveProtectionPolicyError,
                    .hwp3ConversionMustUseDifferentDestination
                )
            }
        }

        XCTAssertThrowsError(
            try DocumentSaveProtectionPolicy.validateRequest(
                sourceProtection: .plain,
                outputIntent: .preserveSourceProtection,
                sourceFormat: .hwp3,
                outputFormat: .hwpx,
                conversionIntent: .hwp3ToHwpx,
                sourceURL: sourceURL,
                destinationURL: existingURL
            )
        ) { error in
            XCTAssertEqual(
                error as? DocumentSaveProtectionPolicyError,
                .hwp3ConversionRequiresNewDestination
            )
        }

        XCTAssertThrowsError(
            try DocumentSaveProtectionPolicy.validateRequest(
                sourceProtection: .passwordProtected,
                outputIntent: .plainCopy,
                sourceFormat: .hwp3,
                outputFormat: .hwp,
                conversionIntent: .hwp3ToHwp5,
                sourceURL: nil,
                destinationURL: existingURL
            )
        ) { error in
            XCTAssertEqual(
                error as? DocumentSaveProtectionPolicyError,
                .hwp3ConversionRequiresNewDestination
            )
        }

        let newURL = directoryURL.appendingPathComponent("new-copy.hwp")
        XCTAssertNoThrow(
            try DocumentSaveProtectionPolicy.validateRequest(
                sourceProtection: .plain,
                outputIntent: .preserveSourceProtection,
                sourceFormat: .hwp3,
                outputFormat: .hwp,
                conversionIntent: .hwp3ToHwp5,
                sourceURL: sourceURL,
                destinationURL: newURL
            )
        )
        XCTAssertNoThrow(
            try DocumentSaveProtectionPolicy.validateRequest(
                sourceProtection: .passwordProtected,
                outputIntent: .plainCopy,
                sourceFormat: .hwp3,
                outputFormat: .hwp,
                conversionIntent: .hwp3ToHwp5,
                sourceURL: sourceURL,
                destinationURL: newURL
            )
        )
    }

    func testPlainCopySuggestedFilenameDescribesProtectionRemoval() {
        XCTAssertEqual(
            DocumentSaveProtectionPolicy.suggestedFilename(
                for: "원본.hwp",
                format: .hwp,
                outputIntent: .plainCopy,
                conversionIntent: .none
            ),
            "원본 (평문 복사본).hwp"
        )
        XCTAssertEqual(
            DocumentSaveProtectionPolicy.suggestedFilename(
                for: "원본.hwp",
                format: .hwpx,
                outputIntent: .plainCopy,
                conversionIntent: .none
            ),
            "원본 (평문 복사본).hwpx"
        )
        XCTAssertEqual(
            DocumentSaveProtectionPolicy.suggestedFilename(
                for: "원본.hwp",
                format: .hwp,
                outputIntent: .preserveSourceProtection,
                conversionIntent: .none
            ),
            "원본.hwp"
        )
    }

    func testSuggestedFilenameDescribesHwp3ConversionAndProtectionRemoval() {
        XCTAssertEqual(
            DocumentSaveProtectionPolicy.suggestedFilename(
                for: "원본.hwp",
                format: .hwp,
                outputIntent: .preserveSourceProtection,
                conversionIntent: .hwp3ToHwp5
            ),
            "원본 (변환 복사본).hwp"
        )
        XCTAssertEqual(
            DocumentSaveProtectionPolicy.suggestedFilename(
                for: "원본.hwp",
                format: .hwpx,
                outputIntent: .preserveSourceProtection,
                conversionIntent: .hwp3ToHwpx
            ),
            "원본 (변환 복사본).hwpx"
        )
        XCTAssertEqual(
            DocumentSaveProtectionPolicy.suggestedFilename(
                for: "원본.hwp",
                format: .hwp,
                outputIntent: .plainCopy,
                conversionIntent: .hwp3ToHwp5
            ),
            "원본 (평문 변환 복사본).hwp"
        )
        XCTAssertEqual(
            DocumentSaveProtectionPolicy.suggestedFilename(
                for: "원본.hwp",
                format: .hwpx,
                outputIntent: .plainCopy,
                conversionIntent: .hwp3ToHwpx
            ),
            "원본 (평문 변환 복사본).hwpx"
        )
    }

    func testPlainSavePreservesPlainProtection() throws {
        let sourceURL = URL(fileURLWithPath: "/tmp/original.hwp")

        XCTAssertEqual(
            DocumentSaveProtectionPolicy.outputIntent(for: .plain),
            .preserveSourceProtection
        )
        XCTAssertNoThrow(
            try DocumentSaveProtectionPolicy.validateRequest(
                sourceProtection: .plain,
                outputIntent: .preserveSourceProtection,
                conversionIntent: .none,
                sourceURL: sourceURL,
                destinationURL: sourceURL
            )
        )
        XCTAssertEqual(
            DocumentSaveProtectionPolicy.resultingProtection(
                sourceProtection: .plain,
                for: .preserveSourceProtection
            ),
            .plain
        )
        XCTAssertEqual(
            DocumentSaveProtectionPolicy.resultingProtection(
                sourceProtection: .passwordProtected,
                for: .plainCopy
            ),
            .plain
        )
    }

    func testSaveContextRejectsDocumentOrProtectionChanges() throws {
        XCTAssertNoThrow(
            try DocumentSaveProtectionPolicy.validateCurrentDocument(
                requestRevision: 7,
                requestProtection: .passwordProtected,
                requestSourceFormat: .hwp3,
                currentRevision: 7,
                currentProtection: .passwordProtected,
                currentSourceFormat: .hwp3
            )
        )

        for (revision, protection, sourceFormat) in [
            (
                Int?.some(8),
                DocumentSourceProtection?.some(.passwordProtected),
                DocumentSourceFormatIdentity?.some(.hwp3)
            ),
            (
                Int?.some(7),
                DocumentSourceProtection?.some(.plain),
                DocumentSourceFormatIdentity?.some(.hwp3)
            ),
            (
                Int?.some(7),
                DocumentSourceProtection?.some(.passwordProtected),
                DocumentSourceFormatIdentity?.some(.other)
            ),
            (nil, nil, nil)
        ] {
            XCTAssertThrowsError(
                try DocumentSaveProtectionPolicy.validateCurrentDocument(
                    requestRevision: 7,
                    requestProtection: .passwordProtected,
                    requestSourceFormat: .hwp3,
                    currentRevision: revision,
                    currentProtection: protection,
                    currentSourceFormat: sourceFormat
                )
            ) { error in
                XCTAssertEqual(
                    error as? DocumentSaveProtectionPolicyError,
                    .documentChanged
                )
            }
        }
    }

    private func validate(
        data: Data,
        responseFormat: DocumentSaveFormat,
        requestFormat: DocumentSaveFormat
    ) throws -> Data {
        try DocumentSaveContract.decodeAndValidate(
            base64: data.base64EncodedString(),
            responseFormatRawValue: responseFormat.rawValue,
            responseByteCount: data.count,
            requestFormat: requestFormat,
            destinationURL: URL(fileURLWithPath: "/tmp/document.\(requestFormat.fileExtension)")
        )
    }
}
