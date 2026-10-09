import Foundation
import Darwin
import CoreGraphics
import CryptoKit

actor Meter {
    var reads = 0
    var releases = 0
    var checks = 0
    func read() { reads += 1 }
    func release() { releases += 1 }
    func check() -> Int { checks += 1; return checks }
}
actor ReadGate {
    var count = 0
    var waiters: [CheckedContinuation<Void, Never>] = []
    var opened = false
    func wait() async {
        count += 1
        if opened { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func finish() { opened = true; waiters.forEach { $0.resume() }; waiters.removeAll() }
}
func verify(_ value: Bool, _ message: String, line: UInt = #line) {
    precondition(value, "\(message) (\(line))")
}
func track(_ snapshot: StudioFontSupplySnapshot, meter: Meter, staleAt: Int? = nil,
           deny: Bool = false) -> StudioFontSupplySnapshot {
    .init(identity: snapshot.identity, faces: snapshot.faces, omitted: snapshot.omitted, failure: snapshot.failure,
        read: { id in
            await meter.read()
            if deny { throw InstalledFontFailure.permissionDenied }
            return try await snapshot.read(id)
        }, current: {
            let check = await meter.check()
            if let staleAt, check >= staleAt { return false }
            return try await snapshot.current()
        }, release: { await snapshot.release(); await meter.release() })
}
func thumbnail(_ cache: HwpThumbnailRenderCache, _ request: HwpThumbnailRenderRequest) async throws -> HwpThumbnailRenderResult {
    try await withCheckedThrowingContinuation { continuation in
        cache.renderedPageResult(for: request) { continuation.resume(with: $0) }
    }
}
@main struct ExtensionProbe {
    static func main() async throws {
        setbuf(stdout, nil)
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let out = URL(fileURLWithPath: CommandLine.arguments[2])
        let libraryRoot = out.appendingPathComponent("private-library")
        let library = FontLibraryStore(rootURL: libraryRoot)
        let fonts = root.appendingPathComponent("build.noindex/task567/fonts/gowun-batang")
        let imported = await library.importCandidates(["Regular", "Bold"].map { .init(sourceURL: fonts.appendingPathComponent("GowunBatang-\($0).ttf")) })
        verify(imported.allSatisfy { $0.status == .added }, "관리 복사본 준비")
        let policy = FontConsumerPolicyStore(rootURL: libraryRoot)
        try policy.publish(enabled: true)
        let own = InstalledFontEnvironment(scan: { grants in
            verify(grants.isEmpty, "Host 권한을 사용하지 않음")
            return .init(records: [], grantIssues: [])
        }, read: { _, _ in throw InstalledFontFailure.permissionDenied }, makeBookmark: { _ in throw InstalledFontFailure.permissionDenied })
        let supply = ExtensionFontSupply(resolveRoot: { libraryRoot }, environment: own)
        let file = root.appendingPathComponent("build.noindex/task568/stage3/fixtures/gowun-document.hwpx")
        let context = try HwpPreviewPDFRenderer.load(fileURL: file)
        var proofs: [[String: Any]] = []
        for mode in [HwpPreviewPNGReplyMode.coreGraphics, .skiaDecode, .skiaDirect] {
            let meter = Meter()
            let png = try await ExtensionFontRenderer.png(context: context, mode: mode,
                supply: { track(try await supply.snapshot(), meter: meter) })
            verify(png.diagnostics.fontFaces.sorted() == ["GowunBatang-Bold", "GowunBatang-Regular"], "PNG 정확한 R/B")
            verify(png.diagnostics.fontSupplyFailure == nil, "PNG 공급 성공")
            verify(await meter.reads == 2, "PNG 두 읽기")
            verify(await meter.releases == 1, "PNG 한 번 해제")
            try png.data.write(to: out.appendingPathComponent("preview-\(mode.identifier).png"))
            proofs.append(["consumer":"PNG", "mode":mode.identifier, "faces":png.diagnostics.fontFaces,
                "reads":await meter.reads, "releases":await meter.releases, "bytes":png.data.count])
        }
        let multiple = try HwpPreviewPDFRenderer.load(fileURL: root.appendingPathComponent("build.noindex/task568/stage5/probe-inputs/multiple-two.hwpx"))
        verify(multiple.pageCount == 2, "여러 페이지 fixture")
        let pdfMeter = Meter()
        let pdf = try await ExtensionFontRenderer.pdf(context: multiple,
            supply: { track(try await supply.snapshot(), meter: pdfMeter) })
        verify(pdf.pageCount == 2 && pdf.pageDiagnostics.allSatisfy { $0.diagnostics.fontSupplyFailure == nil }, "PDF 전체 공급 성공")
        verify(await pdfMeter.releases == 1, "PDF 단일 lease 해제")
        verify(pdf.pageDiagnostics.flatMap { $0.diagnostics.fontFaces }.contains("GowunBatang-Bold"), "PDF Bold")
        try pdf.data.write(to: out.appendingPathComponent("preview-multiple.pdf"))
        proofs.append(["consumer":"PDF", "pages":pdf.pageCount,"reads":await pdfMeter.reads,"releases":await pdfMeter.releases])
        // 어느 공급 검사 시점이든 세대가 바뀌면 대체 PDF를 반환하지 않는다.
        let stale = Meter()
        do {
            _ = try await ExtensionFontRenderer.pdf(context: multiple,
                supply: { track(try await supply.snapshot(), meter: stale, staleAt: 7) })
            preconditionFailure("stale PDF 반환")
        } catch { verify(ExtensionFontRenderer.isStaleOrCancelled(error), "stale 보존") }
        verify(await stale.releases == 1, "stale PDF 해제")
        let denied = Meter()
        let fallback = try await ExtensionFontRenderer.png(context: context, mode: .skiaDirect,
            supply: { track(try await supply.snapshot(), meter: denied, deny: true) })
        verify(fallback.diagnostics.fontSupplyFailure != nil && fallback.diagnostics.fontFaces.isEmpty, "거부된 원본의 명시적 기본 대체")
        verify(fallback.diagnostics.backendUsed == .coreGraphics, "기본 대체가 Skia의 이름 조회를 사용하지 않음")
        verify(await denied.releases == 1, "실패 snapshot 해제")
        try fallback.data.write(to: out.appendingPathComponent("preview-permission-fallback.png"))
        let cacheMeter = Meter()
        let cache = HwpThumbnailRenderCache(supply: { track(try await supply.snapshot(), meter: cacheMeter) })
        let large = try HwpThumbnailRenderRequest(fileURL: file, maximumSize: CGSize(width: 256, height: 256), scale: 1)
        let small = try HwpThumbnailRenderRequest(fileURL: file, maximumSize: CGSize(width: 128, height: 128), scale: 1)
        let miss = try await thumbnail(cache, large)
        let hit = try await thumbnail(cache, large)
        let larger = try await thumbnail(cache, small)
        verify(miss.cacheEvent == .miss && hit.cacheEvent == .exactHit, "Thumbnail cache 재사용")
        verify(larger.cacheEvent == .largerBucketHit(pixelWidth: 256, pixelHeight: 256), "큰 bucket 재사용")
        verify(await cacheMeter.reads == 2, "cache hit 원본 bytes 추가 읽기 없음")
        verify(await cacheMeter.releases == 3, "cache hit lease 해제")
        try policy.publish(enabled: false)
        let changed = try await thumbnail(cache, large)
        verify(changed.cacheEvent == .miss && changed.requestedKey != miss.requestedKey, "설정 revision cache 무효화")
        verify(changed.page.diagnostics.fontFaces.count == 2, "관리 원본은 설치 사용 설정과 독립")
        try HwpPageImageRenderer.encodePNG(changed.page.image).write(to: out.appendingPathComponent("thumbnail.png"))
        proofs.append(["consumer":"Thumbnail","first":miss.cacheEvent.description,"second":hit.cacheEvent.description,
            "smaller":larger.cacheEvent.description,"settingChange":changed.cacheEvent.description,
            "reads":await cacheMeter.reads,"releases":await cacheMeter.releases])
        let gate = ReadGate()
        let boundMeter = Meter()
        let limited = HwpThumbnailRenderCache(supply: {
            let snap = try await supply.snapshot()
            return .init(identity: snap.identity, faces: snap.faces, omitted: snap.omitted, failure: snap.failure,
                read: { id in await boundMeter.read(); let value = try await snap.read(id); await gate.wait(); return value },
                current: snap.current, release: { await snap.release(); await boundMeter.release() })
        })
        let heldA = Task { try await thumbnail(limited, large) }
        for _ in 0..<100 { if await gate.count >= 1 { break }; try await Task.sleep(nanoseconds: 10_000_000) }
        let heldB = Task { try await thumbnail(limited, small) }
        for _ in 0..<100 { if await gate.count >= 2 { break }; try await Task.sleep(nanoseconds: 10_000_000) }
        verify(await gate.count == 2, "동시에 두 원본 작업만 진행")
        let third = try HwpThumbnailRenderRequest(fileURL: file, maximumSize: CGSize(width:512,height:512), scale:1)
        do { _ = try await thumbnail(limited, third); preconditionFailure("세 번째 작업을 무제한 시작") }
        catch { verify((error as? StudioFontError) == .busy, "초과 작업 거부") }
        verify(await boundMeter.reads == 2, "초과 요청은 bytes를 읽지 않음")
        verify(await boundMeter.releases == 1, "초과 요청 lease만 먼저 해제")
        await gate.finish()
        _ = try await heldA.value; _ = try await heldB.value
        verify(await boundMeter.releases == 3, "두 실제 I/O 완료 후 남은 lease 해제")
        let stamp = try InstalledFontSystem.statURL(file)
        let oldStampRequest = large.key
        let modified = out.appendingPathComponent("source-change.hwpx")
        try Data(contentsOf: file).write(to: modified)
        let local = try HwpThumbnailRenderRequest(fileURL: modified, maximumSize: CGSize(width:128,height:128), scale:1)
        _ = try await thumbnail(cache, local)
        // 같은 크기/mtime여도 원본 inode·ctime 변경으로 이전 bitmap을 재사용하지 않는다.
        let originalDate = try modified.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate!
        let beforeChange = try await thumbnail(cache, local)
        try Data(contentsOf: file).write(to: modified, options: .atomic)
        try FileManager.default.setAttributes([.modificationDate:originalDate], ofItemAtPath:modified.path)
        let afterChange = try await thumbnail(cache, local)
        verify(afterChange.cacheEvent == .miss && afterChange.requestedKey != beforeChange.requestedKey, "inode/ctime 변경")
        verify(try InstalledFontSystem.statURL(file) == stamp && oldStampRequest == large.key, "원본 fixture 보존")
        let proof: [String:Any] = ["scope":"unsigned CLI; actual group/Finder not tested", "proofs":proofs,
            "staleRejected":true,"permissionFallback":true,"documentStampInvalidated":true,"concurrentJobsBounded":true]
        try JSONSerialization.data(withJSONObject:proof,options:[.prettyPrinted,.sortedKeys]).write(to:out.appendingPathComponent("result.json"))
        print("PASS: Extension font PNG/PDF/Thumbnail preparation")
    }
}
