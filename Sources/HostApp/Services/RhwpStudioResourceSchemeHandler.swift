import Foundation
import WebKit

enum RhwpStudioResourceRoute {
    static let scheme = "alhangeul-studio"
    static let host = "app"

    static func isStudioResourceURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == scheme && url.host?.lowercased() == host
    }
}

final class RhwpStudioResourceSchemeHandler: NSObject, WKURLSchemeHandler {
    private let bundle: Bundle
    private let fileManager: FileManager

    init(bundle: Bundle = .main, fileManager: FileManager = .default) {
        self.bundle = bundle
        self.fileManager = fileManager
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url,
              RhwpStudioResourceRoute.isStudioResourceURL(url)
        else {
            urlSchemeTask.didFailWithError(
                resourceError(
                    "Invalid rhwp-studio resource URL",
                    url: urlSchemeTask.request.url
                )
            )
            return
        }

        do {
            let resource = try resolveResource(for: url)
            let data: Data
            do {
                data = try Data(contentsOf: resource.fileURL)
            } catch {
                throw resourceError(
                    "Cannot read rhwp-studio resource: \(resource.relativePath)",
                    url: url,
                    relativePath: resource.relativePath,
                    resolvedFileURL: resource.fileURL,
                    underlyingError: error
                )
            }
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: [
                    "Content-Type": contentType(for: resource.fileURL),
                    "Access-Control-Allow-Origin": "*",
                    "Cache-Control": "no-store"
                ]
            )

            if let response {
                urlSchemeTask.didReceive(response)
            }
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        } catch {
            urlSchemeTask.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

    private struct ResolvedResource {
        let fileURL: URL
        let relativePath: String
    }

    private func resolveResource(for url: URL) throws -> ResolvedResource {
        let directoryURL = try RhwpStudioResourceLocator.resourceDirectoryURL(bundle: bundle)
        let relativePath = normalizedRelativePath(from: url)
        let fileURL = directoryURL.appendingPathComponent(relativePath, isDirectory: false).standardizedFileURL

        guard RhwpStudioResourceLocator.isBundledResourceURL(fileURL, bundle: bundle),
              fileManager.fileExists(atPath: fileURL.path)
        else {
            throw resourceError(
                "Missing rhwp-studio resource: \(relativePath)",
                url: url,
                relativePath: relativePath,
                resolvedFileURL: fileURL
            )
        }

        return ResolvedResource(fileURL: fileURL, relativePath: relativePath)
    }

    private func normalizedRelativePath(from url: URL) -> String {
        var path = url.path
        if path.isEmpty || path == "/" {
            return "index.html"
        }
        if path.hasPrefix("/") {
            path.removeFirst()
        }
        return path
    }

    private func contentType(for fileURL: URL) -> String {
        switch fileURL.pathExtension.lowercased() {
        case "html":
            return "text/html; charset=utf-8"
        case "js":
            return "text/javascript; charset=utf-8"
        case "css":
            return "text/css; charset=utf-8"
        case "wasm":
            return "application/wasm"
        case "json", "webmanifest":
            return "application/json; charset=utf-8"
        case "svg":
            return "image/svg+xml"
        case "png":
            return "image/png"
        case "ico":
            return "image/x-icon"
        case "woff2":
            return "font/woff2"
        default:
            return "application/octet-stream"
        }
    }

    private func resourceError(
        _ message: String,
        url: URL? = nil,
        relativePath: String? = nil,
        resolvedFileURL: URL? = nil,
        underlyingError: Error? = nil
    ) -> NSError {
        var userInfo: [String: Any] = [
            NSLocalizedDescriptionKey: message
        ]
        if let url {
            userInfo[NSURLErrorFailingURLErrorKey] = url
            userInfo[NSURLErrorFailingURLStringErrorKey] = url.absoluteString
        }
        if let relativePath {
            userInfo[RhwpStudioWebViewDiagnosticKeys.relativePath] = relativePath
        }
        if let resolvedFileURL {
            userInfo[RhwpStudioWebViewDiagnosticKeys.resolvedFilePath] = resolvedFileURL.path
        }
        if let resourceDirectoryURL = try? RhwpStudioResourceLocator.resourceDirectoryURL(bundle: bundle) {
            userInfo[RhwpStudioWebViewDiagnosticKeys.resourceDirectoryPath] = resourceDirectoryURL.path
        }
        if let underlyingError {
            userInfo[NSUnderlyingErrorKey] = underlyingError
        }

        return NSError(
            domain: RhwpStudioWebViewDiagnosticKeys.resourceSchemeErrorDomain,
            code: 1,
            userInfo: userInfo
        )
    }
}
