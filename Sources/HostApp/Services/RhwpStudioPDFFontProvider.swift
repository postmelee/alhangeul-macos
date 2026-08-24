import Foundation
import WebKit

enum RhwpStudioPDFFontResource: String, CaseIterable {
    case notoSansKRRegular = "NotoSansKR-Regular.woff2"
    case notoSansKRBold = "NotoSansKR-Bold.woff2"
    case notoSerifKRRegular = "NotoSerifKR-Regular.woff2"
    case notoSerifKRBold = "NotoSerifKR-Bold.woff2"

    static let maximumByteCount = 1_310_720
    static let mimeType = "font/woff2"
    static let fileSignature = Data([0x77, 0x4F, 0x46, 0x32])
}

enum RhwpStudioPDFFontRoute {
    static let scheme = "alhangeul-pdf-font"
    static let host = "bundle"

    static func resource(for url: URL?) throws -> RhwpStudioPDFFontResource {
        guard let url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == scheme,
              components.host?.lowercased() == host,
              components.user == nil,
              components.password == nil,
              components.port == nil,
              components.query == nil,
              components.fragment == nil,
              let filename = components.percentEncodedPath.split(separator: "/").only,
              components.percentEncodedPath == "/\(filename)",
              let resource = RhwpStudioPDFFontResource(rawValue: String(filename))
        else {
            throw RhwpStudioPDFFontResourceError.invalidURL(url?.absoluteString ?? "nil")
        }

        return resource
    }
}

protocol RhwpStudioPDFFontResourceProviding {
    func data(for resource: RhwpStudioPDFFontResource) throws -> Data
}

struct RhwpStudioPDFFontBundleResourceProvider: RhwpStudioPDFFontResourceProviding {
    private let bundle: Bundle
    private let fileManager: FileManager

    init(bundle: Bundle = .main, fileManager: FileManager = .default) {
        self.bundle = bundle
        self.fileManager = fileManager
    }

    func data(for resource: RhwpStudioPDFFontResource) throws -> Data {
        guard let studioResourceDirectory = bundle.url(
            forResource: "rhwp-studio",
            withExtension: nil
        ) else {
            throw RhwpStudioPDFFontResourceError.missingResourceDirectory("rhwp-studio/fonts")
        }

        let provider = RhwpStudioPDFFontDirectoryResourceProvider(
            directoryURL: studioResourceDirectory.appendingPathComponent("fonts", isDirectory: true),
            fileManager: fileManager
        )
        return try provider.data(for: resource)
    }
}

struct RhwpStudioPDFFontDirectoryResourceProvider: RhwpStudioPDFFontResourceProviding {
    private let directoryURL: URL
    private let fileManager: FileManager

    init(directoryURL: URL, fileManager: FileManager = .default) {
        self.directoryURL = directoryURL
        self.fileManager = fileManager
    }

    func data(for resource: RhwpStudioPDFFontResource) throws -> Data {
        let canonicalDirectoryURL = directoryURL
            .resolvingSymlinksInPath()
            .standardizedFileURL
        let unresolvedFileURL = directoryURL
            .appendingPathComponent(resource.rawValue, isDirectory: false)
            .standardizedFileURL
        let fileURL = unresolvedFileURL
            .resolvingSymlinksInPath()
            .standardizedFileURL

        guard unresolvedFileURL.deletingLastPathComponent() == directoryURL.standardizedFileURL,
              fileURL.deletingLastPathComponent() == canonicalDirectoryURL
        else {
            throw RhwpStudioPDFFontResourceError.invalidResourceFile(resource.rawValue)
        }

        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try fileManager.attributesOfItem(atPath: unresolvedFileURL.path)
        } catch {
            throw RhwpStudioPDFFontResourceError.missingResource(resource.rawValue)
        }

        guard attributes[.type] as? FileAttributeType == .typeRegular,
              let byteCount = (attributes[.size] as? NSNumber)?.intValue,
              byteCount > 0
        else {
            throw RhwpStudioPDFFontResourceError.invalidResourceFile(resource.rawValue)
        }
        guard byteCount <= RhwpStudioPDFFontResource.maximumByteCount else {
            throw RhwpStudioPDFFontResourceError.resourceTooLarge(
                name: resource.rawValue,
                actual: byteCount,
                maximum: RhwpStudioPDFFontResource.maximumByteCount
            )
        }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
        } catch {
            throw RhwpStudioPDFFontResourceError.unreadableResource(
                name: resource.rawValue,
                reason: error.localizedDescription
            )
        }
        guard !data.isEmpty else {
            throw RhwpStudioPDFFontResourceError.invalidResourceFile(resource.rawValue)
        }
        guard data.count <= RhwpStudioPDFFontResource.maximumByteCount else {
            throw RhwpStudioPDFFontResourceError.resourceTooLarge(
                name: resource.rawValue,
                actual: data.count,
                maximum: RhwpStudioPDFFontResource.maximumByteCount
            )
        }
        guard data.starts(with: RhwpStudioPDFFontResource.fileSignature) else {
            throw RhwpStudioPDFFontResourceError.invalidResourceFormat(resource.rawValue)
        }

        return data
    }
}

final class RhwpStudioPDFFontSchemeHandler: NSObject, WKURLSchemeHandler {
    private let resourceProvider: RhwpStudioPDFFontResourceProviding

    init(resourceProvider: RhwpStudioPDFFontResourceProviding) {
        self.resourceProvider = resourceProvider
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        do {
            let resource = try RhwpStudioPDFFontRoute.resource(for: urlSchemeTask.request.url)
            let data = try resourceProvider.data(for: resource)
            guard !data.isEmpty else {
                throw RhwpStudioPDFFontResourceError.invalidResourceFile(resource.rawValue)
            }
            guard data.count <= RhwpStudioPDFFontResource.maximumByteCount else {
                throw RhwpStudioPDFFontResourceError.resourceTooLarge(
                    name: resource.rawValue,
                    actual: data.count,
                    maximum: RhwpStudioPDFFontResource.maximumByteCount
                )
            }
            guard data.starts(with: RhwpStudioPDFFontResource.fileSignature) else {
                throw RhwpStudioPDFFontResourceError.invalidResourceFormat(resource.rawValue)
            }

            let response = URLResponse(
                url: urlSchemeTask.request.url!,
                mimeType: RhwpStudioPDFFontResource.mimeType,
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        } catch {
            urlSchemeTask.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}

enum RhwpStudioPDFFontStyle {
    static let hangulUnicodeRanges: [ClosedRange<UInt32>] = [
        0x1100...0x11FF,
        0x3130...0x318F,
        0x3200...0x321E,
        0x3260...0x327F,
        0xA960...0xA97F,
        0xAC00...0xD7AF,
        0xD7B0...0xD7FF
    ]

    static let hangulUnicodeRange = hangulUnicodeRanges
        .map { range in
            String(format: "U+%04X-%04X", range.lowerBound, range.upperBound)
        }
        .joined(separator: ", ")

    static let hangulJavaScriptCharacterClass = hangulUnicodeRanges
        .map { range in
            String(format: "\\u%04X-\\u%04X", range.lowerBound, range.upperBound)
        }
        .joined()

    static let sansAliases = [
        "Haansoft Dotum",
        "HYhaeseo",
        "HY중고딕",
        "휴먼고딕",
        "Malgun Gothic",
        "맑은 고딕",
        "Noto Sans KR ExtraLight",
        "Noto Sans KR"
    ]

    static let serifAliases = [
        "Haansoft Batang",
        "Batang",
        "바탕",
        "Nanum Myeongjo",
        "Noto Serif KR"
    ]

    static let ownedFamilyNamesJSON: String = {
        let data = try! JSONSerialization.data(
            withJSONObject: sansAliases + serifAliases,
            options: []
        )
        return String(decoding: data, as: UTF8.self)
    }()

    static let fontFaceCSS: String = {
        var rules: [String] = []
        for alias in sansAliases {
            rules.append(face(
                alias: alias,
                resource: .notoSansKRRegular,
                weight: "400"
            ))
            rules.append(face(
                alias: alias,
                resource: .notoSansKRBold,
                weight: "500 900"
            ))
        }
        for alias in serifAliases {
            rules.append(face(
                alias: alias,
                resource: .notoSerifKRRegular,
                weight: "400"
            ))
            rules.append(face(
                alias: alias,
                resource: .notoSerifKRBold,
                weight: "500 900"
            ))
        }
        return rules.joined(separator: "\n")
    }()

    private static func face(
        alias: String,
        resource: RhwpStudioPDFFontResource,
        weight: String
    ) -> String {
        let source = "\(RhwpStudioPDFFontRoute.scheme)://\(RhwpStudioPDFFontRoute.host)/\(resource.rawValue)"
        return "@font-face { font-family: '\(alias)'; src: url('\(source)') format('woff2'); font-style: normal; font-weight: \(weight); font-display: block; unicode-range: \(hangulUnicodeRange); }"
    }
}

enum RhwpStudioPDFFontResourceError: LocalizedError, Equatable {
    case invalidURL(String)
    case missingResourceDirectory(String)
    case missingResource(String)
    case invalidResourceFile(String)
    case invalidResourceFormat(String)
    case resourceTooLarge(name: String, actual: Int, maximum: Int)
    case unreadableResource(name: String, reason: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let value):
            "허용되지 않은 PDF 글꼴 URL입니다: \(value)"
        case .missingResourceDirectory(let path):
            "PDF 글꼴 리소스 디렉터리를 찾을 수 없습니다: \(path)"
        case .missingResource(let name):
            "PDF 글꼴 리소스를 찾을 수 없습니다: \(name)"
        case .invalidResourceFile(let name):
            "PDF 글꼴 리소스가 일반 파일이 아니거나 비어 있습니다: \(name)"
        case .invalidResourceFormat(let name):
            "PDF 글꼴 리소스가 WOFF2 형식이 아닙니다: \(name)"
        case .resourceTooLarge(let name, let actual, let maximum):
            "PDF 글꼴 리소스 크기가 제한을 초과했습니다: \(name), actual=\(actual), maximum=\(maximum)"
        case .unreadableResource(let name, let reason):
            "PDF 글꼴 리소스를 읽을 수 없습니다: \(name), reason=\(reason)"
        }
    }
}

private extension Collection {
    var only: Element? {
        count == 1 ? first : nil
    }
}
