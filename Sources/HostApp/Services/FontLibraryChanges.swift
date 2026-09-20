import Foundation

actor FontLibraryChanges {
    private var revision: UInt64 = 0
    private var subscribers: [UUID: AsyncStream<UInt64>.Continuation] = [:]
    func publish(_ generation: UInt64) {
        guard generation > revision else { return }
        revision = generation
        for continuation in subscribers.values { continuation.yield(revision) }
    }
    func updates() -> AsyncStream<UInt64> {
        let id = UUID()
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            subscribers[id] = continuation
            continuation.yield(revision)
            continuation.onTermination = { [weak self] _ in Task { await self?.remove(id) } }
        }
    }
    private func remove(_ id: UUID) { subscribers[id] = nil }
}
