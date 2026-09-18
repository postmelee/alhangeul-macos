import Darwin
import Foundation
import XCTest

final class FontLibrarySnapshotTests: XCTestCase {
    private var temporary: URL!
    private var root: URL { temporary.appendingPathComponent("library") }
    override func setUpWithError() throws {
        temporary = FileManager.default.temporaryDirectory.appendingPathComponent("font-snapshot-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: temporary) }
    private func fixture() throws -> URL {
        try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Fixtures", withExtension: nil)).appendingPathComponent("regular.ttf")
    }
    private func imported() async throws -> FontLibraryStore {
        let store = FontLibraryStore(rootURL: root)
        let result = await store.importCandidates([.init(sourceURL: try fixture())])
        XCTAssertEqual(result[0].status, .added)
        return store
    }

    func testDeletedSelectionRemainsReadableUntilReleaseAndReimportRestoresIt() async throws {
        let store = try await imported()
        let snapshot = try await store.acquireSnapshot()
        let resource = try XCTUnwrap(snapshot.resources.first)
        let removed = try await store.remove(objectHash: resource.object.sha256, expectedGeneration: snapshot.generation)
        XCTAssertEqual(removed.generation, snapshot.generation + 1)
        XCTAssertTrue(removed.entries.isEmpty)
        let fresh = try await store.acquireSnapshot()
        XCTAssertTrue(fresh.resources.isEmpty)
        let held = try await store.recover()
        XCTAssertEqual(held.removedObjects, 0)
        let bytes = try await store.readResource(resource.id, snapshot: snapshot)
        XCTAssertEqual(bytes, try Data(contentsOf: fixture()))
        try await store.releaseSnapshot(snapshot)
        do { _ = try await store.readResource(resource.id, snapshot: snapshot); XCTFail("해제 후 읽기") }
        catch { XCTAssertEqual(error as? FontLibraryError, .releasedSnapshot) }
        try await store.releaseSnapshot(snapshot)
        let collected = try await store.recover()
        XCTAssertEqual(collected.removedObjects, 1)
        let reimport = await store.importCandidates([.init(sourceURL: try fixture())])
        XCTAssertEqual(reimport[0].status, .added)
        let restored = try await store.acquireSnapshot()
        XCTAssertEqual(restored.resources, snapshot.resources)
        XCTAssertEqual(restored.digest, snapshot.digest, "generation/session/source receipt는 선택 digest에 포함하지 않음")
        try await store.releaseSnapshot(fresh)
        try await store.releaseSnapshot(restored)
    }

    func testIndependentSnapshotHandlesAndAutomaticLifetimeRelease() async throws {
        let store = try await imported()
        var first: FontLibrarySnapshot? = try await store.acquireSnapshot()
        let second = try await store.acquireSnapshot()
        XCTAssertEqual(first?.digest, second.digest)
        let resource = try XCTUnwrap(second.resources.first)
        _ = try await store.remove(objectHash: resource.object.sha256, expectedGeneration: second.generation)
        first = nil
        let held = try await store.recover()
        XCTAssertEqual(held.removedObjects, 0)
        XCTAssertEqual(held.removedLeases, 1)
        try await store.releaseSnapshot(second)
        let collected = try await store.recover()
        XCTAssertEqual(collected.removedObjects, 1)
    }

    func testInvalidResourceOtherLibraryAndTamperedBytesAreRejected() async throws {
        let store = try await imported()
        let snapshot = try await store.acquireSnapshot()
        let resource = try XCTUnwrap(snapshot.resources.first)
        for id in ["../current.json", resource.id + "/../", ""] {
            do { _ = try await store.readResource(id, snapshot: snapshot); XCTFail("잘못된 ID") }
            catch { XCTAssertEqual(error as? FontLibraryError, .invalidResource) }
        }
        let other = FontLibraryStore(rootURL: temporary.appendingPathComponent("other"))
        do { _ = try await other.readResource(resource.id, snapshot: snapshot); XCTFail("다른 저장소") }
        catch { XCTAssertEqual(error as? FontLibraryError, .snapshotLibraryMismatch) }
        var bytes = try Data(contentsOf: fixture()); bytes[bytes.count - 1] ^= 1
        try bytes.write(to: root.appendingPathComponent("objects/\(resource.object.sha256).font"))
        do { _ = try await store.readResource(resource.id, snapshot: snapshot); XCTFail("변조") }
        catch { XCTAssertEqual(error as? FontLibraryError, .corruptObject) }
        do { _ = try await store.acquireSnapshot(); XCTFail("변조 snapshot") }
        catch { XCTAssertEqual(error as? FontLibraryError, .corruptObject) }
        do { _ = try await store.recover(); XCTFail("변조 복구") }
        catch { XCTAssertEqual(error as? FontLibraryError, .corruptObject) }
    }

    func testCorruptUnknownAndUnsafeLeasesDeferCollection() async throws {
        let store = try await imported()
        let snapshot = try await store.acquireSnapshot()
        let resource = try XCTUnwrap(snapshot.resources.first)
        _ = try await store.remove(objectHash: resource.object.sha256, expectedGeneration: snapshot.generation)
        try await store.releaseSnapshot(snapshot)
        let leaseDir = root.appendingPathComponent("leases")
        let name = UUID().uuidString + ".json"
        let bad = leaseDir.appendingPathComponent(name)
        for data in [Data("broken".utf8), try JSONEncoder().encode(FontLeaseRecord(
            schemaVersion: 2, sessionID: UUID(uuidString: String(name.dropLast(5)))!, objectHashes: []))] {
            try data.write(to: bad)
            let result = try await store.recover()
            XCTAssertTrue(result.collectionDeferred)
            XCTAssertEqual(result.removedObjects, 0)
        }
        try FileManager.default.removeItem(at: bad)
        XCTAssertEqual(symlink("/dev/null", bad.path), 0)
        let unsafe = try await store.recover()
        XCTAssertTrue(unsafe.collectionDeferred)
        XCTAssertEqual(unsafe.removedObjects, 0)
        try FileManager.default.removeItem(at: bad)
        let collected = try await store.recover()
        XCTAssertEqual(collected.removedObjects, 1)
    }

    func testMissingLeaseDirectoryFailsClosedWhileReaderLives() async throws {
        let store = try await imported()
        let snapshot = try await store.acquireSnapshot()
        let resource = try XCTUnwrap(snapshot.resources.first)
        _ = try await store.remove(objectHash: resource.object.sha256, expectedGeneration: snapshot.generation)
        try FileManager.default.moveItem(at: root.appendingPathComponent("leases"), to: root.appendingPathComponent("lost-leases"))
        do { _ = try await store.recover(); XCTFail("유실 lease 디렉터리") } catch {}
        let bytes = try await store.readResource(resource.id, snapshot: snapshot)
        XCTAssertEqual(bytes, try Data(contentsOf: fixture()))
    }

    func testOriginalPermissionLossAndDeletionDoNotAffectManagedReads() async throws {
        let source = temporary.appendingPathComponent("original.ttf")
        try FileManager.default.copyItem(at: fixture(), to: source)
        let store = FontLibraryStore(rootURL: root)
        _ = await store.importCandidates([.init(sourceURL: source)])
        XCTAssertEqual(chmod(source.path, 0), 0)
        let fresh = FontLibraryStore(rootURL: root)
        let snapshot = try await fresh.acquireSnapshot()
        let resource = try XCTUnwrap(snapshot.resources.first)
        let bytes = try await fresh.readResource(resource.id, snapshot: snapshot)
        XCTAssertEqual(bytes, try Data(contentsOf: fixture()))
        try FileManager.default.removeItem(at: source)
        let after = try await fresh.readResource(resource.id, snapshot: snapshot)
        XCTAssertEqual(bytes, after)
    }

    func testStaleRemovalAndReimportBeforeCollection() async throws {
        let store = try await imported()
        let manifest = try await store.list()
        let hash = try XCTUnwrap(manifest.entries.first?.object.sha256)
        do { _ = try await store.remove(objectHash: hash, expectedGeneration: 0); XCTFail("오래된 세대") }
        catch { XCTAssertEqual(error as? FontLibraryError, .staleGeneration) }
        _ = try await store.remove(objectHash: hash, expectedGeneration: manifest.generation)
        let result = await store.importCandidates([.init(sourceURL: try fixture())])
        XCTAssertEqual(result[0].status, .added)
        let recovery = try await store.recover()
        XCTAssertEqual(recovery.removedObjects, 0)
    }

    func testRecoveryCleansOnlyRecognizedAbandonedTransactions() async throws {
        let store = try await imported()
        let stage = root.appendingPathComponent("staging")
        let known = stage.appendingPathComponent(UUID().uuidString)
        let unknown = stage.appendingPathComponent(UUID().uuidString)
        for dir in [known, unknown] { try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: false) }
        try Data([1]).write(to: known.appendingPathComponent("object"))
        try Data([1]).write(to: unknown.appendingPathComponent("unexpected"))
        let result = try await store.recover()
        XCTAssertEqual(result.removedTransactions, 1)
        XCTAssertTrue(result.collectionDeferred)
        XCTAssertTrue(FileManager.default.fileExists(atPath: unknown.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: known.path))
    }
    func testUnreadableLeasePreservesObjectsWithoutProcessIdentityQueries() async throws {
        let store = try await imported()
        let snapshot = try await store.acquireSnapshot()
        let resource = try XCTUnwrap(snapshot.resources.first)
        _ = try await store.remove(objectHash: resource.object.sha256, expectedGeneration: snapshot.generation)
        try await store.releaseSnapshot(snapshot)
        let directory = root.appendingPathComponent("leases")
        let name = try XCTUnwrap(FileManager.default.contentsOfDirectory(atPath: directory.path).first)
        let lease = directory.appendingPathComponent(name)
        XCTAssertEqual(chmod(lease.path, 0), 0)
        defer { _ = chmod(lease.path, 0o600) }
        let denied = try await store.recover()
        XCTAssertTrue(denied.collectionDeferred)
        XCTAssertEqual(denied.removedObjects, 0)
        XCTAssertEqual(chmod(lease.path, 0o600), 0)
        let collected = try await store.recover()
        XCTAssertEqual(collected.removedObjects, 1)
    }

    func testRecoveryDoesNotCollectWhenManifestIsCorruptOrUnsupported() async throws {
        let store = try await imported()
        let manifest = try await store.list()
        let hash = try XCTUnwrap(manifest.entries.first?.object.sha256)
        _ = try await store.remove(objectHash: hash, expectedGeneration: manifest.generation)
        let current = root.appendingPathComponent("current.json")
        let valid = try Data(contentsOf: current)
        for invalid in [Data("broken".utf8), Data("{\"schemaVersion\":999}".utf8)] {
            try invalid.write(to: current)
            do { _ = try await store.recover(); XCTFail("손상 manifest 복구") } catch {}
            XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("objects/\(hash).font").path))
        }
        try valid.write(to: current)
        let collected = try await store.recover()
        XCTAssertEqual(collected.removedObjects, 1)
    }

}
