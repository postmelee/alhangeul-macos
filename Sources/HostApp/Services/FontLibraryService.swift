import Foundation

struct FontLibraryImportRequest: Sendable {
    let candidates: [FontImportCandidate]
    // NSOpenPanel로 고른 폴더와 그 하위 후보 URL은 다를 수 있다.
    // ZIP 해제물은 호출자가 수명을 유지하고, 필요한 원본 권한 URL을 명시한다.
    let accessURLs: [URL]
}

struct FontLibrarySourceAccess: Sendable {
    let start: @Sendable (URL) -> Bool
    let stop: @Sendable (URL) -> Void
    static let securityScoped = Self(
        start: { $0.startAccessingSecurityScopedResource() },
        stop: { $0.stopAccessingSecurityScopedResource() })
}

// UI/탐색/ZIP과 무관한 HostApp 진입점. 원본 권한만 여기서 소유한다.
// 모든 저장 I/O는 FontLibraryStore의 직렬 큐에서 실행한다.
final class FontLibraryService: Sendable {
    private let store: FontLibraryStore
    private let access: FontLibrarySourceAccess

    convenience init() throws {
        try self.init(store: FontLibraryStore(rootURL: FontLibraryLocation().resolve()))
    }

    // 테스트 및 격리된 진단에서만 root가 주입된 store를 전달한다.
    init(store: FontLibraryStore, access: FontLibrarySourceAccess = .securityScoped) {
        self.store = store
        self.access = access
    }

    func prepare() async throws -> FontLibraryRecoveryResult { try await store.recover() }
    func list() async throws -> FontLibraryManifest { try await store.list() }

    func importFonts(_ request: FontLibraryImportRequest) async -> [FontImportItemResult] {
        var started: [URL] = []
        var seen = Set<URL>()
        defer { for url in started.reversed() { access.stop(url) } }
        if !Task.isCancelled {
            for url in request.accessURLs where seen.insert(url).inserted {
                if Task.isCancelled { break }
                if access.start(url) { started.append(url) }
                // false는 sandbox 안의 이미 읽을 수 있는 파일에서도 가능하다.
                // 실제 읽기 거부는 store가 후보별 readFailure로 반환한다.
            }
        }
        // 배치 전체를 한 번에 넘겨 후보 수/누적 bytes 한도를 유지한다.
        return await store.importCandidates(request.candidates)
    }

    func selectActive(groupID: String, faceID: FontFaceID, expectedGeneration: UInt64) async throws -> FontLibraryManifest {
        try await store.selectActive(groupID: groupID, faceID: faceID, expectedGeneration: expectedGeneration)
    }
    func remove(objectHash: String, expectedGeneration: UInt64) async throws -> FontLibraryManifest {
        try await store.remove(objectHash: objectHash, expectedGeneration: expectedGeneration)
    }
    func acquireSnapshot() async throws -> FontLibrarySnapshot { try await store.acquireSnapshot() }
    func readResource(_ id: String, snapshot: FontLibrarySnapshot) async throws -> Data {
        try await store.readResource(id, snapshot: snapshot)
    }
    func releaseSnapshot(_ snapshot: FontLibrarySnapshot) async throws {
        try await store.releaseSnapshot(snapshot)
    }
    func recover() async throws -> FontLibraryRecoveryResult { try await store.recover() }
}
