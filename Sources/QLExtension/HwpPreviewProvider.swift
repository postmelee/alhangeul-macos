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
                return Self.pngReply(previewInfo)
            } else {
                return Self.pdfReply(previewInfo)
            }
        } catch HwpRenderError.fileTooLarge {
            return Self.textReply("The file is larger than 50 MB.")
        } catch {
            throw error
        }
    }

    private static func pngReply(_ previewInfo: HwpPreviewDocumentInfo) -> QLPreviewReply {
        QLPreviewReply(
            dataOfContentType: .png,
            contentSize: previewInfo.contentSize
        ) { reply in
            reply.title = previewInfo.filename
            let document = try RhwpDocument(
                data: previewInfo.data,
                filename: previewInfo.filename
            )
            let page = try HwpPageImageRenderer.renderPage(
                document: document,
                pageIndex: 0
            )
            return try HwpPageImageRenderer.encodePNG(page.image)
        }
    }

    private static func pdfReply(_ previewInfo: HwpPreviewDocumentInfo) -> QLPreviewReply {
        QLPreviewReply(
            dataOfContentType: .pdf,
            contentSize: previewInfo.contentSize
        ) { reply in
            reply.title = previewInfo.filename
            let result = try HwpPreviewPDFRenderer.render(previewInfo: previewInfo)
            return result.data
        }
    }

    private static func textReply(_ text: String) -> QLPreviewReply {
        QLPreviewReply(
            dataOfContentType: .plainText,
            contentSize: CGSize(width: 520, height: 120)
        ) { _ in
            Data(text.utf8)
        }
    }
}
