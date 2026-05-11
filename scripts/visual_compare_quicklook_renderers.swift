import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct VisualCompareError: Error, CustomStringConvertible {
    let description: String
}

struct RGBAImage {
    let width: Int
    let height: Int
    var pixels: [UInt8]
}

struct DiffResult {
    let changedPixels: Int
    let totalPixels: Int
    let changedPercent: Double
    let meanRGBDelta: Double
    let maxRGBDelta: Int
    let bounds: CGRect?
}

@main
struct VisualCompareQuickLookRenderers {
    static func main() throws {
        let args = Array(CommandLine.arguments.dropFirst())
        guard args.count >= 5 else {
            throw VisualCompareError(
                description: "usage: visual_compare_quicklook_renderers <output-dir> <native-dir> <svg-pdf-dir> <page-number> <hwp-or-hwpx> [...]"
            )
        }

        let outputDir = absoluteURL(args[0], isDirectory: true)
        let nativeDir = absoluteURL(args[1], isDirectory: true)
        let svgPDFDir = absoluteURL(args[2], isDirectory: true)
        guard let pageNumber = Int(args[3]), pageNumber > 0 else {
            throw VisualCompareError(description: "page-number must be a positive integer")
        }
        let inputURLs = args.dropFirst(4).map { absoluteURL($0) }

        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        var summaryLines: [String] = []
        summaryLines.append("# Quick Look Visual Compare")
        summaryLines.append("")
        summaryLines.append("Page: \(pageNumber)")
        summaryLines.append("")
        summaryLines.append("| File | Status | Size | ChangedPixels | ChangedPercent | MeanRGBDelta | MaxRGBDelta | DiffBounds | NativePNG | SVGPDFPNG | DiffPNG |")
        summaryLines.append("|------|--------|------|---------------|----------------|--------------|-------------|------------|-----------|-----------|---------|")

        for inputURL in inputURLs {
            let row = try compare(
                inputURL: inputURL,
                pageNumber: pageNumber,
                nativeDir: nativeDir,
                svgPDFDir: svgPDFDir,
                outputDir: outputDir
            )
            summaryLines.append(row)
        }

        try summaryLines.joined(separator: "\n").write(
            to: outputDir.appendingPathComponent("visual-summary-page\(pageNumber).md"),
            atomically: true,
            encoding: .utf8
        )
    }

    private static func compare(
        inputURL: URL,
        pageNumber: Int,
        nativeDir: URL,
        svgPDFDir: URL,
        outputDir: URL
    ) throws -> String {
        let baseName = inputURL.deletingPathExtension().lastPathComponent
        let fileName = inputURL.lastPathComponent
        let nativePNG = nativeDir.appendingPathComponent("\(baseName)-page\(pageNumber)-native.png")
        let svgPDF = svgPDFDir.appendingPathComponent("\(baseName)-run1-svg-core.pdf")
        let svgPDFPNG = outputDir.appendingPathComponent("\(baseName)-page\(pageNumber)-svg-pdf.png")
        let diffPNG = outputDir.appendingPathComponent("\(baseName)-page\(pageNumber)-diff.png")

        do {
            let native = try loadRGBAImage(nativePNG)
            let rendered = try renderPDFPage(svgPDF, pageNumber: pageNumber, width: native.width, height: native.height)
            try writePNG(rendered, to: svgPDFPNG)

            let (diff, diffImage) = makeDiffImage(native: native, candidate: rendered)
            try writePNG(diffImage, to: diffPNG)

            return [
                markdownCell(fileName),
                "OK",
                "\(native.width)x\(native.height)",
                "\(diff.changedPixels)/\(diff.totalPixels)",
                formatPercent(diff.changedPercent),
                formatDouble(diff.meanRGBDelta),
                "\(diff.maxRGBDelta)",
                boundsString(diff.bounds),
                markdownCell(nativePNG.path),
                markdownCell(svgPDFPNG.path),
                markdownCell(diffPNG.path)
            ].joined(separator: " | ").wrappedTableRow
        } catch {
            return [
                markdownCell(fileName),
                "FAIL: \(String(describing: error).replacingOccurrences(of: "|", with: "/"))",
                "-",
                "-",
                "-",
                "-",
                "-",
                "-",
                markdownCell(nativePNG.path),
                markdownCell(svgPDFPNG.path),
                markdownCell(diffPNG.path)
            ].joined(separator: " | ").wrappedTableRow
        }
    }

    private static func loadRGBAImage(_ url: URL) throws -> RGBAImage {
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw VisualCompareError(description: "failed to load image: \(url.path)")
        }
        return try drawImageToRGBA(image)
    }

    private static func renderPDFPage(_ url: URL, pageNumber: Int, width: Int, height: Int) throws -> RGBAImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw VisualCompareError(description: "failed to load PDF: \(url.path)")
        }
        let pageIndex = pageNumber - 1
        guard pageIndex >= 0, pageIndex < CGImageSourceGetCount(source) else {
            throw VisualCompareError(description: "PDF page \(pageNumber) out of range: \(url.path)")
        }
        let maxPixelSize = max(width, height)
        let options: CFDictionary = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary
        guard let pageImage = CGImageSourceCreateThumbnailAtIndex(source, pageIndex, options) else {
            throw VisualCompareError(description: "failed to rasterize PDF page \(pageNumber): \(url.path)")
        }

        var image = blankRGBA(width: width, height: height)
        try image.withBitmapContext { context in
            let targetRect = CGRect(x: 0, y: 0, width: width, height: height)
            context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
            context.fill(targetRect)
            context.interpolationQuality = .high
            context.draw(pageImage, in: targetRect)
        }
        return image
    }

    private static func drawImageToRGBA(_ image: CGImage) throws -> RGBAImage {
        var rgba = blankRGBA(width: image.width, height: image.height)
        try rgba.withBitmapContext { context in
            context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return rgba
    }

    private static func blankRGBA(width: Int, height: Int) -> RGBAImage {
        let bytesPerRow = width * 4
        return RGBAImage(width: width, height: height, pixels: [UInt8](repeating: 255, count: height * bytesPerRow))
    }

    private static func makeDiffImage(native: RGBAImage, candidate: RGBAImage) -> (DiffResult, RGBAImage) {
        precondition(native.width == candidate.width && native.height == candidate.height)

        var diffImage = blankRGBA(width: native.width, height: native.height)
        var changedPixels = 0
        var totalDelta = 0
        var maxDelta = 0
        var minX = native.width
        var minY = native.height
        var maxX = -1
        var maxY = -1

        for y in 0..<native.height {
            for x in 0..<native.width {
                let index = (y * native.width + x) * 4
                let rDelta = abs(Int(native.pixels[index]) - Int(candidate.pixels[index]))
                let gDelta = abs(Int(native.pixels[index + 1]) - Int(candidate.pixels[index + 1]))
                let bDelta = abs(Int(native.pixels[index + 2]) - Int(candidate.pixels[index + 2]))
                let pixelDelta = max(rDelta, gDelta, bDelta)
                totalDelta += rDelta + gDelta + bDelta
                maxDelta = max(maxDelta, pixelDelta)

                if pixelDelta > 12 {
                    changedPixels += 1
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                    diffImage.pixels[index] = 255
                    diffImage.pixels[index + 1] = UInt8(max(0, 255 - pixelDelta))
                    diffImage.pixels[index + 2] = UInt8(max(0, 255 - pixelDelta))
                    diffImage.pixels[index + 3] = 255
                } else {
                    let gray = UInt8(240)
                    diffImage.pixels[index] = gray
                    diffImage.pixels[index + 1] = gray
                    diffImage.pixels[index + 2] = gray
                    diffImage.pixels[index + 3] = 255
                }
            }
        }

        let totalPixels = native.width * native.height
        let bounds: CGRect?
        if maxX >= 0 {
            bounds = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        } else {
            bounds = nil
        }
        let result = DiffResult(
            changedPixels: changedPixels,
            totalPixels: totalPixels,
            changedPercent: totalPixels == 0 ? 0 : Double(changedPixels) * 100.0 / Double(totalPixels),
            meanRGBDelta: totalPixels == 0 ? 0 : Double(totalDelta) / Double(totalPixels * 3),
            maxRGBDelta: maxDelta,
            bounds: bounds
        )
        return (result, diffImage)
    }

    private static func writePNG(_ image: RGBAImage, to url: URL) throws {
        var image = image
        let cgImage = try image.makeCGImage()
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw VisualCompareError(description: "failed to create PNG destination: \(url.path)")
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw VisualCompareError(description: "failed to write PNG: \(url.path)")
        }
    }

    private static func absoluteURL(_ path: String, isDirectory: Bool = false) -> URL {
        let url = URL(fileURLWithPath: path, isDirectory: isDirectory)
        if path.hasPrefix("/") {
            return url.standardizedFileURL
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(path, isDirectory: isDirectory)
            .standardizedFileURL
    }

    private static func markdownCell(_ value: String) -> String {
        "`\(value.replacingOccurrences(of: "|", with: "\\|"))`"
    }

    private static func formatPercent(_ value: Double) -> String {
        String(format: "%.4f%%", value)
    }

    private static func formatDouble(_ value: Double) -> String {
        String(format: "%.4f", value)
    }

    private static func boundsString(_ bounds: CGRect?) -> String {
        guard let bounds else {
            return "-"
        }
        return "\(Int(bounds.minX)),\(Int(bounds.minY)) \(Int(bounds.width))x\(Int(bounds.height))"
    }
}

private extension RGBAImage {
    mutating func withBitmapContext(_ work: (CGContext) throws -> Void) throws {
        let bytesPerRow = width * 4
        try pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                throw VisualCompareError(description: "failed to create bitmap context")
            }
            try work(context)
        }
    }

    mutating func makeCGImage() throws -> CGImage {
        let bytesPerRow = width * 4
        return try pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ), let image = context.makeImage() else {
                throw VisualCompareError(description: "failed to create CGImage")
            }
            return image
        }
    }
}

private extension String {
    var wrappedTableRow: String {
        "| \(self) |"
    }
}
