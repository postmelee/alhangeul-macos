// Task #563 독립 WKWebView 실험. 제품 provider/앱 통합 검증을 대신하지 않는다.
import AppKit
import WebKit
import CoreText
import CryptoKit

struct Face: Codable {
    let id: String
    let file: String
    let sha256: String
    let postScript: String
    let weight: Int
    let variable: Bool?
}

struct Manifest: Codable {
    let faces: [Face]
}

func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

// manifest의 opaque ID만 허용한다. 파일 경로는 웹에 전달하지 않는다.
final class FontHandler: NSObject, WKURLSchemeHandler {
    let resources: [String: Data]
    var events: [[String: String]] = []

    init(resources: [String: Data]) { self.resources = resources }

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url else { return }
        guard let entry = resources.first(where: { url.absoluteString == "probe-font://session/\($0.key)" }) else {
            events.append(["url": url.absoluteString, "status": "rejected"])
            task.didFailWithError(NSError(domain: "FontProbe", code: 404))
            return
        }
        events.append(["id": entry.key, "status": "served", "sha256": digest(entry.value)])
        task.didReceive(URLResponse(url: url, mimeType: "font/sfnt", expectedContentLength: entry.value.count, textEncodingName: nil))
        task.didReceive(entry.value)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}

final class Probe: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    let root: URL
    let output: URL
    let manifest: Manifest
    let handler: FontHandler
    var result: [String: Any]
    var webView: WKWebView!
    var window: NSWindow!

    init(root: URL, output: URL, missing: Bool) throws {
        self.root = root
        self.output = output
        manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: root.appendingPathComponent("manifest.json")))
        let systemNames = Set(CTFontManagerCopyAvailablePostScriptNames() as! [String])
        let collision = manifest.faces.filter { systemNames.contains($0.postScript) }
        guard collision.isEmpty else { throw NSError(domain: "FontProbe.systemCollision", code: 1) }
        var resources: [String: Data] = [:]
        var descriptors: [[String: Any]] = []
        for face in manifest.faces {
            let url = root.appendingPathComponent("managed").appendingPathComponent(face.file)
            if missing {
                guard !FileManager.default.fileExists(atPath: url.path) else {
                    throw NSError(domain: "FontProbe.negativeHasManagedFile", code: 1)
                }
                continue
            }
            let data = try Data(contentsOf: url)
            guard digest(data) == face.sha256 else { throw NSError(domain: "FontProbe.hashMismatch", code: 1) }
            let values = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor] ?? []
            let names = values.compactMap { CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String }
            guard names.contains(face.postScript) else { throw NSError(domain: "FontProbe.faceMismatch", code: 1) }
            descriptors.append(["id": face.id, "names": names, "sha256": digest(data)])
            resources[face.id] = data
        }
        handler = FontHandler(resources: resources)
        result = ["pid": ProcessInfo.processInfo.processIdentifier,
                  "systemCollisions": collision.map(\.postScript), "descriptors": descriptors,
                  "missingControl": missing, "os": ProcessInfo.processInfo.operatingSystemVersionString]
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.setURLSchemeHandler(handler, forURLScheme: "probe-font")
        let height = max(560, manifest.faces.count * 70 + 48)
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1000, height: height), configuration: configuration)
        webView.navigationDelegate = self
        window = NSWindow(contentRect: webView.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = webView
        window.orderFront(nil)
        let rules = manifest.faces.map {
            "@font-face{font-family:'\($0.id)';src:url('probe-font://session/\($0.id)');font-weight:\($0.variable == true ? "45 930" : String($0.weight));}"
        }.joined(separator: "\n")
        let rows = manifest.faces.map {
            "<div class='row' data-id='\($0.id)' data-weight='\($0.weight)' style=\"font-family:'\($0.id)',monospace;font-weight:\($0.weight)\">한글 글꼴 독립 복사 확인 ABC 123</div>"
        }.joined(separator: "\n")
        // 네트워크·파일 로딩 금지. JS는 이 고정 실험 문서의 계측에만 사용한다.
        let html = """
        <!doctype html><meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; font-src probe-font:; style-src 'unsafe-inline'; script-src 'none'">
        <style>\(rules) body{margin:24px;background:white;color:black}.row{font-size:32px;line-height:70px;font-synthesis:none;white-space:nowrap}</style>
        \(rows)
        """
        do { try html.write(to: output.appendingPathComponent("sample.html"), atomically: true, encoding: .utf8) }
        catch { fail(error) }
        webView.loadHTMLString(html, baseURL: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 45) { self.fail(NSError(domain: "FontProbe.timeout", code: 1)) }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.callAsyncJavaScript("""
        const rows = [...document.querySelectorAll('.row')];
        const loads = await Promise.allSettled(rows.map(r => document.fonts.load(`${r.dataset.weight} 32px '${r.dataset.id}'`, r.textContent)));
        await document.fonts.ready;
        await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
        return rows.map((r,i) => {
          const c = document.createElement('canvas'); c.width=950;c.height=65;
          const ctx=c.getContext('2d');ctx.fillStyle='white';ctx.fillRect(0,0,c.width,c.height);
          ctx.fillStyle='black';ctx.font=`${r.dataset.weight} 32px '${r.dataset.id}',monospace`;
          ctx.fillText(r.textContent,0,42);
          const range=document.createRange();range.selectNodeContents(r);
          return {id:r.dataset.id,load:loads[i].status,width:ctx.measureText(r.textContent).width,
                  domWidth:range.getBoundingClientRect().width,raster:c.toDataURL()};
        });
        """, arguments: [:], in: nil, in: .page) { value in
            switch value {
            case .failure(let error): self.fail(error)
            case .success(let data):
                guard var rows = data as? [[String: Any]] else { self.fail(NSError(domain: "FontProbe.metrics", code: 1)) }
                for index in rows.indices {
                    guard let raster = rows[index].removeValue(forKey: "raster") as? String,
                          let png = Data(base64Encoded: String(raster.split(separator: ",", maxSplits: 1).last ?? "")) else {
                        self.fail(NSError(domain: "FontProbe.raster", code: 1))
                    }
                    rows[index]["rasterSHA256"] = digest(png)
                    do { try png.write(to: self.output.appendingPathComponent("row-\(index).png")) }
                    catch { self.fail(error) }
                }
                self.result["rows"] = rows
                self.capture()
            }
        }
    }

    func capture() {
        webView.takeSnapshot(with: nil) { image, error in
            guard error == nil, let tiff = image?.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) else {
                self.fail(error ?? NSError(domain: "FontProbe.snapshot", code: 1))
            }
            do { try png.write(to: self.output.appendingPathComponent("screen.png")) }
            catch { self.fail(error) }
            let configuration = WKPDFConfiguration()
            configuration.rect = self.webView.bounds
            self.webView.createPDF(configuration: configuration) { pdf in
                do {
                    try pdf.get().write(to: self.output.appendingPathComponent("sample.pdf"))
                    self.result["resources"] = self.handler.events
                    let json = try JSONSerialization.data(withJSONObject: self.result, options: [.prettyPrinted, .sortedKeys])
                    try json.write(to: self.output.appendingPathComponent("result.json"))
                    self.window.close()
                    exit(0)
                } catch { self.fail(error) }
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { fail(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { fail(error) }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { fail(NSError(domain: "FontProbe.webProcessTerminated", code: 1)) }

    func fail(_ error: Error) -> Never {
        fputs("Font probe failed: \(error)\n", stderr)
        exit(1)
    }
}

guard CommandLine.arguments.count == 4 else {
    fputs("usage: FontMigrationProbe RUN_ROOT OUTPUT present|missing\n", stderr)
    exit(2)
}
do {
    let probe = try Probe(root: URL(fileURLWithPath: CommandLine.arguments[1]),
                          output: URL(fileURLWithPath: CommandLine.arguments[2]),
                          missing: CommandLine.arguments[3] == "missing")
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    app.delegate = probe
    withExtendedLifetime(probe) { app.run() }
} catch {
    fputs("Font probe failed: \(error)\n", stderr)
    exit(1)
}
