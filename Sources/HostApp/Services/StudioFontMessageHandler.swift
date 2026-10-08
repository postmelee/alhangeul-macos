import Foundation
import WebKit

@MainActor
final class StudioFontMessageHandler: NSObject, WKScriptMessageHandlerWithReply {
    static let name = "alhangeulFonts"
    weak var webView: WKWebView?
    private let session: StudioFontSession
    private let observeLiveChanges: Bool
    private let installed: InstalledFontServiceProvider
    private let library: @Sendable () throws -> FontLibraryService
    private let onFaceRead: ((String, String, String) -> Void)?
    private let onOutputFaceRead: (@MainActor @Sendable (String, StudioFontBytes) async -> Void)?

    init(session: StudioFontSession? = nil, observeLiveChanges: Bool = true,
         installed: InstalledFontServiceProvider = .shared,
         library: @escaping @Sendable () throws -> FontLibraryService = { try FontLibraryService.shared.get() },
         onFaceRead: ((String, String, String) -> Void)? = nil,
         onOutputFaceRead: (@MainActor @Sendable (String, StudioFontBytes) async -> Void)? = nil) {
        self.session = session ?? StudioFontSession(supply: .using(installed: installed, library: library))
        self.observeLiveChanges = observeLiveChanges
        self.installed = installed; self.library = library
        self.onFaceRead = onFaceRead
        self.onOutputFaceRead = onOutputFaceRead
        super.init()
    }
    private var observations: [Task<Void, Never>] = []
    private var active = false
    private var loadToken: String?

    func outputSnapshot() async throws -> StudioFontSupplySnapshot {
        let snapshot = try await StudioFontSupply.using(installed: installed, library: library).snapshot()
        guard let observe = onOutputFaceRead else { return snapshot }
        return .init(identity:snapshot.identity,faces:snapshot.faces,omitted:snapshot.omitted,failure:snapshot.failure,
            read:{ id in
                let bytes = try await snapshot.read(id)
                await observe(id, bytes)
                return bytes
            }, current:snapshot.current,release:snapshot.release)
    }

    deinit { for task in observations { task.cancel() } }

    func begin(loadToken: String, observeChanges: Bool = true) {
        reset()
        active = true
        self.loadToken = loadToken
        guard observeChanges && observeLiveChanges else { return }
        observations.append(Task { [weak self, installed] in
            guard let catalog = try? await installed.service() else { return }
            let stream = await catalog.updates()
            var previous: UUID?
            for await snapshot in stream {
                guard !Task.isCancelled else { return }
                if let previous, previous != snapshot.generation { self?.changed() }
                previous = snapshot.generation
            }
        })
        observations.append(Task { [weak self, library] in
            guard let library = try? library() else { return }
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
                // 격리 검증용으로 현재 frame에 실제 공급한 식별자/검증 hash만 관찰한다.
                if body["op"] as? String == "openFace", let id = body["id"] as? String,
                   let ps = response["postScriptName"] as? String, let hash = response["sha256"] as? String {
                    onFaceRead?(id, ps, hash)
                }
                replyHandler(response, nil)
            }
            catch let error as StudioFontError { replyHandler(nil, error.rawValue) }
            catch let error as InstalledFontFailure { replyHandler(nil, error.rawValue) }
            catch { replyHandler(nil, StudioFontError.unavailable.rawValue) }
        }
    }
}
