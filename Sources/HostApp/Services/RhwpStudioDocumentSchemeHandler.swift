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

        guard let document = documentProvider.document(matching: RhwpStudioDocumentRoute.revision(from: url)) else {
            sendFailure("요청한 문서 revision을 찾을 수 없습니다.", url: url, to: urlSchemeTask)
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
            sendFailure("문서 응답을 만들 수 없습니다.", url: url, to: urlSchemeTask)
            return
        }

        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(document.data)
        urlSchemeTask.didFinish()
    }

    private func sendFailure(_ message: String, url: URL? = nil, to urlSchemeTask: WKURLSchemeTask) {
        var userInfo: [String: Any] = [
            NSLocalizedDescriptionKey: message
        ]
        if let url {
            userInfo[NSURLErrorFailingURLErrorKey] = url
        }

        let error = NSError(
            domain: "com.postmelee.alhangeul.rhwp-studio.document-scheme",
            code: 1,
            userInfo: userInfo
        )
        urlSchemeTask.didFailWithError(error)
    }
}
