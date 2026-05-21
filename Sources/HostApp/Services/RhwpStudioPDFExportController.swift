import AppKit
import Foundation

final class RhwpStudioPDFExportController {
    @MainActor
    func export(
        data: Data,
        filename: String,
        destinationURL: URL,
        completion: @escaping (Result<URL?, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result: Result<URL?, Error>
            do {
                let pdfData = try Self.renderPDFData(data: data, filename: filename)
                try pdfData.write(to: destinationURL, options: .atomic)
                result = .success(destinationURL)
            } catch {
                result = .failure(error)
            }

            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    @MainActor
    func export(
        data: Data,
        filename: String,
        completion: @escaping (Result<URL?, Error>) -> Void
    ) {
        guard let destinationURL = DocumentPDFExportPanel.chooseDestinationURL(
            suggestedFilename: filename
        ) else {
            completion(.success(nil))
            return
        }

        export(
            data: data,
            filename: filename,
            destinationURL: destinationURL,
            completion: completion
        )
    }

    private static func renderPDFData(data: Data, filename: String) throws -> Data {
        let document = try RhwpDocument(data: data, filename: filename)
        let pageCount = document.pageCount
        guard pageCount > 0 else {
            throw HwpRenderError.emptyDocument
        }

        let firstPageSize = document.pageSize(at: 0)
        guard firstPageSize.width > 0, firstPageSize.height > 0 else {
            throw HwpRenderError.invalidPageSize
        }

        let renderedPDF = try HwpPreviewPDFRenderer.render(
            document: document,
            pageCount: pageCount,
            contentSize: CGSize(width: firstPageSize.width, height: firstPageSize.height)
        )
        return renderedPDF.data
    }
}
