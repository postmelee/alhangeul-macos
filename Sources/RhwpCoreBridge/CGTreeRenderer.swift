// Core Graphics 렌더러 — 렌더 트리를 CGContext에 직접 그린다.
// 3a단계: 도형(rect, line, ellipse, path) + 이미지 + 표 테두리
// 3b단계: 텍스트(Core Text + 폰트 폴백) — 별도 구현 예정

import CoreGraphics
import CoreText
import Foundation
import ImageIO

class CGTreeRenderer {
    private let imageCropUnitsPerPixel = 75.0

    private var imageCache: [UInt16: CGImage] = [:]
    private weak var document: RhwpDocument?

    private var pageHeight: Double = 0

    func render(tree: RenderNode, in context: CGContext, pageHeight: Double, document: RhwpDocument?) {
        HwpBundledFontRegistry.ensureRegistered()

        // 이미지 binDataId는 문서 내부 식별자이므로 문서가 바뀌면 캐시를 이어 쓰면 안 된다.
        if !isRenderingSameDocument(document) {
            clearCache()
        }
        self.document = document
        self.pageHeight = pageHeight
        // 호출 측은 좌상단 원점 좌표계로 CGContext를 전달한다.
        // 렌더 트리의 좌표(좌상단 원점)를 그대로 사용할 수 있다.
        // 단, Core Text와 CGImage는 원본 CG 좌표계(좌하단)를 기대하므로
        // 해당 요소에서만 국소적으로 좌표를 조정한다.
        renderNode(tree, in: context)
    }

    func clearCache() {
        imageCache.removeAll()
    }

    private func isRenderingSameDocument(_ document: RhwpDocument?) -> Bool {
        guard let currentDocument = self.document else {
            return document == nil
        }
        guard let document else {
            return false
        }
        return currentDocument === document
    }

    // MARK: - 트리 순회

    private func renderNode(_ node: RenderNode, in ctx: CGContext) {
        guard node.visible else { return }

        switch node.nodeType {
        case .page:
            // 페이지 배경 (흰색)
            ctx.setFillColor(CGColor(gray: 1.0, alpha: 1.0))
            ctx.fill(cgRect(node.bbox))
            renderChildren(node, in: ctx)

        case .pageBackground(let bg):
            renderPageBackground(bg, bbox: node.bbox, in: ctx)

        case .body(let body):
            if let clip = body.clipRect {
                ctx.saveGState()
                ctx.clip(to: cgRect(clip))
                renderChildren(node, in: ctx)
                ctx.restoreGState()
            } else {
                renderChildren(node, in: ctx)
            }

        case .tableCell(let cell):
            if cell.clip {
                ctx.saveGState()
                ctx.clip(to: cgRect(node.bbox))
                renderChildren(node, in: ctx)
                ctx.restoreGState()
            } else {
                renderChildren(node, in: ctx)
            }

        case .rectangle(let rect):
            renderRectangle(rect, bbox: node.bbox, in: ctx)
            renderChildren(node, in: ctx)

        case .line(let line):
            renderLine(line, bbox: node.bbox, in: ctx)
            renderChildren(node, in: ctx)

        case .ellipse(let ell):
            renderEllipse(ell, bbox: node.bbox, in: ctx)
            renderChildren(node, in: ctx)

        case .path(let path):
            renderPath(path, bbox: node.bbox, in: ctx)
            renderChildren(node, in: ctx)

        case .image(let img):
            renderImage(img, bbox: node.bbox, in: ctx)
            renderChildren(node, in: ctx)

        case .group:
            renderGroup(node, in: ctx)

        case .textRun(let run):
            renderTextRun(run, bbox: node.bbox, in: ctx)

        case .equation(let equation):
            renderEquation(equation, bbox: node.bbox, in: ctx)

        case .formObject:
            // 양식 개체는 M3 이후
            break

        case .footnoteMarker(let marker):
            renderFootnoteMarker(marker, bbox: node.bbox, in: ctx)

        default:
            // 구조 노드(header, footer, column 등): 자식만 순회
            renderChildren(node, in: ctx)
        }
    }

    private func renderChildren(_ node: RenderNode, in ctx: CGContext) {
        for child in node.children {
            renderNode(child, in: ctx)
        }
    }

    // MARK: - 사각형

    private func renderRectangle(_ rect: RectangleNode, bbox: BBox, in ctx: CGContext) {
        ctx.saveGState()
        applyTransform(rect.transform, bbox: bbox, in: ctx)

        let r = cgRect(bbox)
        let path: CGPath
        if rect.cornerRadius > 0 {
            path = CGPath(roundedRect: r, cornerWidth: CGFloat(rect.cornerRadius),
                          cornerHeight: CGFloat(rect.cornerRadius), transform: nil)
        } else {
            path = CGPath(rect: r, transform: nil)
        }

        // 그라데이션 채우기
        if let grad = rect.gradient {
            ctx.addPath(path)
            ctx.clip()
            drawGradient(grad, in: r, ctx: ctx)
        } else {
            applyShapeStyleFill(rect.style, path: path, in: ctx)
        }

        applyShapeStyleStroke(rect.style, path: path, in: ctx)
        ctx.restoreGState()
    }

    // MARK: - 직선

    private func renderLine(_ line: LineNode, bbox: BBox, in ctx: CGContext) {
        ctx.saveGState()
        applyTransform(line.transform, bbox: bbox, in: ctx)

        let style = line.style

        ctx.setStrokeColor(colorRefToCGColor(style.color))
        ctx.setLineWidth(CGFloat(max(style.width, 0.5)))
        applyDash(style.dash, in: ctx)

        ctx.move(to: CGPoint(x: line.x1, y: line.y1))
        ctx.addLine(to: CGPoint(x: line.x2, y: line.y2))
        ctx.strokePath()

        ctx.restoreGState()
    }

    // MARK: - 타원

    private func renderEllipse(_ ell: EllipseNode, bbox: BBox, in ctx: CGContext) {
        ctx.saveGState()
        applyTransform(ell.transform, bbox: bbox, in: ctx)

        let r = cgRect(bbox)
        let path = CGPath(ellipseIn: r, transform: nil)

        if let grad = ell.gradient {
            ctx.addPath(path)
            ctx.clip()
            drawGradient(grad, in: r, ctx: ctx)
        } else {
            applyShapeStyleFill(ell.style, path: path, in: ctx)
        }

        applyShapeStyleStroke(ell.style, path: path, in: ctx)
        ctx.restoreGState()
    }

    // MARK: - 패스

    private func renderPath(_ pathNode: PathNode, bbox: BBox, in ctx: CGContext) {
        ctx.saveGState()
        applyTransform(pathNode.transform, bbox: bbox, in: ctx)

        let cgPath = buildCGPath(pathNode.commands)

        if let grad = pathNode.gradient {
            ctx.addPath(cgPath)
            ctx.clip()
            drawGradient(grad, in: cgRect(bbox), ctx: ctx)
        } else {
            applyShapeStyleFill(pathNode.style, path: cgPath, in: ctx)
        }

        // 패스 노드는 lineStyle이 있으면 그것을 사용
        if let ls = pathNode.lineStyle {
            ctx.addPath(cgPath)
            ctx.setStrokeColor(colorRefToCGColor(ls.color))
            ctx.setLineWidth(CGFloat(max(ls.width, 0.5)))
            applyDash(ls.dash, in: ctx)
            ctx.strokePath()
        } else {
            applyShapeStyleStroke(pathNode.style, path: cgPath, in: ctx)
        }

        ctx.restoreGState()
    }

    private func buildCGPath(_ commands: [PathCommand]) -> CGPath {
        let path = CGMutablePath()
        for cmd in commands {
            switch cmd {
            case .moveTo(let x, let y):
                path.move(to: CGPoint(x: x, y: y))
            case .lineTo(let x, let y):
                path.addLine(to: CGPoint(x: x, y: y))
            case .curveTo(let x1, let y1, let x2, let y2, let x, let y):
                path.addCurve(to: CGPoint(x: x, y: y),
                              control1: CGPoint(x: x1, y: y1),
                              control2: CGPoint(x: x2, y: y2))
            case .arcTo(_, _, _, _, _, let x, let y):
                path.addLine(to: CGPoint(x: x, y: y))
            case .closePath:
                path.closeSubpath()
            }
        }
        return path
    }

    // MARK: - 이미지

    private func renderImage(_ img: ImageNode, bbox: BBox, in ctx: CGContext) {
        guard img.binDataId > 0, let doc = document else { return }

        let cgImage: CGImage
        if let cached = imageCache[img.binDataId] {
            cgImage = cached
        } else {
            guard let data = doc.imageData(binDataId: img.binDataId),
                  let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let cg = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return }
            imageCache[img.binDataId] = cg
            cgImage = cg
        }

        ctx.saveGState()
        applyTransform(img.transform, bbox: bbox, in: ctx)

        let drawImage = preparedImage(for: cgImage, node: img)
        let r = cgRect(bbox)
        let drawRect = imageDestinationRect(for: img, size: r.size)
        // CG draw(image:) 는 이미지를 rect에 맞춰 그리지만 상하 반전으로 그린다.
        // 이미지 영역에서만 Y축 반전하여 올바르게 표시한다.
        ctx.saveGState()
        ctx.translateBy(x: r.minX, y: r.minY + r.height)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(drawImage, in: drawRect)
        ctx.restoreGState()

        ctx.restoreGState()
    }

    // MARK: - 수식 SVG fragment

    private func parseEquationSVG(_ svgContent: String) -> [EquationSVGDrawItem] {
        EquationSVGFragmentParser.parse(svgContent)
    }

    private func renderEquation(_ equation: EquationNode, bbox: BBox, in ctx: CGContext) {
        let items = parseEquationSVG(equation.svgContent)
        guard !items.isEmpty else { return }

        let localBounds = equationLocalBounds(equation: equation, items: items)
        guard localBounds.width > 0, localBounds.height > 0 else { return }

        let scaleX = bbox.width / Double(localBounds.width)
        let scaleY = bbox.height / Double(localBounds.height)
        guard scaleX.isFinite, scaleY.isFinite, scaleX > 0, scaleY > 0 else { return }

        let defaultColor = colorRefToCGColor(equation.color)

        ctx.saveGState()
        ctx.translateBy(x: CGFloat(bbox.x), y: CGFloat(bbox.y))
        ctx.scaleBy(x: CGFloat(scaleX), y: CGFloat(scaleY))
        ctx.translateBy(x: -localBounds.minX, y: -localBounds.minY)

        for item in items {
            renderEquationItem(item, defaultColor: defaultColor, in: ctx)
        }

        ctx.restoreGState()
    }

    private func equationLocalBounds(equation: EquationNode, items: [EquationSVGDrawItem]) -> CGRect {
        if let layoutBox = equation.layoutBox, layoutBox.width > 0, layoutBox.height > 0 {
            return CGRect(
                x: layoutBox.x,
                y: layoutBox.y,
                width: layoutBox.width,
                height: layoutBox.height
            )
        }

        return equationItemBounds(items)
    }

    private func renderEquationItem(_ item: EquationSVGDrawItem, defaultColor: CGColor, in ctx: CGContext) {
        switch item {
        case .text(let text):
            renderEquationText(text, defaultColor: defaultColor, in: ctx)
        case .line(let line):
            renderEquationLine(line, defaultColor: defaultColor, in: ctx)
        case .path(let path):
            renderEquationPath(path, defaultColor: defaultColor, in: ctx)
        }
    }

    private func renderEquationText(_ text: EquationSVGText, defaultColor: CGColor, in ctx: CGContext) {
        guard !text.text.isEmpty, text.fontSize > 0,
              let color = cgColor(for: text.fill, defaultColor: defaultColor) else { return }

        let fontSize = CGFloat(text.fontSize)
        let fontName = equationFontName(for: text.text, familyList: text.fontFamily)
        var font = CTFontCreateWithName(fontName as CFString, fontSize, nil)

        if text.fontStyle?.lowercased() == "italic",
           let italicFont = CTFontCreateCopyWithSymbolicTraits(
            font,
            fontSize,
            nil,
            .italicTrait,
            .italicTrait
           ) {
            font = italicFont
        }

        let attributes: [NSAttributedString.Key: Any] = [
            coreTextFontKey: font,
            coreTextForegroundColorKey: color,
        ]
        let attrStr = NSAttributedString(string: text.text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attrStr)

        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))

        var x = CGFloat(text.x)
        switch text.textAnchor {
        case .start:
            break
        case .middle:
            x -= width / 2
        case .end:
            x -= width
        }

        ctx.saveGState()
        ctx.translateBy(x: x, y: CGFloat(text.y))
        ctx.scaleBy(x: 1, y: -1)
        ctx.textPosition = .zero
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }

    private func renderEquationLine(_ line: EquationSVGLine, defaultColor: CGColor, in ctx: CGContext) {
        guard line.strokeWidth > 0,
              let strokeColor = cgColor(for: line.stroke, defaultColor: defaultColor) else { return }

        ctx.saveGState()
        ctx.setStrokeColor(strokeColor)
        ctx.setLineWidth(CGFloat(line.strokeWidth))
        ctx.move(to: CGPoint(x: line.x1, y: line.y1))
        ctx.addLine(to: CGPoint(x: line.x2, y: line.y2))
        ctx.strokePath()
        ctx.restoreGState()
    }

    private func renderEquationPath(_ path: EquationSVGPath, defaultColor: CGColor, in ctx: CGContext) {
        let cgPath = buildEquationCGPath(path.commands)
        let fillColor = cgColor(for: path.fill, defaultColor: defaultColor)
        let strokeColor = cgColor(for: path.stroke, defaultColor: defaultColor)

        ctx.saveGState()
        if let fillColor {
            ctx.addPath(cgPath)
            ctx.setFillColor(fillColor)
            ctx.fillPath()
        }
        if let strokeColor, path.strokeWidth > 0 {
            ctx.addPath(cgPath)
            ctx.setStrokeColor(strokeColor)
            ctx.setLineWidth(CGFloat(path.strokeWidth))
            ctx.strokePath()
        }
        ctx.restoreGState()
    }

    private func buildEquationCGPath(_ commands: [EquationSVGPathCommand]) -> CGPath {
        let path = CGMutablePath()
        for command in commands {
            switch command {
            case .moveTo(let x, let y):
                path.move(to: CGPoint(x: x, y: y))
            case .lineTo(let x, let y):
                path.addLine(to: CGPoint(x: x, y: y))
            case .quadCurveTo(let cx, let cy, let x, let y):
                path.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: cx, y: cy))
            case .closePath:
                path.closeSubpath()
            }
        }
        return path
    }

    private func equationItemBounds(_ items: [EquationSVGDrawItem]) -> CGRect {
        var bounds = CGRect.null

        for item in items {
            switch item {
            case .text(let text):
                let width = max(CGFloat(text.text.count) * CGFloat(text.fontSize) * 0.65, 1)
                let rect = CGRect(
                    x: CGFloat(text.x),
                    y: CGFloat(text.y - text.fontSize),
                    width: width,
                    height: CGFloat(text.fontSize)
                )
                bounds = bounds.union(rect)
            case .line(let line):
                bounds = bounds.union(CGRect(
                    x: min(line.x1, line.x2),
                    y: min(line.y1, line.y2),
                    width: abs(line.x2 - line.x1),
                    height: abs(line.y2 - line.y1)
                ).insetBy(dx: -CGFloat(line.strokeWidth), dy: -CGFloat(line.strokeWidth)))
            case .path(let path):
                for point in equationPathPoints(path.commands) {
                    bounds = bounds.union(CGRect(x: point.x, y: point.y, width: 1, height: 1))
                }
            }
        }

        return bounds.isNull ? .zero : bounds
    }

    private func equationPathPoints(_ commands: [EquationSVGPathCommand]) -> [CGPoint] {
        var points: [CGPoint] = []
        for command in commands {
            switch command {
            case .moveTo(let x, let y), .lineTo(let x, let y):
                points.append(CGPoint(x: x, y: y))
            case .quadCurveTo(let cx, let cy, let x, let y):
                points.append(CGPoint(x: cx, y: cy))
                points.append(CGPoint(x: x, y: y))
            case .closePath:
                break
            }
        }
        return points
    }

    private func equationFontName(for text: String, familyList: String?) -> String {
        if text.contains(where: { character in
            character.unicodeScalars.contains { scalar in
                scalar.value >= 0xAC00 && scalar.value <= 0xD7A3
            }
        }) {
            return "AppleMyungjo"
        }

        let candidates = familyList.map(equationFontCandidates) ?? []
        for candidate in candidates {
            switch candidate.lowercased() {
            case "times new roman":
                return "TimesNewRomanPSMT"
            case "times", "serif":
                return "Times-Roman"
            case "stix two text":
                return "STIXTwoText"
            case "stix two math":
                return "STIXTwoMath"
            case "latin modern math":
                continue
            default:
                if !candidate.isEmpty {
                    return candidate
                }
            }
        }
        return "TimesNewRomanPSMT"
    }

    private func equationFontCandidates(_ familyList: String) -> [String] {
        familyList
            .split(separator: ",")
            .map {
                $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "'\"")))
            }
            .filter { !$0.isEmpty }
    }

    private func cgColor(for paint: EquationSVGPaint?, defaultColor: CGColor) -> CGColor? {
        switch paint {
        case nil:
            return defaultColor
        case .some(.none):
            return nil
        case .some(.color(let color)):
            return CGColor(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
        }
    }

    private func preparedImage(for image: CGImage, node: ImageNode) -> CGImage {
        let cropped = croppedImage(for: image, crop: node.crop)
        return adjustedImage(for: cropped, node: node)
    }

    private func croppedImage(for image: CGImage, crop: [Int32]?) -> CGImage {
        guard let crop, crop.count == 4 else { return image }

        let imageWidth = Double(image.width)
        let imageHeight = Double(image.height)
        guard imageWidth > 0, imageHeight > 0 else { return image }

        let left = max(0, floor(Double(crop[0]) / imageCropUnitsPerPixel))
        let top = max(0, floor(Double(crop[1]) / imageCropUnitsPerPixel))
        let right = min(imageWidth, ceil(Double(crop[2]) / imageCropUnitsPerPixel))
        let bottom = min(imageHeight, ceil(Double(crop[3]) / imageCropUnitsPerPixel))

        guard right > left, bottom > top else { return image }

        let sourceRect = CGRect(x: left, y: top, width: right - left, height: bottom - top)
        return image.cropping(to: sourceRect) ?? image
    }

    private func adjustedImage(for image: CGImage, node: ImageNode) -> CGImage {
        let effect = normalizedImageEffect(node.effect)
        let brightness = node.brightness ?? 0
        let contrast = node.contrast ?? 0
        guard effect != nil || brightness != 0 || contrast != 0 else { return image }

        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return image }

        let bytesPerPixel = 4
        let bitsPerComponent = 8
        let bytesPerRow = width * bytesPerPixel
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
            .union(.byteOrder32Big)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

        return pixels.withUnsafeMutableBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress,
                  let bitmapContext = CGContext(
                    data: baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: bitsPerComponent,
                    bytesPerRow: bytesPerRow,
                    space: colorSpace,
                    bitmapInfo: bitmapInfo.rawValue
                  ) else {
                return image
            }

            bitmapContext.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            applyImageAdjustments(
                to: rawBuffer,
                width: width,
                height: height,
                bytesPerRow: bytesPerRow,
                effect: effect,
                brightness: brightness,
                contrast: contrast
            )
            return bitmapContext.makeImage() ?? image
        }
    }

    private func applyImageAdjustments(
        to rawBuffer: UnsafeMutableRawBufferPointer,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        effect: ImageEffect?,
        brightness: Int,
        contrast: Int
    ) {
        let slope = max(0, 1.0 + Double(contrast) / 100.0)
        let intercept = Double(brightness) / 100.0 * slope
        let bytes = rawBuffer.bindMemory(to: UInt8.self)

        for y in 0..<height {
            let rowOffset = y * bytesPerRow
            for x in 0..<width {
                let offset = rowOffset + x * 4
                let alpha = Double(bytes[offset + 3]) / 255.0
                guard alpha > 0 else {
                    bytes[offset] = 0
                    bytes[offset + 1] = 0
                    bytes[offset + 2] = 0
                    continue
                }

                // CGContext stores premultiplied RGBA. Apply filters in straight color space.
                var red = clampedUnit((Double(bytes[offset]) / 255.0) / alpha)
                var green = clampedUnit((Double(bytes[offset + 1]) / 255.0) / alpha)
                var blue = clampedUnit((Double(bytes[offset + 2]) / 255.0) / alpha)

                if effect == .grayscale || effect == .blackWhite {
                    let gray = red * 0.299 + green * 0.587 + blue * 0.114
                    red = gray
                    green = gray
                    blue = gray
                }

                if brightness != 0 || contrast != 0 {
                    red = red * slope + intercept
                    green = green * slope + intercept
                    blue = blue * slope + intercept
                }

                bytes[offset] = normalizedColorByte(clampedUnit(red) * alpha)
                bytes[offset + 1] = normalizedColorByte(clampedUnit(green) * alpha)
                bytes[offset + 2] = normalizedColorByte(clampedUnit(blue) * alpha)
            }
        }
    }

    private func clampedUnit(_ value: Double) -> Double {
        max(0, min(1, value))
    }

    private func normalizedColorByte(_ value: Double) -> UInt8 {
        UInt8(max(0, min(255, Int((value * 255.0).rounded()))))
    }

    private enum ImageEffect {
        case grayscale
        case blackWhite
    }

    private func normalizedImageEffect(_ effect: String?) -> ImageEffect? {
        guard let effect else { return nil }
        let normalized = effect
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .lowercased()

        switch normalized {
        case "", "realpic", "none":
            return nil
        case "grayscale", "gray", "greyscale", "grey":
            return .grayscale
        case "blackwhite", "blackandwhite", "monochrome":
            // Render as grayscale for now; threshold parity needs a dedicated sample.
            return .blackWhite
        default:
            return nil
        }
    }

    private func imageDestinationRect(for img: ImageNode, size: CGSize) -> CGRect {
        let fullRect = CGRect(origin: .zero, size: size)
        guard let fillMode = img.fillMode?.trimmingCharacters(in: .whitespacesAndNewlines),
              !fillMode.isEmpty else {
            return fullRect
        }

        switch fillMode.replacingOccurrences(of: "_", with: "").lowercased() {
        case "fittosize", "stretch", "stretchtofit":
            return fullRect
        default:
            return fullRect
        }
    }

    // MARK: - 그룹

    private func renderGroup(_ node: RenderNode, in ctx: CGContext) {
        ctx.saveGState()
        // 그룹 노드의 transform은 자식에게 적용
        if case .group = node.nodeType {
            // 그룹 자체는 transform 없음 (자식 개별 적용)
        }
        renderChildren(node, in: ctx)
        ctx.restoreGState()
    }

    // MARK: - 페이지 배경

    private func renderPageBackground(_ bg: PageBackgroundNode, bbox: BBox, in ctx: CGContext) {
        let r = cgRect(bbox)
        if let gradient = bg.gradient {
            ctx.saveGState()
            ctx.clip(to: r)
            drawGradient(gradient, in: r, ctx: ctx)
            ctx.restoreGState()
        } else if let bgColor = bg.backgroundColor {
            ctx.setFillColor(colorRefToCGColor(bgColor))
            ctx.fill(r)
        }
        if let borderColor = bg.borderColor, bg.borderWidth > 0 {
            ctx.setStrokeColor(colorRefToCGColor(borderColor))
            ctx.setLineWidth(CGFloat(bg.borderWidth))
            ctx.stroke(r)
        }
    }

    // MARK: - 텍스트 (Core Text)

    private func renderTextRun(_ run: TextRunNode, bbox: BBox, in ctx: CGContext) {
        guard !run.text.isEmpty else { return }

        let style = run.style
        let fontSize = CGFloat(style.fontSize)
        guard fontSize > 0 else { return }

        ctx.saveGState()

        // 음영 (형광펜 배경) — 텍스트 변환 전에 그리기
        if style.shadeColor != 0x00FFFFFF && style.shadeColor != 0 {
            let shadeRect = cgRect(bbox)
            ctx.setFillColor(colorRefToCGColor(style.shadeColor).copy(alpha: 0.3)!)
            ctx.fill(shadeRect)
        }

        // 전체 좌표계가 Y반전(좌상단 원점) 상태이지만,
        // Core Text는 Y축이 위로 증가하는 좌표계를 기대한다.
        // bbox 영역 내에서만 Y축을 다시 반전하여 Core Text가 올바르게 그리도록 한다.
        ctx.saveGState()
        // bbox 영역의 하단으로 이동 → Y반전 → bbox 내부 좌표 (0,0)이 좌하단이 됨
        ctx.translateBy(x: CGFloat(bbox.x), y: CGFloat(bbox.y + bbox.height))
        ctx.scaleBy(x: 1, y: -1)

        let font = makeTextRunFont(style: style, fontSize: fontSize)
        let attributes = makeTextRunAttributes(style: style, font: font)

        let attrStr = NSAttributedString(string: run.text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attrStr)
        let layout = makeTextRunLayoutPlan(
            text: run.text,
            style: style,
            bbox: bbox,
            line: line,
            attributes: attributes,
            charPositions: run.charPositions
        )

        // Core Text 좌하단 좌표계에서 베이스라인 위치
        // bbox 내부 좌표: baseline은 bbox.y 상단으로부터의 거리
        // Core Text Y: bbox 하단(0)으로부터 위로 = bbox.height - baseline
        let textY = CGFloat(bbox.height) - CGFloat(run.baseline)
        drawTextLine(line, layout: layout, style: style, attributes: attributes, y: textY, in: ctx)

        ctx.restoreGState()

        // 밑줄 (페이지 좌표계, 전체 Y반전 상태)
        if style.underline != "None" {
            let ulY = CGFloat(bbox.y) + CGFloat(run.baseline) + fontSize * 0.15
            drawTextDecoration(
                in: ctx, x: CGFloat(bbox.x), y: ulY, width: CGFloat(bbox.width),
                shape: style.underlineShape,
                color: style.underlineColor != 0 ? style.underlineColor : style.color
            )
        }

        // 취소선
        if style.strikethrough {
            let stY = CGFloat(bbox.y) + CGFloat(bbox.height) / 2
            drawTextDecoration(
                in: ctx, x: CGFloat(bbox.x), y: stY, width: CGFloat(bbox.width),
                shape: style.strikeShape,
                color: style.strikeColor != 0 ? style.strikeColor : style.color
            )
        }

        ctx.restoreGState()
    }

    private func makeTextRunFont(style: TextStyle, fontSize: CGFloat) -> CTFont {
        var font = resolveAppleFont(
            hwpFontFamily: style.fontFamily,
            bold: style.bold,
            italic: style.italic,
            size: fontSize
        )

        if style.ratio != 1.0 && style.ratio > 0 {
            var matrix = CGAffineTransform(scaleX: CGFloat(style.ratio), y: 1.0)
            font = CTFontCreateCopyWithAttributes(font, fontSize, &matrix, nil)
        }

        return font
    }

    private func makeTextRunAttributes(style: TextStyle, font: CTFont) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [
            coreTextFontKey: font,
            coreTextForegroundColorKey: colorRefToCGColor(style.color),
        ]

        if style.letterSpacing != 0 {
            attributes[coreTextKernKey] = CGFloat(style.letterSpacing)
        }

        return attributes
    }

    private func makeTextRunLayoutPlan(
        text: String,
        style: TextStyle,
        bbox: BBox,
        line: CTLine,
        attributes: [NSAttributedString.Key: Any],
        charPositions: [Double]?
    ) -> TextRunLayoutPlan {
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let measuredWidth = max(0, CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading)))
        let targetWidth = max(0, CGFloat(bbox.width))
        let clusterSpans = splitTextRunClusters(text)
        let spacing = estimateTextRunSpacing(clusterSpans: clusterSpans, style: style)
        let explicitPositions = explicitTextRunClusterPositions(
            clusterSpans: clusterSpans,
            charPositions: charPositions
        )
        let clusterPlan = shouldUseTextRunClusterDrawing(
            clusterSpans: clusterSpans,
            style: style,
            measuredWidth: measuredWidth,
            targetWidth: targetWidth,
            spacing: spacing,
            explicitPositions: explicitPositions
        ) ? makeTextRunClusterPlan(
            clusterSpans: clusterSpans,
            style: style,
            targetWidth: targetWidth,
            attributes: attributes,
            explicitPositions: explicitPositions
        ) : nil
        let strategy = chooseTextRunDrawStrategy(
            measuredWidth: measuredWidth,
            targetWidth: targetWidth,
            clusterPlan: clusterPlan
        )

        return TextRunLayoutPlan(
            clusterPlan: clusterPlan,
            strategy: strategy
        )
    }

    private func estimateTextRunSpacing(
        clusterSpans: [TextRunClusterSpan],
        style: TextStyle
    ) -> TextRunSpacingEstimate {
        var clusterSpacingGapCount = 0
        var wordSpaceGapCount = 0
        var tabCount = 0

        for index in clusterSpans.indices {
            let character = clusterSpans[index].text
            let nextIndex = clusterSpans.index(after: index)
            let nextCharacter = nextIndex < clusterSpans.endIndex ? clusterSpans[nextIndex].text : nil
            if character == "\t" {
                tabCount += 1
            } else if nextCharacter != nil && nextCharacter != "\t" {
                clusterSpacingGapCount += 1
            }
            if isTextRunWordSpace(character), nextCharacter != nil, nextCharacter != "\t" {
                wordSpaceGapCount += 1
            }
        }

        let extraCharWidth = CGFloat(style.extraCharSpacing) * CGFloat(clusterSpacingGapCount)
        let extraWordWidth = CGFloat(style.extraWordSpacing) * CGFloat(wordSpaceGapCount)

        return TextRunSpacingEstimate(
            tabCount: tabCount,
            extraCharWidth: extraCharWidth,
            extraWordWidth: extraWordWidth
        )
    }

    private func shouldUseTextRunClusterDrawing(
        clusterSpans: [TextRunClusterSpan],
        style: TextStyle,
        measuredWidth: CGFloat,
        targetWidth: CGFloat,
        spacing: TextRunSpacingEstimate,
        explicitPositions: [CGFloat]?
    ) -> Bool {
        if explicitPositions != nil {
            return true
        }
        if spacing.requiresClusterDrawing {
            return true
        }
        if clusterSpans.contains(where: { needsHalfwidthPunctuationScale($0.text, style: style) }) {
            return true
        }
        guard measuredWidth > 0, targetWidth > 0 else {
            return false
        }
        return abs(targetWidth / measuredWidth - 1) >= 0.02
    }

    private func chooseTextRunDrawStrategy(
        measuredWidth: CGFloat,
        targetWidth: CGFloat,
        clusterPlan: TextRunClusterPlan?
    ) -> TextRunDrawStrategy {
        if clusterPlan != nil {
            return .clusters
        }

        guard measuredWidth > 0, targetWidth > 0 else {
            return .line
        }

        let scale = targetWidth / measuredWidth
        if abs(scale - 1) < 0.005 {
            return .line
        }

        if scale >= 0.90 && scale <= 1.10 {
            return .scaledLine(scale)
        }

        return .line
    }

    private func drawTextLine(
        _ line: CTLine,
        layout: TextRunLayoutPlan,
        style: TextStyle,
        attributes: [NSAttributedString.Key: Any],
        y: CGFloat,
        in ctx: CGContext
    ) {
        switch layout.strategy {
        case .line:
            ctx.textPosition = CGPoint(x: 0, y: y)
            CTLineDraw(line, ctx)
        case .clusters:
            guard let clusterPlan = layout.clusterPlan else {
                ctx.textPosition = CGPoint(x: 0, y: y)
                CTLineDraw(line, ctx)
                return
            }
            drawTextClusters(clusterPlan.clusters, style: style, attributes: attributes, y: y, in: ctx)
        case .scaledLine(let scale):
            ctx.saveGState()
            ctx.scaleBy(x: scale, y: 1)
            ctx.textPosition = CGPoint(x: 0, y: y)
            CTLineDraw(line, ctx)
            ctx.restoreGState()
        }
    }

    private func makeTextRunClusterPlan(
        clusterSpans: [TextRunClusterSpan],
        style: TextStyle,
        targetWidth: CGFloat,
        attributes: [NSAttributedString.Key: Any],
        explicitPositions: [CGFloat]?
    ) -> TextRunClusterPlan? {
        let allowsSingleClusterPlan = clusterSpans.count == 1 &&
            clusterSpans.first.map({ needsHalfwidthPunctuationScale($0.text, style: style) }) == true
        guard clusterSpans.count > 1 || allowsSingleClusterPlan else { return nil }

        let rawPositions: [CGFloat]
        let metrics: [TextRunClusterMetric]?
        if let explicitPositions {
            rawPositions = explicitPositions
            metrics = nil
        } else {
            let measuredMetrics = clusterSpans.map { cluster in
                makeTextRunClusterMetric(cluster.text, style: style, attributes: attributes)
            }
            rawPositions = textRunClusterPositions(metrics: measuredMetrics, style: style)
            metrics = measuredMetrics
        }
        guard rawPositions.count == clusterSpans.count + 1,
              let rawWidth = rawPositions.last,
              rawWidth.isFinite,
              rawWidth > 0 else {
            return nil
        }

        let scale = explicitPositions == nil && targetWidth > 0 ? targetWidth / rawWidth : 1
        guard scale.isFinite, scale >= 0.40, scale <= 2.50 else {
            return nil
        }

        var clusters: [TextRunCluster] = []
        clusters.reserveCapacity(clusterSpans.count)
        for index in clusterSpans.indices {
            let clusterText = clusterSpans[index].text
            let startX = rawPositions[index] * scale
            clusters.append(TextRunCluster(
                text: clusterText,
                x: startX,
                line: metrics?[index].line ?? makeDrawableTextClusterLine(clusterText, attributes: attributes)
            ))
        }

        return TextRunClusterPlan(clusters: clusters)
    }

    private func splitTextRunClusters(_ text: String) -> [TextRunClusterSpan] {
        var spans: [TextRunClusterSpan] = []
        spans.reserveCapacity(text.count)

        var scalarOffset = 0
        for character in text {
            let clusterText = String(character)
            let scalarCount = clusterText.unicodeScalars.count
            spans.append(TextRunClusterSpan(
                text: clusterText,
                scalarStart: scalarOffset,
                scalarEnd: scalarOffset + scalarCount
            ))
            scalarOffset += scalarCount
        }

        return spans
    }

    private func explicitTextRunClusterPositions(
        clusterSpans: [TextRunClusterSpan],
        charPositions: [Double]?
    ) -> [CGFloat]? {
        guard let charPositions,
              let lastCluster = clusterSpans.last else {
            return nil
        }

        let expectedCount = lastCluster.scalarEnd + 1
        guard charPositions.count == expectedCount else {
            return nil
        }

        var positions: [CGFloat] = []
        positions.reserveCapacity(clusterSpans.count + 1)
        for cluster in clusterSpans {
            let value = CGFloat(charPositions[cluster.scalarStart])
            guard value.isFinite else { return nil }
            if let previous = positions.last, value < previous {
                return nil
            }
            positions.append(value)
        }

        let endValue = CGFloat(charPositions[lastCluster.scalarEnd])
        guard endValue.isFinite,
              positions.last.map({ endValue >= $0 }) ?? true else {
            return nil
        }
        positions.append(endValue)
        return positions
    }

    private func textRunClusterPositions(metrics: [TextRunClusterMetric], style: TextStyle) -> [CGFloat] {
        let fontSize = CGFloat(style.fontSize > 0 ? style.fontSize : 12)
        let defaultTabWidth = CGFloat(style.defaultTabWidth > 0 ? style.defaultTabWidth : Double(fontSize * 4))
        let hasCustomTabs = !style.tabStops.isEmpty || style.autoTabRight
        let lineXOffset = CGFloat(style.lineXOffset)

        var positions: [CGFloat] = [0]
        positions.reserveCapacity(metrics.count + 1)

        var x: CGFloat = 0
        var tabIndex = 0
        for index in metrics.indices {
            let metric = metrics[index]
            if metric.text == "\t" {
                if tabIndex < style.inlineTabs.count {
                    let inlineTab = style.inlineTabs[tabIndex]
                    let tabWidth = inlineTab.isEmpty ? defaultTabWidth : CGFloat(inlineTab[0]) * 96 / 7200
                    let tabType = inlineTab.count > 2 ? inlineTab[2] : 0
                    let tabTarget = x + tabWidth
                    x = resolvedTabX(
                        currentX: x,
                        tabTarget: tabTarget,
                        tabType: tabType,
                        metrics: metrics,
                        nextIndex: index + 1,
                        style: style
                    )
                } else if hasCustomTabs {
                    let tabStop = findNextTextRunTabStop(
                        absX: lineXOffset + x,
                        style: style,
                        defaultTabWidth: defaultTabWidth
                    )
                    let tabTarget = tabStop.position - lineXOffset
                    x = resolvedTabX(
                        currentX: x,
                        tabTarget: tabTarget,
                        tabType: tabStop.tabType,
                        metrics: metrics,
                        nextIndex: index + 1,
                        style: style
                    )
                } else {
                    let absX = lineXOffset + x
                    let tabWidth = defaultTabWidth > 0 ? defaultTabWidth : 48
                    let nextAbs = (floor(absX / tabWidth) + 1) * tabWidth
                    x = max(x, nextAbs - lineXOffset)
                }
                tabIndex += 1
            } else {
                x += textRunClusterAdvance(at: index, metrics: metrics, style: style)
            }
            positions.append(x)
        }

        return positions
    }

    private func resolvedTabX(
        currentX: CGFloat,
        tabTarget: CGFloat,
        tabType: UInt16,
        metrics: [TextRunClusterMetric],
        nextIndex: Int,
        style: TextStyle
    ) -> CGFloat {
        switch tabType {
        case 1:
            let segmentWidth = measureTextRunSegment(metrics: metrics, start: nextIndex, style: style)
            return max(currentX, tabTarget - segmentWidth)
        case 2:
            let segmentWidth = measureTextRunSegment(metrics: metrics, start: nextIndex, style: style)
            return max(currentX, tabTarget - segmentWidth / 2)
        default:
            return max(currentX, tabTarget)
        }
    }

    private func measureTextRunSegment(metrics: [TextRunClusterMetric], start: Int, style: TextStyle) -> CGFloat {
        guard start < metrics.count else { return 0 }

        var width: CGFloat = 0
        for index in start..<metrics.count {
            let metric = metrics[index]
            if metric.text == "\t" { break }
            width += textRunClusterAdvance(at: index, metrics: metrics, style: style)
        }
        return width
    }

    private func textRunClusterAdvance(
        at index: Int,
        metrics: [TextRunClusterMetric],
        style: TextStyle
    ) -> CGFloat {
        max(0, metrics[index].baseAdvance + textRunInterClusterSpacing(after: index, metrics: metrics, style: style))
    }

    private func textRunInterClusterSpacing(
        after index: Int,
        metrics: [TextRunClusterMetric],
        style: TextStyle
    ) -> CGFloat {
        let nextIndex = metrics.index(after: index)
        guard nextIndex < metrics.endIndex else { return 0 }

        let metric = metrics[index]
        let nextMetric = metrics[nextIndex]
        guard metric.text != "\t", nextMetric.text != "\t" else { return 0 }

        let styleSpacing = CGFloat(style.letterSpacing + style.extraCharSpacing)
        let wordSpacing = isTextRunWordSpace(metric.text) ? CGFloat(style.extraWordSpacing) : 0
        return styleSpacing + wordSpacing
    }

    private func findNextTextRunTabStop(
        absX: CGFloat,
        style: TextStyle,
        defaultTabWidth: CGFloat
    ) -> TextRunTabStop {
        let availableWidth = CGFloat(style.availableWidth)
        for tabStop in style.tabStops {
            let rawPosition = CGFloat(tabStop.position)
            let position = rawPosition > availableWidth && availableWidth > 0 ? availableWidth : rawPosition
            if position > absX + 0.5 {
                return TextRunTabStop(
                    position: position,
                    tabType: UInt16(tabStop.tabType),
                    fillType: tabStop.fillType
                )
            }
        }

        if style.autoTabRight && availableWidth > absX + 0.5 {
            return TextRunTabStop(position: availableWidth, tabType: 1, fillType: 0)
        }

        let tabWidth = defaultTabWidth > 0 ? defaultTabWidth : 48
        let next = (floor(absX / tabWidth) + 1) * tabWidth
        return TextRunTabStop(position: next, tabType: 0, fillType: 0)
    }

    private func makeTextRunClusterMetric(
        _ cluster: String,
        style: TextStyle,
        attributes: [NSAttributedString.Key: Any]
    ) -> TextRunClusterMetric {
        if cluster == "\t" {
            return TextRunClusterMetric(text: cluster, baseAdvance: 0, line: nil)
        }

        let line = makeTextRunClusterLine(cluster, attributes: attributes)
        let measuredWidth = measureTextRunClusterWidth(line)
        return TextRunClusterMetric(
            text: cluster,
            baseAdvance: textRunClusterBaseWidth(cluster, measuredWidth: measuredWidth, style: style),
            line: isDrawableTextCluster(cluster) ? line : nil
        )
    }

    private func isTextRunWordSpace(_ cluster: String) -> Bool {
        cluster != "\t" && cluster.unicodeScalars.allSatisfy { CharacterSet.whitespaces.contains($0) }
    }

    private func makeDrawableTextClusterLine(
        _ cluster: String,
        attributes: [NSAttributedString.Key: Any]
    ) -> CTLine? {
        guard isDrawableTextCluster(cluster) else { return nil }
        return makeTextRunClusterLine(cluster, attributes: attributes)
    }

    private func makeTextRunClusterLine(
        _ cluster: String,
        attributes: [NSAttributedString.Key: Any]
    ) -> CTLine {
        let attrStr = NSAttributedString(string: cluster, attributes: attributes)
        return CTLineCreateWithAttributedString(attrStr)
    }

    private func measureTextRunClusterWidth(
        _ line: CTLine
    ) -> CGFloat {
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
        return width.isFinite ? max(0, width) : 0
    }

    private func textRunClusterBaseWidth(
        _ cluster: String,
        measuredWidth: CGFloat,
        style: TextStyle
    ) -> CGFloat {
        let fontSize = CGFloat(style.fontSize > 0 ? style.fontSize : 12)
        let ratio = CGFloat(style.ratio > 0 ? style.ratio : 1)
        let halfWidth = fontSize * 0.5 * ratio

        if cluster == "\u{2007}" {
            return halfWidth
        }
        if isReferenceWideCluster(cluster) {
            return fontSize * ratio
        }
        if measuredWidth > 0 {
            return max(measuredWidth, halfWidth)
        }
        return halfWidth
    }

    private func isReferenceWideCluster(_ cluster: String) -> Bool {
        if isHangulJamoCluster(cluster) {
            return true
        }
        guard cluster.unicodeScalars.count == 1,
              let scalar = cluster.unicodeScalars.first else {
            return false
        }
        return isCJKScalar(scalar) || isFullwidthSymbolScalar(scalar)
    }

    private func isHangulJamoCluster(_ cluster: String) -> Bool {
        let scalars = Array(cluster.unicodeScalars)
        guard scalars.count > 1, let first = scalars.first, isHangulChoseong(first) else {
            return false
        }
        guard scalars.count > 1, isHangulJungseong(scalars[1]) else {
            return false
        }
        return scalars.count == 2 || (scalars.count == 3 && isHangulJongseong(scalars[2]))
    }

    private func isHangulChoseong(_ scalar: Unicode.Scalar) -> Bool {
        (0x1100...0x115F).contains(Int(scalar.value)) || (0xA960...0xA97F).contains(Int(scalar.value))
    }

    private func isHangulJungseong(_ scalar: Unicode.Scalar) -> Bool {
        (0x1160...0x11A7).contains(Int(scalar.value)) || (0xD7B0...0xD7C6).contains(Int(scalar.value))
    }

    private func isHangulJongseong(_ scalar: Unicode.Scalar) -> Bool {
        (0x11A8...0x11FF).contains(Int(scalar.value)) || (0xD7CB...0xD7FB).contains(Int(scalar.value))
    }

    private func isCJKScalar(_ scalar: Unicode.Scalar) -> Bool {
        let value = Int(scalar.value)
        return (0x1100...0x11FF).contains(value)
            || (0x3130...0x318F).contains(value)
            || (0xAC00...0xD7AF).contains(value)
            || (0xA960...0xA97F).contains(value)
            || (0xD7B0...0xD7FF).contains(value)
            || (0x4E00...0x9FFF).contains(value)
            || (0x3400...0x4DBF).contains(value)
            || (0xF900...0xFAFF).contains(value)
            || (0x3040...0x30FF).contains(value)
            || (0xFF00...0xFFEF).contains(value)
    }

    private func isFullwidthSymbolScalar(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x20A9, 0x20AC, 0x00A3, 0x00A5, 0x00A7, 0x00B6,
             0x203B, 0x3003, 0x3012, 0x301C, 0x3030, 0x303B:
            return true
        default:
            return false
        }
    }

    private func drawTextClusters(
        _ clusters: [TextRunCluster],
        style: TextStyle,
        attributes: [NSAttributedString.Key: Any],
        y: CGFloat,
        in ctx: CGContext
    ) {
        for cluster in clusters where isDrawableTextCluster(cluster.text) {
            drawTextCluster(cluster, style: style, attributes: attributes, y: y, in: ctx)
        }
    }

    private func drawTextCluster(
        _ cluster: TextRunCluster,
        style: TextStyle,
        attributes: [NSAttributedString.Key: Any],
        y: CGFloat,
        in ctx: CGContext
    ) {
        let line = cluster.line ?? makeTextRunClusterLine(cluster.text, attributes: attributes)

        if needsHalfwidthPunctuationScale(cluster.text, style: style) {
            ctx.saveGState()
            ctx.translateBy(x: cluster.x, y: y)
            ctx.scaleBy(x: 0.5, y: 1)
            ctx.textPosition = .zero
            CTLineDraw(line, ctx)
            ctx.restoreGState()
        } else {
            ctx.textPosition = CGPoint(x: cluster.x, y: y)
            CTLineDraw(line, ctx)
        }
    }

    private func isDrawableTextCluster(_ cluster: String) -> Bool {
        if cluster == " " || cluster == "\t" || cluster == "\u{2007}" {
            return false
        }
        guard let first = cluster.unicodeScalars.first else {
            return false
        }
        if first.value < 0x20 && first.value != 0x09 && first.value != 0x0A && first.value != 0x0D {
            return false
        }
        return true
    }

    private func needsHalfwidthPunctuationScale(_ cluster: String, style: TextStyle) -> Bool {
        let ratio = style.ratio > 0 ? style.ratio : 1
        guard abs(ratio - 1) <= 0.01 else {
            return false
        }
        guard cluster.unicodeScalars.count == 1,
              let scalar = cluster.unicodeScalars.first else {
            return false
        }
        return (0x2018...0x2027).contains(Int(scalar.value)) || scalar.value == 0x00B7
    }

    /// 각주/미주 마커 (위첨자)
    private func renderFootnoteMarker(_ marker: FootnoteMarkerNode, bbox: BBox, in ctx: CGContext) {
        let fontSize = CGFloat(marker.baseFontSize * 0.55) // 위첨자 55%
        guard fontSize > 0 else { return }

        ctx.saveGState()
        ctx.translateBy(x: CGFloat(bbox.x), y: CGFloat(bbox.y + bbox.height))
        ctx.scaleBy(x: 1, y: -1)

        let font = resolveAppleFont(
            hwpFontFamily: marker.fontFamily,
            bold: false,
            italic: false,
            size: fontSize
        )
        let attributes: [NSAttributedString.Key: Any] = [
            coreTextFontKey: font,
            coreTextForegroundColorKey: colorRefToCGColor(marker.color),
        ]
        let attrStr = NSAttributedString(string: marker.text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attrStr)
        ctx.textPosition = CGPoint(x: 0, y: CGFloat(bbox.height) * 0.6)
        CTLineDraw(line, ctx)

        ctx.restoreGState()
    }

    /// 밑줄/취소선 그리기
    private func drawTextDecoration(in ctx: CGContext, x: CGFloat, y: CGFloat, width: CGFloat,
                                     shape: UInt8, color: UInt32) {
        ctx.saveGState()
        ctx.setStrokeColor(colorRefToCGColor(color))
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: x, y: y))
        ctx.addLine(to: CGPoint(x: x + width, y: y))
        ctx.strokePath()
        ctx.restoreGState()
    }

    // MARK: - 스타일 적용 헬퍼

    private func applyShapeStyleFill(_ style: ShapeStyle, path: CGPath, in ctx: CGContext) {
        if let pattern = style.pattern {
            // 패턴 채우기 (M3에서 정확한 패턴 구현)
            if let bgColor = UInt32(exactly: pattern.backgroundColor) {
                ctx.addPath(path)
                ctx.setFillColor(colorRefToCGColor(bgColor))
                ctx.fillPath()
            }
        } else if let fillColor = style.fillColor {
            ctx.addPath(path)
            ctx.setAlpha(CGFloat(style.opacity))
            ctx.setFillColor(colorRefToCGColor(fillColor))
            ctx.fillPath()
            ctx.setAlpha(1.0)
        }
    }

    private func applyShapeStyleStroke(_ style: ShapeStyle, path: CGPath, in ctx: CGContext) {
        if let strokeColor = style.strokeColor, style.strokeWidth > 0 {
            ctx.addPath(path)
            ctx.setStrokeColor(colorRefToCGColor(strokeColor))
            ctx.setLineWidth(CGFloat(max(style.strokeWidth, 0.5)))
            applyDash(style.strokeDash, in: ctx)
            ctx.strokePath()
        }
    }

    private func applyDash(_ dash: String, in ctx: CGContext) {
        switch dash {
        case "Dash":
            ctx.setLineDash(phase: 0, lengths: [6, 3])
        case "Dot":
            ctx.setLineDash(phase: 0, lengths: [2, 2])
        case "DashDot":
            ctx.setLineDash(phase: 0, lengths: [6, 3, 2, 3])
        case "DashDotDot":
            ctx.setLineDash(phase: 0, lengths: [6, 3, 2, 3, 2, 3])
        default: // Solid
            ctx.setLineDash(phase: 0, lengths: [])
        }
    }

    private func applyTransform(_ transform: ShapeTransform, bbox: BBox, in ctx: CGContext) {
        guard transform.rotation != 0 || transform.horzFlip || transform.vertFlip else { return }
        let cx = CGFloat(bbox.x + bbox.width / 2)
        let cy = CGFloat(bbox.y + bbox.height / 2)
        ctx.translateBy(x: cx, y: cy)
        if transform.rotation != 0 {
            ctx.rotate(by: CGFloat(transform.rotation * .pi / 180))
        }
        if transform.horzFlip { ctx.scaleBy(x: -1, y: 1) }
        if transform.vertFlip { ctx.scaleBy(x: 1, y: -1) }
        ctx.translateBy(x: -cx, y: -cy)
    }

    // MARK: - 그라데이션

    private func drawGradient(_ info: GradientFillInfo, in rect: CGRect, ctx: CGContext) {
        guard info.colors.count >= 2 else { return }
        let cgColors = info.colors.map { colorRefToCGColor($0) }
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: cgColors as CFArray,
                                        locations: info.positions.map { CGFloat($0) }) else { return }

        switch info.gradientType {
        case 1: // 선형
            let angle = CGFloat(info.angle) * .pi / 180
            let dx = cos(angle) * rect.width / 2
            let dy = sin(angle) * rect.height / 2
            let center = CGPoint(x: rect.midX, y: rect.midY)
            ctx.drawLinearGradient(gradient,
                start: CGPoint(x: center.x - dx, y: center.y - dy),
                end: CGPoint(x: center.x + dx, y: center.y + dy),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        case 2: // 원형
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = max(rect.width, rect.height) / 2
            ctx.drawRadialGradient(gradient,
                startCenter: center, startRadius: 0,
                endCenter: center, endRadius: radius,
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        default:
            // 원뿔형/사각형 등은 선형으로 근사
            ctx.drawLinearGradient(gradient,
                start: CGPoint(x: rect.minX, y: rect.minY),
                end: CGPoint(x: rect.maxX, y: rect.maxY),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
    }

    // MARK: - 색상 변환

    /// HWP ColorRef (0x00BBGGRR) → CGColor
    private func colorRefToCGColor(_ ref: UInt32) -> CGColor {
        let r = CGFloat(ref & 0xFF) / 255.0
        let g = CGFloat((ref >> 8) & 0xFF) / 255.0
        let b = CGFloat((ref >> 16) & 0xFF) / 255.0
        return CGColor(red: r, green: g, blue: b, alpha: 1.0)
    }

    private var coreTextForegroundColorKey: NSAttributedString.Key {
        NSAttributedString.Key(kCTForegroundColorAttributeName as String)
    }

    private var coreTextFontKey: NSAttributedString.Key {
        NSAttributedString.Key(kCTFontAttributeName as String)
    }

    private var coreTextKernKey: NSAttributedString.Key {
        NSAttributedString.Key(kCTKernAttributeName as String)
    }

    private func cgRect(_ bbox: BBox) -> CGRect {
        CGRect(x: bbox.x, y: bbox.y, width: bbox.width, height: bbox.height)
    }
}

private struct TextRunLayoutPlan {
    let clusterPlan: TextRunClusterPlan?
    let strategy: TextRunDrawStrategy
}

private struct TextRunSpacingEstimate {
    let tabCount: Int
    let extraCharWidth: CGFloat
    let extraWordWidth: CGFloat

    var requiresClusterDrawing: Bool {
        tabCount > 0 || abs(extraCharWidth) > 0.001 || abs(extraWordWidth) > 0.001
    }
}

private enum TextRunDrawStrategy {
    case line
    case scaledLine(CGFloat)
    case clusters
}

private struct TextRunClusterPlan {
    let clusters: [TextRunCluster]
}

private struct TextRunCluster {
    let text: String
    let x: CGFloat
    let line: CTLine?
}

private struct TextRunClusterMetric {
    let text: String
    let baseAdvance: CGFloat
    let line: CTLine?
}

private struct TextRunClusterSpan {
    let text: String
    let scalarStart: Int
    let scalarEnd: Int
}

private struct TextRunTabStop {
    let position: CGFloat
    let tabType: UInt16
    let fillType: UInt8
}

private enum EquationSVGDrawItem {
    case text(EquationSVGText)
    case line(EquationSVGLine)
    case path(EquationSVGPath)
}

private struct EquationSVGText {
    let text: String
    let x: Double
    let y: Double
    let fontSize: Double
    let fill: EquationSVGPaint?
    let fontFamily: String?
    let fontStyle: String?
    let textAnchor: EquationSVGTextAnchor
}

private struct EquationSVGLine {
    let x1: Double
    let y1: Double
    let x2: Double
    let y2: Double
    let stroke: EquationSVGPaint?
    let strokeWidth: Double
}

private struct EquationSVGPath {
    let commands: [EquationSVGPathCommand]
    let fill: EquationSVGPaint?
    let stroke: EquationSVGPaint?
    let strokeWidth: Double
}

private enum EquationSVGPathCommand {
    case moveTo(Double, Double)
    case lineTo(Double, Double)
    case quadCurveTo(Double, Double, Double, Double)
    case closePath
}

private enum EquationSVGPaint: Equatable {
    case none
    case color(EquationSVGColor)
}

private struct EquationSVGColor: Equatable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat
}

private enum EquationSVGTextAnchor {
    case start
    case middle
    case end
}

private final class EquationSVGFragmentParser: NSObject, XMLParserDelegate {
    private struct PendingText {
        let x: Double
        let y: Double
        let fontSize: Double
        let fill: EquationSVGPaint?
        let fontFamily: String?
        let fontStyle: String?
        let textAnchor: EquationSVGTextAnchor
        var content: String
    }

    private var items: [EquationSVGDrawItem] = []
    private var pendingText: PendingText?

    static func parse(_ fragment: String) -> [EquationSVGDrawItem] {
        guard let data = "<root>\(fragment)</root>".data(using: .utf8) else {
            return []
        }
        let delegate = EquationSVGFragmentParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = false
        parser.shouldResolveExternalEntities = false
        _ = parser.parse()
        return delegate.items
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String]
    ) {
        switch elementName.lowercased() {
        case "text":
            pendingText = PendingText(
                x: Self.doubleAttribute("x", in: attributeDict) ?? 0,
                y: Self.doubleAttribute("y", in: attributeDict) ?? 0,
                fontSize: Self.doubleAttribute("font-size", in: attributeDict) ?? 0,
                fill: Self.paintAttribute("fill", in: attributeDict),
                fontFamily: attributeDict["font-family"],
                fontStyle: attributeDict["font-style"],
                textAnchor: Self.textAnchorAttribute("text-anchor", in: attributeDict),
                content: ""
            )
        case "line":
            guard let x1 = Self.doubleAttribute("x1", in: attributeDict),
                  let y1 = Self.doubleAttribute("y1", in: attributeDict),
                  let x2 = Self.doubleAttribute("x2", in: attributeDict),
                  let y2 = Self.doubleAttribute("y2", in: attributeDict) else { return }
            items.append(.line(EquationSVGLine(
                x1: x1,
                y1: y1,
                x2: x2,
                y2: y2,
                stroke: Self.paintAttribute("stroke", in: attributeDict),
                strokeWidth: Self.doubleAttribute("stroke-width", in: attributeDict) ?? 1
            )))
        case "path":
            guard let pathData = attributeDict["d"] else { return }
            let commands = Self.pathCommands(from: pathData)
            guard !commands.isEmpty else { return }
            items.append(.path(EquationSVGPath(
                commands: commands,
                fill: Self.paintAttribute("fill", in: attributeDict),
                stroke: Self.paintAttribute("stroke", in: attributeDict),
                strokeWidth: Self.doubleAttribute("stroke-width", in: attributeDict) ?? 1
            )))
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        pendingText?.content += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard elementName.lowercased() == "text", let text = pendingText else { return }
        items.append(.text(EquationSVGText(
            text: text.content,
            x: text.x,
            y: text.y,
            fontSize: text.fontSize,
            fill: text.fill,
            fontFamily: text.fontFamily,
            fontStyle: text.fontStyle,
            textAnchor: text.textAnchor
        )))
        pendingText = nil
    }

    private static func doubleAttribute(_ name: String, in attributes: [String: String]) -> Double? {
        guard let value = attributes[name]?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return nil
        }
        return Double(value)
    }

    private static func paintAttribute(_ name: String, in attributes: [String: String]) -> EquationSVGPaint? {
        guard let value = attributes[name]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        if value.lowercased() == "none" {
            return EquationSVGPaint.none
        }
        guard value.hasPrefix("#") else {
            return nil
        }
        let hex = String(value.dropFirst())
        guard hex.count == 6, let rgb = UInt32(hex, radix: 16) else {
            return nil
        }
        return .color(EquationSVGColor(
            red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
            green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
            blue: CGFloat(rgb & 0xFF) / 255.0,
            alpha: 1.0
        ))
    }

    private static func textAnchorAttribute(
        _ name: String,
        in attributes: [String: String]
    ) -> EquationSVGTextAnchor {
        switch attributes[name]?.lowercased() {
        case "middle":
            return .middle
        case "end":
            return .end
        default:
            return .start
        }
    }

    private static func pathCommands(from data: String) -> [EquationSVGPathCommand] {
        let tokens = pathTokens(from: data)
        var commands: [EquationSVGPathCommand] = []
        var index = 0
        var currentCommand: String?
        var currentPoint = (x: 0.0, y: 0.0)

        while index < tokens.count {
            let token = tokens[index]
            if isPathCommand(token) {
                currentCommand = token
                index += 1
                if token.uppercased() == "Z" {
                    commands.append(.closePath)
                }
                continue
            }

            guard let command = currentCommand?.uppercased() else {
                index += 1
                continue
            }
            let isRelative = currentCommand?.first?.isLowercase == true

            switch command {
            case "M", "L":
                guard index + 1 < tokens.count,
                      var x = Double(tokens[index]),
                      var y = Double(tokens[index + 1]) else {
                    index += 1
                    continue
                }
                if isRelative {
                    x += currentPoint.x
                    y += currentPoint.y
                }
                if command == "M" {
                    commands.append(.moveTo(x, y))
                    currentCommand = isRelative ? "l" : "L"
                } else {
                    commands.append(.lineTo(x, y))
                }
                currentPoint = (x, y)
                index += 2
            case "H":
                guard var x = Double(token) else {
                    index += 1
                    continue
                }
                if isRelative {
                    x += currentPoint.x
                }
                currentPoint.x = x
                commands.append(.lineTo(currentPoint.x, currentPoint.y))
                index += 1
            case "V":
                guard var y = Double(token) else {
                    index += 1
                    continue
                }
                if isRelative {
                    y += currentPoint.y
                }
                currentPoint.y = y
                commands.append(.lineTo(currentPoint.x, currentPoint.y))
                index += 1
            case "Q":
                guard index + 3 < tokens.count,
                      var cx = Double(tokens[index]),
                      var cy = Double(tokens[index + 1]),
                      var x = Double(tokens[index + 2]),
                      var y = Double(tokens[index + 3]) else {
                    index += 1
                    continue
                }
                if isRelative {
                    cx += currentPoint.x
                    cy += currentPoint.y
                    x += currentPoint.x
                    y += currentPoint.y
                }
                commands.append(.quadCurveTo(cx, cy, x, y))
                currentPoint = (x, y)
                index += 4
            default:
                index += 1
            }
        }

        return commands
    }

    private static func pathTokens(from data: String) -> [String] {
        var tokens: [String] = []
        var current = ""

        func flushCurrent() {
            if !current.isEmpty {
                tokens.append(current)
                current = ""
            }
        }

        for scalar in data.unicodeScalars {
            if isPathCommand(scalar) {
                flushCurrent()
                tokens.append(String(scalar))
            } else if isPathNumberScalar(scalar) {
                current.unicodeScalars.append(scalar)
            } else {
                flushCurrent()
            }
        }
        flushCurrent()
        return tokens
    }

    private static func isPathCommand(_ token: String) -> Bool {
        token.count == 1 && token.unicodeScalars.first.map(isPathCommand) == true
    }

    private static func isPathCommand(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar {
        case "M", "m", "L", "l", "H", "h", "V", "v", "Q", "q", "Z", "z":
            return true
        default:
            return false
        }
    }

    private static func isPathNumberScalar(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar {
        case "0"..."9", ".", "-", "+", "e", "E":
            return true
        default:
            return false
        }
    }
}
