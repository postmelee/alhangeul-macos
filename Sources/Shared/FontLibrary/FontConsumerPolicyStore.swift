import Darwin
import Foundation

/// 공유하는 것은 사용 설정뿐이다. 원본 위치/목록/bookmark는 각 프로세스가 소유한다.
struct FontConsumerPolicy: Codable, Equatable, Sendable {
    var version = 1
    let installedEnabled: Bool
    let revision: UUID
}

struct FontConsumerPolicyStore: Sendable {
    let rootURL: URL

    func read() throws -> FontConsumerPolicy {
        let directory: FontLibraryDirectory
        do { directory = try FontLibraryDirectory.openRoot(rootURL, createMissing: false).existingChild("consumer-policy") }
        catch FontLibraryError.io(let code) where code == ENOENT { return try decode(nil) }
        let fd: Int32
        do { fd = try directory.openFile("lock", flags: O_RDONLY) }
        catch FontLibraryError.io(let code) where code == ENOENT {
            guard try directory.read("pending", limit: 128) == nil,
                  try directory.read("policy.json", limit: 4096) == nil else { throw StudioFontError.unavailable }
            return try decode(nil)
        }
        defer { close(fd) }
        while flock(fd, LOCK_SH | LOCK_NB) != 0 {
            if errno == EINTR { continue }
            throw StudioFontError.busy
        }
        defer { _ = flock(fd, LOCK_UN) }
        return try {
            guard try directory.read("pending", limit: 128) == nil else { throw StudioFontError.unavailable }
            return try decode(directory.read("policy.json", limit: 4096))
        }()
    }

    /// private 저장과 공유 게시 사이의 실패/프로세스 종료는 pending으로 fail closed한다.
    /// 재시작 시 private 저장소의 실제 상태를 다시 게시하여 복구한다.
    func publish(enabled: Bool, savingPrivate: () throws -> Void = {}) throws {
        try withLock { directory in
            let pending = try directory.read("pending", limit: 128) != nil
            let previous = try? decode(directory.read("policy.json", limit: 4096))
            if !pending, previous?.installedEnabled == enabled {
                try savingPrivate()
                return
            }
            if !pending { try directory.writeNew("pending", data: Data("updating".utf8)); try directory.sync() }
            try savingPrivate()
            let policy = FontConsumerPolicy(installedEnabled: enabled, revision: UUID())
            let name = UUID().uuidString + ".json"
            defer { try? directory.remove(name) }
            try directory.writeNew(name, data: JSONEncoder().encode(policy))
            try directory.move(name, to: directory, name: "policy.json")
            try directory.sync()
            try directory.remove("pending")
            try directory.sync()
        }
    }

    func wrapping(_ persistence: InstalledFontPersistence) -> InstalledFontPersistence {
        .init(load: {
            let data = try persistence.load()
            let enabled = try data.map { data -> Bool in
                let state = try JSONDecoder().decode(InstalledFontSavedState.self, from: data)
                guard state.schema == 1, state.records.count <= InstalledFontSystem.maximumRecords,
                      state.grants.count <= 64, Set(state.records.map(\.id)).count == state.records.count else {
                    throw InstalledFontFailure.incompatibleStorage
                }
                return state.enabled
            } ?? false
            try publish(enabled: enabled)
            return data
        }, save: { data in
            let state = try JSONDecoder().decode(InstalledFontSavedState.self, from: data)
            try publish(enabled: state.enabled) { try persistence.save(data) }
        })
    }

    private func decode(_ data: Data?) throws -> FontConsumerPolicy {
        guard let data else {
            // 앱을 한 번도 실행하지 않은 경우 설치 글꼴 사용은 꺼져 있다.
            return .init(installedEnabled: false, revision: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
        }
        let value = try JSONDecoder().decode(FontConsumerPolicy.self, from: data)
        guard value.version == 1 else { throw StudioFontError.unavailable }
        return value
    }

    private func withLock<T>(exclusive: Bool = true, _ body: (FontLibraryDirectory) throws -> T) throws -> T {
        let directory = try FontLibraryDirectory.openRoot(rootURL).child("consumer-policy")
        let fd = try directory.openFile("lock", flags: O_RDWR | O_CREAT)
        defer { close(fd) }
        while flock(fd, (exclusive ? LOCK_EX : LOCK_SH) | LOCK_NB) != 0 {
            if errno == EINTR { continue }
            // 설정 갱신 중에는 확장을 무기한 대기시키지 않는다.
            throw StudioFontError.busy
        }
        defer { _ = flock(fd, LOCK_UN) }
        return try body(directory)
    }
}
