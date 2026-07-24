import CoreGraphics
import Foundation

struct HwpRenderedPreviewPDF {
    let data: Data
    let contentSize: CGSize
    let pageCount: Int
    let pageDiagnostics: [HwpPreviewPDFPageDiagnostics]
}

struct HwpPreviewPDFPageDiagnostics {
    let pageIndex: Int
    let diagnostics: HwpPageRenderDiagnostics
}

struct HwpPreviewDocumentInfo {
    let data: Data
    let filename: String
    let contentSize: CGSize
    let pageCount: Int
}

struct HwpPreviewDocumentContext {
    let filename: String
    let contentSize: CGSize
    let pageCount: Int
    let document: RhwpDocument
    let externalResourceReport: RhwpExternalResourceReport
}

enum HwpPreviewPDFRenderer {
    static func load(fileURL: URL) throws -> HwpPreviewDocumentContext {
        let input = try loadInput(fileURL: fileURL)
        let openResult = try HwpExternalImageResolver.open(
            data: input.data,
            context: RhwpDocumentOpenContext(
                sourceURL: fileURL,
                displayFilename: input.filename,
                maximumExternalResourceBytes: hwpQuickLookMaxFileSize
            )
        )
        let metadata = try previewMetadata(
            document: openResult.document
        )

        return HwpPreviewDocumentContext(
            filename: input.filename,
            contentSize: metadata.contentSize,
            pageCount: metadata.pageCount,
            document: openResult.document,
            externalResourceReport: openResult.externalResourceReport
        )
    }

    static func inspect(fileURL: URL) throws -> HwpPreviewDocumentInfo {
        let input = try loadInput(fileURL: fileURL)
        let document = try RhwpDocument(
            data: input.data,
            filename: input.filename
        )
        let metadata = try previewMetadata(document: document)
        return HwpPreviewDocumentInfo(
            data: input.data,
            filename: input.filename,
            contentSize: metadata.contentSize,
            pageCount: metadata.pageCount
        )
    }

    static func render(
        fileURL: URL,
        policy: HwpPageRenderPolicy = .coreGraphicsOnly,
        collectDiagnostics: Bool = false
    ) throws -> HwpRenderedPreviewPDF {
        try render(
            context: load(fileURL: fileURL),
            policy: policy,
            collectDiagnostics: collectDiagnostics
        )
    }

    static func render(
        context: HwpPreviewDocumentContext,
        policy: HwpPageRenderPolicy = .coreGraphicsOnly,
        collectDiagnostics: Bool = false
    ) throws -> HwpRenderedPreviewPDF {
        try render(
            document: context.document,
            pageCount: context.pageCount,
            contentSize: context.contentSize,
            policy: policy,
            collectDiagnostics: collectDiagnostics
        )
    }

    static func render(
        previewInfo: HwpPreviewDocumentInfo,
        policy: HwpPageRenderPolicy = .coreGraphicsOnly,
        collectDiagnostics: Bool = false
    ) throws -> HwpRenderedPreviewPDF {
        let document = try RhwpDocument(
            data: previewInfo.data,
            filename: previewInfo.filename
        )
        return try render(
            document: document,
            pageCount: previewInfo.pageCount,
            contentSize: previewInfo.contentSize,
            policy: policy,
            collectDiagnostics: collectDiagnostics
        )
    }

    static func render(
        document: RhwpDocument,
        pageCount: Int,
        contentSize: CGSize,
        policy: HwpPageRenderPolicy = .coreGraphicsOnly,
        collectDiagnostics: Bool = false
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

        var pageDiagnostics: [HwpPreviewPDFPageDiagnostics] = []
        if collectDiagnostics {
            pageDiagnostics.reserveCapacity(pageCount)
        }
        for pageIndex in 0..<pageCount {
            let renderedPage = try HwpPageImageRenderer.renderPage(
                document: document,
                pageIndex: pageIndex,
                policy: policy
            )
            if collectDiagnostics {
                pageDiagnostics.append(
                    HwpPreviewPDFPageDiagnostics(
                        pageIndex: pageIndex,
                        diagnostics: renderedPage.diagnostics
                    )
                )
            }
            drawPDFPage(renderedPage, in: context)
        }

        context.closePDF()
        guard pdfData.length > 0 else {
            throw HwpRenderError.pdfEncodingFailed
        }

        return HwpRenderedPreviewPDF(
            data: pdfData as Data,
            contentSize: contentSize,
            pageCount: pageCount,
            pageDiagnostics: pageDiagnostics
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

    private struct LoadedInput {
        let data: Data
        let filename: String
    }

    private struct PreviewMetadata {
        let contentSize: CGSize
        let pageCount: Int
    }

    private static func loadInput(fileURL: URL) throws -> LoadedInput {
        let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])
        if let fileSize = values.fileSize, fileSize > hwpQuickLookMaxFileSize {
            throw HwpRenderError.fileTooLarge
        }

        let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
        return LoadedInput(
            data: data,
            filename: fileURL.lastPathComponent
        )
    }

    private static func previewMetadata(
        document: RhwpDocument
    ) throws -> PreviewMetadata {
        let pageCount = document.pageCount
        guard pageCount > 0 else {
            throw HwpRenderError.emptyDocument
        }

        let firstPageSize = document.pageSize(at: 0)
        guard firstPageSize.width > 0, firstPageSize.height > 0 else {
            throw HwpRenderError.invalidPageSize
        }

        return PreviewMetadata(
            contentSize: CGSize(width: firstPageSize.width, height: firstPageSize.height),
            pageCount: pageCount
        )
    }
}
