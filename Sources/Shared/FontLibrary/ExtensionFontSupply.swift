import CryptoKit
import Foundation
import OSLog

/// 고유 시험 빌드에서만 활성화되는 진단. 경로/bytes 대신 opaque 요청 ID를 연결한다.
enum ExtensionFontPerformanceTrace {
    static let request = TaskLocal<String?>(wrappedValue: nil)
    static let observer = TaskLocal<(@Sendable (UInt64, UInt64, Bool) -> Void)?>(wrappedValue: nil)
    #if ALHANGEUL_FONT_EXTENSION_PROBE
    static let details = TaskLocal<(@Sendable (String, UInt64, UInt64, Bool, String?) -> Void)?>(wrappedValue: nil)
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.postmelee.alhangeul.FontSupply",
                                       category: "FontPerformance")
    static func interval(_ kind: String, start: UInt64, success: Bool, id: String? = request.get()) {
        let end = DispatchTime.now().uptimeNanoseconds
        if kind == "metadata" { observer.get()?(start, end, success) }
        details.get()?(kind, start, end, success, id)
        guard let id else { return }
        let milliseconds = Double(end - start) / 1_000_000
        logger.debug("FontPerformance request=\(id, privacy: .public) kind=\(kind, privacy: .public) startNanos=\(start, privacy: .public) endNanos=\(end, privacy: .public) ms=\(milliseconds, privacy: .public) success=\(success, privacy: .public)")
    }
    static func measure<T>(_ kind: String, _ operation: () async throws -> T) async rethrows -> T {
        let start = DispatchTime.now().uptimeNanoseconds
        var success = false
        defer { interval(kind, start: start, success: success) }
        let result = try await operation()
        success = true
        return result
    }
    static func busy(_ boundary: String) {
        interval("busy." + boundary, start: DispatchTime.now().uptimeNanoseconds, success: false)
    }
    #endif
}

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
        #if ALHANGEUL_FONT_EXTENSION_PROBE
        var prepared = false
        defer { ExtensionFontPerformanceTrace.interval("metadata", start: started, success: prepared) }
        #endif
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
        #if ALHANGEUL_FONT_EXTENSION_PROBE
        _ = try await ExtensionFontPerformanceTrace.measure("catalogRefresh") { try await catalog.refresh() }
        #else
        _ = try await catalog.refresh()
        #endif
        let provider = InstalledFontServiceProvider(factory: { catalog })
        #if ALHANGEUL_FONT_EXTENSION_PROBE
        let base = try await ExtensionFontPerformanceTrace.measure("supplyAssembly") {
            try await StudioFontSupply.using(installed: provider, library: { library }).snapshot()
        }
        #else
        let base = try await StudioFontSupply.using(installed: provider, library: { library }).snapshot()
        #endif
        do {
            let records = await catalog.snapshot().records
            let manifest = try await library.list()
            let fingerprint = try Self.fingerprint(root: root, records: records, manifest: manifest)
            guard try policyStore.read() == policy, try await base.current() else { throw StudioFontError.staleGeneration }
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000
            Self.logger.debug("Font metadata ready installedEnabled=\(policy.installedEnabled, privacy: .public) records=\(records.count, privacy: .public) managed=\(manifest.entries.count, privacy: .public) metadataMs=\(elapsed, privacy: .public)")
            #if ALHANGEUL_FONT_EXTENSION_PROBE
            prepared = true
            #endif
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
        #if ALHANGEUL_FONT_EXTENSION_PROBE
        let started = DispatchTime.now().uptimeNanoseconds
        var success = false
        defer { ExtensionFontPerformanceTrace.interval("sourceFingerprint", start: started, success: success) }
        #endif
        struct Item: Encodable { let id: String; let stamp: InstalledFontStamp? }
        // 실제 읽기는 FD+hash로 검증한다. 이 stat은 cache 무효화 신호일 뿐이다.
        let installed = records.map { Item(id: $0.id, stamp: try? InstalledFontSystem.statURL($0.sourceURL)) }
        let objects = manifest.entries.map { entry in
            Item(id: entry.object.sha256,
                stamp: try? InstalledFontSystem.statURL(root.appendingPathComponent("objects/" + entry.object.sha256 + ".font")))
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(installed + objects)
        #if ALHANGEUL_FONT_EXTENSION_PROBE
        success = true
        #endif
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
