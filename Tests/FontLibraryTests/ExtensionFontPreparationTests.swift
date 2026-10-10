import CoreText
import Foundation
import XCTest

private enum PreparationTestFailure: Error { case deadline }

private final class PreparationScanGate: @unchecked Sendable {
    private let condition = NSCondition()
    private var opened = false
    private(set) var entered = false
    func wait() throws {
        condition.lock(); defer { condition.unlock() }
        entered = true; condition.broadcast()
        let deadline = Date().addingTimeInterval(5)
        while !opened { guard condition.wait(until: deadline) else { throw PreparationTestFailure.deadline } }
    }
    func open() { condition.lock(); opened = true; condition.broadcast(); condition.unlock() }
}

private final class PreparationTestState: @unchecked Sendable {
    private let lock = NSLock()
    var records: [InstalledFontRecord]
    var scanFailure: InstalledFontFailure?
    var signatureFailure: InstalledFontFailure?
    var readFailure: InstalledFontFailure?
    var scans = 0, reads = 0, activeScans = 0, maximumActiveScans = 0
    var gate: PreparationScanGate?
    var signatureReusable = true
    init(_ record: InstalledFontRecord) { records = [record] }
    func locked<T>(_ body: (PreparationTestState) throws -> T) rethrows -> T {
        lock.lock(); defer { lock.unlock() }; return try body(self)
    }
    static func descriptor(_ record: InstalledFontRecord) -> CTFontDescriptor {
        var attributes: [CFString: Any] = [kCTFontURLAttribute: record.sourceURL, kCTFontNameAttribute: record.postScriptName,
            kCTFontFamilyNameAttribute: record.family, kCTFontStyleNameAttribute: record.style,
            kCTFontTraitsAttribute: [kCTFontSymbolicTrait: NSNumber(value: record.traits)]]
        attributes[kCTFontVariationAttribute] = Dictionary(uniqueKeysWithValues: record.axes.map {
            (NSNumber(value: $0.identifier), NSNumber(value: $0.value))
        })
        return CTFontDescriptorCreateWithAttributes(attributes as CFDictionary)
    }
    func environment(signature: Bool = true) -> InstalledFontEnvironment {
        let activeSignature: (@Sendable () throws -> InstalledFontActiveSignature)?
        if signature {
            activeSignature = {
                let input = self.locked { ($0.records, $0.signatureFailure, $0.signatureReusable) }
                if let failure = input.1 { throw failure }
                let value = try InstalledFontActiveSignature.capture(input.0.map(Self.descriptor))
                return .init(digest: value.digest, reusable: value.reusable && input.2)
            }
        } else { activeSignature = nil }
        return .init(scan: { grants in
            guard grants.isEmpty else { throw InstalledFontFailure.permissionDenied }
            let input = self.locked { value -> ([InstalledFontRecord], PreparationScanGate?, InstalledFontFailure?) in
                value.scans += 1; value.activeScans += 1
                value.maximumActiveScans = max(value.maximumActiveScans, value.activeScans)
                return (value.records, value.gate, value.scanFailure)
            }
            defer { self.locked { $0.activeScans -= 1 } }
            try input.1?.wait() // 취소에 즉시 반응하지 않는 물리 scan을 재현한다.
            if let failure = input.2 { throw failure }
            let records = input.0.map { original -> InstalledFontRecord in
                var record = original
                do { record.stamp = try InstalledFontSystem.statURL(record.sourceURL); record.failure = nil }
                catch { record.stamp = nil; record.failure = InstalledFontSystem.failure(error) }
                return record
            }
            return .init(records: records, grantIssues: [])
        }, read: { record, _ in
            let failure = self.locked { $0.reads += 1; return $0.readFailure }
            if let failure { throw failure }
            guard try InstalledFontSystem.statURL(record.sourceURL) == record.stamp else { throw InstalledFontFailure.changed }
            let data = try Data(contentsOf: record.sourceURL)
            let inspected = try FontFileInspector().inspect(data, filename: record.sourceURL.lastPathComponent)
            guard let face = inspected.faces.first(where: { $0.postScriptName == record.postScriptName }) else {
                throw InstalledFontFailure.changed
            }
            return .init(data: data, face: face)
        }, makeBookmark: { _ in throw InstalledFontFailure.permissionDenied }, activeSignature: activeSignature)
    }
}

final class ExtensionFontPreparationTests: XCTestCase {
    private var root: URL!
    private var source: URL!
    private var state: PreparationTestState!
    private var changes: InstalledFontChangeEpoch!
    private var policy: FontConsumerPolicyStore { .init(rootURL: root) }

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        source = root.appendingPathComponent("installed.ttf")
        let fixtures = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Fixtures", withExtension: nil))
        try FileManager.default.copyItem(at: fixtures.appendingPathComponent("regular.ttf"), to: source)
        let face = try XCTUnwrap(FontFileInspector().inspect(Data(contentsOf: source), filename: "installed.ttf").faces.first)
        state = .init(.init(id: "fixture", sourceURL: source, postScriptName: face.postScriptName,
            family: face.familyName ?? "Test", fullName: face.fullName ?? "Test Regular", style: face.subfamilyName ?? "Regular",
            version: "1", traits: 0, axes: [], stamp: try InstalledFontSystem.statURL(source), failure: nil))
        changes = .init()
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }
    private func supply(signature: Bool = true) -> ExtensionFontSupply {
        let root = root!, environment = state.environment(signature: signature)
        return .init(resolveRoot: { root }, environment: environment, changes: changes, observeChanges: false)
    }
    private func coordinator(observe: Bool = false) throws -> ExtensionInstalledFontPreparation {
        let environment = state.environment()
        let catalog = try InstalledFontCatalogService(persistence: .init(load: { nil }, save: { _ in }),
            environment: environment, observeChanges: false)
        return .init(catalog: catalog, environment: environment, policyStore: policy, changes: changes, observeChanges: observe)
    }
    private func importManaged() async throws -> FontLibraryStore {
        let store = FontLibraryStore(rootURL: root)
        let imported = await store.importCandidates([.init(sourceURL: source)])
        XCTAssertEqual(imported.first?.status, .added)
        return store
    }
    private func assertCurrent(_ snapshot: StudioFontSupplySnapshot, _ expected: Bool,
                               file: StaticString = #filePath, line: UInt = #line) async throws {
        let value = try await snapshot.current(); XCTAssertEqual(value, expected, file: file, line: line)
    }
    private func waitFor(_ predicate: () async -> Bool) async throws {
        for _ in 0..<1_000 {
            if await predicate() { return }
            try await Task.sleep(nanoseconds: 2_000_000)
        }
        throw PreparationTestFailure.deadline
    }

    func testOnWarmAndConcurrentRequestsNormalizeOnlyOnceWithoutReadingBytes() async throws {
        try policy.publish(enabled: true)
        let supply = supply()
        let snapshots = try await withThrowingTaskGroup(of: StudioFontSupplySnapshot.self) { group in
            for _ in 0..<10 { group.addTask { try await supply.snapshot() } }
            var values: [StudioFontSupplySnapshot] = []
            for try await value in group { values.append(value) }; return values
        }
        XCTAssertEqual(state.locked { $0.scans }, 1)
        XCTAssertEqual(state.locked { $0.reads }, 0)
        XCTAssertEqual(Set(snapshots.map(\.identity)).count, 1)
        for snapshot in snapshots { try await assertCurrent(snapshot, true); await snapshot.release() }
        for _ in 0..<5 { let value = try await supply.snapshot(); await value.release() }
        XCTAssertEqual(state.locked { $0.scans }, 1)
    }

    func testOffSkipsInstalledPreparationAndEachRequestOwnsItsManagedLease() async throws {
        _ = try await importManaged(); try policy.publish(enabled: false)
        state.locked { $0.scanFailure = .permissionDenied; $0.signatureFailure = .permissionDenied }
        let supply = supply(), a = try await supply.snapshot(), b = try await supply.snapshot()
        XCTAssertFalse(a.faces.contains { $0.source == "installed" }); XCTAssertNil(a.failure)
        XCTAssertEqual(state.locked { $0.scans }, 0)
        let face = try XCTUnwrap(b.faces.first(where: { $0.source == "managed" && $0.limitation == nil }))
        await a.release()
        do { _ = try await a.read(face.id); XCTFail("released lease read") }
        catch { XCTAssertEqual(error as? FontLibraryError, .releasedSnapshot) }
        let actual = try await b.read(face.id)
        XCTAssertEqual(actual.data, try Data(contentsOf: source)); try await assertCurrent(b, true)
        await b.release()
        XCTAssertEqual(state.locked { $0.scans }, 0)
        XCTAssertEqual(state.locked { $0.reads }, 0)
    }

    func testOffOnOffOnStartsNewPreparationAndRejectsOldPolicy() async throws {
        let supply = supply(); try policy.publish(enabled: false)
        let off = try await supply.snapshot()
        try policy.publish(enabled: true); let on = try await supply.snapshot()
        try await assertCurrent(off, false); XCTAssertEqual(state.locked { $0.scans }, 1)
        try policy.publish(enabled: false); let nextOff = try await supply.snapshot()
        try await assertCurrent(on, false); XCTAssertFalse(nextOff.faces.contains { $0.source == "installed" })
        try policy.publish(enabled: true); let nextOn = try await supply.snapshot()
        XCTAssertEqual(state.locked { $0.scans }, 2); XCTAssertNotEqual(on.identity, nextOn.identity)
        for value in [off, on, nextOff, nextOn] { await value.release() }
    }

    func testMissedNotificationAdditionAndRemovalInvalidatePriorSnapshots() async throws {
        try policy.publish(enabled: true); let supply = supply(), original = try await supply.snapshot()
        let record = state.locked { $0.records[0] }
        state.locked { $0.records = [] }
        try await assertCurrent(original, false)
        let empty = try await supply.snapshot(); XCTAssertTrue(empty.faces.isEmpty)
        state.locked { $0.records = [record] }
        try await assertCurrent(empty, false)
        let restored = try await supply.snapshot(); XCTAssertNotEqual(restored.identity, original.identity)
        XCTAssertEqual(state.locked { $0.scans }, 3)
        for value in [original, empty, restored] { await value.release() }
    }

    func testSourceInodeCtimeAndPermissionChangesInvalidateAndRecover() async throws {
        try policy.publish(enabled: true); let supply = supply(), first = try await supply.snapshot()
        let bytes = try Data(contentsOf: source)
        try bytes.write(to: source, options: .atomic)
        try await assertCurrent(first, false)
        let replaced = try await supply.snapshot(); XCTAssertNotEqual(first.identity, replaced.identity)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: source.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: source.path) }
        try await assertCurrent(replaced, false)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: source.path)
        let recovered = try await supply.snapshot(); try await assertCurrent(recovered, true)
        XCTAssertNotEqual(replaced.identity, recovered.identity)
        for value in [first, replaced, recovered] { await value.release() }
    }

    func testSamePSFromNewOriginBecomesConflictAndRemovalRecovers() async throws {
        try policy.publish(enabled: true); let supply = supply(), first = try await supply.snapshot()
        let secondURL = root.appendingPathComponent("other-origin.ttf")
        try FileManager.default.copyItem(at: source, to: secondURL)
        let original = state.locked { $0.records[0] }
        let second = InstalledFontRecord(id: "other-origin", sourceURL: secondURL, postScriptName: original.postScriptName,
            family: original.family, fullName: original.fullName, style: original.style, version: original.version,
            traits: original.traits, axes: original.axes, stamp: try InstalledFontSystem.statURL(secondURL), failure: nil)
        state.locked { $0.records.append(second) }; try await assertCurrent(first, false)
        let conflict = try await supply.snapshot()
        XCTAssertEqual(conflict.faces.count, 2); XCTAssertTrue(conflict.faces.allSatisfy { $0.limitation == "conflict" })
        state.locked { $0.records = [original] }; try await assertCurrent(conflict, false)
        let recovered = try await supply.snapshot(); XCTAssertNil(recovered.faces.first?.limitation)
        XCTAssertEqual(state.locked { $0.scans }, 3)
        for value in [first, conflict, recovered] { await value.release() }
    }

    func testStyleTraitsAndVariationChangeRejectPriorStaticFace() async throws {
        try policy.publish(enabled: true); let supply = supply(), first = try await supply.snapshot()
        let original = state.locked { $0.records[0] }
        let changed = InstalledFontRecord(id: original.id, sourceURL: original.sourceURL, postScriptName: original.postScriptName,
            family: original.family, fullName: original.fullName, style: "Bold", version: original.version, traits: 2,
            axes: [.init(identifier: 0x77676874, minimum: 100, maximum: 900, defaultValue: 400, value: 700)],
            stamp: original.stamp, failure: nil)
        state.locked { $0.records = [changed] }; try await assertCurrent(first, false)
        let next = try await supply.snapshot()
        XCTAssertEqual(next.faces.first?.style, "Bold"); XCTAssertEqual(next.faces.first?.limitation, "unsupported")
        do { _ = try await first.read("installed:" + original.id); XCTFail("prior static face used") }
        catch { XCTAssertEqual(error as? StudioFontError, .staleGeneration) }
        XCTAssertEqual(state.locked { $0.reads }, 0); XCTAssertEqual(state.locked { $0.scans }, 2)
        await first.release(); await next.release()
    }

    func testSourceRemovalAndRecreationInvalidateMissingState() async throws {
        try policy.publish(enabled: true); let supply = supply(), first = try await supply.snapshot()
        let bytes = try Data(contentsOf: source); try FileManager.default.removeItem(at: source)
        try await assertCurrent(first, false)
        let missing = try await supply.snapshot(); XCTAssertEqual(missing.faces.first?.limitation, "missing")
        try bytes.write(to: source); try await assertCurrent(missing, false)
        let restored = try await supply.snapshot(); XCTAssertNil(restored.faces.first?.limitation)
        let face = try XCTUnwrap(restored.faces.first)
        let actual = try await restored.read(face.id); XCTAssertEqual(actual.data, bytes)
        for value in [first, missing, restored] { await value.release() }
    }

    func testReadPermissionFailureForcesRefreshEvenWhenActiveSignatureIsUnchanged() async throws {
        try policy.publish(enabled: true); let supply = supply(), first = try await supply.snapshot()
        let installed = try XCTUnwrap(first.faces.first(where: { $0.source == "installed" }))
        state.locked { $0.readFailure = .permissionDenied }
        do { _ = try await first.read(installed.id); XCTFail("denied read") }
        catch { XCTAssertEqual(error as? InstalledFontFailure, .permissionDenied) }
        state.locked { $0.readFailure = nil }
        let next = try await supply.snapshot(), bytes = try await next.read(installed.id)
        XCTAssertEqual(bytes.data, try Data(contentsOf: source)); XCTAssertEqual(state.locked { $0.scans }, 2)
        try await assertCurrent(first, false)
        await first.release(); await next.release()
    }

    func testSignatureAndScanFailureDoNotServePriorMetadataAndRecover() async throws {
        try policy.publish(enabled: true); let supply = supply(), first = try await supply.snapshot()
        state.locked { $0.signatureFailure = .permissionDenied }
        try await assertCurrent(first, false)
        do { _ = try await supply.snapshot(); XCTFail("signature failure ignored") } catch {}
        state.locked { $0.signatureFailure = nil; $0.scanFailure = .catalogLimit }
        do { _ = try await supply.snapshot(); XCTFail("scan failure ignored") }
        catch { XCTAssertEqual(error as? InstalledFontFailure, .catalogLimit) }
        state.locked { $0.scanFailure = nil }
        let recovered = try await supply.snapshot(); try await assertCurrent(recovered, true)
        XCTAssertNotEqual(recovered.identity, first.identity)
        await first.release(); await recovered.release()
    }

    func testUnknownSignatureFallsBackToFullVerification() async throws {
        try policy.publish(enabled: true); state.locked { $0.signatureReusable = false }
        let supply = supply(), first = try await supply.snapshot()
        let before = state.locked { $0.scans }
        try await assertCurrent(first, true)
        XCTAssertGreaterThan(state.locked { $0.scans }, before)
        await first.release()
        let legacy = self.supply(signature: false), a = try await legacy.snapshot()
        let count = state.locked { $0.scans }; try await assertCurrent(a, true)
        XCTAssertGreaterThan(state.locked { $0.scans }, count); await a.release()
    }

    func testEpochInvalidatesImmediatelyBeforeAnyActorDebounce() async throws {
        try policy.publish(enabled: true); let preparation = try coordinator(observe: true)
        let first = try await preparation.prepare(policy.read())
        let epoch = changes.current()
        NotificationCenter.default.post(name: Notification.Name(kCTFontManagerRegisteredFontsChangedNotification as String), object: nil)
        XCTAssertGreaterThan(changes.current(), epoch)
        let current = try await preparation.current(first); XCTAssertFalse(current)
        let next = try await preparation.prepare(policy.read())
        XCTAssertNotEqual(first.identity, next.identity); XCTAssertEqual(state.locked { $0.scans }, 2)
    }

    func testChangingSignatureDuringScanDiscardsMixedResult() async throws {
        try policy.publish(enabled: true); let preparation = try coordinator(), gate = PreparationScanGate()
        state.locked { $0.gate = gate }
        let requested = try policy.read(), task = Task { try await preparation.prepare(requested) }
        try await waitFor { self.state.locked { $0.activeScans == 1 } }
        state.locked { $0.records = []; $0.gate = nil }; gate.open()
        do { _ = try await task.value; XCTFail("mixed generation published") }
        catch { XCTAssertEqual(error as? StudioFontError, .staleGeneration) }
        let next = try await preparation.prepare(requested)
        XCTAssertTrue(next.state.records.isEmpty); XCTAssertEqual(state.locked { $0.scans }, 2)
    }

    func testEpochDuringScanDiscardsResultEvenWhenDescriptorsAreUnchanged() async throws {
        try policy.publish(enabled: true); let preparation = try coordinator(), gate = PreparationScanGate()
        state.locked { $0.gate = gate }
        let requested = try policy.read(), task = Task { try await preparation.prepare(requested) }
        try await waitFor { self.state.locked { $0.activeScans == 1 } }
        changes.invalidate(); state.locked { $0.gate = nil }; gate.open()
        do { _ = try await task.value; XCTFail("old epoch published") }
        catch { XCTAssertEqual(error as? StudioFontError, .staleGeneration) }
        _ = try await preparation.prepare(requested); XCTAssertEqual(state.locked { $0.scans }, 2)
    }

    func testOffDoesNotWaitForOldPhysicalScanAndOldResultCannotPublish() async throws {
        try policy.publish(enabled: true); let preparation = try coordinator(), gate = PreparationScanGate()
        state.locked { $0.gate = gate }
        let requested = try policy.read(), task = Task { try await preparation.prepare(requested) }
        try await waitFor { self.state.locked { $0.activeScans == 1 } }
        try policy.publish(enabled: false)
        let off = try await preparation.prepare(policy.read())
        XCTAssertFalse(off.state.enabled); XCTAssertTrue(off.state.records.isEmpty)
        XCTAssertEqual(state.locked { $0.activeScans }, 1)
        state.locked { $0.gate = nil }; gate.open()
        do { _ = try await task.value; XCTFail("old ON result published") }
        catch { XCTAssertEqual(error as? StudioFontError, .staleGeneration) }
        try policy.publish(enabled: true); _ = try await preparation.prepare(policy.read())
        XCTAssertEqual(state.locked { $0.scans }, 2)
    }

    func testOneCancelledWaiterDoesNotCancelSharedPreparation() async throws {
        try policy.publish(enabled: true); let preparation = try coordinator(), gate = PreparationScanGate()
        state.locked { $0.gate = gate }
        let requested = try policy.read(), a = Task { try await preparation.prepare(requested) }
        try await waitFor { self.state.locked { $0.activeScans == 1 } }
        let b = Task { try await preparation.prepare(requested) }
        try await waitFor { await preparation.pendingRequestCount() == 2 }
        a.cancel()
        do { _ = try await a.value; XCTFail("cancelled waiter succeeded") } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(state.locked { $0.activeScans }, 1)
        state.locked { $0.gate = nil }; gate.open()
        _ = try await b.value; XCTAssertEqual(state.locked { $0.scans }, 1)
    }

    func testAllCancelledWaitersRetainPhysicalSlotAndDoNotPublish() async throws {
        try policy.publish(enabled: true); let preparation = try coordinator(), gate = PreparationScanGate()
        state.locked { $0.gate = gate }
        let requested = try policy.read(), a = Task { try await preparation.prepare(requested) }
        try await waitFor { self.state.locked { $0.activeScans == 1 } }
        a.cancel()
        do { _ = try await a.value; XCTFail("cancelled waiter succeeded") } catch { XCTAssertTrue(error is CancellationError) }
        do { _ = try await preparation.prepare(requested); XCTFail("overlapped abandoned scan") }
        catch { XCTAssertEqual(error as? StudioFontError, .staleGeneration) }
        XCTAssertEqual(state.locked { $0.scans }, 1)
        state.locked { $0.gate = nil }; gate.open()
        try await waitFor { self.state.locked { $0.activeScans == 0 } }
        // worker 완료의 actor 전달까지 기다린다. 마지막 취소 작업은 절대로 known으로 게시하지 않는다.
        var recovered: ExtensionInstalledFontPreparation.Ticket?
        for _ in 0..<100 {
            do { recovered = try await preparation.prepare(requested); break }
            catch StudioFontError.staleGeneration { try await Task.sleep(nanoseconds: 2_000_000) }
        }
        XCTAssertNotNil(recovered); XCTAssertEqual(state.locked { $0.scans }, 2)
        XCTAssertEqual(state.locked { $0.maximumActiveScans }, 1)
    }

    func testNewSupplyRechecksCatalogWithoutReusingPreviousProcessState() async throws {
        try policy.publish(enabled: true)
        let a = try await supply().snapshot(); await a.release()
        let b = try await supply().snapshot(); await b.release()
        XCTAssertEqual(state.locked { $0.scans }, 2); XCTAssertNotEqual(a.identity, b.identity)
    }

    func testManagedRemovalAndRestorationInvalidateDespiteWarmInstalledCatalog() async throws {
        let store = try await importManaged(); try policy.publish(enabled: true)
        let supply = supply(), first = try await supply.snapshot(), manifest = try await store.list()
        let object = try XCTUnwrap(manifest.entries.first?.object.sha256)
        _ = try await store.remove(objectHash: object, expectedGeneration: manifest.generation)
        try await assertCurrent(first, false); await first.release()
        _ = try await store.recover()
        let imported = await store.importCandidates([.init(sourceURL: source)])
        XCTAssertEqual(imported.first?.status, .added)
        let restored = try await supply.snapshot(); XCTAssertNotEqual(first.identity, restored.identity)
        XCTAssertEqual(state.locked { $0.scans }, 1); await restored.release()
    }

    func testManifestChangesAtSameGenerationInvalidateMetadataAndReads() async throws {
        _ = try await importManaged(); try policy.publish(enabled: true)
        let supply = supply(), first = try await supply.snapshot()
        let file = root.appendingPathComponent("current.json"), original = try Data(contentsOf: file)
        var manifest = try XCTUnwrap(JSONSerialization.jsonObject(with: original) as? [String: Any])
        var entries = try XCTUnwrap(manifest["entries"] as? [[String: Any]])
        var faces = try XCTUnwrap(entries[0]["faces"] as? [[String: Any]])
        faces[0]["fullName"] = "Changed metadata at same generation"
        entries[0]["faces"] = faces; manifest["entries"] = entries
        try JSONSerialization.data(withJSONObject: manifest, options: [.sortedKeys]).write(to: file, options: .atomic)
        try await assertCurrent(first, false)
        let face = try XCTUnwrap(first.faces.first(where: { $0.source == "managed" }))
        do { _ = try await first.read(face.id); XCTFail("same-generation manifest mutation ignored") }
        catch { XCTAssertEqual(error as? StudioFontError, .staleGeneration) }
        try original.write(to: file, options: .atomic)
        let restored = try await supply.snapshot(); try await assertCurrent(restored, true)
        XCTAssertEqual(state.locked { $0.scans }, 1)
        await first.release(); await restored.release()
    }

    func testProductionSignaturePreservesDuplicatesTraitsVariationsAndActiveLimit() throws {
        let record = state.locked { $0.records[0] }, descriptor = PreparationTestState.descriptor(record)
        let first = try InstalledFontActiveSignature.capture([descriptor]); XCTAssertTrue(first.reusable)
        let duplicate = try InstalledFontActiveSignature.capture([descriptor, descriptor]); XCTAssertNotEqual(first, duplicate)
        let none = try InstalledFontActiveSignature.capture([]); XCTAssertNotEqual(first, none)
        var attributes = CTFontDescriptorCopyAttributes(descriptor) as! [CFString: Any]
        attributes[kCTFontVariationAttribute] = [NSNumber(value: 0x77676874): NSNumber(value: 700)]
        let axes = CTFontDescriptorCreateWithAttributes(attributes as CFDictionary)
        XCTAssertNotEqual(first, try InstalledFontActiveSignature.capture([axes]))
        attributes[kCTFontTraitsAttribute] = [kCTFontWeightTrait: NSNumber(value: 0.8)]
        let traits = CTFontDescriptorCreateWithAttributes(attributes as CFDictionary)
        XCTAssertNotEqual(try InstalledFontActiveSignature.capture([axes]), try InstalledFontActiveSignature.capture([traits]))
        XCTAssertEqual(try InstalledFontActiveSignature.capture([traits, axes]), try InstalledFontActiveSignature.capture([axes, traits]))
        attributes[kCTFontEnabledAttribute] = NSNumber(value: false)
        let disabled = CTFontDescriptorCreateWithAttributes(attributes as CFDictionary)
        XCTAssertEqual(none, try InstalledFontActiveSignature.capture(Array(repeating: disabled, count: 20_001)))
        XCTAssertThrowsError(try InstalledFontActiveSignature.capture(Array(repeating: descriptor, count: 20_001)))
        try FileManager.default.removeItem(at: source)
        let missing = try InstalledFontActiveSignature.capture([descriptor]); XCTAssertFalse(missing.reusable)
        XCTAssertNotEqual(first, missing)
    }
}
