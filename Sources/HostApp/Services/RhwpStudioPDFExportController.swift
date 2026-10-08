import Foundation
import PDFKit

@MainActor
final class RhwpStudioPDFExportController {
    private let renderer: RhwpStudioPagePDFRenderer
    private var completion: ((Result<URL, Error>) -> Void)?
    private var isExporting = false
    private var isFinishing = false
    private var writeTask: Task<Void, Never>?
    private let outputFonts: RhwpStudioOutputFontJob?
    private var generation: UInt64 = 0

    init(renderer: RhwpStudioPagePDFRenderer? = nil, outputFonts: RhwpStudioOutputFontJob? = nil) {
        self.outputFonts = outputFonts
        self.renderer = renderer ?? RhwpStudioPagePDFRenderer(outputFonts:outputFonts)
    }

    func cancel() {
        guard isExporting, !isFinishing else { return }
        writeTask?.cancel(); renderer.cancel(); outputFonts?.cancel()
        finish(.failure(RhwpStudioOutputFontError.cancelled))
    }

    func export(
        payload: RhwpStudioPagePayload,
        destinationURL: URL,
        validateBeforeWrite: @escaping @MainActor () async throws -> Void = {},
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        guard !isExporting else {
            completion(.failure(RhwpStudioPDFExportError.exportInProgress))
            return
        }

        self.completion = completion
        isExporting = true
        isFinishing = false
        generation += 1
        let exportGeneration = generation
        renderer.render(payload: payload) { [weak self] result in
            guard let self, self.generation == exportGeneration, self.isExporting, !self.isFinishing else {
                return
            }

            switch result {
            case .success(let document):
                guard let data = document.dataRepresentation(),
                      data.starts(with: Data("%PDF".utf8))
                else {
                    self.finish(.failure(RhwpStudioPDFExportError.pdfEncodingFailed))
                    return
                }
                self.writeTask = Task { @MainActor in
                    do {
                        try await validateBeforeWrite()
                        if let outputFonts = self.outputFonts { try await outputFonts.validate() }
                        try Task.checkCancellation()
                        guard self.isExporting, !self.isFinishing else { throw RhwpStudioOutputFontError.cancelled }
                        // 마지막 세션 검증과 atomic write 사이 native 문서 교체를 허용하지 않는다.
                        try data.write(to: destinationURL, options: .atomic)
                        self.finish(.success(destinationURL), generation:exportGeneration)
                    } catch {
                        self.finish(.failure(error), generation:exportGeneration)
                    }
                }
            case .failure(let error):
                self.finish(.failure(error))
            }
        }
    }

    private func finish(_ result: Result<URL, Error>, generation expected: UInt64? = nil) {
        guard (expected == nil || expected == generation), isExporting, !isFinishing else {
            return
        }

        isFinishing = true
        writeTask = nil
        Task { @MainActor in
            await outputFonts?.close()
            isExporting = false; isFinishing = false
            let completion = completion
            self.completion = nil
            completion?(result)
        }
    }
}

enum RhwpStudioPDFExportError: LocalizedError, Equatable {
    case exportInProgress
    case pdfEncodingFailed

    var errorDescription: String? {
        switch self {
        case .exportInProgress:
            "PDF 내보내기가 이미 진행 중입니다."
        case .pdfEncodingFailed:
            "PDF 데이터를 만들 수 없습니다."
        }
    }
}
