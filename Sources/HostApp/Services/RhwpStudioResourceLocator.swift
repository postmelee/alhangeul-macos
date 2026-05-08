import Foundation

enum RhwpStudioResourceLocator {
    private static let resourceDirectoryName = "rhwp-studio"
    private static let indexHTMLFilename = "index.html"
    private static let assetsDirectoryName = "assets"
    private static let overrideCSSFilename = "alhangeul-wkwebview-overrides.css"

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
        try validateRequiredResources(bundle: bundle)

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

    static func validateRequiredResources(
        bundle: Bundle = .main,
        fileManager: FileManager = .default
    ) throws {
        let directoryURL = try resourceDirectoryURL(bundle: bundle)
        try requireFile(indexHTMLFilename, in: directoryURL, fileManager: fileManager)
        try requireFile(overrideCSSFilename, in: directoryURL, fileManager: fileManager)

        let assetsURL = directoryURL.appendingPathComponent(assetsDirectoryName, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: assetsURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue
        else {
            throw RhwpStudioResourceLocatorError.missingAssetsDirectory(assetsURL.path)
        }

        let assetURLs: [URL]
        do {
            assetURLs = try fileManager.contentsOfDirectory(
                at: assetsURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
        } catch {
            throw RhwpStudioResourceLocatorError.unreadableAssetsDirectory(
                path: assetsURL.path,
                reason: error.localizedDescription
            )
        }
        try requireSingleAsset(
            pattern: "assets/index-*.js",
            in: assetsURL,
            assetURLs: assetURLs
        ) { url in
            url.lastPathComponent.hasPrefix("index-") && url.pathExtension == "js"
        }
        try requireSingleAsset(
            pattern: "assets/index-*.css",
            in: assetsURL,
            assetURLs: assetURLs
        ) { url in
            url.lastPathComponent.hasPrefix("index-") && url.pathExtension == "css"
        }
        try requireSingleAsset(
            pattern: "assets/rhwp_bg-*.wasm",
            in: assetsURL,
            assetURLs: assetURLs
        ) { url in
            url.lastPathComponent.hasPrefix("rhwp_bg-") && url.pathExtension == "wasm"
        }
    }

    private static func requireFile(
        _ filename: String,
        in directoryURL: URL,
        fileManager: FileManager
    ) throws {
        let fileURL = directoryURL.appendingPathComponent(filename, isDirectory: false)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDirectory),
              !isDirectory.boolValue
        else {
            throw RhwpStudioResourceLocatorError.missingRequiredFile(filename, fileURL.path)
        }
    }

    private static func requireSingleAsset(
        pattern: String,
        in directoryURL: URL,
        assetURLs: [URL],
        matches: (URL) -> Bool
    ) throws {
        let count = assetURLs.filter(matches).count
        guard count == 1 else {
            throw RhwpStudioResourceLocatorError.invalidAssetCount(
                pattern: pattern,
                count: count,
                directoryPath: directoryURL.path
            )
        }
    }
}

enum RhwpStudioResourceLocatorError: LocalizedError {
    case missingResourceDirectory(String)
    case missingIndexHTML(String)
    case invalidIndexURL(String)
    case missingRequiredFile(String, String)
    case missingAssetsDirectory(String)
    case unreadableAssetsDirectory(path: String, reason: String)
    case invalidAssetCount(pattern: String, count: Int, directoryPath: String)

    var errorDescription: String? {
        switch self {
        case .missingResourceDirectory(let name):
            return "rhwp-studio 리소스 디렉터리를 찾을 수 없습니다: \(name)"
        case .missingIndexHTML(let path):
            return "rhwp-studio index.html을 찾을 수 없습니다: \(path)"
        case .invalidIndexURL(let value):
            return "rhwp-studio 진입 URL을 만들 수 없습니다: \(value)"
        case .missingRequiredFile(let filename, let path):
            return "rhwp-studio 필수 파일을 찾을 수 없습니다: \(filename) (\(path))"
        case .missingAssetsDirectory(let path):
            return "rhwp-studio assets 디렉터리를 찾을 수 없습니다: \(path)"
        case .unreadableAssetsDirectory(let path, let reason):
            return "rhwp-studio assets 디렉터리를 읽을 수 없습니다: \(path), \(reason)"
        case .invalidAssetCount(let pattern, let count, let directoryPath):
            return "rhwp-studio 필수 asset 개수가 맞지 않습니다: \(pattern), count=\(count), dir=\(directoryPath)"
        }
    }

    var diagnosticDetail: String {
        switch self {
        case .missingResourceDirectory(let name):
            return "missingResourceDirectory=\(name)"
        case .missingIndexHTML(let path):
            return "missingIndexHTML=\(path)"
        case .invalidIndexURL(let value):
            return "invalidIndexURL=\(value)"
        case .missingRequiredFile(let filename, let path):
            return "missingRequiredFile=\(filename)\npath=\(path)"
        case .missingAssetsDirectory(let path):
            return "missingAssetsDirectory=\(path)"
        case .unreadableAssetsDirectory(let path, let reason):
            return "unreadableAssetsDirectory=\(path)\nreason=\(reason)"
        case .invalidAssetCount(let pattern, let count, let directoryPath):
            return "assetPattern=\(pattern)\ncount=\(count)\ndirectoryPath=\(directoryPath)"
        }
    }
}

enum RhwpStudioWebViewFailureCategory: String, Equatable {
    case resourcePreflight
    case resourceScheme
    case documentScheme
    case navigation
    case processTerminated
    case timeout
    case runtime

    var defaultTitle: String {
        switch self {
        case .resourcePreflight:
            return "웹 viewer 자산을 찾을 수 없습니다"
        case .resourceScheme:
            return "웹 viewer 자산을 읽을 수 없습니다"
        case .documentScheme:
            return "문서 데이터를 viewer에 전달할 수 없습니다"
        case .navigation:
            return "웹 viewer 탐색에 실패했습니다"
        case .processTerminated:
            return "웹 viewer 프로세스가 종료되었습니다"
        case .timeout:
            return "웹 viewer 로딩이 지연되고 있습니다"
        case .runtime:
            return "웹 viewer 실행 중 오류가 발생했습니다"
        }
    }

    var defaultMessage: String {
        switch self {
        case .resourcePreflight:
            return "설치본에 viewer 필수 파일이 빠져 있어 문서를 표시할 수 없습니다."
        case .resourceScheme:
            return "viewer asset 요청을 처리하지 못했습니다."
        case .documentScheme:
            return "현재 문서 데이터를 WKWebView viewer에 전달하지 못했습니다."
        case .navigation:
            return "WKWebView가 viewer 진입 URL 또는 내부 탐색을 완료하지 못했습니다."
        case .processTerminated:
            return "WebKit content process가 종료되어 viewer를 다시 로드해야 합니다."
        case .timeout:
            return "지정 시간 안에 WKWebView viewer 로딩이 끝나지 않았습니다."
        case .runtime:
            return "JavaScript 또는 WASM runtime 오류로 viewer가 정상 상태가 아닙니다."
        }
    }
}

struct RhwpStudioWebViewFailure: Error, Identifiable, Equatable {
    let id: UUID
    let category: RhwpStudioWebViewFailureCategory
    let title: String
    let message: String
    let diagnosticDetail: String
    let isFatal: Bool

    init(
        id: UUID = UUID(),
        category: RhwpStudioWebViewFailureCategory,
        title: String? = nil,
        message: String? = nil,
        diagnosticDetail: String,
        isFatal: Bool = true
    ) {
        self.id = id
        self.category = category
        self.title = title ?? category.defaultTitle
        self.message = message ?? category.defaultMessage
        self.diagnosticDetail = diagnosticDetail.isEmpty ? "diagnostic detail 없음" : diagnosticDetail
        self.isFatal = isFatal
    }

    static func resourcePreflight(_ error: RhwpStudioResourceLocatorError) -> RhwpStudioWebViewFailure {
        RhwpStudioWebViewFailure(
            category: .resourcePreflight,
            diagnosticDetail: error.diagnosticDetail
        )
    }

    static func from(error: Error, fallbackURL: URL?) -> RhwpStudioWebViewFailure {
        let nsError = error as NSError
        switch nsError.domain {
        case RhwpStudioWebViewDiagnosticKeys.resourceSchemeErrorDomain:
            return RhwpStudioWebViewFailure(
                category: .resourceScheme,
                diagnosticDetail: diagnosticDetail(for: nsError, fallbackURL: fallbackURL)
            )
        case RhwpStudioWebViewDiagnosticKeys.documentSchemeErrorDomain:
            return RhwpStudioWebViewFailure(
                category: .documentScheme,
                diagnosticDetail: diagnosticDetail(for: nsError, fallbackURL: fallbackURL)
            )
        default:
            return navigation(error: error, fallbackURL: fallbackURL)
        }
    }

    static func navigation(error: Error, fallbackURL: URL?) -> RhwpStudioWebViewFailure {
        RhwpStudioWebViewFailure(
            category: .navigation,
            diagnosticDetail: diagnosticDetail(for: error as NSError, fallbackURL: fallbackURL)
        )
    }

    static func blockedNavigation(to url: URL) -> RhwpStudioWebViewFailure {
        RhwpStudioWebViewFailure(
            category: .navigation,
            message: "허용되지 않은 viewer 탐색을 차단했습니다.",
            diagnosticDetail: "blockedURL=\(url.absoluteString)"
        )
    }

    static func processTerminated(
        lastURL: URL?,
        document: RhwpStudioDocumentPayload?,
        reloadToken: Int
    ) -> RhwpStudioWebViewFailure {
        RhwpStudioWebViewFailure(
            category: .processTerminated,
            diagnosticDetail: loadDiagnosticDetail(
                lastURL: lastURL,
                document: document,
                reloadToken: reloadToken
            )
        )
    }

    static func timeout(
        loadingURL: URL?,
        document: RhwpStudioDocumentPayload?,
        reloadToken: Int,
        timeoutSeconds: Int
    ) -> RhwpStudioWebViewFailure {
        var lines = [
            "timeoutSeconds=\(timeoutSeconds)"
        ]
        lines.append(
            contentsOf: loadDiagnosticDetail(
                lastURL: loadingURL,
                document: document,
                reloadToken: reloadToken
            ).components(separatedBy: "\n")
        )
        return RhwpStudioWebViewFailure(
            category: .timeout,
            diagnosticDetail: lines.joined(separator: "\n")
        )
    }

    static func runtime(
        message: String?,
        sourceURL: String?,
        line: Int?,
        column: Int?,
        reason: String?
    ) -> RhwpStudioWebViewFailure {
        let lines = labeledLines([
            ("message", message),
            ("sourceURL", sourceURL),
            ("line", line.map { String($0) }),
            ("column", column.map { String($0) }),
            ("reason", reason)
        ])

        return RhwpStudioWebViewFailure(
            category: .runtime,
            diagnosticDetail: lines.joined(separator: "\n")
        )
    }

    private static func loadDiagnosticDetail(
        lastURL: URL?,
        document: RhwpStudioDocumentPayload?,
        reloadToken: Int
    ) -> String {
        labeledLines([
            ("lastURL", lastURL?.absoluteString),
            ("documentRevision", document.map { String($0.revision) }),
            ("filename", document?.filename),
            ("byteCount", document.map { String($0.data.count) }),
            ("reloadToken", String(reloadToken))
        ]).joined(separator: "\n")
    }

    private static func diagnosticDetail(for error: NSError, fallbackURL: URL?) -> String {
        var lines = labeledLines([
            ("domain", error.domain),
            ("code", String(error.code)),
            ("description", error.localizedDescription),
            ("fallbackURL", fallbackURL?.absoluteString)
        ])

        appendUserInfoValue(NSURLErrorFailingURLErrorKey, label: "failingURL", from: error, to: &lines)
        appendUserInfoValue(
            NSURLErrorFailingURLStringErrorKey,
            label: "failingURLString",
            from: error,
            to: &lines
        )
        appendUserInfoValue(
            RhwpStudioWebViewDiagnosticKeys.diagnosticDetail,
            label: "detail",
            from: error,
            to: &lines
        )
        appendUserInfoValue(
            RhwpStudioWebViewDiagnosticKeys.relativePath,
            label: "relativePath",
            from: error,
            to: &lines
        )
        appendUserInfoValue(
            RhwpStudioWebViewDiagnosticKeys.resolvedFilePath,
            label: "resolvedFilePath",
            from: error,
            to: &lines
        )
        appendUserInfoValue(
            RhwpStudioWebViewDiagnosticKeys.resourceDirectoryPath,
            label: "resourceDirectoryPath",
            from: error,
            to: &lines
        )
        appendUserInfoValue(
            RhwpStudioWebViewDiagnosticKeys.requestedRevision,
            label: "requestedRevision",
            from: error,
            to: &lines
        )
        appendUserInfoValue(
            RhwpStudioWebViewDiagnosticKeys.currentRevision,
            label: "currentRevision",
            from: error,
            to: &lines
        )
        appendUserInfoValue(
            RhwpStudioWebViewDiagnosticKeys.payloadByteCount,
            label: "payloadByteCount",
            from: error,
            to: &lines
        )
        appendUserInfoValue(
            RhwpStudioWebViewDiagnosticKeys.payloadFilename,
            label: "payloadFilename",
            from: error,
            to: &lines
        )

        if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            lines.append("underlyingDomain=\(underlyingError.domain)")
            lines.append("underlyingCode=\(underlyingError.code)")
            lines.append("underlyingDescription=\(underlyingError.localizedDescription)")
        }

        return lines.joined(separator: "\n")
    }

    private static func labeledLines(_ pairs: [(String, String?)]) -> [String] {
        pairs.compactMap { label, value in
            guard let value, !value.isEmpty else {
                return nil
            }
            return "\(label)=\(value)"
        }
    }

    private static func appendUserInfoValue(
        _ key: String,
        label: String,
        from error: NSError,
        to lines: inout [String]
    ) {
        guard let value = error.userInfo[key] else {
            return
        }
        if let url = value as? URL {
            lines.append("\(label)=\(url.absoluteString)")
        } else {
            lines.append("\(label)=\(value)")
        }
    }
}

enum RhwpStudioWebViewDiagnosticKeys {
    static let resourceSchemeErrorDomain = "com.postmelee.alhangeul.rhwp-studio.resource-scheme"
    static let documentSchemeErrorDomain = "com.postmelee.alhangeul.rhwp-studio.document-scheme"

    static let diagnosticDetail = "com.postmelee.alhangeul.diagnostic-detail"
    static let relativePath = "com.postmelee.alhangeul.relative-path"
    static let resolvedFilePath = "com.postmelee.alhangeul.resolved-file-path"
    static let resourceDirectoryPath = "com.postmelee.alhangeul.resource-directory-path"
    static let requestedRevision = "com.postmelee.alhangeul.requested-revision"
    static let currentRevision = "com.postmelee.alhangeul.current-revision"
    static let payloadByteCount = "com.postmelee.alhangeul.payload-byte-count"
    static let payloadFilename = "com.postmelee.alhangeul.payload-filename"
}
