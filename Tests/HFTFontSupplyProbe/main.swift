// 테스트 전용 JSON-lines 서버. 제품 공급 경로를 호출하며 OS 글꼴을 등록하지 않는다.
import Foundation

@MainActor
@main
struct HFTFontSupplyProbe {
    static var session: StudioFontSession?
    static var catalog: InstalledFontCatalogService?
    static var supply: StudioFontSupply?

    static func main() async {
        guard CommandLine.arguments.count == 3 else { exit(1) }
        let fixtures = URL(fileURLWithPath: CommandLine.arguments[1])
        let root = URL(fileURLWithPath: CommandLine.arguments[2])
        while let line = readLine() {
            var requestID: Any = NSNull()
            do {
                guard let data = line.data(using: .utf8), data.count < 16_384,
                      let envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let op = envelope["command"] as? String else { throw StudioFontError.invalidRequest }
                requestID = envelope["id"] ?? NSNull()
                let result: [String: Any]
                switch op {
                case "configure":
                    result = try await configure(envelope, fixtures: fixtures, root: root)
                case "rpc":
                    guard let session, var body = envelope["body"] as? [String: Any] else { throw StudioFontError.invalidRequest }
                    // loadToken은 HostApp handler의 검증 경계다. 여기서는 제품 session 입력에 맞춘다.
                    body.removeValue(forKey: "loadToken")
                    result = try await session.handle(body)
                case "refresh":
                    guard let catalog, let session else { throw StudioFontError.invalidRequest }
                    _ = try await catalog.refreshForUser()
                    session.invalidate()
                    result = ["refreshed": true]
                default: throw StudioFontError.invalidRequest
                }
                emit(["id": requestID, "result": result])
            } catch {
                let code = (error as? InstalledFontFailure)?.rawValue ?? (error as? StudioFontError)?.rawValue ?? "probeFailure"
                emit(["id": requestID, "error": code])
            }
        }
        session?.invalidate()
        await catalog?.stopMonitoring()
    }

    static func emit(_ value: [String: Any]) {
        do {
            let bytes = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
            FileHandle.standardOutput.write(bytes)
            FileHandle.standardOutput.write(Data([10]))
        } catch { exit(1) }
    }

    static func configure(_ message: [String: Any], fixtures: URL, root: URL) async throws -> [String: Any] {
        session?.invalidate()
        await catalog?.stopMonitoring()
        guard let scenario = message["scenario"] as? String else { throw StudioFontError.invalidRequest }
        let allowed = ["ttf", "otf", "both", "none", "book", "empty", "permission", "corrupt", "conflict", "managed", "installed"]
        guard allowed.contains(scenario) else { throw StudioFontError.invalidRequest }
        let work = root.appendingPathComponent(UUID().uuidString)
        let environment: InstalledFontEnvironment
        var expected: [[String: Any]] = []
        if scenario == "installed" {
            guard let family = message["family"] as? String, !family.isEmpty, family.utf8.count <= 1024 else {
                throw StudioFontError.invalidRequest
            }
            let system = InstalledFontSystem().environment
            environment = .init(scan: { grants in
                let scan = try system.scan(grants)
                return .init(records: scan.records.filter { record in
                    [record.family, record.fullName, record.postScriptName].contains {
                        $0.precomposedStringWithCanonicalMapping.caseInsensitiveCompare(family.precomposedStringWithCanonicalMapping) == .orderedSame
                    }
                }, grantIssues: scan.grantIssues, omittedFaceCount: scan.omittedFaceCount)
            }, read: system.read, makeBookmark: system.makeBookmark)
        } else {
            let names = scenario == "none" ? [] : scenario == "both" ? ["regular.ttf", "regular.otf"] : [scenario == "otf" ? "regular.otf" : "regular.ttf"]
            var records: [InstalledFontRecord] = []
            for name in names {
                let url = fixtures.appendingPathComponent(name)
                let bytes = try Data(contentsOf: url)
                let face = try FontFileInspector().inspect(bytes, filename: name).faces[0]
                records.append(.init(id: name, sourceURL: url, postScriptName: face.postScriptName,
                    family: face.familyName ?? "", fullName: face.fullName ?? face.postScriptName,
                    style: scenario == "book" ? "Book" : scenario == "empty" ? "" : "Regular",
                    version: face.version, traits: 0, axes: [], stamp: try InstalledFontSystem.statURL(url), failure: nil))
                expected.append(["postScriptName": face.postScriptName, "sha256": face.id.objectHash,
                                 "byteCount": bytes.count, "signature": bytes.prefix(4).map { String(format: "%02x", $0) }.joined()])
            }
            if scenario == "conflict", let first = records.first {
                records.append(.init(id: "duplicate", sourceURL: first.sourceURL, postScriptName: first.postScriptName,
                    family: first.family, fullName: first.fullName, style: first.style, version: nil,
                    traits: 0, axes: [], stamp: first.stamp, failure: nil))
            }
            let fixed = records
            environment = .init(scan: { _ in .init(records: fixed, grantIssues: []) }, read: { record, _ in
                if scenario == "permission" { throw InstalledFontFailure.permissionDenied }
                let bytes = scenario == "corrupt" ? Data([0, 1, 2]) : try Data(contentsOf: record.sourceURL)
                let inspected: InspectedFont
                do { inspected = try FontFileInspector().inspect(bytes, filename: record.sourceURL.lastPathComponent) }
                catch { throw InstalledFontFailure.corrupt }
                guard let face = inspected.faces.first(where: { $0.postScriptName == record.postScriptName }) else {
                    throw InstalledFontFailure.changed
                }
                return .init(data: bytes, face: face)
            }, makeBookmark: { _ in throw InstalledFontFailure.permissionDenied })
        }
        let service = try InstalledFontCatalogService(persistence: .file(at: work.appendingPathComponent("catalog")),
                                                     environment: environment, observeChanges: false)
        _ = try await service.prepare()
        _ = try await service.setEnabled(true)
        let library = FontLibraryService(store: FontLibraryStore(rootURL: work.appendingPathComponent("library")))
        if scenario == "managed" {
            let results = await library.importFonts(.init(candidates: [.init(sourceURL: fixtures.appendingPathComponent("regular.ttf"))], accessURLs: []))
            guard results.first?.status == .added else { throw StudioFontError.unavailable }
        }
        let source = StudioFontSupply.using(installed: .init(factory: { service }), library: { library })
        catalog = service; supply = source
        session = StudioFontSession(supply: source)
        let snapshot = try await source.snapshot()
        defer { Task { await snapshot.release() } }
        let rows = try JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot.faces))
        return ["rawFaces": rows, "expected": expected, "identity": snapshot.identity,
                "evidenceKind": scenario == "installed" ? "installed-cli" : "synthetic"]
    }
}
