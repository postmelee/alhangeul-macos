import CryptoKit
import Darwin
import Foundation

final class FontLibraryStore: Sendable {
    private let rootURL: URL
    // 같은 프로세스의 별도 서비스 인스턴스도 초기화부터 하나의 writer를 공유한다.
    private static let queue = DispatchQueue(label: "com.postmelee.alhangeul.font-library", qos: .utility)
    private let limits: FontImportLimits
    private let fault: @Sendable (FontLibraryWritePhase) throws -> Void
    private let maximumManifestBytes = 32 * 1024 * 1024

    init(rootURL: URL, limits: FontImportLimits = FontImportLimits(),
         fault: @escaping @Sendable (FontLibraryWritePhase) throws -> Void = { _ in }) {
        self.rootURL = rootURL
        self.limits = limits
        self.fault = fault
    }

    func list() async throws -> FontLibraryManifest {
        try await perform {
            let fs = try FontLibraryFileSystem(rootURL: self.rootURL)
            return try fs.withLock { try self.load(fs) }
        }
    }

    func importCandidates(_ candidates: [FontImportCandidate]) async -> [FontImportItemResult] {
        let cancellation = FontImportCancellation()
        return await withTaskCancellationHandler(operation: {
            await withCheckedContinuation { continuation in
                Self.queue.async {
                    var consumed = 0
                    let results = candidates.enumerated().map { index, candidate in
                        self.importOne(candidate, index: index, consumed: &consumed, cancellation: cancellation)
                    }
                    continuation.resume(returning: results)
                }
            }
        }, onCancel: { cancellation.cancel() })
    }

    func selectActive(groupID: String, faceID: FontFaceID, expectedGeneration: UInt64) async throws -> FontLibraryManifest {
        try await perform {
            let fs = try FontLibraryFileSystem(rootURL: self.rootURL)
            return try fs.withLock {
                var manifest = try self.load(fs)
                guard manifest.generation == expectedGeneration else { throw FontLibraryError.staleGeneration }
                guard let group = manifest.conflictGroups.first(where: { $0.id == groupID }),
                      group.members.contains(faceID),
                      let entry = manifest.entries.first(where: { $0.object.sha256 == faceID.objectHash }),
                      let face = entry.faces.first(where: { $0.id == faceID }) else { throw FontLibraryError.invalidSelection }
                guard face.applicationSupport == .staticCandidate else { throw FontLibraryError.unsupportedSelection }
                try self.verifyObject(entry.object, fs: fs)
                if manifest.activeSelections.contains(where: { $0.conflictGroupID == groupID && $0.faceID == faceID }) {
                    return manifest
                }
                manifest.activeSelections.removeAll { $0.conflictGroupID == groupID }
                manifest.activeSelections.append(.init(conflictGroupID: groupID, faceID: faceID, axes: [:]))
                try self.advance(&manifest)
                try self.publish(manifest, bytes: nil, object: nil, fs: fs, cancelled: { false })
                return manifest
            }
        }
    }

    private func perform<T: Sendable>(_ operation: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            Self.queue.async { continuation.resume(with: Result { try operation() }) }
        }
    }

    private func importOne(_ candidate: FontImportCandidate, index: Int, consumed: inout Int,
                           cancellation: FontImportCancellation) -> FontImportItemResult {
        var objectHash: String?
        var reading = true
        var operation = "sourceRead"
        func result(_ status: FontImportStatus, _ reason: String? = nil,
                    _ action: FontImportItemResult.NextAction = .none,
                    _ publication: FontPublicationState = .notPublished) -> FontImportItemResult {
            .init(candidateID: candidate.id, status: status, objectHash: objectHash,
                  reasonCode: reason, nextAction: action, publication: publication)
        }
        do {
            if cancellation.isCancelled { throw FontLibraryError.cancelled }
            guard index < limits.maximumCandidates, limits.maximumFileBytes > 0,
                  limits.maximumBatchBytes > consumed else { throw FontLibraryError.inputLimitExceeded }
            guard candidate.sourceURL.isFileURL else { throw FontLibraryError.unsafePath }
            let fd = open(candidate.sourceURL.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
            guard fd >= 0 else { throw FontLibraryError.io(errno) }
            let bytes: Data
            do {
                bytes = try FontLibraryDirectory.readFile(fd,
                    limit: min(64 * 1024 * 1024, limits.maximumFileBytes, limits.maximumBatchBytes - consumed),
                    cancelled: { cancellation.isCancelled }, didRead: { consumed += $0 })
                close(fd)
            } catch { close(fd); throw error }
            var inspectionLimits = FontInspectionLimits()
            inspectionLimits.maximumFileBytes = min(inspectionLimits.maximumFileBytes, limits.maximumFileBytes)
            let inspected = try FontFileInspector(limits: inspectionLimits).inspect(bytes, filename: candidate.sourceURL.lastPathComponent)
            objectHash = inspected.object.sha256
            if cancellation.isCancelled { throw FontLibraryError.cancelled }
            reading = false
            operation = "openLibrary"
            let fs = try FontLibraryFileSystem(rootURL: rootURL)
            return try fs.withLock(cancelled: { cancellation.isCancelled }) {
                operation = "loadManifest"
                var manifest = try load(fs)
                if let old = manifest.entries.first(where: { $0.object.sha256 == inspected.object.sha256 }) {
                    try verifyObject(old.object, fs: fs)
                    // 이전 호출에서 디렉터리 동기화가 실패한 경우 재시도가 내구성을 다시 확인한다.
                    try fs.objects.sync(); try fs.syncPublication()
                    return result(.alreadyPresent, nil, .none, .durable)
                }
                guard manifest.entries.count < 4096 else { throw FontLibraryError.capacityExceeded }
                let entry = FontLibraryEntry(object: inspected.object, faces: inspected.faces,
                    source: .init(id: candidate.id, kind: candidate.sourceKind,
                                  originalFilename: candidate.sourceURL.lastPathComponent,
                                  localSourcePath: candidate.sourceURL.path, bookmark: nil, importedAt: Date()),
                    usageEvidence: candidate.usageEvidence,
                    filenameExtensionMismatch: inspected.filenameExtensionMismatch)
                let conflict = add(entry, to: &manifest)
                try advance(&manifest)
                operation = "publish"
                try publish(manifest, bytes: bytes, object: inspected.object, fs: fs,
                            cancelled: { cancellation.isCancelled })
                if conflict { return result(.selectionRequired, "nameConflict", .chooseActiveFace, .durable) }
                let limited = inspected.faces.contains { $0.applicationSupport != .staticCandidate }
                return result(.added, limited ? "applicationUnverified" : nil,
                              limited ? .reviewSupportLimits : .none, .durable)
            }
        } catch FontLibraryError.cancelled { return result(.cancelled) }
        catch FontLibraryError.publicationUncertain {
            return result(.storageFailure, "commitVisibleDurabilityUnconfirmed", .retry, .visibleDurabilityUnconfirmed)
        } catch let error as FontInspectionError {
            switch error {
            case .unsupportedFormat, .unsupportedStructure:
                return result(.unsupported, String(describing: error), .chooseSupportedFile)
            case .fileTooLarge, .metadataLimitExceeded:
                return result(.unsupported, String(describing: error), .chooseSupportedFile)
            default: return result(.corrupt, String(describing: error), .chooseSupportedFile)
            }
        } catch FontLibraryError.inputLimitExceeded {
            return result(.unsupported, "inputLimitExceeded", .chooseSupportedFile)
        } catch {
            let reason: String
            if case FontLibraryError.io(let code) = error { reason = "\(operation):io(\(code))" }
            else { reason = (error as? FontLibraryError).map { String(describing: $0) } ?? "operationFailed" }
            return result(reading ? .readFailure : .storageFailure, reason, reading ? .chooseReadableFile : .retry)
        }
    }

    private func load(_ fs: FontLibraryFileSystem) throws -> FontLibraryManifest {
        guard let data = try fs.root.read("current.json", limit: maximumManifestBytes) else {
            guard try !fs.initializationMarked(), try fs.objects.isEmpty(), try fs.staging.isEmpty() else {
                throw FontLibraryError.missingManifest
            }
            let empty = FontLibraryManifest()
            // 초기 빈 manifest에는 장애 주입을 하지 않는다. 첫 입력 전에 내구성 표식을 확정한다.
            let temp = ".initial-\(UUID().uuidString)"
            defer { try? fs.root.remove(temp) }
            try fs.root.writeNew(temp, data: JSONEncoder().encode(empty))
            try fs.root.move(temp, to: fs.root, name: "current.json")
            try fs.root.sync()
            try fs.markInitialized()
            return empty
        }
        let decoder = JSONDecoder()
        struct Header: Decodable { let schemaVersion: Int }
        guard let header = try? decoder.decode(Header.self, from: data) else { throw FontLibraryError.corruptManifest }
        guard header.schemaVersion == 1 else { throw FontLibraryError.unsupportedSchema }
        guard let manifest = try? decoder.decode(FontLibraryManifest.self, from: data) else {
            throw FontLibraryError.corruptManifest
        }
        try validate(manifest)
        if try !fs.initializationMarked() { try fs.markInitialized() }
        return manifest
    }

    private func validate(_ manifest: FontLibraryManifest) throws {
        var hashes = Set<String>(), ids = Set<FontFaceID>()
        guard manifest.entries.count <= 4096 else { throw FontLibraryError.corruptManifest }
        for entry in manifest.entries {
            let hash = entry.object.sha256
            guard hash.count == 64, hash.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }),
                  hashes.insert(hash).inserted, entry.object.byteCount > 0,
                  entry.object.byteCount <= 64 * 1024 * 1024,
                  entry.object.faceCount == entry.faces.count, !entry.faces.isEmpty,
                  entry.faces.enumerated().allSatisfy({ index, face in
                      face.id.objectHash == hash && face.id.sfntIndex == index && ids.insert(face.id).inserted
                  }) else { throw FontLibraryError.corruptManifest }
        }
        var groups = Set<String>(), grouped = Set<FontFaceID>()
        for group in manifest.conflictGroups {
            guard !group.id.isEmpty, groups.insert(group.id).inserted, !group.members.isEmpty,
                  Set(group.members).count == group.members.count,
                  group.members.allSatisfy({ ids.contains($0) }) else { throw FontLibraryError.corruptManifest }
            grouped.formUnion(group.members)
        }
        guard grouped == ids else { throw FontLibraryError.corruptManifest }
        var selectedGroups = Set<String>()
        let facesByID = Dictionary(uniqueKeysWithValues: manifest.entries.flatMap(\.faces).map { ($0.id, $0) })
        for selection in manifest.activeSelections {
            guard selectedGroups.insert(selection.conflictGroupID).inserted,
                  let group = manifest.conflictGroups.first(where: { $0.id == selection.conflictGroupID }),
                  group.members.contains(selection.faceID), selection.axes.isEmpty,
                  facesByID[selection.faceID]?.applicationSupport == .staticCandidate else {
                throw FontLibraryError.corruptManifest
            }
        }
    }

    private func add(_ entry: FontLibraryEntry, to manifest: inout FontLibraryManifest) -> Bool {
        var conflict = false
        for face in entry.faces {
            let existing = manifest.entries.flatMap(\.faces) + entry.faces.filter { $0.id.sfntIndex < face.id.sfntIndex }
            let matches = Set(existing.filter { Self.conflicts($0, face) }.map(\.id))
            let indices = manifest.conflictGroups.indices.filter {
                manifest.conflictGroups[$0].members.contains { matches.contains($0) }
            }
            if indices.isEmpty {
                let id = UUID().uuidString
                manifest.conflictGroups.append(.init(id: id, members: [face.id]))
                if face.applicationSupport == .staticCandidate {
                    manifest.activeSelections.append(.init(conflictGroupID: id, faceID: face.id, axes: [:]))
                }
            } else {
                conflict = true
                // 여러 기존 그룹을 잇는 후보도 기존 활성 선택을 합치거나 자동 해제하지 않는다.
                for index in indices { manifest.conflictGroups[index].members.append(face.id) }
            }
        }
        manifest.entries.append(entry)
        return conflict
    }

    private static func normalized(_ text: String) -> String {
        text.precomposedStringWithCanonicalMapping.split(whereSeparator: \.isWhitespace).joined(separator: " ").lowercased()
    }

    private static func conflicts(_ first: FontFace, _ second: FontFace) -> Bool {
        if normalized(first.postScriptName) == normalized(second.postScriptName) { return true }
        guard let a = first.familyName, let b = second.familyName, !a.isEmpty, !b.isEmpty else { return false }
        return normalized(a) == normalized(b)
            && normalized(first.subfamilyName ?? "") == normalized(second.subfamilyName ?? "")
            && first.weightClass == second.weightClass && first.widthClass == second.widthClass
            && first.selectionFlags & 0x201 == second.selectionFlags & 0x201
            && first.italicAngle == second.italicAngle
    }

    private func advance(_ manifest: inout FontLibraryManifest) throws {
        guard manifest.generation < UInt64.max else { throw FontLibraryError.capacityExceeded }
        manifest.generation += 1
    }

    private func verifyObject(_ object: FontObject, fs: FontLibraryFileSystem) throws {
        guard let bytes = try fs.objects.read(object.sha256 + ".font", limit: object.byteCount),
              bytes.count == object.byteCount, Self.hash(bytes) == object.sha256 else {
            throw FontLibraryError.corruptObject
        }
    }

    private static func hash(_ bytes: Data) -> String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }

    private func publish(_ manifest: FontLibraryManifest, bytes: Data?, object: FontObject?,
                         fs: FontLibraryFileSystem, cancelled: () -> Bool) throws {
        try validate(manifest)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(manifest)
        guard data.count <= maximumManifestBytes else { throw FontLibraryError.capacityExceeded }
        let transactionID = UUID().uuidString
        let transaction = try fs.staging.child(transactionID)
        defer {
            try? transaction.remove("object")
            try? transaction.remove("manifest")
            try? fs.staging.remove(transactionID, directory: true)
        }
        var replaced = false
        do {
            try fault(.stagingCreated)
            if cancelled() { throw FontLibraryError.cancelled }
            if let bytes, let object {
                let name = object.sha256 + ".font"
                if try fs.objects.read(name, limit: object.byteCount) != nil {
                    try verifyObject(object, fs: fs)
                } else {
                    try transaction.writeNew("object", data: bytes,
                        written: { try self.fault(.stageWritten) }, synced: { try self.fault(.stageSynced) })
                    try transaction.sync()
                    if cancelled() { throw FontLibraryError.cancelled }
                    try transaction.move("object", to: fs.objects, name: name, replacing: false)
                    try fault(.objectPublished)
                }
                try fs.objects.sync(); try transaction.sync()
                try fault(.objectDirectorySynced)
            }
            try transaction.writeNew("manifest", data: data,
                written: { try self.fault(.manifestWritten) }, synced: { try self.fault(.manifestSynced) })
            try transaction.sync()
            if cancelled() { throw FontLibraryError.cancelled }
            try transaction.move("manifest", to: fs.root, name: "current.json")
            replaced = true
            try fault(.manifestReplaced)
            try transaction.sync(); try fs.syncPublication()
            try fault(.manifestDirectorySynced)
        } catch {
            if replaced {
                // 게시됐지만 내구성이 미확인인 변경을 성공이나 미저장으로 잘못 보고하지 않는다.
                guard (try? fs.root.read("current.json", limit: maximumManifestBytes)) == data else {
                    throw FontLibraryError.corruptManifest
                }
                throw FontLibraryError.publicationUncertain
            }
            throw error
        }
    }
}

extension FontLibraryStore {
    func remove(objectHash: String, expectedGeneration: UInt64) async throws -> FontLibraryManifest {
        try await perform {
            let fs = try FontLibraryFileSystem(rootURL: self.rootURL)
            return try fs.withLock {
                var manifest = try self.load(fs)
                guard manifest.generation == expectedGeneration else { throw FontLibraryError.staleGeneration }
                guard manifest.entries.contains(where: { $0.object.sha256 == objectHash }) else {
                    throw FontLibraryError.invalidSelection
                }
                manifest.entries.removeAll { $0.object.sha256 == objectHash }
                for index in manifest.conflictGroups.indices {
                    manifest.conflictGroups[index].members.removeAll { $0.objectHash == objectHash }
                }
                manifest.conflictGroups.removeAll { $0.members.isEmpty }
                // 삭제된 활성 항목을 다른 버전으로 자동 대체하지 않는다.
                manifest.activeSelections.removeAll { $0.faceID.objectHash == objectHash }
                try self.advance(&manifest)
                try self.publish(manifest, bytes: nil, object: nil, fs: fs, cancelled: { false })
                return manifest
            }
        }
    }

    func acquireSnapshot() async throws -> FontLibrarySnapshot {
        try await perform {
            let fs = try FontLibraryFileSystem(rootURL: self.rootURL)
            return try fs.withLock {
                let manifest = try self.load(fs)
                var resources: [FontSnapshotResource] = []
                let entries = Dictionary(uniqueKeysWithValues: manifest.entries.map { ($0.object.sha256, $0) })
                for selection in manifest.activeSelections {
                    guard let entry = entries[selection.faceID.objectHash],
                          let face = entry.faces.first(where: { $0.id == selection.faceID }) else {
                        throw FontLibraryError.corruptManifest
                    }
                    try self.verifyObject(entry.object, fs: fs)
                    let resource = FontSnapshotResource(id: "font-\(entry.object.sha256)-\(face.id.sfntIndex)",
                        object: entry.object, face: face, axes: selection.axes, usageEvidence: entry.usageEvidence)
                    if !resources.contains(resource) { resources.append(resource) }
                }
                resources.sort { $0.id < $1.id }
                let leases = try fs.leaseDirectory()
                guard try leases.names().count < 4096 else { throw FontLibraryError.capacityExceeded }
                let session = UUID(), name = session.uuidString + ".json"
                let record = FontLeaseRecord(schemaVersion: 1, sessionID: session,
                    objectHashes: Array(Set(resources.map { $0.object.sha256 })).sorted())
                try leases.writeNew(name, data: JSONEncoder().encode(record))
                let fd = try leases.openFile(name, flags: O_RDONLY)
                do {
                    guard flock(fd, LOCK_EX | LOCK_NB) == 0 else { throw FontLibraryError.io(errno) }
                    try leases.sync(); try fs.syncPublication()
                    return try FontLibrarySnapshot(generation: manifest.generation, resources: resources,
                        rootPath: self.rootURL.standardizedFileURL.path, descriptor: fd)
                } catch { close(fd); throw error }
            }
        }
    }

    func readResource(_ resourceID: String, snapshot: FontLibrarySnapshot) async throws -> Data {
        try await perform {
            try snapshot.withLease(rootPath: self.rootURL.standardizedFileURL.path) {
                guard let resource = snapshot.resources.first(where: { $0.id == resourceID }) else {
                    throw FontLibraryError.invalidResource
                }
                let fs = try FontLibraryFileSystem(rootURL: self.rootURL)
                return try fs.withLock {
                    guard let data = try fs.objects.read(resource.object.sha256 + ".font", limit: resource.object.byteCount),
                          data.count == resource.object.byteCount, Self.hash(data) == resource.object.sha256 else {
                        throw FontLibraryError.corruptObject
                    }
                    return data
                }
            }
        }
    }

    func releaseSnapshot(_ snapshot: FontLibrarySnapshot) async throws {
        try await perform { try snapshot.release(rootPath: self.rootURL.standardizedFileURL.path) }
    }

    func recover() async throws -> FontLibraryRecoveryResult {
        try await perform {
            let fs = try FontLibraryFileSystem(rootURL: self.rootURL)
            return try fs.withLock {
                let manifest = try self.load(fs)
                // 유효 manifest의 객체 변조/유실을 먼저 드러내며 그 상태에서 GC하지 않는다.
                for entry in manifest.entries { try self.verifyObject(entry.object, fs: fs) }
                return try FontLibraryRecovery.collect(fs, manifest: manifest)
            }
        }
    }
}
