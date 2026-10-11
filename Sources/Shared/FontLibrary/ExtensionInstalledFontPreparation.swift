import Foundation

/// 알림 callback에서 actor 전달/지연 전에 증가시킨다.
final class InstalledFontChangeEpoch: @unchecked Sendable {
    private let lock = NSLock()
    private var value: UInt64 = 0
    func current() -> UInt64 { lock.lock(); defer { lock.unlock() }; return value }
    func invalidate() { lock.lock(); value &+= 1; lock.unlock() }
}

/// 확장만 사용하는 직렬 준비 소유자. 불변 목록은 공유하고 요청별 FD는 공유하지 않는다.
actor ExtensionInstalledFontPreparation {
    struct Ticket: Sendable {
        let state: InstalledFontSnapshot
        let signature: InstalledFontActiveSignature?
        let epoch: UInt64
        let policy: FontConsumerPolicy
        var identity: String { "\(state.generation):\(epoch):\(signature?.digest ?? "full-scan")" }
    }
    private struct Candidate: Sendable {
        let state: InstalledFontSnapshot
        let signature: InstalledFontActiveSignature?
        let scan: InstalledFontScan?
    }
    private struct Job {
        let id: UUID
        let policy: FontConsumerPolicy
        let epoch: UInt64
        var waiters: [UUID: CheckedContinuation<Ticket, Error>]
        var task: Task<Void, Never>?
    }
    private let catalog: InstalledFontCatalogService
    private let environment: InstalledFontEnvironment
    private let policyStore: FontConsumerPolicyStore
    private let changes: InstalledFontChangeEpoch
    private let observeChanges: Bool
    private var monitor: InstalledFontChangeMonitor?
    private var policy: FontConsumerPolicy?
    private var known: Ticket?
    private var job: Job?

    init(catalog: InstalledFontCatalogService, environment: InstalledFontEnvironment,
         policyStore: FontConsumerPolicyStore, changes: InstalledFontChangeEpoch, observeChanges: Bool) {
        self.catalog = catalog; self.environment = environment; self.policyStore = policyStore
        self.changes = changes; self.observeChanges = observeChanges
    }

    func prepare(_ requested: FontConsumerPolicy) async throws -> Ticket {
        try Task.checkCancellation()
        guard try policyStore.read() == requested else { throw StudioFontError.staleGeneration }
        if policy != requested {
            policy = requested; known = nil; changes.invalidate()
        }
        if !requested.installedEnabled {
            monitor = nil
            let state = try await catalog.setEnabled(false)
            try Task.checkCancellation()
            guard try policyStore.read() == requested else { throw StudioFontError.staleGeneration }
            // 명시적인 빈 설치 상태로 자동 prepare를 피한다. 관리 snapshot은 호출자마다 획득한다.
            return .init(state: .init(generation: state.generation, enabled: false, records: [],
                grantIssues: [], refreshFailure: nil, omittedFaceCount: 0), signature: nil, epoch: 0, policy: requested)
        }
        if observeChanges, monitor == nil {
            let changes = changes
            monitor = InstalledFontChangeMonitor { changes.invalidate() }
        }
        let epoch = changes.current()
        let waiter = UUID()
        let ticket = try await withTaskCancellationHandler(operation: {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Ticket, Error>) in
                if let active = job {
                    guard active.policy == requested, active.epoch == epoch, !active.waiters.isEmpty else {
                        continuation.resume(throwing: StudioFontError.staleGeneration); return
                    }
                    job?.waiters[waiter] = continuation
                } else {
                    start(waiter: waiter, continuation: continuation, policy: requested, epoch: epoch)
                }
            }
        }, onCancel: { Task { await self.cancel(waiter) } })
        try Task.checkCancellation()
        guard try policyStore.read() == ticket.policy, changes.current() == ticket.epoch else {
            throw StudioFontError.staleGeneration
        }
        return ticket
    }

    func current(_ ticket: Ticket) async throws -> Bool {
        guard try policyStore.read() == ticket.policy else { return false }
        if ticket.policy.installedEnabled, changes.current() != ticket.epoch { return false }
        let latest = try await prepare(ticket.policy)
        guard latest.state.generation == ticket.state.generation, latest.signature == ticket.signature,
              latest.epoch == ticket.epoch else { return false }
        guard try policyStore.read() == ticket.policy else { return false }
        return !ticket.policy.installedEnabled || changes.current() == ticket.epoch
    }

    func pendingRequestCount() -> Int { job?.waiters.count ?? 0 }

    private func start(waiter: UUID, continuation: CheckedContinuation<Ticket, Error>,
                       policy: FontConsumerPolicy, epoch: UInt64) {
        let id = UUID(), environment = environment, catalog = catalog, known = known
        job = .init(id: id, policy: policy, epoch: epoch, waiters: [waiter: continuation])
        let task = Task {
            let state = await catalog.snapshot()
            let operation: @Sendable () throws -> Candidate = {
                try Task.checkCancellation()
                let before = try environment.activeSignature?()
                if let known, let before, before.reusable, known.signature == before, known.epoch == epoch,
                   known.state.generation == state.generation, state.refreshFailure == nil, state.enabled {
                    return .init(state: state, signature: before, scan: nil)
                }
                let scan = try environment.scan([]) // 확장은 HostApp grant를 전달하지 않는다.
                try Task.checkCancellation()
                let after = try environment.activeSignature?()
                guard before == after else { throw StudioFontError.staleGeneration }
                return .init(state: state, signature: after, scan: scan)
            }
            #if ALHANGEUL_FONT_EXTENSION_PROBE
            let request = ExtensionFontPerformanceTrace.request.get(), observer = ExtensionFontPerformanceTrace.details.get()
            let worker = Task.detached(priority: .utility) {
                try ExtensionFontPerformanceTrace.withSynchronousContext(request: request, details: observer, operation: operation)
            }
            #else
            let worker = Task.detached(priority: .utility, operation: operation)
            #endif
            let result: Result<Candidate, Error>
            do {
                let value = try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
                result = .success(value)
            } catch { result = .failure(error) }
            await finish(id, result: result)
        }
        job?.task = task
    }

    private func finish(_ id: UUID, result: Result<Candidate, Error>) async {
        guard let active = job, active.id == id else { return }
        let outcome: Result<Ticket, Error>
        do {
            guard !active.waiters.isEmpty, try policyStore.read() == active.policy,
                  changes.current() == active.epoch else { throw StudioFontError.staleGeneration }
            let candidate = try result.get()
            let state: InstalledFontSnapshot
            if let scan = candidate.scan {
                _ = try await catalog.setEnabled(true)
                guard try policyStore.read() == active.policy, changes.current() == active.epoch,
                      job?.waiters.isEmpty == false else { throw StudioFontError.staleGeneration }
                state = try await catalog.acceptExtensionScan(scan)
            } else {
                state = await catalog.snapshot()
                guard state.generation == candidate.state.generation else { throw StudioFontError.staleGeneration }
            }
            guard state.enabled, try policyStore.read() == active.policy, changes.current() == active.epoch,
                  job?.waiters.isEmpty == false else { throw StudioFontError.staleGeneration }
            let ticket = Ticket(state: state, signature: candidate.signature, epoch: active.epoch, policy: active.policy)
            known = ticket
            outcome = .success(ticket)
        } catch {
            known = nil
            // OFF 등 새 정책 상태를 이전 준비 실패로 덮어쓰지 않는다.
            if job?.waiters.isEmpty == false, policy == active.policy,
               (try? policyStore.read()) == active.policy {
                await catalog.failPreparation(error)
            }
            outcome = .failure(error)
        }
        guard let completed = job, completed.id == id else { return }
        job = nil // 실제 worker가 종료된 뒤에만 다음 준비를 허용한다.
        for continuation in completed.waiters.values { continuation.resume(with: outcome) }
    }

    private func cancel(_ waiter: UUID) {
        guard let continuation = job?.waiters.removeValue(forKey: waiter) else { return }
        continuation.resume(throwing: CancellationError())
        if job?.waiters.isEmpty == true { job?.task?.cancel() }
    }
}
