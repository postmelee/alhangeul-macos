import CryptoKit
import Foundation
import OSLog

/// 고유 시험 빌드에서만 활성화되는 진단. 경로/bytes 대신 opaque 요청 ID를 연결한다.
enum ExtensionFontPerformanceTrace {
    static let request = TaskLocal<String?>(wrappedValue: nil)
    static let observer = TaskLocal<(@Sendable (UInt64, UInt64, Bool) -> Void)?>(wrappedValue: nil)
    #if ALHANGEUL_FONT_EXTENSION_PROBE
    static let details = TaskLocal<(@Sendable (String, UInt64, UInt64, Bool, String?) -> Void)?>(wrappedValue: nil)
    private static let synchronousKey = "com.postmelee.alhangeul.FontPerformance.synchronousContext"
    static var currentRequest: String? {
        if let synchronous = Thread.current.threadDictionary[synchronousKey] as? SynchronousContext {
            return synchronous.request
        }
        return request.get()
    }
    private final class SynchronousContext {
        let request: String?
        let details: (@Sendable (String, UInt64, UInt64, Bool, String?) -> Void)?
        init(request: String?, details: (@Sendable (String, UInt64, UInt64, Bool, String?) -> Void)?) {
            self.request = request; self.details = details
        }
    }
    /// 동기 경계에서는 최적화 빌드에서 crash가 재현된 TaskLocal push를 사용하지 않는다.
    /// 동기 operation 범위에만 두고 continuation을 resume하기 전에 원래 상태를 복원한다.
    static func withSynchronousContext<T>(request: String?,
        details: (@Sendable (String, UInt64, UInt64, Bool, String?) -> Void)?,
        operation: () throws -> T) rethrows -> T {
        let dictionary = Thread.current.threadDictionary
        let previous = dictionary[synchronousKey]
        dictionary[synchronousKey] = SynchronousContext(request: request, details: details)
        defer {
            if let previous { dictionary[synchronousKey] = previous }
            else { dictionary.removeObject(forKey: synchronousKey) }
        }
        return try operation()
    }
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.postmelee.alhangeul.FontSupply",
                                       category: "FontPerformance")
    static func interval(_ kind: String, start: UInt64, success: Bool, id: String? = request.get()) {
        let synchronous = Thread.current.threadDictionary[synchronousKey] as? SynchronousContext
        let id = synchronous == nil ? id : synchronous?.request
        let end = DispatchTime.now().uptimeNanoseconds
        if kind == "metadata" { observer.get()?(start, end, success) }
        let report = synchronous == nil ? details.get() : synchronous?.details
        report?(kind, start, end, success, id)
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
    private let changes: InstalledFontChangeEpoch
    private let observeChanges: Bool
    private var preparation: ExtensionInstalledFontPreparation?
    private var catalog: InstalledFontCatalogService?
    private var library: FontLibraryService?
    private var root: URL?

    init(resolveRoot: @escaping @Sendable () throws -> URL = { try FontLibraryLocation().resolve() },
         environment: InstalledFontEnvironment? = nil,
         changes: InstalledFontChangeEpoch = .init(), observeChanges: Bool = true) {
        self.resolveRoot = resolveRoot
        self.environment = environment ?? InstalledFontSystem(descriptorCache: .init(changes: changes)).environment
        self.changes = changes; self.observeChanges = observeChanges
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
                environment: environment, observeChanges: false)
            catalog = own; library = FontLibraryService(store: FontLibraryStore(rootURL: resolved), readOnly: true); root = resolved
            preparation = ExtensionInstalledFontPreparation(catalog: own, environment: environment,
                policyStore: .init(rootURL: resolved), changes: changes, observeChanges: observeChanges)
        }
        guard let root, let catalog, let library, let preparation else { throw StudioFontError.unavailable }
        let policyStore = FontConsumerPolicyStore(rootURL: root)
        let policy = try policyStore.read()
        // metadata 목록만 재사용하고 요청별 관리 snapshot/FD는 아래에서 따로 획득한다.
        #if ALHANGEUL_FONT_EXTENSION_PROBE
        let ticket = try await ExtensionFontPerformanceTrace.measure("catalogPreparation") { try await preparation.prepare(policy) }
        #else
        let ticket = try await preparation.prepare(policy)
        #endif
        try Task.checkCancellation()
        let provider = InstalledFontServiceProvider(factory: { catalog })
        #if ALHANGEUL_FONT_EXTENSION_PROBE
        let base = try await ExtensionFontPerformanceTrace.measure("supplyAssembly") {
            try await StudioFontSupply.using(installed: provider, library: { library }, preparedState: ticket.state).snapshot()
        }
        #else
        let base = try await StudioFontSupply.using(installed: provider, library: { library }, preparedState: ticket.state).snapshot()
        #endif
        do {
            let records = ticket.state.records
            let manifest = try await library.list()
            let fingerprint = try Self.fingerprint(root: root, manifest: manifest)
            let current: @Sendable () async throws -> Bool = {
                do {
                    guard try policyStore.read() == policy, try await preparation.current(ticket),
                          try await base.current() else { return false }
                    let latest = try await library.list()
                    return try Self.fingerprint(root: root, manifest: latest) == fingerprint
                } catch { return false }
            }
            guard try await current() else { throw StudioFontError.staleGeneration }
            try Task.checkCancellation()
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000
            Self.logger.debug("Font metadata ready installedEnabled=\(policy.installedEnabled, privacy: .public) records=\(records.count, privacy: .public) managed=\(manifest.entries.count, privacy: .public) metadataMs=\(elapsed, privacy: .public)")
            #if ALHANGEUL_FONT_EXTENSION_PROBE
            prepared = true
            #endif
            return .init(identity: base.identity + ":" + policy.revision.uuidString + ":" + ticket.identity + ":" + fingerprint,
                faces: base.faces, omitted: base.omitted, failure: base.failure,
                read: { id in
                    try Task.checkCancellation()
                    guard try await current() else { throw StudioFontError.staleGeneration }
                    let bytes = try await base.read(id)
                    try Task.checkCancellation()
                    guard try await current() else { throw StudioFontError.staleGeneration }
                    return bytes
                }, current: current, release: base.release)
        } catch {
            await base.release()
            throw error
        }
    }

    private static func fingerprint(root: URL, manifest: FontLibraryManifest) throws -> String {
        #if ALHANGEUL_FONT_EXTENSION_PROBE
        let started = DispatchTime.now().uptimeNanoseconds
        var success = false
        defer { ExtensionFontPerformanceTrace.interval("sourceFingerprint", start: started, success: success) }
        #endif
        struct Item: Encodable { let id: String; let stamp: InstalledFontStamp? }
        // 실제 읽기는 FD+hash로 검증한다. 이 stat은 cache 무효화 신호일 뿐이다.
        let objects = manifest.entries.map { entry in
            Item(id: entry.object.sha256,
                stamp: try? InstalledFontSystem.statURL(root.appendingPathComponent("objects/" + entry.object.sha256 + ".font")))
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(objects)
        #if ALHANGEUL_FONT_EXTENSION_PROBE
        success = true
        #endif
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
