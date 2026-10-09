import Foundation

// 설정과 모든 문서가 같은 catalog를 사용한다. 동시 최초 요청도 생성 Task를 공유한다.
actor InstalledFontServiceProvider {
    static let shared = InstalledFontServiceProvider()
    private let factory: @Sendable () async throws -> InstalledFontCatalogService
    private var pending: Task<InstalledFontCatalogService, Error>?

    init(factory: @escaping @Sendable () async throws -> InstalledFontCatalogService = {
        try await Task.detached { try InstalledFontCatalogService.live() }.value
    }) { self.factory = factory }

    func service() async throws -> InstalledFontCatalogService {
        if let pending { return try await pending.value }
        let task = Task { try await factory() }
        pending = task
        do { return try await task.value }
        catch { pending = nil; throw error }
    }
}
