import Foundation
import XCTest
import WebKit

private actor StudioFontTestState {
    var valid = true
    var releases = 0
    var reads = 0
    func isCurrent() -> Bool { valid }
    func change() { valid = false }
    func release() { releases += 1 }
    func read() { reads += 1 }
}

@MainActor
final class StudioFontSessionTests: XCTestCase {
    private func bytes() throws -> StudioFontBytes {
        let folder = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Fixtures", withExtension: nil))
        let data = try Data(contentsOf: folder.appendingPathComponent("regular.ttf"))
        return try .init(data: data, face: XCTUnwrap(FontFileInspector().inspect(data, filename: "regular.ttf").faces.first))
    }
    private func make(state: StudioFontTestState = .init(), budget: StudioFontTransferBudget = .init(),
                      now: @escaping () -> Date = Date.init) throws -> StudioFontSession {
        let bytes = try bytes()
        let face = StudioFontFace(id: "test", source: "managed", postScriptName: bytes.face.postScriptName,
            family: "Test", fullName: "Test Regular", style: "Regular", aliases: ["Test"], weight: 400, traits: 0, limitation: nil)
        return StudioFontSession(supply: .init(snapshot: {
            .init(identity: "one", faces: [face], omitted: 0, failure: nil,
                read: { _ in await state.read(); return bytes }, current: { await state.isCurrent() },
                release: { await state.release() })
        }), budget: budget, now: now)
    }
    private func message(_ operation: String, _ handshake: [String: Any], _ extra: [String: Any] = [:]) -> [String: Any] {
        var result = handshake; result["op"] = operation
        result.merge(extra) { _, new in new }; return result
    }
    private func handshake(_ session: StudioFontSession) async throws -> [String: Any] {
        try await session.handle(["version": 1, "op": "handshake"])
    }
    private func rejects(_ expected: StudioFontError, _ body: () async throws -> Void) async {
        do { try await body(); XCTFail("expected \(expected)") }
        catch let error as StudioFontError { XCTAssertEqual(error.rawValue, expected.rawValue) }
        catch { XCTFail("unexpected \(error)") }
    }

    func testChunkRoundTripAndExplicitClose() async throws {
        let session = try make(); let auth = try await handshake(session)
        let catalog = try await session.handle(message("catalog", auth))
        XCTAssertEqual(catalog["total"] as? Int, 1)
        let opened = try await session.handle(message("openFace", auth, ["id": "test"]))
        let id = try XCTUnwrap(opened["id"] as? String)
        let original = try bytes()
        let reply = try await session.handle(message("readChunk", auth, ["id": id, "offset": 0, "length": original.data.count]))
        XCTAssertEqual(Data(base64Encoded: try XCTUnwrap(reply["data"] as? String)), original.data)
        XCTAssertEqual(opened["sha256"] as? String, original.face.id.objectHash)
        _ = try await session.handle(message("closeFace", auth, ["id": id]))
        await rejects(.invalidRequest) { _ = try await session.handle(self.message("readChunk", auth, ["id": id, "offset": 0, "length": 1])) }
        session.invalidate()
    }

    func testMalformedAndUnauthorizedRequestsCannotRead() async throws {
        let state = StudioFontTestState(); let session = try make(state: state)
        let auth = try await handshake(session)
        await rejects(.invalidRequest) { _ = try await session.handle(self.message("openFace", auth, ["id": "test", "path": "/etc/passwd"])) }
        await rejects(.staleSession) { _ = try await session.handle(self.message("catalog", auth, ["session": "wrong"])) }
        await rejects(.invalidRequest) { _ = try await session.handle(self.message("catalog", auth, ["offset": true])) }
        await rejects(.invalidRequest) { _ = try await session.handle(self.message("catalog", auth, ["offset": 0.5])) }
        await rejects(.invalidRequest) { _ = try await session.handle(["op": "handshake", "version": true]) }
        await rejects(.invalidRequest) { _ = try await session.handle(self.message("openFace", auth, ["id": String(repeating: "x", count: 5000)])) }
        let reads = await state.reads; XCTAssertEqual(reads, 0)
        session.invalidate()
    }

    func testAppWideBudgetAndExpiryReleaseSlots() async throws {
        let budget = StudioFontTransferBudget()
        var clock = Date()
        let first = try make(budget: budget, now: { clock })
        let second = try make(budget: budget)
        let a = try await handshake(first), b = try await handshake(second)
        _ = try await first.handle(message("openFace", a, ["id": "test"]))
        _ = try await second.handle(message("openFace", b, ["id": "test"]))
        await rejects(.busy) { _ = try await first.handle(self.message("openFace", a, ["id": "test"])) }
        clock = clock.addingTimeInterval(31)
        await first.expireTransfers()
        _ = try await first.handle(message("openFace", a, ["id": "test"]))
        first.invalidate(); second.invalidate()
    }

    func testRevisionAndNavigationRejectPreviousTransfers() async throws {
        let state = StudioFontTestState(); let session = try make(state: state)
        let auth = try await handshake(session)
        let opened = try await session.handle(message("openFace", auth, ["id": "test"]))
        await state.change()
        await rejects(.staleGeneration) { _ = try await session.handle(self.message("readChunk", auth, ["id": opened["id"]!, "offset": 0, "length": 1])) }
        await rejects(.staleSession) { _ = try await session.handle(self.message("catalog", auth)) }
        session.invalidate()
    }

    func testTrustedFramePolicy() {
        let url = URL(string: "alhangeul-studio://app/index.html")!
        XCTAssertTrue(StudioFontMessageHandler.permits(mainFrame: true, originScheme: "alhangeul-studio", originHost: "app", originPort: 0, frameURL: url, sameWebView: true))
        XCTAssertFalse(StudioFontMessageHandler.permits(mainFrame: false, originScheme: "alhangeul-studio", originHost: "app", originPort: 0, frameURL: url, sameWebView: true))
        XCTAssertFalse(StudioFontMessageHandler.permits(mainFrame: true, originScheme: "https", originHost: "app", originPort: 0, frameURL: url, sameWebView: true))
        XCTAssertFalse(StudioFontMessageHandler.permits(mainFrame: true, originScheme: "alhangeul-studio", originHost: "app", originPort: 0, frameURL: url, sameWebView: false))
    }

    func testManagedChangesStreamPublishesAfterImport() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let service = FontLibraryService(store: FontLibraryStore(rootURL: directory))
        let updates = await service.changes.updates()
        var iterator = updates.makeAsyncIterator()
        let initial = await iterator.next(); XCTAssertEqual(initial, 0)
        let folder = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Fixtures", withExtension: nil))
        let results = await service.importFonts(.init(candidates: [
            .init(sourceURL: folder.appendingPathComponent("regular.ttf")),
            .init(sourceURL: folder.appendingPathComponent("missing.ttf"))], accessURLs: []))
        XCTAssertEqual(results.first?.status, .added)
        XCTAssertEqual(results.last?.status, .readFailure)
        let updated = await iterator.next(); XCTAssertEqual(updated, 1)
        let manifest = try await service.list()
        _ = try await service.remove(objectHash: try XCTUnwrap(results.first?.objectHash), expectedGeneration: manifest.generation)
        let removed = await iterator.next(); XCTAssertEqual(removed, 2)
    }

    func testNavigationDuringReadDiscardsLateBytesAndReleasesBudget() async throws {
        let bytes = try bytes(), state = StudioFontTestState(), gate = StudioFontReadGate()
        let budget = StudioFontTransferBudget()
        let face = StudioFontFace(id: "test", source: "managed", postScriptName: "Test",
            family: "Test", fullName: "Test", style: "Regular", aliases: [], weight: 400, traits: 0, limitation: nil)
        let session = StudioFontSession(supply: .init(snapshot: {
            .init(identity: "one", faces: [face], omitted: 0, failure: nil,
                read: { _ in await gate.enter(); return bytes }, current: { true }, release: { await state.release() })
        }), budget: budget)
        let auth = try await handshake(session)
        let reading = Task { try await session.handle(self.message("openFace", auth, ["id": "test"])) }
        await gate.waitForEntry()
        session.invalidate()
        await gate.open()
        do { _ = try await reading.value; XCTFail("late bytes accepted") } catch {}
        let one = try await budget.acquire(), two = try await budget.acquire()
        await budget.release(one); await budget.release(two)
        for _ in 0..<20 { await Task.yield() }
        let released = await state.releases
        XCTAssertEqual(released, 1)
    }

    func testChunkBoundsAndCrossDocumentTokenAreRejected() async throws {
        let a = try make(), b = try make()
        let auth = try await handshake(a), other = try await handshake(b)
        let transfer = try await a.handle(message("openFace", auth, ["id": "test"]))
        let id = try XCTUnwrap(transfer["id"] as? String)
        await rejects(.invalidRequest) { _ = try await a.handle(self.message("readChunk", auth, ["id": id, "offset": -1, "length": 1])) }
        await rejects(.invalidRequest) { _ = try await a.handle(self.message("readChunk", auth, ["id": id, "offset": 0, "length": 262145])) }
        await rejects(.invalidRequest) { _ = try await b.handle(self.message("readChunk", other, ["id": id, "offset": 0, "length": 1])) }
        a.invalidate(); b.invalidate()
    }

    func testInstalledProviderSharesConcurrentCreation() async throws {
        let count = StudioFontTestState()
        let catalog = try InstalledFontCatalogService(persistence: .init(load: { nil }, save: { _ in }),
            environment: .init(scan: { _ in .init(records: [], grantIssues: []) },
                read: { _, _ in throw InstalledFontFailure.inactive }, makeBookmark: { _ in Data() }), observeChanges: false)
        let provider = InstalledFontServiceProvider(factory: {
            await count.read()
            try await Task.sleep(nanoseconds: 10_000_000)
            return catalog
        })
        async let first = provider.service()
        async let second = provider.service()
        let (a, b) = try await (first, second)
        XCTAssertTrue(a === b)
        let calls = await count.reads; XCTAssertEqual(calls, 1)
    }

}

private actor StudioFontReadGate {
    private var entered = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var continuation: CheckedContinuation<Void, Never>?
    func enter() async {
        entered = true
        for waiter in waiters { waiter.resume() }; waiters.removeAll()
        await withCheckedContinuation { continuation = $0 }
    }
    func waitForEntry() async {
        if entered { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func open() { continuation?.resume(); continuation = nil }
}
