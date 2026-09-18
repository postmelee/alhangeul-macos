#if DEBUG
import Foundation

// 로컬 서명 검증용 Debug 전용 진입점. 정상 시작/사용자 저장소와 분리한다.
@MainActor
enum FontLibraryHostProbe {
    static func runIfRequested() -> Bool {
        let args = CommandLine.arguments
        guard args.contains("--font-library-host-probe") else { return false }
        guard args.count == 4, args[1] == "--font-library-host-probe",
              let session = UUID(uuidString: args[2]), ["create", "reopen"].contains(args[3]) else {
            exit(64)
        }
        Task {
            do {
                let productionRoot = try FontLibraryLocation().resolve()
                let group = productionRoot.deletingLastPathComponent().deletingLastPathComponent()
                    .deletingLastPathComponent().deletingLastPathComponent()
                let isolated = group.appendingPathComponent(".font-library-host-probe-" + session.uuidString)
                if args[3] == "create" {
                    try FileManager.default.createDirectory(at: isolated, withIntermediateDirectories: false)
                } else {
                    guard FileManager.default.fileExists(atPath: isolated.appendingPathComponent("library/current.json").path) else {
                        throw CocoaError(.fileReadNoSuchFile)
                    }
                }
                let service = FontLibraryService(store: FontLibraryStore(rootURL: isolated.appendingPathComponent("library")))
                _ = try await service.prepare()
                if args[3] == "create" {
                    guard let fixture = Bundle.main.url(forResource: "font-probe", withExtension: "ttf") else {
                        throw CocoaError(.fileReadNoSuchFile)
                    }
                    let copied = isolated.appendingPathComponent("source.ttf")
                    try FileManager.default.copyItem(at: fixture, to: copied)
                    let result = await service.importFonts(.init(candidates: [.init(sourceURL: copied)], accessURLs: []))
                    guard result.first?.status == .added else { throw CocoaError(.fileWriteUnknown) }
                    try FileManager.default.removeItem(at: copied)
                }
                let snapshot = try await service.acquireSnapshot()
                guard snapshot.resources.count == 1, let resource = snapshot.resources.first else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                let bytes = try await service.readResource(resource.id, snapshot: snapshot)
                guard bytes.count == resource.object.byteCount else { throw CocoaError(.fileReadCorruptFile) }
                try await service.releaseSnapshot(snapshot)
                _ = try await service.recover()
                if args[3] == "reopen" { try FileManager.default.removeItem(at: isolated) }
                print("PASS: HostApp signed font service \(args[3]), managed bytes verified")
                exit(0)
            } catch {
                print("FAIL: HostApp font service \((error as NSError).domain):\((error as NSError).code)")
                exit(1)
            }
        }
        return true
    }
}
#endif
