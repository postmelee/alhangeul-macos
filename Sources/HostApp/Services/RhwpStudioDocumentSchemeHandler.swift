import Foundation
import WebKit

final class RhwpStudioDocumentProvider {
    private let lock = NSLock()
    private var payload: RhwpStudioDocumentPayload?

    func setDocument(_ payload: RhwpStudioDocumentPayload?) {
        lock.lock()
        defer { lock.unlock() }
        self.payload = payload
    }

    func document(matching revision: Int?) -> RhwpStudioDocumentPayload? {
        lock.lock()
        defer { lock.unlock() }

        guard let payload else {
            return nil
        }

        if let revision, payload.revision != revision {
            return nil
        }
        return payload
    }

    func diagnosticSnapshot() -> RhwpStudioDocumentProviderSnapshot {
        lock.lock()
        defer { lock.unlock() }

        return RhwpStudioDocumentProviderSnapshot(payload: payload)
    }
}

struct RhwpStudioDocumentProviderSnapshot {
    let revision: Int?
    let filename: String?
    let byteCount: Int?

    init(payload: RhwpStudioDocumentPayload?) {
        revision = payload?.revision
        filename = payload?.filename
        byteCount = payload?.data.count
    }
}

final class RhwpStudioDocumentSchemeHandler: NSObject, WKURLSchemeHandler {
    private let documentProvider: RhwpStudioDocumentProvider

    init(documentProvider: RhwpStudioDocumentProvider) {
        self.documentProvider = documentProvider
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            sendFailure("문서 요청 URL이 없습니다.", to: urlSchemeTask)
            return
        }

        guard RhwpStudioDocumentRoute.isCurrentDocumentURL(url) else {
            sendFailure("허용되지 않은 문서 요청입니다.", url: url, to: urlSchemeTask)
            return
        }

        guard let requestedRevision = RhwpStudioDocumentRoute.revision(from: url) else {
            sendFailure("문서 요청 revision이 없습니다.", url: url, to: urlSchemeTask)
            return
        }

        guard let document = documentProvider.document(matching: requestedRevision) else {
            sendFailure(
                "요청한 문서 revision을 찾을 수 없습니다.",
                url: url,
                requestedRevision: requestedRevision,
                to: urlSchemeTask
            )
            return
        }

        sendDocument(document, url: url, to: urlSchemeTask)
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
    }

    private func sendDocument(
        _ document: RhwpStudioDocumentPayload,
        url: URL,
        to urlSchemeTask: WKURLSchemeTask
    ) {
        let headers = [
            "Access-Control-Allow-Origin": "*",
            "Cache-Control": "no-store",
            "Content-Length": String(document.data.count),
            "Content-Type": "application/octet-stream"
        ]

        guard let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        ) else {
            sendFailure(
                "문서 응답을 만들 수 없습니다.",
                url: url,
                requestedRevision: document.revision,
                to: urlSchemeTask
            )
            return
        }

        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(document.data)
        urlSchemeTask.didFinish()
    }

    private func sendFailure(
        _ message: String,
        url: URL? = nil,
        requestedRevision: Int? = nil,
        to urlSchemeTask: WKURLSchemeTask
    ) {
        let snapshot = documentProvider.diagnosticSnapshot()
        var userInfo: [String: Any] = [
            NSLocalizedDescriptionKey: message
        ]
        if let url {
            userInfo[NSURLErrorFailingURLErrorKey] = url
            userInfo[NSURLErrorFailingURLStringErrorKey] = url.absoluteString
        }
        if let requestedRevision {
            userInfo[RhwpStudioWebViewDiagnosticKeys.requestedRevision] = requestedRevision
        }
        if let revision = snapshot.revision {
            userInfo[RhwpStudioWebViewDiagnosticKeys.currentRevision] = revision
        }
        if let byteCount = snapshot.byteCount {
            userInfo[RhwpStudioWebViewDiagnosticKeys.payloadByteCount] = byteCount
        }
        if let filename = snapshot.filename {
            userInfo[RhwpStudioWebViewDiagnosticKeys.payloadFilename] = filename
        }

        let error = NSError(
            domain: RhwpStudioWebViewDiagnosticKeys.documentSchemeErrorDomain,
            code: 1,
            userInfo: userInfo
        )
        urlSchemeTask.didFailWithError(error)
    }
}
