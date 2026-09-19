import Foundation

// 선택 화면과 worker가 같은 session을 보유한다. close 이후에도 진행 중 lease는
// scope를 유지하며 마지막 worker가 끝났을 때만 해제한다.
final class FontImportSourceSession: @unchecked Sendable {
    let urls: [URL]
    private let access: FontLibrarySourceAccess
    private let lock = NSLock()
    private var started: [URL]
    private var users = 0
    private var closing = false

    init(urls: [URL], access: FontLibrarySourceAccess = .securityScoped) {
        var seen = Set<URL>()
        self.urls = urls.filter { seen.insert($0).inserted }
        self.access = access
        self.started = self.urls.filter { access.start($0) }
    }

    func acquire() -> Lease? {
        lock.lock(); defer { lock.unlock() }
        guard !closing else { return nil }
        users += 1
        return Lease(session: self)
    }

    func close() {
        lock.lock()
        closing = true
        let releasing = takeReleasable()
        lock.unlock()
        releasing.reversed().forEach(access.stop)
    }

    private func finish() {
        lock.lock()
        users -= 1
        let releasing = takeReleasable()
        lock.unlock()
        releasing.reversed().forEach(access.stop)
    }

    private func takeReleasable() -> [URL] {
        guard closing && users == 0 else { return [] }
        let releasing = started
        started = []
        return releasing
    }

    deinit { started.reversed().forEach(access.stop) }

    final class Lease: Sendable {
        private let session: FontImportSourceSession
        fileprivate init(session: FontImportSourceSession) { self.session = session }
        deinit { session.finish() }
    }
}
