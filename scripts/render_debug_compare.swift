import CoreGraphics
import CoreText
import Darwin
import Foundation
import ImageIO

struct RenderDebugError: Error, CustomStringConvertible {
    let description: String
}

struct RenderDebugTextStats {
    var textRunCount = 0
    var hangulRunCount = 0
    var hangulScalarCount = 0
    var missingGlyphCount = 0
}

struct NativeRenderResult {
    let outputURL: URL
    let pixelWidth: Int
    let pixelHeight: Int
    let nonWhitePixels: Int
}

@main
struct RenderDebugCompare {
    @MainActor
    static func main() throws {
        var args = Array(CommandLine.arguments.dropFirst())
        guard args.count >= 2 else {
            throw RenderDebugError(description: "usage: render_debug_compare <output-dir> [--page N] <hwp-or-hwpx> [...]")
        }

        let outputDir = absoluteURL(args.removeFirst(), isDirectory: true)
        var pageNumber = 1

        while let first = args.first, first.hasPrefix("--") {
            switch first {
            case "--page":
                args.removeFirst()
                guard let value = args.first, let parsed = Int(value), parsed > 0 else {
                    throw RenderDebugError(description: "--page requires a positive integer")
                }
                pageNumber = parsed
                args.removeFirst()
            case "--help", "-h":
                print("usage: render_debug_compare <output-dir> [--page N] <hwp-or-hwpx> [...]")
                return
            default:
                throw RenderDebugError(description: "unknown option: \(first)")
            }
        }

        guard !args.isEmpty else {
            throw RenderDebugError(description: "missing input document")
        }

        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        var failed = false
        for input in args {
            do {
                let summary = try export(inputPath: input, outputDir: outputDir, pageNumber: pageNumber)
                print(summary)
            } catch {
                failed = true
                print("FAIL \(input): \(error)", to: &standardError)
            }
        }

        if failed {
            print("FAIL: one or more render debug exports failed", to: &standardError)
            exit(1)
        }
    }

    @MainActor
    private static func export(inputPath: String, outputDir: URL, pageNumber: Int) throws -> String {
        let inputURL = absoluteURL(inputPath)
        let data = try Data(contentsOf: inputURL)
        let doc = try RhwpDocument(data: data, filename: inputURL.lastPathComponent)
        guard doc.pageCount > 0 else {
            throw RenderDebugError(description: "page count is zero")
        }

        let pageIndex = pageNumber - 1
        guard pageIndex >= 0, pageIndex < doc.pageCount else {
            throw RenderDebugError(description: "page \(pageNumber) is out of range: pageCount=\(doc.pageCount)")
        }

        let baseName = inputURL.deletingPathExtension().lastPathComponent
        let outputBase = "\(baseName)-page\(pageNumber)"
        let renderTreeURL = outputDir.appendingPathComponent("\(outputBase)-render-tree.json")
        let coreSVGURL = outputDir.appendingPathComponent("\(outputBase)-core.svg")
        let nativePNGURL = outputDir.appendingPathComponent("\(outputBase)-native.png")
        let summaryURL = outputDir.appendingPathComponent("\(outputBase)-summary.txt")

        guard let renderTreeJSON = doc.renderPageTreeJSON(at: pageIndex) else {
            throw RenderDebugError(description: "render tree JSON is nil")
        }
        try renderTreeJSON.write(to: renderTreeURL, atomically: true, encoding: .utf8)

        guard let treeData = renderTreeJSON.data(using: .utf8) else {
            throw RenderDebugError(description: "render tree JSON is not UTF-8")
        }
        let tree = try JSONDecoder().decode(RenderNode.self, from: treeData)

        guard let coreSVG = doc.renderPageSVG(at: pageIndex) else {
            throw RenderDebugError(description: "core SVG is nil")
        }
        try coreSVG.write(to: coreSVGURL, atomically: true, encoding: .utf8)

        var stats = RenderDebugTextStats()
        collectTextStats(tree, into: &stats)

        let pageSize = doc.pageSize(at: pageIndex)
        guard pageSize.width > 0, pageSize.height > 0 else {
            throw RenderDebugError(description: "invalid page size \(pageSize.width)x\(pageSize.height)")
        }

        let nativeResult = try renderNativePNG(
            tree: tree,
            pageSize: pageSize,
            document: doc,
            outputURL: nativePNGURL
        )

        let summaryText = summary(
            inputURL: inputURL,
            pageNumber: pageNumber,
            pageIndex: pageIndex,
            pageCount: doc.pageCount,
            pageSize: pageSize,
            renderTreeURL: renderTreeURL,
            renderTreeBytes: renderTreeJSON.utf8.count,
            coreSVGURL: coreSVGURL,
            coreSVGBytes: coreSVG.utf8.count,
            nativeResult: nativeResult,
            stats: stats
        )
        try summaryText.write(to: summaryURL, atomically: true, encoding: .utf8)

        return "OK \(inputURL.lastPathComponent): page=\(pageNumber) renderTreeJSON=\(renderTreeURL.path) coreSVG=\(coreSVGURL.path) nativePNG=\(nativePNGURL.path) summary=\(summaryURL.path)"
    }

    @MainActor
    private static func renderNativePNG(
        tree: RenderNode,
        pageSize: (width: Double, height: Double),
        document: RhwpDocument,
        outputURL: URL
    ) throws -> NativeRenderResult {
        let scale = 1.0
        let pixelWidth = max(1, Int(ceil(pageSize.width * scale)))
        let pixelHeight = max(1, Int(ceil(pageSize.height * scale)))
        let bytesPerPixel = 4
        let bytesPerRow = pixelWidth * bytesPerPixel
        var pixels = [UInt8](repeating: 255, count: pixelHeight * bytesPerRow)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(
            data: &pixels,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw RenderDebugError(description: "failed to create bitmap context")
        }

        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        ctx.translateBy(x: 0, y: CGFloat(pixelHeight))
        ctx.scaleBy(x: CGFloat(scale), y: -CGFloat(scale))

        let renderer = CGTreeRenderer()
        renderer.render(tree: tree, in: ctx, pageHeight: pageSize.height, document: document)

        guard let image = ctx.makeImage() else {
            throw RenderDebugError(description: "failed to create CGImage")
        }
        try writePNG(image: image, to: outputURL)

        let nonWhitePixels = countNonWhitePixels(
            pixels,
            bytesPerRow: bytesPerRow,
            width: pixelWidth,
            height: pixelHeight
        )
        return NativeRenderResult(
            outputURL: outputURL,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            nonWhitePixels: nonWhitePixels
        )
    }

    private static func summary(
        inputURL: URL,
        pageNumber: Int,
        pageIndex: Int,
        pageCount: Int,
        pageSize: (width: Double, height: Double),
        renderTreeURL: URL,
        renderTreeBytes: Int,
        coreSVGURL: URL,
        coreSVGBytes: Int,
        nativeResult: NativeRenderResult,
        stats: RenderDebugTextStats
    ) -> String {
        """
        Input: \(inputURL.path)
        Page: \(pageNumber)
        PageIndex: \(pageIndex)
        PageCount: \(pageCount)
        PageSizePt: \(pageSize.width)x\(pageSize.height)

        RenderTreeJSON: \(renderTreeURL.path)
        RenderTreeJSONBytes: \(renderTreeBytes)

        CoreSVG: \(coreSVGURL.path)
        CoreSVGBytes: \(coreSVGBytes)

        NativePNG: \(nativeResult.outputURL.path)
        NativePNGSize: \(nativeResult.pixelWidth)x\(nativeResult.pixelHeight)
        NativeNonWhitePixels: \(nativeResult.nonWhitePixels)

        TextRuns: \(stats.textRunCount)
        HangulRuns: \(stats.hangulRunCount)
        HangulScalars: \(stats.hangulScalarCount)
        MissingHangulGlyphs: \(stats.missingGlyphCount)

        Diff: not generated in Stage 2
        """
    }

    private static func collectTextStats(_ node: RenderNode, into stats: inout RenderDebugTextStats) {
        if case .textRun(let run) = node.nodeType {
            stats.textRunCount += 1
            if containsHangul(run.text) {
                stats.hangulRunCount += 1
                stats.hangulScalarCount += hangulScalarCount(run.text)
                stats.missingGlyphCount += missingHangulGlyphCount(in: run)
            }
        }

        for child in node.children {
            collectTextStats(child, into: &stats)
        }
    }

    private static func containsHangul(_ text: String) -> Bool {
        hangulScalarCount(text) > 0
    }

    private static func hangulScalarCount(_ text: String) -> Int {
        text.unicodeScalars.filter { scalar in
            (0xAC00...0xD7AF).contains(Int(scalar.value)) ||
            (0x1100...0x11FF).contains(Int(scalar.value)) ||
            (0x3130...0x318F).contains(Int(scalar.value))
        }.count
    }

    private static func missingHangulGlyphCount(in run: TextRunNode) -> Int {
        let fontName = mapHWPFontToApple(run.style.fontFamily)
        let baseFont = CTFontCreateWithName(fontName as CFString, CGFloat(run.style.fontSize), nil)

        var missing = 0
        for scalar in run.text.unicodeScalars {
            guard (0xAC00...0xD7AF).contains(Int(scalar.value)) ||
                  (0x1100...0x11FF).contains(Int(scalar.value)) ||
                  (0x3130...0x318F).contains(Int(scalar.value)) else {
                continue
            }
            let text = String(scalar)
            let font = CTFontCreateForString(baseFont, text as CFString, CFRange(location: 0, length: text.utf16.count))
            var character = UniChar(scalar.value)
            var glyph = CGGlyph()
            if !CTFontGetGlyphsForCharacters(font, &character, &glyph, 1) || glyph == 0 {
                missing += 1
            }
        }
        return missing
    }

    private static func countNonWhitePixels(_ pixels: [UInt8], bytesPerRow: Int, width: Int, height: Int) -> Int {
        var count = 0
        for y in 0..<height {
            let row = y * bytesPerRow
            for x in 0..<width {
                let i = row + x * 4
                let r = pixels[i]
                let g = pixels[i + 1]
                let b = pixels[i + 2]
                let a = pixels[i + 3]
                if a > 0 && (r < 245 || g < 245 || b < 245) {
                    count += 1
                }
            }
        }
        return count
    }

    private static func writePNG(image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
            throw RenderDebugError(description: "failed to create PNG destination: \(url.path)")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw RenderDebugError(description: "failed to write PNG: \(url.path)")
        }
    }

    private static func absoluteURL(_ path: String, isDirectory: Bool = false) -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path, isDirectory: isDirectory)
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            .appendingPathComponent(path, isDirectory: isDirectory)
    }
}

struct StandardError: TextOutputStream {
    mutating func write(_ string: String) {
        FileHandle.standardError.write(Data(string.utf8))
    }
}

var standardError = StandardError()
