import Foundation
import CoreGraphics

private actor QueueGate {
    private var opened = false
    private var seen: Set<Int> = []
    private var waiting: [Int: CheckedContinuation<Void, Never>] = [:]
    func enter(_ id: Int) async {
        guard seen.insert(id).inserted, !opened else { return }
        await withCheckedContinuation { waiting[id] = $0 }
    }
    func open(_ id: Int) { waiting.removeValue(forKey: id)?.resume() }
    func openAll() { opened = true; waiting.values.forEach { $0.resume() }; waiting.removeAll() }
}

private actor QueueMeter {
    var acquired = 0
    var released: Set<Int> = []
    var starts: [Int] = []
    var currentChecks: [Int: Int] = [:]
    var invalid: Set<Int> = []
    var denied: Set<Int> = []
    func acquire() -> Int { acquired += 1; return acquired }
    func read(_ id: Int) -> Bool {
        verify(!released.contains(id), "해제된 FD를 읽지 않음")
        if !starts.contains(id) { starts.append(id) }
        return !denied.contains(id)
    }
    func release(_ id: Int) { verify(released.insert(id).inserted, "각 획득의 단 한 번 해제") }
    func check(_ id: Int) -> Int { currentChecks[id, default: 0] += 1; return currentChecks[id]! }
    func current(_ id: Int) -> Bool { !invalid.contains(id) && !released.contains(id) }
    func invalidate(_ id: Int) { invalid.insert(id) }
    func deny(_ id: Int) { denied.insert(id) }
}

private func waitUntil(_ message: String, _ predicate: () async -> Bool) async throws {
    for _ in 0..<500 {
        if await predicate() { return }
        try await Task.sleep(nanoseconds: 10_000_000)
    }
    preconditionFailure("제어 gate 미도달: \(message)")
}

private func failed(_ task: Task<HwpThumbnailRenderResult, Error>, busy: Bool = false) async {
    do { _ = try await task.value; preconditionFailure("실패 요청이 결과를 반환") }
    catch {
        verify(busy ? (error as? StudioFontError) == .busy : ExtensionFontRenderer.isStaleOrCancelled(error),
               busy ? "명시적 deadline/admission busy" : "stale/취소 보존")
    }
}

func verifyThumbnailQueue(file: URL, output: URL, supply: @escaping ExtensionFontRenderer.Supply) async throws -> [String: Any] {
    let folder = output.appendingPathComponent("queue-documents")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let bytes = try Data(contentsOf: file)
    var requests: [HwpThumbnailRenderRequest] = []
    for index in 0..<18 {
        let url = folder.appendingPathComponent("queue-\(index).hwpx")
        try bytes.write(to: url)
        requests.append(try .init(fileURL: url, maximumSize: CGSize(width: 64, height: 64), scale: 1))
    }
    func controlled(_ meter: QueueMeter, _ gate: QueueGate, deadline: UInt64 = 30_000_000_000,
                    beforeSupply: QueueGate? = nil, beforeStart: QueueGate? = nil) -> HwpThumbnailRenderCache {
        HwpThumbnailRenderCache(supply: {
            let id = await meter.acquire()
            if let beforeSupply { await beforeSupply.enter(id) }
            let base = try await supply()
            return .init(identity: base.identity, faces: base.faces, omitted: base.omitted, failure: base.failure,
                read: { name in
                    let allowed = await meter.read(id)
                    await gate.enter(id) // 취소에 반응하지 않는 실제 I/O 대기 모사.
                    if !allowed { throw InstalledFontFailure.permissionDenied }
                    return try await base.read(name)
                }, current: {
                    let check = await meter.check(id)
                    if check == 2, let beforeStart { await beforeStart.enter(id) }
                    guard await meter.current(id) else { return false }; return try await base.current()
                },
                release: { await base.release(); await meter.release(id) })
        }, waitNanoseconds: deadline)
    }

    // 10개 고유 key의 FIFO와 실행 중 같은 key 병합. 첫 요청과 참가자 하나만 취소한다.
    let meter = QueueMeter(), gate = QueueGate(), cache = controlled(meter, gate)
    let first = Task { try await cache.renderedPageResult(for: requests[0]) }
    try await waitUntil("첫 렌더", { await meter.starts.count == 1 })
    let joined = (0..<4).map { _ in Task { try await cache.renderedPageResult(for: requests[0]) } }
    var others: [Task<HwpThumbnailRenderResult, Error>] = []
    for index in 1..<10 {
        others.append(Task { try await cache.renderedPageResult(for: requests[index]) })
        let expected = index + 5
        try await waitUntil("FIFO 접수", { await meter.acquired == expected })
        // 공급 직후 key/current 검사가 큐에 도달할 시간을 준다. 타이밍 자체를 통과 기준으로 쓰지 않는다.
        try await Task.sleep(nanoseconds: 30_000_000)
    }
    try await waitUntil("두 실행", { await meter.starts.count == 2 })
    first.cancel(); joined[0].cancel()
    await failed(first); await failed(joined[0])
    verify(await meter.released.count == 1, "최초 요청의 FD는 다른 참가자의 I/O 완료까지 유지")
    verify(await meter.starts.count == 2, "병합·대기 중 추가 bytes 없음")
    await gate.openAll()
    for task in joined.dropFirst() { verify(try await task.value.page.diagnostics.fontSupplyFailure == nil, "병합 참가자 성공") }
    for task in others { verify(try await task.value.page.diagnostics.fontSupplyFailure == nil, "10개 정상 대기 성공") }
    verify(await meter.released.count == 14, "14개 독립 공급 획득 해제")
    verify(await meter.starts == [1] + Array(6...14), "고유 miss FIFO·동일 key는 한 번 렌더")
    let after = try await cache.renderedPageResult(for: requests[0])
    verify(after.cacheEvent == .exactHit, "유효 참가자가 cache 게시")

    // 같은 key의 대기 job도 개별 취소를 분리하고, 모두 취소하면 큐에서 제거한다.
    let mergeMeter = QueueMeter(), mergeGate = QueueGate(), mergeCache = controlled(mergeMeter, mergeGate)
    let mergeA = Task { try await mergeCache.renderedPageResult(for: requests[0]) }
    try await waitUntil("대기 병합 A", { await mergeMeter.starts.count == 1 })
    let mergeB = Task { try await mergeCache.renderedPageResult(for: requests[1]) }
    try await waitUntil("대기 병합 B", { await mergeMeter.starts.count == 2 })
    let queuedOwner = Task { try await mergeCache.renderedPageResult(for: requests[2]) }
    try await waitUntil("대기 owner", { await mergeMeter.acquired == 3 })
    let queuedJoin = Task { try await mergeCache.renderedPageResult(for: requests[2]) }
    try await waitUntil("대기 join", { await mergeMeter.acquired == 4 })
    let abandonedOwner = Task { try await mergeCache.renderedPageResult(for: requests[3]) }
    try await waitUntil("전체 취소 owner", { await mergeMeter.acquired == 5 })
    let abandonedJoin = Task { try await mergeCache.renderedPageResult(for: requests[3]) }
    try await waitUntil("전체 취소 join", { await mergeMeter.acquired == 6 })
    try await Task.sleep(nanoseconds: 100_000_000)
    queuedOwner.cancel(); abandonedOwner.cancel(); abandonedJoin.cancel()
    await failed(queuedOwner); await failed(abandonedOwner); await failed(abandonedJoin)
    try await waitUntil("병합 취소 lease", { await mergeMeter.released.count == 2 })
    verify(await mergeMeter.starts.count == 2, "취소한 대기 job은 bytes를 읽지 않음")
    await mergeGate.openAll()
    _ = try await mergeA.value; _ = try await mergeB.value; _ = try await queuedJoin.value
    verify(await mergeMeter.starts == [1, 2, 3], "남은 대기 참가자는 owner FD를 빌려 완료")
    verify(await mergeMeter.released.count == 6, "대기 병합의 모든 원본 한 번 해제")
    verify(try await mergeCache.renderedPageResult(for: requests[3]).cacheEvent == .miss, "제거된 key의 재시도")

    // 16개 실행/대기/metadata 접수. 17번째는 공급 진입 전에 거부한다.
    let capMeter = QueueMeter(), capGate = QueueGate(), cap = controlled(capMeter, capGate)
    let held = (0..<16).map { index in Task { try await cap.renderedPageResult(for: requests[index]) } }
    try await waitUntil("16 접수", { await capMeter.acquired == 16 })
    try await waitUntil("실행 2", { await capMeter.starts.count == 2 })
    let excess = Task { try await cap.renderedPageResult(for: requests[16]) }
    await failed(excess, busy: true)
    verify(await capMeter.acquired == 16, "17번째는 공급/FD 획득 없음")
    for task in held { task.cancel() }
    for task in held { await failed(task) }
    try await waitUntil("대기 lease 해제", { await capMeter.released.count == 14 })
    let recovery = Task { try await cap.renderedPageResult(for: requests[17]) }
    try await waitUntil("복구 접수", { await capMeter.acquired == 17 })
    try await Task.sleep(nanoseconds: 100_000_000)
    verify(await capMeter.starts.count == 2, "모두 취소한 실제 I/O가 끝나기 전에 slot 재사용 없음")
    await capGate.openAll()
    verify(try await recovery.value.page.diagnostics.fontSupplyFailure == nil, "취소 I/O 종료 후 다음 요청 복구")
    try await waitUntil("전체 해제", { await capMeter.released.count == 17 })
    let retry = try await cap.renderedPageResult(for: requests[0])
    verify(retry.cacheEvent == .miss, "취소된 마지막 참가자의 bitmap을 게시하지 않음")

    // 렌더 시작 전 deadline만 적용한다. 실행 중 I/O는 500ms 뒤에도 유지한다.
    let deadlineMeter = QueueMeter(), deadlineGate = QueueGate()
    let deadline = controlled(deadlineMeter, deadlineGate, deadline: 500_000_000)
    let runningA = Task { try await deadline.renderedPageResult(for: requests[0]) }
    try await waitUntil("deadline A", { await deadlineMeter.starts.count == 1 })
    let runningB = Task { try await deadline.renderedPageResult(for: requests[1]) }
    try await waitUntil("deadline B", { await deadlineMeter.starts.count == 2 })
    let timed = Task { try await deadline.renderedPageResult(for: requests[2]) }
    await failed(timed, busy: true)
    try await waitUntil("deadline 소유 해제", { await deadlineMeter.released.count == 1 })
    let deadlineReleases = await deadlineMeter.released.count
    verify(await deadlineMeter.starts.count == 2 && deadlineReleases == 1, "deadline만 종료·실행 I/O/lease 유지")
    await deadlineGate.openAll()
    _ = try await runningA.value; _ = try await runningB.value
    _ = try await deadline.renderedPageResult(for: requests[2])
    verify(await deadlineMeter.released.count == 4, "deadline 후 재시도·해제")

    // metadata 대기도 admission deadline에 포함된다. Task 실행 전 취소는 공급에 진입하지 않는다.
    let metadataMeter = QueueMeter(), metadataGate = QueueGate(), readGate = QueueGate()
    await readGate.openAll()
    let metadata = controlled(metadataMeter, readGate, deadline: 100_000_000, beforeSupply: metadataGate)
    let delayed = Task { try await metadata.renderedPageResult(for: requests[0]) }
    try await waitUntil("metadata 공급", { await metadataMeter.acquired == 1 })
    try await Task.sleep(nanoseconds: 150_000_000)
    await metadataGate.openAll(); await failed(delayed, busy: true)
    let metadataReleases = await metadataMeter.released.count
    verify(await metadataMeter.starts.isEmpty && metadataReleases == 1, "metadata deadline 후 bytes 없이 해제")
    let preCancelled = Task { () async throws -> HwpThumbnailRenderResult in
        try await Task.sleep(nanoseconds: 100_000_000)
        return try await metadata.renderedPageResult(for: requests[0])
    }
    preCancelled.cancel(); await failed(preCancelled)
    verify(await metadataMeter.acquired == 1, "사전 취소는 접수/공급 진입 없음")

    // 대기 중 문서·원본 현재성이 바뀌면 시작 직전 폐기하고 다음 FIFO 요청을 계속한다.
    let staleMeter = QueueMeter(), staleGate = QueueGate(), staleCache = controlled(staleMeter, staleGate)
    let a = Task { try await staleCache.renderedPageResult(for: requests[0]) }
    try await waitUntil("stale A", { await staleMeter.starts.count == 1 })
    let b = Task { try await staleCache.renderedPageResult(for: requests[1]) }
    try await waitUntil("stale B", { await staleMeter.starts.count == 2 })
    let sourceStale = Task { try await staleCache.renderedPageResult(for: requests[2]) }
    try await waitUntil("stale 원본 대기", { await staleMeter.acquired == 3 })
    let documentStale = Task { try await staleCache.renderedPageResult(for: requests[3]) }
    try await waitUntil("stale 문서 대기", { await staleMeter.acquired == 4 })
    let next = Task { try await staleCache.renderedPageResult(for: requests[4]) }
    try await waitUntil("stale 다음 대기", { await staleMeter.acquired == 5 })
    await staleMeter.invalidate(3)
    try bytes.write(to: requests[3].fileURL, options: .atomic)
    await staleGate.openAll()
    _ = try await a.value; _ = try await b.value
    await failed(sourceStale); await failed(documentStale)
    _ = try await next.value
    verify(await staleMeter.starts == [1, 2, 5], "변경된 대기자는 load/bytes 전에 폐기")
    verify(await staleMeter.released.count == 5, "stale·성공 모든 lease 해제")

    // 읽기 실패의 기본 대체는 성공 cache에 넣지 않는다.
    let failureMeter = QueueMeter(), failureGate = QueueGate(), failureCache = controlled(failureMeter, failureGate)
    await failureMeter.deny(1); await failureGate.openAll()
    let fallback = try await failureCache.renderedPageResult(for: requests[5])
    verify(fallback.page.diagnostics.fontSupplyFailure != nil, "읽기 실패 기본 대체")
    let restored = try await failureCache.renderedPageResult(for: requests[5])
    verify(restored.cacheEvent == .miss && restored.page.diagnostics.fontSupplyFailure == nil, "실패 cache 없음·복구")
    verify(await failureMeter.released.count == 2, "실패/복구 해제")

    // slot 획득 직후 current 재검사 중 취소: document load/bytes 전에 끝난다.
    let boundaryMeter = QueueMeter(), boundaryReads = QueueGate(), boundaryCurrent = QueueGate()
    await boundaryReads.openAll()
    let boundary = controlled(boundaryMeter, boundaryReads, beforeStart: boundaryCurrent)
    let boundaryTask = Task { try await boundary.renderedPageResult(for: requests[5]) }
    try await waitUntil("slot 직후 current", { await boundaryMeter.currentChecks[1] == 2 })
    boundaryTask.cancel(); await failed(boundaryTask)
    verify(await boundaryMeter.starts.isEmpty, "slot 경계 취소는 bytes 없음")
    await boundaryCurrent.openAll()
    try await waitUntil("slot 경계 해제", { await boundaryMeter.released.count == 1 })
    _ = try await boundary.renderedPageResult(for: requests[5])
    verify(await boundaryMeter.released.count == 2, "slot 경계 취소 후 복구")

    // 완료/취소 경합은 성공 또는 취소로 한 번만 끝나며 모두 해제한다.
    let raceMeter = QueueMeter(), raceGate = QueueGate(), raceCache = controlled(raceMeter, raceGate)
    let race = Task { try await raceCache.renderedPageResult(for: requests[6]) }
    try await waitUntil("경합 시작", { await raceMeter.starts.count == 1 })
    race.cancel(); await raceGate.openAll(); await failed(race)
    try await waitUntil("경합 종료", { await raceMeter.released.count == 1 })
    _ = try await raceCache.renderedPageResult(for: requests[6])
    verify(await raceMeter.released.count == 2, "경합 뒤 복구")
    // 기존 LRU의 항목 수와 bitmap bytes 상한을 실제 크기가 다른 페이지로 검증한다.
    let emptySupply: ExtensionFontRenderer.Supply = {
        .init(identity: "queue-empty", faces: [], omitted: 0, failure: nil,
              read: { _ in preconditionFailure("empty supply bytes") }, current: { true }, release: {})
    }
    let entries = HwpThumbnailRenderCache(supply: emptySupply)
    var lruRequests: [HwpThumbnailRenderRequest] = []
    for index in 0..<97 {
        let url = folder.appendingPathComponent("lru-\(index).hwpx")
        try bytes.write(to: url)
        let request = try HwpThumbnailRenderRequest(fileURL: url, maximumSize: CGSize(width:16,height:16), scale:1)
        lruRequests.append(request)
        _ = try await entries.renderedPageResult(for: request)
    }
    verify(try await entries.renderedPageResult(for: lruRequests[96]).cacheEvent == .exactHit, "최근 항목 유지")
    verify(try await entries.renderedPageResult(for: lruRequests[0]).cacheEvent == .miss, "97번째에서 오래된 항목 축출")
    let bitmap = HwpThumbnailRenderCache(supply: emptySupply)
    var largeRequests: [HwpThumbnailRenderRequest] = []
    var renderedBytes = 0
    for index in 0..<8 {
        let request = try HwpThumbnailRenderRequest(fileURL: requests[index].fileURL,
            maximumSize: CGSize(width:2048,height:2048), scale:1)
        largeRequests.append(request)
        let page = try await bitmap.renderedPageResult(for: request).page
        renderedBytes += page.image.bytesPerRow * page.image.height
    }
    verify(renderedBytes > 64 * 1024 * 1024, "64MiB 초과 실제 bitmap 부하")
    verify(try await bitmap.renderedPageResult(for: largeRequests[7]).cacheEvent == .exactHit, "최근 큰 bitmap 유지")
    verify(try await bitmap.renderedPageResult(for: largeRequests[0]).cacheEvent == .miss, "64MiB 초과 시 오래된 bitmap 축출")
    return ["distinctKeys":10, "mergedParticipants":5, "admission":16, "physicalSlots":2,
        "fifo":true, "noEarlyBytes":true, "oneParticipantCancel":true, "queuedMergeCancel":true, "allCancelKeepsIOSlots":true,
        "deadlineIncludesMetadata":true, "deadlineExcludesRunningIO":true, "staleQueueRejected":true,
        "fallbackNotCached":true, "cancelAtSlotBoundary":true, "cancelCompletionRecovery":true, "exactlyOnceRelease":true, "eviction97Entries":true, "eviction64MiB":true]
}
