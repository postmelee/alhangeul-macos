import Foundation
import XCTest

// 주입 callback의 상태는 다른 큐에서도 접근하므로 잠금으로 보호한다.
private final class AccessRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var opened: [URL] = []
    private var closed: [URL] = []
    func start(_ url: URL) -> Bool { lock.lock(); defer { lock.unlock() }; opened.append(url); return true }
    func stop(_ url: URL) { lock.lock(); defer { lock.unlock() }; closed.append(url) }
    var counts: (Int, Int) { lock.lock(); defer { lock.unlock() }; return (opened.count, closed.count) }
}

final class FontLibraryServiceTests: XCTestCase {
    private var temporary: URL!
    override func setUpWithError() throws {
        temporary = FileManager.default.temporaryDirectory.appendingPathComponent("font-service-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: temporary) }
    private func fixture() throws -> URL {
        try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Fixtures", withExtension: nil)).appendingPathComponent("regular.ttf")
    }
    func testFolderScopeHeldUntilBatchCompletesAndFailuresStayPerFile() async throws {
        let recorder = AccessRecorder()
        let store = FontLibraryStore(rootURL: temporary.appendingPathComponent("library"), fault: { _ in
            XCTAssertEqual(recorder.counts.0, 1)
            XCTAssertEqual(recorder.counts.1, 0)
        })
        let service = FontLibraryService(store: store, access: .init(start: { recorder.start($0) }, stop: { recorder.stop($0) }))
        let results = await service.importFonts(.init(candidates: [
            .init(sourceURL: try fixture()), .init(sourceURL: temporary.appendingPathComponent("missing.ttf"))],
            accessURLs: [temporary, temporary]))
        XCTAssertEqual(results.map(\.status), [.added, .readFailure])
        XCTAssertEqual(recorder.counts.0, 1)
        XCTAssertEqual(recorder.counts.1, 1)
    }
    func testFalseScopeStartStillAllowsAccessibleFilesAndIsNotStopped() async throws {
        let service = FontLibraryService(store: FontLibraryStore(rootURL: temporary.appendingPathComponent("library")),
            access: .init(start: { _ in false }, stop: { _ in XCTFail("획득하지 않은 scope 해제") }))
        let results = await service.importFonts(.init(candidates: [.init(sourceURL: try fixture())], accessURLs: [temporary]))
        XCTAssertEqual(results[0].status, .added)
        _ = try await service.prepare()
        let snapshot = try await service.acquireSnapshot()
        let resource = try XCTUnwrap(snapshot.resources.first)
        let bytes = try await service.readResource(resource.id, snapshot: snapshot)
        XCTAssertEqual(bytes, try Data(contentsOf: fixture()))
        _ = try await service.remove(objectHash: resource.object.sha256, expectedGeneration: snapshot.generation)
        try await service.releaseSnapshot(snapshot)
        let recovered = try await service.recover()
        XCTAssertEqual(recovered.removedObjects, 1)
    }
    func testBatchBudgetIsNotResetPerCandidate() async throws {
        var limits = FontImportLimits(); limits.maximumCandidates = 1
        let service = FontLibraryService(store: FontLibraryStore(rootURL: temporary, limits: limits))
        let source = try fixture()
        let results = await service.importFonts(.init(candidates: [.init(sourceURL: source), .init(sourceURL: source)], accessURLs: []))
        XCTAssertEqual(results.map(\.status), [.added, .unsupported])
    }
    func testCancellationReleasesScopeAfterCopyStops() async throws {
        let recorder = AccessRecorder()
        let entered = DispatchSemaphore(value: 0), resume = DispatchSemaphore(value: 0)
        let store = FontLibraryStore(rootURL: temporary, fault: { phase in
            if phase == .stageWritten {
                entered.signal()
                XCTAssertEqual(resume.wait(timeout: .now() + 5), .success)
            }
        })
        let service = FontLibraryService(store: store, access: .init(start: { recorder.start($0) }, stop: { recorder.stop($0) }))
        let source = try fixture(), scope = temporary!
        let task = Task { await service.importFonts(.init(candidates: [.init(sourceURL: source)], accessURLs: [scope])) }
        XCTAssertEqual(entered.wait(timeout: .now() + 5), .success)
        task.cancel()
        XCTAssertEqual(recorder.counts.1, 0)
        resume.signal()
        let results = await task.value
        XCTAssertEqual(results[0].status, .cancelled)
        XCTAssertEqual(recorder.counts.1, 1)
        let manifest = try await service.list()
        XCTAssertTrue(manifest.entries.isEmpty)
    }
    func testStorageFailurePreservesResultAndReleasesScope() async throws {
        let recorder = AccessRecorder()
        let store = FontLibraryStore(rootURL: temporary, fault: { _ in throw FontLibraryError.io(28) })
        let service = FontLibraryService(store: store, access: .init(start: { recorder.start($0) }, stop: { recorder.stop($0) }))
        let results = await service.importFonts(.init(candidates: [.init(sourceURL: try fixture())], accessURLs: [temporary]))
        XCTAssertEqual(results[0].status, .storageFailure)
        XCTAssertEqual(results[0].publication, .notPublished)
        XCTAssertEqual(recorder.counts.1, 1)
    }
}
