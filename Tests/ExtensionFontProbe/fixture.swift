import Foundation
import CryptoKit

/// 승인 후 기존 팀의 App Group에 고유 하위 보관함만 만든다. 실제 관리 글꼴/설정은 변경하지 않는다.
@main struct Fixture {
    static func main() async throws {
        guard let id = FontLibraryLocation.extensionProbeIdentifier else { throw StudioFontError.invalidRequest }
        let root = try FontLibraryLocation().resolve()
        guard root.lastPathComponent == id.uuidString, root.deletingLastPathComponent().lastPathComponent == "extension-probes" else {
            throw StudioFontError.invalidRequest
        }
        let command = CommandLine.arguments.dropFirst().first ?? "--status"
        if command == "--cleanup" {
            if FileManager.default.fileExists(atPath: root.path) { try FileManager.default.removeItem(at: root) }
            print("private fixture removed", id.uuidString)
            return
        }
        let policy = FontConsumerPolicyStore(rootURL: root)
        if command == "--setup" {
            guard let fonts = Bundle.main.resourceURL?.appendingPathComponent("Fonts") else { throw StudioFontError.unavailable }
            let store = FontLibraryStore(rootURL: root)
            let results = await store.importCandidates(["Regular", "Bold"].map { .init(sourceURL: fonts.appendingPathComponent("GowunBatang-\($0).ttf")) })
            guard results.allSatisfy({ [.added, .alreadyPresent].contains($0.status) }) else { throw StudioFontError.unavailable }
            try policy.publish(enabled: true)
        } else if command == "--disable-installed" { try policy.publish(enabled: false) }
        else if command == "--enable-installed" { try policy.publish(enabled: true) }
        else if command == "--remove-managed-object" {
            let manifest = try await FontLibraryStore(rootURL: root).list()
            guard let entry = manifest.entries.first else { throw StudioFontError.unavailable }
            try FileManager.default.removeItem(at: root.appendingPathComponent("objects/" + entry.object.sha256 + ".font"))
        } else if command == "--restore-managed-objects" {
            guard let fonts = Bundle.main.resourceURL?.appendingPathComponent("Fonts") else { throw StudioFontError.unavailable }
            let manifest = try await FontLibraryStore(rootURL: root).list()
            let allowed = Set(manifest.entries.map { $0.object.sha256 })
            for name in ["Regular", "Bold"] {
                let bytes = try Data(contentsOf: fonts.appendingPathComponent("GowunBatang-" + name + ".ttf"))
                let hash = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
                guard allowed.contains(hash) else { throw StudioFontError.invalidRequest }
                try bytes.write(to: root.appendingPathComponent("objects/" + hash + ".font"), options: .atomic)
            }
        }
        else if command != "--status" { throw StudioFontError.invalidRequest }
        let snapshot = try await ExtensionFontSupply.shared.snapshot()
        print("fixture", id.uuidString, "faces", snapshot.faces.count, "current", try await snapshot.current())
        await snapshot.release()
    }
}
