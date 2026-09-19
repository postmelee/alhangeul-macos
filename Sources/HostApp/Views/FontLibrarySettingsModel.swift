import Combine
import Foundation

struct FontLibraryUIClient: Sendable {
    var prepare: @Sendable () async throws -> FontLibraryRecoveryResult
    var list: @Sendable () async throws -> FontLibraryManifest
    var importFonts: @Sendable (FontLibraryImportRequest) async -> [FontImportItemResult]

    init(service: FontLibraryService) {
        prepare = { try await service.prepare() }
        list = { try await service.list() }
        importFonts = { await service.importFonts($0) }
    }
}

@MainActor
final class FontLibrarySettingsModel: ObservableObject {
    enum Phase: Equatable { case source, discovering, candidates, importing, results }
    @Published private(set) var phase: Phase = .source
    @Published private(set) var manifest = FontLibraryManifest()
    @Published private(set) var discovery = MacFontDiscoveryResult()
    @Published private(set) var results: [FontImportItemResult] = []
    @Published private(set) var selected = Set<UUID>()
    @Published private(set) var ready = false
    @Published private(set) var preparing = false
    @Published private(set) var cancelling = false
    @Published private(set) var message: String?
    @Published var showingImport = false

    private let makeClient: () throws -> FontLibraryUIClient
    private let discover: @Sendable (MacFontDiscoveryRequest, FontImportSourceSession?) async -> MacFontDiscoveryResult
    private let sourceAccess: FontLibrarySourceAccess
    private var client: FontLibraryUIClient?
    private var session: FontImportSourceSession?
    private var operation: Task<Void, Never>?
    private var requestID = UUID()

    init(makeClient: @escaping () throws -> FontLibraryUIClient = { .init(service: try FontLibraryService()) },
         discover: @escaping @Sendable (MacFontDiscoveryRequest, FontImportSourceSession?) async -> MacFontDiscoveryResult = {
             await MacFontDiscovery().discover($0, session: $1)
         }, sourceAccess: FontLibrarySourceAccess = .securityScoped) {
        self.makeClient = makeClient
        self.discover = discover
        self.sourceAccess = sourceAccess
    }

    var busy: Bool { preparing || phase == .discovering || phase == .importing }
    var selectedCandidates: [MacFontCandidate] { discovery.candidates.filter { selected.contains($0.id) } }

    func prepare() async {
        guard !busy else { return }
        preparing = true
        message = nil
        defer { preparing = false }
        do {
            let service = try client ?? makeClient()
            let recovery = try await service.prepare()
            let latest = try await service.list()
            client = service
            manifest = latest
            ready = true
            if recovery.collectionDeferred { message = "사용 중이거나 확인이 필요한 파일은 안전하게 보관하고 있습니다." }
        } catch {
            ready = false
            message = "글꼴 보관함을 열 수 없습니다. 다시 시도해 주세요. 문제가 계속되면 앱을 재실행해 주세요."
        }
    }

    func beginImport() {
        guard ready, !busy else { return }
        discardSession()
        phase = .source
        discovery = .init(); results = []; selected = []
        message = nil
        showingImport = true
    }

    func scanInstalled() {
        do { scan(try .defaultInstalled()) }
        catch { message = "사용자 글꼴 위치를 확인할 수 없습니다. 글꼴 폴더를 직접 선택해 주세요." }
    }
    func scanApplications() {
        do { scan(try .defaultApplications()) }
        catch { message = "한글 설치 위치를 확인할 수 없습니다. 한글 앱을 직접 선택해 주세요." }
    }
    func selectedLocations(_ urls: [URL]?) {
        // panel 취소는 현재 후보와 선택·권한을 보존한다.
        guard showingImport, let urls, !urls.isEmpty, !busy else { return }
        scan(.selected(urls), urls: urls)
    }
    func scan(_ request: MacFontDiscoveryRequest, urls: [URL] = []) {
        guard ready, !busy else { return }
        discardSession()
        let currentSession = urls.isEmpty ? nil : FontImportSourceSession(urls: urls, access: sourceAccess)
        session = currentSession
        let id = UUID(); requestID = id
        phase = .discovering; cancelling = false; message = nil
        discovery = .init(); selected = []; results = []
        operation = Task { [weak self, discover] in
            let result = await discover(request, currentSession)
            guard let self, self.requestID == id else { return }
            self.discovery = result
            self.selected = Set(result.candidates.map(\.id))
            self.phase = .candidates
            self.cancelling = false
            self.operation = nil
            if result.cancelled { self.message = "검색을 취소했습니다. 지금까지 찾은 후보를 확인하거나 다시 검색할 수 있습니다." }
        }
    }
    func setSelected(_ id: UUID, _ value: Bool) {
        guard phase == .candidates else { return }
        if value { selected.insert(id) } else { selected.remove(id) }
    }
    func selectAll(_ value: Bool) {
        guard phase == .candidates else { return }
        selected = value ? Set(discovery.candidates.map(\.id)) : []
    }
    func importSelected() {
        guard ready, !busy, phase == .candidates, let client, !selectedCandidates.isEmpty else { return }
        let candidates = selectedCandidates.map(\.importCandidate)
        let currentSession = session
        let lease = currentSession?.acquire()
        guard currentSession == nil || lease != nil else {
            message = "선택한 위치의 접근이 종료됐습니다. 폴더를 다시 선택해 주세요."; return
        }
        let request = FontLibraryImportRequest(candidates: candidates, accessURLs: currentSession?.urls ?? [])
        let id = UUID(); requestID = id
        phase = .importing; cancelling = false; message = nil
        operation = Task { [weak self] in
            let imported = await client.importFonts(request)
            // 취소된 Task에서도 이미 저장한 결과는 새 작업으로 조회한다.
            let refreshed = await Task { try? await client.list() }.value
            withExtendedLifetime(lease) {}
            currentSession?.close()
            guard let self, self.requestID == id else { return }
            self.results = imported
            if let refreshed { self.manifest = refreshed }
            else { self.message = "가져오기 결과는 아래와 같습니다. 보관함 목록은 닫은 뒤 새로고침해 주세요." }
            self.session = nil
            self.phase = .results
            self.cancelling = false
            self.operation = nil
        }
    }
    func cancel() {
        guard phase == .discovering || phase == .importing else { return }
        cancelling = true
        operation?.cancel()
    }
    func dismissImport() {
        if phase == .importing {
            showingImport = false
            cancel()
            return
        }
        operation?.cancel()
        operation = nil
        requestID = UUID()
        discardSession()
        showingImport = false
        phase = .source; cancelling = false
        // worker는 자체 lease를 유지한다. 화면은 늦은 결과를 받지 않는다.
    }
    private func discardSession() { session?.close(); session = nil }
    deinit { operation?.cancel(); session?.close() }
}
