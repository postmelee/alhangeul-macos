import Foundation
import XCTest

final class FontConsumerPolicyTests: XCTestCase {
    private var root: URL!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }

    func testPrivateBookmarksNeverPublishedAndFailedSaveFailsClosed() throws {
        let store = FontConsumerPolicyStore(rootURL: root)
        let privateRoot = root.appendingPathComponent("private")
        let persistence = store.wrapping(.file(at: privateRoot))
        let state = InstalledFontSavedState(schema: 1, enabled: true, records: [],
            grants: [.init(id: UUID(), bookmark: Data("PRIVATE_BOOKMARK".utf8))])
        try persistence.save(JSONEncoder().encode(state))
        XCTAssertTrue(try store.read().installedEnabled)
        let shared = try String(contentsOf: root.appendingPathComponent("consumer-policy/policy.json"), encoding: .utf8)
        XCTAssertFalse(shared.contains("PRIVATE_BOOKMARK"))
        XCTAssertFalse(shared.contains("bookmark"))
        let original = try store.read()
        try store.publish(enabled: true)
        XCTAssertEqual(try store.read(), original)
        XCTAssertThrowsError(try store.publish(enabled: false) { throw StudioFontError.unavailable })
        XCTAssertThrowsError(try store.read())
        // private 저장 실패 후 기존 상태를 load해 설정을 복원한다.
        _ = try persistence.load()
        XCTAssertTrue(try store.read().installedEnabled)
        XCTAssertNotEqual(try store.read().revision, original.revision)
    }

    func testInterruptedPublicationAndCorruptPolicy() throws {
        let store = FontConsumerPolicyStore(rootURL: root)
        XCTAssertFalse(try store.read().installedEnabled)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("consumer-policy").path))
        try store.publish(enabled: false)
        try Data("crash".utf8).write(to: root.appendingPathComponent("consumer-policy/pending"))
        XCTAssertThrowsError(try store.read())
        try store.publish(enabled: false)
        XCTAssertFalse(try store.read().installedEnabled)
        try Data("bad".utf8).write(to: root.appendingPathComponent("consumer-policy/policy.json"))
        XCTAssertThrowsError(try store.read())
        try store.publish(enabled: true)
        XCTAssertTrue(try store.read().installedEnabled)
    }

    func testExtensionOwnCatalogHasNoHostGrantsAndInvalidatesPolicyAndObjectStamp() async throws {
        let store = FontLibraryStore(rootURL: root)
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Fixtures", withExtension: nil)).appendingPathComponent("regular.ttf")
        let imported = await store.importCandidates([.init(sourceURL: fixture)])
        XCTAssertEqual(imported.first?.status, .added)
        let policy = FontConsumerPolicyStore(rootURL: root)
        try policy.publish(enabled: true)
        let own = InstalledFontEnvironment(scan: { grants in
            guard grants.isEmpty else { throw InstalledFontFailure.permissionDenied }
            return .init(records: [], grantIssues: [])
        }, read: { _, _ in throw InstalledFontFailure.permissionDenied }, makeBookmark: { _ in
            throw InstalledFontFailure.permissionDenied
        })
        let isolatedRoot = root!
        let supply = ExtensionFontSupply(resolveRoot: { isolatedRoot }, environment: own)
        let first = try await supply.snapshot()
        let firstCurrent = try await first.current()
        XCTAssertTrue(firstCurrent)
        try policy.publish(enabled: false)
        let firstStale = try await first.current()
        XCTAssertFalse(firstStale)
        await first.release()
        let second = try await supply.snapshot()
        XCTAssertNotEqual(first.identity, second.identity)
        let row = try XCTUnwrap(second.faces.first(where: { $0.source == "managed" && $0.limitation == nil }))
        let bytes = try await second.read(row.id)
        XCTAssertEqual(bytes.data, try Data(contentsOf: fixture))
        let object = root.appendingPathComponent("objects/" + bytes.face.id.objectHash + ".font")
        try Data("changed".utf8).write(to: object, options: .atomic)
        let secondStale = try await second.current()
        XCTAssertFalse(secondStale)
        do { _ = try await second.read(row.id); XCTFail("변경된 원본을 읽음") } catch {}
        await second.release()
    }

    func testReadOnlyConsumerDoesNotCreateLeasesOrRequireWriteAccess() async throws {
        let writer = FontLibraryStore(rootURL: root)
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Fixtures", withExtension: nil)).appendingPathComponent("regular.ttf")
        _ = await writer.importCandidates([.init(sourceURL: fixture)])
        let policy = FontConsumerPolicyStore(rootURL: root)
        try policy.publish(enabled: true)
        let manifest = try await writer.list()
        let object = root.appendingPathComponent("objects/" + manifest.entries[0].object.sha256 + ".font")
        // 읽기 전용 소비자는 디스크 lease나 lock 파일을 새로 만들지 않는다.
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        let files = enumerator.allObjects.compactMap { $0 as? URL }
        let paths = files.map(\.path).sorted()
        for url in files + [root!] {
            let directory = (try url.resourceValues(forKeys: [.isDirectoryKey])).isDirectory == true
            try FileManager.default.setAttributes([.posixPermissions: directory ? 0o500 : 0o400], ofItemAtPath: url.path)
        }
        defer {
            for url in files + [root!] {
                try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
            }
        }
        XCTAssertTrue(try policy.read().installedEnabled)
        let consumer = FontLibraryService(store: FontLibraryStore(rootURL: root), readOnly: true)
        let actualManifest = try await consumer.list()
        XCTAssertEqual(actualManifest, manifest)
        // metadata 준비는 실제 object가 읽기 거부 상태여도 원본 bytes를 읽지 않는다.
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: object.path)
        let snapshot = try await consumer.acquireMetadataSnapshot()
        try FileManager.default.setAttributes([.posixPermissions: 0o400], ofItemAtPath: object.path)
        let bytes = try await consumer.readResource(snapshot.resources[0].id, snapshot: snapshot)
        XCTAssertEqual(bytes, try Data(contentsOf: fixture))
        let denied = await consumer.importFonts(.init(candidates: [.init(sourceURL: fixture)], accessURLs: []))
        XCTAssertEqual(denied.first?.reasonCode, "readOnlyConsumer")
        do { _ = try await consumer.recover(); XCTFail("읽기 전용 소비자의 GC") }
        catch { XCTAssertEqual(error as? FontLibraryError, .readOnlyConsumer) }
        try await consumer.releaseSnapshot(snapshot)
        do { _ = try await consumer.readResource(snapshot.resources[0].id, snapshot: snapshot); XCTFail("해제된 FD 사용") }
        catch { XCTAssertEqual(error as? FontLibraryError, .releasedSnapshot) }
        let after = try XCTUnwrap(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        XCTAssertEqual(after.allObjects.compactMap { ($0 as? URL)?.path }.sorted(), paths)
    }

    func testReadOnlySnapshotDiscardsRemovedSelectionWithoutBlockingWriter() async throws {
        let writer = FontLibraryStore(rootURL: root)
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Fixtures", withExtension: nil)).appendingPathComponent("regular.ttf")
        _ = await writer.importCandidates([.init(sourceURL: fixture)])
        let consumer = FontLibraryService(store: FontLibraryStore(rootURL: root), readOnly: true)
        let snapshot = try await consumer.acquireMetadataSnapshot()
        let resource = snapshot.resources[0]
        _ = try await writer.remove(objectHash: resource.object.sha256, expectedGeneration: snapshot.generation)
        _ = try await writer.recover()
        do { _ = try await consumer.readResource(resource.id, snapshot: snapshot); XCTFail("삭제 전 snapshot 사용") }
        catch { XCTAssertEqual(error as? FontLibraryError, .staleGeneration) }
        try await consumer.releaseSnapshot(snapshot)
    }

    func testReadOnlyEmptyLibraryDoesNotInitializeStorage() async throws {
        let consumer = FontLibraryService(store: FontLibraryStore(rootURL: root), readOnly: true)
        let manifest = try await consumer.list()
        XCTAssertTrue(manifest.entries.isEmpty)
        let snapshot = try await consumer.acquireMetadataSnapshot()
        XCTAssertTrue(snapshot.resources.isEmpty)
        try await consumer.releaseSnapshot(snapshot)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), [])
    }
}
