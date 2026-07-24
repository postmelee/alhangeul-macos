import CoreGraphics
import Foundation

struct SmokeError: Error, CustomStringConvertible {
    let description: String
}

struct Timed<Value> {
    let value: Value
    let seconds: Double
}

struct ModeMeasurement {
    let modeName: String
    let outputModeName: String?
    let status: String
    let error: String?
    let outputBytes: Int?
    let outputPages: Int?
    let elapsedSeconds: Double?
    let skiaPages: Int
    let coreGraphicsPages: Int
    let embeddedThumbnailPages: Int
    let fallbackPages: Int
    let pngBytes: Int?
    let renderMs: Double?
    let firstFallback: String?
    let pixelSize: CGSize?
    let skiaRenderMs: Double?
    let pngHeaderValidateMs: Double?
    let pngDecodeMs: Double?
    let pngEncodeMs: Double?
    let coreGraphicsRenderMs: Double?

    static func notApplicable(modeName: String) -> ModeMeasurement {
        ModeMeasurement(
            modeName: modeName,
            outputModeName: nil,
            status: "N/A",
            error: nil,
            outputBytes: nil,
            outputPages: nil,
            elapsedSeconds: nil,
            skiaPages: 0,
            coreGraphicsPages: 0,
            embeddedThumbnailPages: 0,
            fallbackPages: 0,
            pngBytes: nil,
            renderMs: nil,
            firstFallback: nil,
            pixelSize: nil,
            skiaRenderMs: nil,
            pngHeaderValidateMs: nil,
            pngDecodeMs: nil,
            pngEncodeMs: nil,
            coreGraphicsRenderMs: nil
        )
    }
}

struct FileMeasurement {
    let fileName: String
    let filePath: String
    let fileBytes: Int
    let loadStatus: String
    let loadError: String?
    let pageCount: Int?
    let replyType: String?
    let firstPageSize: CGSize?
    let externalResourceState: String?
    let externalResourceSummary: RhwpExternalResourceSummary?
    let coreGraphics: ModeMeasurement?
    let skiaDecode: ModeMeasurement?
    let skiaDirect: ModeMeasurement?
}

struct ResolverCaseResult {
    let label: String
    let rawValue: String?
    let expected: HwpPreviewPNGReplyMode
    let resolved: HwpPreviewPNGReplyMode

    var status: String {
        expected == resolved ? "OK" : "FAIL"
    }
}

struct ResolverContractResult {
    let build: String
    let environmentKey: String
    let cases: [ResolverCaseResult]

    var status: String {
        cases.allSatisfy { $0.status == "OK" } ? "OK" : "FAIL"
    }
}

@main
struct QuickLookSkiaPolicySmoke {
    static func main() throws {
        let args = Array(CommandLine.arguments.dropFirst())
        guard args.count >= 2 else {
            throw SmokeError(description: "usage: quicklook_skia_policy_smoke <output-dir> <hwp-or-hwpx> [...]")
        }

        let outputDir = absoluteURL(args[0], isDirectory: true)
        let inputs = args.dropFirst().map { absoluteURL($0) }
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let resolverContract = makeResolverContract()
        try writeResolverContract(resolverContract, outputDir: outputDir)

        var measurements: [FileMeasurement] = []
        for inputURL in inputs {
            let measurement = measure(inputURL: inputURL)
            measurements.append(measurement)
            try writeDetail(measurement, outputDir: outputDir)
            print("\(measurement.loadStatus) \(measurement.fileName): \(rowSummary(measurement))")
        }

        try writeSummary(
            measurements,
            resolverContract: resolverContract,
            outputDir: outputDir
        )
    }

    private static func measure(inputURL: URL) -> FileMeasurement {
        let fileName = inputURL.lastPathComponent
        let fileBytes = (try? inputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0

        do {
            let context = try HwpPreviewPDFRenderer.load(fileURL: inputURL)
            let replyType = context.pageCount == 1 ? "png" : "pdf"
            let coreGraphics = measureMode(context: context, mode: .coreGraphics)
            let skiaDecode = measureMode(context: context, mode: .skiaDecode)
            let skiaDirect = context.pageCount == 1
                ? measureMode(context: context, mode: .skiaDirect)
                : ModeMeasurement.notApplicable(modeName: HwpPreviewPNGReplyMode.skiaDirect.identifier)

            return FileMeasurement(
                fileName: fileName,
                filePath: inputURL.path,
                fileBytes: fileBytes,
                loadStatus: "OK",
                loadError: nil,
                pageCount: context.pageCount,
                replyType: replyType,
                firstPageSize: context.contentSize,
                externalResourceState: context.externalResourceReport.state.identifier,
                externalResourceSummary: context.externalResourceReport.summary,
                coreGraphics: coreGraphics,
                skiaDecode: skiaDecode,
                skiaDirect: skiaDirect
            )
        } catch {
            return FileMeasurement(
                fileName: fileName,
                filePath: inputURL.path,
                fileBytes: fileBytes,
                loadStatus: "FAIL",
                loadError: String(describing: error),
                pageCount: nil,
                replyType: nil,
                firstPageSize: nil,
                externalResourceState: nil,
                externalResourceSummary: nil,
                coreGraphics: nil,
                skiaDecode: nil,
                skiaDirect: nil
            )
        }
    }

    private static func measureMode(
        context: HwpPreviewDocumentContext,
        mode: HwpPreviewPNGReplyMode
    ) -> ModeMeasurement {
        do {
            if context.pageCount == 1 {
                let timedResult = try timed {
                    try HwpPreviewPNGRenderer.render(
                        context: context,
                        mode: mode
                    )
                }
                return pngMeasurement(
                    modeName: mode.identifier,
                    result: timedResult.value,
                    elapsedSeconds: timedResult.seconds
                )
            }

            guard mode != .skiaDirect else {
                return .notApplicable(modeName: mode.identifier)
            }

            let policy: HwpPageRenderPolicy = mode == .coreGraphics ? .coreGraphicsOnly : .skiaOptIn
            let timedResult = try timed {
                let pdf = try HwpPreviewPDFRenderer.render(
                    context: context,
                    policy: policy,
                    collectDiagnostics: true
                )
                return pdfPolicyResult(
                    outputBytes: pdf.data.count,
                    outputPages: pdfPageCount(data: pdf.data) ?? pdf.pageCount,
                    diagnostics: pdf.pageDiagnostics
                )
            }
            let result = timedResult.value
            return ModeMeasurement(
                modeName: mode.identifier,
                outputModeName: mode.identifier,
                status: "OK",
                error: nil,
                outputBytes: result.outputBytes,
                outputPages: result.outputPages,
                elapsedSeconds: timedResult.seconds,
                skiaPages: result.skiaPages,
                coreGraphicsPages: result.coreGraphicsPages,
                embeddedThumbnailPages: result.embeddedThumbnailPages,
                fallbackPages: result.fallbackPages,
                pngBytes: result.pngBytes,
                renderMs: result.renderMs,
                firstFallback: result.firstFallback,
                pixelSize: nil,
                skiaRenderMs: nil,
                pngHeaderValidateMs: nil,
                pngDecodeMs: nil,
                pngEncodeMs: nil,
                coreGraphicsRenderMs: nil
            )
        } catch {
            return ModeMeasurement(
                modeName: mode.identifier,
                outputModeName: nil,
                status: "FAIL",
                error: String(describing: error),
                outputBytes: nil,
                outputPages: nil,
                elapsedSeconds: nil,
                skiaPages: 0,
                coreGraphicsPages: 0,
                embeddedThumbnailPages: 0,
                fallbackPages: 0,
                pngBytes: nil,
                renderMs: nil,
                firstFallback: nil,
                pixelSize: nil,
                skiaRenderMs: nil,
                pngHeaderValidateMs: nil,
                pngDecodeMs: nil,
                pngEncodeMs: nil,
                coreGraphicsRenderMs: nil
            )
        }
    }

    private static func pngMeasurement(
        modeName: String,
        result: HwpRenderedPreviewPNG,
        elapsedSeconds: Double
    ) -> ModeMeasurement {
        let diagnostics = result.diagnostics
        return ModeMeasurement(
            modeName: modeName,
            outputModeName: diagnostics.outputMode.identifier,
            status: "OK",
            error: nil,
            outputBytes: diagnostics.outputBytes,
            outputPages: 1,
            elapsedSeconds: elapsedSeconds,
            skiaPages: diagnostics.backendUsed == .skia ? 1 : 0,
            coreGraphicsPages: diagnostics.backendUsed == .coreGraphics ? 1 : 0,
            embeddedThumbnailPages: diagnostics.backendUsed == .embeddedThumbnail ? 1 : 0,
            fallbackPages: diagnostics.fallbackReason == nil ? 0 : 1,
            pngBytes: diagnostics.skiaPNGBytes,
            renderMs: diagnostics.durationMs.totalMs,
            firstFallback: diagnostics.fallbackReason,
            pixelSize: diagnostics.pngPixelSize,
            skiaRenderMs: diagnostics.durationMs.skiaRenderMs,
            pngHeaderValidateMs: diagnostics.durationMs.pngHeaderValidateMs,
            pngDecodeMs: diagnostics.durationMs.pngDecodeMs,
            pngEncodeMs: diagnostics.durationMs.pngEncodeMs,
            coreGraphicsRenderMs: diagnostics.durationMs.coreGraphicsRenderMs
        )
    }

    private struct PDFPolicyResult {
        let outputBytes: Int
        let outputPages: Int
        let skiaPages: Int
        let coreGraphicsPages: Int
        let embeddedThumbnailPages: Int
        let fallbackPages: Int
        let pngBytes: Int
        let renderMs: Double
        let firstFallback: String?
    }

    private static func pdfPolicyResult(
        outputBytes: Int,
        outputPages: Int,
        diagnostics: [HwpPreviewPDFPageDiagnostics]
    ) -> PDFPolicyResult {
        var skiaPages = 0
        var coreGraphicsPages = 0
        var embeddedThumbnailPages = 0
        var fallbackPages = 0
        var pngBytes = 0
        var renderMs = 0.0
        var firstFallback: String?

        for page in diagnostics {
            switch page.diagnostics.backendUsed {
            case .coreGraphics:
                coreGraphicsPages += 1
            case .skia:
                skiaPages += 1
            case .embeddedThumbnail:
                embeddedThumbnailPages += 1
            }

            if let fallbackReason = page.diagnostics.fallbackReason {
                fallbackPages += 1
                if firstFallback == nil {
                    firstFallback = String(describing: fallbackReason)
                }
            }
            pngBytes += page.diagnostics.pngBytes ?? 0
            renderMs += page.diagnostics.durationMs.totalMs
        }

        return PDFPolicyResult(
            outputBytes: outputBytes,
            outputPages: outputPages,
            skiaPages: skiaPages,
            coreGraphicsPages: coreGraphicsPages,
            embeddedThumbnailPages: embeddedThumbnailPages,
            fallbackPages: fallbackPages,
            pngBytes: pngBytes,
            renderMs: renderMs,
            firstFallback: firstFallback
        )
    }

    private static func timed<Value>(_ work: () throws -> Value) rethrows -> Timed<Value> {
        let start = DispatchTime.now().uptimeNanoseconds
        let value = try work()
        let end = DispatchTime.now().uptimeNanoseconds
        return Timed(value: value, seconds: Double(end - start) / 1_000_000_000)
    }

    private static func pdfPageCount(data: Data) -> Int? {
        guard
            let provider = CGDataProvider(data: data as CFData),
            let document = CGPDFDocument(provider)
        else {
            return nil
        }
        return document.numberOfPages
    }

    private static func writeSummary(
        _ measurements: [FileMeasurement],
        resolverContract: ResolverContractResult,
        outputDir: URL
    ) throws {
        var lines: [String] = []
        lines.append("# Quick Look Skia Policy Smoke")
        lines.append("")
        lines.append("GeneratedAt: \(ISO8601DateFormatter().string(from: Date()))")
        lines.append("ResolverBuild: \(resolverContract.build)")
        lines.append("ResolverEnvKey: \(resolverContract.environmentKey)")
        lines.append("ResolverContract: \(resolverContract.status)")
        lines.append("")
        lines.append("| File | Load | Reply | Pages | Size | ExternalState | ExternalTotal | ExternalInjected | ExternalAlreadyLoaded | ExternalMissing | ExternalRejected | ExternalTooLarge | ExternalPermissionDenied | ExternalReadFailed | ExternalBridgeFailed | CGStatus | CGBackend | CGFallback | CGBytes | CGSeconds | SkiaDecodeStatus | SkiaDecodeBackend | SkiaDecodeFallback | SkiaDecodeBytes | SkiaDecodePNGBytes | SkiaDecodeSeconds | SkiaDirectStatus | SkiaDirectBackend | SkiaDirectFallback | SkiaDirectBytes | SkiaDirectPNGBytes | SkiaDirectSeconds | SkiaDirectPixel |")
        lines.append("|------|------|-------|-------|------|---------------|---------------|------------------|-----------------------|-----------------|------------------|------------------|--------------------------|--------------------|----------------------|----------|-----------|------------|---------|-----------|------------------|-------------------|--------------------|----------------|-------------------|-------------------|------------------|-------------------|--------------------|----------------|-------------------|-------------------|-----------------|")

        for measurement in measurements {
            lines.append([
                markdownCell(measurement.fileName),
                measurement.loadStatus,
                measurement.replyType ?? "-",
                optionalInt(measurement.pageCount),
                sizeString(measurement.firstPageSize),
                measurement.externalResourceState ?? "-",
                optionalInt(measurement.externalResourceSummary?.total),
                optionalInt(measurement.externalResourceSummary?.injected),
                optionalInt(measurement.externalResourceSummary?.alreadyLoaded),
                optionalInt(measurement.externalResourceSummary?.missing),
                optionalInt(measurement.externalResourceSummary?.rejected),
                optionalInt(measurement.externalResourceSummary?.tooLarge),
                optionalInt(measurement.externalResourceSummary?.permissionDenied),
                optionalInt(measurement.externalResourceSummary?.readFailed),
                optionalInt(measurement.externalResourceSummary?.bridgeFailed),
                measurement.coreGraphics?.status ?? "-",
                backendSummary(measurement.coreGraphics),
                fallbackSummary(measurement.coreGraphics),
                optionalInt(measurement.coreGraphics?.outputBytes),
                secondsString(measurement.coreGraphics?.elapsedSeconds),
                measurement.skiaDecode?.status ?? "-",
                backendSummary(measurement.skiaDecode),
                fallbackSummary(measurement.skiaDecode),
                optionalInt(measurement.skiaDecode?.outputBytes),
                optionalInt(measurement.skiaDecode?.pngBytes),
                secondsString(measurement.skiaDecode?.elapsedSeconds),
                measurement.skiaDirect?.status ?? "-",
                backendSummary(measurement.skiaDirect),
                fallbackSummary(measurement.skiaDirect),
                optionalInt(measurement.skiaDirect?.outputBytes),
                optionalInt(measurement.skiaDirect?.pngBytes),
                secondsString(measurement.skiaDirect?.elapsedSeconds),
                sizeString(measurement.skiaDirect?.pixelSize)
            ].joined(separator: " | ").wrappedTableRow)
        }

        let failed = measurements.filter {
            $0.loadStatus == "FAIL"
                || isFailure($0.coreGraphics)
                || isFailure($0.skiaDecode)
                || isFailure($0.skiaDirect)
        }
        if !failed.isEmpty || resolverContract.status == "FAIL" {
            lines.append("")
            lines.append("## Failures")
            lines.append("")
            if resolverContract.status == "FAIL" {
                lines.append("- resolver contract failed; see `resolver-contract.txt`")
            }
            for measurement in failed {
                lines.append("- `\(measurement.fileName)`: load=\(measurement.loadError ?? "-") cg=\(measurement.coreGraphics?.error ?? "-") skiaDecode=\(measurement.skiaDecode?.error ?? "-") skiaDirect=\(measurement.skiaDirect?.error ?? "-")")
            }
        }

        try lines.joined(separator: "\n").write(
            to: outputDir.appendingPathComponent("summary.txt"),
            atomically: true,
            encoding: .utf8
        )
    }

    private static func writeDetail(_ measurement: FileMeasurement, outputDir: URL) throws {
        let baseName = URL(fileURLWithPath: measurement.fileName)
            .deletingPathExtension()
            .lastPathComponent
        let detailURL = outputDir.appendingPathComponent("\(baseName)-quicklook-skia-policy.txt")
        var lines: [String] = []
        lines.append("File: \(measurement.filePath)")
        lines.append("LoadStatus: \(measurement.loadStatus)")
        if let loadError = measurement.loadError {
            lines.append("LoadError: \(loadError)")
        }
        lines.append("FileBytes: \(measurement.fileBytes)")
        lines.append("ReplyType: \(measurement.replyType ?? "-")")
        lines.append("PageCount: \(optionalInt(measurement.pageCount))")
        lines.append("FirstPageSize: \(sizeString(measurement.firstPageSize))")
        lines.append("ExternalResourceState: \(measurement.externalResourceState ?? "-")")
        lines.append("ExternalResourceTotal: \(optionalInt(measurement.externalResourceSummary?.total))")
        lines.append("ExternalResourceInjected: \(optionalInt(measurement.externalResourceSummary?.injected))")
        lines.append("ExternalResourceAlreadyLoaded: \(optionalInt(measurement.externalResourceSummary?.alreadyLoaded))")
        lines.append("ExternalResourceMissing: \(optionalInt(measurement.externalResourceSummary?.missing))")
        lines.append("ExternalResourceRejected: \(optionalInt(measurement.externalResourceSummary?.rejected))")
        lines.append("ExternalResourceTooLarge: \(optionalInt(measurement.externalResourceSummary?.tooLarge))")
        lines.append("ExternalResourcePermissionDenied: \(optionalInt(measurement.externalResourceSummary?.permissionDenied))")
        lines.append("ExternalResourceReadFailed: \(optionalInt(measurement.externalResourceSummary?.readFailed))")
        lines.append("ExternalResourceBridgeFailed: \(optionalInt(measurement.externalResourceSummary?.bridgeFailed))")
        appendMode(measurement.coreGraphics, name: "CoreGraphics", lines: &lines)
        appendMode(measurement.skiaDecode, name: "SkiaDecode", lines: &lines)
        appendMode(measurement.skiaDirect, name: "SkiaDirect", lines: &lines)
        try lines.joined(separator: "\n").write(to: detailURL, atomically: true, encoding: .utf8)
    }

    private static func appendMode(_ mode: ModeMeasurement?, name: String, lines: inout [String]) {
        lines.append("")
        lines.append("[\(name)]")
        guard let mode else {
            lines.append("Status: -")
            return
        }
        lines.append("Mode: \(mode.modeName)")
        lines.append("OutputMode: \(mode.outputModeName ?? "-")")
        lines.append("Status: \(mode.status)")
        if let error = mode.error {
            lines.append("Error: \(error)")
        }
        lines.append("OutputBytes: \(optionalInt(mode.outputBytes))")
        lines.append("OutputPages: \(optionalInt(mode.outputPages))")
        lines.append("ElapsedSeconds: \(secondsString(mode.elapsedSeconds))")
        lines.append("Backend: \(backendSummary(mode))")
        lines.append("SkiaPages: \(mode.skiaPages)")
        lines.append("CoreGraphicsPages: \(mode.coreGraphicsPages)")
        lines.append("EmbeddedThumbnailPages: \(mode.embeddedThumbnailPages)")
        lines.append("FallbackPages: \(mode.fallbackPages)")
        lines.append("FirstFallback: \(mode.firstFallback ?? "-")")
        lines.append("PNGBytes: \(optionalInt(mode.pngBytes))")
        lines.append("PixelSize: \(sizeString(mode.pixelSize))")
        lines.append("RenderMs: \(millisecondsString(mode.renderMs))")
        lines.append("SkiaRenderMs: \(millisecondsString(mode.skiaRenderMs))")
        lines.append("PNGHeaderValidateMs: \(millisecondsString(mode.pngHeaderValidateMs))")
        lines.append("PNGDecodeMs: \(millisecondsString(mode.pngDecodeMs))")
        lines.append("PNGEncodeMs: \(millisecondsString(mode.pngEncodeMs))")
        lines.append("CoreGraphicsRenderMs: \(millisecondsString(mode.coreGraphicsRenderMs))")
    }

    private static func makeResolverContract() -> ResolverContractResult {
        let key = HwpQuickLookPNGReplyModeResolver.environmentKey
        let cases: [(label: String, rawValue: String?, expected: HwpPreviewPNGReplyMode)] = [
            ("missing", nil, .coreGraphics),
            ("empty", "", .coreGraphics),
            ("invalid", "banana", .coreGraphics),
            ("coreGraphics", "coreGraphics", .coreGraphics),
            ("coreGraphicsOnly", "coreGraphicsOnly", .coreGraphics),
            ("skia", "skia", expectedSkiaMode()),
            ("skiaDecode", "skiaDecode", expectedSkiaMode()),
            ("skiaOptIn", "skiaOptIn", expectedSkiaMode()),
            ("direct", "direct", expectedDirectMode()),
            ("skiaDirect", "skiaDirect", expectedDirectMode())
        ]

        let results = cases.map { item in
            let environment: [String: String]
            if let rawValue = item.rawValue {
                environment = [key: rawValue]
            } else {
                environment = [:]
            }
            return ResolverCaseResult(
                label: item.label,
                rawValue: item.rawValue,
                expected: item.expected,
                resolved: HwpQuickLookPNGReplyModeResolver.resolve(environment: environment)
            )
        }

        return ResolverContractResult(
            build: resolverBuildString(),
            environmentKey: key,
            cases: results
        )
    }

    private static func writeResolverContract(
        _ contract: ResolverContractResult,
        outputDir: URL
    ) throws {
        var lines: [String] = []
        lines.append("ResolverBuild: \(contract.build)")
        lines.append("ResolverEnvKey: \(contract.environmentKey)")
        lines.append("ResolverContract: \(contract.status)")
        lines.append("")
        lines.append("| Case | RawValue | Expected | Resolved | Status |")
        lines.append("|------|----------|----------|----------|--------|")
        for item in contract.cases {
            lines.append([
                item.label,
                item.rawValue ?? "<missing>",
                item.expected.identifier,
                item.resolved.identifier,
                item.status
            ].joined(separator: " | ").wrappedTableRow)
        }
        try lines.joined(separator: "\n").write(
            to: outputDir.appendingPathComponent("resolver-contract.txt"),
            atomically: true,
            encoding: .utf8
        )
    }

    private static func expectedSkiaMode() -> HwpPreviewPNGReplyMode {
#if DEBUG
        .skiaDecode
#else
        .coreGraphics
#endif
    }

    private static func expectedDirectMode() -> HwpPreviewPNGReplyMode {
#if DEBUG
        .skiaDirect
#else
        .coreGraphics
#endif
    }

    private static func resolverBuildString() -> String {
#if DEBUG
        "DEBUG"
#else
        "RELEASE"
#endif
    }

    private static func rowSummary(_ measurement: FileMeasurement) -> String {
        guard measurement.loadStatus == "OK" else {
            return measurement.loadError ?? "load failed"
        }
        return "reply=\(measurement.replyType ?? "-") pages=\(optionalInt(measurement.pageCount)) external=\(measurement.externalResourceState ?? "-"):\(optionalInt(measurement.externalResourceSummary?.total)) cg=\(backendSummary(measurement.coreGraphics)) skiaDecode=\(backendSummary(measurement.skiaDecode)) skiaDirect=\(backendSummary(measurement.skiaDirect)) directFallback=\(fallbackSummary(measurement.skiaDirect))"
    }

    private static func isFailure(_ measurement: ModeMeasurement?) -> Bool {
        measurement?.status == "FAIL"
    }

    private static func backendSummary(_ measurement: ModeMeasurement?) -> String {
        guard let measurement, measurement.status == "OK" else {
            return "-"
        }
        return "skia:\(measurement.skiaPages),cg:\(measurement.coreGraphicsPages),embedded:\(measurement.embeddedThumbnailPages)"
    }

    private static func fallbackSummary(_ measurement: ModeMeasurement?) -> String {
        guard let measurement, measurement.status == "OK" else {
            return "-"
        }
        if measurement.fallbackPages == 0 {
            return "0"
        }
        return "\(measurement.fallbackPages)(\(measurement.firstFallback ?? "unknown"))"
    }

    private static func absoluteURL(_ path: String, isDirectory: Bool = false) -> URL {
        let url = URL(fileURLWithPath: path, isDirectory: isDirectory)
        if path.hasPrefix("/") {
            return url.standardizedFileURL
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(path, isDirectory: isDirectory)
            .standardizedFileURL
    }

    private static func optionalInt(_ value: Int?) -> String {
        guard let value else { return "-" }
        return "\(value)"
    }

    private static func secondsString(_ value: Double?) -> String {
        guard let value else { return "-" }
        return String(format: "%.6f", value)
    }

    private static func millisecondsString(_ value: Double?) -> String {
        guard let value else { return "-" }
        return String(format: "%.3f", value)
    }

    private static func sizeString(_ size: CGSize?) -> String {
        guard let size else { return "-" }
        return "\(Int(size.width))x\(Int(size.height))"
    }

    private static func markdownCell(_ value: String) -> String {
        value.replacingOccurrences(of: "|", with: "\\|")
    }
}

private extension String {
    var wrappedTableRow: String {
        "| \(self) |"
    }
}
