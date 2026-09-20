import Foundation

// WebView에 전달하는 데이터에는 원본 위치와 권한 정보가 없다.
struct StudioFontFace: Encodable, Sendable {
    let id: String
    let source: String
    let postScriptName: String
    let family: String
    let fullName: String
    let style: String
    let aliases: [String]
    let weight: Int?
    let traits: UInt32
    let limitation: String?

    var validMetadata: Bool {
        [id, source, postScriptName, family, fullName, style].allSatisfy { $0.utf8.count <= 1024 }
            && aliases.count <= 32 && aliases.allSatisfy { $0.utf8.count <= 1024 }
    }
}

struct StudioFontBytes: Sendable {
    let data: Data
    let face: FontFace
}

struct StudioFontSupplySnapshot: Sendable {
    let identity: String
    let faces: [StudioFontFace]
    let omitted: Int
    let failure: String?
    let read: @Sendable (String) async throws -> StudioFontBytes
    let current: @Sendable () async throws -> Bool
    let release: @Sendable () async -> Void
}

struct StudioFontSupply: Sendable {
    let snapshot: @Sendable () async throws -> StudioFontSupplySnapshot

    static let live = StudioFontSupply {
        let installed = try await InstalledFontServiceProvider.shared.service()
        if await installed.snapshot().refreshFailure == .notPrepared {
            _ = try await installed.prepare()
        }
        let state = await installed.snapshot()
        let library = try FontLibraryService.shared.get()
        let manifest = try await library.list()
        let managed = try await library.acquireSnapshot()
        guard managed.generation == manifest.generation else {
            try? await library.releaseSnapshot(managed)
            throw StudioFontError.staleGeneration
        }
        let installedFaces = state.records.map { record in
            StudioFontFace(id: "installed:" + record.id, source: "installed",
                postScriptName: record.postScriptName, family: record.family,
                fullName: record.fullName, style: record.style,
                aliases: Array(Set([record.family, record.fullName, record.postScriptName])).sorted(),
                weight: nil, traits: record.traits,
                limitation: (!state.enabled ? "disabled" : state.refreshFailure?.rawValue)
                    ?? record.failure?.rawValue ?? (record.axes.isEmpty ? nil : "unsupported"))
        }
        let managedFaces = managed.resources.map { resource in
            let face = resource.face
            let aliases = Set(face.names.filter { [1, 4, 6, 16].contains($0.nameID) }.compactMap(\.value))
            return StudioFontFace(id: "managed:" + resource.id, source: "managed",
                postScriptName: face.postScriptName, family: face.familyName ?? "",
                fullName: face.fullName ?? face.postScriptName, style: face.subfamilyName ?? "",
                aliases: aliases.sorted(), weight: Int(face.weightClass), traits: UInt32(face.selectionFlags),
                limitation: face.applicationSupport == .staticCandidate ? nil : "unsupported")
        }
        guard state.records.count <= 20_000, managed.resources.count <= 4096 else {
            try? await library.releaseSnapshot(managed)
            throw StudioFontError.catalogLimit
        }
        let selectedGroups = Set(manifest.activeSelections.map(\.conflictGroupID))
        let unresolvedIDs = Set(manifest.conflictGroups.filter { !selectedGroups.contains($0.id) }.flatMap(\.members))
        let conflicts = manifest.entries.flatMap(\.faces).filter { unresolvedIDs.contains($0.id) }.map { face in
            StudioFontFace(id: "conflict:\(face.id.objectHash):\(face.id.sfntIndex)", source: "managed",
                postScriptName: face.postScriptName, family: face.familyName ?? "",
                fullName: face.fullName ?? face.postScriptName, style: face.subfamilyName ?? "",
                aliases: Array(Set(face.names.filter { [1, 4, 6, 16].contains($0.nameID) }.compactMap(\.value))).sorted(),
                weight: Int(face.weightClass), traits: UInt32(face.selectionFlags), limitation: "conflict")
        }
        guard managedFaces.count + conflicts.count <= 4096 else {
            try? await library.releaseSnapshot(managed)
            throw StudioFontError.catalogLimit
        }
        let faces = managedFaces + conflicts + installedFaces
        let valid = faces.filter(\.validMetadata)
        let generation = state.generation
        return StudioFontSupplySnapshot(identity: "\(generation):\(managed.generation):\(managed.digest)",
            faces: valid, omitted: state.omittedFaceCount + faces.count - valid.count,
            failure: state.refreshFailure?.rawValue,
            read: { id in
                if let resource = managed.resources.first(where: { "managed:" + $0.id == id }) {
                    return StudioFontBytes(data: try await library.readResource(resource.id, snapshot: managed), face: resource.face)
                }
                guard let record = state.records.first(where: { "installed:" + $0.id == id }) else {
                    throw StudioFontError.invalidRequest
                }
                let result = try await installed.readResource(record.id, expectedGeneration: generation)
                return StudioFontBytes(data: result.data, face: result.face)
            }, current: {
                let latest = await installed.snapshot()
                let manifest = try await library.list()
                return latest.generation == generation && manifest.generation == managed.generation
            }, release: { try? await library.releaseSnapshot(managed) })
    }
}

enum StudioFontError: String, Error {
    case invalidRequest, unauthorized, staleSession, staleGeneration, busy, tooLarge, catalogLimit, unavailable, cancelled
}

// 읽는 중인 요청도 slot을 점유한다. 취소된 I/O가 반환할 때까지 slot을 유지한다.
actor StudioFontTransferBudget {
    static let shared = StudioFontTransferBudget()
    private var slots = Set<UUID>()
    func acquire() throws -> UUID {
        guard slots.count < 2 else { throw StudioFontError.busy }
        let id = UUID(); slots.insert(id); return id
    }
    func release(_ id: UUID) { slots.remove(id) }
}
