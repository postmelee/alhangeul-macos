import Darwin
import Foundation
import XCTest

final class FontLibraryProcessTests: XCTestCase {
    private var temporary: URL!
    override func setUpWithError() throws {
        temporary = FileManager.default.temporaryDirectory.appendingPathComponent("font-process-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: temporary) }

    private func fixture(_ name: String) throws -> URL {
        try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Fixtures", withExtension: nil)).appendingPathComponent(name)
    }
    private func launch(_ args: [String]) throws -> (Process, Pipe) {
        let executable = Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("FontLibraryProcessProbe")
        let process = Process(), output = Pipe()
        process.executableURL = executable
        process.arguments = args
        process.standardOutput = output
        process.standardError = output
        try process.run()
        return (process, output)
    }
    private func finish(_ value: (Process, Pipe), expected: Int32 = 0) throws -> Data {
        let deadline = Date().addingTimeInterval(10)
        while value.0.isRunning && Date() < deadline { usleep(10_000) }
        if value.0.isRunning {
            value.0.terminate()
            throw NSError(domain: "FontLibraryProcessTests.timeout", code: 1)
        }
        // async 테스트는 launch와 다른 스레드에서 재개될 수 있다.
        // 종료를 확인한 뒤 waitUntilExit의 스레드별 RunLoop 대기를 다시 호출하지 않는다.
        let data = value.1.fileHandleForReading.readDataToEndOfFile()
        XCTAssertEqual(value.0.terminationStatus, expected, String(decoding: data, as: UTF8.self))
        return data
    }

    func testProcessDeathAtEveryPublicationBoundaryPreservesCommittedGeneration() async throws {
        for phase in FontLibraryWritePhase.allCases {
            let root = temporary.appendingPathComponent(phase.rawValue)
            _ = try await FontLibraryStore(rootURL: root).list()
            let killed = try launch(["import", root.path, fixture("regular.ttf").path, phase.rawValue])
            _ = try finish(killed, expected: 71)
            let fresh = try finish(launch(["list", root.path]))
            let manifest = try JSONDecoder().decode(FontLibraryManifest.self, from: fresh)
            let committed = phase == .manifestReplaced || phase == .manifestDirectorySynced
            XCTAssertEqual(manifest.entries.count, committed ? 1 : 0, phase.rawValue)
            for entry in manifest.entries {
                XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("objects/\(entry.object.sha256).font")),
                               try Data(contentsOf: fixture("regular.ttf")))
            }
            let recovery = try await FontLibraryStore(rootURL: root).recover()
            let orphanPhases: [FontLibraryWritePhase] = [.objectPublished, .objectDirectorySynced, .manifestWritten, .manifestSynced]
            XCTAssertEqual(recovery.removedObjects, orphanPhases.contains(phase) ? 1 : 0, phase.rawValue)
            XCTAssertEqual(recovery.removedTransactions, 1, phase.rawValue)
            let retry = try finish(launch(["import", root.path, fixture("regular.ttf").path]))
            let results = try JSONDecoder().decode([FontImportItemResult].self, from: retry)
            XCTAssertEqual(results[0].status, committed ? .alreadyPresent : .added, phase.rawValue)
        }
    }

    func testTwoProcessesSerializeAndDeduplicateWithoutLostUpdates() async throws {
        for sameInput in [false, true] {
            let root = temporary.appendingPathComponent(sameInput ? "same" : "different")
            let gate = temporary.appendingPathComponent(UUID().uuidString)
            let first = try launch(["import", root.path, fixture("regular.ttf").path, "stagingCreated", gate.path])
            defer { if first.0.isRunning { first.0.terminate() } }
            let ready = URL(fileURLWithPath: gate.path + ".ready")
            let deadline = Date().addingTimeInterval(10)
            while !FileManager.default.fileExists(atPath: ready.path) && first.0.isRunning && Date() < deadline { usleep(10_000) }
            XCTAssertTrue(FileManager.default.fileExists(atPath: ready.path))
            let second = try launch(["import", root.path, fixture(sameInput ? "regular.ttf" : "bold.ttf").path])
            defer { if second.0.isRunning { second.0.terminate() } }
            usleep(100_000)
            XCTAssertTrue(second.0.isRunning, "다른 writer의 잠금이 풀릴 때까지 기다려야 함")
            try Data([1]).write(to: gate)
            _ = try finish(first)
            let result = try JSONDecoder().decode([FontImportItemResult].self, from: finish(second))
            XCTAssertEqual(result[0].status, sameInput ? .alreadyPresent : .added)
            let manifest = try await FontLibraryStore(rootURL: root).list()
            XCTAssertEqual(manifest.entries.count, sameInput ? 1 : 2)
            XCTAssertEqual(manifest.generation, sameInput ? 1 : 2)
        }
    }
    func testConcurrentProcessInitialization() async throws {
        for attempt in 0..<10 {
            let root = temporary.appendingPathComponent("initial-\(attempt)")
            let first = try launch(["import", root.path, fixture("regular.ttf").path])
            let second = try launch(["import", root.path, fixture("bold.ttf").path])
            _ = try finish(first)
            _ = try finish(second)
            let manifest = try await FontLibraryStore(rootURL: root).list()
            XCTAssertEqual(manifest.entries.count, 2)
        }
    }
    func testSeparateReaderSurvivesDeletionAndCrashReleasesLease() async throws {
        for crash in [false, true] {
            let root = temporary.appendingPathComponent(crash ? "crashed-reader" : "reader")
            let source = temporary.appendingPathComponent(UUID().uuidString + ".ttf")
            try FileManager.default.copyItem(at: fixture("regular.ttf"), to: source)
            let store = FontLibraryStore(rootURL: root)
            _ = await store.importCandidates([.init(sourceURL: source)])
            let manifest = try await store.list()
            let entry = try XCTUnwrap(manifest.entries.first)
            try FileManager.default.removeItem(at: source)
            let gate = temporary.appendingPathComponent(UUID().uuidString)
            let reader = try launch(["reader", root.path, gate.path, crash ? "crash" : "release"])
            defer { if reader.0.isRunning { reader.0.terminate() } }
            let deadline = Date().addingTimeInterval(10)
            while !FileManager.default.fileExists(atPath: gate.path + ".ready") && reader.0.isRunning && Date() < deadline {
                usleep(10_000)
            }
            XCTAssertTrue(FileManager.default.fileExists(atPath: gate.path + ".ready"))
            _ = try await store.remove(objectHash: entry.object.sha256, expectedGeneration: manifest.generation)
            let fresh = try await store.acquireSnapshot()
            XCTAssertTrue(fresh.resources.isEmpty)
            let held = try await store.recover()
            XCTAssertEqual(held.removedObjects, 0)
            try Data([1]).write(to: gate)
            _ = try finish(reader, expected: crash ? 72 : 0)
            if !crash {
                XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: gate.path + ".bytes")),
                               try Data(contentsOf: fixture("regular.ttf")))
                let face = try JSONDecoder().decode(FontFace.self,
                    from: Data(contentsOf: URL(fileURLWithPath: gate.path + ".face")))
                XCTAssertEqual(face, entry.faces[0])
            }
            let collected = try await FontLibraryStore(rootURL: root).recover()
            XCTAssertEqual(collected.removedObjects, 1)
            try await store.releaseSnapshot(fresh)
        }
    }

}
