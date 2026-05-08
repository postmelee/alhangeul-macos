import Foundation
import QuickLookUI
import UniformTypeIdentifiers

final class HwpPreviewProvider: QLPreviewProvider, QLPreviewingController {
    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        try Self.createPreview(for: request)
    }

    private static func createPreview(for request: QLFilePreviewRequest) throws -> QLPreviewReply {
        do {
            let previewInfo = try HwpPreviewPDFRenderer.inspect(fileURL: request.fileURL)
            if previewInfo.pageCount == 1 {
                return try Self.pngReply(previewInfo)
            } else {
                return try Self.pdfReply(previewInfo)
            }
        } catch {
            if let reason = HwpDocumentFallbackClassifier.reason(for: error) {
                return Self.textReply(
                    HwpDocumentFallbackClassifier.quickLookMessage(for: reason),
                    title: request.fileURL.lastPathComponent
                )
            }
            throw error
        }
    }

    private static func pngReply(_ previewInfo: HwpPreviewDocumentInfo) throws -> QLPreviewReply {
        let document = try RhwpDocument(
            data: previewInfo.data,
            filename: previewInfo.filename
        )
        let page = try HwpPageImageRenderer.renderPage(
            document: document,
            pageIndex: 0
        )
        let data = try HwpPageImageRenderer.encodePNG(page.image)

        return QLPreviewReply(
            dataOfContentType: .png,
            contentSize: previewInfo.contentSize
        ) { reply in
            reply.title = previewInfo.filename
            return data
        }
    }

    private static func pdfReply(_ previewInfo: HwpPreviewDocumentInfo) throws -> QLPreviewReply {
        let result = try HwpPreviewPDFRenderer.render(previewInfo: previewInfo)

        return QLPreviewReply(
            dataOfContentType: .pdf,
            contentSize: previewInfo.contentSize
        ) { reply in
            reply.title = previewInfo.filename
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
}
