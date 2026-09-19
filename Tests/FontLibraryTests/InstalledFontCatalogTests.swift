import CoreText
import Foundation
import XCTest

private final class InstalledFontTestState: @unchecked Sendable {
    private let lock = NSLock()
    var records: [InstalledFontRecord] = []
    var stored: Data?
    var writesFail = false
    var reads = 0
    var readFailure: InstalledFontFailure?
    var scanFailure: InstalledFontFailure?
    var scanCount = 0
    var grantIssues: [InstalledFontGrantIssue] = []
    func locked<T>(_ body: (InstalledFontTestState) throws -> T) rethrows -> T {
        lock.lock(); defer { lock.unlock() }; return try body(self)
    }
    var persistence: InstalledFontPersistence {
        .init(load: { self.locked { $0.stored } }, save: { data in
            try self.locked { if $0.writesFail { throw InstalledFontFailure.storage }; $0.stored = data }
        })
    }
    func environment(_ result: InstalledFontRead, gate: InstalledFontTestGate? = nil) -> InstalledFontEnvironment {
        .init(scan: { _ in try self.locked {
            $0.scanCount += 1
            if let failure = $0.scanFailure { throw failure }
            return .init(records: $0.records, grantIssues: $0.grantIssues)
        } }, read: { _, _ in
            let failure = self.locked { $0.reads += 1; return $0.readFailure }
            if let gate { await gate.enter() }
            if let failure { throw failure }
            return result
        }, makeBookmark: { Data($0.path.utf8) })
    }
}

private actor InstalledFontTestGate {
    private var entered = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var release: CheckedContinuation<Void, Never>?
    func enter() async {
        entered = true
        waiters.forEach { $0.resume() }; waiters.removeAll()
        await withCheckedContinuation { release = $0 }
    }
    func waitForEntry() async {
        if entered { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func open() { release?.resume(); release = nil }
}

final class InstalledFontCatalogTests: XCTestCase {
    private func fixture() throws -> URL {
        try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Fixtures", withExtension: nil)).appendingPathComponent("regular.ttf")
    }
    private func result() throws -> InstalledFontRead {
        let url = try fixture(), data = try Data(contentsOf: url)
        return try .init(data: data, face: XCTUnwrap(FontFileInspector().inspect(data, filename: "regular.ttf").faces.first))
    }
    private func record(id: String = "face-1", revision: Int64 = 1) -> InstalledFontRecord {
        .init(id: id, sourceURL: URL(fileURLWithPath: "/fixture/\(id).ttf"), postScriptName: "Test-Regular",
              family: "Test", fullName: "Test Regular", style: "Regular", version: "1", traits: 0, axes: [],
              stamp: .init(device: 1, inode: 1, size: 100, modifiedSeconds: revision, modifiedNanos: 0, changedSeconds: revision, changedNanos: 0), failure: nil)
    }
    private func service(_ state: InstalledFontTestState, gate: InstalledFontTestGate? = nil) throws -> InstalledFontCatalogService {
        try .init(persistence: state.persistence, environment: state.environment(result(), gate: gate), observeChanges: false)
    }

    func testRelaunchRestoresSettingsButRechecksLiveCatalogBeforeServing() async throws {
        let state = InstalledFontTestState(); state.records = [record()]
        let first = try service(state)
        _ = try await first.prepare(); _ = try await first.setEnabled(true)
        let saved = try XCTUnwrap(state.stored)
        XCTAssertFalse(String(decoding: saved, as: UTF8.self).contains("base64"))
        let second = try service(state)
        var current = await second.snapshot()
        XCTAssertTrue(current.enabled); XCTAssertEqual(current.refreshFailure, .notPrepared)
        do { _ = try await second.readResource("face-1", expectedGeneration: current.generation); XCTFail() }
        catch { XCTAssertEqual(error as? InstalledFontFailure, .notPrepared) }
        state.locked { $0.records = [record(revision: 2)] }
        current = try await second.prepare()
        XCTAssertEqual(current.records[0].stamp?.modifiedSeconds, 2)
        XCTAssertEqual(state.reads, 0, "startup must not read all font bytes")
        _ = try await second.readResource("face-1", expectedGeneration: current.generation)
        XCTAssertEqual(state.reads, 1)
    }

    func testDifferentOriginsWithSamePSAreNotSilentlyCollapsed() async throws {
        let state = InstalledFontTestState(); state.records = [record(), record(id: "face-2")]
        let service = try service(state)
        _ = try await service.prepare(); let snapshot = try await service.setEnabled(true)
        XCTAssertEqual(snapshot.records.count, 2)
        XCTAssertTrue(snapshot.records.allSatisfy { $0.failure == .conflict })
        do { _ = try await service.readResource("face-1", expectedGeneration: snapshot.generation); XCTFail() }
        catch { XCTAssertEqual(error as? InstalledFontFailure, .conflict) }
        XCTAssertEqual(state.reads, 0)
    }

    func testRemovalAndUpdateInvalidateGeneration() async throws {
        let state = InstalledFontTestState(); state.records = [record()]
        let service = try service(state)
        _ = try await service.prepare(); let initial = try await service.setEnabled(true)
        state.locked { $0.records = [] }
        let removed = try await service.refresh()
        XCTAssertNotEqual(removed.generation, initial.generation)
        XCTAssertTrue(removed.records.isEmpty)
        do { _ = try await service.readResource("face-1", expectedGeneration: removed.generation); XCTFail() }
        catch { XCTAssertEqual(error as? InstalledFontFailure, .inactive) }
        state.locked { $0.records = [record(revision: 3)] }
        let updated = try await service.refresh()
        XCTAssertNil(updated.records.first?.failure)
        XCTAssertNotEqual(updated.generation, removed.generation)
        do { _ = try await service.readResource("face-1", expectedGeneration: initial.generation); XCTFail() }
        catch { XCTAssertEqual(error as? InstalledFontFailure, .staleGeneration) }
    }

    func testHistoricalCatalogAtCapacityIsPrunedAndPersistsAcrossRelaunch() async throws {
        let state = InstalledFontTestState()
        state.records = (0..<InstalledFontSystem.maximumRecords).map { record(id: "old-\($0)") }
        let catalog = try service(state)
        _ = try await catalog.prepare()
        let old = try await catalog.setEnabled(true)
        state.locked { $0.records = [record(id: "new-face")] }
        let current = try await catalog.refresh()
        XCTAssertEqual(current.records.map(\.id), ["new-face"])
        XCTAssertNil(current.refreshFailure)
        XCTAssertNotEqual(current.generation, old.generation)
        do { _ = try await catalog.readResource("old-0", expectedGeneration: old.generation); XCTFail() }
        catch { XCTAssertEqual(error as? InstalledFontFailure, .staleGeneration) }
        do { _ = try await catalog.readResource("old-0", expectedGeneration: current.generation); XCTFail() }
        catch { XCTAssertEqual(error as? InstalledFontFailure, .inactive) }
        _ = try await catalog.readResource("new-face", expectedGeneration: current.generation)
        let saved = try JSONDecoder().decode(InstalledFontSavedState.self, from: XCTUnwrap(state.stored))
        XCTAssertEqual(saved.records.map(\.id), ["new-face"])
        let relaunched = try service(state)
        let restored = try await relaunched.prepare()
        XCTAssertTrue(restored.enabled)
        XCTAssertEqual(restored.records.map(\.id), ["new-face"])
        _ = try await relaunched.readResource("new-face", expectedGeneration: restored.generation)
    }

    func testOverCapacityCatalogRecoversWhenCurrentScanReturnsWithinLimit() async throws {
        let state = InstalledFontTestState(); state.records = [record()]
        let catalog = try service(state)
        _ = try await catalog.prepare()
        let initial = try await catalog.setEnabled(true)
        state.locked { $0.records = (0...InstalledFontSystem.maximumRecords).map { record(id: "large-\($0)") } }
        do { _ = try await catalog.refresh(); XCTFail() }
        catch { XCTAssertEqual(error as? InstalledFontFailure, .catalogLimit) }
        let failed = await catalog.snapshot()
        XCTAssertEqual(failed.refreshFailure, .catalogLimit)
        do { _ = try await catalog.readResource("face-1", expectedGeneration: failed.generation); XCTFail() }
        catch { XCTAssertEqual(error as? InstalledFontFailure, .catalogLimit) }
        state.locked { $0.records = [record(id: "recovered-face")] }
        let recovered = try await catalog.refresh()
        XCTAssertNil(recovered.refreshFailure)
        XCTAssertEqual(recovered.records.map(\.id), ["recovered-face"])
        XCTAssertNotEqual(recovered.generation, initial.generation)
        _ = try await catalog.readResource("recovered-face", expectedGeneration: recovered.generation)
    }

    func testOldReadIsRejectedWhenDisabledWhileWorkerRuns() async throws {
        let state = InstalledFontTestState(); state.records = [record()]
        let gate = InstalledFontTestGate(), service = try service(state, gate: gate)
        _ = try await service.prepare(); let snapshot = try await service.setEnabled(true)
        let read = Task { try await service.readResource("face-1", expectedGeneration: snapshot.generation) }
        await gate.waitForEntry()
        let disabled = try await service.setEnabled(false)
        await gate.open()
        do { _ = try await read.value; XCTFail() }
        catch { XCTAssertEqual(error as? InstalledFontFailure, .staleGeneration) }
        XCTAssertFalse(disabled.enabled)
    }

    func testConcurrentReadsShareWorkerButDoNotPersistBytes() async throws {
        let state = InstalledFontTestState(); state.records = [record()]
        let gate = InstalledFontTestGate(), service = try service(state, gate: gate)
        _ = try await service.prepare(); let snapshot = try await service.setEnabled(true)
        let first = Task { try await service.readResource("face-1", expectedGeneration: snapshot.generation) }
        await gate.waitForEntry()
        let second = Task { try await service.readResource("face-1", expectedGeneration: snapshot.generation) }
        // Worker를 막아 같은 generation의 동시 요청을 겹치게 한다.
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(state.locked { $0.reads }, 1)
        await gate.open()
        let a = try await first.value, b = try await second.value
        XCTAssertEqual(a.data, b.data)
        XCTAssertEqual(state.reads, 1)
        let saved = try JSONDecoder().decode(InstalledFontSavedState.self, from: XCTUnwrap(state.stored))
        XCTAssertEqual(saved.records.count, 1); XCTAssertEqual(saved.grants.count, 0)
    }

    func testReadFailureInvalidatesAndRequiresExplicitRetry() async throws {
        let state = InstalledFontTestState(); state.records = [record()]; state.readFailure = .corrupt
        let service = try service(state)
        _ = try await service.prepare(); let snapshot = try await service.setEnabled(true)
        do { _ = try await service.readResource("face-1", expectedGeneration: snapshot.generation); XCTFail() }
        catch { XCTAssertEqual(error as? InstalledFontFailure, .corrupt) }
        let failed = try await service.refresh()
        XCTAssertEqual(failed.records[0].failure, .corrupt)
        XCTAssertNotEqual(failed.generation, snapshot.generation)
        state.locked { $0.readFailure = nil }
        let retry = try await service.refresh(retryIDs: ["face-1"])
        _ = try await service.readResource("face-1", expectedGeneration: retry.generation)
    }

    func testScanFailureBlocksOldSnapshotAndRecoveryRevalidates() async throws {
        let state = InstalledFontTestState(); state.records = [record()]
        let service = try service(state)
        _ = try await service.prepare(); let initial = try await service.setEnabled(true)
        state.locked { $0.scanFailure = .catalogLimit }
        do { _ = try await service.refresh(); XCTFail() } catch {}
        let failed = await service.snapshot()
        XCTAssertEqual(failed.refreshFailure, .catalogLimit)
        XCTAssertNotEqual(failed.generation, initial.generation)
        state.locked { $0.scanFailure = nil }
        let recovered = try await service.refresh()
        XCTAssertNil(recovered.refreshFailure)
    }

    func testStorageFailureDoesNotPretendSettingsWereSaved() async throws {
        let state = InstalledFontTestState(); let service = try service(state)
        _ = try await service.prepare()
        state.locked { $0.writesFail = true }
        do { _ = try await service.setEnabled(true); XCTFail() }
        catch { XCTAssertEqual(error as? InstalledFontFailure, .storage) }
        let snapshot = await service.snapshot()
        XCTAssertFalse(snapshot.enabled)
    }

    func testCorruptOrNewerStorageIsPreserved() throws {
        let state = InstalledFontTestState(); state.stored = Data("broken".utf8)
        XCTAssertThrowsError(try service(state))
        XCTAssertEqual(state.stored, Data("broken".utf8))
        state.stored = try JSONEncoder().encode(InstalledFontSavedState(schema: 99, enabled: true, records: [], grants: []))
        XCTAssertThrowsError(try service(state)) { XCTAssertEqual($0 as? InstalledFontFailure, .incompatibleStorage) }
    }

    func testPermissionBookmarksPersistReplaceAndRevoke() async throws {
        let state = InstalledFontTestState(); let service = try service(state)
        _ = try await service.prepare()
        _ = try await service.grantAccess(to: URL(fileURLWithPath: "/selected"))
        var saved = try JSONDecoder().decode(InstalledFontSavedState.self, from: XCTUnwrap(state.stored))
        let id = try XCTUnwrap(saved.grants.first?.id)
        _ = try await service.grantAccess(to: URL(fileURLWithPath: "/new-selection"), replacing: id)
        saved = try JSONDecoder().decode(InstalledFontSavedState.self, from: XCTUnwrap(state.stored))
        XCTAssertEqual(saved.grants.count, 1)
        XCTAssertEqual(saved.grants[0].bookmark, Data("/new-selection".utf8))
        _ = try await service.revokeAccess(id)
        saved = try JSONDecoder().decode(InstalledFontSavedState.self, from: XCTUnwrap(state.stored))
        XCTAssertTrue(saved.grants.isEmpty)
    }

    func testScopeBalanceAndStalePermissionsEvenWhenOperationFails() throws {
        let state = InstalledFontTestState()
        let access = InstalledFontPermissionAccess(resolve: { data in
            if data == Data([2]) { throw InstalledFontFailure.permissionUnresolvable }
            return (URL(fileURLWithPath: "/selected"), data == Data([1]))
        }, create: { _ in Data() }, scope: .init(start: { _ in state.locked { $0.reads += 1 }; return true },
                                              stop: { _ in state.locked { $0.scanCount += 1 } }))
        let grants = [0, 0, 1, 2].map { InstalledFontGrant(id: UUID(), bookmark: Data([UInt8($0)])) }
        XCTAssertThrowsError(try access.withAccess(grants) { issues in
            XCTAssertEqual(issues.map(\.failure), [.stalePermission, .permissionUnresolvable])
            XCTAssertEqual(state.reads, 1, "same scope is deduplicated")
            XCTAssertEqual(state.scanCount, 0, "scope remains open during operation")
            throw InstalledFontFailure.corrupt
        })
        XCTAssertEqual(state.scanCount, 1)
    }

    func testRealActiveFixtureReadRejectsChangedOriginalWithoutNotification() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("active.ttf")
        try FileManager.default.copyItem(at: fixture(), to: url)
        XCTAssertTrue(CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil))
        defer { CTFontManagerUnregisterFontsForURL(url as CFURL, .process, nil) }
        let system = InstalledFontSystem()
        let record = try XCTUnwrap(system.scan([]).records.first { $0.sourceURL == url })
        let result = try system.read(record, grants: [])
        XCTAssertEqual(result.face.postScriptName, record.postScriptName)
        try Data("replaced".utf8).write(to: url, options: .atomic)
        XCTAssertThrowsError(try system.read(record, grants: [])) {
            XCTAssertTrue([InstalledFontFailure.changed, .inactive].contains($0 as? InstalledFontFailure ?? .corrupt))
        }
    }

    func testNotificationBurstIsDebounced() async throws {
        let state = InstalledFontTestState(); state.records = [record()]
        let service = try service(state)
        _ = try await service.prepare()
        let before = state.scanCount
        for _ in 0..<20 { await service.scheduleRefresh() }
        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertEqual(state.locked { $0.scanCount }, before + 1)
        await service.stopMonitoring()
    }
    func testCoreTextNotificationInvalidatesAndStreamsNewGeneration() async throws {
        let state = InstalledFontTestState(); state.records = [record()]
        let service = try InstalledFontCatalogService(persistence: state.persistence,
            environment: state.environment(result()), observeChanges: true)
        _ = try await service.prepare()
        let stream = await service.updates()
        var iterator = stream.makeAsyncIterator()
        let initial = await iterator.next()
        state.locked { $0.records = [record(revision: 7)] }
        NotificationCenter.default.post(name: Notification.Name(kCTFontManagerRegisteredFontsChangedNotification as String), object: nil)
        try await Task.sleep(nanoseconds: 500_000_000)
        let snapshot = await service.snapshot()
        // 먼저 상태를 확인해 알림 누락 시 iterator를 무한 대기하지 않는다.
        guard snapshot.records.first?.stamp?.modifiedSeconds == 7 else {
            await service.stopMonitoring(); XCTFail("CoreText notification did not refresh"); return
        }
        let update = await iterator.next()
        XCTAssertNotEqual(initial?.generation, update?.generation)
        await service.stopMonitoring()
    }

    func testChangedGenerationRejectsInFlightBytes() async throws {
        let state = InstalledFontTestState(); state.records = [record()]
        let gate = InstalledFontTestGate(), service = try service(state, gate: gate)
        _ = try await service.prepare(); let initial = try await service.setEnabled(true)
        let worker = Task { try await service.readResource("face-1", expectedGeneration: initial.generation) }
        await gate.waitForEntry()
        state.locked { $0.records = [record(revision: 2)] }
        _ = try await service.refresh()
        await gate.open()
        do { _ = try await worker.value; XCTFail() }
        catch { XCTAssertEqual(error as? InstalledFontFailure, .staleGeneration) }
    }

}

extension InstalledFontCatalogTests {
    @MainActor
    func testSettingsUsesOrderedUpdatesAndCancelledSelectionPreservesPermission() async throws {
        let state = InstalledFontTestState(); state.records = [record()]
        let catalog = try service(state)
        let model = InstalledFontSettingsModel(makeService: { catalog })
        await model.prepare()
        await model.setEnabled(true)
        await model.selectLocation(nil)
        for _ in 0..<100 where model.snapshot?.enabled != true { await Task.yield() }
        XCTAssertEqual(model.snapshot?.enabled, true)
        XCTAssertNil(model.message)
        XCTAssertFalse(model.busy)
        let saved = try JSONDecoder().decode(InstalledFontSavedState.self, from: XCTUnwrap(state.stored))
        XCTAssertTrue(saved.enabled)
        XCTAssertTrue(saved.grants.isEmpty)
        XCTAssertEqual(state.reads, 0)
        // 외부 변경도 같은 stream 순서로 반영된다.
        _ = try await catalog.setEnabled(false)
        for _ in 0..<100 where model.snapshot?.enabled != false { await Task.yield() }
        XCTAssertEqual(model.snapshot?.enabled, false)
    }

    @MainActor
    func testSettingsSaveFailureDoesNotShowEnabledSuccess() async throws {
        let state = InstalledFontTestState(); state.records = [record()]
        let catalog = try service(state)
        let model = InstalledFontSettingsModel(makeService: { catalog })
        await model.prepare()
        state.locked { $0.writesFail = true }
        await model.setEnabled(true)
        for _ in 0..<100 where model.snapshot == nil { await Task.yield() }
        XCTAssertEqual(model.snapshot?.enabled, false)
        XCTAssertNotNil(model.message)
        state.locked { $0.writesFail = false }
        await model.setEnabled(true)
        for _ in 0..<100 where model.snapshot?.enabled != true { await Task.yield() }
        XCTAssertEqual(model.snapshot?.enabled, true)
        XCTAssertNil(model.message)
    }

    func testSupplyContractDoesNotExposeSourceOrPermission() throws {
        let source = record()
        let snapshot = InstalledFontSnapshot(generation: UUID(), enabled: true, records: [source],
            grantIssues: [.init(id: UUID(), failure: .stalePermission)], refreshFailure: nil, omittedFaceCount: 0)
        let data = try JSONEncoder().encode(InstalledFontSupplyCatalog(snapshot))
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(text.contains(source.sourceURL.path))
        XCTAssertFalse(text.contains("bookmark"))
        XCTAssertFalse(text.contains("sourceURL"))
        XCTAssertTrue(text.contains(source.id))
        XCTAssertTrue(text.contains(snapshot.generation.uuidString))
    }
}
