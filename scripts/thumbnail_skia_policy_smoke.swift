import CoreGraphics
import Foundation

struct SmokeError: Error, CustomStringConvertible {
    let description: String
}

struct Timed<Value> {
    let value: Value
    let seconds: Double
}

struct RequestPreset {
    let name: String
    let maximumSize: CGSize
    let scale: CGFloat

    var display: String {
        let doubleScale = Double(scale)
        let scaleString = doubleScale.rounded() == doubleScale
            ? "\(Int(doubleScale))"
            : String(format: "%.2f", doubleScale)
        return "\(name):\(Int(maximumSize.width))x\(Int(maximumSize.height))@\(scaleString)"
    }
}

struct RenderMeasurement {
    let policyName: String
    let request: RequestPreset
    let status: String
    let error: String?
    let cacheEvent: String?
    let requestedBucket: String?
    let matchedBucket: String?
    let signature: String?
    let backend: String?
    let fallback: String?
    let pageSize: CGSize?
    let pixelSize: CGSize?
    let pngBytes: Int?
    let outputBytes: Int?
    let renderMs: Double?
    let elapsedSeconds: Double?
}

struct ResolverMeasurement {
    let caseName: String
    let envValue: String?
    let expectedPolicy: String
    let resolvedPolicy: String

    var status: String {
        expectedPolicy == resolvedPolicy ? "OK" : "FAIL"
    }
}

struct FileMeasurement {
    let fileName: String
    let filePath: String
    let fileBytes: Int
    let coreGraphics: [RenderMeasurement]
    let skiaOptIn: [RenderMeasurement]
}

struct CacheSeparationMeasurement {
    let fileName: String
    let status: String
    let coreGraphicsFirstCache: String
    let skiaOptInFirstCache: String
    let coreGraphicsSignature: String
    let skiaOptInSignature: String
    let note: String
}

@main
struct ThumbnailSkiaPolicySmoke {
    static func main() throws {
        let parsed = try parseArguments(Array(CommandLine.arguments.dropFirst()))
        try FileManager.default.createDirectory(at: parsed.outputDir, withIntermediateDirectories: true)

        let resolverMeasurements = measureResolverContract()
        try writeResolverDetail(resolverMeasurements, outputDir: parsed.outputDir)
        print("resolver: \(resolverStatusSummary(resolverMeasurements))")

        var measurements: [FileMeasurement] = []
        for inputURL in parsed.inputs {
            let measurement = measure(inputURL: inputURL, requests: parsed.requests)
            measurements.append(measurement)
            try writeDetail(measurement, outputDir: parsed.outputDir)
            print("\(measurement.fileName): \(rowSummary(measurement))")
        }

        try writeSummary(
            measurements,
            requests: parsed.requests,
            resolverMeasurements: resolverMeasurements,
            outputDir: parsed.outputDir
        )
    }

    private struct ParsedArguments {
        let outputDir: URL
        let requests: [RequestPreset]
        let inputs: [URL]
    }

    private static func parseArguments(_ args: [String]) throws -> ParsedArguments {
        guard !args.isEmpty else {
            throw SmokeError(description: usage)
        }

        let outputDir = absoluteURL(args[0], isDirectory: true)
        var requests: [RequestPreset] = []
        var inputs: [URL] = []
        var index = 1
        while index < args.count {
            let arg = args[index]
            if arg == "--request" {
                guard index + 1 < args.count else {
                    throw SmokeError(description: "--request requires NAME:WIDTHxHEIGHT@SCALE")
                }
                requests.append(try parseRequest(args[index + 1]))
                index += 2
            } else if arg == "--help" || arg == "-h" {
                throw SmokeError(description: usage)
            } else if arg.hasPrefix("--") {
                throw SmokeError(description: "unknown option \(arg)\n\(usage)")
            } else {
                inputs.append(absoluteURL(arg))
                index += 1
            }
        }

        guard !inputs.isEmpty else {
            throw SmokeError(description: usage)
        }
        return ParsedArguments(
            outputDir: outputDir,
            requests: requests.isEmpty ? defaultRequests : requests,
            inputs: inputs
        )
    }

    private static var usage: String {
        "usage: thumbnail_skia_policy_smoke <output-dir> [--request NAME:WIDTHxHEIGHT@SCALE] <hwp-or-hwpx> [...]"
    }

    private static let defaultRequests: [RequestPreset] = [
        RequestPreset(name: "large", maximumSize: CGSize(width: 512, height: 512), scale: 2),
        RequestPreset(name: "large-repeat", maximumSize: CGSize(width: 512, height: 512), scale: 2),
        RequestPreset(name: "medium-after-large", maximumSize: CGSize(width: 256, height: 256), scale: 2),
        RequestPreset(name: "small-after-large", maximumSize: CGSize(width: 128, height: 128), scale: 1)
    ]

    private static var resolverBuildMode: String {
#if DEBUG
        "DEBUG"
#else
        "RELEASE"
#endif
    }

    private static func parseRequest(_ value: String) throws -> RequestPreset {
        let nameAndRest = value.split(separator: ":", maxSplits: 1).map(String.init)
        guard nameAndRest.count == 2 else {
            throw SmokeError(description: "invalid request '\(value)': expected NAME:WIDTHxHEIGHT@SCALE")
        }

        let sizeAndScale = nameAndRest[1].split(separator: "@", maxSplits: 1).map(String.init)
        guard sizeAndScale.count == 2 else {
            throw SmokeError(description: "invalid request '\(value)': expected NAME:WIDTHxHEIGHT@SCALE")
        }

        let widthAndHeight = sizeAndScale[0].split(separator: "x", maxSplits: 1).map(String.init)
        guard
            widthAndHeight.count == 2,
            let width = Double(widthAndHeight[0]),
            let height = Double(widthAndHeight[1]),
            let scale = Double(sizeAndScale[1]),
            width > 0,
            height > 0,
            scale > 0
        else {
            throw SmokeError(description: "invalid request '\(value)': size and scale must be positive numbers")
        }

        return RequestPreset(
            name: nameAndRest[0],
            maximumSize: CGSize(width: width, height: height),
            scale: CGFloat(scale)
        )
    }

    private static func measure(inputURL: URL, requests: [RequestPreset]) -> FileMeasurement {
        let fileName = inputURL.lastPathComponent
        let fileBytes = (try? inputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let coreGraphics = measurePolicy(
            inputURL: inputURL,
            requests: requests,
            policyName: "coreGraphicsOnly",
            policy: .coreGraphicsOnly
        )
        let skiaOptIn = measurePolicy(
            inputURL: inputURL,
            requests: requests,
            policyName: "skiaOptIn",
            policy: .skiaOptIn
        )
        return FileMeasurement(
            fileName: fileName,
            filePath: inputURL.path,
            fileBytes: fileBytes,
            coreGraphics: coreGraphics,
            skiaOptIn: skiaOptIn
        )
    }

    private static func measurePolicy(
        inputURL: URL,
        requests: [RequestPreset],
        policyName: String,
        policy: HwpPageRenderPolicy
    ) -> [RenderMeasurement] {
        requests.map { request in
            measureRender(inputURL: inputURL, request: request, policyName: policyName, policy: policy)
        }
    }

    private static func measureRender(
        inputURL: URL,
        request: RequestPreset,
        policyName: String,
        policy: HwpPageRenderPolicy
    ) -> RenderMeasurement {
        do {
            let renderRequest = try HwpThumbnailRenderRequest(
                fileURL: inputURL,
                maximumSize: request.maximumSize,
                scale: request.scale,
                policy: policy
            )
            let timedResult = try timedRender(request: renderRequest)
            let result = timedResult.value
            let diagnostics = result.page.diagnostics
            let outputPNG = try HwpPageImageRenderer.encodePNG(result.page.image)
            return RenderMeasurement(
                policyName: policyName,
                request: request,
                status: "OK",
                error: nil,
                cacheEvent: result.cacheEvent.description,
                requestedBucket: bucketString(result.requestedKey),
                matchedBucket: bucketString(result.matchedKey),
                signature: result.requestedKey.renderSignature.identifier,
                backend: backendName(diagnostics.backendUsed),
                fallback: diagnostics.fallbackReason.map(fallbackReasonName) ?? "-",
                pageSize: diagnostics.pageSize,
                pixelSize: diagnostics.pixelSize,
                pngBytes: diagnostics.pngBytes,
                outputBytes: outputPNG.count,
                renderMs: diagnostics.durationMs.totalMs,
                elapsedSeconds: timedResult.seconds
            )
        } catch {
            return RenderMeasurement(
                policyName: policyName,
                request: request,
                status: "FAIL",
                error: String(describing: error),
                cacheEvent: nil,
                requestedBucket: nil,
                matchedBucket: nil,
                signature: nil,
                backend: nil,
                fallback: nil,
                pageSize: nil,
                pixelSize: nil,
                pngBytes: nil,
                outputBytes: nil,
                renderMs: nil,
                elapsedSeconds: nil
            )
        }
    }

    private static func timedRender(request: HwpThumbnailRenderRequest) throws -> Timed<HwpThumbnailRenderResult> {
        let semaphore = DispatchSemaphore(value: 0)
        let start = DispatchTime.now().uptimeNanoseconds
        var captured: Result<HwpThumbnailRenderResult, Error>?

        HwpThumbnailRenderCache.shared.renderedPageResult(for: request) { result in
            captured = result
            semaphore.signal()
        }

        semaphore.wait()
        let end = DispatchTime.now().uptimeNanoseconds
        switch captured {
        case .success(let result):
            return Timed(value: result, seconds: Double(end - start) / 1_000_000_000)
        case .failure(let error):
            throw error
        case .none:
            throw SmokeError(description: "thumbnail render completed without result")
        }
    }

    private static func writeSummary(
        _ measurements: [FileMeasurement],
        requests: [RequestPreset],
        resolverMeasurements: [ResolverMeasurement],
        outputDir: URL
    ) throws {
        var lines: [String] = []
        lines.append("# Thumbnail Skia Policy Smoke")
        lines.append("")
        lines.append("GeneratedAt: \(ISO8601DateFormatter().string(from: Date()))")
        lines.append("Requests: \(requests.map(\.display).joined(separator: ", "))")
        lines.append("ResolverBuild: \(resolverBuildMode)")
        lines.append("ResolverEnvKey: \(HwpThumbnailPolicyResolver.environmentKey)")
        lines.append("ResolverContract: \(resolverStatusSummary(resolverMeasurements))")
        lines.append("")
        appendResolverContract(resolverMeasurements, lines: &lines)
        lines.append("")
        lines.append("| File | Policy | Request | Status | Cache | RequestedBucket | MatchedBucket | Backend | Fallback | Pixel | OutputBytes | PNGBytes | RenderMs | Seconds |")
        lines.append("|------|--------|---------|--------|-------|-----------------|---------------|---------|----------|-------|-------------|----------|----------|---------|")

        for measurement in measurements {
            for render in measurement.coreGraphics + measurement.skiaOptIn {
                lines.append(summaryRow(fileName: measurement.fileName, render: render))
            }
        }

        lines.append("")
        lines.append("## Cache Signature Separation")
        lines.append("")
        lines.append("| File | Status | CoreFirstCache | SkiaFirstCache | CoreSignature | SkiaSignature | Note |")
        lines.append("|------|--------|----------------|----------------|---------------|---------------|------|")
        for measurement in measurements {
            lines.append(cacheSeparationRow(cacheSeparation(for: measurement)))
        }

        let failed = measurements.flatMap { $0.coreGraphics + $0.skiaOptIn }.filter { $0.status == "FAIL" }
        if !failed.isEmpty {
            lines.append("")
            lines.append("## Failures")
            lines.append("")
            for render in failed {
                lines.append("- `\(render.policyName)` `\(render.request.display)`: \(render.error ?? "-")")
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
        let detailURL = outputDir.appendingPathComponent("\(baseName)-thumbnail-skia-policy.txt")
        var lines: [String] = []
        lines.append("File: \(measurement.filePath)")
        lines.append("FileBytes: \(measurement.fileBytes)")
        appendCacheSeparation(cacheSeparation(for: measurement), lines: &lines)
        appendPolicy(measurement.coreGraphics, name: "CoreGraphics", lines: &lines)
        appendPolicy(measurement.skiaOptIn, name: "SkiaOptIn", lines: &lines)
        try lines.joined(separator: "\n").write(to: detailURL, atomically: true, encoding: .utf8)
    }

    private static func writeResolverDetail(
        _ resolverMeasurements: [ResolverMeasurement],
        outputDir: URL
    ) throws {
        var lines: [String] = []
        lines.append("# Thumbnail Policy Resolver Contract")
        lines.append("")
        lines.append("ResolverBuild: \(resolverBuildMode)")
        lines.append("ResolverEnvKey: \(HwpThumbnailPolicyResolver.environmentKey)")
        lines.append("ResolverContract: \(resolverStatusSummary(resolverMeasurements))")
        lines.append("")
        appendResolverContract(resolverMeasurements, lines: &lines)
        try lines.joined(separator: "\n").write(
            to: outputDir.appendingPathComponent("resolver-contract.txt"),
            atomically: true,
            encoding: .utf8
        )
    }

    private static func appendResolverContract(
        _ resolverMeasurements: [ResolverMeasurement],
        lines: inout [String]
    ) {
        lines.append("## Resolver Contract")
        lines.append("")
        lines.append("| Case | EnvValue | Expected | Resolved | Status |")
        lines.append("|------|----------|----------|----------|--------|")
        for measurement in resolverMeasurements {
            lines.append(resolverRow(measurement))
        }
    }

    private static func appendCacheSeparation(
        _ check: CacheSeparationMeasurement,
        lines: inout [String]
    ) {
        lines.append("")
        lines.append("[CacheSignatureSeparation]")
        lines.append("Status: \(check.status)")
        lines.append("CoreFirstCache: \(check.coreGraphicsFirstCache)")
        lines.append("SkiaFirstCache: \(check.skiaOptInFirstCache)")
        lines.append("CoreSignature: \(check.coreGraphicsSignature)")
        lines.append("SkiaSignature: \(check.skiaOptInSignature)")
        lines.append("Note: \(check.note)")
    }

    private static func appendPolicy(_ renders: [RenderMeasurement], name: String, lines: inout [String]) {
        lines.append("")
        lines.append("[\(name)]")
        for render in renders {
            lines.append("")
            lines.append("Request: \(render.request.display)")
            lines.append("Status: \(render.status)")
            if let error = render.error {
                lines.append("Error: \(error)")
            }
            lines.append("CacheEvent: \(render.cacheEvent ?? "-")")
            lines.append("RequestedBucket: \(render.requestedBucket ?? "-")")
            lines.append("MatchedBucket: \(render.matchedBucket ?? "-")")
            lines.append("Signature: \(render.signature ?? "-")")
            lines.append("Backend: \(render.backend ?? "-")")
            lines.append("Fallback: \(render.fallback ?? "-")")
            lines.append("PageSize: \(sizeString(render.pageSize))")
            lines.append("PixelSize: \(sizeString(render.pixelSize))")
            lines.append("PNGBytes: \(optionalInt(render.pngBytes))")
            lines.append("OutputBytes: \(optionalInt(render.outputBytes))")
            lines.append("RenderMs: \(optionalMilliseconds(render.renderMs))")
            lines.append("ElapsedSeconds: \(optionalSeconds(render.elapsedSeconds))")
        }
    }

    private static func summaryRow(fileName: String, render: RenderMeasurement) -> String {
        [
            markdownCell(fileName),
            render.policyName,
            markdownCell(render.request.display),
            render.status,
            render.cacheEvent ?? "-",
            render.requestedBucket ?? "-",
            render.matchedBucket ?? "-",
            render.backend ?? "-",
            render.fallback ?? "-",
            sizeString(render.pixelSize),
            optionalInt(render.outputBytes),
            optionalInt(render.pngBytes),
            optionalMilliseconds(render.renderMs),
            optionalSeconds(render.elapsedSeconds)
        ].joined(separator: " | ").wrappedTableRow
    }

    private static func resolverRow(_ measurement: ResolverMeasurement) -> String {
        [
            markdownCell(measurement.caseName),
            markdownCell(measurement.envValue ?? "<missing>"),
            measurement.expectedPolicy,
            measurement.resolvedPolicy,
            measurement.status
        ].joined(separator: " | ").wrappedTableRow
    }

    private static func cacheSeparationRow(_ check: CacheSeparationMeasurement) -> String {
        [
            markdownCell(check.fileName),
            check.status,
            check.coreGraphicsFirstCache,
            check.skiaOptInFirstCache,
            markdownCell(check.coreGraphicsSignature),
            markdownCell(check.skiaOptInSignature),
            markdownCell(check.note)
        ].joined(separator: " | ").wrappedTableRow
    }

    private static func rowSummary(_ measurement: FileMeasurement) -> String {
        let renders = measurement.coreGraphics + measurement.skiaOptIn
        let failed = renders.filter { $0.status == "FAIL" }.count
        let cacheEvents = renders.map { $0.cacheEvent ?? "fail" }.joined(separator: ",")
        return "renders=\(renders.count) failed=\(failed) cache=\(cacheEvents)"
    }

    private static func measureResolverContract() -> [ResolverMeasurement] {
        let key = HwpThumbnailPolicyResolver.environmentKey
        let cases: [(caseName: String, envValue: String?, expectedPolicy: String)] = [
            ("missing", nil, "coreGraphicsOnly"),
            ("empty", "", "coreGraphicsOnly"),
            ("invalid", "invalid", "coreGraphicsOnly"),
            ("coreGraphics", "coreGraphics", "coreGraphicsOnly"),
            ("coreGraphicsOnly", "coreGraphicsOnly", "coreGraphicsOnly"),
            ("skia", "skia", "skiaOptIn"),
            ("skiaOptIn", "skiaOptIn", "skiaOptIn")
        ]

        return cases.map { testCase in
            let environment = testCase.envValue.map { [key: $0] } ?? [:]
            let resolved = HwpThumbnailPolicyResolver.resolve(environment: environment)
            return ResolverMeasurement(
                caseName: testCase.caseName,
                envValue: testCase.envValue,
                expectedPolicy: testCase.expectedPolicy,
                resolvedPolicy: HwpThumbnailPolicyResolver.identifier(for: resolved)
            )
        }
    }

    private static func resolverStatusSummary(_ measurements: [ResolverMeasurement]) -> String {
        let failed = measurements.filter { $0.status != "OK" }.count
        return failed == 0 ? "OK" : "FAIL(\(failed))"
    }

    private static func cacheSeparation(for measurement: FileMeasurement) -> CacheSeparationMeasurement {
        let coreFirst = measurement.coreGraphics.first
        let skiaFirst = measurement.skiaOptIn.first
        let coreCache = coreFirst?.cacheEvent ?? "-"
        let skiaCache = skiaFirst?.cacheEvent ?? "-"
        let coreSignature = coreFirst?.signature ?? "-"
        let skiaSignature = skiaFirst?.signature ?? "-"
        let signaturesDiffer = coreSignature != "-"
            && skiaSignature != "-"
            && coreSignature != skiaSignature
        let firstRequestsMiss = coreCache == "miss" && skiaCache == "miss"
        let status = signaturesDiffer && firstRequestsMiss ? "OK" : "WARN"
        let note: String
        if signaturesDiffer && firstRequestsMiss {
            note = "policy signatures are separated"
        } else if !signaturesDiffer {
            note = "policy signatures are not separated"
        } else {
            note = "first policy requests did not both miss"
        }

        return CacheSeparationMeasurement(
            fileName: measurement.fileName,
            status: status,
            coreGraphicsFirstCache: coreCache,
            skiaOptInFirstCache: skiaCache,
            coreGraphicsSignature: coreSignature,
            skiaOptInSignature: skiaSignature,
            note: note
        )
    }

    private static func bucketString(_ key: HwpThumbnailCacheKey) -> String {
        "\(key.pixelWidth)x\(key.pixelHeight)"
    }

    private static func backendName(_ backend: HwpPageRenderBackend) -> String {
        switch backend {
        case .coreGraphics:
            return "coreGraphics"
        case .skia:
            return "skia"
        case .embeddedThumbnail:
            return "embeddedThumbnail"
        }
    }

    private static func fallbackReasonName(_ reason: HwpPageRenderFallbackReason) -> String {
        switch reason {
        case .ffiUnavailable:
            return "ffiUnavailable"
        case .invalidDocumentHandle:
            return "invalidDocumentHandle"
        case .invalidPageIndex:
            return "invalidPageIndex"
        case .invalidRenderOptions:
            return "invalidRenderOptions"
        case .invalidPageSize:
            return "invalidPageSize"
        case .skiaRenderFailure:
            return "skiaRenderFailure"
        case .pngDecodeFailure:
            return "pngDecodeFailure"
        case .memoryTimeoutFallback:
            return "memoryTimeoutFallback"
        }
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

    private static func optionalMilliseconds(_ value: Double?) -> String {
        guard let value else { return "-" }
        return String(format: "%.3f", value)
    }

    private static func optionalSeconds(_ value: Double?) -> String {
        guard let value else { return "-" }
        return String(format: "%.6f", value)
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
