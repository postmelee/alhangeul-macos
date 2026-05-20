import CoreGraphics
import Foundation
import OSLog
import PDFKit

struct HwpPDFViewLazyProbeMetadata: Sendable {
    let filename: String
    let pageCount: Int
    let pageWidth: CGFloat
    let pageHeight: CGFloat
}

enum HwpPDFViewLazyProbe {
    static func metadata(for fileURL: URL) throws -> HwpPDFViewLazyProbeMetadata {
        let info = try HwpPreviewPDFRenderer.inspect(fileURL: fileURL)
        return HwpPDFViewLazyProbeMetadata(
            filename: info.filename,
            pageCount: info.pageCount,
            pageWidth: info.contentSize.width,
            pageHeight: info.contentSize.height
        )
    }

    static func makeDocument(
        metadata: HwpPDFViewLazyProbeMetadata,
        generation: Int,
        recorder: HwpPDFViewLazyProbeRecorder
    ) -> PDFDocument {
        let document = PDFDocument()
        for pageIndex in 0..<metadata.pageCount {
            let page = HwpPDFViewLazyProbePage(
                pageIndex: pageIndex,
                generation: generation,
                size: CGSize(width: metadata.pageWidth, height: metadata.pageHeight),
                recorder: recorder
            )
            document.insert(page, at: pageIndex)
        }
        return document
    }
}

final class HwpPDFViewLazyProbeRecorder {
    private let logger: Logger
    private let filename: String
    private let lock = NSLock()
    private var events: [String] = []

    init(logger: Logger, filename: String) {
        self.logger = logger
        self.filename = filename
    }

    func record(_ event: String, pageIndex: Int?, generation: Int) {
        let pageText = pageIndex.map { " page=\($0 + 1)" } ?? ""
        let line = "generation=\(generation)\(pageText) event=\(event) file=\(filename)"
        lock.lock()
        events.append(line)
        lock.unlock()
        logger.notice("PDFView lazy probe \(line, privacy: .public)")
    }

    func snapshot() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return events
    }
}

final class HwpPDFViewLazyProbePage: PDFPage {
    private let pageIndex: Int
    private let generation: Int
    private let pageSize: CGSize
    private let recorder: HwpPDFViewLazyProbeRecorder

    init(
        pageIndex: Int,
        generation: Int,
        size: CGSize,
        recorder: HwpPDFViewLazyProbeRecorder
    ) {
        self.pageIndex = pageIndex
        self.generation = generation
        self.pageSize = size
        self.recorder = recorder
        super.init()
        recorder.record("page-init", pageIndex: pageIndex, generation: generation)
    }

    override func bounds(for box: PDFDisplayBox) -> CGRect {
        CGRect(origin: .zero, size: pageSize)
    }

    override func draw(with box: PDFDisplayBox, to context: CGContext) {
        recorder.record("draw-begin", pageIndex: pageIndex, generation: generation)

        let rect = bounds(for: box)
        context.saveGState()
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(rect)
        context.setStrokeColor(CGColor(gray: 0.72, alpha: 1))
        context.setLineWidth(1)
        context.stroke(rect.insetBy(dx: 24, dy: 24))

        let headerRect = CGRect(
            x: rect.minX + 72,
            y: rect.maxY - 120,
            width: rect.width - 144,
            height: 48
        )
        context.setStrokeColor(CGColor(red: 0.18, green: 0.36, blue: 0.58, alpha: 1))
        context.stroke(headerRect)

        let bodyTop = rect.maxY - 180
        context.setStrokeColor(CGColor(gray: 0.25, alpha: 1))
        for line in 0..<10 {
            let y = bodyTop - CGFloat(line) * 34
            context.move(to: CGPoint(x: rect.minX + 96, y: y))
            context.addLine(to: CGPoint(x: rect.maxX - 96, y: y))
            context.strokePath()
        }

        context.setFillColor(CGColor(gray: 0.1, alpha: 1))
        let marker = CGRect(
            x: rect.minX + 96,
            y: rect.minY + 72,
            width: 18 + CGFloat(pageIndex % 4) * 24,
            height: 18
        )
        context.fill(marker)
        context.restoreGState()

        recorder.record("draw-end", pageIndex: pageIndex, generation: generation)
    }
}
