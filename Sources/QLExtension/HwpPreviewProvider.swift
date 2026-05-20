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
                logger.debug("Preview selected PNG reply file=\(documentContext.filename, privacy: .public) pages=\(documentContext.pageCount, privacy: .public) size=\(Int(documentContext.contentSize.width), privacy: .public)x\(Int(documentContext.contentSize.height), privacy: .public)")
                return try Self.pngReply(documentContext)
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

    private static func pngReply(_ documentContext: HwpPreviewDocumentContext) throws -> QLPreviewReply {
        logger.debug("Preview rendering PNG file=\(documentContext.filename, privacy: .public)")
        let page = try HwpPageImageRenderer.renderPage(
            document: documentContext.document,
            pageIndex: 0
        )
        let data = try HwpPageImageRenderer.encodePNG(page.image)
        logger.debug("Preview PNG ready file=\(documentContext.filename, privacy: .public) bytes=\(data.count, privacy: .public)")

        return QLPreviewReply(
            dataOfContentType: .png,
            contentSize: documentContext.contentSize
        ) { reply in
            reply.title = documentContext.filename
            return data
        }
    }

    private static func pdfReply(_ documentContext: HwpPreviewDocumentContext) throws -> QLPreviewReply {
        logger.debug("Preview rendering PDF file=\(documentContext.filename, privacy: .public) pages=\(documentContext.pageCount, privacy: .public)")
        let result = try HwpPreviewPDFRenderer.render(context: documentContext)
        logger.debug("Preview PDF ready file=\(documentContext.filename, privacy: .public) pages=\(result.pageCount, privacy: .public) bytes=\(result.data.count, privacy: .public)")

        return QLPreviewReply(
            dataOfContentType: .pdf,
            contentSize: documentContext.contentSize
        ) { reply in
            reply.title = documentContext.filename
            return result.data
        }
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
}
