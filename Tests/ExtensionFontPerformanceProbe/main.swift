import Foundation
import CoreGraphics
import CryptoKit
import Darwin

enum PerformanceTrace {
    static let request = TaskLocal<String?>(wrappedValue: nil)
}
func uptime() -> UInt64 { DispatchTime.now().uptimeNanoseconds }
func errorIdentifier(_ error: Error) -> String {
    if let value = error as? StudioFontError { return value.rawValue }
    if ExtensionFontRenderer.isStaleOrCancelled(error) { return "staleOrCancelled" }
    return String(describing: type(of: error))
}
struct Span: Codable, Sendable {
    let request: String
    let kind: String
    let start: UInt64
    let end: UInt64
    let bytes: Int
    let success: Bool
    var milliseconds: Double { Double(end - start) / 1_000_000 }
}
final class PerformanceMeter: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Span] = []
    func record(_ kind: String, _ start: UInt64, bytes: Int = 0, success: Bool = true, request: String? = nil) {
        let span = Span(request: request ?? PerformanceTrace.request.get() ?? "background", kind: kind,
                        start: start, end: uptime(), bytes: bytes, success: success)
        lock.lock(); values.append(span); lock.unlock()
    }
    func spans(_ request: String) -> [Span] {
        lock.lock(); defer { lock.unlock() }
        return values.filter { $0.request == request }
    }
    func metadata(_ start: UInt64, _ end: UInt64, _ success: Bool) {
        let span = Span(request: PerformanceTrace.request.get() ?? "background", kind: "metadata",
                        start: start, end: end, bytes: 0, success: success)
        lock.lock(); values.append(span); lock.unlock()
    }
    func all() -> [Span] {
        lock.lock(); defer { lock.unlock() }; return values
    }
}
struct PerformanceSample: Codable, Sendable {
    let request: String
    let scenario: String
    let phase: String
    let file: String
    let width: Int
    let start: UInt64
    var end: UInt64 = 0
    var status = "success"
    var cache: String?
    var identity: String?
    var faces: [String] = []
    var faceCount: Int?
    var fallback: String?
    var renderMs: Double?
    var pages: Int?
    var spans: [Span] = []
    var totalMs: Double { Double(end - start) / 1_000_000 }
}
struct PerformanceResult: Encodable {
    let schema = 1
    let pid: Int32
    let mode: String
    let installedEnabled: Bool
    let repetition: Int
    let processBundledFontWarmup: Bool
    let scope = "unsigned direct common services; real CoreText scan, private store; no OS installation"
    let samples: [PerformanceSample]
    let events: [Span]
    let proofs: [String: Bool]
}
enum PerformanceFailure: Error { case invalid(String) }
actor PerformanceGate {
    private(set) var count = 0
    private var opened = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func wait() async {
        count += 1
        if !opened { await withCheckedContinuation { waiters.append($0) } }
    }
    func finish() { opened = true; waiters.forEach { $0.resume() }; waiters.removeAll() }
    func increment() { count += 1 }
}
func waitFor(_ gate: PerformanceGate, count: Int) async throws {
    for _ in 0..<500 {
        if await gate.count == count { return }
        try await Task.sleep(nanoseconds: 10_000_000)
    }
    throw PerformanceFailure.invalid("controlled gate deadline")
}
func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw PerformanceFailure.invalid(message) }
}
func thumbnail(_ cache: HwpThumbnailRenderCache, _ file: URL, width: Int) async throws -> HwpThumbnailRenderResult {
    let request = try HwpThumbnailRenderRequest(fileURL: file,
        maximumSize: CGSize(width: width, height: width), scale: 1)
    return try await withCheckedThrowingContinuation { continuation in
        cache.renderedPageResult(for: request) { continuation.resume(with: $0) }
    }
}

@main struct ExtensionFontPerformanceProbe {
    static func main() async throws {
        setbuf(stdout, nil)
        guard CommandLine.arguments.count == 6 else { throw PerformanceFailure.invalid("arguments") }
        let input = URL(fileURLWithPath: CommandLine.arguments[1])
        let output = URL(fileURLWithPath: CommandLine.arguments[2])
        let mode = CommandLine.arguments[3], enabled = CommandLine.arguments[4] == "on"
        let repetition = Int(CommandLine.arguments[5]) ?? 0
        let root = output.appendingPathComponent("library")
        let store = FontLibraryStore(rootURL: root)
        let imported = await store.importCandidates(["Regular", "Bold"].map {
            .init(sourceURL: input.appendingPathComponent("GowunBatang-\($0).ttf"))
        })
        try require(imported.count == 2 && imported.allSatisfy { $0.status == .added }, "private font import")
        let policy = FontConsumerPolicyStore(rootURL: root)
        try policy.publish(enabled: enabled)
        if mode != "snapshot" {
            let context = try HwpPreviewPDFRenderer.load(fileURL: input.appendingPathComponent("single.hwpx"))
            _ = try HwpPreviewPNGRenderer.render(context: context, mode: .coreGraphics, forceDefaultFonts: true)
        }
        let meter = PerformanceMeter(), live = InstalledFontSystem().environment
        let environment = InstalledFontEnvironment(scan: { grants in
            let start = uptime()
            do { let value = try live.scan(grants); meter.record("scan", start); return value }
            catch { meter.record("scan", start, success: false); throw error }
        }, read: { record, grants in
            let start = uptime()
            do { let value = try await live.read(record, grants); meter.record("installedRead", start, bytes: value.data.count); return value }
            catch { meter.record("installedRead", start, success: false); throw error }
        }, makeBookmark: live.makeBookmark)
        let supply = ExtensionFontSupply(resolveRoot: { root }, environment: environment)
        let tracked: ExtensionFontRenderer.Supply = {
            let start = uptime()
            let request = PerformanceTrace.request.get()
            let value: StudioFontSupplySnapshot
            do {
                value = try await ExtensionFontPerformanceTrace.request.withValue(PerformanceTrace.request.get()) {
                    try await ExtensionFontPerformanceTrace.observer.withValue({ meter.metadata($0, $1, $2) }) {
                        try await supply.snapshot()
                    }
                }
                meter.record("snapshotCall", start)
            }
            catch { meter.record("snapshotCall", start, success: false); throw error }
            return .init(identity: value.identity, faces: value.faces, omitted: value.omitted, failure: value.failure,
                read: { id in
                    let start = uptime()
                    do { let bytes = try await value.read(id); meter.record("read", start, bytes: bytes.data.count, request: request); return bytes }
                    catch { meter.record("read", start, success: false, request: request); throw error }
                }, current: value.current, release: { let start = uptime(); await value.release(); meter.record("release", start, request: request) })
        }
        var samples: [PerformanceSample] = [], proofs: [String: Bool] = [:]
        func save() throws {
            let result = PerformanceResult(pid: getpid(), mode: mode, installedEnabled: enabled,
                repetition: repetition, processBundledFontWarmup: mode != "snapshot",
                samples: samples, events: meter.all(), proofs: proofs)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(result).write(to: output.appendingPathComponent("result.json"), options: .atomic)
        }
        func finish(_ value: PerformanceSample) -> PerformanceSample {
            var result = value; result.end = uptime(); result.spans = meter.spans(value.request); return result
        }
        func runThumbnail(_ cache: HwpThumbnailRenderCache, file: URL, scenario: String,
                          phase: String, index: Int, width: Int = 256) async -> PerformanceSample {
            let id = "\(scenario)-\(file.lastPathComponent)-\(index)-\(width)"
            return await PerformanceTrace.request.withValue(id) {
                var row = PerformanceSample(request: id, scenario: scenario, phase: phase,
                    file: file.lastPathComponent, width: width, start: uptime())
                do {
                    let value = try await thumbnail(cache, file, width: width)
                    row.cache = value.cacheEvent.description; row.identity = value.page.diagnostics.fontIdentity
                    row.faces = value.page.diagnostics.fontFaces.sorted(); row.fallback = value.page.diagnostics.fontSupplyFailure
                    if value.cacheEvent == .miss { row.renderMs = value.page.diagnostics.durationMs.totalMs }
                } catch { row.status = errorIdentifier(error) }
                return finish(row)
            }
        }
        do {
            if mode == "snapshot" {
                for index in 0...10 {
                    let id = "snapshot-\(index)"
                    let row = try await PerformanceTrace.request.withValue(id) {
                        var row = PerformanceSample(request: id, scenario: "snapshot", phase: index == 0 ? "cold" : "warm", file: "none", width: 0, start: uptime())
                        let value = try await tracked(); row.identity = value.identity; row.faceCount = value.faces.count
                        try require(try await value.current(), "snapshot current")
                        await value.release(); return finish(row)
                    }
                    samples.append(row); try save()
                    try require(row.spans.filter { $0.kind == "scan" }.count == 1, "one real scan per snapshot")
                    try require(!row.spans.contains { $0.kind == "read" || $0.kind == "installedRead" }, "no bytes pre-read")
                }
                proofs["metadataOnly"] = true
            } else if mode == "consumers" {
                for name in ["single.hwp", "single.hwpx"] {
                    let cache = HwpThumbnailRenderCache(supply: tracked), file = input.appendingPathComponent(name)
                    for index in 0...10 {
                        let row = await runThumbnail(cache, file: file, scenario: "same", phase: index == 0 ? "cold" : "warm", index: index)
                        samples.append(row); try save()
                        try require(row.status == "success" && row.fallback == nil && row.faces == ["GowunBatang-Bold", "GowunBatang-Regular"], "exact managed R/B thumbnail")
                        try require(row.cache == (index == 0 ? "miss" : "exactHit"), "same bitmap cache")
                        try require(row.spans.filter { $0.kind == "read" }.count == (index == 0 ? 2 : 0), "miss two reads, hit no reads")
                        try require(row.spans.filter { $0.kind == "release" }.count == 1, "one thumbnail release")
                    }
                    for index in 1...10 {
                        let row = await runThumbnail(cache, file: file, scenario: "larger", phase: "warm", index: index, width: 128)
                        samples.append(row); try save()
                        try require(row.status == "success" && row.cache?.contains("larger") == true, "larger bitmap cache")
                        try require(!row.spans.contains { $0.kind == "read" }, "larger hit no reads")
                        try require(row.spans.filter { $0.kind == "release" }.count == 1, "larger hit release")
                    }
                }
                for concurrent in [false, true] {
                    let cache = HwpThumbnailRenderCache(supply: tracked)
                    for pass in 0..<3 {
                        for offset in stride(from: 0, to: 10, by: concurrent ? 4 : 1) {
                            let batch = offset..<min(10, offset + (concurrent ? 4 : 1))
                            let rows = await withTaskGroup(of: PerformanceSample.self, returning: [PerformanceSample].self) { group in
                                for index in batch {
                                    group.addTask { await runThumbnail(cache, file: input.appendingPathComponent("many-\(index).hwpx"), scenario: concurrent ? "many-concurrent" : "many-serial", phase: pass == 0 ? "cold" : "warm", index: pass) }
                                }
                                var values: [PerformanceSample] = []; for await row in group { values.append(row) }; return values
                            }
                            samples.append(contentsOf: rows.sorted { $0.request < $1.request }); try save()
                        }
                    }
                }
                for name in ["single.hwp", "single.hwpx", "two.hwpx"] {
                    let context = try HwpPreviewPDFRenderer.load(fileURL: input.appendingPathComponent(name))
                    try require(context.pageCount == (name == "two.hwpx" ? 2 : 1), "preview pageCount")
                    for index in 0...3 {
                        let id = "preview-\(name)-\(index)"
                        let row = await PerformanceTrace.request.withValue(id) {
                            var row = PerformanceSample(request: id, scenario: "preview", phase: index == 0 ? "cold" : "warm", file: name, width: 0, start: uptime())
                            do {
                                if context.pageCount == 1 {
                                    let value = try await ExtensionFontRenderer.png(context: context, mode: .coreGraphics, supply: tracked)
                                    row.faces = value.diagnostics.fontFaces.sorted(); row.fallback = value.diagnostics.fontSupplyFailure
                                } else {
                                    let value = try await ExtensionFontRenderer.pdf(context: context, supply: tracked)
                                    row.faces = Array(Set(value.pageDiagnostics.flatMap { $0.diagnostics.fontFaces })).sorted()
                                    row.fallback = value.pageDiagnostics.compactMap { $0.diagnostics.fontSupplyFailure }.first
                                }
                                row.pages = context.pageCount
                            } catch { row.status = errorIdentifier(error) }
                            return finish(row)
                        }
                        samples.append(row); try save()
                        try require(row.status == "success" && row.fallback == nil && row.faces.count == 2, "preview exact face")
                        try require(row.spans.filter { $0.kind == "release" }.count == 1, "one preview snapshot release")
                    }
                }
                proofs["exactManagedRegularBold"] = true; proofs["hitWithoutBytes"] = true
                proofs["singleSnapshotMultiPage"] = true
            } else if mode == "transitions" {
                let cache = HwpThumbnailRenderCache(supply: tracked), file = input.appendingPathComponent("single.hwpx")
                let first = await runThumbnail(cache, file: file, scenario: "change", phase: "before", index: 0)
                samples.append(first)
                try policy.publish(enabled: !enabled)
                let toggled = await runThumbnail(cache, file: file, scenario: "change", phase: "toggle", index: 1)
                samples.append(toggled)
                try require(toggled.status == "success" && toggled.cache == "miss" && toggled.identity != first.identity, "policy identity invalidated")
                let manifest = try await store.list()
                guard let entry = manifest.entries.first else { throw PerformanceFailure.invalid("managed entry") }
                let object = root.appendingPathComponent("objects/\(entry.object.sha256).font")
                let original = try Data(contentsOf: object)
                try FileManager.default.removeItem(at: object)
                let missing = await runThumbnail(cache, file: file, scenario: "change", phase: "missing", index: 2)
                samples.append(missing); try save()
                try require(missing.status == "success" && missing.fallback != nil && missing.faces.isEmpty, "missing object explicit fallback")
                try original.write(to: object, options: .atomic)
                let restored = await runThumbnail(cache, file: file, scenario: "change", phase: "restored", index: 3)
                samples.append(restored)
                try require(restored.status == "success" && restored.fallback == nil && restored.faces.count == 2 && restored.cache == "miss", "restored exact face")
                proofs["policyInvalidatesCache"] = true; proofs["missingFallbackNotCached"] = true; proofs["restoredExact"] = true
            } else if mode == "guards" {
                // 제어한 대기는 성능 samples에 포함하지 않는다. 실제 17번째 요청의 공급 진입을 검사한다.
                let admission = PerformanceGate(), admissionReleases = PerformanceGate()
                let limited = HwpThumbnailRenderCache(supply: {
                    await admission.wait()
                    return .init(identity: "controlled-admission", faces: [], omitted: 0, failure: nil,
                        read: { _ in throw StudioFontError.invalidRequest }, current: { false },
                        release: { await admissionReleases.increment() })
                })
                let file = input.appendingPathComponent("single.hwpx")
                let held = (0..<16).map { _ in Task { try await thumbnail(limited, file, width: 256) } }
                try await waitFor(admission, count: 16)
                do { _ = try await thumbnail(limited, file, width: 256); throw PerformanceFailure.invalid("17th admitted") }
                catch { try require((error as? StudioFontError) == .busy, "17th busy") }
                try require(await admission.count == 16, "17th never entered supply")
                await admission.finish()
                for task in held {
                    do { _ = try await task.value; throw PerformanceFailure.invalid("stale returned") }
                    catch { try require(ExtensionFontRenderer.isStaleOrCancelled(error), "stale admission completion") }
                }
                try require(await admissionReleases.count == 16, "16 admitted snapshots released")
                proofs["admission16BeforeSupply"] = true

                let context = try HwpPreviewPDFRenderer.load(fileURL: file)
                let cancelGate = PerformanceGate(), cancelReleases = PerformanceGate()
                let cancelled = Task {
                    try await ExtensionFontRenderer.png(context: context, mode: .coreGraphics, supply: {
                        let snapshot = try await tracked()
                        return .init(identity: snapshot.identity, faces: snapshot.faces, omitted: snapshot.omitted, failure: snapshot.failure,
                            read: { id in await cancelGate.wait(); try Task.checkCancellation(); return try await snapshot.read(id) },
                            current: snapshot.current, release: { await snapshot.release(); await cancelReleases.increment() })
                    })
                }
                try await waitFor(cancelGate, count: 1)
                cancelled.cancel(); await cancelGate.finish()
                do { _ = try await cancelled.value; throw PerformanceFailure.invalid("cancelled PNG returned") }
                catch { try require(ExtensionFontRenderer.isStaleOrCancelled(error), "cancelled result preserved") }
                try require(await cancelReleases.count == 1, "cancelled snapshot released")
                proofs["cancelledPreviewReleased"] = true

                // OFL 원본의 격리 복사본에 padding만 추가해 같은 이름/스타일의 다른 객체를 만든다.
                let before = try await tracked()
                var bytes = try Data(contentsOf: input.appendingPathComponent("GowunBatang-Regular.ttf")); bytes.append(0)
                let variant = output.appendingPathComponent("padding-variant.ttf"); try bytes.write(to: variant)
                let imported = await store.importCandidates([.init(sourceURL: variant)])
                try require(imported.first?.status == .selectionRequired, "same-name conflict prepared")
                let manifest = try await store.list()
                guard let group = manifest.conflictGroups.first(where: { $0.members.count == 2 }),
                      let alternate = group.members.first(where: { $0.objectHash == imported.first?.objectHash }) else {
                    throw PerformanceFailure.invalid("alternate selection")
                }
                _ = try await store.selectActive(groupID: group.id, faceID: alternate, expectedGeneration: manifest.generation)
                try require(try await !before.current(), "selection stales prior snapshot")
                await before.release()
                let selected = try await tracked()
                try require(selected.identity != before.identity, "selection changes identity")
                guard let face = selected.faces.first(where: { $0.postScriptName == "GowunBatang-Regular" && $0.source == "managed" && $0.limitation == nil }) else {
                    throw PerformanceFailure.invalid("selected Regular")
                }
                let actual = try await selected.read(face.id)
                try require(actual.face.id == alternate && actual.data == bytes, "selected exact bytes")
                await selected.release()
                proofs["selectionChangesIdentityAndExactBytes"] = true
            } else { throw PerformanceFailure.invalid("mode") }
            try save(); print("PASS", mode, enabled ? "on" : "off", samples.count, "samples")
        } catch { try save(); throw error }
    }
}
