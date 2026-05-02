import Foundation

enum RhwpStudioResourceLocator {
    private static let resourceDirectoryName = "rhwp-studio"
    private static let indexHTMLFilename = "index.html"

    static func resourceDirectoryURL(bundle: Bundle = .main) throws -> URL {
        guard let url = bundle.url(forResource: resourceDirectoryName, withExtension: nil) else {
            throw RhwpStudioResourceLocatorError.missingResourceDirectory(resourceDirectoryName)
        }
        return url
    }

    static func indexHTMLURL(bundle: Bundle = .main) throws -> URL {
        let directoryURL = try resourceDirectoryURL(bundle: bundle)
        let indexURL = directoryURL.appendingPathComponent(indexHTMLFilename, isDirectory: false)

        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            throw RhwpStudioResourceLocatorError.missingIndexHTML(indexURL.path)
        }
        return indexURL
    }

    static func loadURL(for document: RhwpStudioDocumentPayload?, bundle: Bundle = .main) throws -> URL {
        _ = try indexHTMLURL(bundle: bundle)

        var components = URLComponents()
        components.scheme = RhwpStudioResourceRoute.scheme
        components.host = RhwpStudioResourceRoute.host
        components.path = "/index.html"

        if let document {
            components.queryItems = [
                URLQueryItem(
                    name: "url",
                    value: RhwpStudioDocumentRoute.currentDocumentURL(revision: document.revision).absoluteString
                ),
                URLQueryItem(name: "filename", value: document.filename)
            ]
        } else {
            components.queryItems = nil
        }

        guard let url = components.url else {
            throw RhwpStudioResourceLocatorError.invalidIndexURL(RhwpStudioResourceRoute.scheme)
        }
        return url
    }

    static func isBundledResourceURL(_ url: URL, bundle: Bundle = .main) -> Bool {
        guard url.isFileURL, let resourceDirectoryURL = try? resourceDirectoryURL(bundle: bundle) else {
            return false
        }

        let resourcePath = resourceDirectoryURL.standardizedFileURL.path
        let targetPath = url.standardizedFileURL.path
        return targetPath == resourcePath || targetPath.hasPrefix(resourcePath + "/")
    }
}

enum RhwpStudioResourceLocatorError: LocalizedError {
    case missingResourceDirectory(String)
    case missingIndexHTML(String)
    case invalidIndexURL(String)

    var errorDescription: String? {
        switch self {
        case .missingResourceDirectory(let name):
            return "rhwp-studio 리소스 디렉터리를 찾을 수 없습니다: \(name)"
        case .missingIndexHTML(let path):
            return "rhwp-studio index.html을 찾을 수 없습니다: \(path)"
        case .invalidIndexURL(let value):
            return "rhwp-studio 진입 URL을 만들 수 없습니다: \(value)"
        }
    }
}
