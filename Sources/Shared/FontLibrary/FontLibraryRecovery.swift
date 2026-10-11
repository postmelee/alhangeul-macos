import Darwin
import Foundation

struct FontLibraryRecoveryResult: Equatable, Sendable {
    var removedObjects = 0
    var removedLeases = 0
    var removedTransactions = 0
    var collectionDeferred = false
}

extension FontLibraryFileSystem {
    // 한 번 lease를 발급한 저장소에서 디렉터리가 사라지면 재생성/GC하지 않는다.
    // 라이브 reader의 디렉터리 유실을 빈 lease 목록으로 오인하지 않기 위한 표식이다.
    func leaseDirectory() throws -> FontLibraryDirectory {
        if let marker = try root.read("leases.version", limit: 16) {
            guard marker == Data([1]) else { throw FontLibraryError.corruptLease }
            return try root.existingChild("leases")
        }
        let directory = try root.child("leases")
        guard try directory.isEmpty() else { throw FontLibraryError.corruptLease }
        try root.writeNew("leases.version", data: Data([1]))
        try root.sync()
        return directory
    }
}

// 호출자는 전체 작업 동안 library.lock을 보유해야 한다.
// 알 수 없는 lease/잠금 오류가 있으면 모든 객체를 보존한다. 시간 기반 회수는 없다.
struct FontLibraryRecovery {
    static func validHash(_ value: String) -> Bool {
        value.count == 64 && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }

    static func collect(_ fs: FontLibraryFileSystem, manifest: FontLibraryManifest) throws -> FontLibraryRecoveryResult {
        var result = FontLibraryRecoveryResult()
        var retained = Set(manifest.entries.map { $0.object.sha256 })
        let leases = try fs.leaseDirectory()
        // 검사와 삭제를 분리한다. 손상된 뒤쪽 lease가 앞쪽 객체 회수에 영향을 주지 않도록 한다.
        var expired: [String] = []
        for name in try leases.names() {
            do {
                guard name.hasSuffix(".json"), let id = UUID(uuidString: String(name.dropLast(5))) else {
                    throw FontLibraryError.corruptLease
                }
                let fd = try leases.openFile(name, flags: O_RDONLY)
                defer { close(fd) }
                let data = try FontLibraryDirectory.readFile(fd, limit: 1024 * 1024)
                let record = try JSONDecoder().decode(FontLeaseRecord.self, from: data)
                guard record.schemaVersion == 1, record.sessionID == id,
                      record.objectHashes.count <= 4096, record.objectHashes.allSatisfy(validHash) else {
                    throw FontLibraryError.corruptLease
                }
                if flock(fd, LOCK_EX | LOCK_NB) == 0 {
                    // 동일 inode에 잠금을 획득했으므로 소유 reader는 없다. 새 reader는 writer 잠금에 막혀 있다.
                    expired.append(name)
                } else if errno == EWOULDBLOCK {
                    retained.formUnion(record.objectHashes)
                } else { throw FontLibraryError.io(errno) }
            } catch { result.collectionDeferred = true }
        }
        guard !result.collectionDeferred else { return result }
        for name in expired { try leases.remove(name); result.removedLeases += 1 }
        try leases.sync()
        for name in try fs.objects.names() {
            guard name.hasSuffix(".font"), validHash(String(name.dropLast(5))) else {
                result.collectionDeferred = true; continue
            }
            if retained.contains(String(name.dropLast(5))) { continue }
            // symlink/디렉터리/hardlink는 회수하지 않는다.
            do {
                let fd = try fs.objects.openFile(name, flags: O_RDONLY)
                close(fd)
            } catch { result.collectionDeferred = true; continue }
            try fs.objects.remove(name); result.removedObjects += 1
        }
        try fs.objects.sync()
        for name in try fs.staging.names() {
            guard UUID(uuidString: name) != nil else { result.collectionDeferred = true; continue }
            do {
                let transaction = try fs.staging.existingChild(name)
                let members = try transaction.names()
                guard members.allSatisfy({ ["object", "manifest"].contains($0) }) else {
                    result.collectionDeferred = true; continue
                }
                // 모든 자식의 형식을 먼저 검사한다. 임의 경로 재귀 삭제는 하지 않는다.
                for member in members { let fd = try transaction.openFile(member, flags: O_RDONLY); close(fd) }
                for member in members { try transaction.remove(member) }
                try transaction.sync()
                try fs.staging.remove(name, directory: true)
                result.removedTransactions += 1
            } catch { result.collectionDeferred = true }
        }
        try fs.staging.sync(); try fs.syncPublication()
        return result
    }
}
