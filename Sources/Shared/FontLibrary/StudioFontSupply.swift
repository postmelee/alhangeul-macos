import Foundation

struct StudioFontSupply: Sendable {
    let snapshot: @Sendable () async throws -> StudioFontSupplySnapshot

    static let live = using(installed: .shared, library: { try FontLibraryService.shared.get() })

    static func using(installed provider: InstalledFontServiceProvider,
                      library makeLibrary: @escaping @Sendable () throws -> FontLibraryService) -> Self {
        Self {
            let installed = try await provider.service()
            if await installed.snapshot().refreshFailure == .notPrepared {
                _ = try await installed.prepare()
            }
            let state = await installed.snapshot()
            let library = try makeLibrary()
            let manifest = try await library.list()
            let managed = try await library.acquireMetadataSnapshot()
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
                        return StudioFontBytes(data: try await library.readResource(resource.id, snapshot: managed),
                                               face: resource.face, usageEvidence: resource.usageEvidence)
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
}
