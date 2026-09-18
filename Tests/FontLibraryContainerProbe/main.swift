import Foundation

@main
struct FontLibraryContainerProbe {
    static func main() async {
        // 격리 폴더의 저장소만 사용한다. 제품의 current.json은 변경하지 않는다.
        do {
            let root = try FontLibraryLocation().resolve()
            let probe = root.deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent(".font-library-probe-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: probe, withIntermediateDirectories: false)
            defer { try? FileManager.default.removeItem(at: probe) }
            guard let fixture = Bundle.main.url(forResource: "regular", withExtension: "ttf") else {
                throw CocoaError(.fileNoSuchFile)
            }
            let source = probe.appendingPathComponent("source.ttf")
            try FileManager.default.copyItem(at: fixture, to: source)
            let store = FontLibraryStore(rootURL: probe.appendingPathComponent("library"))
            let results = await store.importCandidates([.init(sourceURL: source)])
            guard results[0].status == .added, results[0].publication == .durable else {
                print("FAIL: signed store \(results[0].reasonCode ?? "unknown")")
                throw CocoaError(.fileWriteUnknown)
            }
            try FileManager.default.removeItem(at: source)
            let manifest = try await FontLibraryStore(rootURL: probe.appendingPathComponent("library")).list()
            guard manifest.entries.count == 1 else { throw CocoaError(.fileReadCorruptFile) }
            let snapshot = try await store.acquireSnapshot()
            guard let resource = snapshot.resources.first else { throw CocoaError(.fileReadCorruptFile) }
            _ = try await store.remove(objectHash: resource.object.sha256, expectedGeneration: snapshot.generation)
            let retained = try await store.recover()
            let bytes = try await store.readResource(resource.id, snapshot: snapshot)
            guard retained.removedObjects == 0, bytes == (try Data(contentsOf: fixture)) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            try await store.releaseSnapshot(snapshot)
            let collected = try await store.recover()
            guard collected.removedObjects == 1 else { throw CocoaError(.fileWriteUnknown) }
            try FileManager.default.removeItem(at: probe)
            guard !FileManager.default.fileExists(atPath: probe.path) else { throw CocoaError(.fileWriteUnknown) }
            print("PASS: signed sandbox import/snapshot/read, source removed, live lease retained, released object collected, probe cleanup")
        } catch {
            if let reason = error as? FontLibraryLocationError { print("FAIL: App Group location: \(reason)") }
            else { print("FAIL: App Group store (\((error as NSError).domain):\((error as NSError).code))") }
            exit(1)
        }
    }
}
