import AppKit
import PDFKit

enum RhwpStudioPrintOrientationPolicy {
    static func orientation(for document: PDFDocument) -> NSPrintInfo.PaperOrientation? {
        var resolvedOrientation: NSPrintInfo.PaperOrientation?

        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else {
                continue
            }

            let bounds = page.bounds(for: .mediaBox)
            guard bounds.width.isFinite,
                  bounds.height.isFinite,
                  bounds.width > 0,
                  bounds.height > 0,
                  bounds.width != bounds.height
            else {
                continue
            }

            let pageOrientation: NSPrintInfo.PaperOrientation = bounds.width > bounds.height
                ? .landscape
                : .portrait

            if let resolvedOrientation, resolvedOrientation != pageOrientation {
                return nil
            }
            resolvedOrientation = pageOrientation
        }

        return resolvedOrientation
    }
}
