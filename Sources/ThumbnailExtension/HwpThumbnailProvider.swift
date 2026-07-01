import CoreGraphics
import Foundation
import OSLog
import QuickLookThumbnailing

final class HwpThumbnailProvider: QLThumbnailProvider {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.postmelee.alhangeul.ThumbnailExtension",
        category: "ThumbnailProvider"
    )

    override func provideThumbnail(
        for request: QLFileThumbnailRequest,
        _ handler: @escaping (QLThumbnailReply?, Error?) -> Void
    ) {
        let policy = HwpThumbnailPolicyResolver.resolve()
        let policyID = HwpThumbnailPolicyResolver.identifier(for: policy)
        Self.logger.debug("Thumbnail requested file=\(request.fileURL.lastPathComponent, privacy: .public) policy=\(policyID, privacy: .public) max=\(Int(request.maximumSize.width), privacy: .public)x\(Int(request.maximumSize.height), privacy: .public) scale=\(request.scale, privacy: .public)")
        do {
            let renderRequest = try HwpThumbnailRenderRequest(
                fileURL: request.fileURL,
                maximumSize: request.maximumSize,
                scale: request.scale,
                policy: policy
            )
            Self.logger.debug("Thumbnail render enqueued file=\(request.fileURL.lastPathComponent, privacy: .public) policy=\(policyID, privacy: .public) pixels=\(Int(renderRequest.maximumPixelSize.width), privacy: .public)x\(Int(renderRequest.maximumPixelSize.height), privacy: .public)")
            HwpThumbnailRenderCache.shared.renderedPageResult(for: renderRequest) { result in
                switch result {
                case .success(let renderResult):
                    let renderedPage = renderResult.page
                    let diagnostics = renderedPage.diagnostics
                    let contextSize = Self.aspectFit(renderedPage.size, within: request.maximumSize)
                    let image = renderedPage.image
                    Self.logger.debug("Thumbnail ready file=\(request.fileURL.lastPathComponent, privacy: .public) policy=\(policyID, privacy: .public) cache=\(renderResult.cacheEvent.description, privacy: .public) requestedBucket=\(Self.bucketDescription(renderResult.requestedKey), privacy: .public) matchedBucket=\(Self.bucketDescription(renderResult.matchedKey), privacy: .public) backend=\(Self.backendDescription(diagnostics.backendUsed), privacy: .public) fallback=\(Self.fallbackDescription(diagnostics.fallbackReason), privacy: .public) renderMs=\(Self.durationDescription(diagnostics.durationMs.totalMs), privacy: .public) pixels=\(Self.sizeDescription(diagnostics.pixelSize), privacy: .public) context=\(Self.sizeDescription(contextSize), privacy: .public) page=\(Self.sizeDescription(renderedPage.size), privacy: .public)")
                    let reply = QLThumbnailReply(contextSize: contextSize) { context in
                        Self.drawPageImage(image, in: context, size: contextSize)
                        return true
                    }
                    reply.extensionBadge = request.fileURL.pathExtension.uppercased()
                    handler(reply, nil)

                case .failure(let error) where HwpDocumentFallbackClassifier.shouldUseThumbnailFallback(for: error):
                    Self.logger.warning("Thumbnail fallback file=\(request.fileURL.lastPathComponent, privacy: .public) policy=\(policyID, privacy: .public) error=\(Self.errorDescription(error), privacy: .public)")
                    handler(Self.fallbackReply(for: request), nil)

                case .failure(let error):
                    Self.logger.error("Thumbnail failed file=\(request.fileURL.lastPathComponent, privacy: .public) policy=\(policyID, privacy: .public) error=\(Self.errorDescription(error), privacy: .public)")
                    handler(nil, error)
                }
            }
        } catch {
            if HwpDocumentFallbackClassifier.shouldUseThumbnailFallback(for: error) {
                Self.logger.warning("Thumbnail fallback before render file=\(request.fileURL.lastPathComponent, privacy: .public) policy=\(policyID, privacy: .public) error=\(Self.errorDescription(error), privacy: .public)")
                handler(Self.fallbackReply(for: request), nil)
            } else {
                Self.logger.error("Thumbnail failed before render file=\(request.fileURL.lastPathComponent, privacy: .public) policy=\(policyID, privacy: .public) error=\(Self.errorDescription(error), privacy: .public)")
                handler(nil, error)
            }
        }
    }

    private static func fallbackReply(for request: QLFileThumbnailRequest) -> QLThumbnailReply {
        let reply = QLThumbnailReply(contextSize: request.maximumSize) { context in
            Self.drawFallback(in: context, size: request.maximumSize)
            return true
        }
        reply.extensionBadge = request.fileURL.pathExtension.uppercased()
        return reply
    }

    private static func aspectFit(_ source: CGSize, within maximumSize: CGSize) -> CGSize {
        guard source.width > 0, source.height > 0, maximumSize.width > 0, maximumSize.height > 0 else {
            return CGSize(width: 128, height: 128)
        }
        let scale = min(maximumSize.width / source.width, maximumSize.height / source.height)
        return CGSize(width: max(1, source.width * scale), height: max(1, source.height * scale))
    }

    private static func drawPageImage(_ image: CGImage, in context: CGContext, size: CGSize) {
        let rect = drawingBounds(in: context, fallbackSize: size)
        context.saveGState()
        context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        context.fill(rect)
        context.draw(image, in: rect)
        context.restoreGState()
    }

    private static func drawFallback(in context: CGContext, size: CGSize) {
        let rect = drawingBounds(in: context, fallbackSize: size)
        context.saveGState()
        context.setFillColor(red: 0.93, green: 0.93, blue: 0.93, alpha: 1)
        context.fill(rect)
        context.setStrokeColor(red: 0.55, green: 0.55, blue: 0.55, alpha: 1)
        context.setLineWidth(max(1, min(size.width, size.height) * 0.04))
        context.stroke(rect.insetBy(dx: 2, dy: 2))
        context.restoreGState()
    }

    private static func drawingBounds(in context: CGContext, fallbackSize: CGSize) -> CGRect {
        let clipBounds = context.boundingBoxOfClipPath
        guard
            !clipBounds.isNull,
            !clipBounds.isInfinite,
            clipBounds.width.isFinite,
            clipBounds.height.isFinite,
            clipBounds.width > 0,
            clipBounds.height > 0
        else {
            return CGRect(origin: .zero, size: fallbackSize)
        }
        return clipBounds
    }

    private static func bucketDescription(_ key: HwpThumbnailCacheKey) -> String {
        "\(key.pixelWidth)x\(key.pixelHeight)"
    }

    private static func backendDescription(_ backend: HwpPageRenderBackend) -> String {
        switch backend {
        case .coreGraphics:
            return "coreGraphics"
        case .skia:
            return "skia"
        case .embeddedThumbnail:
            return "embeddedThumbnail"
        }
    }

    private static func fallbackDescription(_ reason: HwpPageRenderFallbackReason?) -> String {
        guard let reason else {
            return "-"
        }

        switch reason {
        case .ffiUnavailable:
            return "ffiUnavailable"
        case .invalidDocumentHandle:
            return "invalidDocumentHandle"
        case .invalidPageIndex:
            return "invalidPageIndex"
        case .invalidRenderOptions:
            return "invalidRenderOptions"
        case .invalidPageSize:
            return "invalidPageSize"
        case .skiaRenderFailure:
            return "skiaRenderFailure"
        case .pngDecodeFailure:
            return "pngDecodeFailure"
        case .memoryTimeoutFallback:
            return "memoryTimeoutFallback"
        }
    }

    private static func durationDescription(_ milliseconds: Double) -> String {
        String(format: "%.2f", milliseconds)
    }

    private static func sizeDescription(_ size: CGSize) -> String {
        "\(Int(size.width))x\(Int(size.height))"
    }

    private static func errorDescription(_ error: Error) -> String {
        let nsError = error as NSError
        return "\(type(of: error))(domain=\(nsError.domain), code=\(nsError.code))"
    }
}
