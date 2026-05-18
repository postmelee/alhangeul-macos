import CoreGraphics
import Foundation
import OSLog
import PDFKit
import QuickLookUI

enum HwpPDFKitLazyPreviewProbe {
    static let environmentKey = "ALHANGEUL_PDFKIT_LAZY_PROBE"
    static let flagPath = "/private/tmp/rhwp-task87-enable-pdfkit-probe"

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.postmelee.alhangeul.QLExtension",
        category: "PDFKitLazyProbe"
    )

    static var isEnabled: Bool {
        if probeValueIsEnabled(ProcessInfo.processInfo.environment[environmentKey]) {
            return true
        }
        return FileManager.default.fileExists(atPath: flagPath)
    }

    static func reply(previewInfo: HwpPreviewDocumentInfo) -> QLPreviewReply {
        QLPreviewReply(forPDFWithPageSize: previewInfo.contentSize) { reply in
            reply.title = previewInfo.filename
            let recorder = HwpPDFKitLazyProbeRecorder(
                filename: previewInfo.filename,
                pageCount: previewInfo.pageCount,
                pageSize: previewInfo.contentSize
            )
            recorder.record(phase: "documentCreation", detail: "begin")
            let document = HwpPDFKitLazyProbeDocument(recorder: recorder)
            for pageIndex in 0..<previewInfo.pageCount {
                let page = HwpPDFKitLazyProbePage(
                    pageNumber: pageIndex + 1,
                    pageSize: previewInfo.contentSize,
                    recorder: recorder
                )
                document.insert(page, at: pageIndex)
            }
            recorder.record(
                phase: "documentCreation",
                detail: "end documentPageCount=\(document.pageCount)"
            )
            logger.warning("PDFKit lazy probe document ready file=\(previewInfo.filename, privacy: .public) pages=\(document.pageCount, privacy: .public) summary=\(recorder.summaryURL.path, privacy: .public)")
            return document
        }
    }

    private static func probeValueIsEnabled(_ value: String?) -> Bool {
        guard let normalized = value?.lowercased() else {
            return false
        }
        return normalized == "1" || normalized == "true" || normalized == "yes" || normalized == "on"
    }
}

private final class HwpPDFKitLazyProbeDocument: PDFDocument {
    private let recorder: HwpPDFKitLazyProbeRecorder

    init(recorder: HwpPDFKitLazyProbeRecorder) {
        self.recorder = recorder
        super.init()
    }

    override func page(at index: Int) -> PDFPage? {
        recorder.record(phase: "pageRequest", pageNumber: index + 1, detail: "page(at:)")
        return super.page(at: index)
    }

    override func dataRepresentation() -> Data? {
        recorder.record(phase: "dataRepresentation", detail: "begin")
        let data = super.dataRepresentation()
        recorder.record(
            phase: "dataRepresentation",
            detail: "end bytes=\(data?.count ?? 0)"
        )
        return data
    }
}

private final class HwpPDFKitLazyProbePage: PDFPage {
    private let pageNumber: Int
    private let pageRect: CGRect
    private let recorder: HwpPDFKitLazyProbeRecorder

    init(pageNumber: Int, pageSize: CGSize, recorder: HwpPDFKitLazyProbeRecorder) {
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
            phase: "draw",
            pageNumber: pageNumber,
            detail: "draw(with:to:)",
            displayBox: box,
            pageBounds: bounds(for: box),
            clipBounds: context.boundingBoxOfClipPath
        )
        drawSyntheticPage(with: box, to: context)
    }

    private func drawSyntheticPage(with box: PDFDisplayBox, to context: CGContext) {
        let rect = bounds(for: box)
        context.saveGState()
        context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        context.fill(rect)

        let inset = rect.insetBy(dx: 24, dy: 24)
        context.setStrokeColor(red: 0.1, green: 0.35, blue: 0.7, alpha: 1)
        context.setLineWidth(4)
        context.stroke(inset)

        context.setFillColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1)
        let barWidth = min(inset.width, CGFloat(max(1, pageNumber)) * 12)
        context.fill(CGRect(x: inset.minX, y: inset.minY, width: barWidth, height: 18))
        context.restoreGState()
    }
}

private final class HwpPDFKitLazyProbeRecorder {
    struct Event {
        let sequence: Int
        let elapsedMilliseconds: Double
        let phase: String
        let pageNumber: Int?
        let detail: String
        let displayBox: PDFDisplayBox?
        let pageBounds: CGRect?
        let clipBounds: CGRect?
        let threadDescription: String
    }

    let summaryURL: URL

    private let filename: String
    private let pageCount: Int
    private let pageSize: CGSize
    private let sessionID = UUID().uuidString
    private let startTime = DispatchTime.now().uptimeNanoseconds
    private let outputDirectory = URL(
        fileURLWithPath: "/private/tmp/rhwp-task87-pdfkit-extension-probe",
        isDirectory: true
    )
    private let latestSummaryURL: URL
    private let lock = NSLock()
    private var events: [Event] = []
    private var nextSequence = 1

    init(filename: String, pageCount: Int, pageSize: CGSize) {
        self.filename = filename
        self.pageCount = pageCount
        self.pageSize = pageSize
        self.summaryURL = outputDirectory.appendingPathComponent("summary-\(sessionID).txt")
        self.latestSummaryURL = outputDirectory.appendingPathComponent("latest-summary.txt")
        try? FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )
        writeSummary(events: [])
    }

    func record(
        phase: String,
        pageNumber: Int? = nil,
        detail: String,
        displayBox: PDFDisplayBox? = nil,
        pageBounds: CGRect? = nil,
        clipBounds: CGRect? = nil
    ) {
        let copiedEvents: [Event]
        lock.lock()
        let event = Event(
            sequence: nextSequence,
            elapsedMilliseconds: elapsedMilliseconds(),
            phase: phase,
            pageNumber: pageNumber,
            detail: detail,
            displayBox: displayBox,
            pageBounds: pageBounds,
            clipBounds: clipBounds,
            threadDescription: Thread.isMainThread ? "main" : "background"
        )
        events.append(event)
        nextSequence += 1
        copiedEvents = events
        lock.unlock()

        writeSummary(events: copiedEvents)
    }

    private func elapsedMilliseconds() -> Double {
        let now = DispatchTime.now().uptimeNanoseconds
        return Double(now - startTime) / 1_000_000
    }

    private func writeSummary(events: [Event]) {
        var lines: [String] = []
        lines.append("# PDFKit Lazy Preview Probe")
        lines.append("")
        lines.append("GeneratedAt: \(ISO8601DateFormatter().string(from: Date()))")
        lines.append("SessionID: \(sessionID)")
        lines.append("Filename: \(filename)")
        lines.append("PageCount: \(pageCount)")
        lines.append("PageSize: \(formatSize(pageSize))")
        lines.append("EventCount: \(events.count)")
        lines.append("")
        lines.append("## Events")
        lines.append("")
        lines.append("| Seq | ElapsedMs | Phase | Page | Detail | DisplayBox | PageBounds | ClipBounds | Thread |")
        lines.append("|-----|-----------|-------|------|--------|------------|------------|------------|--------|")
        if events.isEmpty {
            lines.append("| - | - | - | - | - | - | - | - | - |")
        } else {
            for event in events {
                lines.append([
                    "\(event.sequence)",
                    format(event.elapsedMilliseconds),
                    event.phase,
                    event.pageNumber.map(String.init) ?? "-",
                    event.detail,
                    event.displayBox.map(displayBoxString) ?? "-",
                    event.pageBounds.map(rectString) ?? "-",
                    event.clipBounds.map(rectString) ?? "-",
                    event.threadDescription
                ].map(markdownCell).joined(separator: " | ").wrappedTableRow)
            }
        }

        let text = lines.joined(separator: "\n")
        try? text.write(to: summaryURL, atomically: true, encoding: .utf8)
        try? text.write(to: latestSummaryURL, atomically: true, encoding: .utf8)
    }

    private func markdownCell(_ value: String) -> String {
        value.replacingOccurrences(of: "|", with: "/")
    }

    private func formatSize(_ size: CGSize) -> String {
        "\(format(Double(size.width)))x\(format(Double(size.height)))"
    }

    private func rectString(_ rect: CGRect) -> String {
        "x=\(format(Double(rect.origin.x))),y=\(format(Double(rect.origin.y))),w=\(format(Double(rect.width))),h=\(format(Double(rect.height)))"
    }

    private func format(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func displayBoxString(_ box: PDFDisplayBox) -> String {
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
