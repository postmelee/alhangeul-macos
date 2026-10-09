import CoreText
import CryptoKit
import Darwin
import Foundation

struct InstalledFontPermissionAccess: Sendable {
    let resolve: @Sendable (Data) throws -> (URL, Bool)
    let create: @Sendable (URL) throws -> Data
    let scope: FontLibrarySourceAccess

    static let system = Self(resolve: { data in
        var stale = false
        let url = try URL(resolvingBookmarkData: data, options: [.withSecurityScope, .withoutUI, .withoutMounting],
                          relativeTo: nil, bookmarkDataIsStale: &stale)
        return (url, stale)
    }, create: { url in
        try url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                             includingResourceValuesForKeys: nil, relativeTo: nil)
    }, scope: .securityScoped)

    func withAccess<T>(_ grants: [InstalledFontGrant], _ operation: ([InstalledFontGrantIssue]) throws -> T) rethrows -> T {
        var urls: [URL] = []
        var issues: [InstalledFontGrantIssue] = []
        for grant in grants {
            do {
                let (url, stale) = try resolve(grant.bookmark)
                if stale { issues.append(.init(id: grant.id, failure: .stalePermission)) }
                else { urls.append(url) }
            } catch { issues.append(.init(id: grant.id, failure: .permissionUnresolvable)) }
        }
        let session = FontImportSourceSession(urls: urls, access: scope)
        defer { session.close() }
        return try operation(issues)
    }
}

struct InstalledFontSystem: Sendable {
    let access: InstalledFontPermissionAccess
    static let maximumRecords = 20_000
    static let maximumBytes = 64 * 1024 * 1024

    init(access: InstalledFontPermissionAccess = .system) { self.access = access }

    var environment: InstalledFontEnvironment {
        .init(scan: { try self.scan($0) }, read: { record, grants in
            let work = Task.detached(priority: .utility) { try self.read(record, grants: grants) }
            return try await withTaskCancellationHandler(operation: { try await work.value }, onCancel: { work.cancel() })
        }, makeBookmark: { url in
            let session = FontImportSourceSession(urls: [url], access: self.access.scope)
            defer { session.close() }
            return try self.access.create(url)
        })
    }

    func scan(_ grants: [InstalledFontGrant]) throws -> InstalledFontScan {
        try access.withAccess(grants) { issues in
            let descriptors = activeDescriptors()
            guard descriptors.count <= Self.maximumRecords else { throw InstalledFontFailure.catalogLimit }
            var records: [String: InstalledFontRecord] = [:]
            var omitted = 0
            for descriptor in descriptors {
                try Task.checkCancellation()
                guard let url = CTFontDescriptorCopyAttribute(descriptor, kCTFontURLAttribute) as? URL,
                      let ps = CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String else { omitted += 1; continue }
                let font = CTFontCreateWithFontDescriptor(descriptor, 16, nil)
                let variation = CTFontCopyVariation(font) as? [NSNumber: NSNumber] ?? [:]
                let axes = (CTFontCopyVariationAxes(font) as? [[CFString: Any]] ?? []).compactMap { axis -> InstalledFontAxis? in
                    guard let identifier = axis[kCTFontVariationAxisIdentifierKey] as? NSNumber,
                          let minimum = axis[kCTFontVariationAxisMinimumValueKey] as? NSNumber,
                          let maximum = axis[kCTFontVariationAxisMaximumValueKey] as? NSNumber,
                          let defaultValue = axis[kCTFontVariationAxisDefaultValueKey] as? NSNumber else { return nil }
                    return .init(identifier: identifier.uint32Value, minimum: minimum.doubleValue, maximum: maximum.doubleValue,
                                 defaultValue: defaultValue.doubleValue, value: variation[identifier]?.doubleValue ?? defaultValue.doubleValue)
                }.sorted { $0.identifier < $1.identifier }
                let source = url.standardizedFileURL
                let axisKey = axes.map { "\($0.identifier)=\($0.value)" }.joined(separator: ";")
                // 길이 구분 직렬화로 경로·PS 경계 충돌을 피한다. bytes/content hash가 아니다.
                let identity = try JSONEncoder().encode([source.path, ps, axisKey])
                let id = SHA256.hash(data: identity).map { String(format: "%02x", $0) }.joined()
                var stamp: InstalledFontStamp?
                var failure: InstalledFontFailure?
                do { stamp = try Self.statURL(source) }
                catch { failure = Self.failure(error) }
                let record = InstalledFontRecord(id: id, sourceURL: source, postScriptName: ps,
                    family: CTFontCopyFamilyName(font) as String, fullName: CTFontCopyFullName(font) as String,
                    style: CTFontDescriptorCopyAttribute(descriptor, kCTFontStyleNameAttribute) as? String ?? "",
                    version: CTFontCopyName(font, kCTFontVersionNameKey) as String?,
                    traits: CTFontGetSymbolicTraits(font).rawValue, axes: axes, stamp: stamp, failure: failure)
                records[id] = record
            }
            return .init(records: records.values.sorted { $0.id < $1.id }, grantIssues: issues, omittedFaceCount: omitted)
        }
    }

    private func activeDescriptors() -> [CTFontDescriptor] {
        let collection = CTFontCollectionCreateFromAvailableFonts(nil)
        return (CTFontCollectionCreateMatchingFontDescriptors(collection) as? [CTFontDescriptor] ?? []).filter {
            (CTFontDescriptorCopyAttribute($0, kCTFontEnabledAttribute) as? NSNumber)?.boolValue != false
        }
    }

    private func isActive(_ record: InstalledFontRecord) -> Bool {
        // 같은 PS의 다른 원본이 활성화된 경우도 일치로 간주하지 않는다.
        activeDescriptors().contains {
            (CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String) == record.postScriptName &&
            (CTFontDescriptorCopyAttribute($0, kCTFontURLAttribute) as? URL)?.standardizedFileURL == record.sourceURL
        }
    }

    func read(_ record: InstalledFontRecord, grants: [InstalledFontGrant]) throws -> InstalledFontRead {
        try access.withAccess(grants) { _ in
            try Task.checkCancellation()
            guard record.axes.isEmpty else { throw InstalledFontFailure.unsupported }
            let fd = open(record.sourceURL.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK)
            guard fd >= 0 else { throw Self.posixFailure(errno) }
            defer { close(fd) }
            var info = stat()
            guard fstat(fd, &info) == 0 else { throw Self.posixFailure(errno) }
            guard info.st_mode & S_IFMT == S_IFREG else { throw InstalledFontFailure.unsupported }
            let before = Self.stamp(info)
            guard before == record.stamp else { throw InstalledFontFailure.changed }
            guard isActive(record) else { throw InstalledFontFailure.inactive }
            guard before.size > 0, before.size <= Self.maximumBytes else { throw InstalledFontFailure.tooLarge }
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 64 * 1024)
            while true {
                try Task.checkCancellation()
                let count = Darwin.read(fd, &buffer, buffer.count)
                if count < 0 { if errno == EINTR { continue }; throw Self.posixFailure(errno) }
                if count == 0 { break }
                guard data.count + count <= Self.maximumBytes else { throw InstalledFontFailure.tooLarge }
                data.append(contentsOf: buffer.prefix(count))
            }
            guard fstat(fd, &info) == 0, Self.stamp(info) == before,
                  try Self.statURL(record.sourceURL) == before else { throw InstalledFontFailure.changed }
            let inspected: InspectedFont
            do { inspected = try FontFileInspector().inspect(data, filename: record.sourceURL.lastPathComponent) }
            catch { throw InstalledFontFailure.corrupt }
            // 정확한 collection face/variable 축 적용은 소비자 검증 전 허용하지 않는다.
            guard inspected.object.format != .collection else { throw InstalledFontFailure.unsupported }
            let matches = inspected.faces.filter { $0.postScriptName == record.postScriptName }
            guard matches.count == 1 else { throw InstalledFontFailure.changed }
            let face = matches[0]
            guard face.applicationSupport == .staticCandidate else { throw InstalledFontFailure.unsupported }
            guard isActive(record), try Self.statURL(record.sourceURL) == before else { throw InstalledFontFailure.changed }
            return .init(data: data, face: face)
        }
    }

    static func statURL(_ url: URL) throws -> InstalledFontStamp {
        var info = stat()
        guard lstat(url.path, &info) == 0 else { throw posixFailure(errno) }
        guard info.st_mode & S_IFMT == S_IFREG else { throw InstalledFontFailure.unsupported }
        return stamp(info)
    }

    private static func stamp(_ value: stat) -> InstalledFontStamp {
        .init(device: UInt64(UInt32(bitPattern: value.st_dev)), inode: UInt64(value.st_ino), size: value.st_size,
              modifiedSeconds: Int64(value.st_mtimespec.tv_sec), modifiedNanos: Int64(value.st_mtimespec.tv_nsec),
              changedSeconds: Int64(value.st_ctimespec.tv_sec), changedNanos: Int64(value.st_ctimespec.tv_nsec))
    }
    static func failure(_ error: Error) -> InstalledFontFailure {
        if error is CancellationError { return .cancelled }
        return error as? InstalledFontFailure ?? .permissionDenied
    }
    private static func posixFailure(_ code: Int32) -> InstalledFontFailure {
        switch code {
        case ENOENT, ENOTDIR: return .missing
        case EACCES, EPERM: return .permissionDenied
        case ELOOP: return .unsupported
        default: return .changed
        }
    }
}
