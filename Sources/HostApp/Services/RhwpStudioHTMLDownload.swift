import Foundation
import WebKit

/// 한 요청의 Blob만 임시 파일로 받고, native 검증·게시 전 bytes를 반환한다.
@MainActor
final class RhwpStudioHTMLDownload: NSObject, WKDownloadDelegate {
    let blobURL: URL
    private let format: DocumentHTMLExportFormat
    private let directory: URL
    private let stagingURL: URL
    private var navigationClaimed = false
    private var download: WKDownload?
    private var result: Result<Data, Error>?
    private var continuation: CheckedContinuation<Data, Error>?
    private var timeout: Task<Void, Never>?
    private var isCancelling = false

    init(blobURL: URL, format: DocumentHTMLExportFormat) throws {
        self.blobURL = blobURL
        self.format = format
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("alhangeul-export-\(UUID().uuidString)", isDirectory:true)
        stagingURL = directory.appendingPathComponent("download.\(format.rawValue)")
        try FileManager.default.createDirectory(at:directory, withIntermediateDirectories:false)
        super.init()
        timeout = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds:30_000_000_000)
            guard !Task.isCancelled else { return }
            self?.cancel(error:DocumentHTMLExportError.timedOut)
        }
    }

    func claimNavigation(_ url: URL) -> Bool {
        guard url == blobURL, !navigationClaimed, result == nil, !isCancelling else { return false }
        navigationClaimed = true
        return true
    }

    func receive(_ download: WKDownload, url: URL?) {
        guard url == blobURL, navigationClaimed, self.download == nil, result == nil, !isCancelling else {
            download.cancel { _ in }
            return
        }
        self.download = download
        download.delegate = self
    }

    func data() async throws -> Data {
        if let result { return try result.get() }
        return try await withCheckedThrowingContinuation { continuation = $0 }
    }

    func cancel(error: Error = DocumentHTMLExportError.cancelled) {
        guard result == nil, !isCancelling else { return }
        isCancelling = true
        if let download {
            download.cancel { [self] _ in finish(.failure(error)) }
        } else {
            finish(.failure(error))
        }
    }

    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse,
                  suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        do {
            guard self.download === download, response.url == blobURL, !isCancelling else {
                throw DocumentHTMLExportError.invalidDownload
            }
            try format.validateResponse(mime:response.mimeType, filename:suggestedFilename)
            completionHandler(stagingURL)
        } catch {
            completionHandler(nil)
            cancel(error:error)
        }
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard self.download === download, !isCancelling else { return }
        finish(Result { try Data(contentsOf:stagingURL) })
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        guard self.download === download, !isCancelling else { return }
        finish(.failure(error))
    }

    private func finish(_ result: Result<Data, Error>) {
        guard self.result == nil else { return }
        self.result = result
        timeout?.cancel()
        timeout = nil
        download?.delegate = nil
        download = nil
        try? FileManager.default.removeItem(at:directory)
        continuation?.resume(with:result)
        continuation = nil
    }
}
