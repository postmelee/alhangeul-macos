import Foundation
import CoreGraphics
import CoreText
import CryptoKit
import ImageIO
import UniformTypeIdentifiers

// 새 Swift wrapper → C ABI → pinned Skia와 실제 CGTreeRenderer의 격리 수용.
let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let output = root.appendingPathComponent("build.noindex/task568/stage4/swift-integration")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
struct Metadata: Decodable {
    struct Entry: Decodable { let id: String; let postScriptName: String; let sha256: String; let faceIndex: UInt32 }
    let identity: String
    let faces: [Entry]
    let requests: [RhwpNativeFontContext.Request]
}
func supply(_ path: String) throws -> RhwpNativeFontContext {
    let metadata = try JSONDecoder().decode(Metadata.self, from: Data(contentsOf: root.appendingPathComponent(path)))
    let faces = try metadata.faces.map { entry in
        let data = try Data(contentsOf: root.appendingPathComponent("build.noindex/task567/fonts/gowun-batang/\(entry.postScriptName).ttf"))
        return RhwpNativeFontContext.Face(id: entry.id, postScriptName: entry.postScriptName,
            sha256: entry.sha256, faceIndex: entry.faceIndex, data: data)
    }
    return try .init(identity: metadata.identity, faces: faces, requests: metadata.requests)
}
func bitmap(_ document: RhwpDocument, tree: RenderNode, renderer: CGTreeRenderer,
            supply: RhwpCoreTextFontContext?) throws -> Data {
    let size = document.pageSize(at: 0)
    let width = Int(ceil(size.width)), height = Int(ceil(size.height))
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.translateBy(x: 0, y: CGFloat(height)); context.scaleBy(x: 1, y: -1)
    if let supply { try renderer.render(tree: tree, in: context, pageHeight: size.height, document: document, fontContext: supply) }
    else { renderer.render(tree: tree, in: context, pageHeight: size.height, document: document) }
    let data = NSMutableData()
    let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    precondition(CGImageDestinationFinalize(destination))
    return data as Data
}
func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format:"%02x",$0) }.joined() }
var records: [[String: Any]] = []
let regular = try supply("build.noindex/task568/stage4/ffi-regular/regular-metadata.json")
// 메타데이터 view가 실제로 전송 buffer를 공유하는지 검사한다(큰 font의 이중 보관 방지).
regular.bytes.withUnsafeBytes { buffer in
    regular.faces[0].data.withUnsafeBytes { face in
        precondition(buffer.baseAddress == face.baseAddress)
    }
}
let control = try RhwpDocument(data: Data(contentsOf: root.appendingPathComponent("build.noindex/task568/stage4/regular-control.hwpx")), filename: "regular-control.hwpx")
let png = control.renderPagePNG(at: 0, maxDimension: 2048, fontContext: regular)
precondition(png.status == .ok && png.fontDiagnostic?.provenRuns == png.fontDiagnostic?.targetRuns && !png.data.isEmpty)
try png.data.write(to: output.appendingPathComponent("skia-regular.png"))
precondition(control.renderPagePNG(at: Int.max, fontContext: regular).status == .invalidPageIndex)
let originalFace = regular.faces[0]
var changedBytes = originalFace.data; changedBytes.append(contentsOf: [0, 0, 0, 0])
let changed = try RhwpNativeFontContext(identity: "changed-bytes", faces: [.init(id: originalFace.id,
    postScriptName: originalFace.postScriptName, sha256: hash(changedBytes), faceIndex: 0, data: changedBytes)], requests: regular.requests)
let changedPNG = control.renderPagePNG(at: 0, fontContext: changed)
precondition(changedPNG.status == .ok && changedPNG.fontDiagnostic?.faces?.first?.sha256 == hash(changedBytes))
precondition(control.renderPagePNG(at: 0, fontContext: regular).fontDiagnostic?.faces?.first?.sha256 == originalFace.sha256)
let missing = try RhwpDocument(data: Data(contentsOf: root.appendingPathComponent("build.noindex/task568/stage4/missing-glyph.hwpx")), filename: "missing-glyph.hwpx")
let missingContext = try supply("build.noindex/task568/stage4/ffi-missing/regular-metadata.json")
let missingPNG = missing.renderPagePNG(at: 0, fontContext: missingContext)
precondition(missingPNG.status == .unsupportedFontContext && missingPNG.data.isEmpty)
// invalid/missing face가 공통 경로의 기본 글꼴로 조용히 바뀌면 안 된다.
do { _ = try HwpPageImageRenderer.renderPage(document: missing, pageIndex: 0, policy: .skiaOptIn, fontContext: missingContext); preconditionFailure("missing glyph silently replaced") }
catch { precondition(error as? RhwpCoreTextFontContext.Failure == .missingGlyph) }
for fileExtension in ["hwpx", "hwp"] {
    let context = try supply("build.noindex/task568/stage4/ffi-\(fileExtension)/both-metadata.json")
    let document = try RhwpDocument(data: Data(contentsOf: root.appendingPathComponent("build.noindex/task568/stage3/fixtures/gowun-document.\(fileExtension)")), filename: "probe.\(fileExtension)")
    let tree = try document.renderPageTreeThrowing(at: 0)
    let original = document.renderPageTreeJSON(at: 0)
    let fonts = try RhwpCoreTextFontContext(context)
    let names = try fonts.validate(tree)
    precondition(names == ["GowunBatang-Bold", "GowunBatang-Regular"])
    let renderer = CGTreeRenderer()
    let image = try bitmap(document, tree: tree, renderer: renderer, supply: fonts)
    try image.write(to: output.appendingPathComponent("cg-\(fileExtension).png"))
    let restored = try bitmap(document, tree: tree, renderer: renderer, supply: nil)
    let clean = try bitmap(document, tree: tree, renderer: CGTreeRenderer(), supply: nil)
    precondition(restored == clean, "작업 context가 다음 렌더에 남으면 안 됩니다")
    let skia = document.renderPagePNG(at: 0, maxDimension: 2048, fontContext: context)
    precondition(skia.status == .ok && !skia.data.isEmpty
        && skia.fontDiagnostic?.targetRuns == skia.fontDiagnostic?.provenRuns)
    try skia.data.write(to: output.appendingPathComponent("skia-\(fileExtension).png"))
    let composed = try HwpPageImageRenderer.renderPage(document: document, pageIndex: 0,
        maximumPixelSize: CGSize(width: 1024, height: 1024), policy: .skiaOptIn, fontContext: context)
    precondition(composed.diagnostics.backendUsed == .skia
        && composed.diagnostics.fallbackReason == nil
        && composed.diagnostics.fontIdentity == context.identity
        && composed.diagnostics.fontFaces.sorted() == names)
    try HwpPageImageRenderer.encodePNG(composed.image).write(to: output.appendingPathComponent("composed-\(fileExtension).png"))
    precondition(document.renderPageTreeJSON(at: 0) == original)
    records.append(["format": fileExtension, "coreGraphicsPS": names, "imageSHA256": hash(image),
        "contextRestored": true, "documentUnchanged": true, "skiaStatus": "ok",
        "sharedRenderer": "same exact faces in Skia",
        "skiaReason": skia.fontDiagnostic?.reason ?? "missing", "provenRuns": skia.fontDiagnostic?.provenRuns ?? -1,
        "targetRuns": skia.fontDiagnostic?.targetRuns ?? -1])
}
// 바이트/PS 불일치가 이름 조회 fallback으로 성공하지 않는지 검사한다.
for wrongPS in [false, true] {
    let original = regular.faces[0]
    let invalid = RhwpNativeFontContext.Face(id: original.id, postScriptName: wrongPS ? "wrong" : original.postScriptName,
        sha256: wrongPS ? original.sha256 : String(repeating: "0", count: 64), faceIndex: 0, data: original.data)
    let context = try RhwpNativeFontContext(identity: "invalid", faces: [invalid], requests: regular.requests)
    do { _ = try RhwpCoreTextFontContext(context); preconditionFailure("invalid bytes/PS accepted") }
    catch { precondition(error as? RhwpCoreTextFontContext.Failure == .invalidFace) }
    precondition(control.renderPagePNG(at: 0, fontContext: context).status == .invalidFontContext)
}
let summary: [String: Any] = ["passed": true, "kind": "isolated native adapter acceptance; live service/Finder unconnected",
    "regularSkiaRuns": png.fontDiagnostic?.provenRuns ?? -1, "regularSkiaPNGBytes": png.data.count,
    "invalidHashAndPSRejected": true, "widePageIndexRejected": true, "userFontOSRegistration": false,
    "sharedTransportBuffer": true, "samePSChangedBytesAndOriginalReused": true, "missingGlyphRejectedWithoutPNG": true,
    "bundledProcessRegisteredCount": HwpBundledFontRegistry.registrationStatus().registeredCount,
    "records": records]
try JSONSerialization.data(withJSONObject: summary, options: [.prettyPrinted, .sortedKeys])
    .write(to: output.appendingPathComponent("result.json"))
print("native integration probe passed")
