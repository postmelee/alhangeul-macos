import Foundation

struct OverlaySmokeError: Error, CustomStringConvertible {
    let description: String
}

struct OverlaySampleReport: Encodable {
    let fileName: String
    let filePath: String
    let fileBytes: Int
    let status: String
    let error: String?
    let pageNumber: Int
    let pageIndex: Int
    let pageCount: Int?
    let overlayJSONBytes: Int?
    let upstreamImageCount: Int?
    let overlayImageCount: Int?
    let behindCount: Int?
    let frontCount: Int?
    let overlayRenderableCount: Int?
    let overlayBinLinkedCount: Int?
    let overlayBakedWatermarkCount: Int?
    let overlayBase64Bytes: Int?
    let treeImageCount: Int?
    let treeEmbeddedImageCount: Int?
    let treeEmbeddedAvailableCount: Int?
    let treeOverlayCandidateCount: Int?
    let treeWrapHistogram: [String: Int]
    let overlayImages: [OverlayImageReport]
}

struct OverlayImageReport: Encodable {
    let layer: String
    let wrap: String
    let bbox: BBoxReport
    let mime: String
    let byteCount: Int
    let base64Length: Int
    let binDataId: UInt16?
    let binDataAvailable: Bool?
    let effect: String
    let brightness: Int
    let contrast: Int
    let watermarkPreset: String?
    let bakedWatermark: Bool
    let transform: TransformReport
    let fillMode: String?
    let originalSize: [Double]?
    let originalSizeHU: [Double]?
    let crop: [Int32]?
}

struct BBoxReport: Encodable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    init(_ bbox: BBox) {
        x = bbox.x
        y = bbox.y
        width = bbox.width
        height = bbox.height
    }
}

struct TransformReport: Encodable {
    let rotation: Double
    let horzFlip: Bool
    let vertFlip: Bool

    init(_ transform: RhwpPageOverlayTransform) {
        rotation = transform.rotation
        horzFlip = transform.horzFlip
        vertFlip = transform.vertFlip
    }
}

struct TreeImageStats {
    var imageCount = 0
    var embeddedImageCount = 0
    var embeddedAvailableCount = 0
    var overlayCandidateCount = 0
    var wrapHistogram: [String: Int] = [:]
}

@main
struct OverlayMetadataSmoke {
    static func main() throws {
        var args = Array(CommandLine.arguments.dropFirst())
        guard !args.isEmpty else {
            throw OverlaySmokeError(description: "usage: overlay_metadata_smoke <output-dir> [--page N] <hwp-or-hwpx> [...]")
        }

        let outputDir = URL(fileURLWithPath: args.removeFirst(), isDirectory: true)
        var pageNumber = 1

        while let first = args.first, first.hasPrefix("--") {
            switch first {
            case "--page":
                args.removeFirst()
                guard let value = args.first, let parsed = Int(value), parsed > 0 else {
                    throw OverlaySmokeError(description: "--page requires a positive integer")
                }
                pageNumber = parsed
                args.removeFirst()
            case "--help", "-h":
                print("usage: overlay_metadata_smoke <output-dir> [--page N] <hwp-or-hwpx> [...]")
                return
            default:
                throw OverlaySmokeError(description: "unknown option: \(first)")
            }
        }

        guard !args.isEmpty else {
            throw OverlaySmokeError(description: "missing input document")
        }

        let metadataDir = outputDir.appendingPathComponent("metadata", isDirectory: true)
        try FileManager.default.createDirectory(at: metadataDir, withIntermediateDirectories: true)

        var reports: [OverlaySampleReport] = []
        for input in args {
            let inputURL = URL(fileURLWithPath: input)
            let report = inspect(inputURL: inputURL, pageNumber: pageNumber, metadataDir: metadataDir)
            reports.append(report)
            try writeDetail(report, metadataDir: metadataDir)
            print(rowSummary(report))
        }

        try writeJSONLines(reports, outputDir: outputDir)
        try writeSummary(reports, outputDir: outputDir)

        if reports.contains(where: { $0.status != "OK" }) {
            throw OverlaySmokeError(description: "one or more overlay metadata smoke checks failed")
        }
    }

    private static func inspect(
        inputURL: URL,
        pageNumber: Int,
        metadataDir: URL
    ) -> OverlaySampleReport {
        let fileName = inputURL.lastPathComponent
        let fileBytes = (try? inputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let pageIndex = pageNumber - 1

        do {
            let data = try Data(contentsOf: inputURL)
            let document = try RhwpDocument(data: data, filename: fileName)
            guard pageIndex >= 0, pageIndex < document.pageCount else {
                return failureReport(
                    inputURL: inputURL,
                    fileBytes: fileBytes,
                    pageNumber: pageNumber,
                    pageIndex: pageIndex,
                    pageCount: document.pageCount,
                    error: "page \(pageNumber) is out of range: pageCount=\(document.pageCount)"
                )
            }

            let overlayJSON = document.pageOverlayImagesJSON(at: pageIndex)
            let overlays = document.pageOverlayImages(at: pageIndex)
            let tree = document.renderPageTree(at: pageIndex)
            let treeStats = tree.map { collectTreeImageStats($0, document: document) } ?? TreeImageStats()
            let overlayImages = overlays?.allImages.map(overlayImageReport) ?? []

            return OverlaySampleReport(
                fileName: fileName,
                filePath: inputURL.path,
                fileBytes: fileBytes,
                status: "OK",
                error: nil,
                pageNumber: pageNumber,
                pageIndex: pageIndex,
                pageCount: document.pageCount,
                overlayJSONBytes: overlayJSON?.utf8.count,
                upstreamImageCount: overlays?.imageCount,
                overlayImageCount: overlays?.overlayImageCount,
                behindCount: overlays?.behind.count,
                frontCount: overlays?.front.count,
                overlayRenderableCount: overlayImages.filter { $0.byteCount > 0 || $0.binDataAvailable == true }.count,
                overlayBinLinkedCount: overlayImages.filter { $0.binDataId != nil }.count,
                overlayBakedWatermarkCount: overlayImages.filter(\.bakedWatermark).count,
                overlayBase64Bytes: overlayImages.reduce(0) { $0 + $1.byteCount },
                treeImageCount: treeStats.imageCount,
                treeEmbeddedImageCount: treeStats.embeddedImageCount,
                treeEmbeddedAvailableCount: treeStats.embeddedAvailableCount,
                treeOverlayCandidateCount: treeStats.overlayCandidateCount,
                treeWrapHistogram: treeStats.wrapHistogram,
                overlayImages: overlayImages
            )
        } catch {
            return failureReport(
                inputURL: inputURL,
                fileBytes: fileBytes,
                pageNumber: pageNumber,
                pageIndex: pageIndex,
                pageCount: nil,
                error: String(describing: error)
            )
        }
    }

    private static func failureReport(
        inputURL: URL,
        fileBytes: Int,
        pageNumber: Int,
        pageIndex: Int,
        pageCount: Int?,
        error: String
    ) -> OverlaySampleReport {
        OverlaySampleReport(
            fileName: inputURL.lastPathComponent,
            filePath: inputURL.path,
            fileBytes: fileBytes,
            status: "FAIL",
            error: error,
            pageNumber: pageNumber,
            pageIndex: pageIndex,
            pageCount: pageCount,
            overlayJSONBytes: nil,
            upstreamImageCount: nil,
            overlayImageCount: nil,
            behindCount: nil,
            frontCount: nil,
            overlayRenderableCount: nil,
            overlayBinLinkedCount: nil,
            overlayBakedWatermarkCount: nil,
            overlayBase64Bytes: nil,
            treeImageCount: nil,
            treeEmbeddedImageCount: nil,
            treeEmbeddedAvailableCount: nil,
            treeOverlayCandidateCount: nil,
            treeWrapHistogram: [:],
            overlayImages: []
        )
    }

    private static func collectTreeImageStats(_ root: RenderNode, document: RhwpDocument) -> TreeImageStats {
        var stats = TreeImageStats()

        func visit(_ node: RenderNode) {
            if case .image(let image) = node.nodeType {
                stats.imageCount += 1
                let wrapKey = image.textWrap?.isEmpty == false ? image.textWrap! : "nil"
                stats.wrapHistogram[wrapKey, default: 0] += 1

                if image.binDataId > 0 {
                    stats.embeddedImageCount += 1
                    if document.imageData(binDataId: image.binDataId) != nil {
                        stats.embeddedAvailableCount += 1
                    }
                }

                if RhwpPageOverlayLayer(textWrap: image.textWrap) != nil {
                    stats.overlayCandidateCount += 1
                }
            }

            for child in node.children {
                visit(child)
            }
        }

        visit(root)
        return stats
    }

    private static func overlayImageReport(_ image: RhwpPageOverlayImage) -> OverlayImageReport {
        OverlayImageReport(
            layer: image.layer.rawValue,
            wrap: image.wrap,
            bbox: BBoxReport(image.bbox),
            mime: image.source.mime,
            byteCount: image.source.byteCount,
            base64Length: image.source.base64Length,
            binDataId: image.source.binDataId,
            binDataAvailable: image.source.binDataAvailable,
            effect: image.effect,
            brightness: image.brightness,
            contrast: image.contrast,
            watermarkPreset: image.watermarkPreset,
            bakedWatermark: image.bakedWatermark,
            transform: TransformReport(image.transform),
            fillMode: image.fillMode,
            originalSize: image.originalSize,
            originalSizeHU: image.originalSizeHU,
            crop: image.crop
        )
    }

    private static func writeDetail(_ report: OverlaySampleReport, metadataDir: URL) throws {
        let outputURL = metadataDir.appendingPathComponent("\(report.fileName)-page\(report.pageNumber)-overlay.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(report)
        try data.write(to: outputURL)
    }

    private static func writeJSONLines(_ reports: [OverlaySampleReport], outputDir: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        var lines: [String] = []
        for report in reports {
            let data = try encoder.encode(report)
            guard let line = String(data: data, encoding: .utf8) else {
                throw OverlaySmokeError(description: "failed to encode JSONL row")
            }
            lines.append(line)
        }
        try lines.joined(separator: "\n").appending("\n")
            .write(to: outputDir.appendingPathComponent("metadata.jsonl"), atomically: true, encoding: .utf8)
    }

    private static func writeSummary(_ reports: [OverlaySampleReport], outputDir: URL) throws {
        var lines: [String] = []
        lines.append("# Overlay Metadata Smoke")
        lines.append("")
        lines.append("| File | Status | PageCount | UpstreamImages | Overlay | Behind | Front | Renderable | BinLinked | TreeImages | TreeEmbeddedAvailable | Wraps | Error |")
        lines.append("|------|--------|-----------|----------------|---------|--------|-------|------------|-----------|------------|-----------------------|-------|-------|")
        for report in reports {
            lines.append([
                markdownCode(report.fileName),
                report.status,
                intCell(report.pageCount),
                intCell(report.upstreamImageCount),
                intCell(report.overlayImageCount),
                intCell(report.behindCount),
                intCell(report.frontCount),
                intCell(report.overlayRenderableCount),
                intCell(report.overlayBinLinkedCount),
                intCell(report.treeImageCount),
                treeEmbeddedCell(report),
                wrapHistogramCell(report.treeWrapHistogram),
                markdownCell(report.error ?? "")
            ].joined(separator: " | ").wrappedTableRow())
        }
        lines.append("")
        lines.append("Artifacts:")
        lines.append("")
        lines.append("- `metadata.jsonl`: one JSON object per input")
        lines.append("- `metadata/*.json`: pretty-printed per-input metadata")
        lines.append("")
        try lines.joined(separator: "\n").appending("\n")
            .write(to: outputDir.appendingPathComponent("summary.md"), atomically: true, encoding: .utf8)
    }

    private static func rowSummary(_ report: OverlaySampleReport) -> String {
        if report.status != "OK" {
            return "FAIL \(report.fileName): \(report.error ?? "unknown error")"
        }
        return "OK \(report.fileName): page=\(report.pageNumber) upstreamImages=\(report.upstreamImageCount ?? 0) overlay=\(report.overlayImageCount ?? 0) behind=\(report.behindCount ?? 0) front=\(report.frontCount ?? 0) treeImages=\(report.treeImageCount ?? 0) treeEmbeddedAvailable=\(report.treeEmbeddedAvailableCount ?? 0)/\(report.treeEmbeddedImageCount ?? 0)"
    }

    private static func intCell(_ value: Int?) -> String {
        value.map(String.init) ?? "-"
    }

    private static func treeEmbeddedCell(_ report: OverlaySampleReport) -> String {
        guard let available = report.treeEmbeddedAvailableCount,
              let total = report.treeEmbeddedImageCount else {
            return "-"
        }
        return "\(available)/\(total)"
    }

    private static func wrapHistogramCell(_ histogram: [String: Int]) -> String {
        guard !histogram.isEmpty else {
            return "-"
        }
        return histogram
            .keys
            .sorted()
            .map { "\($0):\(histogram[$0] ?? 0)" }
            .joined(separator: ", ")
    }

    private static func markdownCode(_ value: String) -> String {
        "`\(markdownCell(value))`"
    }

    private static func markdownCell(_ value: String) -> String {
        value
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: " ")
    }
}

private extension String {
    func wrappedTableRow() -> String {
        "| \(self) |"
    }
}
