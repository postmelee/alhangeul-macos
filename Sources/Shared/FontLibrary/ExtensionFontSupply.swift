import CryptoKit
import Foundation
import OSLog

/// 확장별 singleton. HostApp catalog/bookmark는 읽지 않고 자체 CoreText 목록과 권한을 사용한다.
actor ExtensionFontSupply {
    static let shared = ExtensionFontSupply()
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.postmelee.alhangeul.FontSupply",
                                       category: "ExtensionFontSupply")
    private let resolveRoot: @Sendable () throws -> URL
    private let environment: InstalledFontEnvironment
    private var catalog: InstalledFontCatalogService?
    private var library: FontLibraryService?
    private var root: URL?

    init(resolveRoot: @escaping @Sendable () throws -> URL = { try FontLibraryLocation().resolve() },
         environment: InstalledFontEnvironment = InstalledFontSystem().environment) {
        self.resolveRoot = resolveRoot; self.environment = environment
    }

    func snapshot() async throws -> StudioFontSupplySnapshot {
        let started = DispatchTime.now().uptimeNanoseconds
        try Task.checkCancellation()
        if root == nil {
            let resolved = try resolveRoot()
            let own = try InstalledFontCatalogService(persistence: .init(load: { nil }, save: { _ in }),
                environment: environment)
            catalog = own; library = FontLibraryService(store: FontLibraryStore(rootURL: resolved), readOnly: true); root = resolved
        }
        guard let root, let catalog, let library else { throw StudioFontError.unavailable }
        let policyStore = FontConsumerPolicyStore(rootURL: root)
        let policy = try policyStore.read()
        _ = try await catalog.setEnabled(policy.installedEnabled)
        // 각 요청의 cache 조회 전에 자체 metadata 목록을 다시 확인한다. bytes 선읽기는 없다.
        _ = try await catalog.refresh()
        let provider = InstalledFontServiceProvider(factory: { catalog })
        let base = try await StudioFontSupply.using(installed: provider, library: { library }).snapshot()
        do {
            let records = await catalog.snapshot().records
            let manifest = try await library.list()
            let fingerprint = try Self.fingerprint(root: root, records: records, manifest: manifest)
            guard try policyStore.read() == policy, try await base.current() else { throw StudioFontError.staleGeneration }
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000
            Self.logger.debug("Font metadata ready installedEnabled=\(policy.installedEnabled, privacy: .public) records=\(records.count, privacy: .public) managed=\(manifest.entries.count, privacy: .public) metadataMs=\(elapsed, privacy: .public)")
            return .init(identity: base.identity + ":" + policy.revision.uuidString + ":" + fingerprint,
                faces: base.faces, omitted: base.omitted, failure: base.failure,
                read: base.read, current: {
                    do {
                        guard try policyStore.read() == policy, try await base.current() else { return false }
                        let latest = try await library.list()
                        return try Self.fingerprint(root: root, records: records, manifest: latest) == fingerprint
                    } catch { return false } // 게시/원본 확인 중 실패한 이전 결과는 사용하지 않는다.
                }, release: base.release)
        } catch {
            await base.release()
            throw error
        }
    }

    private static func fingerprint(root: URL, records: [InstalledFontRecord], manifest: FontLibraryManifest) throws -> String {
        struct Item: Encodable { let id: String; let stamp: InstalledFontStamp? }
        // 실제 읽기는 FD+hash로 검증한다. 이 stat은 cache 무효화 신호일 뿐이다.
        let installed = records.map { Item(id: $0.id, stamp: try? InstalledFontSystem.statURL($0.sourceURL)) }
        let objects = manifest.entries.map { entry in
            Item(id: entry.object.sha256,
                stamp: try? InstalledFontSystem.statURL(root.appendingPathComponent("objects/" + entry.object.sha256 + ".font")))
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(installed + objects)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
