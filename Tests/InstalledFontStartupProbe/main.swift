import Foundation

// 실제 CoreText 목록을 사용하되 경로/이름/bytes를 결과에 남기지 않는 시작 비용 조사.
private final class ProbeMeter: @unchecked Sendable {
    private let lock = NSLock()
    private var scans: [Double] = []
    private var reads = 0
    private var writes = 0
    func scan(_ ms: Double) { lock.lock(); defer { lock.unlock() }; scans.append(ms) }
    func read() { lock.lock(); defer { lock.unlock() }; reads += 1 }
    func write() { lock.lock(); defer { lock.unlock() }; writes += 1 }
    func snapshot() -> ([Double], Int, Int) {
        lock.lock(); defer { lock.unlock() }; return (scans, reads, writes)
    }
}

@main
struct InstalledFontStartupProbe {
    private static func now() -> UInt64 { DispatchTime.now().uptimeNanoseconds }
    private static func elapsed(_ start: UInt64) -> Double { Double(now() - start) / 1_000_000 }

    static func main() async throws {
        guard CommandLine.arguments.count == 3 else { throw InstalledFontFailure.notPrepared }
        let stateURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
        let meter = ProbeMeter(), system = InstalledFontSystem().environment
        let persistence = InstalledFontPersistence.file(at: stateURL)
        let existed = try persistence.load() != nil
        let environment = InstalledFontEnvironment(scan: { grants in
            let start = now()
            defer { meter.scan(elapsed(start)) }
            return try system.scan(grants)
        }, read: { record, grants in
            meter.read(); return try await system.read(record, grants)
        }, makeBookmark: system.makeBookmark)
        let measuredPersistence = InstalledFontPersistence(load: persistence.load, save: { data in
            meter.write(); try persistence.save(data)
        })
        let start = now()
        let provider = InstalledFontServiceProvider(factory: {
            try await Task.detached {
                try InstalledFontCatalogService(persistence: measuredPersistence,
                    environment: environment, observeChanges: false)
            }.value
        })
        let catalog = try await provider.service()
        let serviceMS = elapsed(start), prepareStart = now()
        let ready = try await catalog.prepare()
        let prepareMS = elapsed(prepareStart)
        // 제품의 시작 prepare 뒤 didBecomeActive 요청을 재현한다.
        await catalog.scheduleRefresh(retryPermissionFailures: true)
        let deadline = now() + 30_000_000_000
        while meter.snapshot().0.count < 2 {
            guard now() < deadline else { throw InstalledFontFailure.busy }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        let latest = await catalog.snapshot()
        let before = meter.snapshot().0.count, repeatedStart = now()
        for _ in 0..<20 { _ = try await catalog.prepare() }
        let repeatedMS = elapsed(repeatedStart), metrics = meter.snapshot()
        guard metrics.0.count == before, metrics.1 == 0, ready.records == latest.records else {
            throw InstalledFontFailure.changed
        }
        await catalog.stopMonitoring()
        let result: [String: Any] = [
            "restoredSavedMetadata": existed, "enabled": ready.enabled,
            "faceCount": ready.records.count, "familyCount": Set(ready.records.map(\.family)).count,
            "serviceLoadMS": serviceMS, "prepareMS": prepareMS,
            "metadataScanMS": metrics.0, "scanCountAfterActivation": metrics.0.count,
            "repeatPrepare20MS": repeatedMS, "repeatPrepareAdditionalScans": metrics.0.count - before,
            "directFontBytesReads": metrics.1, "metadataSaveCount": metrics.2,
            "savedJSONBytes": try persistence.load()?.count ?? 0,
            "metadataUnchangedAfterActivation": ready.records == latest.records
        ]
        try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]).write(to: outputURL)
        print("PASS: 실제 시작 catalog 준비·활성화·반복 준비 조사")
    }
}
