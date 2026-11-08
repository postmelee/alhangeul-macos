import Foundation
import CryptoKit

@main
struct NativeDocumentProbe {
    static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    @MainActor static func main() async throws {
        let args = CommandLine.arguments
        let output = URL(fileURLWithPath: args[2])
        let document = URL(fileURLWithPath: args[3])
        let font = URL(fileURLWithPath: args[4])
        let data = try Data(contentsOf: document)
        let fontData = try Data(contentsOf: font)
        let face = try FontFileInspector().inspect(fontData, filename: font.lastPathComponent).faces.first
        guard let expectedPS = face?.postScriptName else { throw CocoaError(.fileReadCorruptFile) }
        let slots = try RhwpDocument(data: data, filename: document.lastPathComponent).nativeFontRequests(at: 0)
        let requests = slots.enumerated().map { index, slot in
            RhwpNativeFontMatcher.Request(key: String(index), family: slot.family,
                                          weight: slot.bold ? 700 : 400, slant: slot.italic ? "italic" : "normal")
        }
        let catalog = try InstalledFontCatalogService(persistence: .file(at: output.appendingPathComponent("catalog")),
                                                      observeChanges: false)
        _ = try await catalog.prepare()
        _ = try await catalog.setEnabled(false)
        let library = FontLibraryService(store: .init(rootURL: output.appendingPathComponent("library")))
        let supply = StudioFontSupply.using(installed: .init(factory: { catalog }), library: { library })
        var rows = [[String: Any]]()
        var failed = false
        for managed in [false, true] {
            if managed {
                let result = await library.importFonts(.init(candidates: [.init(sourceURL: font)], accessURLs: []))
                guard result.first?.status == .added else { throw CocoaError(.fileReadCorruptFile) }
            }
            let snapshot = try await supply.snapshot()
            let choices: [RhwpNativeFontMatcher.Selection]
            do { choices = try RhwpNativeFontMatcher.resolve(snapshot: snapshot, requests: requests) }
            catch { await snapshot.release(); throw error }
            await snapshot.release()
            let decisions = zip(requests, choices).map { request, choice -> [String: Any] in
                ["family": request.family, "weight": request.weight, "slant": request.slant,
                 "status": choice.status, "postScriptName": choice.postscriptName ?? ""]
            }
            for policy in [HwpPageRenderPolicy.coreGraphicsOnly, .skiaOptIn] {
                var row: [String: Any] = ["managed": managed, "policy": policy.identifier, "beforeEnvironmentDecisions": decisions]
                do {
                    let result = try await HwpNativeFontPageRenderer.render(data: data, filename: document.lastPathComponent,
                        snapshot: try await supply.snapshot(), policy: policy)
                    let png = try HwpPageImageRenderer.encodePNG(result.page.image)
                    try png.write(to: output.appendingPathComponent("\(managed)-\(policy.identifier).png"))
                    row["selected"] = result.selectedFaces
                    row["fallbacks"] = result.fallbackFamilies
                    row["bytes"] = result.sourceBytes
                    row["reads"] = result.sourceReads
                    let rendered = result.page.diagnostics
                    row["rendererFaces"] = rendered.fontFaces
                    row["fallbackReason"] = rendered.fallbackReason.map { String(describing: $0) } ?? ""
                    if managed && (result.sourceReads != 1 || result.sourceBytes != fontData.count ||
                        !rendered.fontFaces.contains(expectedPS) || !result.selectedFaces.contains(expectedPS) ||
                        (policy.identifier == "skiaOptIn" && rendered.backendUsed != .skia)) {
                        row["error"] = "managedSourceNotConsumed"
                        failed = true
                    }
                    row["pngSHA256"] = digest(png)
                    row["backend"] = String(describing: result.page.diagnostics.backendUsed)
                } catch {
                    row["error"] = String(describing: error)
                    failed = true
                }
                rows.append(row)
            }
        }
        let report: [String: Any] = ["documentSHA256": digest(data), "fontSHA256": digest(fontData),
                                     "pageIndex": 0, "renders": rows]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("result.json"))
        if failed { exit(1) }
    }
}
