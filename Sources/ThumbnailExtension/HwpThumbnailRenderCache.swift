import CoreGraphics
import Foundation
import CryptoKit

struct HwpThumbnailRenderRequest {
    let fileURL: URL
    let maximumSize: CGSize
    let maximumPixelSize: CGSize
    let policy: HwpPageRenderPolicy
    let renderSignature: HwpThumbnailRenderSignature
    let key: HwpThumbnailCacheKey

    init(
        fileURL: URL,
        maximumSize: CGSize,
        scale: CGFloat,
        policy: HwpPageRenderPolicy = .coreGraphicsOnly,
        renderSignature: HwpThumbnailRenderSignature? = nil
    ) throws {
        let values = try fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let pixelWidth = Self.pixelBucket(for: maximumSize.width, scale: scale)
        let pixelHeight = Self.pixelBucket(for: maximumSize.height, scale: scale)
        let resolvedSignature = renderSignature ?? HwpThumbnailRenderSignature(policy: policy)

        self.fileURL = fileURL
        self.maximumSize = maximumSize
        self.maximumPixelSize = CGSize(width: pixelWidth, height: pixelHeight)
        self.policy = policy
        self.renderSignature = resolvedSignature
        self.key = HwpThumbnailCacheKey(
            path: fileURL.path,
            modificationTime: values.contentModificationDateKeyTimeInterval,
            fileSize: values.fileSize ?? 0,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            renderSignature: resolvedSignature
        )
    }

    private static func pixelBucket(for value: CGFloat, scale: CGFloat) -> Int {
        let scaledValue = max(16, Int(ceil(max(value, 1) * max(scale, 1))))
        var bucket = 16
        while bucket < scaledValue {
            bucket *= 2
        }
        return min(bucket, 2048)
    }
}

struct HwpThumbnailRenderSignature: Hashable {
    private static let rendererOptionVersion = "thumbnail-renderer-v1"
    private static let coreReleaseTag = RhwpCoreBuildInfo.releaseTag
    private static let coreCommit = RhwpCoreBuildInfo.commit
    private static let coreEnabledFeatures = RhwpCoreBuildInfo.enabledFeatures
    private static let maxDimensionPolicyVersion = "skia-max-dimension-thumbnail-v1"

    let backendPolicy: String
    let rendererOptionVersion: String
    let coreReleaseTag: String
    let coreCommit: String
    let coreEnabledFeatures: String
    let maxDimensionPolicyVersion: String

    init(
        policy: HwpPageRenderPolicy,
        rendererOptionVersion: String = Self.rendererOptionVersion,
        coreReleaseTag: String = Self.coreReleaseTag,
        coreCommit: String = Self.coreCommit,
        coreEnabledFeatures: String = Self.coreEnabledFeatures,
        maxDimensionPolicyVersion: String = Self.maxDimensionPolicyVersion
    ) {
        self.backendPolicy = policy.identifier
        self.rendererOptionVersion = rendererOptionVersion
        self.coreReleaseTag = coreReleaseTag
        self.coreCommit = coreCommit
        self.coreEnabledFeatures = coreEnabledFeatures
        self.maxDimensionPolicyVersion = maxDimensionPolicyVersion
    }

    var identifier: String {
        [
            backendPolicy,
            rendererOptionVersion,
            coreReleaseTag,
            coreCommit,
            coreEnabledFeatures,
            maxDimensionPolicyVersion
        ].joined(separator: "|")
    }
}

struct HwpThumbnailCacheKey: Hashable {
    let path: String
    let modificationTime: TimeInterval
    let fileSize: Int
    let pixelWidth: Int
    let pixelHeight: Int
    let renderSignature: HwpThumbnailRenderSignature
    var documentIdentity: String = ""
}

enum HwpThumbnailCacheEvent: CustomStringConvertible, Equatable {
    case miss
    case exactHit
    case largerBucketHit(pixelWidth: Int, pixelHeight: Int)

    var description: String {
        switch self {
        case .miss:
            return "miss"
        case .exactHit:
            return "exactHit"
        case .largerBucketHit(let pixelWidth, let pixelHeight):
            return "largerBucketHit(\(pixelWidth)x\(pixelHeight))"
        }
    }
}

struct HwpThumbnailRenderResult {
    let page: HwpRenderedPage
    let cacheEvent: HwpThumbnailCacheEvent
    let requestedKey: HwpThumbnailCacheKey
    let matchedKey: HwpThumbnailCacheKey
}

private struct HwpThumbnailCacheHit {
    let key: HwpThumbnailCacheKey
    let page: HwpRenderedPage
    let event: HwpThumbnailCacheEvent
}

private extension URLResourceValues {
    var contentModificationDateKeyTimeInterval: TimeInterval {
        contentModificationDate?.timeIntervalSinceReferenceDate ?? 0
    }
}

// mutable bitmap/LRU는 stateQueue, font 작업은 fontQueue가 독점한다.
final class HwpThumbnailRenderCache: @unchecked Sendable {
    static let shared = HwpThumbnailRenderCache(supply: ExtensionFontRenderer.live)

    private let stateQueue = DispatchQueue(label: "com.postmelee.alhangeul.thumbnail-cache")
    private let workerQueue = DispatchQueue(
        label: "com.postmelee.alhangeul.thumbnail-render",
        qos: .utility
    )
    private let maxEntryCount = 96
    private let maxBitmapBytes = 64 * 1024 * 1024
    private let supply: ExtensionFontRenderer.Supply?
    private let fontQueue: HwpThumbnailFontQueue

    private var cachedPages: [HwpThumbnailCacheKey: HwpRenderedPage] = [:]
    private var accessOrder: [HwpThumbnailCacheKey] = []
    private var inFlight: [HwpThumbnailCacheKey: [(Result<HwpThumbnailRenderResult, Error>) -> Void]] = [:]

    init(supply: ExtensionFontRenderer.Supply? = nil, waitNanoseconds: UInt64 = 30_000_000_000) {
        self.supply = supply
        self.fontQueue = HwpThumbnailFontQueue(waitNanoseconds: waitNanoseconds)
    }

    /// callback provider와 달리 호출 Task의 취소가 대기자까지 전달되는 내부 경계.
    func renderedPageResult(for request: HwpThumbnailRenderRequest) async throws -> HwpThumbnailRenderResult {
        if let supply { return try await renderWithFonts(request, supply: supply) }
        return try await withCheckedThrowingContinuation { continuation in
            renderedPageResult(for: request) { continuation.resume(with: $0) }
        }
    }

    func renderedPage(
        for request: HwpThumbnailRenderRequest,
        completion: @escaping (Result<HwpRenderedPage, Error>) -> Void
    ) {
        renderedPageResult(for: request) { result in
            switch result {
            case .success(let renderResult):
                completion(.success(renderResult.page))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func renderedPageResult(
        for request: HwpThumbnailRenderRequest,
        completion: @escaping (Result<HwpThumbnailRenderResult, Error>) -> Void
    ) {
        if let supply {
            Task {
                do { completion(.success(try await renderWithFonts(request, supply: supply))) }
                catch { completion(.failure(error)) }
            }
            return
        }
        stateQueue.async {
            if let hit = self.cachedPage(for: request.key) {
                self.touch(hit.key)
                self.workerQueue.async {
                    completion(.success(HwpThumbnailRenderResult(
                        page: hit.page,
                        cacheEvent: hit.event,
                        requestedKey: request.key,
                        matchedKey: hit.key
                    )))
                }
                return
            }

            if self.inFlight[request.key] != nil {
                self.inFlight[request.key, default: []].append(completion)
                return
            }

            self.inFlight[request.key] = [completion]
            self.workerQueue.async {
                let result = Result {
                    try HwpPageImageRenderer.renderFirstPage(
                        fileURL: request.fileURL,
                        maximumPixelSize: request.maximumPixelSize,
                        embeddedThumbnailPolicy: .never,
                        policy: request.policy
                    )
                }

                self.stateQueue.async {
                    let callbacks = self.inFlight.removeValue(forKey: request.key) ?? []
                    let callbackResult: Result<HwpThumbnailRenderResult, Error>
                    switch result {
                    case .success(let page):
                        self.store(page, for: request.key)
                        callbackResult = .success(HwpThumbnailRenderResult(
                            page: page,
                            cacheEvent: .miss,
                            requestedKey: request.key,
                            matchedKey: request.key
                        ))
                    case .failure(let error):
                        callbackResult = .failure(error)
                    }
                    for callback in callbacks {
                        self.workerQueue.async {
                            callback(callbackResult)
                        }
                    }
                }
            }
        }
    }

    private func state<T>(_ body: @escaping () -> T) async -> T {
        await withCheckedContinuation { continuation in
            stateQueue.async { continuation.resume(returning: body()) }
        }
    }

    private func renderWithFonts(_ request: HwpThumbnailRenderRequest,
        supply: ExtensionFontRenderer.Supply) async throws -> HwpThumbnailRenderResult {
        let id = UUID()
        return try await withTaskCancellationHandler(operation: {
            try await fontQueue.admit(id)
            do {
                try Task.checkCancellation()
                let result = try await performWithFonts(request, supply: supply, id: id)
                await fontQueue.leave(id)
                return result
            } catch {
                await fontQueue.leave(id)
                throw error
            }
        }, onCancel: {
            Task { await self.fontQueue.cancel(id) }
        })
    }

    private func performWithFonts(_ request: HwpThumbnailRenderRequest,
        supply: ExtensionFontRenderer.Supply, id: UUID) async throws -> HwpThumbnailRenderResult {
        let stamp = try InstalledFontSystem.statURL(request.fileURL)
        let current: @Sendable () async throws -> Bool = { try InstalledFontSystem.statURL(request.fileURL) == stamp }
        let snapshot: StudioFontSupplySnapshot
        do { snapshot = try await supply() }
        catch {
            if ExtensionFontRenderer.isStaleOrCancelled(error) { throw error }
            // 공급 실패의 기본 대체도 같은 물리 실행 한도·deadline을 따른다. cache는 채우지 않는다.
            var key = request.key
            key.documentIdentity = UUID().uuidString
            let page = try await fontQueue.run(id, key: key, makeWork: {
                .init(render: {
                    try Task.checkCancellation()
                    guard try await current() else { throw HwpNativeFontSupplyError.stale }
                    try Task.checkCancellation()
                    let context = try HwpPreviewPDFRenderer.load(fileURL: request.fileURL, resolveExternalImages: false)
                    return try await ExtensionFontRenderer.fallbackThumbnail(context: context,
                        maximumPixelSize: request.maximumPixelSize, policy: request.policy, current: current, error: error)
                }, release: {})
            })
            guard try await current() else { throw HwpNativeFontSupplyError.stale }
            try await fontQueue.commit(id) {}
            return .init(page: page, cacheEvent: .miss, requestedKey: request.key, matchedKey: request.key)
        }
        let lease = HwpThumbnailSnapshotLease(snapshot)
        do {
            let result = try await performWithSnapshot(request, id: id, stamp: stamp, current: current, lease: lease)
            await lease.release()
            return result
        } catch { await lease.release(); throw error }
    }

    private func performWithSnapshot(_ request: HwpThumbnailRenderRequest, id: UUID,
        stamp: InstalledFontStamp, current: @escaping @Sendable () async throws -> Bool,
        lease: HwpThumbnailSnapshotLease) async throws -> HwpThumbnailRenderResult {
        let snapshot = lease.snapshot
        var key = request.key
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        key.documentIdentity = SHA256.hash(data: try encoder.encode(stamp)).map { String(format: "%02x", $0) }.joined() + ":" + snapshot.identity
        try await fontQueue.check(id)
        guard try await snapshot.current(), try await current() else { throw HwpNativeFontSupplyError.stale }
        let immutableKey = key
        if let hit = await state({ self.cachedPage(for: immutableKey) }) {
            guard try await snapshot.current(), try await current() else { throw HwpNativeFontSupplyError.stale }
            try await fontQueue.commit(id) { self.stateQueue.sync { self.touch(hit.key) } }
            return .init(page: hit.page, cacheEvent: hit.event, requestedKey: key, matchedKey: hit.key)
        }
        let page = try await fontQueue.run(id, key: key, makeWork: {
            // 최초 참가자의 snapshot을 job이 retain한다. 참가자 해제와 물리 I/O 해제를 분리한다.
            lease.retain()
            let renderingSnapshot = StudioFontSupplySnapshot(identity: snapshot.identity, faces: snapshot.faces,
                omitted: snapshot.omitted, failure: snapshot.failure, read: snapshot.read, current: snapshot.current,
                release: {})
            return .init(render: {
                try Task.checkCancellation()
                guard try await snapshot.current(), try await current() else { throw HwpNativeFontSupplyError.stale }
                try Task.checkCancellation()
                let context = try HwpPreviewPDFRenderer.load(fileURL: request.fileURL, resolveExternalImages: false)
                return try await ExtensionFontRenderer.thumbnail(context: context,
                    maximumPixelSize: request.maximumPixelSize, policy: request.policy,
                    snapshot: renderingSnapshot, current: current)
            }, release: { await lease.release() })
        })
        guard try await snapshot.current(), try await current() else { throw HwpNativeFontSupplyError.stale }
        try await fontQueue.commit(id) {
            if page.diagnostics.fontSupplyFailure == nil {
                self.stateQueue.sync { self.store(page, for: immutableKey) }
            }
        }
        return .init(page: page, cacheEvent: .miss, requestedKey: key, matchedKey: key)
    }

    private func store(_ page: HwpRenderedPage, for key: HwpThumbnailCacheKey) {
        cachedPages[key] = page
        touch(key)

        while accessOrder.count > maxEntryCount || cachedPages.values.reduce(0, { $0 + $1.image.bytesPerRow * $1.image.height }) > maxBitmapBytes {
            let removedKey = accessOrder.removeFirst()
            cachedPages.removeValue(forKey: removedKey)
        }
    }

    private func touch(_ key: HwpThumbnailCacheKey) {
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
    }

    private func cachedPage(for requestedKey: HwpThumbnailCacheKey) -> HwpThumbnailCacheHit? {
        if let cached = cachedPages[requestedKey] {
            return HwpThumbnailCacheHit(
                key: requestedKey,
                page: cached,
                event: .exactHit
            )
        }

        var bestMatch: HwpThumbnailCacheHit?
        var bestArea = Int.max

        for (candidateKey, page) in cachedPages {
            guard
                candidateKey.path == requestedKey.path,
                candidateKey.modificationTime == requestedKey.modificationTime,
                candidateKey.fileSize == requestedKey.fileSize,
                candidateKey.renderSignature == requestedKey.renderSignature,
                candidateKey.documentIdentity == requestedKey.documentIdentity,
                candidateKey.pixelWidth >= requestedKey.pixelWidth,
                candidateKey.pixelHeight >= requestedKey.pixelHeight
            else {
                continue
            }

            let area = candidateKey.pixelWidth * candidateKey.pixelHeight
            if area < bestArea {
                bestArea = area
                bestMatch = HwpThumbnailCacheHit(
                    key: candidateKey,
                    page: page,
                    event: .largerBucketHit(
                        pixelWidth: candidateKey.pixelWidth,
                        pixelHeight: candidateKey.pixelHeight
                    )
                )
            }
        }

        return bestMatch
    }
}

/// FD의 실제 소유는 하나다. 최초 참가자와 공유 job이 각각 한 참조를 갖고 마지막 참조가 해제한다.
private final class HwpThumbnailSnapshotLease: @unchecked Sendable {
    let snapshot: StudioFontSupplySnapshot
    private let lock = NSLock()
    private var references = 1
    init(_ snapshot: StudioFontSupplySnapshot) { self.snapshot = snapshot }
    func retain() { lock.lock(); references += 1; lock.unlock() }
    private func drop() -> Bool {
        lock.lock(); defer { lock.unlock() }
        precondition(references > 0)
        references -= 1
        return references == 0
    }
    func release() async { if drop() { await snapshot.release() } }
}

/// callback/UI와 독립된 bounded FIFO. 상태 전이는 이 actor만 소유한다.
private actor HwpThumbnailFontQueue {
    struct Work {
        let render: @Sendable () async throws -> HwpRenderedPage
        let release: @Sendable () async -> Void
        init(render: @escaping @Sendable () async throws -> HwpRenderedPage,
             release: @escaping @Sendable () async -> Void) {
            #if ALHANGEUL_FONT_EXTENSION_PROBE
            let request = ExtensionFontPerformanceTrace.request.get()
            let details = ExtensionFontPerformanceTrace.details.get()
            self.render = {
                try await ExtensionFontPerformanceTrace.request.withValue(request) {
                    try await ExtensionFontPerformanceTrace.details.withValue(details) { try await render() }
                }
            }
            self.release = {
                await ExtensionFontPerformanceTrace.request.withValue(request) {
                    await ExtensionFontPerformanceTrace.details.withValue(details) { await release() }
                }
            }
            #else
            self.render = render; self.release = release
            #endif
        }
    }
    private final class Admission {
        let deadline: UInt64
        var error: Error?
        var started = false
        var completed = false
        var callerDone = false
        var ownsJob = false
        var jobID: UUID?
        var timer: Task<Void, Never>?
        #if ALHANGEUL_FONT_EXTENSION_PROBE
        var traceWait: ((Bool) -> Void)?
        var traceDeadline: (() -> Void)?
        #endif
        init(deadline: UInt64) { self.deadline = deadline }
    }
    private final class Job {
        let id = UUID()
        let key: HwpThumbnailCacheKey
        let anchor: UUID
        let work: Work
        var waiters: [UUID: CheckedContinuation<HwpRenderedPage, Error>] = [:]
        var worker: Task<Void, Never>?
        init(key: HwpThumbnailCacheKey, anchor: UUID, work: Work) {
            self.key = key; self.anchor = anchor; self.work = work
        }
    }
    private let waitNanoseconds: UInt64
    private var admissions: [UUID: Admission] = [:]
    private var jobs: [UUID: Job] = [:]
    private var byKey: [HwpThumbnailCacheKey: UUID] = [:]
    private var fifo: [UUID] = []
    private var running = 0

    init(waitNanoseconds: UInt64) { self.waitNanoseconds = waitNanoseconds }

    func admit(_ id: UUID) throws {
        try Task.checkCancellation()
        guard admissions.count < 16 else {
            #if ALHANGEUL_FONT_EXTENSION_PROBE
            ExtensionFontPerformanceTrace.busy("thumbnailAdmission")
            #endif
            throw StudioFontError.busy
        }
        let entry = Admission(deadline: DispatchTime.now().uptimeNanoseconds + waitNanoseconds)
        #if ALHANGEUL_FONT_EXTENSION_PROBE
        let request = ExtensionFontPerformanceTrace.request.get()
        let details = ExtensionFontPerformanceTrace.details.get()
        entry.traceDeadline = {
            ExtensionFontPerformanceTrace.withSynchronousContext(request: request, details: details) {
                ExtensionFontPerformanceTrace.busy("thumbnailWaitDeadline")
            }
        }
        #endif
        admissions[id] = entry
        let deadline = entry.deadline
        entry.timer = Task { [weak self] in
            let now = DispatchTime.now().uptimeNanoseconds
            do { if deadline > now { try await Task.sleep(nanoseconds: deadline - now) } }
            catch { return }
            await self?.expire(id)
        }
    }

    func check(_ id: UUID) throws {
        try Task.checkCancellation()
        guard let entry = admissions[id] else { throw CancellationError() }
        if !entry.started, !entry.completed, DispatchTime.now().uptimeNanoseconds >= entry.deadline { expire(id) }
        if let error = entry.error { throw error }
    }

    func commit(_ id: UUID, publish: @Sendable () -> Void) throws {
        try check(id)
        // 완료와 취소/deadline의 승자를 직렬화한 다음에만 bitmap을 게시한다.
        publish()
        admissions[id]?.completed = true
        admissions[id]?.timer?.cancel()
    }

    func run(_ id: UUID, key: HwpThumbnailCacheKey, makeWork: () -> Work) async throws -> HwpRenderedPage {
        try check(id)
        #if ALHANGEUL_FONT_EXTENSION_PROBE
        let started = DispatchTime.now().uptimeNanoseconds
        let traceID = ExtensionFontPerformanceTrace.request.get()
        let observer = ExtensionFontPerformanceTrace.details.get()
        admissions[id]?.traceWait = { success in
            ExtensionFontPerformanceTrace.withSynchronousContext(request: traceID, details: observer) {
                ExtensionFontPerformanceTrace.interval("thumbnailRenderWait", start: started, success: success, id: traceID)
            }
        }
        #endif
        return try await withCheckedThrowingContinuation { continuation in
            let job: Job
            if let existing = byKey[key], let value = jobs[existing] { job = value }
            else {
                job = Job(key: key, anchor: id, work: makeWork())
                jobs[job.id] = job; byKey[key] = job.id; fifo.append(job.id)
                admissions[id]?.ownsJob = true
            }
            job.waiters[id] = continuation
            admissions[id]?.jobID = job.id
            if job.worker != nil { markStarted(id) }
            startNext()
        }
    }

    private func markStarted(_ id: UUID) {
        #if ALHANGEUL_FONT_EXTENSION_PROBE
        admissions[id]?.traceWait?(true)
        admissions[id]?.traceWait = nil
        #endif
        admissions[id]?.started = true
        admissions[id]?.timer?.cancel()
    }

    private func startNext() {
        while running < 2, !fifo.isEmpty {
            let id = fifo.removeFirst()
            guard let job = jobs[id] else { continue }
            // timer의 실행이 지연돼도 단조 deadline을 넘긴 대기자는 시작하지 않는다.
            for waiter in Array(job.waiters.keys) {
                if let entry = admissions[waiter], DispatchTime.now().uptimeNanoseconds >= entry.deadline { expire(waiter) }
            }
            guard jobs[id] != nil, !job.waiters.isEmpty else { continue }
            running += 1
            for waiter in job.waiters.keys { markStarted(waiter) }
            let work = job.work
            job.worker = Task {
                let result: Result<HwpRenderedPage, Error>
                do { result = .success(try await work.render()) }
                catch { result = .failure(error) }
                // 실제 읽기·렌더와 job 참조 해제까지 끝나야 다음 슬롯을 연다.
                await work.release()
                self.finish(job.id, result: result)
            }
        }
    }

    private func finish(_ id: UUID, result: Result<HwpRenderedPage, Error>) {
        guard let job = jobs.removeValue(forKey: id) else { return }
        if byKey[job.key] == id { byKey.removeValue(forKey: job.key) }
        running -= 1
        admissions[job.anchor]?.ownsJob = false
        removeFinished(job.anchor)
        for (id, waiter) in job.waiters {
            admissions[id]?.jobID = nil
            waiter.resume(with: result)
        }
        startNext()
    }

    private func expire(_ id: UUID) {
        guard let entry = admissions[id], !entry.started, !entry.completed, entry.error == nil else { return }
        #if ALHANGEUL_FONT_EXTENSION_PROBE
        entry.traceDeadline?()
        #endif
        abort(id, error: StudioFontError.busy)
    }

    func cancel(_ id: UUID) { abort(id, error: CancellationError()) }

    private func abort(_ id: UUID, error: Error) {
        guard let entry = admissions[id], !entry.completed, entry.error == nil else { return }
        entry.error = error; entry.timer?.cancel()
        #if ALHANGEUL_FONT_EXTENSION_PROBE
        entry.traceWait?(false); entry.traceWait = nil
        #endif
        guard let jobID = entry.jobID, let job = jobs[jobID] else { return }
        job.waiters.removeValue(forKey: id)?.resume(throwing: error)
        entry.jobID = nil
        guard job.waiters.isEmpty else { return }
        // 취소된 실행 job에 새로운 동일 key 요청을 병합하지 않는다.
        if byKey[job.key] == jobID { byKey.removeValue(forKey: job.key) }
        if let worker = job.worker {
            worker.cancel()
            // anchor의 접수 한도·lease·물리 slot은 실제 종료까지 보유한다.
        } else {
            jobs.removeValue(forKey: jobID); fifo.removeAll { $0 == jobID }
            // 대기 job의 소유 참조 해제까지 anchor 접수 한도를 보유한다.
            Task {
                await job.work.release()
                self.releaseAnchor(job.anchor)
            }
        }
    }

    private func releaseAnchor(_ id: UUID) {
        admissions[id]?.ownsJob = false
        removeFinished(id)
    }

    func leave(_ id: UUID) {
        guard let entry = admissions[id] else { return }
        entry.callerDone = true; entry.timer?.cancel()
        removeFinished(id)
    }

    private func removeFinished(_ id: UUID) {
        guard let entry = admissions[id], entry.callerDone, !entry.ownsJob else { return }
        admissions.removeValue(forKey: id)
    }
}
