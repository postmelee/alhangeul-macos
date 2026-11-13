import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let hwpQuickLookMaxFileSize = 50 * 1024 * 1024

enum HwpPageRenderBackend {
    case coreGraphics
    case skia
    case embeddedThumbnail
}

enum HwpPageRenderPolicy {
    case coreGraphicsOnly
    case quickLookAutomatic
    case skiaOptIn

    var identifier: String {
        switch self {
        case .quickLookAutomatic:
            return "quickLookAutomatic"
        case .coreGraphicsOnly:
            return "coreGraphicsOnly"
        case .skiaOptIn:
            return "skiaOptIn"
        }
    }
}

enum HwpPageRenderFallbackReason {
    case ffiUnavailable
    case invalidDocumentHandle
    case invalidPageIndex
    case invalidRenderOptions
    case invalidPageSize
    case skiaRenderFailure
    case pngDecodeFailure
    case memoryTimeoutFallback
    case unsupportedFontContext
}

struct HwpPageRenderDuration {
    let skiaRenderMs: Double?
    let pngDecodeMs: Double?
    let coreGraphicsRenderMs: Double?
    let totalMs: Double

    init(
        skiaRenderMs: Double? = nil,
        pngDecodeMs: Double? = nil,
        coreGraphicsRenderMs: Double? = nil,
        totalMs: Double
    ) {
        self.skiaRenderMs = skiaRenderMs
        self.pngDecodeMs = pngDecodeMs
        self.coreGraphicsRenderMs = coreGraphicsRenderMs
        self.totalMs = totalMs
    }
}

struct HwpPageRenderDiagnostics {
    let policy: HwpPageRenderPolicy
    let backendUsed: HwpPageRenderBackend
    let fallbackReason: HwpPageRenderFallbackReason?
    let pageSize: CGSize
    let pixelSize: CGSize
    let pngBytes: Int?
    let durationMs: HwpPageRenderDuration
    var rawSvgSelection: String? = nil
    var fontIdentity: String? = nil
    var fontFaces: [String] = []
    var fontSupplyFailure: String? = nil
}

struct HwpRenderedPage: @unchecked Sendable {
    let image: CGImage
    let size: CGSize
    let diagnostics: HwpPageRenderDiagnostics

    init(
        image: CGImage,
        size: CGSize,
        diagnostics: HwpPageRenderDiagnostics? = nil
    ) {
        self.image = image
        self.size = size
        self.diagnostics = diagnostics ?? HwpPageRenderDiagnostics(
            policy: .coreGraphicsOnly,
            backendUsed: .coreGraphics,
            fallbackReason: nil,
            pageSize: size,
            pixelSize: CGSize(width: CGFloat(image.width), height: CGFloat(image.height)),
            pngBytes: nil,
            durationMs: HwpPageRenderDuration(totalMs: 0)
        )
    }
}

enum HwpEmbeddedThumbnailPolicy {
    case never
    case smallFinderThumbnail(maxPixelDimension: CGFloat)
}

enum HwpRenderError: Error {
    case fileTooLarge
    case emptyDocument
    case pageOutOfRange
    case renderTreeUnavailable
    case invalidPageSize
    case bitmapContextUnavailable
    case imageUnavailable
    case pngEncodingFailed
    case pdfEncodingFailed
}

enum HwpPageImageRenderer {
    static func renderFirstPage(fileURL: URL) throws -> HwpRenderedPage {
        try renderFirstPage(fileURL: fileURL, maximumPixelSize: nil, embeddedThumbnailPolicy: .never)
    }

    static func renderFirstPage(
        fileURL: URL,
        maximumPixelSize: CGSize?,
        embeddedThumbnailPolicy: HwpEmbeddedThumbnailPolicy = .never,
        policy: HwpPageRenderPolicy = .coreGraphicsOnly
    ) throws -> HwpRenderedPage {
        let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])
        if shouldRejectBeforeReadingData(
            fileSize: values.fileSize,
            policy: embeddedThumbnailPolicy
        ) {
            throw HwpRenderError.fileTooLarge
        }

        let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
        if let embedded = decodeEmbeddedThumbnail(
            from: data,
            maximumPixelSize: maximumPixelSize,
            thumbnailPolicy: embeddedThumbnailPolicy,
            renderPolicy: policy
        ) {
            return embedded
        }
        if let fileSize = values.fileSize, fileSize > hwpQuickLookMaxFileSize {
            throw HwpRenderError.fileTooLarge
        }

        let document = try RhwpDocument(data: data, filename: fileURL.lastPathComponent)
        guard document.pageCount > 0 else {
            throw HwpRenderError.emptyDocument
        }
        return try renderPage(
            document: document,
            pageIndex: 0,
            maximumPixelSize: maximumPixelSize,
            policy: policy
        )
    }

    static func renderPage(
        document: RhwpDocument,
        pageIndex: Int,
        maximumPixelSize: CGSize? = nil,
        policy: HwpPageRenderPolicy = .coreGraphicsOnly,
        fontContext: RhwpNativeFontContext? = nil,
        forceDefaultFonts: Bool = false
    ) throws -> HwpRenderedPage {
        guard pageIndex >= 0, pageIndex < document.pageCount else {
            throw HwpRenderError.pageOutOfRange
        }

        if policy == .quickLookAutomatic {
            let selection = forceDefaultFonts ? HwpQuickLookRawSvgPolicy.Selection.fontFallback
                : HwpQuickLookRawSvgPolicy.select(tree: document.renderPageTree(at: pageIndex))
            let page = try renderPage(document: document, pageIndex: pageIndex,
                maximumPixelSize: maximumPixelSize, policy: selection.policy,
                fontContext: fontContext, forceDefaultFonts: forceDefaultFonts)
            var diagnostics = page.diagnostics
            diagnostics.rawSvgSelection = selection.rawValue
            return .init(image: page.image, size: page.size, diagnostics: diagnostics)
        }

        let rawPageSize = document.pageSize(at: pageIndex)
        let pageSize = CGSize(width: CGFloat(rawPageSize.width), height: CGFloat(rawPageSize.height))
        guard isValidPageSize(pageSize) else {
            throw HwpRenderError.invalidPageSize
        }

        let scale = renderScale(
            pageSize: pageSize,
            maximumPixelSize: maximumPixelSize
        )
        let pixelSize = renderedPixelSize(pageSize: pageSize, scale: scale)

        if forceDefaultFonts {
            return try renderCoreGraphicsPage(document: document, pageIndex: pageIndex, pageSize: pageSize,
                scale: scale, pixelSize: pixelSize, policy: policy, forceDefaultFonts: true)
        }

        switch policy {
        case .coreGraphicsOnly, .quickLookAutomatic:
            return try renderCoreGraphicsPage(
                document: document,
                pageIndex: pageIndex,
                pageSize: pageSize,
                scale: scale,
                pixelSize: pixelSize,
                policy: policy,
                fontContext: fontContext
            )
        case .skiaOptIn:
            let attempt = renderSkiaPage(
                document: document,
                pageIndex: pageIndex,
                pageSize: pageSize,
                scale: scale,
                maxDimension: skiaMaxDimension(from: maximumPixelSize),
                fontContext: fontContext
            )
            if let page = attempt.page {
                return page
            }
            return try renderCoreGraphicsPage(
                document: document,
                pageIndex: pageIndex,
                pageSize: pageSize,
                scale: scale,
                pixelSize: pixelSize,
                policy: policy,
                fallbackReason: attempt.fallbackReason,
                pngBytes: attempt.pngBytes,
                skiaRenderMs: attempt.skiaRenderMs,
                pngDecodeMs: attempt.pngDecodeMs,
                fontContext: fontContext
            )
        }
    }

    static func encodePNG(_ image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            throw HwpRenderError.pngEncodingFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw HwpRenderError.pngEncodingFailed
        }
        return data as Data
    }

    private static func decodeEmbeddedThumbnail(
        from data: Data,
        maximumPixelSize: CGSize?,
        thumbnailPolicy: HwpEmbeddedThumbnailPolicy,
        renderPolicy: HwpPageRenderPolicy
    ) -> HwpRenderedPage? {
        guard let thumbnail = RhwpDocument.extractEmbeddedThumbnail(from: data) else {
            return nil
        }
        guard let source = CGImageSourceCreateWithData(thumbnail.data as CFData, nil) else {
            return nil
        }

        let decodeStart = DispatchTime.now().uptimeNanoseconds
        let image: CGImage?
        if let maximumPixelSize {
            let maxDimension = Int(max(maximumPixelSize.width, maximumPixelSize.height))
            if maxDimension > 0 {
                let options: CFDictionary = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceShouldCacheImmediately: true,
                    kCGImageSourceThumbnailMaxPixelSize: maxDimension
                ] as CFDictionary
                image = CGImageSourceCreateThumbnailAtIndex(source, 0, options)
            } else {
                image = CGImageSourceCreateImageAtIndex(source, 0, nil)
            }
        } else {
            image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        }
        let decodeMs = elapsedMilliseconds(since: decodeStart)

        guard let image else {
            return nil
        }

        guard shouldUseEmbeddedThumbnail(
            requestPixelSize: maximumPixelSize,
            policy: thumbnailPolicy
        ) else {
            return nil
        }

        let width = thumbnail.width > 0 ? thumbnail.width : image.width
        let height = thumbnail.height > 0 ? thumbnail.height : image.height
        let pageSize = CGSize(width: CGFloat(width), height: CGFloat(height))
        let pixelSize = CGSize(width: CGFloat(image.width), height: CGFloat(image.height))
        let diagnostics = HwpPageRenderDiagnostics(
            policy: renderPolicy,
            backendUsed: .embeddedThumbnail,
            fallbackReason: nil,
            pageSize: pageSize,
            pixelSize: pixelSize,
            pngBytes: nil,
            durationMs: HwpPageRenderDuration(totalMs: decodeMs)
        )
        return HwpRenderedPage(
            image: image,
            size: pageSize,
            diagnostics: diagnostics
        )
    }

    private static func shouldUseEmbeddedThumbnail(
        requestPixelSize: CGSize?,
        policy: HwpEmbeddedThumbnailPolicy
    ) -> Bool {
        switch policy {
        case .never:
            return false
        case .smallFinderThumbnail(let maxPixelDimension):
            guard let requestPixelSize else {
                return false
            }
            let requestedMaxDimension = max(requestPixelSize.width, requestPixelSize.height)
            guard requestedMaxDimension > 0 else {
                return false
            }
            return requestedMaxDimension <= maxPixelDimension
        }
    }

    private static func shouldRejectBeforeReadingData(
        fileSize: Int?,
        policy: HwpEmbeddedThumbnailPolicy
    ) -> Bool {
        guard let fileSize, fileSize > hwpQuickLookMaxFileSize else {
            return false
        }

        switch policy {
        case .never:
            return true
        case .smallFinderThumbnail:
            return false
        }
    }

    private struct SkiaRenderAttempt {
        let page: HwpRenderedPage?
        let fallbackReason: HwpPageRenderFallbackReason?
        let pngBytes: Int?
        let skiaRenderMs: Double?
        let pngDecodeMs: Double?
    }

    private static func renderSkiaPage(
        document: RhwpDocument,
        pageIndex: Int,
        pageSize: CGSize,
        scale: CGFloat,
        maxDimension: Int,
        fontContext: RhwpNativeFontContext?
    ) -> SkiaRenderAttempt {
        let skiaStart = DispatchTime.now().uptimeNanoseconds
        let png = document.renderPagePNG(
            at: pageIndex,
            scale: maxDimension > 0 ? 0 : Double(scale),
            maxDimension: maxDimension,
            fontContext: fontContext
        )
        let skiaRenderMs = elapsedMilliseconds(since: skiaStart)

        guard png.status == .ok, png.byteCount > 0 else {
            return SkiaRenderAttempt(
                page: nil,
                fallbackReason: fallbackReason(for: png.status),
                pngBytes: png.byteCount > 0 ? png.byteCount : nil,
                skiaRenderMs: skiaRenderMs,
                pngDecodeMs: nil
            )
        }

        let decodeStart = DispatchTime.now().uptimeNanoseconds
        let image = decodePNGImage(png.data)
        let pngDecodeMs = elapsedMilliseconds(since: decodeStart)

        guard let image else {
            return SkiaRenderAttempt(
                page: nil,
                fallbackReason: .pngDecodeFailure,
                pngBytes: png.byteCount,
                skiaRenderMs: skiaRenderMs,
                pngDecodeMs: pngDecodeMs
            )
        }

        let pixelSize = CGSize(width: CGFloat(image.width), height: CGFloat(image.height))
        let duration = HwpPageRenderDuration(
            skiaRenderMs: skiaRenderMs,
            pngDecodeMs: pngDecodeMs,
            totalMs: skiaRenderMs + pngDecodeMs
        )
        return SkiaRenderAttempt(
            page: HwpRenderedPage(
                image: image,
                size: pageSize,
                diagnostics: HwpPageRenderDiagnostics(
                    policy: .skiaOptIn,
                    backendUsed: .skia,
                    fallbackReason: nil,
                    pageSize: pageSize,
                    pixelSize: pixelSize,
                    pngBytes: png.byteCount,
                    durationMs: duration,
                    fontIdentity: fontContext?.identity,
                    fontFaces: png.fontDiagnostic?.faces?.map(\.postScriptName) ?? []
                )
            ),
            fallbackReason: nil,
            pngBytes: png.byteCount,
            skiaRenderMs: skiaRenderMs,
            pngDecodeMs: pngDecodeMs
        )
    }

    private static func renderCoreGraphicsPage(
        document: RhwpDocument,
        pageIndex: Int,
        pageSize: CGSize,
        scale: CGFloat,
        pixelSize: CGSize,
        policy: HwpPageRenderPolicy,
        fallbackReason: HwpPageRenderFallbackReason? = nil,
        pngBytes: Int? = nil,
        skiaRenderMs: Double? = nil,
        pngDecodeMs: Double? = nil,
        fontContext: RhwpNativeFontContext? = nil,
        forceDefaultFonts: Bool = false
    ) throws -> HwpRenderedPage {
        let coreStart = DispatchTime.now().uptimeNanoseconds
        guard let tree = document.renderPageTree(at: pageIndex) else {
            throw HwpRenderError.renderTreeUnavailable
        }
        let overlays = document.pageOverlayImages(at: pageIndex, renderTree: tree)

        let width = Int(pixelSize.width)
        let height = Int(pixelSize.height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw HwpRenderError.bitmapContextUnavailable
        }

        context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: scale, y: -scale)

        let nativeFonts = try fontContext.map(RhwpCoreTextFontContext.init)
        if let nativeFonts {
            try HwpNativePageCompositor.render(tree: tree, overlays: overlays, in: context,
                pageHeight: pageSize.height, document: document, fontContext: nativeFonts)
        } else {
            HwpNativePageCompositor.render(
                tree: tree,
                overlays: overlays,
                in: context,
                pageHeight: pageSize.height,
                document: document,
                forceDefaultFonts: forceDefaultFonts
            )
        }

        guard let image = context.makeImage() else {
            throw HwpRenderError.imageUnavailable
        }
        let coreGraphicsRenderMs = elapsedMilliseconds(since: coreStart)
        let totalMs = (skiaRenderMs ?? 0) + (pngDecodeMs ?? 0) + coreGraphicsRenderMs
        let diagnostics = HwpPageRenderDiagnostics(
            policy: policy,
            backendUsed: .coreGraphics,
            fallbackReason: fallbackReason,
            pageSize: pageSize,
            pixelSize: pixelSize,
            pngBytes: pngBytes,
            durationMs: HwpPageRenderDuration(
                skiaRenderMs: skiaRenderMs,
                pngDecodeMs: pngDecodeMs,
                coreGraphicsRenderMs: coreGraphicsRenderMs,
                totalMs: totalMs
            ),
            fontIdentity: fontContext?.identity,
            fontFaces: try nativeFonts?.validate(tree) ?? []
        )

        return HwpRenderedPage(
            image: image,
            size: pageSize,
            diagnostics: diagnostics
        )
    }

    private static func decodePNGImage(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private static func fallbackReason(for status: RhwpPagePNGStatus) -> HwpPageRenderFallbackReason {
        switch status {
        case .ok:
            return .skiaRenderFailure
        case .invalidHandle:
            return .invalidDocumentHandle
        case .invalidOutput:
            return .ffiUnavailable
        case .invalidPageIndex:
            return .invalidPageIndex
        case .invalidOptions:
            return .invalidRenderOptions
        case .unsupportedFontContext:
            return .unsupportedFontContext
        case .failure, .invalidFontContext, .fontContextTooLarge:
            return .skiaRenderFailure
        }
    }

    private static func isValidPageSize(_ pageSize: CGSize) -> Bool {
        pageSize.width.isFinite
            && pageSize.height.isFinite
            && pageSize.width > 0
            && pageSize.height > 0
    }

    private static func renderedPixelSize(pageSize: CGSize, scale: CGFloat) -> CGSize {
        let width = max(1, Int(ceil(pageSize.width * scale)))
        let height = max(1, Int(ceil(pageSize.height * scale)))
        return CGSize(
            width: CGFloat(width),
            height: CGFloat(height)
        )
    }

    private static func elapsedMilliseconds(since start: UInt64) -> Double {
        let end = DispatchTime.now().uptimeNanoseconds
        guard end >= start else {
            return 0
        }
        return Double(end - start) / 1_000_000
    }

    private static func renderScale(pageSize: CGSize, maximumPixelSize: CGSize?) -> CGFloat {
        guard
            let maximumPixelSize,
            pageSize.width > 0,
            pageSize.height > 0,
            maximumPixelSize.width > 0,
            maximumPixelSize.height > 0
        else {
            return 1
        }

        let scale = min(
            maximumPixelSize.width / pageSize.width,
            maximumPixelSize.height / pageSize.height
        )
        return scale.isFinite && scale > 0 ? scale : 1
    }

    private static func skiaMaxDimension(from maximumPixelSize: CGSize?) -> Int {
        guard let maximumPixelSize else {
            return 0
        }
        let longestEdge = max(maximumPixelSize.width, maximumPixelSize.height)
        guard longestEdge.isFinite, longestEdge > 0 else {
            return 0
        }
        let cappedEdge = min(ceil(longestEdge), CGFloat(Int32.max))
        return Int(cappedEdge)
    }
}

/// Quick Look에서만 사용한다. 임의 SVG 엔진을 활성화하지 않고 제한된 core 벡터만 허용한다.
/// 하나라도 검사를 통과하지 못하면 페이지 전체를 기존 CoreGraphics로 유지한다.
enum HwpQuickLookRawSvgPolicy {
    enum Selection: String {
        case vector, noVector, rejected, treeUnavailable, fontFallback
        var policy: HwpPageRenderPolicy { self == .vector ? .skiaOptIn : .coreGraphicsOnly }
    }

    static func select(tree: RenderNode?) -> Selection {
        guard let tree else { return .treeUnavailable }
        // 선택적 fallback은 1x preview 출력 예산 안에서만 사용한다.
        guard tree.bbox.width.isFinite, tree.bbox.height.isFinite,
              tree.bbox.width > 0, tree.bbox.height > 0,
              tree.bbox.width <= 8192, tree.bbox.height <= 8192,
              tree.bbox.width * tree.bbox.height <= 8_388_608 else { return .rejected }
        var pending: [(RenderNode, Int)] = [(tree, 0)]
        var nodes = 0
        var fragments = 0
        var bytes = 0
        var vector = false
        while let (node, depth) = pending.popLast() {
            nodes += 1
            guard nodes <= 100_000, depth <= 128 else { return .rejected }
            guard node.visible else { continue }
            if case .rawSvg(let raw) = node.nodeType {
                fragments += 1
                bytes += raw.svg.utf8.count
                let b = node.bbox
                guard fragments <= 32, bytes <= 4 * 1024 * 1024,
                      [b.x, b.y, b.width, b.height].allSatisfy({ $0.isFinite }),
                      b.width > 0, b.height > 0,
                      b.width <= 8192, b.height <= 8192,
                      b.width * b.height <= 8_388_608 else { return .rejected }
                // 기존 단일 래스터 조각만 있는 페이지는 전환하지 않는다.
                // 다른 조각과 섞인 경우에도 보수적으로 CoreGraphics를 유지한다.
                guard HwpQuickLookVectorSVG.isAllowed(raw.svg) else { return .rejected }
                vector = true
            }
            guard pending.count + node.children.count <= 100_000 else { return .rejected }
            pending.append(contentsOf: node.children.map { ($0, depth + 1) })
        }
        return vector ? .vector : .noVector
    }
}

private final class HwpQuickLookVectorSVG: NSObject, XMLParserDelegate {
    private static let elements: Set<String> = ["svg", "g", "rect", "line", "path", "text", "tspan", "circle", "ellipse", "polygon", "polyline"]
    private static let attributes: Set<String> = [
        "xmlns", "xmlns:xlink", "class", "id", "x", "y", "x1", "y1", "x2", "y2",
        "width", "height", "viewBox", "preserveAspectRatio", "transform", "d", "points",
        "cx", "cy", "r", "rx", "ry", "fill", "fill-rule", "fill-opacity", "stroke",
        "stroke-width", "stroke-opacity", "stroke-linecap", "stroke-linejoin",
        "stroke-dasharray", "stroke-dashoffset", "opacity", "font-family", "font-size",
        "font-weight", "font-style", "text-anchor", "dominant-baseline", "alignment-baseline",
        "dx", "dy", "letter-spacing", "textLength", "lengthAdjust", "xml:space"
    ]
    private var valid = true
    private var count = 0
    private var depth = 0
    private var drawable = false

    static func isAllowed(_ fragment: String) -> Bool {
        // DTD/entity/처리 명령/CSS는 진입 전에 거부하고 외부 해석을 하지 않는다.
        guard !fragment.isEmpty, !fragment.contains("<!"), !fragment.contains("<?"),
              let data = ("<svg xmlns=\"http://www.w3.org/2000/svg\">" + fragment + "</svg>").data(using: .utf8) else { return false }
        let delegate = HwpQuickLookVectorSVG()
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        return parser.parse() && delegate.valid && delegate.drawable
    }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName: String?, attributes values: [String: String]) {
        count += 1
        depth += 1
        guard count <= 16_384, depth <= 64, Self.elements.contains(name), values.count <= 32,
              values.allSatisfy({ key, value in
                  Self.attributes.contains(key) && !value.lowercased().contains("url")
                      && !value.contains("\\") && !value.contains("@")
              }) else {
            valid = false
            parser.abortParsing()
            return
        }
        if name != "svg" && name != "g" { drawable = true }
    }

    func parser(_ parser: XMLParser, didEndElement: String, namespaceURI: String?, qualifiedName: String?) {
        depth -= 1
    }
}
