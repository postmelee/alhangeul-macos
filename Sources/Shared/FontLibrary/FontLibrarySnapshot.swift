import CryptoKit
import Darwin
import Foundation

// 원본 URL/bookmark를 노출하지 않는다. 권한 판단과 renderer 적용은 소비자 책임이다.
struct FontSnapshotResource: Codable, Equatable, Sendable {
    let id: String
    let object: FontObject
    let face: FontFace
    let axes: [String: Double]
    let usageEvidence: FontUsageEvidence
}

struct FontLeaseRecord: Codable {
    let schemaVersion: Int
    let sessionID: UUID
    let objectHashes: [String]
}

// 불변 선택과 잠금 FD의 수명을 묶는다. NSLock은 release/read/deinit 경합을 직렬화한다.
// 프로세스 PID/시각 추정 대신 kernel flock의 실제 소유 여부를 사용한다.
final class FontLibrarySnapshot: @unchecked Sendable {
    let generation: UInt64
    let policyVersion = 1
    let digest: String
    let resources: [FontSnapshotResource]
    private let rootPath: String
    private let lock = NSLock()
    private var descriptor: Int32

    init(generation: UInt64, resources: [FontSnapshotResource], rootPath: String, descriptor: Int32) throws {
        self.generation = generation
        self.resources = resources
        self.rootPath = rootPath
        self.descriptor = descriptor
        struct Identity: Encodable {
            let policyVersion: Int
            let resources: [FontSnapshotResource]
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let bytes = try encoder.encode(Identity(policyVersion: 1, resources: resources))
        digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }

    deinit { closeLease() }

    func withLease<T>(rootPath: String, _ body: () throws -> T) throws -> T {
        lock.lock(); defer { lock.unlock() }
        guard self.rootPath == rootPath else { throw FontLibraryError.snapshotLibraryMismatch }
        guard descriptor >= 0 else { throw FontLibraryError.releasedSnapshot }
        return try body()
    }

    func release(rootPath: String) throws {
        lock.lock(); defer { lock.unlock() }
        guard self.rootPath == rootPath else { throw FontLibraryError.snapshotLibraryMismatch }
        if descriptor >= 0 { close(descriptor); descriptor = -1 }
    }

    private func closeLease() {
        lock.lock(); defer { lock.unlock() }
        if descriptor >= 0 { close(descriptor); descriptor = -1 }
    }
}
