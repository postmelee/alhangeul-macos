// Stage 4: 제품 service를 사용하는 별도 sandbox 앱. 배포·사용자 글꼴 설치 없음.
import AppKit
import CoreText
import Foundation

final class CatalogProbeDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            do { try await InstalledCatalogProbe.run(); exit(0) }
            catch { fputs("catalog probe failed: \(error)\n", stderr); exit(1) }
        }
    }
}

@main
struct InstalledCatalogProbe {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = CatalogProbeDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { app.run() }
    }
    @MainActor static func run() async throws {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let root = support.appendingPathComponent("InstalledFontCatalogProbe")
        let store = InstalledFontPersistence.file(at: root)
        let service = try InstalledFontCatalogService(persistence: store, observeChanges: false)
        let wasEnabled = await service.snapshot().enabled
        var snapshot = try await service.prepare()
        snapshot = try await service.setEnabled(true)
        var details: [[String: Any]] = []
        for ps in ["NanumSquareR", "NanumSquareB"] {
            guard let record = snapshot.records.first(where: { $0.postScriptName == ps && $0.failure == nil }) else {
                throw InstalledFontFailure.inactive
            }
            let result = try await service.readResource(record.id, expectedGeneration: snapshot.generation)
            details.append(["ps": ps, "bytes": result.data.count, "sha256": result.face.id.objectHash,
                            "faceIndex": result.face.id.sfntIndex])
        }
        let args = CommandLine.arguments
        var outsideReadableBefore: Bool?
        if args.count == 3, args[1] == "--choose" {
            let target = URL(fileURLWithPath: args[2], isDirectory: true)
            outsideReadableBefore = (try? Data(contentsOf: target.appendingPathComponent("regular.ttf"))) != nil
            let panel = NSOpenPanel()
            panel.title = "Stage 4 — 테스트 폴더 지속 권한 검증"
            panel.message = "이번 실험에서 만든 installed-font-permission-fixture 폴더를 선택합니다."
            panel.prompt = "검증 폴더 선택"
            panel.canChooseFiles = false; panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false; panel.directoryURL = target
            guard panel.runModal() == .OK, let selected = panel.url else { throw InstalledFontFailure.cancelled }
            snapshot = try await service.grantAccess(to: selected)
        }
        let saved = try JSONDecoder().decode(InstalledFontSavedState.self, from: store.load()!)
        var bookmarkRead = false
        if !saved.grants.isEmpty {
            let access = InstalledFontPermissionAccess.system
            let (directory, stale) = try access.resolve(saved.grants[0].bookmark)
            guard !stale else { throw InstalledFontFailure.stalePermission }
            let fixture = directory.appendingPathComponent("regular.ttf")
            try access.withAccess(saved.grants) { issues in
                guard issues.isEmpty, CTFontManagerRegisterFontsForURL(fixture as CFURL, .process, nil) else {
                    throw InstalledFontFailure.permissionDenied
                }
            }
            defer { access.withAccess(saved.grants) { _ in _ = CTFontManagerUnregisterFontsForURL(fixture as CFURL, .process, nil) } }
            snapshot = try await service.refresh()
            guard let record = snapshot.records.first(where: { $0.sourceURL == fixture && $0.failure == nil }) else {
                throw InstalledFontFailure.inactive
            }
            let resource = try await service.readResource(record.id, expectedGeneration: snapshot.generation)
            bookmarkRead = !resource.data.isEmpty
        }
        var output: [String: Any] = ["pid": ProcessInfo.processInfo.processIdentifier, "restoredEnabled": wasEnabled,
                                     "records": snapshot.records.count, "omittedFaceCount": snapshot.omittedFaceCount, "fonts": details, "bookmarkCount": saved.grants.count,
                                     "bookmarkRead": bookmarkRead, "grantIssues": snapshot.grantIssues.count,
                                     "os": ProcessInfo.processInfo.operatingSystemVersionString]
        if let outsideReadableBefore { output["outsideReadableBeforeSelection"] = outsideReadableBefore }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let encoded = try JSONSerialization.data(withJSONObject: output, options: [.sortedKeys, .prettyPrinted])
        try encoded.write(to: root.appendingPathComponent("result-\(ProcessInfo.processInfo.processIdentifier).json"))
        print(String(decoding: encoded, as: UTF8.self))
        await service.stopMonitoring()
    }
}
