import CoreGraphics
import Foundation

struct CompareError: Error, CustomStringConvertible {
    let description: String
}

struct Timed<Value> {
    let value: Value
    let seconds: Double
}

struct FileMeasurement {
    let fileName: String
    let filePath: String
    let fileBytes: Int
    let status: String
    let error: String?
    let pageCount: Int?
    let firstPageSize: CGSize?
    let currentQuickLookReply: String?
    let nativeInspectSeconds: Double?
    let nativePDFSeconds: Double?
    let nativePDFBytes: Int?
    let nativePDFPageCount: Int?
    let coreDataReadSeconds: Double?
    let coreOpenSeconds: Double?
    let coreSVGSeconds: Double?
    let coreSVGBytes: Int?
    let coreSVGFailures: [Int]
    let pageSVGSeconds: [Double]
}

@main
struct QuickLookPDFRendererCompare {
    static func main() throws {
        let args = Array(CommandLine.arguments.dropFirst())
        guard args.count >= 2 else {
            throw CompareError(description: "usage: quicklook_pdf_renderer_compare <output-dir> <hwp-or-hwpx> [...]")
        }

        let outputDir = absoluteURL(args[0], isDirectory: true)
        let inputs = args.dropFirst().map { absoluteURL($0) }
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        var measurements: [FileMeasurement] = []
        for inputURL in inputs {
            let measurement = measure(inputURL: inputURL, outputDir: outputDir)
            measurements.append(measurement)
            try writeDetail(measurement, outputDir: outputDir)
            print("\(measurement.status) \(measurement.fileName): \(rowSummary(measurement))")
        }

        try writeSummary(measurements, outputDir: outputDir)
    }

    private static func measure(inputURL: URL, outputDir: URL) -> FileMeasurement {
        let fileName = inputURL.lastPathComponent
        let fileBytes = (try? inputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0

        do {
            let inspect = try timed {
                try HwpPreviewPDFRenderer.inspect(fileURL: inputURL)
            }
            let previewInfo = inspect.value
            let nativePDF = try timed {
                try HwpPreviewPDFRenderer.render(previewInfo: previewInfo)
            }
            let nativePageCount = pdfPageCount(data: nativePDF.value.data) ?? nativePDF.value.pageCount

            let coreData = try timed {
                try Data(contentsOf: inputURL, options: [.mappedIfSafe])
            }
            let coreDocument = try timed {
                try RhwpDocument(data: coreData.value, filename: fileName)
            }

            var svgBytes = 0
            var svgFailures: [Int] = []
            var pageTimes: [Double] = []
            let svgTotal = timed {
                for pageIndex in 0..<coreDocument.value.pageCount {
                    let pageSVG = timed {
                        coreDocument.value.renderPageSVG(at: pageIndex)
                    }
                    pageTimes.append(pageSVG.seconds)
                    guard let svg = pageSVG.value else {
                        svgFailures.append(pageIndex + 1)
                        continue
                    }
                    svgBytes += svg.utf8.count
                }
            }

            return FileMeasurement(
                fileName: fileName,
                filePath: inputURL.path,
                fileBytes: fileBytes,
                status: svgFailures.isEmpty ? "OK" : "PARTIAL",
                error: nil,
                pageCount: previewInfo.pageCount,
                firstPageSize: previewInfo.contentSize,
                currentQuickLookReply: previewInfo.pageCount == 1 ? "png" : "pdf",
                nativeInspectSeconds: inspect.seconds,
                nativePDFSeconds: nativePDF.seconds,
                nativePDFBytes: nativePDF.value.data.count,
                nativePDFPageCount: nativePageCount,
                coreDataReadSeconds: coreData.seconds,
                coreOpenSeconds: coreDocument.seconds,
                coreSVGSeconds: svgTotal.seconds,
                coreSVGBytes: svgBytes,
                coreSVGFailures: svgFailures,
                pageSVGSeconds: pageTimes
            )
        } catch {
            return FileMeasurement(
                fileName: fileName,
                filePath: inputURL.path,
                fileBytes: fileBytes,
                status: "FAIL",
                error: String(describing: error),
                pageCount: nil,
                firstPageSize: nil,
                currentQuickLookReply: nil,
                nativeInspectSeconds: nil,
                nativePDFSeconds: nil,
                nativePDFBytes: nil,
                nativePDFPageCount: nil,
                coreDataReadSeconds: nil,
                coreOpenSeconds: nil,
                coreSVGSeconds: nil,
                coreSVGBytes: nil,
                coreSVGFailures: [],
                pageSVGSeconds: []
            )
        }
    }

    private static func timed<Value>(_ work: () throws -> Value) rethrows -> Timed<Value> {
        let start = DispatchTime.now().uptimeNanoseconds
        let value = try work()
        let end = DispatchTime.now().uptimeNanoseconds
        return Timed(value: value, seconds: Double(end - start) / 1_000_000_000)
    }

    private static func timed(_ work: () throws -> Void) rethrows -> Timed<Void> {
        let start = DispatchTime.now().uptimeNanoseconds
        try work()
        let end = DispatchTime.now().uptimeNanoseconds
        return Timed(value: (), seconds: Double(end - start) / 1_000_000_000)
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
        lines.append("# Quick Look PDF Renderer Compare")
        lines.append("")
        lines.append("GeneratedAt: \(ISO8601DateFormatter().string(from: Date()))")
        lines.append("")
        lines.append("| File | Status | FileBytes | Pages | CurrentReply | FirstPageSize | NativeInspectSeconds | NativePDFSeconds | NativePDFBytes | NativePDFPages | CoreDataReadSeconds | CoreOpenSeconds | CoreSVGSeconds | CoreSVGBytes | CoreSVGFailures |")
        lines.append("|------|--------|-----------|-------|--------------|---------------|----------------------|------------------|----------------|----------------|---------------------|-----------------|----------------|--------------|-----------------|")

        for measurement in measurements {
            lines.append([
                markdownCell(measurement.fileName),
                measurement.status,
                intString(measurement.fileBytes),
                optionalInt(measurement.pageCount),
                measurement.currentQuickLookReply ?? "-",
                sizeString(measurement.firstPageSize),
                secondsString(measurement.nativeInspectSeconds),
                secondsString(measurement.nativePDFSeconds),
                optionalInt(measurement.nativePDFBytes),
                optionalInt(measurement.nativePDFPageCount),
                secondsString(measurement.coreDataReadSeconds),
                secondsString(measurement.coreOpenSeconds),
                secondsString(measurement.coreSVGSeconds),
                optionalInt(measurement.coreSVGBytes),
                failureString(measurement.coreSVGFailures)
            ].joined(separator: " | ").wrappedTableRow)
        }

        let failed = measurements.filter { $0.status == "FAIL" }
        if !failed.isEmpty {
            lines.append("")
            lines.append("## Failures")
            lines.append("")
            for measurement in failed {
                lines.append("- `\(measurement.fileName)`: \(measurement.error ?? "unknown error")")
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
        let detailURL = outputDir.appendingPathComponent("\(baseName)-compare.txt")
        var lines: [String] = []
        lines.append("File: \(measurement.filePath)")
        lines.append("Status: \(measurement.status)")
        lines.append("FileBytes: \(measurement.fileBytes)")
        if let error = measurement.error {
            lines.append("Error: \(error)")
        }
        lines.append("PageCount: \(optionalInt(measurement.pageCount))")
        lines.append("CurrentQuickLookReply: \(measurement.currentQuickLookReply ?? "-")")
        lines.append("FirstPageSize: \(sizeString(measurement.firstPageSize))")
        lines.append("NativeInspectSeconds: \(secondsString(measurement.nativeInspectSeconds))")
        lines.append("NativePDFSeconds: \(secondsString(measurement.nativePDFSeconds))")
        lines.append("NativePDFBytes: \(optionalInt(measurement.nativePDFBytes))")
        lines.append("NativePDFPageCount: \(optionalInt(measurement.nativePDFPageCount))")
        lines.append("CoreDataReadSeconds: \(secondsString(measurement.coreDataReadSeconds))")
        lines.append("CoreOpenSeconds: \(secondsString(measurement.coreOpenSeconds))")
        lines.append("CoreSVGSeconds: \(secondsString(measurement.coreSVGSeconds))")
        lines.append("CoreSVGBytes: \(optionalInt(measurement.coreSVGBytes))")
        lines.append("CoreSVGFailures: \(failureString(measurement.coreSVGFailures))")
        if !measurement.pageSVGSeconds.isEmpty {
            lines.append("PageSVGSeconds:")
            for (index, seconds) in measurement.pageSVGSeconds.enumerated() {
                lines.append("  page \(index + 1): \(formatSeconds(seconds))")
            }
        }
        try lines.joined(separator: "\n").write(to: detailURL, atomically: true, encoding: .utf8)
    }

    private static func rowSummary(_ measurement: FileMeasurement) -> String {
        if let error = measurement.error {
            return error
        }
        return "pages=\(optionalInt(measurement.pageCount)) nativePDF=\(secondsString(measurement.nativePDFSeconds)) coreSVG=\(secondsString(measurement.coreSVGSeconds))"
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

    private static func secondsString(_ value: Double?) -> String {
        guard let value else { return "-" }
        return formatSeconds(value)
    }

    private static func formatSeconds(_ value: Double) -> String {
        String(format: "%.6f", value)
    }

    private static func optionalInt(_ value: Int?) -> String {
        guard let value else { return "-" }
        return "\(value)"
    }

    private static func intString(_ value: Int) -> String {
        "\(value)"
    }

    private static func sizeString(_ size: CGSize?) -> String {
        guard let size else { return "-" }
        return "\(String(format: "%.1f", size.width))x\(String(format: "%.1f", size.height))"
    }

    private static func failureString(_ failures: [Int]) -> String {
        failures.isEmpty ? "-" : failures.map(String.init).joined(separator: ",")
    }

    private static func markdownCell(_ value: String) -> String {
        "`\(value.replacingOccurrences(of: "|", with: "\\|"))`"
    }
}

private extension String {
    var wrappedTableRow: String {
        "| \(self) |"
    }
}
