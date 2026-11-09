import CryptoKit
import Foundation

/// 정상 저장 및 parser 재검증을 마친 bytes만 입장한다. 화면/원본/편집 metadata는 입장하지 않는다.
@MainActor
final class DocumentRecoveryCopies {
    static let shared = DocumentRecoveryCopies()
    struct Copy {
        let id = UUID()
        let data: Data
        let format: DocumentSaveFormat
        let sourceURL: URL
        let savedAt: Date
        let admittedAt: TimeInterval
        let loadID: Int
        let epoch: Int
        let revision: Int
        let digest: Data
    }
    struct Lease { let id: UUID; let copy: Copy }
    private var copies: [UUID: Copy] = [:]
    private var leases: [UUID: Copy] = [:]
    private var expiryTask: Task<Void, Never>?
    private let now: () -> TimeInterval
    let ttl: TimeInterval
    let perWindowLimit: Int
    let totalLimit: Int

    init(ttl: TimeInterval = 30 * 60, perWindowLimit: Int = 32 * 1024 * 1024,
         totalLimit: Int = 64 * 1024 * 1024,
         now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.ttl = ttl; self.perWindowLimit = perWindowLimit; self.totalLimit = totalLimit; self.now = now
    }

    var retainedByteCount: Int {
        var unique = copies.values.reduce(into: [UUID: Copy]()) { $0[$1.id] = $1 }
        for copy in leases.values { unique[copy.id] = copy }
        return unique.values.reduce(0) { $0 + $1.data.count }
    }

    @discardableResult
    func admit(owner: UUID, data: Data, format: DocumentSaveFormat, sourceURL: URL,
               sourceProtection: DocumentSourceProtection, conversion: DocumentSaveConversionIntent,
               parserValidated: Bool, sessionIsCurrent: Bool, savedAt: Date = Date(),
               loadID: Int, epoch: Int, revision: Int) -> Bool {
        prune()
        guard sourceProtection == .plain, conversion == .none, parserValidated, sessionIsCurrent,
              !data.isEmpty, data.count <= perWindowLimit, format.matchesPayloadSignature(data) else { return false }
        let prior = copies.removeValue(forKey: owner)
        guard retainedByteCount + data.count <= totalLimit else {
            copies[owner] = prior
            return false
        }
        copies[owner] = Copy(data: data, format: format, sourceURL: sourceURL,
            savedAt: savedAt, admittedAt: now(), loadID: loadID, epoch: epoch, revision: revision,
            digest: Data(SHA256.hash(data: data)))
        scheduleExpiry()
        return true
    }

    private func scheduleExpiry() {
        expiryTask?.cancel()
        guard let next = copies.values.map({ $0.admittedAt + ttl }).min() else { expiryTask = nil; return }
        let delay = max(0.001, next - now())
        expiryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(min(delay, 1800) * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            self.prune(); self.scheduleExpiry()
        }
    }

    func copy(for owner: UUID) -> Copy? { prune(); return copies[owner] }
    func acquire(for owner: UUID) -> Lease? {
        guard let copy = copy(for: owner) else { return nil }
        let lease = Lease(id: UUID(), copy: copy)
        leases[lease.id] = copy
        return lease
    }
    func release(_ lease: Lease) { leases[lease.id] = nil; prune() }
    func remove(owner: UUID) { copies[owner] = nil }
    private func prune() { let time = now(); copies = copies.filter { time - $0.value.admittedAt < ttl } }
}

enum DocumentRecoveryExport {
    static func write(_ copy: DocumentRecoveryCopies.Copy, to destination: URL, currentSource: URL?) throws {
        let destinations = [copy.sourceURL, currentSource].compactMap { $0 }
        guard !destinations.contains(where: { sameFile($0, destination) }),
              DocumentSaveFormat(url: destination) == copy.format,
              Data(SHA256.hash(data: copy.data)) == copy.digest else { throw Failure.invalidDestination }
        // RENAME_EXCL은 기존 파일/별칭/링크 및 게시 직전 생성 경쟁에서도 덮어쓰지 않는다.
        try DocumentSaveWritePolicy.write(data: copy.data, to: destination, allowOverwrite: false)
    }
    private static func sameFile(_ a: URL, _ b: URL) -> Bool {
        a.standardizedFileURL.resolvingSymlinksInPath().path.compare(
            b.standardizedFileURL.resolvingSymlinksInPath().path, options: .caseInsensitive) == .orderedSame
    }
    enum Failure: LocalizedError {
        case invalidDestination
        var errorDescription: String? { "원본과 다른 새 파일 이름과 같은 문서 형식을 선택해 주세요." }
    }
}
