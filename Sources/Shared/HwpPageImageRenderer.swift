import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let hwpQuickLookMaxFileSize = 50 * 1024 * 1024

struct HwpRenderedPage: @unchecked Sendable {
    let image: CGImage
    let size: CGSize
}

enum HwpEmbeddedThumbnailPolicy {
    case never
    case smallFinderThumbnail(maxPixelDimension: CGFloat)
}

enum HwpRenderError: Error {
    case fileTooLarge
    case emptyDocument
    case renderTreeUnavailable
    case invalidPageSize
    case bitmapContextUnavailable
    case imageUnavailable
    case pngEncodingFailed
}

enum HwpPageImageRenderer {
    static func renderFirstPage(fileURL: URL) throws -> HwpRenderedPage {
        try renderFirstPage(fileURL: fileURL, maximumPixelSize: nil, embeddedThumbnailPolicy: .never)
    }

    static func renderFirstPage(
        fileURL: URL,
        maximumPixelSize: CGSize?,
        embeddedThumbnailPolicy: HwpEmbeddedThumbnailPolicy = .never
    ) throws -> HwpRenderedPage {
        let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])
        let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
        if let embedded = decodeEmbeddedThumbnail(
            from: data,
            maximumPixelSize: maximumPixelSize,
            policy: embeddedThumbnailPolicy
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
        guard let tree = document.renderPageTree(at: 0) else {
            throw HwpRenderError.renderTreeUnavailable
        }

        let pageSize = document.pageSize(at: 0)
        guard pageSize.width > 0, pageSize.height > 0 else {
            throw HwpRenderError.invalidPageSize
        }

        let renderScale = renderScale(
            pageSize: CGSize(width: pageSize.width, height: pageSize.height),
            maximumPixelSize: maximumPixelSize
        )
        let width = max(1, Int(ceil(pageSize.width * renderScale)))
        let height = max(1, Int(ceil(pageSize.height * renderScale)))
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 255, count: height * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw HwpRenderError.bitmapContextUnavailable
        }

        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: renderScale, y: -renderScale)

        let renderer = CGTreeRenderer()
        renderer.render(tree: tree, in: context, pageHeight: pageSize.height, document: document)

        guard let image = context.makeImage() else {
            throw HwpRenderError.imageUnavailable
        }

        return HwpRenderedPage(
            image: image,
            size: CGSize(width: pageSize.width, height: pageSize.height)
        )
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
        policy: HwpEmbeddedThumbnailPolicy
    ) -> HwpRenderedPage? {
        guard let thumbnail = RhwpDocument.extractEmbeddedThumbnail(from: data) else {
            return nil
        }
        guard let source = CGImageSourceCreateWithData(thumbnail.data as CFData, nil) else {
            return nil
        }

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

        guard let image else {
            return nil
        }

        guard shouldUseEmbeddedThumbnail(
            requestPixelSize: maximumPixelSize,
            policy: policy
        ) else {
            return nil
        }

        let width = thumbnail.width > 0 ? thumbnail.width : image.width
        let height = thumbnail.height > 0 ? thumbnail.height : image.height
        return HwpRenderedPage(
            image: image,
            size: CGSize(width: width, height: height)
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
}
