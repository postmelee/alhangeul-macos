import Foundation
import XCTest

final class HwpExternalImageResolverTests: XCTestCase {
    func testOpenCreatesDocumentWithoutEnablingResolverForBytesOnlyContext() throws {
        let result = try HwpExternalImageResolver.open(
            data: ExternalImageTestSupport.sampleData(at: "samples/basic/KTX.hwp"),
            context: RhwpDocumentOpenContext(
                sourceURL: nil,
                displayFilename: "KTX.hwp",
                maximumExternalResourceBytes: 1024
            )
        )

        XCTAssertGreaterThan(result.document.pageCount, 0)
        XCTAssertEqual(
            result.externalResourceReport,
            RhwpExternalResourceReport(
                state: .disabledNoSourceURL,
                filenameStatus: .ok,
                resolutions: []
            )
        )
    }

    func testNilAndNonFileSourceDisableQueries() {
        let contexts = [
            RhwpDocumentOpenContext(
                sourceURL: nil,
                displayFilename: "sample.hwp",
                maximumExternalResourceBytes: 1024
            ),
            RhwpDocumentOpenContext(
                sourceURL: URL(string: "https://example.invalid/sample.hwp"),
                displayFilename: "sample.hwp",
                maximumExternalResourceBytes: 1024
            )
        ]

        for (index, context) in contexts.enumerated() {
            let document = FakeExternalImageDocument(
                referenceResults: [.success([])]
            )

            let report = HwpExternalImageResolver.resolve(
                document: document,
                context: context
            )

            XCTAssertEqual(
                report.state,
                index == 0 ? .disabledNoSourceURL : .disabledNonFileURL
            )
            XCTAssertEqual(report.filenameStatus, .ok)
            XCTAssertEqual(document.referenceQueryCount, 0)
            XCTAssertTrue(document.injections.isEmpty)
        }
    }

    func testEmptyReferencesProduceAttemptedEmptyReport() throws {
        try ExternalImageTestSupport.withTemporaryDirectory { directoryURL in
            let sourceURL = try makeSourceDocument(in: directoryURL)
            let document = FakeExternalImageDocument(
                referenceResults: [.success([])]
            )

            let report = HwpExternalImageResolver.resolve(
                document: document,
                context: context(sourceURL: sourceURL)
            )

            XCTAssertEqual(report.state, .attempted)
            XCTAssertEqual(report.resolutions, [])
            XCTAssertEqual(report.summary.total, 0)
            XCTAssertEqual(document.referenceQueryCount, 1)
        }
    }

    func testReferenceQueryFailureIsNonFatal() throws {
        try ExternalImageTestSupport.withTemporaryDirectory { directoryURL in
            let sourceURL = try makeSourceDocument(in: directoryURL)
            let document = FakeExternalImageDocument(
                referenceResults: [.failure(FakeDocumentError.referenceQuery)]
            )

            let report = HwpExternalImageResolver.resolve(
                document: document,
                context: context(sourceURL: sourceURL)
            )

            XCTAssertEqual(report.state, .referenceQueryFailed)
            XCTAssertEqual(report.filenameStatus, .ok)
            XCTAssertEqual(report.resolutions, [])
            XCTAssertTrue(document.injections.isEmpty)
        }
    }

    func testAlreadyLoadedReferenceSkipsFileReadAndInjection() throws {
        try ExternalImageTestSupport.withTemporaryDirectory { directoryURL in
            let sourceURL = try makeSourceDocument(in: directoryURL)
            let reference = makeReference(
                key: "binData:1",
                basename: "already.png",
                loaded: true
            )
            let document = FakeExternalImageDocument(
                referenceResults: [.success([reference])]
            )
            var readCount = 0

            let report = HwpExternalImageResolver.resolve(
                document: document,
                context: context(sourceURL: sourceURL)
            ) { _ in
                readCount += 1
                return Data()
            }

            XCTAssertEqual(
                report.resolutions,
                [
                    RhwpExternalResourceResolution(
                        key: reference.key,
                        decision: .alreadyLoaded
                    )
                ]
            )
            XCTAssertEqual(readCount, 0)
            XCTAssertTrue(document.injections.isEmpty)
            XCTAssertEqual(document.referenceQueryCount, 1)
        }
    }

    func testValidSiblingInjectsBytesAndBasenameThenVerifiesLoaded() throws {
        try ExternalImageTestSupport.withTemporaryDirectory { directoryURL in
            let sourceURL = try makeSourceDocument(in: directoryURL)
            let imageData = Data([0x89, 0x50, 0x4E, 0x47])
            let imageURL = try ExternalImageTestSupport.write(
                imageData,
                named: "sibling.png",
                in: directoryURL
            )
            let unloaded = makeReference(
                key: "binData:7",
                basename: imageURL.lastPathComponent
            )
            let loaded = makeReference(
                key: unloaded.key,
                basename: unloaded.basename,
                loaded: true
            )
            let document = FakeExternalImageDocument(
                referenceResults: [
                    .success([unloaded]),
                    .success([loaded])
                ]
            )

            let report = HwpExternalImageResolver.resolve(
                document: document,
                context: context(sourceURL: sourceURL)
            )

            XCTAssertEqual(
                report.resolutions,
                [
                    RhwpExternalResourceResolution(
                        key: unloaded.key,
                        decision: .injected(byteCount: imageData.count)
                    )
                ]
            )
            XCTAssertEqual(
                document.injections,
                [
                    FakeInjection(
                        key: unloaded.key,
                        data: imageData,
                        displayPath: "sibling.png"
                    )
                ]
            )
            XCTAssertEqual(document.referenceQueryCount, 2)
        }
    }

    func testOriginalPathIsNotUsedForFileDiscovery() throws {
        try ExternalImageTestSupport.withTemporaryDirectory { rootURL in
            let sourceDirectoryURL = rootURL.appendingPathComponent(
                "source",
                isDirectory: true
            )
            let outsideDirectoryURL = rootURL.appendingPathComponent(
                "outside",
                isDirectory: true
            )
            try FileManager.default.createDirectory(
                at: sourceDirectoryURL,
                withIntermediateDirectories: false
            )
            try FileManager.default.createDirectory(
                at: outsideDirectoryURL,
                withIntermediateDirectories: false
            )
            let sourceURL = try makeSourceDocument(in: sourceDirectoryURL)
            let outsideURL = try ExternalImageTestSupport.write(
                Data([0x01]),
                named: "outside.png",
                in: outsideDirectoryURL
            )
            let reference = makeReference(
                key: "binData:outside",
                basename: "missing-sibling.png",
                originalPath: outsideURL.path
            )
            let document = FakeExternalImageDocument(
                referenceResults: [.success([reference])]
            )

            let report = HwpExternalImageResolver.resolve(
                document: document,
                context: context(sourceURL: sourceURL)
            )

            XCTAssertEqual(report.resolutions.first?.decision, .missing)
            XCTAssertTrue(document.injections.isEmpty)
        }
    }

    func testInjectionAlreadyLoadedRaceIsAcceptedWithoutFinalQuery() throws {
        try ExternalImageTestSupport.withTemporaryDirectory { directoryURL in
            let sourceURL = try makeSourceDocument(in: directoryURL)
            try ExternalImageTestSupport.write(
                Data([0x01]),
                named: "race.png",
                in: directoryURL
            )
            let reference = makeReference(
                key: "binData:race",
                basename: "race.png"
            )
            let document = FakeExternalImageDocument(
                referenceResults: [.success([reference])],
                injectionStatuses: [reference.key: .alreadyLoaded]
            )

            let report = HwpExternalImageResolver.resolve(
                document: document,
                context: context(sourceURL: sourceURL)
            )

            XCTAssertEqual(
                report.resolutions.first?.decision,
                .alreadyLoaded
            )
            XCTAssertEqual(document.injections.count, 1)
            XCTAssertEqual(document.referenceQueryCount, 1)
        }
    }

    func testInvalidBasenamesAreRejectedWithoutReads() throws {
        try ExternalImageTestSupport.withTemporaryDirectory { directoryURL in
            let sourceURL = try makeSourceDocument(in: directoryURL)
            let invalidBasenames = [
                "",
                ".",
                "..",
                "nested/image.png",
                #"nested\image.png"#,
                "nul\0image.png"
            ]
            let references = invalidBasenames.enumerated().map { index, basename in
                makeReference(
                    key: "binData:\(index + 1)",
                    basename: basename
                )
            }
            let document = FakeExternalImageDocument(
                referenceResults: [.success(references)]
            )
            var readCount = 0

            let report = HwpExternalImageResolver.resolve(
                document: document,
                context: context(sourceURL: sourceURL)
            ) { _ in
                readCount += 1
                return Data()
            }

            XCTAssertEqual(
                report.resolutions.map(\.decision),
                Array(
                    repeating: .rejectedInvalidBasename,
                    count: invalidBasenames.count
                )
            )
            XCTAssertEqual(readCount, 0)
            XCTAssertTrue(document.injections.isEmpty)
        }
    }

    func testSourceDocumentAndDirectoryAreRejected() throws {
        try ExternalImageTestSupport.withTemporaryDirectory { directoryURL in
            let sourceURL = try makeSourceDocument(in: directoryURL)
            let childDirectoryURL = directoryURL.appendingPathComponent(
                "images",
                isDirectory: true
            )
            try FileManager.default.createDirectory(
                at: childDirectoryURL,
                withIntermediateDirectories: false
            )
            let references = [
                makeReference(
                    key: "binData:self",
                    basename: sourceURL.lastPathComponent
                ),
                makeReference(
                    key: "binData:directory",
                    basename: childDirectoryURL.lastPathComponent
                )
            ]
            let document = FakeExternalImageDocument(
                referenceResults: [.success(references)]
            )

            let report = HwpExternalImageResolver.resolve(
                document: document,
                context: context(sourceURL: sourceURL)
            )

            XCTAssertEqual(
                report.resolutions.map(\.decision),
                [.rejectedSourceDocument, .rejectedNonRegularFile]
            )
            XCTAssertTrue(document.injections.isEmpty)
        }
    }

    func testSiblingSymlinkEscapingParentIsRejected() throws {
        try ExternalImageTestSupport.withTemporaryDirectory { rootURL in
            let sourceDirectoryURL = rootURL.appendingPathComponent(
                "source",
                isDirectory: true
            )
            let outsideDirectoryURL = rootURL.appendingPathComponent(
                "outside",
                isDirectory: true
            )
            try FileManager.default.createDirectory(
                at: sourceDirectoryURL,
                withIntermediateDirectories: false
            )
            try FileManager.default.createDirectory(
                at: outsideDirectoryURL,
                withIntermediateDirectories: false
            )
            let sourceURL = try makeSourceDocument(in: sourceDirectoryURL)
            let outsideImageURL = try ExternalImageTestSupport.write(
                Data([0x01]),
                named: "outside.png",
                in: outsideDirectoryURL
            )
            let linkURL = sourceDirectoryURL.appendingPathComponent("linked.png")
            try FileManager.default.createSymbolicLink(
                at: linkURL,
                withDestinationURL: outsideImageURL
            )
            let reference = makeReference(
                key: "binData:escape",
                basename: linkURL.lastPathComponent
            )
            let document = FakeExternalImageDocument(
                referenceResults: [.success([reference])]
            )

            let report = HwpExternalImageResolver.resolve(
                document: document,
                context: context(sourceURL: sourceURL)
            )

            XCTAssertEqual(
                report.resolutions.first?.decision,
                .rejectedOutsideSourceDirectory
            )
            XCTAssertTrue(document.injections.isEmpty)
        }
    }

    func testMetadataAndReadByteLimitsAreAppliedIndependently() throws {
        try ExternalImageTestSupport.withTemporaryDirectory { directoryURL in
            let sourceURL = try makeSourceDocument(in: directoryURL)
            try ExternalImageTestSupport.write(
                Data(repeating: 0x01, count: 5),
                named: "metadata-large.png",
                in: directoryURL
            )
            try ExternalImageTestSupport.write(
                Data([0x01]),
                named: "read-large.png",
                in: directoryURL
            )
            let references = [
                makeReference(
                    key: "binData:metadata",
                    basename: "metadata-large.png"
                ),
                makeReference(
                    key: "binData:read",
                    basename: "read-large.png"
                )
            ]
            let document = FakeExternalImageDocument(
                referenceResults: [.success(references)]
            )
            var loadedNames: [String] = []

            let report = HwpExternalImageResolver.resolve(
                document: document,
                context: context(sourceURL: sourceURL, limit: 4)
            ) { url in
                loadedNames.append(url.lastPathComponent)
                return Data(repeating: 0x02, count: 5)
            }

            XCTAssertEqual(
                report.resolutions.map(\.decision),
                [
                    .tooLarge(actualBytes: 5, limit: 4),
                    .tooLarge(actualBytes: 5, limit: 4)
                ]
            )
            XCTAssertEqual(loadedNames, ["read-large.png"])
            XCTAssertTrue(document.injections.isEmpty)
        }
    }

    func testMissingPermissionAndGenericReadFailuresAreClassified() throws {
        try ExternalImageTestSupport.withTemporaryDirectory { directoryURL in
            let sourceURL = try makeSourceDocument(in: directoryURL)
            try ExternalImageTestSupport.write(
                Data([0x01]),
                named: "permission.png",
                in: directoryURL
            )
            try ExternalImageTestSupport.write(
                Data([0x02]),
                named: "read-failure.png",
                in: directoryURL
            )
            let references = [
                makeReference(
                    key: "binData:missing",
                    basename: "missing.png"
                ),
                makeReference(
                    key: "binData:permission",
                    basename: "permission.png"
                ),
                makeReference(
                    key: "binData:read",
                    basename: "read-failure.png"
                )
            ]
            let document = FakeExternalImageDocument(
                referenceResults: [.success(references)]
            )

            let report = HwpExternalImageResolver.resolve(
                document: document,
                context: context(sourceURL: sourceURL)
            ) { url in
                if url.lastPathComponent == "permission.png" {
                    throw NSError(
                        domain: NSCocoaErrorDomain,
                        code: NSFileReadNoPermissionError
                    )
                }
                throw NSError(
                    domain: "HwpExternalImageResolverTests",
                    code: 1
                )
            }

            XCTAssertEqual(
                report.resolutions.map(\.decision),
                [.missing, .permissionDenied, .readFailed]
            )
            XCTAssertTrue(document.injections.isEmpty)
        }
    }

    func testBridgeRejectionsPreserveStatuses() throws {
        try ExternalImageTestSupport.withTemporaryDirectory { directoryURL in
            let sourceURL = try makeSourceDocument(in: directoryURL)
            let statuses: [RhwpExternalImageOperationStatus] = [
                .referenceNotFound,
                .failure,
                .unknown(77)
            ]
            let references = try statuses.enumerated().map { index, _ in
                let basename = "bridge-\(index).png"
                try ExternalImageTestSupport.write(
                    Data([UInt8(index)]),
                    named: basename,
                    in: directoryURL
                )
                return makeReference(
                    key: "binData:\(index)",
                    basename: basename
                )
            }
            let document = FakeExternalImageDocument(
                referenceResults: [.success(references)],
                injectionStatuses: Dictionary(
                    uniqueKeysWithValues: zip(
                        references.map(\.key),
                        statuses
                    )
                )
            )

            let report = HwpExternalImageResolver.resolve(
                document: document,
                context: context(sourceURL: sourceURL)
            )

            XCTAssertEqual(
                report.resolutions.map(\.decision),
                statuses.map(RhwpExternalResourceDecision.bridgeRejected)
            )
            XCTAssertEqual(document.injections.count, statuses.count)
            XCTAssertEqual(document.referenceQueryCount, 1)
        }
    }

    func testReferenceFailureDoesNotStopLaterValidInjection() throws {
        try ExternalImageTestSupport.withTemporaryDirectory { directoryURL in
            let sourceURL = try makeSourceDocument(in: directoryURL)
            let validData = Data([0xCA, 0xFE])
            try ExternalImageTestSupport.write(
                validData,
                named: "valid.png",
                in: directoryURL
            )
            let missing = makeReference(
                key: "binData:missing",
                basename: "missing.png"
            )
            let valid = makeReference(
                key: "binData:valid",
                basename: "valid.png"
            )
            let loadedValid = makeReference(
                key: valid.key,
                basename: valid.basename,
                loaded: true
            )
            let document = FakeExternalImageDocument(
                referenceResults: [
                    .success([missing, valid]),
                    .success([missing, loadedValid])
                ]
            )

            let report = HwpExternalImageResolver.resolve(
                document: document,
                context: context(sourceURL: sourceURL)
            )

            XCTAssertEqual(
                report.resolutions.map(\.decision),
                [.missing, .injected(byteCount: validData.count)]
            )
            XCTAssertEqual(document.injections.map(\.key), [valid.key])
        }
    }

    func testSuccessfulInjectionWithoutLoadedTransitionFailsVerification() throws {
        try ExternalImageTestSupport.withTemporaryDirectory { directoryURL in
            let sourceURL = try makeSourceDocument(in: directoryURL)
            try ExternalImageTestSupport.write(
                Data([0x01]),
                named: "pending.png",
                in: directoryURL
            )
            let reference = makeReference(
                key: "binData:pending",
                basename: "pending.png"
            )
            let document = FakeExternalImageDocument(
                referenceResults: [
                    .success([reference]),
                    .success([reference])
                ]
            )

            let report = HwpExternalImageResolver.resolve(
                document: document,
                context: context(sourceURL: sourceURL)
            )

            XCTAssertEqual(
                report.resolutions.first?.decision,
                .verificationFailed
            )
            XCTAssertEqual(document.referenceQueryCount, 2)
        }
    }

    func testFinalReferenceQueryFailureFailsAllPendingVerification() throws {
        try ExternalImageTestSupport.withTemporaryDirectory { directoryURL in
            let sourceURL = try makeSourceDocument(in: directoryURL)
            let references = try ["first.png", "second.png"].enumerated().map {
                index,
                basename in
                try ExternalImageTestSupport.write(
                    Data([UInt8(index)]),
                    named: basename,
                    in: directoryURL
                )
                return makeReference(
                    key: "binData:\(index)",
                    basename: basename
                )
            }
            let document = FakeExternalImageDocument(
                referenceResults: [
                    .success(references),
                    .failure(FakeDocumentError.referenceQuery)
                ]
            )

            let report = HwpExternalImageResolver.resolve(
                document: document,
                context: context(sourceURL: sourceURL)
            )

            XCTAssertEqual(
                report.resolutions.map(\.decision),
                [.verificationFailed, .verificationFailed]
            )
            XCTAssertEqual(document.referenceQueryCount, 2)
        }
    }

    func testReportSummaryContainsOnlyPrivacySafeCounts() {
        let report = RhwpExternalResourceReport(
            state: .attempted,
            filenameStatus: .ok,
            resolutions: [
                RhwpExternalResourceResolution(
                    key: "binData:1",
                    decision: .injected(byteCount: 10)
                ),
                RhwpExternalResourceResolution(
                    key: "binData:2",
                    decision: .alreadyLoaded
                ),
                RhwpExternalResourceResolution(
                    key: "binData:3",
                    decision: .missing
                ),
                RhwpExternalResourceResolution(
                    key: "binData:4",
                    decision: .rejectedOutsideSourceDirectory
                ),
                RhwpExternalResourceResolution(
                    key: "binData:5",
                    decision: .tooLarge(actualBytes: 20, limit: 10)
                ),
                RhwpExternalResourceResolution(
                    key: "binData:6",
                    decision: .permissionDenied
                ),
                RhwpExternalResourceResolution(
                    key: "binData:7",
                    decision: .readFailed
                ),
                RhwpExternalResourceResolution(
                    key: "binData:8",
                    decision: .bridgeRejected(.failure)
                ),
                RhwpExternalResourceResolution(
                    key: "binData:9",
                    decision: .verificationFailed
                )
            ]
        )

        XCTAssertEqual(
            report.summary,
            RhwpExternalResourceSummary(
                total: 9,
                injected: 1,
                alreadyLoaded: 1,
                missing: 1,
                rejected: 1,
                tooLarge: 1,
                permissionDenied: 1,
                readFailed: 1,
                bridgeFailed: 2
            )
        )
        XCTAssertEqual(
            report.privacySafeDescription,
            "state=attempted total=9 injected=1 alreadyLoaded=1 "
                + "missing=1 rejected=1 tooLarge=1 permissionDenied=1 "
                + "readFailed=1 bridgeFailed=2"
        )
        XCTAssertFalse(report.privacySafeDescription.contains("secret.png"))
        XCTAssertFalse(report.privacySafeDescription.contains("/private/"))
        XCTAssertEqual(
            Set(
                Mirror(reflecting: report.summary)
                    .children
                    .compactMap(\.label)
            ),
            [
                "total",
                "injected",
                "alreadyLoaded",
                "missing",
                "rejected",
                "tooLarge",
                "permissionDenied",
                "readFailed",
                "bridgeFailed"
            ]
        )
    }

    private func context(
        sourceURL: URL,
        limit: Int = 1024
    ) -> RhwpDocumentOpenContext {
        RhwpDocumentOpenContext(
            sourceURL: sourceURL,
            displayFilename: sourceURL.lastPathComponent,
            maximumExternalResourceBytes: limit
        )
    }

    private func makeSourceDocument(in directoryURL: URL) throws -> URL {
        try ExternalImageTestSupport.write(
            Data([0xD0, 0xCF]),
            named: "document.hwp",
            in: directoryURL
        )
    }

    private func makeReference(
        key: String,
        basename: String,
        originalPath: String = "/private/original/secret.png",
        loaded: Bool = false
    ) -> RhwpExternalImageReference {
        RhwpExternalImageReference(
            key: key,
            binDataId: 1,
            originalPath: originalPath,
            basename: basename,
            fileExtension: "png",
            loaded: loaded
        )
    }
}

private enum FakeDocumentError: Error {
    case referenceQuery
}

private struct FakeInjection: Equatable {
    let key: String
    let data: Data
    let displayPath: String?
}

private final class FakeExternalImageDocument: RhwpExternalImageDocumentAccess {
    private let referenceResults: [Result<[RhwpExternalImageReference], Error>]
    private let injectionStatuses: [String: RhwpExternalImageOperationStatus]

    private(set) var filenames: [String] = []
    private(set) var referenceQueryCount = 0
    private(set) var injections: [FakeInjection] = []

    init(
        referenceResults: [Result<[RhwpExternalImageReference], Error>],
        injectionStatuses: [String: RhwpExternalImageOperationStatus] = [:]
    ) {
        self.referenceResults = referenceResults
        self.injectionStatuses = injectionStatuses
    }

    func setFileName(_ filename: String) -> RhwpExternalImageOperationStatus {
        filenames.append(filename)
        return .ok
    }

    func externalImageReferences() throws -> [RhwpExternalImageReference] {
        defer {
            referenceQueryCount += 1
        }
        guard !referenceResults.isEmpty else {
            return []
        }
        let index = min(referenceQueryCount, referenceResults.count - 1)
        return try referenceResults[index].get()
    }

    func injectExternalImage(
        key: String,
        data: Data,
        displayPath: String?
    ) -> RhwpExternalImageOperationStatus {
        injections.append(
            FakeInjection(
                key: key,
                data: data,
                displayPath: displayPath
            )
        )
        return injectionStatuses[key] ?? .ok
    }
}
