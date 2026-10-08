import Foundation

// OS 글꼴 등록 없이 전용 복사본의 실제 파일 상태만 바꾼다. 활성 목록은 주입한다.
final class FontChangeFixture: @unchecked Sendable {
    let directory: URL
    let gate = FontChangeReadGate()
    private let originals: [(URL, Data, FontFace)]

    init(repository: URL, directory: URL, create: Bool) throws {
        self.directory = directory
        originals = try ["Regular", "Bold"].map { style in
            let source = repository.appendingPathComponent("build.noindex/task567/fonts/gowun-batang/GowunBatang-\(style).ttf")
            let data = try Data(contentsOf: source)
            guard let face = try FontFileInspector().inspect(data, filename: source.lastPathComponent).faces.first else {
                throw InstalledFontFailure.corrupt
            }
            return (directory.appendingPathComponent(source.lastPathComponent), data, face)
        }
        if create { try restore() }
    }

    func restore() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (url, data, _) in originals {
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
        }
    }
    func setReadable(_ readable: Bool) throws {
        for (url, _, _) in originals where FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.setAttributes([.posixPermissions: readable ? 0o644 : 0], ofItemAtPath: url.path)
        }
    }
    func replaceBytes() throws -> String {
        let (url, original, _) = originals[0]
        // 유효 SFNT 뒤에 0 padding을 더해 이름/weight/glyph는 유지하면서 content hash를 바꾼다.
        var replacement = original; replacement.append(contentsOf: [0, 0, 0, 0])
        try replacement.write(to: url, options: .atomic)
        return try FontFileInspector().inspect(replacement, filename: url.lastPathComponent).object.sha256
    }
    func removeSources() throws {
        for (url, _, _) in originals where FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
    var sourceExists: Bool { originals.contains { FileManager.default.fileExists(atPath: $0.0.path) } }

    var environment: InstalledFontEnvironment {
        .init(scan: { _ in
            let records = try self.originals.compactMap { url, _, face -> InstalledFontRecord? in
                guard FileManager.default.fileExists(atPath: url.path) else { return nil }
                return .init(id: face.postScriptName, sourceURL: url, postScriptName: face.postScriptName,
                    family: face.familyName ?? "", fullName: face.fullName ?? face.postScriptName,
                    style: face.subfamilyName ?? "", version: face.version,
                    traits: face.weightClass >= 700 ? 2 : 0, axes: [],
                    stamp: try InstalledFontSystem.statURL(url), failure: nil)
            }
            return .init(records: records, grantIssues: [])
        }, read: { record, _ in
            await self.gate.pauseIfArmed()
            return try await Task.detached(priority: .utility) {
                try Task.checkCancellation()
                guard try InstalledFontSystem.statURL(record.sourceURL) == record.stamp else { throw InstalledFontFailure.changed }
                let data = try Data(contentsOf: record.sourceURL)
                guard let face = try FontFileInspector().inspect(data, filename: record.sourceURL.lastPathComponent).faces.first,
                      face.postScriptName == record.postScriptName else { throw InstalledFontFailure.changed }
                guard try InstalledFontSystem.statURL(record.sourceURL) == record.stamp else { throw InstalledFontFailure.changed }
                try Task.checkCancellation()
                return InstalledFontRead(data: data, face: face)
            }.value
        }, makeBookmark: { _ in throw InstalledFontFailure.unsupported })
    }
}

actor FontChangeReadGate {
    private var armed = false
    private(set) var entered = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func arm() { armed = true; entered = false }
    func pauseIfArmed() async {
        guard armed else { return }
        entered = true
        await withCheckedContinuation { waiters.append($0) }
    }
    func open() {
        armed = false
        let old = waiters; waiters.removeAll()
        old.forEach { $0.resume() }
    }
}
