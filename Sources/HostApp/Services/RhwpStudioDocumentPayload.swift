import Foundation

struct RhwpStudioDocumentPayload {
    let data: Data
    let filename: String
    let revision: Int
}

enum RhwpStudioDocumentRoute {
    static let scheme = "alhangeul-document"
    static let currentHost = "current"
    static let revisionQueryItemName = "revision"

    static func currentDocumentURL(revision: Int) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = currentHost
        components.queryItems = [
            URLQueryItem(name: revisionQueryItemName, value: String(revision))
        ]

        guard let url = components.url else {
            preconditionFailure("Failed to build rhwp-studio document URL")
        }
        return url
    }

    static func isCurrentDocumentURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == scheme && url.host == currentHost
    }

    static func revision(from url: URL) -> Int? {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let value = components.queryItems?.first(where: { $0.name == revisionQueryItemName })?.value
        else {
            return nil
        }
        return Int(value)
    }
}
