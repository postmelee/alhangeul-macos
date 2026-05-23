import CoreGraphics
import Foundation

struct SmokeError: Error, CustomStringConvertible {
    let description: String
}

struct Timed<Value> {
    let value: Value
    let seconds: Double
}

struct PolicyMeasurement {
    let policyName: String
    let status: String
    let error: String?
    let outputBytes: Int?
    let outputPages: Int?
    let elapsedSeconds: Double?
    let skiaPages: Int
    let coreGraphicsPages: Int
    let embeddedThumbnailPages: Int
    let fallbackPages: Int
    let pngBytes: Int
    let renderMs: Double
    let firstFallback: String?
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
    let coreGraphics: PolicyMeasurement?
    let skiaOptIn: PolicyMeasurement?
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

        var measurements: [FileMeasurement] = []
        for inputURL in inputs {
            let measurement = measure(inputURL: inputURL)
            measurements.append(measurement)
            try writeDetail(measurement, outputDir: outputDir)
            print("\(measurement.loadStatus) \(measurement.fileName): \(rowSummary(measurement))")
        }

        try writeSummary(measurements, outputDir: outputDir)
    }

    private static func measure(inputURL: URL) -> FileMeasurement {
        let fileName = inputURL.lastPathComponent
        let fileBytes = (try? inputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0

        do {
            let context = try HwpPreviewPDFRenderer.load(fileURL: inputURL)
            let replyType = context.pageCount == 1 ? "png" : "pdf"
            let coreGraphics = measurePolicy(
                context: context,
                policyName: "coreGraphicsOnly",
                policy: .coreGraphicsOnly
            )
            let skiaOptIn = measurePolicy(
                context: context,
                policyName: "skiaOptIn",
                policy: .skiaOptIn
            )
            return FileMeasurement(
                fileName: fileName,
                filePath: inputURL.path,
                fileBytes: fileBytes,
                loadStatus: "OK",
                loadError: nil,
                pageCount: context.pageCount,
                replyType: replyType,
                firstPageSize: context.contentSize,
                coreGraphics: coreGraphics,
                skiaOptIn: skiaOptIn
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
                coreGraphics: nil,
                skiaOptIn: nil
            )
        }
    }

    private static func measurePolicy(
        context: HwpPreviewDocumentContext,
        policyName: String,
        policy: HwpPageRenderPolicy
    ) -> PolicyMeasurement {
        do {
            let timedResult = try timed {
                if context.pageCount == 1 {
                    let page = try HwpPageImageRenderer.renderPage(
                        document: context.document,
                        pageIndex: 0,
                        policy: policy
                    )
                    let png = try HwpPageImageRenderer.encodePNG(page.image)
                    return policyResult(
                        outputBytes: png.count,
                        outputPages: 1,
                        diagnostics: [
                            HwpPreviewPDFPageDiagnostics(
                                pageIndex: 0,
                                diagnostics: page.diagnostics
                            )
                        ]
                    )
                }

                let pdf = try HwpPreviewPDFRenderer.render(
                    context: context,
                    policy: policy,
                    collectDiagnostics: true
                )
                return policyResult(
                    outputBytes: pdf.data.count,
                    outputPages: pdfPageCount(data: pdf.data) ?? pdf.pageCount,
                    diagnostics: pdf.pageDiagnostics
                )
            }
            let result = timedResult.value
            return PolicyMeasurement(
                policyName: policyName,
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
                firstFallback: result.firstFallback
            )
        } catch {
            return PolicyMeasurement(
                policyName: policyName,
                status: "FAIL",
                error: String(describing: error),
                outputBytes: nil,
                outputPages: nil,
                elapsedSeconds: nil,
                skiaPages: 0,
                coreGraphicsPages: 0,
                embeddedThumbnailPages: 0,
                fallbackPages: 0,
                pngBytes: 0,
                renderMs: 0,
                firstFallback: nil
            )
        }
    }

    private struct PolicyResult {
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

    private static func policyResult(
        outputBytes: Int,
        outputPages: Int,
        diagnostics: [HwpPreviewPDFPageDiagnostics]
    ) -> PolicyResult {
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

        return PolicyResult(
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

    private static func writeSummary(_ measurements: [FileMeasurement], outputDir: URL) throws {
        var lines: [String] = []
        lines.append("# Quick Look Skia Policy Smoke")
        lines.append("")
        lines.append("GeneratedAt: \(ISO8601DateFormatter().string(from: Date()))")
        lines.append("")
        lines.append("| File | Load | Reply | Pages | Size | CGStatus | CGBackend | CGFallback | CGBytes | CGSeconds | SkiaStatus | SkiaBackend | SkiaFallback | SkiaBytes | SkiaPNGBytes | SkiaSeconds |")
        lines.append("|------|------|-------|-------|------|----------|-----------|------------|---------|-----------|------------|-------------|--------------|-----------|--------------|-------------|")

        for measurement in measurements {
            lines.append([
                markdownCell(measurement.fileName),
                measurement.loadStatus,
                measurement.replyType ?? "-",
                optionalInt(measurement.pageCount),
                sizeString(measurement.firstPageSize),
                measurement.coreGraphics?.status ?? "-",
                backendSummary(measurement.coreGraphics),
                fallbackSummary(measurement.coreGraphics),
                optionalInt(measurement.coreGraphics?.outputBytes),
                secondsString(measurement.coreGraphics?.elapsedSeconds),
                measurement.skiaOptIn?.status ?? "-",
                backendSummary(measurement.skiaOptIn),
                fallbackSummary(measurement.skiaOptIn),
                optionalInt(measurement.skiaOptIn?.outputBytes),
                optionalInt(measurement.skiaOptIn?.pngBytes),
                secondsString(measurement.skiaOptIn?.elapsedSeconds)
            ].joined(separator: " | ").wrappedTableRow)
        }

        let failed = measurements.filter { $0.loadStatus == "FAIL" || $0.coreGraphics?.status == "FAIL" || $0.skiaOptIn?.status == "FAIL" }
        if !failed.isEmpty {
            lines.append("")
            lines.append("## Failures")
            lines.append("")
            for measurement in failed {
                lines.append("- `\(measurement.fileName)`: load=\(measurement.loadError ?? "-") cg=\(measurement.coreGraphics?.error ?? "-") skia=\(measurement.skiaOptIn?.error ?? "-")")
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
        appendPolicy(measurement.coreGraphics, name: "CoreGraphics", lines: &lines)
        appendPolicy(measurement.skiaOptIn, name: "SkiaOptIn", lines: &lines)
        try lines.joined(separator: "\n").write(to: detailURL, atomically: true, encoding: .utf8)
    }

    private static func appendPolicy(_ policy: PolicyMeasurement?, name: String, lines: inout [String]) {
        lines.append("")
        lines.append("[\(name)]")
        guard let policy else {
            lines.append("Status: -")
            return
        }
        lines.append("Status: \(policy.status)")
        if let error = policy.error {
            lines.append("Error: \(error)")
        }
        lines.append("OutputBytes: \(optionalInt(policy.outputBytes))")
        lines.append("OutputPages: \(optionalInt(policy.outputPages))")
        lines.append("ElapsedSeconds: \(secondsString(policy.elapsedSeconds))")
        lines.append("SkiaPages: \(policy.skiaPages)")
        lines.append("CoreGraphicsPages: \(policy.coreGraphicsPages)")
        lines.append("EmbeddedThumbnailPages: \(policy.embeddedThumbnailPages)")
        lines.append("FallbackPages: \(policy.fallbackPages)")
        lines.append("FirstFallback: \(policy.firstFallback ?? "-")")
        lines.append("PNGBytes: \(policy.pngBytes)")
        lines.append("RenderMs: \(formatMilliseconds(policy.renderMs))")
    }

    private static func rowSummary(_ measurement: FileMeasurement) -> String {
        guard measurement.loadStatus == "OK" else {
            return measurement.loadError ?? "load failed"
        }
        return "reply=\(measurement.replyType ?? "-") pages=\(optionalInt(measurement.pageCount)) cg=\(backendSummary(measurement.coreGraphics)) skia=\(backendSummary(measurement.skiaOptIn)) fallback=\(fallbackSummary(measurement.skiaOptIn))"
    }

    private static func backendSummary(_ measurement: PolicyMeasurement?) -> String {
        guard let measurement, measurement.status == "OK" else {
            return "-"
        }
        return "skia:\(measurement.skiaPages),cg:\(measurement.coreGraphicsPages),embedded:\(measurement.embeddedThumbnailPages)"
    }

    private static func fallbackSummary(_ measurement: PolicyMeasurement?) -> String {
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

    private static func formatMilliseconds(_ value: Double) -> String {
        String(format: "%.3f", value)
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
