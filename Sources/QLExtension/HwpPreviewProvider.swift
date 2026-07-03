import Foundation
import OSLog
import QuickLookUI
import UniformTypeIdentifiers

final class HwpPreviewProvider: QLPreviewProvider, QLPreviewingController {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.postmelee.alhangeul.QLExtension",
        category: "PreviewProvider"
    )

    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        try Self.createPreview(for: request)
    }

    private static func createPreview(for request: QLFilePreviewRequest) throws -> QLPreviewReply {
        logger.debug("Preview requested file=\(request.fileURL.lastPathComponent, privacy: .public)")
        do {
            let documentContext = try HwpPreviewPDFRenderer.load(fileURL: request.fileURL)
            if documentContext.pageCount == 1 {
                let mode = HwpQuickLookPNGReplyModeResolver.resolve()
                logger.debug("Preview selected PNG reply file=\(documentContext.filename, privacy: .public) mode=\(mode.identifier, privacy: .public) pages=\(documentContext.pageCount, privacy: .public) size=\(Int(documentContext.contentSize.width), privacy: .public)x\(Int(documentContext.contentSize.height), privacy: .public)")
                return try Self.pngReply(documentContext, mode: mode)
            } else {
                logger.debug("Preview selected PDF reply file=\(documentContext.filename, privacy: .public) pages=\(documentContext.pageCount, privacy: .public) size=\(Int(documentContext.contentSize.width), privacy: .public)x\(Int(documentContext.contentSize.height), privacy: .public)")
                return try Self.pdfReply(documentContext)
            }
        } catch {
            if let reason = HwpDocumentFallbackClassifier.reason(for: error) {
                logger.warning("Preview fallback file=\(request.fileURL.lastPathComponent, privacy: .public) reason=\(String(describing: reason), privacy: .public) error=\(Self.errorDescription(error), privacy: .public)")
                return Self.textReply(
                    HwpDocumentFallbackClassifier.quickLookMessage(for: reason),
                    title: request.fileURL.lastPathComponent
                )
            }
            logger.error("Preview failed file=\(request.fileURL.lastPathComponent, privacy: .public) error=\(Self.errorDescription(error), privacy: .public)")
            throw error
        }
    }

    private static func pngReply(
        _ documentContext: HwpPreviewDocumentContext,
        mode: HwpPreviewPNGReplyMode
    ) throws -> QLPreviewReply {
        logger.debug("Preview rendering PNG file=\(documentContext.filename, privacy: .public) mode=\(mode.identifier, privacy: .public)")
        let filename = documentContext.filename
        let result = try HwpPreviewPNGRenderer.render(
            context: documentContext,
            mode: mode
        )
        let data = result.data
        logPNGDiagnostics(result, filename: filename)
        logger.debug("Preview PNG ready file=\(filename, privacy: .public) mode=\(result.diagnostics.outputMode.identifier, privacy: .public) bytes=\(data.count, privacy: .public)")

        return QLPreviewReply(
            dataOfContentType: .png,
            contentSize: result.contentSize
        ) { reply in
            reply.title = filename
            return data
        }
    }

    private static func logPNGDiagnostics(
        _ result: HwpRenderedPreviewPNG,
        filename: String
    ) {
        let diagnostics = result.diagnostics
        logger.debug("Preview PNG render backend file=\(filename, privacy: .public) requestedMode=\(diagnostics.requestedMode.identifier, privacy: .public) outputMode=\(diagnostics.outputMode.identifier, privacy: .public) backend=\(backendDescription(diagnostics.backendUsed), privacy: .public) fallback=\(optionalStringDescription(diagnostics.fallbackReason), privacy: .public)")
        logger.debug("Preview PNG render output file=\(filename, privacy: .public) bytes=\(diagnostics.outputBytes, privacy: .public) skiaPNGBytes=\(optionalIntDescription(diagnostics.skiaPNGBytes), privacy: .public) pixel=\(optionalSizeDescription(diagnostics.pngPixelSize), privacy: .public)")
        logger.debug("Preview PNG render timing totalMs=\(millisecondsDescription(diagnostics.durationMs.totalMs), privacy: .public) skiaMs=\(optionalMillisecondsDescription(diagnostics.durationMs.skiaRenderMs), privacy: .public) validateMs=\(optionalMillisecondsDescription(diagnostics.durationMs.pngHeaderValidateMs), privacy: .public) decodeMs=\(optionalMillisecondsDescription(diagnostics.durationMs.pngDecodeMs), privacy: .public) encodeMs=\(optionalMillisecondsDescription(diagnostics.durationMs.pngEncodeMs), privacy: .public) coreMs=\(optionalMillisecondsDescription(diagnostics.durationMs.coreGraphicsRenderMs), privacy: .public)")
    }

    private static func pdfReply(_ documentContext: HwpPreviewDocumentContext) throws -> QLPreviewReply {
        logger.debug("Preview rendering PDF file=\(documentContext.filename, privacy: .public) pages=\(documentContext.pageCount, privacy: .public)")
        let filename = documentContext.filename
        let contentSize = documentContext.contentSize
        let result = try HwpPreviewPDFRenderer.render(
            context: documentContext,
            policy: .coreGraphicsOnly,
            collectDiagnostics: true
        )
        let data = result.data
        logPDFDiagnostics(result, filename: filename)
        logger.debug("Preview PDF ready file=\(filename, privacy: .public) pages=\(result.pageCount, privacy: .public) bytes=\(data.count, privacy: .public)")

        return QLPreviewReply(
            dataOfContentType: .pdf,
            contentSize: contentSize
        ) { reply in
            reply.title = filename
            return data
        }
    }

    private static func logPDFDiagnostics(_ result: HwpRenderedPreviewPDF, filename: String) {
        var skiaPages = 0
        var coreGraphicsPages = 0
        var embeddedThumbnailPages = 0
        var fallbackPages = 0
        var pngBytes = 0
        var totalRenderMs = 0.0

        for page in result.pageDiagnostics {
            switch page.diagnostics.backendUsed {
            case .coreGraphics:
                coreGraphicsPages += 1
            case .skia:
                skiaPages += 1
            case .embeddedThumbnail:
                embeddedThumbnailPages += 1
            }

            if page.diagnostics.fallbackReason != nil {
                fallbackPages += 1
            }
            pngBytes += page.diagnostics.pngBytes ?? 0
            totalRenderMs += page.diagnostics.durationMs.totalMs
        }

        logger.debug("Preview PDF render backend file=\(filename, privacy: .public) pages=\(result.pageCount, privacy: .public) skiaPages=\(skiaPages, privacy: .public) coreGraphicsPages=\(coreGraphicsPages, privacy: .public)")
        logger.debug("Preview PDF render fallback embeddedThumbnailPages=\(embeddedThumbnailPages, privacy: .public) fallbackPages=\(fallbackPages, privacy: .public)")
        logger.debug("Preview PDF render output pngBytes=\(pngBytes, privacy: .public) totalRenderMs=\(millisecondsDescription(totalRenderMs), privacy: .public)")
    }

    private static func textReply(_ text: String, title: String) -> QLPreviewReply {
        QLPreviewReply(
            dataOfContentType: .plainText,
            contentSize: CGSize(width: 520, height: 120)
        ) { reply in
            reply.title = title
            return Data(text.utf8)
        }
    }

    private static func errorDescription(_ error: Error) -> String {
        let nsError = error as NSError
        return "\(type(of: error))(domain=\(nsError.domain), code=\(nsError.code))"
    }

    private static func optionalIntDescription(_ value: Int?) -> String {
        guard let value else {
            return "none"
        }
        return String(value)
    }

    private static func optionalStringDescription(_ value: String?) -> String {
        value ?? "none"
    }

    private static func optionalSizeDescription(_ value: CGSize?) -> String {
        guard let value else {
            return "none"
        }
        return "\(Int(value.width))x\(Int(value.height))"
    }

    private static func optionalMillisecondsDescription(_ value: Double?) -> String {
        guard let value else {
            return "none"
        }
        return millisecondsDescription(value)
    }

    private static func millisecondsDescription(_ value: Double) -> String {
        String(format: "%.3f", value)
    }

    private static func backendDescription(_ backend: HwpPageRenderBackend) -> String {
        switch backend {
        case .coreGraphics:
            return "coreGraphics"
        case .skia:
            return "skia"
        case .embeddedThumbnail:
            return "embeddedThumbnail"
        }
    }
}
