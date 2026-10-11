import Foundation
import CoreGraphics
import CoreText
import CryptoKit

struct RhwpNativePageFontRequest: Decodable, Hashable {
    let charShapeId: UInt32
    let languageIndex: Int
    let family: String
    let bold: Bool
    let italic: Bool
}

/// 호출 동안만 전달하는 글꼴 원본과 명시적인 문서 slot 선택. 경로/권한/OS 등록을 보관하지 않는다.
struct RhwpNativeFontContext: Sendable {
    struct Face: Sendable {
        let id: String
        let postScriptName: String
        let sha256: String
        let faceIndex: UInt32
        let data: Data
    }

    struct Request: Codable, Hashable, Sendable {
        let charShapeId: UInt32
        let languageIndex: Int
        let family: String
        let bold: Bool
        let italic: Bool
        let faceId: String
    }

    enum Failure: Error { case invalid, tooLarge }

    let identity: String
    let faces: [Face]
    let requests: [Request]
    let metadata: Data
    let bytes: Data

    private struct Metadata: Encodable {
        let version = 1
        let identity: String
        let faces: [Entry]
        let requests: [Request]
    }
    private struct Entry: Encodable {
        let id: String
        let postScriptName: String
        let sha256: String
        let faceIndex: UInt32
        let offset: Int
        let length: Int
    }
    private struct Slot: Hashable { let shape: UInt32; let language: Int }

    init(identity: String, faces: [Face], requests: [Request]) throws {
        let valid: (String) -> Bool = { !$0.isEmpty && $0.utf8.count <= 1024
            && !$0.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) }
        guard valid(identity), !faces.isEmpty, !requests.isEmpty else { throw Failure.invalid }
        guard faces.count <= 64, requests.count <= 2048 else { throw Failure.tooLarge }
        var byID: [String:Face] = [:]
        var entries: [Entry] = []
        var total = 0
        for face in faces {
            guard valid(face.id), valid(face.postScriptName), byID[face.id] == nil, !face.data.isEmpty,
                  face.sha256.utf8.count == 64,
                  face.sha256.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else { throw Failure.invalid }
            guard face.data.count <= 64 * 1024 * 1024, total <= 128 * 1024 * 1024 - face.data.count else { throw Failure.tooLarge }
            entries.append(.init(id: face.id, postScriptName: face.postScriptName, sha256: face.sha256,
                                 faceIndex: face.faceIndex, offset: total, length: face.data.count))
            total += face.data.count; byID[face.id] = face
        }
        var slots = Set<Slot>(); var used = Set<String>(); var mappedBytes = 0
        for request in requests {
            guard (0...6).contains(request.languageIndex), valid(request.family),
                  let face = byID[request.faceId],
                  slots.insert(.init(shape: request.charShapeId, language: request.languageIndex)).inserted else { throw Failure.invalid }
            guard mappedBytes <= 128 * 1024 * 1024 - face.data.count else { throw Failure.tooLarge }
            mappedBytes += face.data.count; used.insert(face.id)
        }
        guard used.count == faces.count else { throw Failure.invalid }
        let metadata = try JSONEncoder().encode(Metadata(identity: identity, faces: entries, requests: requests))
        guard metadata.count <= 1024 * 1024 else { throw Failure.tooLarge }
        var bytes = Data(capacity: total)
        for face in faces { bytes.append(face.data) }
        // 전송 buffer의 slice를 사용해 context 자체가 원본과 합친 bytes를 이중 보관하지 않는다.
        self.identity = identity
        self.faces = zip(faces, entries).map { face, entry in
            Face(id: face.id, postScriptName: face.postScriptName, sha256: face.sha256,
                 faceIndex: face.faceIndex, data: bytes[entry.offset..<(entry.offset + entry.length)])
        }
        self.requests = requests
        self.metadata = metadata; self.bytes = bytes
    }
}

struct RhwpNativeFontDiagnostic: Decodable {
    struct Face: Decodable { let postScriptName: String; let sha256: String; let faceIndex: UInt32 }
    let version: Int
    let identity: String?
    let reason: String
    let targetRuns: Int?
    let provenRuns: Int?
    let emittedRuns: Int?
    let proofFailures: [String]?
    let faces: [Face]?
}

/// CoreGraphics의 제한된 작업별 face 공급. 동일 charShape/family/style의 모든 언어 mapping이
/// 같은 face일 때만 사용한다. 언어마다 다른 face를 쓰는 run은 추가 분해 없이 거부한다.
final class RhwpCoreTextFontContext {
    enum Failure: Error, Equatable { case invalidFace, ambiguousLanguageFaces, missingGlyph, requestMismatch }
    private struct Key: Hashable {
        let shape: UInt32
        let family: String
        let bold: Bool
        let italic: Bool
    }
    let identity: String
    private let fonts: [Key: CTFont]

    init(_ context: RhwpNativeFontContext) throws {
        var faces: [String: CTFont] = [:]
        for face in context.faces {
            let hash = SHA256.hash(data: face.data).map { String(format: "%02x", $0) }.joined()
            guard hash == face.sha256, face.faceIndex == 0, face.data.prefix(4) != Data("ttcf".utf8),
                  let provider = CGDataProvider(data: face.data as CFData), let graphic = CGFont(provider) else { throw Failure.invalidFace }
            let font = CTFontCreateWithGraphicsFont(graphic, 1, nil, nil)
            guard CTFontCopyPostScriptName(font) as String == face.postScriptName,
                  (CTFontCopyVariationAxes(font) as? [Any] ?? []).isEmpty else { throw Failure.invalidFace }
            faces[face.id] = font
        }
        var fontIDs: [Key: String] = [:]
        var fonts: [Key: CTFont] = [:]
        for request in context.requests {
            let key = Key(shape: request.charShapeId, family: request.family, bold: request.bold, italic: request.italic)
            if let previous = fontIDs[key], previous != request.faceId { throw Failure.ambiguousLanguageFaces }
            guard let font = faces[request.faceId] else { throw Failure.invalidFace }
            let traits = CTFontGetSymbolicTraits(font)
            guard traits.contains(.traitBold) == request.bold, traits.contains(.traitItalic) == request.italic else { throw Failure.invalidFace }
            fontIDs[key] = request.faceId; fonts[key] = font
        }
        self.identity = context.identity; self.fonts = fonts
    }

    func font(for run: TextRunNode, size: CGFloat) -> CTFont? {
        guard let shape = run.charShapeId,
              let font = fonts[Key(shape: shape, family: run.style.fontFamily, bold: run.style.bold, italic: run.style.italic)] else { return nil }
        return CTFontCreateCopyWithAttributes(font, size, nil, nil)
    }

    /// 지정된 run 모두의 기본 glyph coverage를 확인한다. 복잡 shaping/언어별 face 분해를
    /// 새로 구현하지 않으며 이것을 전체 layout parity 증거로 사용하지 않는다.
    func validate(_ tree: RenderNode) throws -> [String] {
        var used = Set<Key>(); var names = Set<String>()
        func visit(_ node: RenderNode) throws {
            guard node.visible else { return }
            if case .textRun(let run) = node.nodeType, let shape = run.charShapeId {
                let key = Key(shape: shape, family: run.style.fontFamily, bold: run.style.bold, italic: run.style.italic)
                if let font = fonts[key], !run.text.isEmpty {
                    let characters = Array(run.text.utf16)
                    var glyphs = [CGGlyph](repeating: 0, count: characters.count)
                    guard CTFontGetGlyphsForCharacters(font, characters, &glyphs, characters.count),
                          glyphs.allSatisfy({ $0 != 0 }) else { throw Failure.missingGlyph }
                    used.insert(key); names.insert(CTFontCopyPostScriptName(font) as String)
                }
            }
            for child in node.children { try visit(child) }
        }
        try visit(tree)
        guard used == Set(fonts.keys) else { throw Failure.requestMismatch }
        return names.sorted()
    }
}
