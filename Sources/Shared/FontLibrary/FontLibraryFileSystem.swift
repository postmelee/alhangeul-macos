import Darwin
import Foundation

// 디렉터리 FD에 상대적으로 접근한다. 관리 경로의 symlink를 따라가지 않는다.
final class FontLibraryDirectory {
    let descriptor: Int32
    init(descriptor: Int32) { self.descriptor = descriptor }
    deinit { close(descriptor) }

    static func openRoot(_ url: URL) throws -> FontLibraryDirectory {
        guard url.isFileURL, url.path.hasPrefix("/") else { throw FontLibraryError.unsafePath }
        var directory = FontLibraryDirectory(descriptor: open("/", O_SEARCH | O_CLOEXEC))
        guard directory.descriptor >= 0 else { throw FontLibraryError.io(errno) }
        var components = Array(url.pathComponents.dropFirst())
        // Foundation의 임시 URL은 /private/var를 /var로 표시할 수 있다.
        // macOS의 root 소유 표준 별칭만 치환하고 그 외 symlink는 허용하지 않는다.
        if let first = components.first, ["var", "tmp", "etc"].contains(first) {
            components.insert("private", at: 0)
        }
        for (index, part) in components.enumerated() {
            directory = try directory.child(part, searchOnly: index < components.count - 1)
        }
        return directory
    }

    private func validate(_ name: String) throws {
        guard !name.isEmpty, name != ".", name != "..", !name.contains("/"), !name.contains("\0") else {
            throw FontLibraryError.unsafePath
        }
    }

    func child(_ name: String, searchOnly: Bool = false) throws -> FontLibraryDirectory {
        try validate(name)
        let created = mkdirat(descriptor, name, 0o700) == 0
        if !created && errno != EEXIST { throw FontLibraryError.directoryIO(operation: "mkdir", code: errno) }
        let access = searchOnly ? O_SEARCH : (O_RDONLY | O_DIRECTORY)
        let fd = openat(descriptor, name, access | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { throw FontLibraryError.directoryIO(operation: "open", code: errno) }
        let child = FontLibraryDirectory(descriptor: fd)
        if created { try sync() }
        return child
    }

    func openFile(_ name: String, flags: Int32, mode: mode_t = 0o600) throws -> Int32 {
        try validate(name)
        let fd = openat(descriptor, name, flags | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK, mode)
        guard fd >= 0 else { throw FontLibraryError.io(errno) }
        var info = stat()
        guard fstat(fd, &info) == 0 else { let error = errno; close(fd); throw FontLibraryError.io(error) }
        guard info.st_mode & S_IFMT == S_IFREG, info.st_nlink == 1 else {
            close(fd); throw FontLibraryError.notRegularFile
        }
        return fd
    }

    func read(_ name: String, limit: Int) throws -> Data? {
        let fd: Int32
        do { fd = try openFile(name, flags: O_RDONLY) }
        catch FontLibraryError.io(let code) where code == ENOENT { return nil }
        defer { close(fd) }
        return try Self.readFile(fd, limit: limit)
    }

    static func readFile(_ fd: Int32, limit: Int, cancelled: () -> Bool = { false },
                         didRead: (Int) -> Void = { _ in }) throws -> Data {
        var before = stat()
        guard fstat(fd, &before) == 0 else { throw FontLibraryError.io(errno) }
        guard before.st_mode & S_IFMT == S_IFREG else { throw FontLibraryError.notRegularFile }
        guard before.st_size >= 0, before.st_size <= limit else { throw FontLibraryError.inputLimitExceeded }
        var data = Data()
        data.reserveCapacity(Int(before.st_size))
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        while true {
            if cancelled() { throw FontLibraryError.cancelled }
            let length = Darwin.read(fd, &buffer, min(buffer.count, limit - data.count + 1))
            if length < 0 {
                if errno == EINTR { continue }
                throw FontLibraryError.io(errno)
            }
            if length == 0 { break }
            didRead(length)
            guard length <= limit - data.count else { throw FontLibraryError.inputLimitExceeded }
            data.append(contentsOf: buffer.prefix(length))
        }
        var after = stat()
        guard fstat(fd, &after) == 0 else { throw FontLibraryError.io(errno) }
        guard data.count == before.st_size, before.st_size == after.st_size,
              before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec,
              before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec,
              before.st_ctimespec.tv_sec == after.st_ctimespec.tv_sec,
              before.st_ctimespec.tv_nsec == after.st_ctimespec.tv_nsec else {
            throw FontLibraryError.inputChanged
        }
        return data
    }

    func writeNew(_ name: String, data: Data, written: () throws -> Void = {}, synced: () throws -> Void = {}) throws {
        let fd = try openFile(name, flags: O_WRONLY | O_CREAT | O_EXCL)
        defer { close(fd) }
        try data.withUnsafeBytes { bytes in
            var offset = 0
            while offset < bytes.count {
                let size = Darwin.write(fd, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
                if size < 0 {
                    if errno == EINTR { continue }
                    throw FontLibraryError.io(errno)
                }
                guard size > 0 else { throw FontLibraryError.io(EIO) }
                offset += size
            }
        }
        try written()
        // fsync에 더해 장치 cache flush를 요청한다. 미지원/실패를 성공으로 바꾸지 않는다.
        guard fsync(fd) == 0, fcntl(fd, F_FULLFSYNC) == 0 else { throw FontLibraryError.io(errno) }
        try synced()
    }

    func move(_ source: String, to directory: FontLibraryDirectory, name: String, replacing: Bool = true) throws {
        try validate(source); try directory.validate(name)
        guard renameatx_np(descriptor, source, directory.descriptor, name, replacing ? 0 : UInt32(RENAME_EXCL)) == 0 else {
            throw FontLibraryError.io(errno)
        }
    }

    func remove(_ name: String, directory: Bool = false) throws {
        try validate(name)
        if unlinkat(descriptor, name, directory ? AT_REMOVEDIR : 0) != 0 && errno != ENOENT {
            throw FontLibraryError.io(errno)
        }
    }

    func sync() throws {
        // O_SEARCH로 연 상위 경로도 실제로 생성한 자식의 부모만 동기화한다.
        let fd = openat(descriptor, ".", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { throw FontLibraryError.directoryIO(operation: "openForSync", code: errno) }
        defer { close(fd) }
        guard fsync(fd) == 0 else { throw FontLibraryError.directoryIO(operation: "sync", code: errno) }
    }

    func isEmpty() throws -> Bool {
        let copy = dup(descriptor)
        guard copy >= 0 else { throw FontLibraryError.io(errno) }
        guard let stream = fdopendir(copy) else { close(copy); throw FontLibraryError.io(errno) }
        defer { closedir(stream) }
        rewinddir(stream)
        while true {
            errno = 0
            guard let entry = readdir(stream) else {
                guard errno == 0 else { throw FontLibraryError.io(errno) }
                return true
            }
            let name = withUnsafePointer(to: &entry.pointee.d_name) {
                $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXNAMLEN) + 1) { String(cString: $0) }
            }
            if name != "." && name != ".." { return false }
        }
    }
}

// 상태 접근은 모두 NSLock으로 직렬화한다.
final class FontImportCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    func cancel() { lock.lock(); value = true; lock.unlock() }
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return value }
}

final class FontLibraryFileSystem {
    let root: FontLibraryDirectory
    let objects: FontLibraryDirectory
    let staging: FontLibraryDirectory
    private let lockFD: Int32

    init(rootURL: URL) throws {
        root = try FontLibraryDirectory.openRoot(rootURL)
        // macOS에서 같은 파일의 동시 O_CREAT가 ENOENT를 반환하는 경합을 피한다.
        // 한 writer만 생성하고 나머지는 이미 생성된 inode를 연다. lock 파일은 교체하지 않는다.
        do { lockFD = try root.openFile("library.lock", flags: O_RDWR | O_CREAT | O_EXCL) }
        catch FontLibraryError.io(let code) where code == EEXIST {
            lockFD = try root.openFile("library.lock", flags: O_RDWR)
        }
        // 초기화 디렉터리는 멱등하게 생성하며 실제 manifest 처리는 writer 잠금 아래 수행한다.
        do {
            objects = try root.child("objects")
            staging = try root.child("staging")
        } catch { close(lockFD); throw error }
    }
    deinit { close(lockFD) }

    func withLock<T>(cancelled: () -> Bool = { false }, _ body: () throws -> T) throws -> T {
        while flock(lockFD, LOCK_EX | LOCK_NB) != 0 {
            let code = errno
            guard code == EWOULDBLOCK || code == EINTR else { throw FontLibraryError.directoryIO(operation: "lock", code: code) }
            if cancelled() { throw FontLibraryError.cancelled }
            usleep(10_000)
        }
        defer { flock(lockFD, LOCK_UN) }
        if cancelled() { throw FontLibraryError.cancelled }
        return try body()
    }

    func initializationMarked() throws -> Bool {
        var value: UInt8 = 0
        let count = pread(lockFD, &value, 1, 0)
        guard count >= 0 else { throw FontLibraryError.io(errno) }
        return count != 0
    }

    func markInitialized() throws {
        var value: UInt8 = 1
        guard pwrite(lockFD, &value, 1, 0) == 1,
              fsync(lockFD) == 0, fcntl(lockFD, F_FULLFSYNC) == 0 else {
            throw FontLibraryError.io(errno)
        }
        try root.sync()
    }

    func syncPublication() throws {
        try root.sync()
        guard fsync(lockFD) == 0, fcntl(lockFD, F_FULLFSYNC) == 0 else { throw FontLibraryError.io(errno) }
    }
}
