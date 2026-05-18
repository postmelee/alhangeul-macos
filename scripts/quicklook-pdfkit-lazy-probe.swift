import CoreGraphics
import Darwin
import Foundation
import PDFKit

struct ProbeError: Error, CustomStringConvertible {
    let description: String
}

struct ProbeConfiguration {
    let pageCount: Int
    let outputDirectory: URL
    let pageSize: CGSize
}

struct DrawEvent {
    let sequence: Int
    let phase: String
    let pageNumber: Int
    let displayBox: PDFDisplayBox
    let pageBounds: CGRect
    let clipBounds: CGRect
}

final class DrawRecorder {
    private(set) var events: [DrawEvent] = []
    private var nextSequence = 1
    private var currentPhase = "unknown"

    func withPhase<Value>(_ phase: String, _ work: () throws -> Value) rethrows -> Value {
        let previousPhase = currentPhase
        currentPhase = phase
        defer { currentPhase = previousPhase }
        return try work()
    }

    func record(pageNumber: Int, displayBox: PDFDisplayBox, pageBounds: CGRect, clipBounds: CGRect) {
        events.append(
            DrawEvent(
                sequence: nextSequence,
                phase: currentPhase,
                pageNumber: pageNumber,
                displayBox: displayBox,
                pageBounds: pageBounds,
                clipBounds: clipBounds
            )
        )
        nextSequence += 1
    }

    func eventCount(phase: String) -> Int {
        events.filter { $0.phase == phase }.count
    }
}

final class ProbePDFPage: PDFPage {
    let pageNumber: Int
    private let pageRect: CGRect
    private let recorder: DrawRecorder

    init(pageNumber: Int, pageSize: CGSize, recorder: DrawRecorder) {
        self.pageNumber = pageNumber
        self.pageRect = CGRect(origin: .zero, size: pageSize)
        self.recorder = recorder
        super.init()
    }

    override func bounds(for box: PDFDisplayBox) -> CGRect {
        pageRect
    }

    override func draw(with box: PDFDisplayBox, to context: CGContext) {
        recorder.record(
            pageNumber: pageNumber,
            displayBox: box,
            pageBounds: bounds(for: box),
            clipBounds: context.boundingBoxOfClipPath
        )

        let rect = bounds(for: box)
        context.saveGState()
        context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        context.fill(rect)

        let inset = rect.insetBy(dx: 18, dy: 18)
        context.setStrokeColor(
            red: CGFloat((pageNumber % 3) + 1) / 4.0,
            green: CGFloat((pageNumber % 5) + 1) / 6.0,
            blue: CGFloat((pageNumber % 7) + 1) / 8.0,
            alpha: 1
        )
        context.setLineWidth(4)
        context.stroke(inset)

        context.setFillColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)
        context.fill(CGRect(x: 28, y: 28, width: CGFloat(pageNumber * 7), height: 16))
        context.restoreGState()
    }
}

struct QuickLookPDFKitLazyProbe {
    static func run() throws {
        let configuration = try parseArguments(Array(CommandLine.arguments.dropFirst()))
        try FileManager.default.createDirectory(
            at: configuration.outputDirectory,
            withIntermediateDirectories: true
        )

        let recorder = DrawRecorder()
        let document = try makeDocument(configuration: configuration, recorder: recorder)
        let dataRepresentationBytes = recorder.withPhase("dataRepresentation") {
            document.dataRepresentation()?.count
        }
        guard let dataRepresentationBytes = dataRepresentationBytes else {
            throw ProbeError(description: "PDFDocument.dataRepresentation returned nil")
        }

        try recorder.withPhase("directDraw") {
            try drawAllPages(document: document, pageSize: configuration.pageSize)
        }

        try writeSummary(
            configuration: configuration,
            document: document,
            dataRepresentationBytes: dataRepresentationBytes,
            recorder: recorder
        )

        print("OK pages=\(configuration.pageCount) drawEvents=\(recorder.events.count) summary=\(configuration.outputDirectory.appendingPathComponent("summary.txt").path)")
    }

    private static func parseArguments(_ args: [String]) throws -> ProbeConfiguration {
        var pageCount: Int?
        var outputDirectory: URL?
        var width: CGFloat = 612
        var height: CGFloat = 792
        var index = 0

        while index < args.count {
            let argument = args[index]
            switch argument {
            case "--pages":
                index += 1
                guard index < args.count, let value = Int(args[index]), value > 0 else {
                    throw ProbeError(description: "--pages requires a positive integer")
                }
                pageCount = value
            case "--output":
                index += 1
                guard index < args.count else {
                    throw ProbeError(description: "--output requires a directory path")
                }
                outputDirectory = absoluteURL(args[index], isDirectory: true)
            case "--width":
                index += 1
                guard index < args.count, let value = Double(args[index]), value > 0 else {
                    throw ProbeError(description: "--width requires a positive number")
                }
                width = CGFloat(value)
            case "--height":
                index += 1
                guard index < args.count, let value = Double(args[index]), value > 0 else {
                    throw ProbeError(description: "--height requires a positive number")
                }
                height = CGFloat(value)
            case "--help", "-h":
                throw ProbeError(description: usage)
            default:
                throw ProbeError(description: "unknown argument: \(argument)\n\(usage)")
            }
            index += 1
        }

        guard let pageCount else {
            throw ProbeError(description: "--pages is required\n\(usage)")
        }
        guard let outputDirectory else {
            throw ProbeError(description: "--output is required\n\(usage)")
        }

        return ProbeConfiguration(
            pageCount: pageCount,
            outputDirectory: outputDirectory,
            pageSize: CGSize(width: width, height: height)
        )
    }

    private static var usage: String {
        "usage: quicklook-pdfkit-lazy-probe.swift --pages <count> --output <dir> [--width 612] [--height 792]"
    }

    private static func makeDocument(
        configuration: ProbeConfiguration,
        recorder: DrawRecorder
    ) throws -> PDFDocument {
        let document = PDFDocument()
        recorder.withPhase("insert") {
            for pageIndex in 0..<configuration.pageCount {
                let page = ProbePDFPage(
                    pageNumber: pageIndex + 1,
                    pageSize: configuration.pageSize,
                    recorder: recorder
                )
                document.insert(page, at: pageIndex)
            }
        }

        guard document.pageCount == configuration.pageCount else {
            throw ProbeError(
                description: "document page count mismatch: expected \(configuration.pageCount), got \(document.pageCount)"
            )
        }
        return document
    }

    private static func drawAllPages(document: PDFDocument, pageSize: CGSize) throws {
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else {
                throw ProbeError(description: "missing PDF page at zero-based index \(pageIndex)")
            }
            try drawPage(page, pageSize: pageSize)
        }
    }

    private static func drawPage(_ page: PDFPage, pageSize: CGSize) throws {
        let width = max(1, Int(ceil(pageSize.width)))
        let height = max(1, Int(ceil(pageSize.height)))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ProbeError(description: "failed to create bitmap context for direct draw")
        }

        context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        page.draw(with: .mediaBox, to: context)
    }

    private static func writeSummary(
        configuration: ProbeConfiguration,
        document: PDFDocument,
        dataRepresentationBytes: Int,
        recorder: DrawRecorder
    ) throws {
        var lines: [String] = []
        lines.append("# PDFKit Lazy Probe")
        lines.append("")
        lines.append("GeneratedAt: \(ISO8601DateFormatter().string(from: Date()))")
        lines.append("PagesRequested: \(configuration.pageCount)")
        lines.append("DocumentPageCount: \(document.pageCount)")
        lines.append("PageSize: \(formatSize(configuration.pageSize))")
        lines.append("DataRepresentationBytes: \(dataRepresentationBytes)")
        lines.append("InsertDrawEvents: \(recorder.eventCount(phase: "insert"))")
        lines.append("DataRepresentationDrawEvents: \(recorder.eventCount(phase: "dataRepresentation"))")
        lines.append("DirectDrawEvents: \(recorder.eventCount(phase: "directDraw"))")
        lines.append("TotalDrawEvents: \(recorder.events.count)")
        lines.append("")
        lines.append("## Page Bounds")
        lines.append("")
        lines.append("| Page | MediaBox | CropBox |")
        lines.append("|------|----------|---------|")
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else {
                throw ProbeError(description: "missing PDF page while writing bounds: \(pageIndex)")
            }
            lines.append([
                "\(pageIndex + 1)",
                rectString(page.bounds(for: .mediaBox)),
                rectString(page.bounds(for: .cropBox))
            ].joined(separator: " | ").wrappedTableRow)
        }
        lines.append("")
        lines.append("## Draw Events")
        lines.append("")
        lines.append("| Seq | Phase | Page | DisplayBox | PageBounds | ClipBounds |")
        lines.append("|-----|-------|------|------------|------------|------------|")
        if recorder.events.isEmpty {
            lines.append("| - | - | - | - | - | - |")
        } else {
            for event in recorder.events {
                lines.append([
                    "\(event.sequence)",
                    event.phase,
                    "\(event.pageNumber)",
                    displayBoxString(event.displayBox),
                    rectString(event.pageBounds),
                    rectString(event.clipBounds)
                ].joined(separator: " | ").wrappedTableRow)
            }
        }

        let summaryURL = configuration.outputDirectory.appendingPathComponent("summary.txt")
        try lines.joined(separator: "\n").write(
            to: summaryURL,
            atomically: true,
            encoding: .utf8
        )
    }

    private static func absoluteURL(_ path: String, isDirectory: Bool = false) -> URL {
        let url = URL(fileURLWithPath: path, isDirectory: isDirectory)
        if url.path.hasPrefix("/") {
            return url
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(path, isDirectory: isDirectory)
    }

    private static func formatSize(_ size: CGSize) -> String {
        "\(format(size.width))x\(format(size.height))"
    }

    private static func rectString(_ rect: CGRect) -> String {
        "x=\(format(rect.origin.x)),y=\(format(rect.origin.y)),w=\(format(rect.width)),h=\(format(rect.height))"
    }

    private static func format(_ value: CGFloat) -> String {
        String(format: "%.1f", Double(value))
    }

    private static func displayBoxString(_ box: PDFDisplayBox) -> String {
        switch box {
        case .mediaBox:
            return "mediaBox"
        case .cropBox:
            return "cropBox"
        case .bleedBox:
            return "bleedBox"
        case .trimBox:
            return "trimBox"
        case .artBox:
            return "artBox"
        @unknown default:
            return "unknown"
        }
    }
}

private extension String {
    var wrappedTableRow: String {
        "| \(self) |"
    }
}

do {
    try QuickLookPDFKitLazyProbe.run()
} catch {
    fputs("\(error)\n", stderr)
    exit(1)
}
