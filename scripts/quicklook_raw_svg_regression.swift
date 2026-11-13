import CoreGraphics
import Foundation
import Darwin
import ImageIO

private struct Failure: Error { let message: String }

@main
struct RawSvgRegression {
    static func check(_ value: @autoclosure () -> Bool, _ message: String) throws {
        guard value() else { throw Failure(message: message) }
    }

    static func node(_ svg: String, width: Double = 300, children: [RenderNode] = []) -> RenderNode {
        RenderNode(id: 1, nodeType: .rawSvg(RawSvgNode(svg: svg)),
            bbox: BBox(x: 113, y: 139, width: width, height: 200), children: children, visible: true)
    }

    static func policyChecks() throws {
        let valid = "<g><rect x=\"113\" y=\"139\" width=\"200\" height=\"100\" fill=\"#009966\"/><text x=\"120\" y=\"160\">남성</text></g>"
        try check(HwpQuickLookRawSvgPolicy.select(tree: node(valid)) == .vector, "vector")
        let empty = RenderNode(id: 0, nodeType: .masterPage,
            bbox: BBox(x: 0, y: 0, width: 794, height: 1123), children: [], visible: true)
        try check(HwpQuickLookRawSvgPolicy.select(tree: empty) == .noVector, "normal page")
        let nested = RenderNode(id: 0, nodeType: .masterPage, bbox: empty.bbox,
            children: [empty, node(valid)], visible: true)
        try check(HwpQuickLookRawSvgPolicy.select(tree: nested) == .vector, "nested vector")
        try check(HwpQuickLookRawSvgPolicy.select(tree: nil) == .treeUnavailable, "decode failure")
        let rejected = [
            "<g><rect></g>", "<g/>", "<script>alert(1)</script>",
            "<image href=\"file:///tmp/private.png\"/>",
            "<image href=\"https://example.invalid/a.png\"/>",
            "<image href=\"data:image/png;base64,AAAA\"/>",
            "<rect width=\"10\" height=\"10\" fill=\"url(#x)\"/>",
            "<rect style=\"fill:red\"/>", "<rect onload=\"x\"/>",
            "<!DOCTYPE svg [<!ENTITY e SYSTEM 'file:///tmp/a'>]><text>&e;</text>",
            "<?xml-stylesheet href='https://example.invalid/a.css'?><rect/>",
            String(repeating: "<g>", count: 65) + "<rect/>" + String(repeating: "</g>", count: 65),
            String(repeating: "<rect/>", count: 16_385),
            "<text>" + String(repeating: "x", count: 4 * 1024 * 1024) + "</text>"
        ]
        for (index, svg) in rejected.enumerated() {
            try check(HwpQuickLookRawSvgPolicy.select(tree: node(svg)) == .rejected, "rejected input \(index)")
        }
        for width in [Double.nan, Double.infinity, -1, 0, 8193] {
            try check(HwpQuickLookRawSvgPolicy.select(tree: node(valid, width: width)) == .rejected, "bbox")
        }
        try check(HwpQuickLookRawSvgPolicy.select(tree: node(valid, children: [node(rejected[0])])) == .rejected, "mixed page")
        try check(HwpQuickLookRawSvgPolicy.select(tree: node(valid, children: Array(repeating: node(valid), count: 32))) == .rejected, "fragment budget")
        try check(HwpQuickLookPNGReplyModeResolver.resolve(environment: [:]) == .automatic, "release default")
        print("PASS policy: normal/nested/mixed/malformed/external/entity/size/depth/count/bbox")
    }

    static func greenPixels(_ image: CGImage) throws -> Int {
        let w = image.width, h = image.height
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        guard let context = CGContext(data: &bytes, width: w, height: h, bitsPerComponent: 8,
            bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw Failure(message: "bitmap") }
        context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return stride(from: 0, to: bytes.count, by: 4).filter {
            let r = Int(bytes[$0]), g = Int(bytes[$0 + 1]), b = Int(bytes[$0 + 2])
            return g > 90 && g > r + 35 && g > b + 15
        }.count
    }

    static func main() async {
        setbuf(stdout, nil)
        do { try await run() }
        catch { fputs("FAIL: \(error)\n", stderr); exit(1) }
    }

    static func run() async throws {
        try policyChecks()
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let output = URL(fileURLWithPath: CommandLine.arguments[2])
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let chart = try HwpPreviewPDFRenderer.load(fileURL: root.appendingPathComponent("samples/issue7406/7406_OLE__CHART.hwp"))
        try check(chart.pageCount == 1, "chart pages")
        let before = try HwpPageImageRenderer.renderPage(document: chart.document, pageIndex: 0)
        let after = try HwpPageImageRenderer.renderPage(document: chart.document, pageIndex: 0, policy: .quickLookAutomatic)
        try check(before.diagnostics.backendUsed == .coreGraphics, "before backend")
        try check(after.diagnostics.backendUsed == .skia && after.diagnostics.rawSvgSelection == "vector", "chart selection")
        let beforeGreen = try greenPixels(before.image), afterGreen = try greenPixels(after.image)
        try check(beforeGreen == 0 && afterGreen > 5000, "chart bars must render")
        try HwpPageImageRenderer.encodePNG(before.image).write(to: output.appendingPathComponent("before.png"))
        try HwpPageImageRenderer.encodePNG(after.image).write(to: output.appendingPathComponent("after.png"))
        let reply = try HwpPreviewPNGRenderer.render(context: chart, mode: .automatic)
        try check(reply.diagnostics.outputMode == .skiaDecode && reply.diagnostics.rawSvgSelection == "vector", "PNG actual backend")
        try reply.data.write(to: output.appendingPathComponent("preview.png"))
        let fallback = try HwpPreviewPNGRenderer.render(context: chart, mode: .automatic, forceDefaultFonts: true)
        try check(fallback.diagnostics.backendUsed == .coreGraphics && fallback.diagnostics.rawSvgSelection == "fontFallback", "font denial preserved")
        let pdf = try HwpPreviewPDFRenderer.render(document: chart.document, pageCount: chart.pageCount,
            contentSize: chart.contentSize, policy: .quickLookAutomatic, collectDiagnostics: true)
        try check(pdf.pageDiagnostics.allSatisfy { $0.diagnostics.backendUsed == .skia }, "PDF selection")
        try pdf.data.write(to: output.appendingPathComponent("preview.pdf"))
        let normal = try HwpPreviewPDFRenderer.load(fileURL: root.appendingPathComponent("samples/basic/KTX.hwp"))
        let normalReply = try HwpPreviewPNGRenderer.render(context: normal, mode: .automatic)
        try check(normalReply.diagnostics.backendUsed == .coreGraphics && normalReply.diagnostics.rawSvgSelection == "noVector", "normal unchanged")
        let forced = try HwpPreviewPNGRenderer.render(context: chart, mode: .coreGraphics)
        try check(forced.diagnostics.backendUsed == .coreGraphics, "explicit CG preserved")
        let supply: ExtensionFontRenderer.Supply = {
            StudioFontSupplySnapshot(identity: "task612-empty", faces: [], omitted: 0, failure: nil,
                read: { _ in throw StudioFontError.unavailable }, current: { true }, release: {})
        }
        let livePath = try await ExtensionFontRenderer.png(context: chart, mode: .automatic, supply: supply)
        try check(livePath.diagnostics.backendUsed == .skia, "extension supply path")
        let denied = try await ExtensionFontRenderer.png(context: chart, mode: .automatic,
            supply: { throw StudioFontError.unauthorized })
        try check(denied.diagnostics.backendUsed == .coreGraphics && denied.diagnostics.fontSupplyFailure != nil,
            "extension denied supply")
        do {
            _ = try await ExtensionFontRenderer.png(context: chart, mode: .automatic, supply: supply, current: { false })
            throw Failure(message: "stale request was published")
        } catch let error as HwpNativeFontSupplyError {
            try check(error == .stale, "stale propagation")
        }
        let multi = try HwpPreviewPDFRenderer.load(fileURL: root.appendingPathComponent("samples/hwp-multi-001.hwp"))
        try check(multi.pageCount > 1, "multiple pages fixture")
        let multiPDF = try await ExtensionFontRenderer.pdf(context: multi, supply: supply)
        try check(multiPDF.pageCount == multi.pageCount && multiPDF.pageDiagnostics.count == multi.pageCount, "all PDF pages")
        for page in multiPDF.pageDiagnostics {
            let selected = HwpQuickLookRawSvgPolicy.select(tree: multi.document.renderPageTree(at: page.pageIndex))
            let expected = page.diagnostics.fontSupplyFailure == nil ? selected.rawValue : "fontFallback"
            try check(page.diagnostics.rawSvgSelection == expected, "per-page PDF policy")
        }
        let multiDirect = try HwpPreviewPDFRenderer.render(document: multi.document, pageCount: multi.pageCount,
            contentSize: multi.contentSize, policy: .quickLookAutomatic, collectDiagnostics: true)
        for page in multiDirect.pageDiagnostics {
            try check(page.diagnostics.rawSvgSelection == HwpQuickLookRawSvgPolicy.select(
                tree: multi.document.renderPageTree(at: page.pageIndex)).rawValue, "multi-page direct selection")
        }
        let extensionPDF = try await ExtensionFontRenderer.pdf(context: chart, supply: supply)
        try check(extensionPDF.pageDiagnostics.first?.diagnostics.backendUsed == .skia, "extension PDF vector")
        print("PASS extension: supply/denial/stale and PDF per-page selection (\(multi.pageCount) pages)")
        print("PASS integration: chart PNG/PDF, normal CG, font failure CG, explicit CG; green pixels \(beforeGreen) -> \(afterGreen)")
        print("chart totalMs=\(after.diagnostics.durationMs.totalMs), pngBytes=\(reply.data.count)")
    }
}
