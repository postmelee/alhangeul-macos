import CoreGraphics
import Foundation

struct HwpRenderedPreviewPDF {
    let data: Data
    let contentSize: CGSize
    let pageCount: Int
}

struct HwpPreviewDocumentInfo {
    let data: Data
    let filename: String
    let contentSize: CGSize
    let pageCount: Int
}

struct HwpPreviewDocumentContext {
    let data: Data
    let filename: String
    let contentSize: CGSize
    let pageCount: Int
    let document: RhwpDocument

    var documentInfo: HwpPreviewDocumentInfo {
        HwpPreviewDocumentInfo(
            data: data,
            filename: filename,
            contentSize: contentSize,
            pageCount: pageCount
        )
    }
}

enum HwpPreviewPDFRenderer {
    static func load(fileURL: URL) throws -> HwpPreviewDocumentContext {
        let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])
        if let fileSize = values.fileSize, fileSize > hwpQuickLookMaxFileSize {
            throw HwpRenderError.fileTooLarge
        }

        let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
        let document = try RhwpDocument(data: data, filename: fileURL.lastPathComponent)
        let pageCount = document.pageCount
        guard pageCount > 0 else {
            throw HwpRenderError.emptyDocument
        }

        let firstPageSize = document.pageSize(at: 0)
        guard firstPageSize.width > 0, firstPageSize.height > 0 else {
            throw HwpRenderError.invalidPageSize
        }

        return HwpPreviewDocumentContext(
            data: data,
            filename: fileURL.lastPathComponent,
            contentSize: CGSize(width: firstPageSize.width, height: firstPageSize.height),
            pageCount: pageCount,
            document: document
        )
    }

    static func inspect(fileURL: URL) throws -> HwpPreviewDocumentInfo {
        try load(fileURL: fileURL).documentInfo
    }

    static func render(fileURL: URL) throws -> HwpRenderedPreviewPDF {
        try render(context: load(fileURL: fileURL))
    }

    static func render(context: HwpPreviewDocumentContext) throws -> HwpRenderedPreviewPDF {
        try render(
            document: context.document,
            pageCount: context.pageCount,
            contentSize: context.contentSize
        )
    }

    static func render(previewInfo: HwpPreviewDocumentInfo) throws -> HwpRenderedPreviewPDF {
        let document = try RhwpDocument(
            data: previewInfo.data,
            filename: previewInfo.filename
        )
        return try render(
            document: document,
            pageCount: previewInfo.pageCount,
            contentSize: previewInfo.contentSize
        )
    }

    static func render(
        document: RhwpDocument,
        pageCount: Int,
        contentSize: CGSize
    ) throws -> HwpRenderedPreviewPDF {
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else {
            throw HwpRenderError.pdfEncodingFailed
        }

        var mediaBox = CGRect(
            origin: .zero,
            size: contentSize
        )
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw HwpRenderError.pdfEncodingFailed
        }

        for pageIndex in 0..<pageCount {
            let renderedPage = try HwpPageImageRenderer.renderPage(
                document: document,
                pageIndex: pageIndex
            )
            drawPDFPage(renderedPage, in: context)
        }

        context.closePDF()
        guard pdfData.length > 0 else {
            throw HwpRenderError.pdfEncodingFailed
        }

        return HwpRenderedPreviewPDF(
            data: pdfData as Data,
            contentSize: contentSize,
            pageCount: pageCount
        )
    }

    private static func drawPDFPage(_ page: HwpRenderedPage, in context: CGContext) {
        let pageRect = CGRect(origin: .zero, size: page.size)
        var mediaBox = pageRect
        let mediaBoxData = NSData(bytes: &mediaBox, length: MemoryLayout<CGRect>.size)
        let pageInfo = [
            kCGPDFContextMediaBox as String: mediaBoxData
        ] as CFDictionary

        context.beginPDFPage(pageInfo)
        context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        context.fill(pageRect)
        context.draw(page.image, in: pageRect)
        context.endPDFPage()
    }
}
