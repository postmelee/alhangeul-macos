import CoreText
import Foundation

struct InstalledFontPersistence: Sendable {
    let load: @Sendable () throws -> Data?
    let save: @Sendable (Data) throws -> Void

    static func file(at root: URL) -> Self {
        let file = root.appendingPathComponent("installed-fonts-v1.json")
        return .init(load: {
            guard FileManager.default.fileExists(atPath: file.path) else { return nil }
            let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
            guard size <= 32 * 1024 * 1024 else { throw InstalledFontFailure.incompatibleStorage }
            return try Data(contentsOf: file)
        }, save: { data in
            guard data.count <= 32 * 1024 * 1024 else { throw InstalledFontFailure.catalogLimit }
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try data.write(to: file, options: .atomic)
        })
    }
}

// CoreText의 process scope와 session/persistent scope 알림을 모두 받는다.
private final class InstalledFontChangeMonitor: @unchecked Sendable {
    private let local: NSObjectProtocol
    private let distributed: NSObjectProtocol
    init(changed: @escaping @Sendable () -> Void) {
        let name = Notification.Name(kCTFontManagerRegisteredFontsChangedNotification as String)
        local = NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { _ in changed() }
        distributed = DistributedNotificationCenter.default().addObserver(forName: name, object: nil, queue: nil) { _ in changed() }
    }
    deinit {
        NotificationCenter.default.removeObserver(local)
        DistributedNotificationCenter.default().removeObserver(distributed)
    }
}

// MainActor와 분리된 직렬 metadata/설정 소유자. bytes는 보존하지 않고 진행 중 요청만 합친다.
actor InstalledFontCatalogService {
    private let environment: InstalledFontEnvironment
    private let persistence: InstalledFontPersistence
    private let observeChanges: Bool
    private var saved: InstalledFontSavedState
    private var generation = UUID()
    private var prepared = false
    private var omittedFaceCount = 0
    private var grantIssues: [InstalledFontGrantIssue] = []
    private var refreshFailure: InstalledFontFailure?
    private var observers: [UUID: AsyncStream<InstalledFontSnapshot>.Continuation] = [:]
    private var monitor: InstalledFontChangeMonitor?
    private var refreshTask: Task<Void, Never>?
    private struct Pending {
        let token: UUID
        let task: Task<InstalledFontRead, Error>
    }
    private var pending: [String: Pending] = [:]

    init(persistence: InstalledFontPersistence, environment: InstalledFontEnvironment = InstalledFontSystem().environment,
         observeChanges: Bool = true) throws {
        self.persistence = persistence
        self.environment = environment
        self.observeChanges = observeChanges
        do {
            if let data = try persistence.load() {
                let decoded = try JSONDecoder().decode(InstalledFontSavedState.self, from: data)
                guard decoded.schema == 1, decoded.records.count <= InstalledFontSystem.maximumRecords,
                      decoded.grants.count <= 64, Set(decoded.records.map(\.id)).count == decoded.records.count else {
                    throw InstalledFontFailure.incompatibleStorage
                }
                saved = decoded
            } else { saved = .init(schema: 1, enabled: false, records: [], grants: []) }
        } catch let error as InstalledFontFailure { throw error }
        catch { throw InstalledFontFailure.storage }
    }

    static func live() throws -> InstalledFontCatalogService {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw InstalledFontFailure.storage
        }
        return try .init(persistence: .file(at: support.appendingPathComponent("Alhangeul/InstalledFonts", isDirectory: true)))
    }

    func snapshot() -> InstalledFontSnapshot {
        .init(generation: generation, enabled: saved.enabled, records: saved.records,
              grantIssues: grantIssues, refreshFailure: prepared ? refreshFailure : .notPrepared, omittedFaceCount: omittedFaceCount)
    }

    func updates() -> AsyncStream<InstalledFontSnapshot> {
        let id = UUID()
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            observers[id] = continuation
            continuation.yield(snapshot())
            continuation.onTermination = { [weak self] _ in Task { await self?.removeObserver(id) } }
        }
    }
    private func removeObserver(_ id: UUID) { observers.removeValue(forKey: id) }

    @discardableResult
    func prepare() throws -> InstalledFontSnapshot {
        if observeChanges, monitor == nil {
            monitor = InstalledFontChangeMonitor { [weak self] in Task { await self?.scheduleRefresh() } }
        }
        return try refresh()
    }

    // UI 수동 새로고침, 시작 시 재검사, CoreText 알림은 같은 경로를 사용한다.
    @discardableResult
    func refresh(retryIDs: Set<String> = []) throws -> InstalledFontSnapshot {
        do {
            let scan = try environment.scan(saved.grants)
            let previousRecords = Dictionary(uniqueKeysWithValues: saved.records.map { ($0.id, $0) })
            // 성공한 스캔의 현재 목록만 보존한다. 제거된 원본은 generation 변경과
            // 알 수 없는 ID의 inactive 응답으로 차단하며 과거 이력을 누적하지 않는다.
            var fresh: [String: InstalledFontRecord] = [:]
            for var record in scan.records {
                if let previous = previousRecords[record.id], previous.stamp == record.stamp,
                   record.failure == nil, !retryIDs.contains(record.id),
                   let failure = previous.failure, [.corrupt, .unsupported, .permissionDenied].contains(failure) {
                    record.failure = failure
                }
                fresh[record.id] = record
            }
            guard fresh.count <= InstalledFontSystem.maximumRecords else { throw InstalledFontFailure.catalogLimit }
            let active = scan.records.filter { $0.failure != .inactive }
            let groups = Dictionary(grouping: active, by: { $0.postScriptName.lowercased() })
            for group in groups.values where Set(group.map(\.id)).count > 1 {
                for record in group { fresh[record.id]?.failure = .conflict }
            }
            var next = saved
            next.records = fresh.values.sorted { $0.id < $1.id }
            let changed = !prepared || next.records != saved.records || scan.grantIssues != grantIssues || scan.omittedFaceCount != omittedFaceCount || refreshFailure != nil
            if changed { try store(next) }
            saved = next; omittedFaceCount = scan.omittedFaceCount; grantIssues = scan.grantIssues; refreshFailure = nil; prepared = true
            if changed { invalidate() }
            return snapshot()
        } catch {
            refreshFailure = InstalledFontSystem.failure(error)
            if !(error is InstalledFontFailure) { refreshFailure = .storage }
            prepared = true
            invalidate()
            throw refreshFailure!
        }
    }

    @discardableResult
    func setEnabled(_ enabled: Bool) throws -> InstalledFontSnapshot {
        guard saved.enabled != enabled else { return snapshot() }
        var next = saved; next.enabled = enabled
        try store(next); saved = next
        invalidate()
        return snapshot()
    }

    // NSOpenPanel 등에서 사용자가 직접 선택한 native URL만 전달한다. 자동 탐색 URL로 만들지 않는다.
    @discardableResult
    func grantAccess(to selectedURL: URL, replacing grantID: UUID? = nil) throws -> InstalledFontSnapshot {
        guard saved.grants.count < 64 || saved.grants.contains(where: { $0.id == grantID }) else {
            throw InstalledFontFailure.catalogLimit
        }
        let bookmark: Data
        do { bookmark = try environment.makeBookmark(selectedURL) }
        catch { throw InstalledFontFailure.permissionDenied }
        var next = saved
        let grant = InstalledFontGrant(id: grantID ?? UUID(), bookmark: bookmark)
        next.grants.removeAll { $0.id == grant.id }; next.grants.append(grant)
        try store(next); saved = next
        invalidate()
        return try refresh(retryIDs: Set(saved.records.map(\.id)))
    }

    @discardableResult
    func revokeAccess(_ id: UUID) throws -> InstalledFontSnapshot {
        var next = saved; next.grants.removeAll { $0.id == id }
        try store(next); saved = next
        invalidate()
        return try refresh()
    }

    func readResource(_ id: String, expectedGeneration: UUID) async throws -> InstalledFontResource {
        try Task.checkCancellation()
        guard prepared else { throw InstalledFontFailure.notPrepared }
        guard saved.enabled else { throw InstalledFontFailure.disabled }
        guard refreshFailure == nil else { throw refreshFailure! }
        guard generation == expectedGeneration else { throw InstalledFontFailure.staleGeneration }
        guard let record = saved.records.first(where: { $0.id == id }) else { throw InstalledFontFailure.inactive }
        if let failure = record.failure { throw failure }
        let operation: Pending
        if let existing = pending[id] { operation = existing }
        else {
            guard pending.count < 2 else { throw InstalledFontFailure.busy }
            let environment = environment, grants = saved.grants
            operation = Pending(token: UUID(), task: Task { try await environment.read(record, grants) })
            pending[id] = operation
        }
        defer { if pending[id]?.token == operation.token { pending.removeValue(forKey: id) } }
        do {
            let result = try await operation.task.value
            try Task.checkCancellation()
            guard generation == expectedGeneration, saved.enabled else { throw InstalledFontFailure.staleGeneration }
            return .init(resourceID: id, generation: generation, data: result.data, face: result.face)
        } catch {
            try Task.checkCancellation()
            guard generation == expectedGeneration else { throw InstalledFontFailure.staleGeneration }
            let failure = InstalledFontSystem.failure(error)
            if failure != .cancelled {
                var next = saved
                if let index = next.records.firstIndex(where: { $0.id == id }) { next.records[index].failure = failure }
                do { try store(next); saved = next }
                catch { refreshFailure = .storage }
                invalidate()
            }
            throw failure
        }
    }

    // 알림이 누락되어도 readResource의 실제 원본/활성 상태 검사가 마지막 방어선이다.
    func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 200_000_000); try Task.checkCancellation() }
            catch { return }
            _ = try? await self?.refresh()
        }
    }

    func stopMonitoring() {
        monitor = nil; refreshTask?.cancel(); refreshTask = nil
    }

    private func store(_ next: InstalledFontSavedState) throws {
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            try persistence.save(encoder.encode(next))
        } catch let error as InstalledFontFailure { throw error }
        catch { throw InstalledFontFailure.storage }
    }
    private func invalidate() {
        generation = UUID()
        pending.values.forEach { $0.task.cancel() }; pending.removeAll()
        for continuation in observers.values { continuation.yield(snapshot()) }
    }
    deinit {
        refreshTask?.cancel()
        pending.values.forEach { $0.task.cancel() }
        observers.values.forEach { $0.finish() }
    }
}
