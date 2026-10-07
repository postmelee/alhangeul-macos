import Foundation
import WebKit

@MainActor
final class StudioFontMessageHandler: NSObject, WKScriptMessageHandlerWithReply {
    static let name = "alhangeulFonts"
    weak var webView: WKWebView?
    private let session: StudioFontSession
    private let observeLiveChanges: Bool

    init(session: StudioFontSession? = nil, observeLiveChanges: Bool = true) {
        self.session = session ?? StudioFontSession()
        self.observeLiveChanges = observeLiveChanges
        super.init()
    }
    private var observations: [Task<Void, Never>] = []
    private var active = false
    private var loadToken: String?

    deinit { for task in observations { task.cancel() } }

    func begin(loadToken: String, observeChanges: Bool = true) {
        reset()
        active = true
        self.loadToken = loadToken
        guard observeChanges && observeLiveChanges else { return }
        observations.append(Task { [weak self] in
            guard let catalog = try? await InstalledFontServiceProvider.shared.service() else { return }
            let stream = await catalog.updates()
            var previous: UUID?
            for await snapshot in stream {
                guard !Task.isCancelled else { return }
                if let previous, previous != snapshot.generation { self?.changed() }
                previous = snapshot.generation
            }
        })
        observations.append(Task { [weak self] in
            guard let library = try? FontLibraryService.shared.get() else { return }
            let stream = await library.changes.updates()
            var initial = true
            for await _ in stream {
                guard !Task.isCancelled else { return }
                if !initial { self?.changed() }
                initial = false
            }
        })
    }

    func reset() {
        active = false
        loadToken = nil
        for task in observations { task.cancel() }
        observations.removeAll()
        session.invalidate()
    }

    private func changed() {
        session.invalidate()
        webView?.evaluateJavaScript("window.dispatchEvent(new Event('alhangeul-fonts-changed'))", completionHandler: nil)
    }

    static func permits(mainFrame: Bool, originScheme: String, originHost: String,
                        originPort: Int, frameURL: URL?, sameWebView: Bool) -> Bool {
        mainFrame && sameWebView && originScheme == "alhangeul-studio"
            && originHost == "app" && originPort == 0
            && frameURL?.scheme == "alhangeul-studio" && frameURL?.host == "app"
            && frameURL?.path == "/index.html"
    }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage,
                               replyHandler: @escaping (Any?, String?) -> Void) {
        let origin = message.frameInfo.securityOrigin
        guard active, message.name == Self.name,
              Self.permits(mainFrame: message.frameInfo.isMainFrame,
                           originScheme: origin.protocol, originHost: origin.host, originPort: origin.port,
                           frameURL: message.frameInfo.request.url, sameWebView: message.webView === webView)
        else { replyHandler(nil, StudioFontError.unauthorized.rawValue); return }
        guard var body = message.body as? [String: Any],
              JSONSerialization.isValidJSONObject(body),
              let encoded = try? JSONSerialization.data(withJSONObject: body), encoded.count <= 4096,
              let token = body.removeValue(forKey: "loadToken") as? String, token == loadToken
        else { replyHandler(nil, StudioFontError.staleSession.rawValue); return }
        Task { @MainActor [weak self] in
            guard let self, self.active, self.loadToken == token else { replyHandler(nil, StudioFontError.cancelled.rawValue); return }
            do {
                let response = try await session.handle(body)
                guard active, loadToken == token else { throw StudioFontError.staleSession }
                replyHandler(response, nil)
            }
            catch let error as StudioFontError { replyHandler(nil, error.rawValue) }
            catch let error as InstalledFontFailure { replyHandler(nil, error.rawValue) }
            catch { replyHandler(nil, StudioFontError.unavailable.rawValue) }
        }
    }
}
