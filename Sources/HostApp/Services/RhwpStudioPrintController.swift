import AppKit
import PDFKit

@MainActor
final class RhwpStudioPrintController: RhwpStudioPrintControlling {
    private let renderer: RhwpStudioPagePDFRenderer
    private let outputFonts: RhwpStudioOutputFontJob?
    private let onSealed: @MainActor () async -> Void
    private let runOperation: @MainActor (PDFDocument, String) -> Bool?
    private let onResult: @MainActor (RhwpStudioPrintResult) -> Void
    private let presentError: @MainActor (Error) -> Void
    private var completion: (() -> Void)?
    private var renderedDocument: PDFDocument?
    private var didFinish = false
    private var sealed = false
    private var preparationTask: Task<Void, Never>?
    private var isPrinting = false
    private var generation: UInt64 = 0

    init(renderer: RhwpStudioPagePDFRenderer? = nil, outputFonts: RhwpStudioOutputFontJob? = nil,
         onSealed: @escaping @MainActor () async -> Void = {},
         runOperation: (@MainActor (PDFDocument, String) -> Bool?)? = nil,
         onResult: @escaping @MainActor (RhwpStudioPrintResult) -> Void = { _ in },
         presentError: @escaping @MainActor (Error) -> Void = RhwpStudioPrintErrorPresenter.present) {
        self.renderer = renderer ?? .init(outputFonts:outputFonts)
        self.outputFonts = outputFonts; self.onSealed = onSealed
        self.runOperation = runOperation ?? Self.runLiveOperation; self.onResult = onResult; self.presentError = presentError
    }

    func cancel() {
        // 확정한 PDF로 열린 패널/이미 spool된 출력을 취소했다고 취급하지 않는다.
        guard isPrinting, !sealed, !didFinish else { return }
        preparationTask?.cancel(); renderer.cancel(); outputFonts?.cancel()
        finish(.cancelledBeforePanel)
    }

    func print(payload: RhwpStudioPagePayload, completion: @escaping () -> Void) {
        guard !isPrinting else {
            onResult(.failed(RhwpStudioPrintError.printInProgress)); completion(); return
        }
        isPrinting = true
        generation += 1
        let printGeneration = generation
        let fileName = payload.fileName
        self.completion = completion
        didFinish = false
        sealed = false
        renderer.render(payload: payload) { [weak self] result in
            guard let self, self.generation == printGeneration, !self.didFinish else {
                return
            }
            switch result {
            case .success(let document):
                self.renderedDocument = document
                self.preparationTask = Task { @MainActor in
                    do {
                        if let outputFonts = self.outputFonts { try await outputFonts.seal() }
                        try Task.checkCancellation()
                        guard self.generation == printGeneration, !self.didFinish else { return }
                        self.sealed = true
                        await self.onSealed()
                        guard let result = self.runOperation(document,fileName) else {
                            throw RhwpStudioPrintError.printOperationUnavailable
                        }
                        self.finish(result ? .completed : .cancelledOrFailed, generation:printGeneration)
                    } catch {
                        self.finish(error is CancellationError || error as? RhwpStudioOutputFontError == .cancelled
                            ? .cancelledBeforePanel : .failed(error), generation:printGeneration)
                    }
                }
            case .failure(let error):
                self.finish(error as? RhwpStudioOutputFontError == .cancelled ? .cancelledBeforePanel : .failed(error))
            }
        }
    }

    static func runLiveOperation(document: PDFDocument, fileName: String) -> Bool? {
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
            return nil
        }

        operation.jobTitle = fileName
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        return operation.run()
    }

    private func finish(_ result: RhwpStudioPrintResult, generation expected: UInt64? = nil) {
        guard (expected == nil || expected == generation), !didFinish else {
            return
        }

        didFinish = true
        preparationTask = nil
        Task { @MainActor [self] in
            await outputFonts?.close()
            if case .failed(let error) = result { presentError(error) }
            onResult(result)
            let completion = completion
            self.completion = nil
            renderedDocument = nil
            isPrinting = false
            completion?()
        }
    }
}

enum RhwpStudioPrintResult {
    case completed, cancelledBeforePanel, cancelledOrFailed, failed(Error)
}

enum RhwpStudioPrintError: LocalizedError {
    case printOperationUnavailable
    case printInProgress

    var errorDescription: String? {
        switch self {
        case .printOperationUnavailable:
            "PDF 인쇄 작업을 만들 수 없습니다."
        case .printInProgress:
            "인쇄가 이미 진행 중입니다."
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
