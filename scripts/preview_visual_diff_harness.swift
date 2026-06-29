import AppKit
import CoreGraphics
import Darwin
import Foundation
import ImageIO
import UniformTypeIdentifiers
import WebKit

struct PreviewHarnessError: Error, CustomStringConvertible {
    let description: String
}

enum PreviewHarnessPhase: String {
    case navigation
    case readiness
    case settle
    case canvasExport = "canvas export"
    case snapshot
    case nativeRender = "native render"
    case diff
    case unknown
}

struct PreviewHarnessPhaseError: Error, CustomStringConvertible {
    let phase: PreviewHarnessPhase
    let detail: String

    var description: String {
        "[phase:\(phase.rawValue)] \(detail)"
    }
}

struct HarnessOptions {
    let outputDir: URL
    let resourceDir: URL
    let pageNumber: Int
    let policy: HwpPageRenderPolicy
    let viewportSize: CGSize
    let settleMilliseconds: Int
    let inputURLs: [URL]
}

struct StudioManifest: Decodable {
    let source_release_tag: String
    let source_resolved_commit: String
    let entrypoints: [String: Entrypoint]

    struct Entrypoint: Codable {
        let path: String
        let sha256: String
    }

    static func load(from resourceDir: URL) throws -> StudioManifest {
        let url = resourceDir.appendingPathComponent("manifest.json", isDirectory: false)
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(StudioManifest.self, from: data)
        } catch {
            throw PreviewHarnessError(description: "failed to read rhwp-studio manifest: \(url.path): \(error)")
        }
    }
}

struct RectMetadata: Codable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

struct SizeMetadata: Codable {
    let width: Double
    let height: Double
}

struct StudioCaptureMetadata: Codable {
    let sourcePath: String
    let filename: String
    let page: Int
    let loadURL: String
    let automationLoad: Bool
    let automationStrategy: String
    let automationPageCount: Int
    let automationFileName: String
    let automationSourceFormat: String?
    let automationLocalFontsSeeded: Bool
    let selector: String
    let rect: RectMetadata
    let canvasRect: RectMetadata
    let devicePixelRatio: Double
    let viewportSize: SizeMetadata
    let canvasCount: Int
    let overlayCount: Int
    let usedOverlayUnion: Bool
    let canvasSampleNonWhitePixels: Int
    let canvasSamplePixels: Int
    let snapshotSampleNonWhitePixels: Int
    let snapshotSamplePixels: Int
    let captureMode: String
    let overlayIncluded: Bool
    let statusText: String
    let captureContaminated: Bool
    let uiSuppressed: Bool
    let modalCount: Int
    let toastCount: Int
    let localFontUIVisible: Bool
    let contaminationText: [String]
    let preCaptureUI: UIContaminationProbe
    let postCaptureUI: UIContaminationProbe
    let captureMs: Double
    let settleMs: Int
    let studioReleaseTag: String
    let studioResolvedCommit: String
    let entrypoints: [String: StudioManifest.Entrypoint]
    let chromeHidden: [String]
    let editorChromeResidual: String?
    let pngPath: String
    let pngBytes: Int
    let pngWidth: Int
    let pngHeight: Int
}

struct StudioCaptureResult {
    let fileName: String
    let pngURL: URL
    let jsonURL: URL
    let pngWidth: Int
    let pngHeight: Int
    let canvasCount: Int
    let overlayCount: Int
    let canvasSampleNonWhitePixels: Int
    let canvasSamplePixels: Int
    let captureMode: String
    let captureContaminated: Bool
    let uiSuppressed: Bool
    let captureMs: Double
}

struct AutomationLoadInfo {
    let pageCount: Int
    let fileName: String
    let sourceFormat: String?
    let strategy: String?
    let localFontsSeeded: Bool
    let statusText: String
}

struct UIContaminationProbe: Codable {
    let modalCount: Int
    let toastCount: Int
    let localFontUIVisible: Bool
    let contaminationText: [String]

    var captureContaminated: Bool {
        modalCount > 0 || toastCount > 0 || localFontUIVisible
    }

    init(dictionary: [String: Any]) {
        modalCount = intValue(dictionary["modalCount"])
        toastCount = intValue(dictionary["toastCount"])
        localFontUIVisible = dictionary["localFontUIVisible"] as? Bool ?? false
        contaminationText = stringArrayValue(dictionary["contaminationText"])
    }
}

struct PNGOutput {
    let data: Data
    let width: Int
    let height: Int
    let sampleNonWhitePixels: Int
    let samplePixels: Int
}

struct NativeRenderMetadata: Codable {
    let sourcePath: String
    let filename: String
    let page: Int
    let pageCount: Int
    let policy: String
    let backendUsed: String
    let fallbackReason: String?
    let pageSize: SizeMetadata
    let pixelSize: SizeMetadata
    let pngPath: String
    let pngBytes: Int
    let nonWhiteSamplePixels: Int
    let sampledPixels: Int
    let renderMs: Double
    let skiaRenderMs: Double?
    let pngDecodeMs: Double?
    let coreGraphicsRenderMs: Double?
}

struct NativeRenderResult {
    let pngURL: URL
    let jsonURL: URL
    let image: CGImage
    let pngBytes: Int
    let pageCount: Int
    let policy: String
    let backendUsed: String
    let fallbackReason: String?
    let renderMs: Double
    let pixelWidth: Int
    let pixelHeight: Int
    let nonWhiteSamplePixels: Int
    let sampledPixels: Int
}

struct RGBAImage {
    let width: Int
    let height: Int
    var pixels: [UInt8]
}

struct DiffResult {
    let changedPixels: Int
    let totalPixels: Int
    let changedPercent: Double
    let meanRGBDelta: Double
    let maxRGBDelta: Int
    let bounds: CGRect?
}

struct VisualDiffResult {
    let diffURL: URL
    let changedPixels: Int
    let totalPixels: Int
    let changedPercent: Double
    let meanRGBDelta: Double
    let maxRGBDelta: Int
    let bounds: CGRect?
    let compareWidth: Int
    let compareHeight: Int
}

struct PageState {
    let ready: Bool
    let reason: String
    let selector: String
    let statusText: String
    let canvasCount: Int
    let overlayCount: Int
    let usedOverlayUnion: Bool
    let canvasSampleNonWhitePixels: Int
    let canvasSamplePixels: Int
    let devicePixelRatio: Double
    let viewportSize: SizeMetadata
    let canvasRect: RectMetadata?
    let snapshotRect: RectMetadata?

    init(dictionary: [String: Any]) {
        ready = dictionary["ready"] as? Bool ?? false
        reason = dictionary["reason"] as? String ?? ""
        selector = dictionary["selector"] as? String ?? "#scroll-content canvas"
        statusText = dictionary["statusText"] as? String ?? ""
        canvasCount = intValue(dictionary["canvasCount"])
        overlayCount = intValue(dictionary["overlayCount"])
        usedOverlayUnion = dictionary["usedOverlayUnion"] as? Bool ?? false
        canvasSampleNonWhitePixels = intValue(dictionary["canvasSampleNonWhitePixels"])
        canvasSamplePixels = intValue(dictionary["canvasSamplePixels"])
        devicePixelRatio = doubleValue(dictionary["devicePixelRatio"], default: 1)

        if let viewport = dictionary["viewportSize"] as? [String: Any] {
            viewportSize = SizeMetadata(
                width: doubleValue(viewport["width"]),
                height: doubleValue(viewport["height"])
            )
        } else {
            viewportSize = SizeMetadata(width: 0, height: 0)
        }

        if let rect = dictionary["canvasRect"] as? [String: Any] {
            canvasRect = RectMetadata(
                x: doubleValue(rect["x"]),
                y: doubleValue(rect["y"]),
                width: doubleValue(rect["width"]),
                height: doubleValue(rect["height"])
            )
        } else {
            canvasRect = nil
        }

        if let rect = dictionary["snapshotRect"] as? [String: Any] {
            snapshotRect = RectMetadata(
                x: doubleValue(rect["x"]),
                y: doubleValue(rect["y"]),
                width: doubleValue(rect["width"]),
                height: doubleValue(rect["height"])
            )
        } else {
            snapshotRect = nil
        }
    }
}

final class StudioResourceSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "alhangeul-studio"
    static let host = "app"

    private let resourceDir: URL
    private let fileManager: FileManager
    private let stats: StudioSchemeRequestStats

    init(resourceDir: URL, fileManager: FileManager = .default, stats: StudioSchemeRequestStats) {
        self.resourceDir = resourceDir.standardizedFileURL
        self.fileManager = fileManager
        self.stats = stats
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url,
              url.scheme?.lowercased() == Self.scheme,
              url.host?.lowercased() == Self.host
        else {
            fail("invalid rhwp-studio resource URL", url: urlSchemeTask.request.url, task: urlSchemeTask)
            return
        }

        let relativePath = normalizedRelativePath(from: url)
        stats.recordResource(path: relativePath)
        let fileURL = resourceDir.appendingPathComponent(relativePath, isDirectory: false).standardizedFileURL
        guard isResourceFile(fileURL) else {
            fail("missing rhwp-studio resource: \(relativePath)", url: url, task: urlSchemeTask)
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            guard let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: [
                    "Content-Type": contentType(for: fileURL),
                    "Access-Control-Allow-Origin": "*",
                    "Cache-Control": "no-store"
                ]
            ) else {
                fail("failed to create rhwp-studio resource response", url: url, task: urlSchemeTask)
                return
            }
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        } catch {
            fail("failed to read rhwp-studio resource: \(relativePath): \(error)", url: url, task: urlSchemeTask)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

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

    private func isResourceFile(_ fileURL: URL) -> Bool {
        let rootPath = resourceDir.path
        let targetPath = fileURL.path
        guard targetPath == rootPath || targetPath.hasPrefix(rootPath + "/") else {
            return false
        }
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: targetPath, isDirectory: &isDirectory) && !isDirectory.boolValue
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
        case "txt", "md", "ts":
            return "text/plain; charset=utf-8"
        default:
            return "application/octet-stream"
        }
    }

    private func fail(_ message: String, url: URL?, task: WKURLSchemeTask) {
        stats.recordFailure(message: message, url: url)
        var userInfo: [String: Any] = [NSLocalizedDescriptionKey: message]
        if let url {
            userInfo[NSURLErrorFailingURLErrorKey] = url
        }
        task.didFailWithError(NSError(domain: "PreviewVisualDiffStudioResource", code: -1, userInfo: userInfo))
    }
}

final class StudioDocumentSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "alhangeul-document"
    static let host = "current"

    private let data: Data
    private let revision: Int
    private let stats: StudioSchemeRequestStats

    init(data: Data, revision: Int, stats: StudioSchemeRequestStats) {
        self.data = data
        self.revision = revision
        self.stats = stats
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url,
              url.scheme?.lowercased() == Self.scheme,
              url.host?.lowercased() == Self.host
        else {
            fail("invalid rhwp-studio document URL", url: urlSchemeTask.request.url, task: urlSchemeTask)
            return
        }

        stats.recordDocument()
        guard requestedRevision(from: url) == revision else {
            fail("requested document revision does not match", url: url, task: urlSchemeTask)
            return
        }

        guard let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Access-Control-Allow-Origin": "*",
                "Cache-Control": "no-store",
                "Content-Length": String(data.count),
                "Content-Type": "application/octet-stream"
            ]
        ) else {
            fail("failed to create rhwp-studio document response", url: url, task: urlSchemeTask)
            return
        }

        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

    private func requestedRevision(from url: URL) -> Int? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "revision" })?
            .value
            .flatMap(Int.init)
    }

    private func fail(_ message: String, url: URL?, task: WKURLSchemeTask) {
        stats.recordFailure(message: message, url: url)
        var userInfo: [String: Any] = [NSLocalizedDescriptionKey: message]
        if let url {
            userInfo[NSURLErrorFailingURLErrorKey] = url
        }
        task.didFailWithError(NSError(domain: "PreviewVisualDiffStudioDocument", code: -1, userInfo: userInfo))
    }
}

final class StudioSchemeRequestStats {
    private struct Snapshot {
        let resourceRequestCount: Int
        let documentRequestCount: Int
        let resourcePaths: [String]
        let failures: [String]
    }

    private let lock = NSLock()
    private var resourceRequestCount = 0
    private var documentRequestCount = 0
    private var resourcePaths: [String] = []
    private var failures: [String] = []

    func recordResource(path: String) {
        withLock {
            resourceRequestCount += 1
            if resourcePaths.count < 12 {
                resourcePaths.append(path)
            }
        }
    }

    func recordDocument() {
        withLock {
            documentRequestCount += 1
        }
    }

    func recordFailure(message: String, url: URL?) {
        let entry: String
        if let url {
            entry = "\(message) url=\(url.absoluteString)"
        } else {
            entry = message
        }
        withLock {
            guard failures.count < 8 else {
                return
            }
            failures.append(entry)
        }
    }

    var summary: String {
        let snapshot = withLock {
            Snapshot(
                resourceRequestCount: resourceRequestCount,
                documentRequestCount: documentRequestCount,
                resourcePaths: resourcePaths,
                failures: failures
            )
        }
        var parts = [
            "resourceRequests=\(snapshot.resourceRequestCount)",
            "documentRequests=\(snapshot.documentRequestCount)"
        ]
        if !snapshot.resourcePaths.isEmpty {
            parts.append("resourcePaths=[\(snapshot.resourcePaths.joined(separator: ","))]")
        }
        if !snapshot.failures.isEmpty {
            parts.append("requestFailures=[\(snapshot.failures.joined(separator: "; "))]")
        }
        return parts.joined(separator: ", ")
    }

    private func withLock<T>(_ work: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return work()
    }
}

final class StudioReferenceRenderer: NSObject, WKNavigationDelegate {
    private let resourceDir: URL
    private let viewportSize: CGSize
    private let settleMilliseconds: Int
    private var webView: WKWebView?
    private var window: NSWindow?
    private var resourceSchemeHandler: StudioResourceSchemeHandler?
    private var documentSchemeHandler: StudioDocumentSchemeHandler?
    private var navigationResult: Result<Void, Error>?
    private var navigationDidCommit = false
    private var navigationEvents: [String] = []
    private var schemeStats = StudioSchemeRequestStats()

    init(resourceDir: URL, viewportSize: CGSize, settleMilliseconds: Int) {
        self.resourceDir = resourceDir
        self.viewportSize = viewportSize
        self.settleMilliseconds = settleMilliseconds
    }

    func capture(
        inputURL: URL,
        outputDir: URL,
        pageNumber: Int,
        manifest: StudioManifest
    ) throws -> StudioCaptureResult {
        let revision = 1
        let data = try Data(contentsOf: inputURL)
        let documentURL = try makeDocumentURL(revision: revision)
        let loadURL = try makeAutomationAppURL()
        let baseName = outputStem(for: inputURL)
        let outputBase = "\(baseName)-page\(pageNumber)"
        let pngURL = outputDir.appendingPathComponent("\(outputBase)-studio.png", isDirectory: false)
        let jsonURL = outputDir.appendingPathComponent("\(outputBase)-studio.json", isDirectory: false)

        try createWebView(documentData: data, revision: revision)
        defer {
            webView?.navigationDelegate = nil
            webView?.stopLoading()
            window?.orderOut(nil)
            webView = nil
            window = nil
            resourceSchemeHandler = nil
            documentSchemeHandler = nil
            navigationResult = nil
            navigationDidCommit = false
            navigationEvents = []
            schemeStats = StudioSchemeRequestStats()
        }

        let startTime = Date()
        let navigation: WKNavigation?
        if loadURL.isFileURL {
            navigation = webView?.loadFileURL(loadURL, allowingReadAccessTo: resourceDir)
        } else {
            navigation = webView?.load(URLRequest(url: loadURL))
        }
        if navigation == nil {
            recordNavigationEvent("loadReturnedNil:\(loadURL.scheme ?? "nil")")
        }
        try waitForAutomationRuntime(timeout: 30)
        let automationLoadInfo = try loadDocumentForAutomation(
            documentURL: documentURL,
            filename: inputURL.lastPathComponent,
            timeout: 30
        )
        guard pageNumber >= 1, pageNumber <= automationLoadInfo.pageCount else {
            throw PreviewHarnessPhaseError(
                phase: .readiness,
                detail: "automation load page \(pageNumber) is out of range: pageCount=\(automationLoadInfo.pageCount)"
            )
        }
        try waitForPageReady(pageNumber: pageNumber, timeout: 30)
        try alignPageAndHideChrome(pageNumber: pageNumber)
        runMainLoop(milliseconds: settleMilliseconds)
        let pageState = try currentPageState(pageNumber: pageNumber)
        guard pageState.ready else {
            throw PreviewHarnessError(description: "page \(pageNumber) not ready after settle: \(pageState.reason)")
        }
        guard let snapshotRectMetadata = pageState.snapshotRect,
              let canvasRectMetadata = pageState.canvasRect
        else {
            throw PreviewHarnessError(description: "page \(pageNumber) rect is unavailable")
        }

        let preCaptureUI = try currentUIContaminationProbe()
        var png: PNGOutput
        var captureMode = "canvasDataURL"
        var overlayIncluded = false
        var snapshotSampleNonWhitePixels = 0
        var snapshotSamplePixels = 0
        let hasOverlayDOM = pageState.overlayCount > 0 || pageState.usedOverlayUnion
        if hasOverlayDOM {
            png = try exportCompositePNG(pageNumber: pageNumber)
            captureMode = "domComposite"
            overlayIncluded = true
            snapshotSampleNonWhitePixels = png.sampleNonWhitePixels
            snapshotSamplePixels = png.samplePixels
        } else if pageState.canvasSampleNonWhitePixels <= 0 {
            png = try captureSnapshotPNG(rect: snapshotRectMetadata.cgRect)
            captureMode = "webViewSnapshot"
            snapshotSampleNonWhitePixels = png.sampleNonWhitePixels
            snapshotSamplePixels = png.samplePixels
        } else {
            png = try exportCanvasPNG(pageNumber: pageNumber)
            if let snapshotPNG = try? captureSnapshotPNG(rect: snapshotRectMetadata.cgRect) {
                snapshotSampleNonWhitePixels = snapshotPNG.sampleNonWhitePixels
                snapshotSamplePixels = snapshotPNG.samplePixels
            }
        }
        let postCaptureUI = try currentUIContaminationProbe()
        let captureContaminated = preCaptureUI.captureContaminated || postCaptureUI.captureContaminated
        let uiSuppressed = false
        let modalCount = max(preCaptureUI.modalCount, postCaptureUI.modalCount)
        let toastCount = max(preCaptureUI.toastCount, postCaptureUI.toastCount)
        let localFontUIVisible = preCaptureUI.localFontUIVisible || postCaptureUI.localFontUIVisible
        let contaminationText = combinedContaminationText(preCaptureUI, postCaptureUI)
        try png.data.write(to: pngURL, options: .atomic)

        let elapsedMs = Date().timeIntervalSince(startTime) * 1000
        let metadata = StudioCaptureMetadata(
            sourcePath: inputURL.path,
            filename: inputURL.lastPathComponent,
            page: pageNumber,
            loadURL: loadURL.absoluteString,
            automationLoad: true,
            automationStrategy: automationLoadInfo.strategy ?? "unknown",
            automationPageCount: automationLoadInfo.pageCount,
            automationFileName: automationLoadInfo.fileName.isEmpty ? inputURL.lastPathComponent : automationLoadInfo.fileName,
            automationSourceFormat: automationLoadInfo.sourceFormat,
            automationLocalFontsSeeded: automationLoadInfo.localFontsSeeded,
            selector: pageState.selector,
            rect: snapshotRectMetadata,
            canvasRect: canvasRectMetadata,
            devicePixelRatio: pageState.devicePixelRatio,
            viewportSize: pageState.viewportSize,
            canvasCount: pageState.canvasCount,
            overlayCount: pageState.overlayCount,
            usedOverlayUnion: pageState.usedOverlayUnion,
            canvasSampleNonWhitePixels: pageState.canvasSampleNonWhitePixels,
            canvasSamplePixels: pageState.canvasSamplePixels,
            snapshotSampleNonWhitePixels: snapshotSampleNonWhitePixels,
            snapshotSamplePixels: snapshotSamplePixels,
            captureMode: captureMode,
            overlayIncluded: overlayIncluded,
            statusText: pageState.statusText,
            captureContaminated: captureContaminated,
            uiSuppressed: uiSuppressed,
            modalCount: modalCount,
            toastCount: toastCount,
            localFontUIVisible: localFontUIVisible,
            contaminationText: contaminationText,
            preCaptureUI: preCaptureUI,
            postCaptureUI: postCaptureUI,
            captureMs: elapsedMs,
            settleMs: settleMilliseconds,
            studioReleaseTag: manifest.source_release_tag,
            studioResolvedCommit: manifest.source_resolved_commit,
            entrypoints: manifest.entrypoints,
            chromeHidden: chromeSelectors,
            editorChromeResidual: "canvas 내부 margin/editor guide는 CSS로 제거하지 않고 reference에 잔류할 수 있음",
            pngPath: pngURL.path,
            pngBytes: png.data.count,
            pngWidth: png.width,
            pngHeight: png.height
        )
        try writeJSON(metadata, to: jsonURL)

        return StudioCaptureResult(
            fileName: inputURL.lastPathComponent,
            pngURL: pngURL,
            jsonURL: jsonURL,
            pngWidth: png.width,
            pngHeight: png.height,
            canvasCount: pageState.canvasCount,
            overlayCount: pageState.overlayCount,
            canvasSampleNonWhitePixels: pageState.canvasSampleNonWhitePixels,
            canvasSamplePixels: pageState.canvasSamplePixels,
            captureMode: captureMode,
            captureContaminated: captureContaminated,
            uiSuppressed: uiSuppressed,
            captureMs: elapsedMs
        )
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        recordNavigationEvent("didFinish")
        navigationResult = .success(())
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        recordNavigationEvent("didCommit")
        navigationDidCommit = true
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        recordNavigationEvent("didStartProvisional")
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        recordNavigationEvent("didFail:\(describeError(error))")
        navigationResult = .failure(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        recordNavigationEvent("didFailProvisional:\(describeError(error))")
        navigationResult = .failure(error)
    }

    private func recordNavigationEvent(_ event: String) {
        guard navigationEvents.count < 16 else {
            return
        }
        navigationEvents.append(event)
    }

    private var chromeSelectors: [String] {
        [
            "#menu-bar",
            "#icon-toolbar",
            "#style-bar",
            "#status-bar",
            "#ruler-corner",
            "#h-ruler",
            "#v-ruler"
        ]
    }

    private func createWebView(documentData: Data, revision: Int) throws {
        navigationResult = nil
        navigationEvents = []
        schemeStats = StudioSchemeRequestStats()
        let resourceHandler = StudioResourceSchemeHandler(resourceDir: resourceDir, stats: schemeStats)
        let documentHandler = StudioDocumentSchemeHandler(data: documentData, revision: revision, stats: schemeStats)
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.setURLSchemeHandler(resourceHandler, forURLScheme: StudioResourceSchemeHandler.scheme)
        configuration.setURLSchemeHandler(documentHandler, forURLScheme: StudioDocumentSchemeHandler.scheme)

        let frame = CGRect(origin: .zero, size: viewportSize)
        let webView = WKWebView(frame: frame, configuration: configuration)
        webView.wantsLayer = true
        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground")

        let window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = webView
        window.alphaValue = 1
        window.ignoresMouseEvents = true
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        window.orderFrontRegardless()

        self.resourceSchemeHandler = resourceHandler
        self.documentSchemeHandler = documentHandler
        self.webView = webView
        self.window = window
        navigationDidCommit = false
    }

    private func waitForPageReady(pageNumber: Int, timeout: TimeInterval) throws {
        let deadline = Date().addingTimeInterval(timeout)
        var lastState: PageState?
        var lastError: Error?
        var errorCount = 0
        while Date() < deadline {
            try throwIfNavigationFailed()
            guard navigationDidCommit else {
                RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
                continue
            }
            do {
                let state = try currentPageState(pageNumber: pageNumber)
                if state.ready {
                    return
                }
                lastState = state
            } catch {
                lastError = error
                errorCount += 1
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
        var details: [String] = []
        if let lastState {
            details.append("lastState={reason=\(lastState.reason), canvasCount=\(lastState.canvasCount), status=\(lastState.statusText)}")
        }
        if let lastError {
            details.append("lastError={\(lastError)}")
        }
        details.append("navigation=\(navigationStatusDescription)")
        details.append("events=[\(navigationEvents.joined(separator: ","))]")
        details.append("scheme={\(schemeStats.summary)}")
        if errorCount > 0 {
            details.append("errorCount=\(errorCount)")
        }
        if details.isEmpty {
            details.append("no page state")
        }
        throw PreviewHarnessPhaseError(
            phase: .readiness,
            detail: "rhwp-studio page \(pageNumber) readiness timed out: \(details.joined(separator: "; "))"
        )
    }

    private func waitForAutomationRuntime(timeout: TimeInterval) throws {
        let deadline = Date().addingTimeInterval(timeout)
        var lastJSON = ""
        var lastError: Error?
        var errorCount = 0
        var startedProbe = false
        while Date() < deadline {
            try throwIfNavigationFailed()
            guard case .success = navigationResult else {
                RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
                continue
            }
            if !startedProbe {
                _ = try evaluateJavaScript(
                    automationReadyStartScript(),
                    timeout: 5,
                    phase: .readiness
                )
                startedProbe = true
            }
            do {
                let value = try evaluateJavaScript(
                    "String(window.__alhangeulPreviewAutomationReadyJSON || '')",
                    timeout: 2,
                    phase: .readiness
                )
                if let json = value as? String, !json.isEmpty {
                    lastJSON = json
                    guard let data = json.data(using: .utf8),
                          let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    else {
                        throw PreviewHarnessPhaseError(
                            phase: .readiness,
                            detail: "unexpected automation ready result: \(json)"
                        )
                    }
                    if dictionary["ok"] as? Bool == true {
                        return
                    }
                    let errorMessage = dictionary["error"] as? String ?? "unknown automation ready error"
                    throw PreviewHarnessPhaseError(
                        phase: .readiness,
                        detail: "rhwp-studio automation runtime failed: \(errorMessage)"
                    )
                }
            } catch {
                lastError = error
                errorCount += 1
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }

        var details = [
            "navigation=\(navigationStatusDescription)",
            "events=[\(navigationEvents.joined(separator: ","))]",
            "scheme={\(schemeStats.summary)}",
            "lastAutomationJSON=\(lastJSON)"
        ]
        if let lastError {
            details.append("lastError={\(lastError)}")
        }
        if errorCount > 0 {
            details.append("errorCount=\(errorCount)")
        }
        throw PreviewHarnessPhaseError(
            phase: .readiness,
            detail: "rhwp-studio automation runtime timed out: \(details.joined(separator: "; "))"
        )
    }

    private func loadDocumentForAutomation(
        documentURL: URL,
        filename: String,
        timeout: TimeInterval
    ) throws -> AutomationLoadInfo {
        _ = try evaluateJavaScript(
            automationLoadStartScript(documentURL: documentURL, filename: filename),
            timeout: 5,
            phase: .readiness
        )

        let deadline = Date().addingTimeInterval(timeout)
        var lastJSON = ""
        var lastError: Error?
        while Date() < deadline {
            do {
                let value = try evaluateJavaScript(
                    "String(window.__alhangeulPreviewAutomationLoadJSON || '')",
                    timeout: 2,
                    phase: .readiness
                )
                if let json = value as? String, !json.isEmpty {
                    lastJSON = json
                    return try automationLoadInfo(from: json)
                }
            } catch {
                lastError = error
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }

        var details = [
            "filename=\(filename)",
            "documentURL=\(documentURL.absoluteString)",
            "navigation=\(navigationStatusDescription)",
            "events=[\(navigationEvents.joined(separator: ","))]",
            "scheme={\(schemeStats.summary)}"
        ]
        if !lastJSON.isEmpty {
            details.append("lastAutomationJSON=\(lastJSON)")
        }
        if let lastError {
            details.append("lastError={\(lastError)}")
        }
        throw PreviewHarnessPhaseError(
            phase: .readiness,
            detail: "rhwp-studio automation document load timed out: \(details.joined(separator: "; "))"
        )
    }

    private func automationLoadInfo(from json: String) throws -> AutomationLoadInfo {
        guard let data = json.data(using: .utf8),
              let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw PreviewHarnessPhaseError(
                phase: .readiness,
                detail: "unexpected automation load result: \(json)"
            )
        }
        if dictionary["ok"] as? Bool != true {
            let errorMessage = dictionary["error"] as? String ?? "unknown automation load error"
            throw PreviewHarnessPhaseError(
                phase: .readiness,
                detail: "rhwp-studio automation document load failed: \(errorMessage)"
            )
        }

        return AutomationLoadInfo(
            pageCount: intValue(dictionary["pageCount"]),
            fileName: dictionary["fileName"] as? String ?? "",
            sourceFormat: dictionary["sourceFormat"] as? String,
            strategy: dictionary["strategy"] as? String,
            localFontsSeeded: dictionary["localFontsSeeded"] as? Bool ?? false,
            statusText: dictionary["statusText"] as? String ?? ""
        )
    }

    private func throwIfNavigationFailed() throws {
        if case .failure(let error) = navigationResult {
            throw PreviewHarnessPhaseError(
                phase: .navigation,
                detail: "rhwp-studio navigation failed: \(describeError(error))"
            )
        }
    }

    private var navigationStatusDescription: String {
        switch navigationResult {
        case .none:
            return navigationDidCommit ? "committed" : "pending"
        case .success:
            return "finished"
        case .failure(let error):
            return "failed(\(describeError(error)))"
        }
    }

    private func alignPageAndHideChrome(pageNumber: Int) throws {
        _ = try evaluateJavaScript(alignAndHideChromeScript(pageNumber: pageNumber), timeout: 5, phase: .settle)
        _ = try evaluateJavaScript(settleFlagScript(), timeout: 5, phase: .settle)

        let deadline = Date().addingTimeInterval(1)
        while Date() < deadline {
            let settled = try evaluateJavaScript(
                "window.__alhangeulPreviewCaptureSettled === true",
                timeout: 2,
                phase: .settle
            ) as? Bool ?? false
            if settled {
                return
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
        throw PreviewHarnessPhaseError(
            phase: .settle,
            detail: "rhwp-studio capture settle timed out for page \(pageNumber)"
        )
    }

    private func currentPageState(pageNumber: Int) throws -> PageState {
        _ = try evaluateJavaScript(pageStateScript(pageNumber: pageNumber), timeout: 5, phase: .readiness)
        let value = try evaluateJavaScript(
            "String(window.__alhangeulPreviewPageStateJSON || '')",
            timeout: 5,
            phase: .readiness
        )
        guard let json = value as? String,
              let data = json.data(using: .utf8),
              let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw PreviewHarnessPhaseError(
                phase: .readiness,
                detail: "unexpected page state result: \(describeJavaScriptValue(value))"
            )
        }
        return PageState(dictionary: dictionary)
    }

    private func currentUIContaminationProbe() throws -> UIContaminationProbe {
        let value = try evaluateJavaScript(uiContaminationProbeScript(), timeout: 5, phase: .settle)
        guard let json = value as? String,
              let data = json.data(using: .utf8),
              let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw PreviewHarnessPhaseError(
                phase: .settle,
                detail: "unexpected UI contamination probe result: \(describeJavaScriptValue(value))"
            )
        }
        return UIContaminationProbe(dictionary: dictionary)
    }

    private func combinedContaminationText(_ first: UIContaminationProbe, _ second: UIContaminationProbe) -> [String] {
        var seen = Set<String>()
        var values: [String] = []
        for text in first.contaminationText + second.contaminationText {
            let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, !seen.contains(normalized) else {
                continue
            }
            seen.insert(normalized)
            values.append(normalized)
        }
        return values
    }

    private func evaluateJavaScript(
        _ script: String,
        timeout: TimeInterval,
        phase: PreviewHarnessPhase
    ) throws -> Any? {
        guard let webView else {
            throw PreviewHarnessPhaseError(phase: phase, detail: "WKWebView is not available")
        }

        var result: Result<Any?, Error>?
        webView.evaluateJavaScript(script) { value, error in
            if let error {
                result = .failure(error)
            } else {
                result = .success(value)
            }
        }

        let deadline = Date().addingTimeInterval(timeout)
        while result == nil && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }

        guard let result else {
            throw PreviewHarnessPhaseError(phase: phase, detail: "JavaScript evaluation timed out")
        }
        do {
            return try result.get()
        } catch {
            throw PreviewHarnessPhaseError(
                phase: phase,
                detail: "JavaScript evaluation failed: \(describeError(error))"
            )
        }
    }

    private func visibleSnapshotRect(_ rect: CGRect) throws -> CGRect {
        guard let webView else {
            throw PreviewHarnessError(description: "WKWebView is not available")
        }
        let integral = CGRect(
            x: floor(rect.origin.x),
            y: floor(rect.origin.y),
            width: ceil(rect.width),
            height: ceil(rect.height)
        )
        let visible = integral.intersection(webView.bounds)
        guard visible.width > 0, visible.height > 0 else {
            throw PreviewHarnessError(description: "snapshot rect is outside viewport: \(rect)")
        }
        guard abs(visible.width - integral.width) < 1, abs(visible.height - integral.height) < 1 else {
            throw PreviewHarnessError(
                description: "snapshot rect does not fit viewport: rect=\(integral), viewport=\(webView.bounds.size). Increase --viewport."
            )
        }
        return integral
    }

    private func takeSnapshot(rect: CGRect) throws -> NSImage {
        guard let webView else {
            throw PreviewHarnessError(description: "WKWebView is not available")
        }

        var result: Result<NSImage, Error>?
        let configuration = WKSnapshotConfiguration()
        configuration.rect = rect
        configuration.afterScreenUpdates = true
        webView.takeSnapshot(with: configuration) { image, error in
            if let error {
                result = .failure(error)
            } else if let image {
                result = .success(image)
            } else {
                result = .failure(PreviewHarnessError(description: "WKWebView snapshot returned nil image"))
            }
        }

        let deadline = Date().addingTimeInterval(10)
        while result == nil && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }

        guard let result else {
            throw PreviewHarnessError(description: "WKWebView snapshot timed out")
        }
        return try result.get()
    }

    private func captureSnapshotPNG(rect: CGRect) throws -> PNGOutput {
        let snapshotRect = try visibleSnapshotRect(rect)
        let image = try takeSnapshot(rect: snapshotRect)
        return try pngData(from: image)
    }

    private func exportCanvasPNG(pageNumber: Int) throws -> PNGOutput {
        let value = try evaluateJavaScript(canvasDataURLScript(pageNumber: pageNumber), timeout: 10, phase: .canvasExport)
        return try pngOutput(fromCanvasExportValue: value, phase: .canvasExport)
    }

    private func exportCompositePNG(pageNumber: Int) throws -> PNGOutput {
        let value = try evaluateJavaScript(compositeDataURLScript(pageNumber: pageNumber), timeout: 10, phase: .canvasExport)
        return try pngOutput(fromCanvasExportValue: value, phase: .canvasExport)
    }

    private func pngOutput(fromCanvasExportValue value: Any?, phase: PreviewHarnessPhase) throws -> PNGOutput {
        guard let json = value as? String,
              let data = json.data(using: .utf8),
              let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataURL = dictionary["dataURL"] as? String
        else {
            throw PreviewHarnessPhaseError(
                phase: phase,
                detail: "unexpected canvas export result: \(describeJavaScriptValue(value))"
            )
        }

        let marker = "base64,"
        guard let markerRange = dataURL.range(of: marker) else {
            throw PreviewHarnessError(description: "canvas export did not return base64 PNG data")
        }
        let base64 = String(dataURL[markerRange.upperBound...])
        guard let pngData = Data(base64Encoded: base64) else {
            throw PreviewHarnessError(description: "failed to decode canvas PNG data")
        }

        let width = intValue(dictionary["width"])
        let height = intValue(dictionary["height"])
        return PNGOutput(
            data: pngData,
            width: width,
            height: height,
            sampleNonWhitePixels: intValue(dictionary["canvasSampleNonWhitePixels"]),
            samplePixels: intValue(dictionary["canvasSamplePixels"])
        )
    }

    private func makeDocumentURL(revision: Int) throws -> URL {
        var documentComponents = URLComponents()
        documentComponents.scheme = StudioDocumentSchemeHandler.scheme
        documentComponents.host = StudioDocumentSchemeHandler.host
        documentComponents.queryItems = [
            URLQueryItem(name: "revision", value: String(revision))
        ]
        guard let documentURL = documentComponents.url else {
            throw PreviewHarnessError(description: "failed to build document URL")
        }
        return documentURL
    }

    private func makeAutomationAppURL() throws -> URL {
        var components = URLComponents()
        components.scheme = StudioResourceSchemeHandler.scheme
        components.host = StudioResourceSchemeHandler.host
        components.path = "/index.html"
        guard let url = components.url else {
            throw PreviewHarnessError(description: "failed to build rhwp-studio automation URL")
        }
        return url
    }

    private func makeLoadURL(filename: String, revision: Int) throws -> URL {
        let documentURL = try makeDocumentURL(revision: revision)

        var components = URLComponents()
        components.scheme = StudioResourceSchemeHandler.scheme
        components.host = StudioResourceSchemeHandler.host
        components.path = "/index.html"
        components.queryItems = [
            URLQueryItem(name: "url", value: documentURL.absoluteString),
            URLQueryItem(name: "filename", value: filename)
        ]
        guard let url = components.url else {
            throw PreviewHarnessError(description: "failed to build rhwp-studio load URL")
        }
        return url
    }

    private func automationReadyStartScript() -> String {
        """
        (() => {
          window.__alhangeulPreviewAutomationReadyJSON = '';
          const finish = (payload) => {
            window.__alhangeulPreviewAutomationReadyJSON = JSON.stringify(payload);
          };
          if (window.__wasm && window.__canvasView) {
            finish({ ok: true, strategy: 'direct-globals' });
            return true;
          }
          const requestId = `alhangeul-preview-ready-${Date.now()}-${Math.random().toString(16).slice(2)}`;
          const cleanup = () => {
            clearTimeout(timer);
            window.removeEventListener('message', onMessage);
          };
          const onMessage = (event) => {
            const data = event.data;
            if (!data || data.type !== 'rhwp-response' || data.id !== requestId) {
              return;
            }
            cleanup();
            if (data.error) {
              finish({ ok: false, strategy: 'rhwp-request', error: String(data.error) });
            } else {
              finish({ ok: true, strategy: 'rhwp-request' });
            }
          };
          const timer = setTimeout(() => {
            cleanup();
            finish({ ok: false, strategy: 'rhwp-request', error: 'ready request timed out' });
          }, 15000);
          window.addEventListener('message', onMessage);
          window.postMessage({ type: 'rhwp-request', id: requestId, method: 'ready' }, '*');
          return true;
        })();
        """
    }

    private func automationLoadStartScript(documentURL: URL, filename: String) -> String {
        let documentURLLiteral = javaScriptStringLiteral(documentURL.absoluteString)
        let filenameLiteral = javaScriptStringLiteral(filename)
        return """
        (() => {
          window.__alhangeulPreviewAutomationLoadJSON = '';
          const documentURL = \(documentURLLiteral);
          const filename = \(filenameLiteral);
          const finish = (payload) => {
            window.__alhangeulPreviewAutomationLoadJSON = JSON.stringify(payload);
          };
          const seedAutomationLocalFonts = () => {
            try {
              window.localStorage?.setItem('rhwp-local-fonts', JSON.stringify({
                version: 1,
                source: 'local-font-access',
                detectedAt: '1970-01-01T00:00:00.000Z',
                families: []
              }));
              return true;
            } catch (_) {
              return false;
            }
          };
          const postRhwpRequest = (method, params) => new Promise((resolve, reject) => {
            const requestId = `alhangeul-preview-load-${Date.now()}-${Math.random().toString(16).slice(2)}`;
            const cleanup = () => {
              clearTimeout(timer);
              window.removeEventListener('message', onMessage);
            };
            const onMessage = (event) => {
              const data = event.data;
              if (!data || data.type !== 'rhwp-response' || data.id !== requestId) {
                return;
              }
              cleanup();
              if (data.error) {
                reject(new Error(String(data.error)));
              } else {
                resolve(data.result);
              }
            };
            const timer = setTimeout(() => {
              cleanup();
              reject(new Error(`${method} request timed out`));
            }, 30000);
            window.addEventListener('message', onMessage);
            window.postMessage({ type: 'rhwp-request', id: requestId, method, params }, '*');
          });
          (async () => {
            try {
              const localFontsSeeded = seedAutomationLocalFonts();
              const response = await fetch(documentURL, { cache: 'no-store' });
              if (!response.ok) {
                throw new Error(`document fetch failed: HTTP ${response.status}`);
              }
              const buffer = await response.arrayBuffer();
              const bytes = new Uint8Array(buffer);
              let strategy = 'direct-globals';
              let pageCount = 0;
              let fileName = filename;
              let sourceFormat = null;
              if (window.__wasm && window.__canvasView) {
                const docInfo = window.__wasm.loadDocument(bytes, filename);
                if (!docInfo) {
                  throw new Error('window.__wasm.loadDocument returned null');
                }
                if (typeof window.__canvasView.loadDocument !== 'function') {
                  throw new Error('window.__canvasView.loadDocument is not available');
                }
                window.__canvasView.loadDocument();
                pageCount = Number(docInfo.pageCount ?? window.__wasm.pageCount ?? 0) || 0;
                fileName = window.__wasm.fileName || filename;
                sourceFormat = typeof window.__wasm.getSourceFormat === 'function'
                  ? window.__wasm.getSourceFormat()
                  : null;
              } else {
                strategy = 'rhwp-request';
                const result = await postRhwpRequest('loadFile', {
                  data: bytes,
                  fileName: filename,
                  skipUnsavedGuard: true
                });
                pageCount = Number(result?.pageCount || 0) || 0;
              }
              const statusText = `${filename} — ${pageCount}페이지 (automation)`;
              const statusElement = document.querySelector('#sb-message');
              if (statusElement) {
                statusElement.textContent = statusText;
              }
              finish({
                ok: true,
                pageCount,
                fileName,
                sourceFormat,
                strategy,
                localFontsSeeded,
                statusText
              });
            } catch (error) {
              finish({
                ok: false,
                error: error && error.message ? error.message : String(error)
              });
            }
          })();
          return true;
        })();
        """
    }

    private func pageStateScript(pageNumber: Int) -> String {
        """
        (() => {
          const writeState = (state) => {
            window.__alhangeulPreviewPageStateJSON = JSON.stringify(state);
            return true;
          };
          try {
            const pageNumber = \(pageNumber);
            const content = document.querySelector('#scroll-content');
            const canvases = content
              ? Array.from(content.querySelectorAll('canvas')).filter((canvas) => {
                  const rect = canvas.getBoundingClientRect();
                  return rect.width > 0 && rect.height > 0 && canvas.width > 0 && canvas.height > 0;
                })
              : [];
            const target = canvases[pageNumber - 1] || null;
            const statusText = (document.querySelector('#sb-message')?.textContent || '').trim();
            const rectObject = (rect) => ({
              x: Number(rect.left) || 0,
              y: Number(rect.top) || 0,
              width: Number(rect.width) || 0,
              height: Number(rect.height) || 0
            });
            const viewportSize = {
              width: Number(window.innerWidth) || 0,
              height: Number(window.innerHeight) || 0
            };
            if (!content) {
              return writeState({
                ready: false,
                reason: 'missing #scroll-content',
                selector: '#scroll-content canvas',
                statusText,
                canvasCount: 0,
                overlayCount: 0,
                usedOverlayUnion: false,
                canvasSampleNonWhitePixels: 0,
                canvasSamplePixels: 0,
                devicePixelRatio: Number(window.devicePixelRatio) || 1,
                viewportSize
              });
            }
            if (!target) {
              return writeState({
                ready: false,
                reason: `page canvas not found for page ${pageNumber}`,
                selector: '#scroll-content canvas',
                statusText,
                canvasCount: canvases.length,
                overlayCount: 0,
                usedOverlayUnion: false,
                canvasSampleNonWhitePixels: 0,
                canvasSamplePixels: 0,
                devicePixelRatio: Number(window.devicePixelRatio) || 1,
                viewportSize
              });
            }

            const targetRect = target.getBoundingClientRect();
            let unionLeft = targetRect.left;
            let unionTop = targetRect.top;
            let unionRight = targetRect.right;
            let unionBottom = targetRect.bottom;
            let overlayCount = 0;

            for (const element of Array.from(content.querySelectorAll('*'))) {
              if (element === target || element.tagName.toLowerCase() === 'canvas') {
                continue;
              }
              const style = window.getComputedStyle(element);
              if (style.display === 'none' || style.visibility === 'hidden' || Number(style.opacity) === 0) {
                continue;
              }
              const rect = element.getBoundingClientRect();
              if (rect.width <= 0 || rect.height <= 0) {
                continue;
              }
              const intersectsVertical = rect.bottom >= targetRect.top - 1 && rect.top <= targetRect.bottom + 1;
              const intersectsHorizontal = rect.right >= targetRect.left - 1 && rect.left <= targetRect.right + 1;
              if (!intersectsVertical || !intersectsHorizontal) {
                continue;
              }
              overlayCount += 1;
              unionLeft = Math.min(unionLeft, rect.left);
              unionTop = Math.min(unionTop, rect.top);
              unionRight = Math.max(unionRight, rect.right);
              unionBottom = Math.max(unionBottom, rect.bottom);
            }

            const snapshotRect = {
              x: Number(unionLeft) || 0,
              y: Number(unionTop) || 0,
              width: Number(unionRight - unionLeft) || 0,
              height: Number(unionBottom - unionTop) || 0
            };
            let canvasSampleNonWhitePixels = 0;
            let canvasSamplePixels = 0;
            try {
              const context = target.getContext('2d', { willReadFrequently: true });
              const backingWidth = target.width;
              const backingHeight = target.height;
              const step = Math.max(1, Math.floor(Math.min(backingWidth, backingHeight) / 160));
              const imageData = context.getImageData(0, 0, backingWidth, backingHeight).data;
              for (let y = 0; y < backingHeight; y += step) {
                for (let x = 0; x < backingWidth; x += step) {
                  const index = (y * backingWidth + x) * 4;
                  const r = imageData[index];
                  const g = imageData[index + 1];
                  const b = imageData[index + 2];
                  const a = imageData[index + 3];
                  canvasSamplePixels += 1;
                  if (a > 0 && (r < 245 || g < 245 || b < 245)) {
                    canvasSampleNonWhitePixels += 1;
                  }
                }
              }
            } catch (_) {
              canvasSampleNonWhitePixels = -1;
              canvasSamplePixels = -1;
            }

            return writeState({
              ready: true,
              reason: 'ready',
              selector: '#scroll-content canvas',
              statusText,
              canvasCount: canvases.length,
              overlayCount,
              usedOverlayUnion: overlayCount > 0,
              canvasSampleNonWhitePixels,
              canvasSamplePixels,
              devicePixelRatio: Number(window.devicePixelRatio) || 1,
              viewportSize,
              canvasRect: rectObject(targetRect),
              snapshotRect
            });
          } catch (error) {
            return writeState({
              ready: false,
              reason: `page state probe error: ${error && error.message ? error.message : String(error)}`,
              selector: '#scroll-content canvas',
              statusText: '',
              canvasCount: 0,
              overlayCount: 0,
              usedOverlayUnion: false,
              canvasSampleNonWhitePixels: -1,
              canvasSamplePixels: -1,
              devicePixelRatio: Number(window.devicePixelRatio) || 1,
              viewportSize: { width: Number(window.innerWidth) || 0, height: Number(window.innerHeight) || 0 }
            });
          }
        })()
        """
    }

    private func uiContaminationProbeScript() -> String {
        """
        JSON.stringify((() => {
          const isVisible = (element) => {
            if (!element || !(element instanceof Element)) {
              return false;
            }
            const style = window.getComputedStyle(element);
            if (style.display === 'none' || style.visibility === 'hidden' || Number(style.opacity) === 0) {
              return false;
            }
            const rect = element.getBoundingClientRect();
            return rect.width > 0 && rect.height > 0;
          };
          const uniqueElements = (selectors) => {
            const seen = new Set();
            const elements = [];
            for (const selector of selectors) {
              for (const element of Array.from(document.querySelectorAll(selector))) {
                if (seen.has(element)) {
                  continue;
                }
                seen.add(element);
                if (isVisible(element)) {
                  elements.push(element);
                }
              }
            }
            return elements;
          };
          const outermostElements = (elements) => elements.filter((element) =>
            !elements.some((other) => other !== element && other.contains(element))
          );
          const textOf = (element) => (element.textContent || '').replace(/\\s+/g, ' ').trim();
          const snippet = (text) => text.length > 160 ? `${text.slice(0, 157)}...` : text;
          const modalElements = outermostElements(uniqueElements([
            'dialog',
            '[role="dialog"]',
            '[aria-modal="true"]',
            '.modal-overlay',
            '.dialog-wrap',
            '.modal',
            '[class*="modal"]',
            '[id*="modal"]'
          ]));
          const toastElements = outermostElements(uniqueElements([
            '#rhwp-toast-container > *',
            '#rhwp-toast-container [role="status"]',
            '.toast',
            '.snackbar',
            '.notification',
            '[class*="toast"]',
            '[class*="snackbar"]',
            '[class*="notification"]'
          ]));
          const statusElements = uniqueElements(['#sb-message', '[role="alert"]']);
          const candidateElements = [...modalElements, ...toastElements, ...statusElements];
          const localFontPattern = /로컬\\s*(글꼴|폰트)|글꼴\\s*감지|폰트\\s*감지|Local\\s*Font/i;
          const contaminationTexts = [];
          for (const element of candidateElements) {
            const text = textOf(element);
            if (!text) {
              continue;
            }
            if (modalElements.includes(element) || toastElements.includes(element) || localFontPattern.test(text)) {
              contaminationTexts.push(snippet(text));
            }
          }
          const dedupedTexts = [];
          const seenTexts = new Set();
          for (const text of contaminationTexts) {
            if (!seenTexts.has(text)) {
              seenTexts.add(text);
              dedupedTexts.push(text);
            }
          }
          return {
            modalCount: modalElements.length,
            toastCount: toastElements.length,
            localFontUIVisible: candidateElements.some((element) => localFontPattern.test(textOf(element))),
            contaminationText: dedupedTexts.slice(0, 12)
          };
        })())
        """
    }

    private func canvasDataURLScript(pageNumber: Int) -> String {
        """
        JSON.stringify((() => {
          const pageNumber = \(pageNumber);
          const content = document.querySelector('#scroll-content');
          const canvases = content
            ? Array.from(content.querySelectorAll('canvas')).filter((canvas) => {
                const rect = canvas.getBoundingClientRect();
                return rect.width > 0 && rect.height > 0 && canvas.width > 0 && canvas.height > 0;
              })
            : [];
          const target = canvases[pageNumber - 1] || null;
          if (!target) {
            throw new Error(`page canvas not found for page ${pageNumber}`);
          }
          let canvasSampleNonWhitePixels = 0;
          let canvasSamplePixels = 0;
          const context = target.getContext('2d', { willReadFrequently: true });
          const backingWidth = target.width;
          const backingHeight = target.height;
          const step = Math.max(1, Math.floor(Math.min(backingWidth, backingHeight) / 160));
          const imageData = context.getImageData(0, 0, backingWidth, backingHeight).data;
          for (let y = 0; y < backingHeight; y += step) {
            for (let x = 0; x < backingWidth; x += step) {
              const index = (y * backingWidth + x) * 4;
              const r = imageData[index];
              const g = imageData[index + 1];
              const b = imageData[index + 2];
              const a = imageData[index + 3];
              canvasSamplePixels += 1;
              if (a > 0 && (r < 245 || g < 245 || b < 245)) {
                canvasSampleNonWhitePixels += 1;
              }
            }
          }
          return {
            width: target.width,
            height: target.height,
            canvasSampleNonWhitePixels,
            canvasSamplePixels,
            dataURL: (() => {
              const exportCanvas = document.createElement('canvas');
              exportCanvas.width = target.width;
              exportCanvas.height = target.height;
              const exportContext = exportCanvas.getContext('2d');
              exportContext.fillStyle = '#ffffff';
              exportContext.fillRect(0, 0, exportCanvas.width, exportCanvas.height);
              exportContext.drawImage(target, 0, 0);
              return exportCanvas.toDataURL('image/png');
            })()
          };
        })());
        """
    }

    // WKWebView snapshots can omit the canvas backing store in this harness, so
    // overlay-positive references are composited from same-origin DOM drawables.
    private func compositeDataURLScript(pageNumber: Int) -> String {
        """
        JSON.stringify((() => {
          const pageNumber = \(pageNumber);
          const content = document.querySelector('#scroll-content');
          const canvases = content
            ? Array.from(content.querySelectorAll('canvas')).filter((canvas) => {
                const rect = canvas.getBoundingClientRect();
                return rect.width > 0 && rect.height > 0 && canvas.width > 0 && canvas.height > 0;
              })
            : [];
          const target = canvases[pageNumber - 1] || null;
          if (!target) {
            throw new Error(`page canvas not found for page ${pageNumber}`);
          }

          const targetRect = target.getBoundingClientRect();
          let unionLeft = targetRect.left;
          let unionTop = targetRect.top;
          let unionRight = targetRect.right;
          let unionBottom = targetRect.bottom;
          const drawables = [];
          let order = 0;
          const addDrawable = (element, role) => {
            const tag = element.tagName.toLowerCase();
            if (tag !== 'canvas' && tag !== 'img') {
              return;
            }
            const style = window.getComputedStyle(element);
            if (style.display === 'none' || style.visibility === 'hidden' || Number(style.opacity) === 0) {
              return;
            }
            if (tag === 'img' && (!element.complete || element.naturalWidth <= 0 || element.naturalHeight <= 0)) {
              return;
            }
            const rect = element.getBoundingClientRect();
            if (rect.width <= 0 || rect.height <= 0) {
              return;
            }
            const intersectsVertical = rect.bottom >= targetRect.top - 1 && rect.top <= targetRect.bottom + 1;
            const intersectsHorizontal = rect.right >= targetRect.left - 1 && rect.left <= targetRect.right + 1;
            if (!intersectsVertical || !intersectsHorizontal) {
              return;
            }
            unionLeft = Math.min(unionLeft, rect.left);
            unionTop = Math.min(unionTop, rect.top);
            unionRight = Math.max(unionRight, rect.right);
            unionBottom = Math.max(unionBottom, rect.bottom);
            const z = Number.parseFloat(style.zIndex);
            const opacity = Number.parseFloat(style.opacity);
            drawables.push({
              element,
              role,
              tag,
              order: order++,
              zIndex: Number.isFinite(z) ? z : 0,
              opacity: Number.isFinite(opacity) ? opacity : 1,
              rect
            });
          };

          addDrawable(target, 'pageCanvas');
          for (const element of Array.from(content.querySelectorAll('*'))) {
            if (element === target) {
              continue;
            }
            addDrawable(element, 'overlay');
          }
          drawables.sort((a, b) => (a.zIndex - b.zIndex) || (a.order - b.order));

          const dpr = Number(window.devicePixelRatio) || 1;
          const cssWidth = Math.max(1, unionRight - unionLeft);
          const cssHeight = Math.max(1, unionBottom - unionTop);
          const exportCanvas = document.createElement('canvas');
          exportCanvas.width = Math.max(1, Math.round(cssWidth * dpr));
          exportCanvas.height = Math.max(1, Math.round(cssHeight * dpr));
          const exportContext = exportCanvas.getContext('2d');
          exportContext.fillStyle = '#ffffff';
          exportContext.fillRect(0, 0, exportCanvas.width, exportCanvas.height);
          exportContext.setTransform(dpr, 0, 0, dpr, -unionLeft * dpr, -unionTop * dpr);

          for (const item of drawables) {
            exportContext.save();
            exportContext.globalAlpha = Math.max(0, Math.min(1, item.opacity));
            exportContext.drawImage(
              item.element,
              item.rect.left,
              item.rect.top,
              item.rect.width,
              item.rect.height
            );
            exportContext.restore();
          }

          exportContext.setTransform(1, 0, 0, 1, 0, 0);
          const imageData = exportContext.getImageData(0, 0, exportCanvas.width, exportCanvas.height).data;
          const step = Math.max(1, Math.floor(Math.min(exportCanvas.width, exportCanvas.height) / 160));
          let canvasSampleNonWhitePixels = 0;
          let canvasSamplePixels = 0;
          for (let y = 0; y < exportCanvas.height; y += step) {
            for (let x = 0; x < exportCanvas.width; x += step) {
              const index = (y * exportCanvas.width + x) * 4;
              const r = imageData[index];
              const g = imageData[index + 1];
              const b = imageData[index + 2];
              const a = imageData[index + 3];
              canvasSamplePixels += 1;
              if (a > 0 && (r < 245 || g < 245 || b < 245)) {
                canvasSampleNonWhitePixels += 1;
              }
            }
          }

          return {
            width: exportCanvas.width,
            height: exportCanvas.height,
            canvasSampleNonWhitePixels,
            canvasSamplePixels,
            dataURL: exportCanvas.toDataURL('image/png')
          };
        })());
        """
    }

    private func alignAndHideChromeScript(pageNumber: Int) -> String {
        let css = """
        #menu-bar,
        #icon-toolbar,
        #style-bar,
        #status-bar,
        #ruler-corner,
        #h-ruler,
        #v-ruler {
          display: none !important;
        }
        """

        return """
        (() => {
          const css = \(javaScriptStringLiteral(css));
          let style = document.getElementById('__alhangeul_preview_capture_chrome_hide');
          if (!style) {
            style = document.createElement('style');
            style.id = '__alhangeul_preview_capture_chrome_hide';
            document.head.appendChild(style);
          }
          style.textContent = css;

          const pageNumber = \(pageNumber);
          const content = document.querySelector('#scroll-content');
          const scrollContainer = document.querySelector('#scroll-container');
          const canvases = content
            ? Array.from(content.querySelectorAll('canvas')).filter((canvas) => {
                const rect = canvas.getBoundingClientRect();
                return rect.width > 0 && rect.height > 0 && canvas.width > 0 && canvas.height > 0;
              })
            : [];
          const target = canvases[pageNumber - 1] || null;
          if (target && scrollContainer) {
            const targetRect = target.getBoundingClientRect();
            const containerRect = scrollContainer.getBoundingClientRect();
            scrollContainer.scrollTop += targetRect.top - containerRect.top - 24;
            scrollContainer.scrollLeft = 0;
          }
          return true;
        })();
        """
    }

    private func settleFlagScript() -> String {
        """
        (() => {
          window.__alhangeulPreviewCaptureSettled = false;
          const markSettled = () => {
            window.__alhangeulPreviewCaptureSettled = true;
          };
          if (typeof requestAnimationFrame === 'function') {
            requestAnimationFrame(() => {
              requestAnimationFrame(markSettled);
            });
            setTimeout(markSettled, 250);
          } else {
            setTimeout(markSettled, 0);
          }
          return true;
        })();
        """
    }
}

enum NativePreviewRenderer {
    static func render(
        inputURL: URL,
        outputDir: URL,
        pageNumber: Int,
        policy: HwpPageRenderPolicy
    ) throws -> NativeRenderResult {
        let data = try Data(contentsOf: inputURL)
        let document = try RhwpDocument(data: data, filename: inputURL.lastPathComponent)
        guard document.pageCount > 0 else {
            throw PreviewHarnessError(description: "page count is zero")
        }
        let pageIndex = pageNumber - 1
        guard pageIndex >= 0, pageIndex < document.pageCount else {
            throw PreviewHarnessError(description: "page \(pageNumber) is out of range: pageCount=\(document.pageCount)")
        }

        let baseName = outputStem(for: inputURL)
        let outputBase = "\(baseName)-page\(pageNumber)"
        let pngURL = outputDir.appendingPathComponent("\(outputBase)-native.png", isDirectory: false)
        let jsonURL = outputDir.appendingPathComponent("\(outputBase)-native.json", isDirectory: false)

        let page = try HwpPageImageRenderer.renderPage(
            document: document,
            pageIndex: pageIndex,
            policy: policy
        )
        let pngData = try HwpPageImageRenderer.encodePNG(page.image)
        try pngData.write(to: pngURL, options: .atomic)
        let sample = sampleNonWhitePixels(cgImage: page.image)

        let diagnostics = page.diagnostics
        let metadata = NativeRenderMetadata(
            sourcePath: inputURL.path,
            filename: inputURL.lastPathComponent,
            page: pageNumber,
            pageCount: document.pageCount,
            policy: renderPolicyName(diagnostics.policy),
            backendUsed: backendName(diagnostics.backendUsed),
            fallbackReason: diagnostics.fallbackReason.map(fallbackReasonName),
            pageSize: SizeMetadata(width: diagnostics.pageSize.width, height: diagnostics.pageSize.height),
            pixelSize: SizeMetadata(width: diagnostics.pixelSize.width, height: diagnostics.pixelSize.height),
            pngPath: pngURL.path,
            pngBytes: pngData.count,
            nonWhiteSamplePixels: sample.nonWhite,
            sampledPixels: sample.total,
            renderMs: diagnostics.durationMs.totalMs,
            skiaRenderMs: diagnostics.durationMs.skiaRenderMs,
            pngDecodeMs: diagnostics.durationMs.pngDecodeMs,
            coreGraphicsRenderMs: diagnostics.durationMs.coreGraphicsRenderMs
        )
        try writeJSON(metadata, to: jsonURL)

        return NativeRenderResult(
            pngURL: pngURL,
            jsonURL: jsonURL,
            image: page.image,
            pngBytes: pngData.count,
            pageCount: document.pageCount,
            policy: metadata.policy,
            backendUsed: metadata.backendUsed,
            fallbackReason: metadata.fallbackReason,
            renderMs: metadata.renderMs,
            pixelWidth: page.image.width,
            pixelHeight: page.image.height,
            nonWhiteSamplePixels: sample.nonWhite,
            sampledPixels: sample.total
        )
    }
}

enum VisualDiffEngine {
    static func compare(
        studioPNG: URL,
        nativeImage: CGImage,
        outputDir: URL,
        baseName: String,
        pageNumber: Int
    ) throws -> VisualDiffResult {
        let studio = try loadRGBAImage(studioPNG)
        let native = try drawCGImageToRGBA(nativeImage, width: studio.width, height: studio.height)
        let (diff, diffImage) = makeDiffImage(reference: studio, candidate: native)
        let diffURL = outputDir.appendingPathComponent("\(baseName)-page\(pageNumber)-diff.png", isDirectory: false)
        try writePNG(diffImage, to: diffURL)
        return VisualDiffResult(
            diffURL: diffURL,
            changedPixels: diff.changedPixels,
            totalPixels: diff.totalPixels,
            changedPercent: diff.changedPercent,
            meanRGBDelta: diff.meanRGBDelta,
            maxRGBDelta: diff.maxRGBDelta,
            bounds: diff.bounds,
            compareWidth: studio.width,
            compareHeight: studio.height
        )
    }

    private static func loadRGBAImage(_ url: URL) throws -> RGBAImage {
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw PreviewHarnessError(description: "failed to load image: \(url.path)")
        }
        return try drawCGImageToRGBA(image, width: image.width, height: image.height)
    }

    private static func drawCGImageToRGBA(_ image: CGImage, width: Int, height: Int) throws -> RGBAImage {
        var rgba = blankRGBA(width: width, height: height)
        try rgba.withBitmapContext { context in
            context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return rgba
    }

    private static func blankRGBA(width: Int, height: Int) -> RGBAImage {
        let bytesPerRow = width * 4
        return RGBAImage(width: width, height: height, pixels: [UInt8](repeating: 255, count: height * bytesPerRow))
    }

    private static func makeDiffImage(reference: RGBAImage, candidate: RGBAImage) -> (DiffResult, RGBAImage) {
        precondition(reference.width == candidate.width && reference.height == candidate.height)

        var diffImage = blankRGBA(width: reference.width, height: reference.height)
        var changedPixels = 0
        var totalDelta = 0
        var maxDelta = 0
        var minX = reference.width
        var minY = reference.height
        var maxX = -1
        var maxY = -1

        for y in 0..<reference.height {
            for x in 0..<reference.width {
                let index = (y * reference.width + x) * 4
                let redDelta = abs(Int(reference.pixels[index]) - Int(candidate.pixels[index]))
                let greenDelta = abs(Int(reference.pixels[index + 1]) - Int(candidate.pixels[index + 1]))
                let blueDelta = abs(Int(reference.pixels[index + 2]) - Int(candidate.pixels[index + 2]))
                let pixelDelta = max(redDelta, greenDelta, blueDelta)
                totalDelta += redDelta + greenDelta + blueDelta
                maxDelta = max(maxDelta, pixelDelta)

                if pixelDelta > 12 {
                    changedPixels += 1
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                    diffImage.pixels[index] = 255
                    diffImage.pixels[index + 1] = UInt8(max(0, 255 - pixelDelta))
                    diffImage.pixels[index + 2] = UInt8(max(0, 255 - pixelDelta))
                    diffImage.pixels[index + 3] = 255
                } else {
                    let gray = UInt8(240)
                    diffImage.pixels[index] = gray
                    diffImage.pixels[index + 1] = gray
                    diffImage.pixels[index + 2] = gray
                    diffImage.pixels[index + 3] = 255
                }
            }
        }

        let totalPixels = reference.width * reference.height
        let bounds: CGRect?
        if maxX >= 0 {
            bounds = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        } else {
            bounds = nil
        }
        return (
            DiffResult(
                changedPixels: changedPixels,
                totalPixels: totalPixels,
                changedPercent: totalPixels == 0 ? 0 : Double(changedPixels) * 100.0 / Double(totalPixels),
                meanRGBDelta: totalPixels == 0 ? 0 : Double(totalDelta) / Double(totalPixels * 3),
                maxRGBDelta: maxDelta,
                bounds: bounds
            ),
            diffImage
        )
    }

    private static func writePNG(_ image: RGBAImage, to url: URL) throws {
        var image = image
        let cgImage = try image.makeCGImage()
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw PreviewHarnessError(description: "failed to create PNG destination: \(url.path)")
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw PreviewHarnessError(description: "failed to write PNG: \(url.path)")
        }
    }
}

@main
struct PreviewVisualDiffHarness {
    static func main() throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        NSApplication.shared.finishLaunching()

        let options = try parseOptions(Array(CommandLine.arguments.dropFirst()))
        let studioDir = options.outputDir.appendingPathComponent("studio", isDirectory: true)
        let nativeDir = options.outputDir.appendingPathComponent("native", isDirectory: true)
        let diffDir = options.outputDir.appendingPathComponent("diff", isDirectory: true)
        try FileManager.default.createDirectory(at: studioDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nativeDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: diffDir, withIntermediateDirectories: true)

        let manifest = try StudioManifest.load(from: options.resourceDir)
        let renderer = StudioReferenceRenderer(
            resourceDir: options.resourceDir,
            viewportSize: options.viewportSize,
            settleMilliseconds: options.settleMilliseconds
        )

        var failed = false
        var summaryLines: [String] = []
        summaryLines.append("# Preview Visual Diff Harness")
        summaryLines.append("")
        summaryLines.append("Page: \(options.pageNumber)")
        summaryLines.append("NativePolicy: \(renderPolicyName(options.policy))")
        summaryLines.append("ResourceDir: \(options.resourceDir.path)")
        summaryLines.append("StudioReleaseTag: \(manifest.source_release_tag)")
        summaryLines.append("StudioResolvedCommit: \(manifest.source_resolved_commit)")
        summaryLines.append("Viewport: \(Int(options.viewportSize.width))x\(Int(options.viewportSize.height))")
        summaryLines.append("SettleMs: \(options.settleMilliseconds)")
        summaryLines.append("DiffPixelThreshold: 12")
        summaryLines.append("")
        summaryLines.append("| File | Status | Phase | StudioSize | NativeSize | CompareSize | ChangedPixels | ChangedPercent | MeanRGBDelta | MaxRGBDelta | DiffBounds | StudioCapture | NativeBackend | NativeMs | StudioPNG | NativePNG | DiffPNG |")
        summaryLines.append("|------|--------|-------|------------|------------|-------------|---------------|----------------|--------------|-------------|------------|---------------|---------------|----------|-----------|-----------|---------|")

        for inputURL in options.inputURLs {
            do {
                let result = try renderer.capture(
                    inputURL: inputURL,
                    outputDir: studioDir,
                    pageNumber: options.pageNumber,
                    manifest: manifest
                )
                let native = try NativePreviewRenderer.render(
                    inputURL: inputURL,
                    outputDir: nativeDir,
                    pageNumber: options.pageNumber,
                    policy: options.policy
                )
                let baseName = outputStem(for: inputURL)
                let diff = try VisualDiffEngine.compare(
                    studioPNG: result.pngURL,
                    nativeImage: native.image,
                    outputDir: diffDir,
                    baseName: baseName,
                    pageNumber: options.pageNumber
                )
                summaryLines.append([
                    markdownCell(result.fileName),
                    "OK",
                    "-",
                    "\(result.pngWidth)x\(result.pngHeight)",
                    "\(native.pixelWidth)x\(native.pixelHeight)",
                    "\(diff.compareWidth)x\(diff.compareHeight)",
                    "\(diff.changedPixels)/\(diff.totalPixels)",
                    formatPercent(diff.changedPercent),
                    formatDouble(diff.meanRGBDelta),
                    "\(diff.maxRGBDelta)",
                    boundsString(diff.bounds),
                    studioCaptureSummary(result),
                    native.backendUsed + fallbackSuffix(native.fallbackReason),
                    formatMilliseconds(native.renderMs),
                    markdownCell(result.pngURL.path),
                    markdownCell(native.pngURL.path),
                    markdownCell(diff.diffURL.path)
                ].joined(separator: " | ").wrappedTableRow)
                print(
                    "OK \(result.fileName): studioPNG=\(result.pngURL.path) nativePNG=\(native.pngURL.path) diffPNG=\(diff.diffURL.path)"
                )
            } catch {
                failed = true
                let failureCells = [
                    markdownCell(inputURL.lastPathComponent),
                    "FAIL: \(String(describing: error).replacingOccurrences(of: "|", with: "/"))",
                    failurePhase(for: error).rawValue
                ] + Array(repeating: "-", count: 14)
                summaryLines.append(failureCells.joined(separator: " | ").wrappedTableRow)
                print("FAIL \(inputURL.path): \(error)", to: &standardError)
            }
        }

        try summaryLines.joined(separator: "\n").write(
            to: options.outputDir.appendingPathComponent("summary.md", isDirectory: false),
            atomically: true,
            encoding: .utf8
        )

        if failed {
            Darwin.exit(1)
        }
    }

    private static func parseOptions(_ args: [String]) throws -> HarnessOptions {
        guard args.count >= 2 else {
            throw PreviewHarnessError(
                description: "usage: preview_visual_diff_harness <output-dir> [--page N] [--policy coreGraphicsOnly|skiaOptIn] [--viewport WIDTHxHEIGHT] [--settle-ms N] [--resource-dir DIR] <hwp-or-hwpx> [...]"
            )
        }

        var remaining = args
        let outputDir = absoluteURL(remaining.removeFirst(), isDirectory: true)
        var resourceDir = absoluteURL("Sources/HostApp/Resources/rhwp-studio", isDirectory: true)
        var pageNumber = 1
        var policy = HwpPageRenderPolicy.coreGraphicsOnly
        var viewportSize = CGSize(width: 1400, height: 1800)
        var settleMilliseconds = 120

        while let first = remaining.first, first.hasPrefix("--") {
            switch first {
            case "--page":
                remaining.removeFirst()
                guard let value = remaining.first, let parsed = Int(value), parsed > 0 else {
                    throw PreviewHarnessError(description: "--page requires a positive integer")
                }
                pageNumber = parsed
                remaining.removeFirst()
            case "--resource-dir":
                remaining.removeFirst()
                guard let value = remaining.first else {
                    throw PreviewHarnessError(description: "--resource-dir requires a directory")
                }
                resourceDir = absoluteURL(value, isDirectory: true)
                remaining.removeFirst()
            case "--policy":
                remaining.removeFirst()
                guard let value = remaining.first else {
                    throw PreviewHarnessError(description: "--policy requires coreGraphicsOnly or skiaOptIn")
                }
                policy = try parsePolicy(value)
                remaining.removeFirst()
            case "--viewport":
                remaining.removeFirst()
                guard let value = remaining.first else {
                    throw PreviewHarnessError(description: "--viewport requires WIDTHxHEIGHT")
                }
                viewportSize = try parseViewport(value)
                remaining.removeFirst()
            case "--settle-ms":
                remaining.removeFirst()
                guard let value = remaining.first, let parsed = Int(value), parsed >= 0 else {
                    throw PreviewHarnessError(description: "--settle-ms requires a non-negative integer")
                }
                settleMilliseconds = parsed
                remaining.removeFirst()
            default:
                throw PreviewHarnessError(description: "unknown option: \(first)")
            }
        }

        guard !remaining.isEmpty else {
            throw PreviewHarnessError(description: "missing input document")
        }

        return HarnessOptions(
            outputDir: outputDir,
            resourceDir: resourceDir,
            pageNumber: pageNumber,
            policy: policy,
            viewportSize: viewportSize,
            settleMilliseconds: settleMilliseconds,
            inputURLs: remaining.map { absoluteURL($0) }
        )
    }

    private static func parsePolicy(_ value: String) throws -> HwpPageRenderPolicy {
        switch value {
        case "coreGraphicsOnly":
            return .coreGraphicsOnly
        case "skiaOptIn":
            return .skiaOptIn
        default:
            throw PreviewHarnessError(description: "--policy must be coreGraphicsOnly or skiaOptIn")
        }
    }

    private static func parseViewport(_ value: String) throws -> CGSize {
        let parts = value.split(separator: "x", maxSplits: 1).map(String.init)
        guard parts.count == 2,
              let width = Double(parts[0]),
              let height = Double(parts[1]),
              width > 0,
              height > 0
        else {
            throw PreviewHarnessError(description: "--viewport must use WIDTHxHEIGHT with positive numbers")
        }
        return CGSize(width: width, height: height)
    }
}

private func absoluteURL(_ path: String, isDirectory: Bool = false) -> URL {
    let url: URL
    if path.hasPrefix("/") {
        url = URL(fileURLWithPath: path, isDirectory: isDirectory)
    } else {
        url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            .appendingPathComponent(path, isDirectory: isDirectory)
    }
    return url.standardizedFileURL
}

private func outputStem(for url: URL) -> String {
    url.lastPathComponent
}

private func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(value)
    try data.write(to: url, options: .atomic)
}

private func pngData(from image: NSImage) throws -> PNGOutput {
    var proposedRect = CGRect(origin: .zero, size: image.size)
    guard let cgImage = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
        throw PreviewHarnessError(description: "failed to create CGImage from snapshot")
    }
    let representation = NSBitmapImageRep(cgImage: cgImage)
    guard let data = representation.representation(using: .png, properties: [:]) else {
        throw PreviewHarnessError(description: "failed to encode snapshot PNG")
    }
    let sample = sampleNonWhitePixels(cgImage: cgImage)
    return PNGOutput(
        data: data,
        width: cgImage.width,
        height: cgImage.height,
        sampleNonWhitePixels: sample.nonWhite,
        samplePixels: sample.total
    )
}

private func sampleNonWhitePixels(cgImage: CGImage) -> (nonWhite: Int, total: Int) {
    let width = cgImage.width
    let height = cgImage.height
    guard width > 0, height > 0 else {
        return (0, 0)
    }

    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    var pixels = [UInt8](repeating: 255, count: height * bytesPerRow)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return (-1, -1)
    }

    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    let step = max(1, min(width, height) / 160)
    var nonWhite = 0
    var total = 0
    var y = 0
    while y < height {
        var x = 0
        while x < width {
            let index = (y * width + x) * bytesPerPixel
            let red = pixels[index]
            let green = pixels[index + 1]
            let blue = pixels[index + 2]
            let alpha = pixels[index + 3]
            total += 1
            if alpha > 0 && (red < 245 || green < 245 || blue < 245) {
                nonWhite += 1
            }
            x += step
        }
        y += step
    }
    return (nonWhite, total)
}

private func runMainLoop(milliseconds: Int) {
    guard milliseconds > 0 else {
        return
    }
    let deadline = Date().addingTimeInterval(Double(milliseconds) / 1000)
    while Date() < deadline {
        RunLoop.current.run(mode: .default, before: min(deadline, Date().addingTimeInterval(0.02)))
    }
}

private func javaScriptStringLiteral(_ string: String) -> String {
    let data = try! JSONEncoder().encode(string)
    return String(data: data, encoding: .utf8)!
}

private func intValue(_ value: Any?) -> Int {
    if let value = value as? Int {
        return value
    }
    if let value = value as? Double {
        return Int(value)
    }
    if let value = value as? NSNumber {
        return value.intValue
    }
    return 0
}

private func doubleValue(_ value: Any?, default defaultValue: Double = 0) -> Double {
    if let value = value as? Double {
        return value
    }
    if let value = value as? Int {
        return Double(value)
    }
    if let value = value as? NSNumber {
        return value.doubleValue
    }
    return defaultValue
}

private func stringArrayValue(_ value: Any?) -> [String] {
    if let strings = value as? [String] {
        return strings
    }
    if let values = value as? [Any] {
        return values.compactMap { $0 as? String }
    }
    return []
}

private func markdownCell(_ value: String) -> String {
    value.replacingOccurrences(of: "|", with: "/")
}

private func describeError(_ error: Error) -> String {
    if let phaseError = error as? PreviewHarnessPhaseError {
        return phaseError.description
    }

    let nsError = error as NSError
    let message = nsError.localizedDescription
    guard nsError.domain != NSCocoaErrorDomain || nsError.code != 0 else {
        return message
    }
    return "\(nsError.domain) Code=\(nsError.code) \"\(message)\""
}

private func describeJavaScriptValue(_ value: Any?) -> String {
    guard let value else {
        return "nil"
    }
    return "\(type(of: value)) \(String(describing: value))"
}

private func failurePhase(for error: Error) -> PreviewHarnessPhase {
    if let phaseError = error as? PreviewHarnessPhaseError {
        return phaseError.phase
    }

    let description = String(describing: error).lowercased()
    if description.contains("navigation") {
        return .navigation
    }
    if description.contains("ready") || description.contains("page state") || description.contains("rect is unavailable") {
        return .readiness
    }
    if description.contains("settle") {
        return .settle
    }
    if description.contains("canvas") || description.contains("dataurl") {
        return .canvasExport
    }
    if description.contains("snapshot") {
        return .snapshot
    }
    if description.contains("native") || description.contains("render") {
        return .nativeRender
    }
    if description.contains("diff") || description.contains("compare") {
        return .diff
    }
    return .unknown
}

private func formatMilliseconds(_ value: Double) -> String {
    String(format: "%.1f", value)
}

private func formatPercent(_ value: Double) -> String {
    String(format: "%.4f%%", value)
}

private func formatDouble(_ value: Double) -> String {
    String(format: "%.4f", value)
}

private func boundsString(_ bounds: CGRect?) -> String {
    guard let bounds else {
        return "-"
    }
    return "\(Int(bounds.minX)),\(Int(bounds.minY)) \(Int(bounds.width))x\(Int(bounds.height))"
}

private func studioCaptureSummary(_ result: StudioCaptureResult) -> String {
    let contamination = result.captureContaminated ? "ui=contaminated" : "ui=clean"
    let suppression = result.uiSuppressed ? ";suppressed=true" : ""
    return "\(result.captureMode);\(contamination)\(suppression)"
}

private func renderPolicyName(_ policy: HwpPageRenderPolicy) -> String {
    switch policy {
    case .coreGraphicsOnly:
        return "coreGraphicsOnly"
    case .skiaOptIn:
        return "skiaOptIn"
    }
}

private func backendName(_ backend: HwpPageRenderBackend) -> String {
    switch backend {
    case .coreGraphics:
        return "coreGraphics"
    case .skia:
        return "skia"
    case .embeddedThumbnail:
        return "embeddedThumbnail"
    }
}

private func fallbackReasonName(_ reason: HwpPageRenderFallbackReason) -> String {
    switch reason {
    case .ffiUnavailable:
        return "ffiUnavailable"
    case .invalidDocumentHandle:
        return "invalidDocumentHandle"
    case .invalidPageIndex:
        return "invalidPageIndex"
    case .invalidRenderOptions:
        return "invalidRenderOptions"
    case .invalidPageSize:
        return "invalidPageSize"
    case .skiaRenderFailure:
        return "skiaRenderFailure"
    case .pngDecodeFailure:
        return "pngDecodeFailure"
    case .memoryTimeoutFallback:
        return "memoryTimeoutFallback"
    }
}

private func fallbackSuffix(_ reason: String?) -> String {
    guard let reason else {
        return ""
    }
    return " fallback=\(reason)"
}

extension String {
    var wrappedTableRow: String {
        "| \(self) |"
    }
}

private extension RGBAImage {
    mutating func withBitmapContext(_ work: (CGContext) throws -> Void) throws {
        let bytesPerRow = width * 4
        try pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                throw PreviewHarnessError(description: "failed to create bitmap context")
            }
            try work(context)
        }
    }

    mutating func makeCGImage() throws -> CGImage {
        let bytesPerRow = width * 4
        return try pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ), let image = context.makeImage() else {
                throw PreviewHarnessError(description: "failed to create CGImage")
            }
            return image
        }
    }
}

private func print(_ value: String, to stream: inout FileHandle) {
    let data = Data((value + "\n").utf8)
    stream.write(data)
}

private var standardError = FileHandle.standardError
