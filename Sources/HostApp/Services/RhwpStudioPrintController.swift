import AppKit
import PDFKit

@MainActor
final class RhwpStudioPrintController: RhwpStudioPrintControlling {
    private let renderer = RhwpStudioPagePDFRenderer()
    private var completion: (() -> Void)?
    private var renderedDocument: PDFDocument?
    private var printOperation: NSPrintOperation?
    private var didFinish = false

    func print(payload: RhwpStudioPagePayload, completion: @escaping () -> Void) {
        let fileName = payload.fileName
        self.completion = completion
        didFinish = false
        renderer.render(payload: payload) { [weak self] result in
            guard let self else {
                return
            }
            switch result {
            case .success(let document):
                self.renderedDocument = document
                self.runPrintOperation(document: document, fileName: fileName)
            case .failure(let error):
                self.finish(error: error)
            }
        }
    }

    private func runPrintOperation(document: PDFDocument, fileName: String) {
        let printInfo = NSPrintInfo.shared.copy() as? NSPrintInfo ?? NSPrintInfo()
        printInfo.jobDisposition = .spool
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .fit
        if let orientation = RhwpStudioPrintOrientationPolicy.orientation(for: document) {
            printInfo.orientation = orientation
        }

        guard let operation = document.printOperation(
            for: printInfo,
            scalingMode: .pageScaleDownToFit,
            autoRotate: true
        ) else {
            finish(error: RhwpStudioPrintError.printOperationUnavailable)
            return
        }

        operation.jobTitle = fileName
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        printOperation = operation
        operation.run()
        printOperation = nil
        finish(error: nil)
    }

    private func finish(error: Error?) {
        guard !didFinish else {
            return
        }

        didFinish = true
        if let error {
            RhwpStudioPrintErrorPresenter.present(error)
        }
        let completion = completion
        self.completion = nil
        renderedDocument = nil
        printOperation = nil
        completion?()
    }
}

enum RhwpStudioPrintError: LocalizedError {
    case printOperationUnavailable

    var errorDescription: String? {
        switch self {
        case .printOperationUnavailable:
            "PDF 인쇄 작업을 만들 수 없습니다."
        }
    }
}

enum RhwpStudioPrintErrorPresenter {
    @MainActor
    static func present(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "인쇄할 수 없습니다."
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "확인")
        alert.runModal()
    }
}
