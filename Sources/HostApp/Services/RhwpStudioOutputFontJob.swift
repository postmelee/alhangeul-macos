import Foundation

enum RhwpStudioOutputFontRoute { static let scheme = "alhangeul-pdf-font" }

struct RhwpStudioOutputDocumentIdentity: Equatable, Sendable {
    let loadToken: String
    let epoch: Int
    let revision: Int
}

struct RhwpStudioOutputFontRequest: Codable, Hashable, Sendable {
    let key: String
    let family: String
    let weight: Int
    let slant: String
    let hasStroke: Bool?
    let hasUnsupportedStyle: Bool?

    init(key: String, family: String, weight: Int, slant: String,
         hasStroke: Bool? = nil, hasUnsupportedStyle: Bool? = nil) {
        self.key = key; self.family = family; self.weight = weight; self.slant = slant
        self.hasStroke = hasStroke; self.hasUnsupportedStyle = hasUnsupportedStyle
    }
}

struct RhwpStudioOutputFontSelection: Decodable, Sendable {
    let key: String
    let status: String
    let id: String?
    let postscriptName: String?
    let weight: Int?
    let slant: String?
}

struct RhwpStudioOutputFontResolution: Decodable, Sendable {
    let identity: String
    let revision: String
    let generation: Int
    let selections: [RhwpStudioOutputFontSelection]
}

struct RhwpStudioOutputFontDescriptor: Encodable, Sendable {
    let alias: String
    let url: String
    let weight: Int
    let slant: String
}

struct RhwpStudioOutputFontNode: Encodable, Sendable {
    let key: String
    let font: RhwpStudioOutputFontDescriptor?
}

struct RhwpStudioOutputFontLimits: Sendable {
    var faces = 64
    var requests = 2048
    var fileBytes = 64 * 1024 * 1024
    var residentBytes = 128 * 1024 * 1024
}

// 하나의 출력만 소유한다. 화면 session의 navigation 수명과 독립이다.
@MainActor
final class RhwpStudioOutputFontJob {
    typealias Resolver = @MainActor ([RhwpStudioOutputFontRequest]) async throws -> RhwpStudioOutputFontResolution
    private struct Prepared {
        let bytes: StudioFontBytes
        let descriptor: RhwpStudioOutputFontDescriptor
    }
    let document: RhwpStudioOutputDocumentIdentity
    let token = UUID().uuidString
    private let snapshot: StudioFontSupplySnapshot
    private let resolve: Resolver
    private let documentIsCurrent: @MainActor () async throws -> Bool
    private let budget: StudioFontTransferBudget
    private let limits: RhwpStudioOutputFontLimits
    private var active = true
    private var sealed = false
    private var binding: (revision: String, generation: Int)?
    private var requests = Set<String>()
    private var prepared: [String: Prepared] = [:]
    private var pending: [String: Task<StudioFontBytes, Error>] = [:]
    private var reservedBytes = 0
    private var releaseTask: Task<Void, Never>?

    init(document: RhwpStudioOutputDocumentIdentity, snapshot: StudioFontSupplySnapshot,
         budget: StudioFontTransferBudget = .shared, limits: RhwpStudioOutputFontLimits = .init(),
         documentIsCurrent: @escaping @MainActor () async throws -> Bool, resolve: @escaping Resolver) {
        self.document = document; self.snapshot = snapshot; self.budget = budget; self.limits = limits
        self.documentIsCurrent = documentIsCurrent; self.resolve = resolve
    }

    deinit {
        let work = Array(pending.values), snapshot = snapshot, release = releaseTask
        work.forEach { $0.cancel() }
        if release == nil {
            Task { for task in work { _ = try? await task.value }; await snapshot.release() }
        }
    }

    func validate() async throws {
        guard active, !sealed, !Task.isCancelled else { throw RhwpStudioOutputFontError.cancelled }
        let fontsCurrent = try await snapshot.current()
        let documentCurrent = try await documentIsCurrent()
        guard active, !sealed, !Task.isCancelled else { throw RhwpStudioOutputFontError.cancelled }
        guard fontsCurrent, documentCurrent else { throw RhwpStudioOutputFontError.stale }
    }

    func prepare(_ input: [RhwpStudioOutputFontRequest]) async throws -> [RhwpStudioOutputFontNode] {
        try await validate()
        guard input.count <= limits.requests, Set(input.map(\.key)).count == input.count,
              input.allSatisfy({ request in
                  !request.key.isEmpty && request.key.utf8.count <= 1024 && !request.family.isEmpty
                      && request.family.utf8.count <= 1024 && (1...1000).contains(request.weight)
                      && ["normal", "italic", "oblique"].contains(request.slant)
              }) else { throw RhwpStudioOutputFontError.invalidRequest }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        for request in input {
            let signature = try encoder.encode([request.family, String(request.weight), request.slant,
                String(request.hasStroke ?? false), String(request.hasUnsupportedStyle ?? false)])
            requests.insert(String(decoding: signature, as: UTF8.self))
        }
        guard requests.count <= limits.requests else { throw RhwpStudioOutputFontError.tooLarge }
        let result = try await resolve(input)
        try await validate()
        guard result.identity == snapshot.identity, !result.revision.isEmpty, result.revision.utf8.count <= 1024,
              result.generation >= 0, result.selections.count == input.count,
              result.selections.map(\.key) == input.map(\.key) else { throw RhwpStudioOutputFontError.stale }
        if let binding {
            guard binding.revision == result.revision, binding.generation == result.generation else {
                throw RhwpStudioOutputFontError.stale
            }
        } else { binding = (result.revision, result.generation) }
        var nodes: [RhwpStudioOutputFontNode] = []
        for (request, selected) in zip(input, result.selections) {
            if selected.status == "absent" {
                guard selected.id == nil, selected.postscriptName == nil, selected.weight == nil, selected.slant == nil
                else { throw RhwpStudioOutputFontError.invalidRequest }
                nodes.append(.init(key: request.key, font: nil)); continue
            }
            guard selected.status == "selected", let id = selected.id,
                  let ps = selected.postscriptName, !ps.isEmpty,
                  let weight = selected.weight, let slant = selected.slant,
                  [400, 700].contains(request.weight), [400, 700].contains(weight),
                  request.hasStroke != true, request.hasUnsupportedStyle != true,
                  ["normal", "italic", "oblique"].contains(slant)
            else { throw RhwpStudioOutputFontError.unavailable }
            let font = try await read(id, postscriptName: ps, weight: weight, slant: slant)
            nodes.append(.init(key: request.key, font: font))
        }
        try await validate()
        return nodes
    }

    private func read(_ id: String, postscriptName: String, weight: Int, slant: String) async throws -> RhwpStudioOutputFontDescriptor {
        let matches = snapshot.faces.filter { $0.id == id }
        guard matches.count == 1, let metadata = matches.first, metadata.validMetadata, metadata.limitation == nil,
              metadata.postScriptName == postscriptName else { throw RhwpStudioOutputFontError.unavailable }
        if let existing = prepared[id] {
            guard existing.descriptor.weight == weight, existing.descriptor.slant == slant else { throw RhwpStudioOutputFontError.stale }
            return existing.descriptor
        }
        let task: Task<StudioFontBytes, Error>
        let owner: Bool
        if let existing = pending[id] { task = existing; owner = false }
        else {
            guard prepared.count + pending.count < limits.faces,
                  limits.fileBytes > 0, reservedBytes <= limits.residentBytes - limits.fileBytes - residentBytes
            else { throw RhwpStudioOutputFontError.tooLarge }
            reservedBytes += limits.fileBytes
            let snapshot = snapshot, budget = budget
            task = Task {
                let slot = try await budget.acquire()
                do {
                    let supplied = try await snapshot.read(id)
                    try Task.checkCancellation()
                    let inspected = try await Task.detached(priority: .utility) {
                        try FontFileInspector().inspect(supplied.data, filename: "output.ttf")
                    }.value
                    guard inspected.faces.count == 1, inspected.faces[0] == supplied.face else {
                        throw RhwpStudioOutputFontError.stale
                    }
                    let value = StudioFontBytes(data: supplied.data, face: inspected.faces[0], usageEvidence: supplied.usageEvidence)
                    try Task.checkCancellation()
                    await budget.release(slot)
                    return value
                } catch { await budget.release(slot); throw error }
            }
            pending[id] = task; owner = true
        }
        defer {
            if owner, pending.removeValue(forKey: id) != nil { reservedBytes -= limits.fileBytes }
        }
        let value = try await task.value
        try await validate()
        guard !value.data.isEmpty, value.data.count <= limits.fileBytes else { throw RhwpStudioOutputFontError.tooLarge }
        guard value.face.postScriptName == postscriptName, Int(value.face.weightClass) == weight
        else { throw RhwpStudioOutputFontError.stale }
        try RhwpStudioOutputFontPolicy.validate(value)
        let actualSlant = value.face.selectionFlags & 512 != 0 || value.face.subfamilyName?.lowercased().contains("oblique") == true
            ? "oblique" : (value.face.selectionFlags & 1 != 0 || value.face.italicAngle != 0 ? "italic" : "normal")
        guard actualSlant == slant else { throw RhwpStudioOutputFontError.unsupported }
        if let existing = prepared[id] { return existing.descriptor }
        guard value.data.count <= limits.residentBytes - residentBytes else { throw RhwpStudioOutputFontError.tooLarge }
        let resource = UUID().uuidString
        let descriptor = RhwpStudioOutputFontDescriptor(alias: "AlhangeulOutput" + resource.replacingOccurrences(of: "-", with: ""),
            url: "\(RhwpStudioOutputFontRoute.scheme)://snapshot/\(token)/\(resource)", weight: weight, slant: slant)
        prepared[id] = Prepared(bytes: value, descriptor: descriptor)
        return descriptor
    }

    var residentBytes: Int { prepared.values.reduce(0) { $0 + $1.bytes.data.count } }

    func resource(for url: URL) throws -> (data: Data, mimeType: String) {
        guard active, !sealed, let row = prepared.values.first(where: { $0.descriptor.url == url.absoluteString }) else {
            throw RhwpStudioOutputFontError.invalidRequest
        }
        // allowlist의 생성한 exact URL만 허용한다. decode/경로 해석은 하지 않는다.
        let cff = row.bytes.data.prefix(4) == Data([0x4f,0x54,0x54,0x4f])
        return (row.bytes.data, cff ? "font/otf" : "font/ttf")
    }

    func seal() async throws { try await validate(); sealed = true }

    func cancel() {
        active = false; prepared.removeAll(); pending.values.forEach { $0.cancel() }
        Task { await close() }
    }

    func close() async {
        active = false; prepared.removeAll()
        let tasks = Array(pending.values); tasks.forEach { $0.cancel() }
        for task in tasks { _ = try? await task.value }
        pending.removeAll(); reservedBytes = 0
        if releaseTask == nil {
            let snapshot = snapshot
            releaseTask = Task { await snapshot.release() }
        }
        await releaseTask?.value
    }
}
