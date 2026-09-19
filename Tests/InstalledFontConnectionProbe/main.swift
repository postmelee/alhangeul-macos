// Task #565 Stage 3: 독립 연결 실험. 제품 provider 및 sandbox 검증을 대신하지 않는다.
import AppKit
import WebKit
import CoreText
import CryptoKit

func sha(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
func json(_ value: Any) throws -> Data { try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]) }

final class Probe: NSObject, NSApplicationDelegate, WKURLSchemeHandler, WKScriptMessageHandlerWithReply {
    let root: URL
    let output: URL
    var entries: [[String: String]] = []
    var urls: [String: URL] = [:]
    var events: [[String: Any]] = []
    var storage: [String: Any] = [:]
    var window: NSWindow!
    var web: WKWebView!
    var phase = "initial"
    var fault = "none"
    var done = false

    init(root: URL, output: URL) throws {
        self.root = root; self.output = output
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let saved = output.appendingPathComponent("snapshot.json")
        if let data = try? Data(contentsOf: saved) { storage = (try JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:] }
        super.init()
        let collection = CTFontCollectionCreateFromAvailableFonts(nil)
        let descriptors = CTFontCollectionCreateMatchingFontDescriptors(collection) as? [CTFontDescriptor] ?? []
        for ps in ["NanumSquareR", "NanumSquareB"] {
            guard let descriptor = descriptors.first(where: { CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String == ps }),
                  let url = CTFontDescriptorCopyAttribute(descriptor, kCTFontURLAttribute) as? URL else {
                throw NSError(domain: "Probe.requiredActiveFace.\(ps)", code: 1)
            }
            let font = CTFontCreateWithFontDescriptor(descriptor, 16, nil)
            let id = "face-\(entries.count)"
            urls[id] = url
            entries.append(["id": id, "postscriptName": ps, "family": CTFontCopyFamilyName(font) as String,
                "fullName": CTFontCopyFullName(font) as String,
                "style": CTFontDescriptorCopyAttribute(descriptor, kCTFontStyleNameAttribute) as? String ?? ""])
        }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.setURLSchemeHandler(self, forURLScheme: "probe")
        config.userContentController.addScriptMessageHandler(self, contentWorld: .page, name: "native")
        web = WKWebView(frame: NSRect(x: 0, y: 0, width: 1000, height: 580), configuration: config)
        window = NSWindow(contentRect: web.frame, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Mac 설치 글꼴 연결 실험 — 제품 화면 아님"
        window.contentView = web; window.makeKeyAndOrderFront(nil)
        web.load(URLRequest(url: URL(string: "probe://app/index.html")!))
        DispatchQueue.main.asyncAfter(deadline: .now() + 90) { if !self.done { self.finish(["error": "timeout"], status: 1) } }
    }
    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        do {
            guard let url = task.request.url, url.host == "app" else { throw NSError(domain: "Probe.origin", code: 1) }
            let files = ["/index.html": "index.html", "/app.js": "app.js", "/canvaskit.wasm": "canvaskit.wasm",
                         "/fonts/NotoSansKR-Regular.woff2": "fonts/NotoSansKR-Regular.woff2",
                         "/fonts/D2Coding-Regular.woff2": "fonts/D2Coding-Regular.woff2",
                         "/fonts/SourceHanSerifK-OldHangul-subset.woff2": "fonts/SourceHanSerifK-OldHangul-subset.woff2"]
            guard let path = files[url.path] else { throw NSError(domain: "Probe.path", code: 404) }
            let data = try Data(contentsOf: root.appendingPathComponent(path))
            let mime = path.hasSuffix("js") ? "text/javascript" : path.hasSuffix("wasm") ? "application/wasm" : path.hasSuffix("html") ? "text/html" : "font/woff2"
            task.didReceive(HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": mime, "Content-Length": String(data.count)])!)
            task.didReceive(data); task.didFinish()
        } catch { task.didFailWithError(error) }
    }
    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage,
                               replyHandler: @escaping (Any?, String?) -> Void) {
        do {
            guard message.frameInfo.isMainFrame, message.frameInfo.request.url?.host == "app",
                  let body = message.body as? [String: Any], let op = body["op"] as? String else { throw NSError(domain: "Probe.message", code: 1) }
            switch op {
            case "catalog": replyHandler(entries, nil)
            case "phase": phase = body["value"] as? String ?? "unknown"; fault = body["fault"] as? String ?? "none"; replyHandler(true, nil)
            case "get": replyHandler(storage, nil)
            case "set":
                guard let items = body["items"] as? [String: Any] else { throw NSError(domain: "Probe.storage", code: 1) }
                storage.merge(items) { _, new in new }
                try json(storage).write(to: output.appendingPathComponent("snapshot.json"), options: .atomic)
                replyHandler(true, nil)
            case "read":
                guard let id = body["id"] as? String, let url = urls[id], let entry = entries.first(where: { $0["id"] == id }) else { throw NSError(domain: "Probe.id", code: 1) }
                if fault == "missing" || fault == "denied" {
                    events.append(["phase": phase, "id": id, "fault": fault, "read": false])
                    replyHandler(nil, "injected-\(fault)"); return
                }
                let active = Set(CTFontManagerCopyAvailablePostScriptNames() as! [String])
                guard active.contains(entry["postscriptName"]!) else { throw NSError(domain: "Probe.inactive", code: 1) }
                let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
                guard let size = attrs[.size] as? NSNumber, size.intValue <= 64 * 1024 * 1024 else { throw NSError(domain: "Probe.size", code: 1) }
                let data = fault.hasPrefix("corrupt") ? Data("invalid font".utf8) : try Data(contentsOf: url)
                let names = CTFontManagerCreateFontDescriptorsFromData(data as CFData) as? [CTFontDescriptor] ?? []
                let actual = names.compactMap { CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String }
                events.append(["phase": phase, "id": id, "sha256": sha(data), "bytes": data.count, "sourceFile": url.lastPathComponent,
                               "inode": String(describing: attrs[.systemFileNumber] ?? ""), "actualPS": actual, "fault": fault, "read": true, "diskRead": !fault.hasPrefix("corrupt"),
                               "validationPassed": actual.contains(entry["postscriptName"]!)])
                if fault != "corruptRaw", !actual.contains(entry["postscriptName"]!) { throw NSError(domain: "Probe.identity", code: 1) }
                replyHandler(data.base64EncodedString(), nil)
            case "finish":
                replyHandler(true, nil)
                finish(body["result"] as? [String: Any] ?? ["error": "no result"], status: body["failed"] as? Bool == true ? 1 : 0)
            default: throw NSError(domain: "Probe.operation", code: 1)
            }
        } catch { replyHandler(nil, String(describing: error)) }
    }
    func finish(_ value: [String: Any], status: Int32) {
        guard !done else { return }; done = true
        var result = value
        if let png = result.removeValue(forKey: "png") as? String, let data = Data(base64Encoded: String(png.split(separator: ",").last ?? "")) {
            try? data.write(to: output.appendingPathComponent("render-\(ProcessInfo.processInfo.processIdentifier).png"))
        }
        result["events"] = events; result["catalog"] = entries
        result["pid"] = ProcessInfo.processInfo.processIdentifier
        result["os"] = ProcessInfo.processInfo.operatingSystemVersionString
        result["sandbox"] = CommandLine.arguments.contains("--sandbox")
        do { try json(result).write(to: output.appendingPathComponent("result-\(ProcessInfo.processInfo.processIdentifier).json")) }
        catch { fputs("result write failed: \(error)\n", stderr); exit(1) }
        print("probe status=\(status) events=\(events.count) output=\(output.path)")
        exit(status)
    }
}
let args = CommandLine.arguments
let sandbox = args.count == 2 && args[1] == "--sandbox"
guard args.count == 3 || sandbox else { fatalError("usage: probe static-root output-root | --sandbox") }
let staticRoot = sandbox ? Bundle.main.resourceURL! : URL(fileURLWithPath: args[1])
let resultRoot = sandbox ? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Task565ConnectionProbe") : URL(fileURLWithPath: args[2])
let app = NSApplication.shared
let probe = try Probe(root: staticRoot, output: resultRoot)
app.delegate = probe
app.setActivationPolicy(.regular)
app.run()
