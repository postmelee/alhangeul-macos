import Foundation

struct RhwpPageOverlayImageSet {
    let behind: [RhwpPageOverlayImage]
    let front: [RhwpPageOverlayImage]
    let imageCount: Int

    var overlayImageCount: Int {
        behind.count + front.count
    }

    var allImages: [RhwpPageOverlayImage] {
        behind + front
    }
}

enum RhwpPageOverlayLayer: String {
    case behindText
    case inFrontOfText

    init?(textWrap: String?) {
        guard let normalized = textWrap?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() else {
            return nil
        }
        switch normalized {
        case "behindtext", "behind_text", "behind-text":
            self = .behindText
        case "infrontoftext", "in_front_of_text", "in-front-of-text":
            self = .inFrontOfText
        default:
            return nil
        }
    }
}

struct RhwpPageOverlayImage {
    let layer: RhwpPageOverlayLayer
    let wrap: String
    let bbox: BBox
    let source: RhwpPageOverlayImageSource
    let effect: String
    let brightness: Int
    let contrast: Int
    let watermarkPreset: String?
    let bakedWatermark: Bool
    let transform: RhwpPageOverlayTransform
    let fillMode: String?
    let originalSize: [Double]?
    let originalSizeHU: [Double]?
    let crop: [Int32]?

    var hasRenderableData: Bool {
        source.hasRenderableData
    }

    fileprivate func applying(_ supplement: RhwpPageOverlayImageSupplement?) -> RhwpPageOverlayImage {
        guard let supplement else {
            return self
        }
        return RhwpPageOverlayImage(
            layer: layer,
            wrap: wrap,
            bbox: bbox,
            source: source.applying(supplement),
            effect: effect,
            brightness: brightness,
            contrast: contrast,
            watermarkPreset: watermarkPreset,
            bakedWatermark: bakedWatermark,
            transform: transform,
            fillMode: supplement.fillMode ?? fillMode,
            originalSize: supplement.originalSize ?? originalSize,
            originalSizeHU: supplement.originalSizeHU ?? originalSizeHU,
            crop: supplement.crop ?? crop
        )
    }
}

struct RhwpPageOverlayImageSource {
    let mime: String
    let data: Data?
    let base64Length: Int
    let binDataId: UInt16?
    let binDataAvailable: Bool?

    var byteCount: Int {
        data?.count ?? 0
    }

    var hasRenderableData: Bool {
        byteCount > 0 || binDataAvailable == true
    }

    fileprivate func applying(_ supplement: RhwpPageOverlayImageSupplement) -> RhwpPageOverlayImageSource {
        RhwpPageOverlayImageSource(
            mime: mime,
            data: data,
            base64Length: base64Length,
            binDataId: supplement.binDataId,
            binDataAvailable: supplement.binDataAvailable
        )
    }
}

struct RhwpPageOverlayTransform: Decodable, Equatable {
    let rotation: Double
    let horzFlip: Bool
    let vertFlip: Bool

    static let identity = RhwpPageOverlayTransform(rotation: 0, horzFlip: false, vertFlip: false)

    init(rotation: Double, horzFlip: Bool, vertFlip: Bool) {
        self.rotation = rotation
        self.horzFlip = horzFlip
        self.vertFlip = vertFlip
    }

    init(_ transform: ShapeTransform) {
        self.init(
            rotation: transform.rotation,
            horzFlip: transform.horzFlip,
            vertFlip: transform.vertFlip
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rotation = try container.decodeIfPresent(Double.self, forKey: .rotation) ?? 0
        horzFlip = try container.decodeIfPresent(Bool.self, forKey: .horzFlip)
            ?? container.decodeIfPresent(Bool.self, forKey: .horzFlipSnake)
            ?? false
        vertFlip = try container.decodeIfPresent(Bool.self, forKey: .vertFlip)
            ?? container.decodeIfPresent(Bool.self, forKey: .vertFlipSnake)
            ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case rotation
        case horzFlip
        case vertFlip
        case horzFlipSnake = "horz_flip"
        case vertFlipSnake = "vert_flip"
    }
}

extension RhwpDocument {
    func pageOverlayImages(at page: Int) -> RhwpPageOverlayImageSet? {
        guard page >= 0, page < pageCount else {
            return nil
        }

        let supplements = renderPageTree(at: page).map {
            collectPageOverlaySupplements(from: $0, document: self)
        } ?? []

        if let json = pageOverlayImagesJSON(at: page),
           let data = json.data(using: .utf8),
           let payload = try? JSONDecoder().decode(RhwpPageOverlayImageSetPayload.self, from: data) {
            return payload.model(merging: supplements)
        }

        guard !supplements.isEmpty else {
            return nil
        }
        return RhwpPageOverlayImageSet(
            behind: supplements
                .filter { $0.layer == .behindText }
                .map { $0.fallbackImage() },
            front: supplements
                .filter { $0.layer == .inFrontOfText }
                .map { $0.fallbackImage() },
            imageCount: supplements.count
        )
    }
}

private struct RhwpPageOverlayImageSetPayload: Decodable {
    let behind: [RhwpPageOverlayImagePayload]
    let front: [RhwpPageOverlayImagePayload]
    let imageCount: Int

    enum CodingKeys: String, CodingKey {
        case behind
        case front
        case imageCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        behind = try container.decodeIfPresent([RhwpPageOverlayImagePayload].self, forKey: .behind) ?? []
        front = try container.decodeIfPresent([RhwpPageOverlayImagePayload].self, forKey: .front) ?? []
        imageCount = try container.decodeIfPresent(Int.self, forKey: .imageCount) ?? (behind.count + front.count)
    }

    func model(merging supplements: [RhwpPageOverlayImageSupplement]) -> RhwpPageOverlayImageSet {
        var usedSupplementIndexes = Set<Int>()
        let behindImages = behind.map {
            $0.model(layer: .behindText)
                .applying(matchingSupplement(
                    for: $0.bbox,
                    layer: .behindText,
                    in: supplements,
                    used: &usedSupplementIndexes
                ))
        }
        let frontImages = front.map {
            $0.model(layer: .inFrontOfText)
                .applying(matchingSupplement(
                    for: $0.bbox,
                    layer: .inFrontOfText,
                    in: supplements,
                    used: &usedSupplementIndexes
                ))
        }
        return RhwpPageOverlayImageSet(
            behind: behindImages,
            front: frontImages,
            imageCount: imageCount
        )
    }
}

private struct RhwpPageOverlayImagePayload: Decodable {
    let bbox: BBox
    let mime: String?
    let base64: String?
    let effect: String?
    let brightness: Int?
    let contrast: Int?
    let watermark: RhwpPageOverlayWatermarkPayload?
    let bakedWatermark: Bool?
    let wrap: String?
    let transform: RhwpPageOverlayTransform?

    func model(layer: RhwpPageOverlayLayer) -> RhwpPageOverlayImage {
        let data = base64.flatMap { Data(base64Encoded: $0) }
        return RhwpPageOverlayImage(
            layer: layer,
            wrap: wrap ?? layer.rawValue,
            bbox: bbox,
            source: RhwpPageOverlayImageSource(
                mime: mime ?? "application/octet-stream",
                data: data,
                base64Length: base64?.count ?? 0,
                binDataId: nil,
                binDataAvailable: nil
            ),
            effect: effect ?? "realPic",
            brightness: brightness ?? 0,
            contrast: contrast ?? 0,
            watermarkPreset: watermark?.preset,
            bakedWatermark: bakedWatermark == true,
            transform: transform ?? .identity,
            fillMode: nil,
            originalSize: nil,
            originalSizeHU: nil,
            crop: nil
        )
    }
}

private struct RhwpPageOverlayWatermarkPayload: Decodable {
    let preset: String?
}

private struct RhwpPageOverlayImageSupplement {
    let layer: RhwpPageOverlayLayer
    let bbox: BBox
    let binDataId: UInt16
    let binDataAvailable: Bool
    let effect: String?
    let brightness: Int?
    let contrast: Int?
    let transform: RhwpPageOverlayTransform
    let fillMode: String?
    let originalSize: [Double]?
    let originalSizeHU: [Double]?
    let crop: [Int32]?

    func fallbackImage() -> RhwpPageOverlayImage {
        RhwpPageOverlayImage(
            layer: layer,
            wrap: layer.rawValue,
            bbox: bbox,
            source: RhwpPageOverlayImageSource(
                mime: "application/octet-stream",
                data: nil,
                base64Length: 0,
                binDataId: binDataId,
                binDataAvailable: binDataAvailable
            ),
            effect: effect ?? "realPic",
            brightness: brightness ?? 0,
            contrast: contrast ?? 0,
            watermarkPreset: nil,
            bakedWatermark: false,
            transform: transform,
            fillMode: fillMode,
            originalSize: originalSize,
            originalSizeHU: originalSizeHU,
            crop: crop
        )
    }
}

private func collectPageOverlaySupplements(
    from root: RenderNode,
    document: RhwpDocument
) -> [RhwpPageOverlayImageSupplement] {
    var supplements: [RhwpPageOverlayImageSupplement] = []

    func visit(_ node: RenderNode) {
        if case .image(let image) = node.nodeType,
           let layer = RhwpPageOverlayLayer(textWrap: image.textWrap) {
            supplements.append(
                RhwpPageOverlayImageSupplement(
                    layer: layer,
                    bbox: node.bbox,
                    binDataId: image.binDataId,
                    binDataAvailable: image.binDataId > 0 && document.imageData(binDataId: image.binDataId) != nil,
                    effect: image.effect,
                    brightness: image.brightness,
                    contrast: image.contrast,
                    transform: RhwpPageOverlayTransform(image.transform),
                    fillMode: image.fillMode,
                    originalSize: image.originalSize,
                    originalSizeHU: image.originalSizeHU,
                    crop: image.crop
                )
            )
        }

        for child in node.children {
            visit(child)
        }
    }

    visit(root)
    return supplements
}

private func matchingSupplement(
    for bbox: BBox,
    layer: RhwpPageOverlayLayer,
    in supplements: [RhwpPageOverlayImageSupplement],
    used: inout Set<Int>
) -> RhwpPageOverlayImageSupplement? {
    guard let index = supplements.indices.first(where: { index in
        !used.contains(index)
            && supplements[index].layer == layer
            && bboxApproximatelyEqual(bbox, supplements[index].bbox)
    }) else {
        return nil
    }
    used.insert(index)
    return supplements[index]
}

private func bboxApproximatelyEqual(_ lhs: BBox, _ rhs: BBox) -> Bool {
    let tolerance = 0.75
    return abs(lhs.x - rhs.x) <= tolerance
        && abs(lhs.y - rhs.y) <= tolerance
        && abs(lhs.width - rhs.width) <= tolerance
        && abs(lhs.height - rhs.height) <= tolerance
}
