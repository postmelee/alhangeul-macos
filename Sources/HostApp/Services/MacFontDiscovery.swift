import Foundation
import Darwin

struct MacFontDiscoveryLimits: Sendable {
    var applicationDepth = 4
    var fontDepth = 32
    var maximumVisited = 20_000
    var maximumCandidates = 4_096
}

struct MacFontSource: Identifiable, Equatable, Sendable {
    let id: URL
    let name: String
    let version: String?
    let kind: FontSourceKind
}

struct MacFontCandidate: Identifiable, Sendable {
    let id: UUID
    let url: URL
    let byteCount: Int
    let source: MacFontSource

    var importCandidate: FontImportCandidate {
        .init(sourceURL: url, id: id, sourceKind: source.kind)
    }
}

struct MacFontDiscoveryNotice: Equatable, Sendable {
    enum Reason: Equatable, Sendable {
        case missing, accessDenied, readFailure, unsafePath, depthLimit, visitLimit, candidateLimit
    }
    let url: URL
    let reason: Reason
}

struct MacFontDiscoveryResult: Sendable {
    var sources: [MacFontSource] = []
    var candidates: [MacFontCandidate] = []
    var notices: [MacFontDiscoveryNotice] = []
    var unsupportedHFTCount = 0
    var cancelled = false
}

enum MacFontDiscoveryRequest: Sendable {
    case applications([URL])
    case installed([URL])
    case selected([URL])

    static func defaultApplications() throws -> Self {
        .applications([URL(fileURLWithPath: "/Applications"), try userHome().appendingPathComponent("Applications")])
    }
    static func defaultInstalled() throws -> Self {
        .installed([try userHome().appendingPathComponent("Library/Fonts"), URL(fileURLWithPath: "/Library/Fonts")])
    }
    // NSHomeDirectory는 sandbox에서는 컨테이너를 가리킬 수 있다.
    static func userHome() throws -> URL {
        var entry = passwd(), resolved: UnsafeMutablePointer<passwd>?
        var buffer = [CChar](repeating: 0, count: 16_384)
        let path: String? = buffer.withUnsafeMutableBufferPointer { bytes in
            guard getpwuid_r(getuid(), &entry, bytes.baseAddress, bytes.count, &resolved) == 0,
                  resolved != nil, let directory = entry.pw_dir else { return nil }
            return String(cString: directory)
        }
        guard let path, path.hasPrefix("/") else { throw FontLibraryError.unsafePath }
        return URL(fileURLWithPath: path, isDirectory: true)
    }
}

private final class MacFontDiscoveryCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    func cancel() { lock.lock(); value = true; lock.unlock() }
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return value }
}

final class MacFontDiscovery: Sendable {
    private let queue = DispatchQueue(label: "com.postmelee.alhangeul.font-discovery", qos: .utility)
    private let limits: MacFontDiscoveryLimits
    // 실제 권한과 별개로 재현 가능한 오류·취소 테스트를 위한 읽기 전 hook.
    private let beforeRead: @Sendable (URL) throws -> Void

    init(limits: MacFontDiscoveryLimits = .init(), beforeRead: @escaping @Sendable (URL) throws -> Void = { _ in }) {
        self.limits = limits
        self.beforeRead = beforeRead
    }

    func discover(_ request: MacFontDiscoveryRequest, session: FontImportSourceSession? = nil) async -> MacFontDiscoveryResult {
        let cancellation = MacFontDiscoveryCancellation()
        let lease = session?.acquire()
        if session != nil && lease == nil { return .init(cancelled: true) }
        return await withTaskCancellationHandler(operation: {
            await withCheckedContinuation { continuation in
                queue.async { [limits, beforeRead, lease] in
                    let worker = Worker(limits: limits, cancellation: cancellation, beforeRead: beforeRead)
                    let result = worker.run(request)
                    withExtendedLifetime(lease) { continuation.resume(returning: result) }
                }
            }
        }, onCancel: { cancellation.cancel() })
    }
}

private final class Worker {
    static let documentPaths = ["Contents/Resources/Hnc/Shared/TTF/Install",
                                "Contents/Resources/Hnc/Shared/TTF/Hwp", "Contents/Resources/Hnc/Shared/Fonts"]
    let limits: MacFontDiscoveryLimits
    let cancellation: MacFontDiscoveryCancellation
    let beforeRead: @Sendable (URL) throws -> Void
    let manager = FileManager()
    var result = MacFontDiscoveryResult()
    var visited = 0
    var stopped = false
    var candidateURLs = Set<URL>()
    var sourceURLs = Set<URL>()
    let keys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .isAliasFileKey, .fileSizeKey]

    init(limits: MacFontDiscoveryLimits, cancellation: MacFontDiscoveryCancellation,
         beforeRead: @escaping @Sendable (URL) throws -> Void) {
        self.limits = limits; self.cancellation = cancellation; self.beforeRead = beforeRead
    }

    func run(_ request: MacFontDiscoveryRequest) -> MacFontDiscoveryResult {
        switch request {
        case .applications(let roots):
            for root in roots where !halted {
                walk(root, depth: limits.applicationDepth) { url, values, enumerator in
                    guard values.isDirectory == true, url.pathExtension.lowercased() == "app" else { return }
                    enumerator.skipDescendants()
                    self.application(url, explicit: false)
                }
            }
        case .installed(let roots):
            for root in roots where !halted { fonts(root, source: .init(id: root, name: root.path, version: nil, kind: .macInstalled)) }
        case .selected(let roots):
            for root in roots where !halted {
                if root.pathExtension.lowercased() == "app" { application(root, explicit: true) }
                else { fonts(root, source: .init(id: root, name: root.lastPathComponent, version: nil, kind: .userSelected)) }
            }
        }
        result.cancelled = cancellation.isCancelled
        result.sources.sort { $0.id.path < $1.id.path }
        result.candidates.sort { $0.url.path < $1.url.path }
        return result
    }

    var halted: Bool { stopped || cancellation.isCancelled }
    func notice(_ url: URL, _ reason: MacFontDiscoveryNotice.Reason) {
        let value = MacFontDiscoveryNotice(url: url, reason: reason)
        if !result.notices.contains(value) { result.notices.append(value) }
    }
    func failure(_ url: URL, _ error: Error) {
        let ns = error as NSError
        let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError
        let code = ns.domain == NSPOSIXErrorDomain ? ns.code : underlying?.code
        if code == Int(EACCES) || code == Int(EPERM) || (ns.domain == NSCocoaErrorDomain && ns.code == NSFileReadNoPermissionError) {
            notice(url, .accessDenied)
        } else if code == Int(ENOENT) || (ns.domain == NSCocoaErrorDomain && ns.code == NSFileReadNoSuchFileError) {
            notice(url, .missing)
        } else { notice(url, .readFailure) }
    }
    func safe(_ url: URL) -> Bool {
        // Darwin의 /var, /tmp 표준 별칭만 허용하고 사용자 symlink 조상은 거부한다.
        guard url.isFileURL else { notice(url, .unsafePath); return false }
        func canonicalSystemPrefix(_ path: String) -> String {
            for prefix in ["/var", "/tmp", "/etc"] where path == prefix || path.hasPrefix(prefix + "/") {
                return "/private" + path
            }
            return path
        }
        let path = canonicalSystemPrefix(url.standardizedFileURL.path)
        let resolved = canonicalSystemPrefix(url.resolvingSymlinksInPath().path)
        guard resolved == path else {
            notice(url, .unsafePath); return false
        }
        return true
    }
    func readValues(_ url: URL) -> URLResourceValues? {
        guard !halted else { return nil }
        guard visited < limits.maximumVisited else { notice(url, .visitLimit); stopped = true; return nil }
        visited += 1
        do {
            try beforeRead(url)
            guard !halted else { return nil }
            let values = try url.resourceValues(forKeys: keys)
            guard values.isSymbolicLink != true, values.isAliasFile != true else { notice(url, .unsafePath); return nil }
            return values
        } catch { failure(url, error); return nil }
    }
    func walk(_ root: URL, depth: Int, body: (URL, URLResourceValues, FileManager.DirectoryEnumerator) -> Void) {
        guard !halted, safe(root), let values = readValues(root) else { return }
        guard values.isDirectory == true else { notice(root, .unsafePath); return }
        guard let enumerator = manager.enumerator(at: root, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles],
            errorHandler: { url, error in self.failure(url, error); return !self.halted }) else {
            notice(root, .readFailure); return
        }
        while !halted, let url = enumerator.nextObject() as? URL {
            guard enumerator.level <= depth else { enumerator.skipDescendants(); notice(url, .depthLimit); continue }
            guard let values = readValues(url) else { enumerator.skipDescendants(); continue }
            if values.isDirectory == true && enumerator.level >= depth {
                enumerator.skipDescendants(); notice(url, .depthLimit)
            }
            body(url, values, enumerator)
        }
    }
    func application(_ url: URL, explicit: Bool) {
        guard safe(url), let values = readValues(url), values.isDirectory == true else { return }
        let infoURL = url.appendingPathComponent("Contents/Info.plist")
        guard safe(infoURL), let infoValues = readValues(infoURL), infoValues.isRegularFile == true,
              (infoValues.fileSize ?? Int.max) <= 1_048_576 else { return }
        do {
            let handle = try FileHandle(forReadingFrom: infoURL)
            defer { try? handle.close() }
            let data = try handle.read(upToCount: 1_048_577) ?? Data()
            guard data.count <= 1_048_576,
                  let info = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
                notice(infoURL, .readFailure); return
            }
            let known = info["CFBundleIdentifier"] as? String == "com.haansoft.HancomOfficeViewer.Mac"
            guard known || explicit else { return }
            let source = MacFontSource(id: url, name: info["CFBundleDisplayName"] as? String ?? url.deletingPathExtension().lastPathComponent,
                                       version: info["CFBundleShortVersionString"] as? String, kind: known ? .macApplication : .userSelected)
            if sourceURLs.insert(url).inserted { result.sources.append(source) }
            for path in Self.documentPaths where !halted { fonts(url.appendingPathComponent(path), source: source) }
        } catch { failure(infoURL, error) }
    }
    func fonts(_ root: URL, source: MacFontSource) {
        if sourceURLs.insert(source.id).inserted { result.sources.append(source) }
        walk(root, depth: limits.fontDepth) { url, values, enumerator in
            if values.isDirectory == true && ["app", "framework", "bundle"].contains(url.pathExtension.lowercased()) {
                enumerator.skipDescendants(); return
            }
            guard values.isRegularFile == true else { return }
            let ext = url.pathExtension.lowercased()
            guard ["ttf", "otf", "ttc", "otc", "hft"].contains(ext) else { return }
            guard self.candidateURLs.insert(url.standardizedFileURL).inserted else { return }
            if ext == "hft" { self.result.unsupportedHFTCount += 1; return }
            guard self.result.candidates.count < self.limits.maximumCandidates else {
                self.notice(url, .candidateLimit); self.stopped = true; return
            }
            self.result.candidates.append(.init(id: UUID(), url: url, byteCount: values.fileSize ?? 0, source: source))
        }
    }
}
