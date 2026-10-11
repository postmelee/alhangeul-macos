import Darwin
import Foundation
import XCTest

final class FontLibraryStoreTests: XCTestCase {
    private var temporary: URL!
    override func setUpWithError() throws {
        temporary = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("font-library-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: temporary)
    }
    private var root: URL { temporary.appendingPathComponent("library", isDirectory: true) }
    private func fixture(_ name: String) throws -> URL {
        try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Fixtures", withExtension: nil)).appendingPathComponent(name)
    }
    private func input(_ name: String) throws -> FontImportCandidate { .init(sourceURL: try fixture(name)) }
    private func bytes(_ name: String) throws -> Data { try Data(contentsOf: fixture(name)) }
    private func objectURL(_ hash: String) -> URL { root.appendingPathComponent("objects/\(hash).font") }
    private func manifestURL() -> URL { root.appendingPathComponent("current.json") }

    func testIndependentCopyDuplicateAndRestart() async throws {
        let source = temporary.appendingPathComponent("source.ttf")
        try bytes("regular.ttf").write(to: source)
        let store = FontLibraryStore(rootURL: root)
        let first = await store.importCandidates([.init(sourceURL: source)])
        XCTAssertEqual(first[0].status, .added)
        XCTAssertEqual(first[0].publication, .durable)
        let hash = try XCTUnwrap(first[0].objectHash)
        XCTAssertEqual(try Data(contentsOf: objectURL(hash)), try bytes("regular.ttf"))
        let before = try await store.list()
        let duplicate = await store.importCandidates([.init(sourceURL: source)])
        XCTAssertEqual(duplicate[0].status, .alreadyPresent)
        let actual1 = try await store.list()
        XCTAssertEqual(actual1, before)
        try FileManager.default.removeItem(at: source)
        let actual2 = try await FontLibraryStore(rootURL: root).list()
        XCTAssertEqual(actual2, before)
        XCTAssertEqual(try Data(contentsOf: objectURL(hash)), try bytes("regular.ttf"))
    }

    func testConflictKeepsCurrentSelectionAndVersionNeverAutoReplaces() async throws {
        let store = FontLibraryStore(rootURL: root)
        _ = await store.importCandidates([try input("regular.ttf")])
        let before = try await store.list()
        // 마지막 padding 변경은 이름과 스타일을 유지하면서 hash만 다른 파일을 만든다.
        var changed = try bytes("regular.ttf")
        changed.append(0)
        let source = temporary.appendingPathComponent("another-version.ttf")
        try changed.write(to: source)
        let result = await store.importCandidates([.init(sourceURL: source), try input("bold.ttf")])
        XCTAssertEqual(result.map(\.status), [.selectionRequired, .added])
        let after = try await store.list()
        XCTAssertEqual(after.entries.count, 3)
        XCTAssertEqual(after.activeSelections.first, before.activeSelections.first)
        XCTAssertEqual(after.activeSelections.count, 2)
        XCTAssertEqual(after.conflictGroups.filter { $0.members.count == 2 }.count, 1)
        let group = try XCTUnwrap(after.conflictGroups.first { $0.members.count == 2 })
        let selected = try await store.selectActive(groupID: group.id, faceID: group.members[1], expectedGeneration: after.generation)
        XCTAssertEqual(selected.activeSelections.first { $0.conflictGroupID == group.id }?.faceID, group.members[1])
        do {
            _ = try await store.selectActive(groupID: group.id, faceID: group.members[0], expectedGeneration: after.generation)
            XCTFail("오래된 선택 요청은 거부해야 함")
        } catch { XCTAssertEqual(error as? FontLibraryError, .staleGeneration) }
    }

    func testLimitedFormatsAreStoredWithoutAutomaticActivation() async throws {
        let store = FontLibraryStore(rootURL: root)
        let result = await store.importCandidates([try input("two-face.ttc"), try input("variable.ttf")])
        XCTAssertEqual(result[0].status, .added)
        XCTAssertEqual(result[0].nextAction, .reviewSupportLimits)
        let manifest = try await store.list()
        XCTAssertEqual(manifest.entries.count, 2)
        XCTAssertTrue(manifest.activeSelections.isEmpty)
        let group = try XCTUnwrap(manifest.conflictGroups.first)
        do {
            _ = try await store.selectActive(groupID: group.id, faceID: group.members[0], expectedGeneration: manifest.generation)
            XCTFail("미검증 형식은 활성화하지 않음")
        } catch { XCTAssertEqual(error as? FontLibraryError, .unsupportedSelection) }
    }

    func testPartialFailureDoesNotRollbackValidFiles() async throws {
        let invalid = temporary.appendingPathComponent("corrupt.ttf")
        try Data([0, 1]).write(to: invalid)
        let store = FontLibraryStore(rootURL: root)
        let results = await store.importCandidates([try input("regular.ttf"), .init(sourceURL: invalid),
                                                   .init(sourceURL: temporary.appendingPathComponent("missing")), try input("bold.ttf")])
        XCTAssertEqual(results.map(\.status), [.added, .corrupt, .readFailure, .added])
        let actual3 = try await store.list().entries.count
        XCTAssertEqual(actual3, 2)
    }

    func testCandidateFileAndBatchLimits() async throws {
        let candidate = try input("regular.ttf")
        var limits = FontImportLimits()
        limits.maximumFileBytes = try bytes("regular.ttf").count - 1
        let tooLarge = await FontLibraryStore(rootURL: root, limits: limits).importCandidates([candidate])
        XCTAssertEqual(tooLarge[0].reasonCode, "inputLimitExceeded")
        limits.maximumFileBytes += 1
        limits.maximumBatchBytes = limits.maximumFileBytes
        let store = FontLibraryStore(rootURL: root, limits: limits)
        let batch = await store.importCandidates([candidate, candidate])
        XCTAssertEqual(batch.map(\.status), [.added, .unsupported])
        limits.maximumCandidates = 1
        limits.maximumBatchBytes *= 2
        let count = await FontLibraryStore(rootURL: root, limits: limits).importCandidates([candidate, candidate])
        XCTAssertEqual(count.map(\.status), [.alreadyPresent, .unsupported])
    }

    func testCorruptOrUnknownManifestIsNeverOverwritten() async throws {
        let store = FontLibraryStore(rootURL: root)
        _ = try await store.list()
        for data in [Data("broken".utf8), Data("{\"schemaVersion\":99}".utf8)] {
            try data.write(to: manifestURL())
            let results = await store.importCandidates([try input("regular.ttf")])
            XCTAssertEqual(results[0].status, .storageFailure)
            XCTAssertEqual(try Data(contentsOf: manifestURL()), data)
        }
    }

    func testMissingManifestCannotResetExistingLibrary() async throws {
        let store = FontLibraryStore(rootURL: root)
        _ = await store.importCandidates([try input("regular.ttf")])
        try FileManager.default.removeItem(at: manifestURL())
        let result = await store.importCandidates([try input("bold.ttf")])
        XCTAssertEqual(result[0].reasonCode, "missingManifest")
        XCTAssertFalse(FileManager.default.fileExists(atPath: manifestURL().path))
    }

    func testTamperedObjectCannotBeReportedAsDuplicate() async throws {
        let store = FontLibraryStore(rootURL: root)
        let original = await store.importCandidates([try input("regular.ttf")])
        let hash = try XCTUnwrap(original[0].objectHash)
        try Data([1, 2, 3]).write(to: objectURL(hash))
        let duplicate = await store.importCandidates([try input("regular.ttf")])
        XCTAssertEqual(duplicate[0].status, .storageFailure)
        XCTAssertEqual(duplicate[0].reasonCode, "corruptObject")
        XCTAssertEqual(try Data(contentsOf: objectURL(hash)), Data([1, 2, 3]))
    }

    func testManagedSymlinkAndSourceFIFOAreRejected() async throws {
        let outside = temporary.appendingPathComponent("outside")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: root, withDestinationURL: outside)
        let result = await FontLibraryStore(rootURL: root).importCandidates([try input("regular.ttf")])
        XCTAssertEqual(result[0].status, .storageFailure)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: outside.path).isEmpty)
        let fifo = temporary.appendingPathComponent("fifo")
        XCTAssertEqual(mkfifo(fifo.path, 0o600), 0)
        let inputFailure = await FontLibraryStore(rootURL: outside).importCandidates([.init(sourceURL: fifo)])
        XCTAssertEqual(inputFailure[0].status, .readFailure)
    }

    func testWriteFailureBeforeCommitPreservesOldManifest() async throws {
        for phase in FontLibraryWritePhase.allCases where phase != .manifestReplaced && phase != .manifestDirectorySynced {
            let isolated = temporary.appendingPathComponent(phase.rawValue)
            let clean = FontLibraryStore(rootURL: isolated)
            let baseline = try await clean.list()
            let store = FontLibraryStore(rootURL: isolated, fault: { if $0 == phase { throw FontLibraryError.io(ENOSPC) } })
            let result = await store.importCandidates([try input("regular.ttf")])
            XCTAssertEqual(result[0].status, .storageFailure, phase.rawValue)
            XCTAssertEqual(result[0].publication, .notPublished, phase.rawValue)
            let actual4 = try await clean.list()
            XCTAssertEqual(actual4, baseline, phase.rawValue)
            let retried = await clean.importCandidates([try input("regular.ttf")])
            XCTAssertEqual(retried[0].status, .added, phase.rawValue)
        }
    }

    func testFailureAfterRenameReportsVisibleCommitAndRetryIsSafe() async throws {
        let store = FontLibraryStore(rootURL: root, fault: {
            if $0 == .manifestReplaced { throw FontLibraryError.io(EIO) }
        })
        let result = await store.importCandidates([try input("regular.ttf")])
        XCTAssertEqual(result[0].status, .storageFailure)
        XCTAssertEqual(result[0].publication, .visibleDurabilityUnconfirmed)
        let fresh = FontLibraryStore(rootURL: root)
        let actual5 = try await fresh.list().entries.count
        XCTAssertEqual(actual5, 1)
        let retry = await fresh.importCandidates([try input("regular.ttf")])
        XCTAssertEqual(retry[0].status, .alreadyPresent)
        XCTAssertEqual(retry[0].publication, .durable)
    }

    func testConcurrentStoreInstancesDoNotLoseUpdates() async throws {
        for attempt in 0..<20 {
            let isolated = temporary.appendingPathComponent("race-\(attempt)")
            let a = FontLibraryStore(rootURL: isolated), b = FontLibraryStore(rootURL: isolated)
            async let first = a.importCandidates([try input("regular.ttf")])
            async let second = b.importCandidates([try input("bold.ttf")])
            let results = try await (first, second)
            XCTAssertEqual(results.0[0].status, .added, String(describing: results.0))
            XCTAssertEqual(results.1[0].status, .added, String(describing: results.1))
            let actual6 = try await a.list().entries.count
            XCTAssertEqual(actual6, 2)
        }
    }
    func testSourceReplacementAfterInspectionCannotChangeStoredBytes() async throws {
        let source = temporary.appendingPathComponent("replace.ttf")
        let original = try bytes("regular.ttf")
        try original.write(to: source)
        let store = FontLibraryStore(rootURL: root, fault: {
            if $0 == .stagingCreated { try Data([1, 2]).write(to: source) }
        })
        let results = await store.importCandidates([.init(sourceURL: source)])
        XCTAssertEqual(results[0].status, .added)
        let hash = try XCTUnwrap(results[0].objectHash)
        XCTAssertEqual(try Data(contentsOf: objectURL(hash)), original)
    }

    func testManagedChildSymlinkCannotEscapeRoot() async throws {
        let store = FontLibraryStore(rootURL: root)
        _ = try await store.list()
        let outside = temporary.appendingPathComponent("external-objects")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: false)
        let objects = root.appendingPathComponent("objects")
        try FileManager.default.removeItem(at: objects)
        try FileManager.default.createSymbolicLink(at: objects, withDestinationURL: outside)
        let results = await store.importCandidates([try input("regular.ttf")])
        XCTAssertEqual(results[0].status, .storageFailure)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: outside.path).isEmpty)
    }

    func testCancellationPreservesPreviouslyCommittedItems() async throws {
        let gate = ImportGate()
        let store = FontLibraryStore(rootURL: root, fault: { phase in
            if phase == .stagingCreated { gate.visit() }
        })
        let candidates = [try input("regular.ttf"), try input("bold.ttf"), try input("regular.otf")]
        let task = Task { await store.importCandidates(candidates) }
        let deadline = Date().addingTimeInterval(5)
        while !gate.reached && Date() < deadline { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertTrue(gate.reached)
        task.cancel()
        gate.release.signal()
        let results = await task.value
        XCTAssertEqual(results.map(\.status), [.added, .cancelled, .cancelled])
        let manifest = try await store.list()
        XCTAssertEqual(manifest.entries.count, 1)
        XCTAssertEqual(manifest.entries[0].faces[0].postScriptName, "AlhangeulFixture-Regular")
    }
}

private final class ImportGate: @unchecked Sendable {
    let release = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var count = 0
    var reached: Bool { lock.lock(); defer { lock.unlock() }; return count >= 2 }
    func visit() {
        lock.lock(); count += 1; let shouldWait = count == 2; lock.unlock()
        if shouldWait { _ = release.wait(timeout: .now() + 5) }
    }
}
