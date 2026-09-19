import Foundation
import XCTest

private final class DiscoveryAccessRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var starts = 0, stops = 0
    func start(_ url: URL) -> Bool { lock.lock(); defer { lock.unlock() }; starts += 1; return true }
    func stop(_ url: URL) { lock.lock(); defer { lock.unlock() }; stops += 1 }
    var counts: [Int] { lock.lock(); defer { lock.unlock() }; return [starts, stops] }
}

final class MacFontDiscoveryTests: XCTestCase {
    private var root: URL!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("font-discovery-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }
    @discardableResult private func file(_ path: String, data: Data = Data([0])) throws -> URL {
        let url = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
        return url
    }
    private func app(_ name: String, id: String = "com.haansoft.HancomOfficeViewer.Mac") throws -> URL {
        let data = try PropertyListSerialization.data(fromPropertyList: ["CFBundleIdentifier": id,
            "CFBundleDisplayName": "한글 뷰어", "CFBundleShortVersionString": "12.31.8"], format: .xml, options: 0)
        try file("\(name)/Contents/Info.plist", data: data)
        try file("\(name)/Contents/Resources/Hnc/Shared/TTF/Install/문서.TTF")
        try file("\(name)/Contents/Frameworks/Web.framework/icon.ttf")
        return root.appendingPathComponent(name)
    }
    func testMultipleApplicationsOnlyIncludeDocumentFonts() async throws {
        _ = try app("Applications/A.app")
        _ = try app("Applications/한컴/B.app")
        _ = try app("Applications/Fake.app", id: "example.unrelated")
        let result = await MacFontDiscovery().discover(.applications([root.appendingPathComponent("Applications")]))
        XCTAssertEqual(result.sources.count, 2)
        XCTAssertEqual(result.candidates.count, 2)
        XCTAssertTrue(result.candidates.allSatisfy { $0.source.kind == .macApplication && $0.url.lastPathComponent == "문서.TTF" })
        XCTAssertTrue(result.sources.allSatisfy { $0.version == "12.31.8" })
    }
    func testExplicitUnknownAppUsesOnlyKnownSubfoldersWithoutClaimingHancom() async throws {
        let url = try app("Custom.app", id: "example.editor")
        try file("Custom.app/Contents/Resources/Hnc/Shared/TTF/Hwp/편집기.otf")
        try file("Custom.app/Contents/Resources/Hnc/Shared/Fonts/legacy.hft")
        let result = await MacFontDiscovery().discover(.selected([url]))
        XCTAssertEqual(result.candidates.count, 2)
        XCTAssertEqual(result.unsupportedHFTCount, 1)
        XCTAssertTrue(result.candidates.allSatisfy { $0.source.kind == .userSelected })
    }
    func testInstalledAndSelectedSourcesDeduplicateAndKeepFormats() async throws {
        for name in ["a.ttf", "b.OTF", "c.ttc", "d.otc", "old.hft", "skip.woff2"] { try file("Fonts/\(name)") }
        let fonts = root.appendingPathComponent("Fonts")
        let result = await MacFontDiscovery().discover(.installed([fonts, fonts]))
        XCTAssertEqual(result.candidates.count, 4)
        XCTAssertEqual(result.sources.count, 1)
        XCTAssertEqual(result.unsupportedHFTCount, 1)
        XCTAssertTrue(result.candidates.allSatisfy { $0.importCandidate.sourceKind == .macInstalled })
    }
    func testSymlinksAndNestedAppsAreExcluded() async throws {
        try file("Fonts/good.ttf")
        let outside = try file("Outside/no.ttf")
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("Fonts/link.ttf"), withDestinationURL: outside)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("Fonts/cycle"), withDestinationURL: root)
        try file("Fonts/Other.app/no.ttf")
        let result = await MacFontDiscovery().discover(.selected([root.appendingPathComponent("Fonts")]))
        XCTAssertEqual(result.candidates.map { $0.url.lastPathComponent }, ["good.ttf"])
        XCTAssertTrue(result.notices.contains { $0.reason == .unsafePath })
        let linked = await MacFontDiscovery().discover(.selected([root.appendingPathComponent("Fonts/cycle/Outside")]))
        XCTAssertTrue(linked.candidates.isEmpty)
        XCTAssertTrue(linked.notices.contains { $0.reason == .unsafePath })
    }
    func testDepthVisitAndCandidateLimitsReportPartialSearch() async throws {
        for index in 0..<5 { try file("Fonts/\(index).ttf") }
        try file("Fonts/Deep/Deeper/no.ttf")
        let fonts = root.appendingPathComponent("Fonts")
        var limits = MacFontDiscoveryLimits(); limits.fontDepth = 1
        let shallow = await MacFontDiscovery(limits: limits).discover(.selected([fonts]))
        XCTAssertEqual(shallow.candidates.count, 5)
        XCTAssertTrue(shallow.notices.contains { $0.reason == .depthLimit })
        limits = .init(); limits.maximumCandidates = 2
        let capped = await MacFontDiscovery(limits: limits).discover(.selected([fonts]))
        XCTAssertEqual(capped.candidates.count, 2)
        XCTAssertTrue(capped.notices.contains { $0.reason == .candidateLimit })
        limits = .init(); limits.maximumVisited = 2
        let visited = await MacFontDiscovery(limits: limits).discover(.selected([fonts]))
        XCTAssertLessThanOrEqual(visited.candidates.count, 1)
        XCTAssertTrue(visited.notices.contains { $0.reason == .visitLimit })
    }
    func testMissingAndPermissionErrorsRemainDistinct() async throws {
        try file("Denied/no.ttf")
        try file("Allowed/yes.ttf")
        let denied = root.appendingPathComponent("Denied")
        let discovery = MacFontDiscovery(beforeRead: { url in
            if url == denied { throw NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES)) }
        })
        let result = await discovery.discover(.installed([root.appendingPathComponent("Missing"), denied, root.appendingPathComponent("Allowed")]))
        XCTAssertEqual(result.candidates.count, 1)
        XCTAssertTrue(result.notices.contains { $0.reason == .missing })
        XCTAssertTrue(result.notices.contains { $0.reason == .accessDenied })
    }
    func testScopeCloseWaitsForCancelledWorkerAndCannotBeReopened() async throws {
        try file("Fonts/a.ttf")
        let fonts = root.appendingPathComponent("Fonts")
        let recorder = DiscoveryAccessRecorder()
        let session = FontImportSourceSession(urls: [fonts, fonts], access: .init(start: { recorder.start($0) }, stop: { recorder.stop($0) }))
        let entered = DispatchSemaphore(value: 0), resume = DispatchSemaphore(value: 0)
        let discovery = MacFontDiscovery(beforeRead: { _ in
            entered.signal()
            XCTAssertEqual(resume.wait(timeout: .now() + 5), .success)
        })
        let task = Task { await discovery.discover(.selected([fonts]), session: session) }
        // MainActor를 막지 않는 별도 queue에서 worker 진입을 기다린다.
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async { XCTAssertEqual(entered.wait(timeout: .now() + 5), .success); continuation.resume() }
        }
        task.cancel(); session.close()
        XCTAssertEqual(recorder.counts, [1, 0])
        XCTAssertNil(session.acquire())
        resume.signal()
        let result = await task.value
        XCTAssertTrue(result.cancelled)
        // worker continuation 복귀 직전 lease가 소멸하도록 queue barrier 역할의 다음 요청을 기다린다.
        _ = await discovery.discover(.selected([]))
        XCTAssertEqual(recorder.counts, [1, 1])
        session.close()
        XCTAssertEqual(recorder.counts, [1, 1])
    }
    func testFalseScopeStartAllowsReadAndNeverStops() async throws {
        try file("Fonts/a.ttf")
        let session = FontImportSourceSession(urls: [root], access: .init(start: { _ in false }, stop: { _ in XCTFail("unacquired scope") }))
        let result = await MacFontDiscovery().discover(.selected([root]), session: session)
        XCTAssertEqual(result.candidates.count, 1)
        session.close()
        let closed = await MacFontDiscovery().discover(.selected([root]), session: session)
        XCTAssertTrue(closed.cancelled)
    }
    func testHomeIsAccountHomeAndDefaultRequestsExcludeSystemFonts() throws {
        let home = try MacFontDiscoveryRequest.userHome()
        XCTAssertTrue(home.path.hasPrefix("/"))
        XCTAssertFalse(home.path.contains("/Library/Containers/"))
        guard case .installed(let roots) = try MacFontDiscoveryRequest.defaultInstalled() else { return XCTFail() }
        XCTAssertEqual(roots, [home.appendingPathComponent("Library/Fonts"), URL(fileURLWithPath: "/Library/Fonts")])
    }
    func testApplicationDepthAndLinkedDocumentDirectory() async throws {
        _ = try app("Applications/Deep/TooDeep.app")
        var limits = MacFontDiscoveryLimits(); limits.applicationDepth = 1
        let shallow = await MacFontDiscovery(limits: limits).discover(.applications([root.appendingPathComponent("Applications")]))
        XCTAssertTrue(shallow.candidates.isEmpty)
        XCTAssertTrue(shallow.notices.contains { $0.reason == .depthLimit })
        let selected = try app("Linked.app")
        let documentRoot = selected.appendingPathComponent("Contents/Resources/Hnc/Shared/TTF/Install")
        try FileManager.default.removeItem(at: documentRoot)
        try file("Outside/private.ttf")
        try FileManager.default.createSymbolicLink(at: documentRoot, withDestinationURL: root.appendingPathComponent("Outside"))
        let linked = await MacFontDiscovery().discover(.selected([selected]))
        XCTAssertTrue(linked.candidates.isEmpty)
        XCTAssertTrue(linked.notices.contains { $0.reason == .unsafePath })
    }
    func testMidTraversalFailurePreservesReadableCandidatesAndSessionDeinitCloses() async throws {
        try file("Fonts/good.ttf")
        let bad = try file("Fonts/bad.ttf")
        let result = await MacFontDiscovery(beforeRead: { url in
            if url.standardizedFileURL.path == bad.standardizedFileURL.path {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(EIO))
            }
        }).discover(.selected([root.appendingPathComponent("Fonts")]))
        XCTAssertEqual(result.candidates.map { $0.url.lastPathComponent }, ["good.ttf"])
        XCTAssertTrue(result.notices.contains { $0.reason == .readFailure })
        let recorder = DiscoveryAccessRecorder()
        var session: FontImportSourceSession? = .init(urls: [root], access: .init(start: { recorder.start($0) }, stop: { recorder.stop($0) }))
        XCTAssertEqual(session?.urls.count, 1)
        session = nil
        XCTAssertEqual(recorder.counts, [1, 1])
    }
}
