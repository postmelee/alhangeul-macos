import AppKit
import WebKit

// xctest의 NSApplication 수명과 분리한 실제 WebKit/응답형 IPC 계약 검증.
// 실제 설치 감지·제품 Studio renderer 수용은 별도 Stage 3.2/4/5에서 수행한다.
@MainActor
private final class Probe: NSObject, NSApplicationDelegate, WKURLSchemeHandler, WKScriptMessageHandler {
    private var webView: WKWebView?
    private var handler: StudioFontMessageHandler?
    private var expected = Data()
    private var html = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
            guard let face = try FontFileInspector().inspect(data, filename: "regular.ttf").faces.first else {
                throw StudioFontError.unavailable
            }
            expected = data
            let row = StudioFontFace(id: "fixture", source: "managed", postScriptName: face.postScriptName,
                family: face.familyName ?? "Fixture", fullName: face.fullName ?? "Fixture Regular",
                style: "Regular", aliases: [], weight: Int(face.weightClass), traits: UInt32(face.selectionFlags), limitation: nil)
            let session = StudioFontSession(supply: .init(snapshot: {
                .init(identity: "fixture-1", faces: [row], omitted: 0, failure: nil,
                    read: { _ in .init(data: data, face: face) }, current: { true }, release: {})
            }), budget: .init())
            let handler = StudioFontMessageHandler(session: session)
            self.handler = handler
            let configuration = WKWebViewConfiguration()
            configuration.websiteDataStore = .nonPersistent()
            configuration.setURLSchemeHandler(self, forURLScheme: "alhangeul-studio")
            configuration.userContentController.addScriptMessageHandler(handler, contentWorld: .page, name: "alhangeulFonts")
            configuration.userContentController.add(self, name: "result")
            let view = WKWebView(frame: .zero, configuration: configuration)
            webView = view; handler.webView = view
            handler.begin(loadToken: "adapter-probe", observeChanges: false)
            html = """
            <!doctype html><meta charset="utf-8"><script>
            (async () => {
              const create = \(StudioFontProviderScript.source);
              const adapter = create({events: window, getLoadToken: () => 'adapter-probe',
                postMessage: body => window.webkit.messageHandlers.alhangeulFonts.postMessage(body),
                getFontsAPI: () => ({setProvider: async provider => {
                  if (provider) await provider.getSnapshot(new AbortController().signal);
                }, getState: () => ({active: true})})});
              try {
                await adapter.connect();
                const snapshot = await adapter.provider.getSnapshot(new AbortController().signal);
                const result = await adapter.provider.readFace(snapshot.faces[0].id, snapshot.revision, new AbortController().signal);
                await adapter.dispose();
                window.webkit.messageHandlers.result.postMessage({count: snapshot.faces.length,
                  bytes: Array.from(new Uint8Array(result.bytes)), faceIndex: result.faceIndex});
              } catch (error) {
                await adapter.dispose();
                window.webkit.messageHandlers.result.postMessage({error: String(error)});
              }
            })();
            </script>
            """
            view.load(URLRequest(url: URL(string: "alhangeul-studio://app/index.html")!))
            DispatchQueue.main.asyncAfter(deadline: .now() + 20) { self.finish("WebKit 응답 timeout") }
        } catch { finish("probe 초기화: \(error)") }
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        let data = Data(html.utf8)
        urlSchemeTask.didReceive(URLResponse(url: urlSchemeTask.request.url!, mimeType: "text/html",
            expectedContentLength: data.count, textEncodingName: "utf-8"))
        urlSchemeTask.didReceive(data); urlSchemeTask.didFinish()
    }
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], body["error"] == nil,
              body["count"] as? Int == 1, body["faceIndex"] as? Int == 0,
              let bytes = body["bytes"] as? [UInt8], Data(bytes) == expected else {
            finish("bytes/face 불일치: \((message.body as? [String: Any])?["error"] ?? "invalid result")")
            return
        }
        finish(nil)
    }
    private func finish(_ error: String?) {
        handler?.reset()
        webView?.stopLoading()
        webView?.configuration.userContentController.removeAllScriptMessageHandlers()
        print(error.map { "FAIL: \($0)" } ?? "PASS: 실제 WKWebView → native session → adapter, \(expected.count) bytes 완전 일치·faceIndex 0")
        exit(error == nil ? 0 : 1)
    }
}

@main
private struct Main {
    @MainActor static func main() {
        let app = NSApplication.shared
        let probe = Probe()
        app.setActivationPolicy(.prohibited)
        app.delegate = probe
        withExtendedLifetime(probe) { app.run() }
    }
}
