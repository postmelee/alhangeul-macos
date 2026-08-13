import Foundation
import PDFKit

@MainActor
final class RhwpStudioPDFExportController {
    private let renderer = RhwpStudioPagePDFRenderer()
    private var completion: ((Result<URL, Error>) -> Void)?
    private var isExporting = false

    func export(
        payload: RhwpStudioPagePayload,
        destinationURL: URL,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        guard !isExporting else {
            completion(.failure(RhwpStudioPDFExportError.exportInProgress))
            return
        }

        self.completion = completion
        isExporting = true
        renderer.render(payload: payload) { [weak self] result in
            guard let self else {
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
                self.write(data: data, to: destinationURL)
            case .failure(let error):
                self.finish(.failure(error))
            }
        }
    }

    private func write(data: Data, to destinationURL: URL) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result: Result<URL, Error>
            do {
                try data.write(to: destinationURL, options: .atomic)
                result = .success(destinationURL)
            } catch {
                result = .failure(error)
            }

            DispatchQueue.main.async {
                self?.finish(result)
            }
        }
    }

    private func finish(_ result: Result<URL, Error>) {
        guard isExporting else {
            return
        }

        isExporting = false
        let completion = completion
        self.completion = nil
        completion?(result)
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
