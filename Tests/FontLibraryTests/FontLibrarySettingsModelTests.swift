import Foundation
import XCTest

private actor SettingsGate {
    private(set) var entered = false
    private var continuation: CheckedContinuation<Void, Never>?
    func wait() async { entered = true; await withCheckedContinuation { continuation = $0 } }
    func release() { continuation?.resume(); continuation = nil }
}

@MainActor
final class FontLibrarySettingsModelTests: XCTestCase {
    private var root: URL!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("font-settings-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }
    private func client() -> FontLibraryUIClient { .init(service: FontLibraryService(store: FontLibraryStore(rootURL: root))) }
    private func candidates() throws -> MacFontDiscoveryResult {
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Fixtures", withExtension: nil)).appendingPathComponent("regular.ttf")
        let source = MacFontSource(id: fixture.deletingLastPathComponent(), name: "테스트 글꼴", version: nil, kind: .userSelected)
        return .init(sources: [source], candidates: [
            .init(id: UUID(), url: fixture, byteCount: 1124, source: source),
            .init(id: UUID(), url: fixture, byteCount: 1124, source: source)])
    }
    private func waitFor(_ condition: () -> Bool) async throws {
        for _ in 0..<500 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("상태 전이 시간 초과")
    }
    private func waitForGate(_ gate: SettingsGate) async throws {
        for _ in 0..<500 {
            if await gate.entered { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("worker 진입 시간 초과")
    }
    func testPreparationFailureCanRetryWithoutShowingImport() async {
        var failing = true
        let client = client()
        let model = FontLibrarySettingsModel(makeClient: {
            if failing { throw FontLibraryError.corruptManifest }
            return client
        })
        await model.prepare()
        XCTAssertFalse(model.ready)
        XCTAssertNotNil(model.message)
        model.beginImport()
        XCTAssertFalse(model.showingImport)
        failing = false
        await model.prepare()
        XCTAssertTrue(model.ready)
        XCTAssertNil(model.message)
    }
    func testSelectionPanelCancellationAndSingleBatchImport() async throws {
        let client = client(), found = try candidates()
        let model = FontLibrarySettingsModel(makeClient: { client }, discover: { _, _ in found })
        await model.prepare(); model.beginImport(); model.scan(.selected([]))
        try await waitFor { model.phase == .candidates }
        XCTAssertEqual(model.selected.count, 2)
        model.setSelected(found.candidates[0].id, false)
        model.selectedLocations(nil)
        XCTAssertEqual(model.selected.count, 1)
        model.selectAll(true)
        model.importSelected()
        model.importSelected() // 중복 클릭으로 두 배치가 게시되지 않아야 한다.
        try await waitFor { model.phase == .results }
        XCTAssertEqual(model.results.map(\.status), [.added, .alreadyPresent])
        XCTAssertEqual(model.manifest.entries.count, 1)
    }
    func testOneBatchPreservesTotalCandidateLimit() async throws {
        var limits = FontImportLimits(); limits.maximumCandidates = 1
        let client = FontLibraryUIClient(service: .init(store: .init(rootURL: root, limits: limits)))
        let found = try candidates()
        let model = FontLibrarySettingsModel(makeClient: { client }, discover: { _, _ in found })
        await model.prepare(); model.beginImport(); model.scan(.selected([]))
        try await waitFor { model.phase == .candidates }
        model.importSelected()
        try await waitFor { model.phase == .results }
        XCTAssertEqual(model.results.map(\.status), [.added, .unsupported])
    }
    func testDismissedScanCannotOverwriteNewSession() async throws {
        let gate = SettingsGate(), client = client(), found = try candidates()
        let model = FontLibrarySettingsModel(makeClient: { client }, discover: { _, _ in
            await gate.wait(); return found
        })
        await model.prepare(); model.beginImport(); model.scan(.selected([]))
        try await waitForGate(gate)
        model.scan(.selected([])) // busy이면 재시작하지 않는다.
        model.dismissImport(); model.beginImport()
        await gate.release()
        try await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertEqual(model.phase, .source)
        XCTAssertTrue(model.discovery.candidates.isEmpty)
        XCTAssertTrue(model.showingImport)
    }
    func testCancelledDiscoveryRetainsPartialCandidates() async throws {
        let client = client()
        var found = try candidates(); found.cancelled = true
        let partial = found
        let model = FontLibrarySettingsModel(makeClient: { client }, discover: { _, _ in partial })
        await model.prepare(); model.beginImport(); model.scan(.selected([]))
        try await waitFor { model.phase == .candidates }
        XCTAssertNotNil(model.message)
        XCTAssertEqual(model.selected.count, 2)
    }
    func testDismissDuringImportWaitsForWorkerAndRefreshesStoredResults() async throws {
        let gate = SettingsGate(), found = try candidates()
        let service = FontLibraryService(store: .init(rootURL: root))
        var client = FontLibraryUIClient(service: service)
        client.importFonts = { request in
            // 앞선 항목 게시 후 취소되는 부분 성공을 재현한다.
            let result = await service.importFonts(request)
            await gate.wait()
            return result
        }
        let injected = client
        let model = FontLibrarySettingsModel(makeClient: { injected }, discover: { _, _ in found })
        await model.prepare(); model.beginImport(); model.scan(.selected([]))
        try await waitFor { model.phase == .candidates }
        model.importSelected()
        try await waitForGate(gate)
        model.dismissImport()
        XCTAssertTrue(model.busy)
        model.beginImport()
        XCTAssertFalse(model.showingImport)
        await gate.release()
        try await waitFor { model.phase == .results }
        XCTAssertEqual(model.manifest.entries.count, 1)
        XCTAssertFalse(model.busy)
        XCTAssertFalse(model.cancelling)
    }
}
