import Foundation
import CoreGraphics
import CryptoKit

enum HwpNativeFontSupplyError: Error, Equatable {
    case invalid, stale, unavailable, unsupported, tooLarge
}

struct HwpNativeFontPageResult: Sendable {
    let page: HwpRenderedPage
    // cache를 쓰는 소비자는 크기/policy와 함께 이 identity를 사용하고 snapshot을 재확인한다.
    let cacheIdentity: String
    let snapshotIdentity: String
    let selectedFaces: [String]
    let fallbackFamilies: [String]
    let sourceReads: Int
    let sourceBytes: Int
}

/// immutable 문서 copy와 snapshot lease를 한 요청에 묶는다. 영구 bytes/PNG cache를 만들지 않는다.
/// snapshot의 소유권을 받으며 성공·실패·취소에서 실제 I/O가 끝난 뒤 한 번 release한다.
enum HwpNativeFontPageRenderer {
    struct Limits: Sendable {
        var faces = 64
        var fileBytes = 64 * 1024 * 1024
        var residentBytes = 128 * 1024 * 1024
    }
    static func render(data: Data, filename: String, pageIndex: Int = 0,
                       snapshot: StudioFontSupplySnapshot,
                       maximumPixelSize: CGSize? = nil, policy: HwpPageRenderPolicy = .coreGraphicsOnly,
                       documentIsCurrent: @escaping @Sendable () async throws -> Bool = { true },
                       budget: StudioFontTransferBudget = .shared, limits: Limits = .init()) async throws -> HwpNativeFontPageResult {
        let result: HwpNativeFontPageResult
        do {
            result = try await perform(data: data, filename: filename, pageIndex: pageIndex,
                snapshot: snapshot, maximumPixelSize: maximumPixelSize, policy: policy,
                documentIsCurrent: documentIsCurrent,
                budget: budget, limits: limits)
        } catch {
            await snapshot.release()
            throw error
        }
        await snapshot.release()
        try Task.checkCancellation()
        return result
    }

    private static func validate(_ snapshot: StudioFontSupplySnapshot,
                                 _ document: @Sendable () async throws -> Bool) async throws {
        try Task.checkCancellation()
        guard try await snapshot.current(), try await document() else { throw HwpNativeFontSupplyError.stale }
        try Task.checkCancellation()
    }

    struct Prepared {
        let programs: Data?
        let context: RhwpNativeFontContext?
        let cacheIdentity: String
        let snapshotIdentity: String
        let selectedFaces: [String]
        let fallbackFamilies: [String]
        let sourceReads: Int
        let sourceBytes: Int
    }

    /// 외부 이미지가 주입된 기존 document를 사용한다. 이 호출이 snapshot을 소유한다.
    static func withPreparedPage<T>(document: RhwpDocument, documentIdentity: String, filename: String,
        pageIndex: Int, snapshot: StudioFontSupplySnapshot, maximumPixelSize: CGSize? = nil,
        policy: HwpPageRenderPolicy = .coreGraphicsOnly,
        documentIsCurrent: @escaping @Sendable () async throws -> Bool = { true },
        operation: (Prepared) throws -> T) async throws -> T {
        let result: T
        do {
            let prepared = try await preparePage(document: document, documentIdentity: documentIdentity,
                filename: filename, pageIndex: pageIndex, snapshot: snapshot, maximumPixelSize: maximumPixelSize,
                policy: policy, documentIsCurrent: documentIsCurrent)
            result = try document.withFontPrograms(prepared.programs) { try operation(prepared) }
            try await validate(snapshot, documentIsCurrent)
        } catch {
            await snapshot.release()
            throw error
        }
        await snapshot.release()
        try Task.checkCancellation()
        return result
    }

    private static func perform(data: Data, filename: String, pageIndex: Int, snapshot: StudioFontSupplySnapshot,
        maximumPixelSize: CGSize?, policy: HwpPageRenderPolicy,
        documentIsCurrent: @escaping @Sendable () async throws -> Bool,
        budget: StudioFontTransferBudget, limits: Limits) async throws -> HwpNativeFontPageResult {
        guard data.count <= hwpQuickLookMaxFileSize else { throw HwpNativeFontSupplyError.tooLarge }
        let document = try RhwpDocument(data: data, filename: filename)
        let prepared = try await preparePage(document: document, documentIdentity: digest(data), filename: filename,
            pageIndex: pageIndex, snapshot: snapshot, maximumPixelSize: maximumPixelSize, policy: policy,
            documentIsCurrent: documentIsCurrent, budget: budget, limits: limits)
        let page = try document.withFontPrograms(prepared.programs) {
            try HwpPageImageRenderer.renderPage(document: document, pageIndex: pageIndex,
                maximumPixelSize: maximumPixelSize, policy: policy, fontContext: prepared.context)
        }
        try await validate(snapshot, documentIsCurrent)
        return .init(page: page, cacheIdentity: prepared.cacheIdentity, snapshotIdentity: prepared.snapshotIdentity,
            selectedFaces: prepared.selectedFaces, fallbackFamilies: prepared.fallbackFamilies,
            sourceReads: prepared.sourceReads, sourceBytes: prepared.sourceBytes)
    }

    /// snapshot을 빌린다. 여러 페이지 PDF의 외부 호출자가 같은 세대의 lease를 한 번 해제한다.
    static func preparePage(document: RhwpDocument, documentIdentity: String, filename: String,
        pageIndex: Int, snapshot: StudioFontSupplySnapshot, maximumPixelSize: CGSize? = nil,
        policy: HwpPageRenderPolicy = .coreGraphicsOnly,
        documentIsCurrent: @escaping @Sendable () async throws -> Bool = { true },
        budget: StudioFontTransferBudget = .shared, limits: Limits = .init()) async throws -> Prepared {
        guard !documentIdentity.isEmpty, limits.faces > 0, limits.faces <= 64,
              limits.fileBytes > 0, limits.fileBytes <= 64 * 1024 * 1024,
              limits.residentBytes > 0, limits.residentBytes <= 128 * 1024 * 1024 else { throw HwpNativeFontSupplyError.tooLarge }
        guard !filename.isEmpty, filename.utf8.count <= 1024 else { throw HwpNativeFontSupplyError.invalid }
        if let size = maximumPixelSize {
            guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0,
                  size.width <= 16_384, size.height <= 16_384 else { throw HwpNativeFontSupplyError.invalid }
        }
        try await validate(snapshot, documentIsCurrent)
        let sourceNames = Set(try document.declaredFontCandidates())
        var sourceData = [String: StudioFontBytes]()
        var programs = [[String: Any]]()
        var sourceBytes = 0
        let declaredRequests = sourceNames.sorted().map {
            RhwpNativeFontMatcher.Request(key: $0, family: $0, weight: 400, slant: "normal", hftCandidateOnly: true)
        }
        var declared = [RhwpNativeFontMatcher.Selection]()
        if !snapshot.faces.isEmpty {
            for start in stride(from: 0, to: declaredRequests.count, by: 2048) {
                try await validate(snapshot, documentIsCurrent)
                let batch = Array(declaredRequests[start..<min(start + 2048, declaredRequests.count)])
                declared += try await RhwpNativeFontMatcher.resolve(snapshot: snapshot, requests: batch)
            }
        }
        for choice in declared {
            let family = choice.key
            guard choice.status == "selected", choice.weight == 400, let id = choice.id,
                  let row = snapshot.faces.first(where: { $0.id == id }), row.limitation == nil else { continue }
            let value: StudioFontBytes
            if let existing = sourceData[row.id] { value = existing } else {
                guard sourceData.count < limits.faces, sourceBytes <= limits.residentBytes - limits.fileBytes else {
                    throw HwpNativeFontSupplyError.tooLarge
                }
                value = try await read(row.id, snapshot: snapshot, budget: budget, maximumBytes: limits.fileBytes)
                sourceBytes += value.data.count
                sourceData[row.id] = value
            }
            guard value.data.starts(with: "OTTO".utf8), value.face.weightClass == 400,
                  value.face.names.contains(where: { [1,16].contains($0.nameID) && $0.value == family }) else { continue }
            programs.append(["query":family, "family":family, "openTypeCff":true, "programId":digest(value.data)])
        }
        try await validate(snapshot, documentIsCurrent)
        let programData = programs.isEmpty ? nil : try JSONSerialization.data(withJSONObject: ["programs":programs])
        let hftSources = Set(programs.compactMap { $0["query"] as? String })
        let slots = try document.withFontPrograms(programData) { try document.nativeFontRequests(at: pageIndex) }
        let requests = slots.enumerated().map { index, slot in
            RhwpNativeFontMatcher.Request(key: String(index), family: slot.family,
                weight: slot.bold ? 700 : 400, slant: slot.italic ? "italic" : "normal", allowHftRegular: hftSources.contains(slot.family))
        }
        let selections = try await RhwpNativeFontMatcher.resolve(snapshot: snapshot, requests: requests)
        try await validate(snapshot, documentIsCurrent)
        var selected: [RhwpNativeFontContext.Request] = []
        var needed: [String: RhwpNativeFontMatcher.Selection] = [:]
        var fallbacks = Set<String>()
        for (slot, choice) in zip(slots, selections) {
            if choice.status == "absent" { fallbacks.insert(slot.family); continue }
            let regular = choice.status == "hftRegular" && hftSources.contains(slot.family) && slot.bold && !slot.italic
            guard choice.status == "selected" || regular, let id = choice.id, let weight = choice.weight,
                  choice.postscriptName != nil, let slant = choice.slant else { throw HwpNativeFontSupplyError.unavailable }
            // PS/full-name의 exact 선택은 원래 요청 스타일을 덮어쓰지 않는다.
            guard weight == (slot.bold && !regular ? 700 : 400), slant == (slot.italic ? "italic" : "normal") else {
                throw HwpNativeFontSupplyError.unsupported
            }
            if let previous = needed[id], previous.weight != weight || previous.slant != slant { throw HwpNativeFontSupplyError.invalid }
            needed[id] = choice
            selected.append(.init(charShapeId: slot.charShapeId, languageIndex: slot.languageIndex,
                family: slot.family, bold: slot.bold, italic: slot.italic, faceId: id, hftRegular: regular))
        }
        guard needed.count <= limits.faces else { throw HwpNativeFontSupplyError.tooLarge }
        var sourceReads = sourceData.count
        sourceData = sourceData.filter { needed[$0.key] != nil }
        var remainingSourceBytes = sourceData.values.reduce(0) { $0 + $1.data.count }
        var faces: [RhwpNativeFontContext.Face] = []
        var total = 0
        for id in needed.keys.sorted() {
            try await validate(snapshot, documentIsCurrent)
            guard let choice = needed[id], let row = snapshot.faces.first(where: { $0.id == id }), row.limitation == nil,
                  snapshot.faces.filter({ $0.id == id }).count == 1,
                  row.postScriptName == choice.postscriptName else { throw HwpNativeFontSupplyError.invalid }
            // read/inspect에 필요한 최악의 file slot을 읽기 전에 예약한다.
            guard total <= limits.residentBytes - limits.fileBytes else { throw HwpNativeFontSupplyError.tooLarge }
            let value: StudioFontBytes
            if let preloaded = sourceData.removeValue(forKey: id) {
                value = preloaded
                remainingSourceBytes -= value.data.count
            } else {
                guard total + remainingSourceBytes <= limits.residentBytes - limits.fileBytes else {
                    throw HwpNativeFontSupplyError.tooLarge
                }
                value = try await read(id, snapshot: snapshot, budget: budget, maximumBytes: limits.fileBytes)
                sourceBytes += value.data.count
                sourceReads += 1
            }
            try await validate(snapshot, documentIsCurrent)
            let face = value.face
            guard face.applicationSupport == .staticCandidate, face.id.sfntIndex == 0, face.axes.isEmpty,
                  face.postScriptName == choice.postscriptName, Int(face.weightClass) == choice.weight else {
                throw HwpNativeFontSupplyError.unsupported
            }
            let slant = face.selectionFlags & 512 != 0 ? "oblique"
                : face.selectionFlags & 1 != 0 || face.italicAngle != 0 ? "italic" : "normal"
            guard slant == choice.slant else { throw HwpNativeFontSupplyError.unsupported }
            total += value.data.count
            guard total <= limits.residentBytes else { throw HwpNativeFontSupplyError.tooLarge }
            faces.append(.init(id: id, postScriptName: face.postScriptName, sha256: digest(value.data),
                               faceIndex: UInt32(face.id.sfntIndex), data: value.data))
        }
        let identityData = try JSONSerialization.data(withJSONObject: [
            "version": 1, "core": RhwpCoreBuildInfo.commit, "matcher": RhwpNativeFontMatcherSource.sha256, "document": documentIdentity, "filename": filename, "page": pageIndex, "snapshot": snapshot.identity,
            "renderer": policy.identifier, "width": maximumPixelSize?.width ?? 0,
            "height": maximumPixelSize?.height ?? 0,
            "faces": faces.map { ["id": $0.id, "sha256": $0.sha256, "postScriptName": $0.postScriptName] },
            "requests": selected.map { ["shape": Int($0.charShapeId), "language": $0.languageIndex,
                "family": $0.family, "bold": $0.bold, "italic": $0.italic, "face": $0.faceId] as [String: Any] },
            "fallback": fallbacks.sorted()
        ], options: [.sortedKeys])
        let identity = digest(identityData)
        let context = faces.isEmpty ? nil : try RhwpNativeFontContext(identity: identity, faces: faces, requests: selected)
        faces.removeAll() // 합친 buffer 이외의 원본 참조를 render 전에 해제한다.
        try await validate(snapshot, documentIsCurrent)
        return .init(programs: programData, context: context, cacheIdentity: identity, snapshotIdentity: snapshot.identity,
            selectedFaces: context?.faces.map(\.postScriptName).sorted() ?? [], fallbackFamilies: fallbacks.sorted(),
            sourceReads: sourceReads, sourceBytes: sourceBytes)
    }

    private static func read(_ id: String, snapshot: StudioFontSupplySnapshot,
                             budget: StudioFontTransferBudget, maximumBytes: Int) async throws -> StudioFontBytes {
        let operation = Task {
            var token: UUID?
            for delay in [UInt64(0), 100_000_000, 250_000_000, 500_000_000] {
                if delay > 0 { try await Task.sleep(nanoseconds: delay) }
                try Task.checkCancellation()
                do { token = try await budget.acquire(); break }
                catch StudioFontError.busy { continue }
            }
            guard let token else { throw StudioFontError.busy }
            do {
                let value = try await snapshot.read(id)
                try Task.checkCancellation()
                guard !value.data.isEmpty, value.data.count <= maximumBytes else { throw HwpNativeFontSupplyError.tooLarge }
                let checked = try await Task.detached(priority: .utility) {
                    try FontFileInspector().inspect(value.data, filename: "native.ttf")
                }.value
                guard checked.faces.count == 1, checked.faces[0] == value.face else { throw HwpNativeFontSupplyError.invalid }
                try Task.checkCancellation()
                await budget.release(token)
                return value
            } catch {
                await budget.release(token)
                throw error
            }
        }
        return try await withTaskCancellationHandler(operation: { try await operation.value }, onCancel: { operation.cancel() })
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
