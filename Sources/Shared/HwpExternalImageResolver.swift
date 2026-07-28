import Foundation

struct RhwpDocumentOpenContext: Equatable {
    let sourceURL: URL?
    let displayFilename: String?
    let maximumExternalResourceBytes: Int
}

enum RhwpExternalResourceReportState: Equatable {
    case disabledNoSourceURL
    case disabledNonFileURL
    case attempted
    case referenceQueryFailed

    var identifier: String {
        switch self {
        case .disabledNoSourceURL:
            return "disabledNoSourceURL"
        case .disabledNonFileURL:
            return "disabledNonFileURL"
        case .attempted:
            return "attempted"
        case .referenceQueryFailed:
            return "referenceQueryFailed"
        }
    }
}

enum RhwpExternalResourceDecision: Equatable {
    case alreadyLoaded
    case injected(byteCount: Int)
    case missing
    case rejectedInvalidBasename
    case rejectedOutsideSourceDirectory
    case rejectedSourceDocument
    case rejectedNonRegularFile
    case tooLarge(actualBytes: Int?, limit: Int)
    case permissionDenied
    case readFailed
    case bridgeRejected(RhwpExternalImageOperationStatus)
    case verificationFailed
}

struct RhwpExternalResourceResolution: Equatable {
    let key: String
    let decision: RhwpExternalResourceDecision
}

struct RhwpExternalResourceSummary: Equatable, CustomStringConvertible {
    let total: Int
    let injected: Int
    let alreadyLoaded: Int
    let missing: Int
    let rejected: Int
    let tooLarge: Int
    let permissionDenied: Int
    let readFailed: Int
    let bridgeFailed: Int

    var description: String {
        [
            "total=\(total)",
            "injected=\(injected)",
            "alreadyLoaded=\(alreadyLoaded)",
            "missing=\(missing)",
            "rejected=\(rejected)",
            "tooLarge=\(tooLarge)",
            "permissionDenied=\(permissionDenied)",
            "readFailed=\(readFailed)",
            "bridgeFailed=\(bridgeFailed)"
        ].joined(separator: " ")
    }
}

struct RhwpExternalResourceReport: Equatable {
    let state: RhwpExternalResourceReportState
    let filenameStatus: RhwpExternalImageOperationStatus?
    let resolutions: [RhwpExternalResourceResolution]

    var summary: RhwpExternalResourceSummary {
        var injected = 0
        var alreadyLoaded = 0
        var missing = 0
        var rejected = 0
        var tooLarge = 0
        var permissionDenied = 0
        var readFailed = 0
        var bridgeFailed = 0

        for resolution in resolutions {
            switch resolution.decision {
            case .injected:
                injected += 1
            case .alreadyLoaded:
                alreadyLoaded += 1
            case .missing:
                missing += 1
            case .rejectedInvalidBasename,
                 .rejectedOutsideSourceDirectory,
                 .rejectedSourceDocument,
                 .rejectedNonRegularFile:
                rejected += 1
            case .tooLarge:
                tooLarge += 1
            case .permissionDenied:
                permissionDenied += 1
            case .readFailed:
                readFailed += 1
            case .bridgeRejected, .verificationFailed:
                bridgeFailed += 1
            }
        }

        return RhwpExternalResourceSummary(
            total: resolutions.count,
            injected: injected,
            alreadyLoaded: alreadyLoaded,
            missing: missing,
            rejected: rejected,
            tooLarge: tooLarge,
            permissionDenied: permissionDenied,
            readFailed: readFailed,
            bridgeFailed: bridgeFailed
        )
    }

    var privacySafeDescription: String {
        "state=\(state.identifier) \(summary)"
    }
}

struct RhwpDocumentOpenResult {
    let document: RhwpDocument
    let externalResourceReport: RhwpExternalResourceReport
}

protocol RhwpExternalImageDocumentAccess: AnyObject {
    @discardableResult
    func setFileName(_ filename: String) -> RhwpExternalImageOperationStatus

    func externalImageReferences() throws -> [RhwpExternalImageReference]

    @discardableResult
    func injectExternalImage(
        key: String,
        data: Data,
        displayPath: String?
    ) -> RhwpExternalImageOperationStatus
}

extension RhwpDocument: RhwpExternalImageDocumentAccess {}

enum HwpExternalImageResolver {
    typealias DataLoader = (URL) throws -> Data

    static func open(
        data: Data,
        context: RhwpDocumentOpenContext,
        dataLoader: DataLoader = loadMappedData
    ) throws -> RhwpDocumentOpenResult {
        let document = try RhwpDocument(
            data: data,
            filename: context.displayFilename
        )
        let report = resolve(
            document: document,
            context: context,
            dataLoader: dataLoader
        )
        return RhwpDocumentOpenResult(
            document: document,
            externalResourceReport: report
        )
    }

    static func resolve(
        document: RhwpExternalImageDocumentAccess,
        context: RhwpDocumentOpenContext,
        dataLoader: DataLoader = loadMappedData
    ) -> RhwpExternalResourceReport {
        let filenameStatus = context.displayFilename.map(document.setFileName)

        guard let sourceURL = context.sourceURL else {
            return RhwpExternalResourceReport(
                state: .disabledNoSourceURL,
                filenameStatus: filenameStatus,
                resolutions: []
            )
        }
        guard sourceURL.isFileURL else {
            return RhwpExternalResourceReport(
                state: .disabledNonFileURL,
                filenameStatus: filenameStatus,
                resolutions: []
            )
        }

        let references: [RhwpExternalImageReference]
        do {
            references = try document.externalImageReferences()
        } catch {
            return RhwpExternalResourceReport(
                state: .referenceQueryFailed,
                filenameStatus: filenameStatus,
                resolutions: []
            )
        }

        let limit = max(0, context.maximumExternalResourceBytes)
        var resolutions: [RhwpExternalResourceResolution] = []
        resolutions.reserveCapacity(references.count)
        var pendingVerification: [(index: Int, key: String)] = []

        for reference in references {
            if reference.loaded {
                resolutions.append(
                    RhwpExternalResourceResolution(
                        key: reference.key,
                        decision: .alreadyLoaded
                    )
                )
                continue
            }

            let resolution = resolveReference(
                reference,
                sourceURL: sourceURL,
                maximumBytes: limit,
                document: document,
                dataLoader: dataLoader
            )
            let resolutionIndex = resolutions.count
            resolutions.append(resolution)
            if case .injected = resolution.decision {
                pendingVerification.append(
                    (resolutionIndex, reference.key)
                )
            }
        }

        verifyPendingInjections(
            pendingVerification,
            document: document,
            resolutions: &resolutions
        )

        return RhwpExternalResourceReport(
            state: .attempted,
            filenameStatus: filenameStatus,
            resolutions: resolutions
        )
    }

    private static func resolveReference(
        _ reference: RhwpExternalImageReference,
        sourceURL: URL,
        maximumBytes: Int,
        document: RhwpExternalImageDocumentAccess,
        dataLoader: DataLoader
    ) -> RhwpExternalResourceResolution {
        guard isValidBasename(reference.basename) else {
            return resolution(reference, .rejectedInvalidBasename)
        }

        let standardizedSource = sourceURL.standardizedFileURL
        let sourceParent = standardizedSource
            .deletingLastPathComponent()
            .resolvingSymlinksInPath()
            .standardizedFileURL
        let candidate = standardizedSource
            .deletingLastPathComponent()
            .appendingPathComponent(reference.basename, isDirectory: false)
            .standardizedFileURL
        let resolvedCandidate = candidate
            .resolvingSymlinksInPath()
            .standardizedFileURL
        let resolvedSource = standardizedSource
            .resolvingSymlinksInPath()
            .standardizedFileURL

        if sameFilePath(candidate, standardizedSource)
            || sameFilePath(resolvedCandidate, resolvedSource) {
            return resolution(reference, .rejectedSourceDocument)
        }
        guard sameFilePath(
            resolvedCandidate.deletingLastPathComponent(),
            sourceParent
        ) else {
            return resolution(reference, .rejectedOutsideSourceDirectory)
        }

        let resourceValues: URLResourceValues
        do {
            resourceValues = try candidate.resourceValues(
                forKeys: [.isRegularFileKey, .fileSizeKey]
            )
        } catch {
            return resolution(reference, decision(forFileError: error))
        }

        guard resourceValues.isRegularFile == true else {
            return resolution(reference, .rejectedNonRegularFile)
        }
        if let fileSize = resourceValues.fileSize, fileSize > maximumBytes {
            return resolution(
                reference,
                .tooLarge(actualBytes: fileSize, limit: maximumBytes)
            )
        }

        let data: Data
        do {
            data = try dataLoader(candidate)
        } catch {
            return resolution(reference, decision(forFileError: error))
        }
        guard data.count <= maximumBytes else {
            return resolution(
                reference,
                .tooLarge(actualBytes: data.count, limit: maximumBytes)
            )
        }

        let status = document.injectExternalImage(
            key: reference.key,
            data: data,
            displayPath: reference.basename
        )
        switch status {
        case .ok:
            return resolution(
                reference,
                .injected(byteCount: data.count)
            )
        case .alreadyLoaded:
            return resolution(reference, .alreadyLoaded)
        default:
            return resolution(reference, .bridgeRejected(status))
        }
    }

    private static func verifyPendingInjections(
        _ pending: [(index: Int, key: String)],
        document: RhwpExternalImageDocumentAccess,
        resolutions: inout [RhwpExternalResourceResolution]
    ) {
        guard !pending.isEmpty else {
            return
        }

        let loadedKeys: Set<String>
        do {
            loadedKeys = Set(
                try document.externalImageReferences()
                    .filter(\.loaded)
                    .map(\.key)
            )
        } catch {
            for item in pending {
                resolutions[item.index] = RhwpExternalResourceResolution(
                    key: item.key,
                    decision: .verificationFailed
                )
            }
            return
        }

        for item in pending where !loadedKeys.contains(item.key) {
            resolutions[item.index] = RhwpExternalResourceResolution(
                key: item.key,
                decision: .verificationFailed
            )
        }
    }

    private static func isValidBasename(_ basename: String) -> Bool {
        !basename.isEmpty
            && basename != "."
            && basename != ".."
            && !basename.contains("/")
            && !basename.contains("\\")
            && !basename.contains("\0")
    }

    private static func sameFilePath(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.standardizedFileURL.path == rhs.standardizedFileURL.path
    }

    private static func decision(
        forFileError error: Error
    ) -> RhwpExternalResourceDecision {
        let nsError = error as NSError

        if nsError.domain == NSCocoaErrorDomain {
            switch nsError.code {
            case NSFileNoSuchFileError, NSFileReadNoSuchFileError:
                return .missing
            case NSFileReadNoPermissionError:
                return .permissionDenied
            default:
                break
            }
        }

        if nsError.domain == NSPOSIXErrorDomain {
            switch nsError.code {
            case Int(POSIXErrorCode.ENOENT.rawValue):
                return .missing
            case Int(POSIXErrorCode.EACCES.rawValue),
                 Int(POSIXErrorCode.EPERM.rawValue):
                return .permissionDenied
            default:
                break
            }
        }

        if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError,
           underlyingError !== nsError {
            let underlyingDecision = decision(forFileError: underlyingError)
            if underlyingDecision != .readFailed {
                return underlyingDecision
            }
        }

        return .readFailed
    }

    private static func resolution(
        _ reference: RhwpExternalImageReference,
        _ decision: RhwpExternalResourceDecision
    ) -> RhwpExternalResourceResolution {
        RhwpExternalResourceResolution(
            key: reference.key,
            decision: decision
        )
    }

    private static func loadMappedData(from url: URL) throws -> Data {
        try Data(contentsOf: url, options: [.mappedIfSafe])
    }
}
