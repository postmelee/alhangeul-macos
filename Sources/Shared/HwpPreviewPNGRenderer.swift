import CoreGraphics
import Foundation

enum HwpPreviewPNGReplyMode: Equatable {
    case coreGraphics
    case skiaDecode
    case skiaDirect

    var identifier: String {
        switch self {
        case .coreGraphics:
            return "coreGraphics"
        case .skiaDecode:
            return "skiaDecode"
        case .skiaDirect:
            return "skiaDirect"
        }
    }
}

struct HwpPreviewPNGDuration {
    let skiaRenderMs: Double?
    let pngHeaderValidateMs: Double?
    let pngDecodeMs: Double?
    let pngEncodeMs: Double?
    let coreGraphicsRenderMs: Double?
    let totalMs: Double
}

struct HwpPreviewPNGDiagnostics {
    let requestedMode: HwpPreviewPNGReplyMode
    let outputMode: HwpPreviewPNGReplyMode
    let backendUsed: HwpPageRenderBackend
    let fallbackReason: String?
    let outputBytes: Int
    let skiaPNGBytes: Int?
    let pngPixelSize: CGSize?
    let durationMs: HwpPreviewPNGDuration
}

struct HwpRenderedPreviewPNG {
    let data: Data
    let contentSize: CGSize
    let diagnostics: HwpPreviewPNGDiagnostics
}

enum HwpPreviewPNGRenderer {
    static func render(
        context: HwpPreviewDocumentContext,
        mode: HwpPreviewPNGReplyMode = .coreGraphics
    ) throws -> HwpRenderedPreviewPNG {
        guard context.pageCount == 1 else {
            throw HwpRenderError.pageOutOfRange
        }

        switch mode {
        case .coreGraphics:
            return try renderEncodedPage(
                context: context,
                requestedMode: mode,
                policy: .coreGraphicsOnly
            )
        case .skiaDecode:
            return try renderEncodedPage(
                context: context,
                requestedMode: mode,
                policy: .skiaOptIn
            )
        case .skiaDirect:
            return try renderDirectSkiaPNG(context: context)
        }
    }

    private static func renderDirectSkiaPNG(
        context: HwpPreviewDocumentContext
    ) throws -> HwpRenderedPreviewPNG {
        let skiaStart = DispatchTime.now().uptimeNanoseconds
        let png = context.document.renderPagePNG(
            at: 0,
            scale: 1,
            maxDimension: 0
        )
        let skiaRenderMs = elapsedMilliseconds(since: skiaStart)

        guard png.status == .ok, png.byteCount > 0 else {
            return try renderEncodedPage(
                context: context,
                requestedMode: .skiaDirect,
                policy: .coreGraphicsOnly,
                fallbackReason: directFallbackReason(for: png.status),
                skiaRenderMs: skiaRenderMs,
                skiaPNGBytes: png.byteCount > 0 ? png.byteCount : nil
            )
        }

        let validateStart = DispatchTime.now().uptimeNanoseconds
        guard let pixelSize = pngPixelSize(from: png.data) else {
            let validateMs = elapsedMilliseconds(since: validateStart)
            return try renderEncodedPage(
                context: context,
                requestedMode: .skiaDirect,
                policy: .coreGraphicsOnly,
                fallbackReason: "invalidPNGHeader",
                skiaRenderMs: skiaRenderMs,
                pngHeaderValidateMs: validateMs,
                skiaPNGBytes: png.byteCount
            )
        }
        let validateMs = elapsedMilliseconds(since: validateStart)

        return HwpRenderedPreviewPNG(
            data: png.data,
            contentSize: context.contentSize,
            diagnostics: HwpPreviewPNGDiagnostics(
                requestedMode: .skiaDirect,
                outputMode: .skiaDirect,
                backendUsed: .skia,
                fallbackReason: nil,
                outputBytes: png.byteCount,
                skiaPNGBytes: png.byteCount,
                pngPixelSize: pixelSize,
                durationMs: HwpPreviewPNGDuration(
                    skiaRenderMs: skiaRenderMs,
                    pngHeaderValidateMs: validateMs,
                    pngDecodeMs: nil,
                    pngEncodeMs: nil,
                    coreGraphicsRenderMs: nil,
                    totalMs: skiaRenderMs + validateMs
                )
            )
        )
    }

    private static func renderEncodedPage(
        context: HwpPreviewDocumentContext,
        requestedMode: HwpPreviewPNGReplyMode,
        policy: HwpPageRenderPolicy,
        fallbackReason: String? = nil,
        skiaRenderMs: Double? = nil,
        pngHeaderValidateMs: Double? = nil,
        skiaPNGBytes: Int? = nil
    ) throws -> HwpRenderedPreviewPNG {
        let page = try HwpPageImageRenderer.renderPage(
            document: context.document,
            pageIndex: 0,
            policy: policy
        )

        let encodeStart = DispatchTime.now().uptimeNanoseconds
        let data = try HwpPageImageRenderer.encodePNG(page.image)
        let encodeMs = elapsedMilliseconds(since: encodeStart)

        let renderDiagnostics = page.diagnostics
        let outputMode = encodedOutputMode(
            requestedMode: requestedMode,
            diagnostics: renderDiagnostics
        )
        let externalSkiaRenderMs = skiaRenderMs
        let resolvedSkiaRenderMs = skiaRenderMs ?? renderDiagnostics.durationMs.skiaRenderMs
        let resolvedFallback = fallbackReason ?? renderDiagnostics.fallbackReason.map { String(describing: $0) }
        let totalMs = (externalSkiaRenderMs ?? 0)
            + (pngHeaderValidateMs ?? 0)
            + renderDiagnostics.durationMs.totalMs
            + encodeMs

        return HwpRenderedPreviewPNG(
            data: data,
            contentSize: context.contentSize,
            diagnostics: HwpPreviewPNGDiagnostics(
                requestedMode: requestedMode,
                outputMode: outputMode,
                backendUsed: renderDiagnostics.backendUsed,
                fallbackReason: resolvedFallback,
                outputBytes: data.count,
                skiaPNGBytes: skiaPNGBytes ?? renderDiagnostics.pngBytes,
                pngPixelSize: renderDiagnostics.pixelSize,
                durationMs: HwpPreviewPNGDuration(
                    skiaRenderMs: resolvedSkiaRenderMs,
                    pngHeaderValidateMs: pngHeaderValidateMs,
                    pngDecodeMs: renderDiagnostics.durationMs.pngDecodeMs,
                    pngEncodeMs: encodeMs,
                    coreGraphicsRenderMs: renderDiagnostics.durationMs.coreGraphicsRenderMs,
                    totalMs: totalMs
                )
            )
        )
    }

    private static func encodedOutputMode(
        requestedMode: HwpPreviewPNGReplyMode,
        diagnostics: HwpPageRenderDiagnostics
    ) -> HwpPreviewPNGReplyMode {
        if requestedMode == .skiaDirect {
            return .coreGraphics
        }
        if requestedMode == .skiaDecode, diagnostics.backendUsed == .skia {
            return .skiaDecode
        }
        return .coreGraphics
    }

    private static func directFallbackReason(for status: RhwpPagePNGStatus) -> String {
        switch status {
        case .ok:
            return "skiaRenderFailure"
        case .invalidHandle:
            return "invalidDocumentHandle"
        case .invalidOutput:
            return "ffiUnavailable"
        case .invalidPageIndex:
            return "invalidPageIndex"
        case .invalidOptions:
            return "invalidRenderOptions"
        case .failure:
            return "skiaRenderFailure"
        }
    }

    private static func pngPixelSize(from data: Data) -> CGSize? {
        data.withUnsafeBytes { rawBuffer -> CGSize? in
            let bytes = rawBuffer.bindMemory(to: UInt8.self)
            guard bytes.count >= 33 else {
                return nil
            }

            let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
            for (index, expectedByte) in signature.enumerated() where bytes[index] != expectedByte {
                return nil
            }

            let ihdrLength = readUInt32BE(bytes, offset: 8)
            guard
                ihdrLength == 13,
                bytes[12] == 0x49,
                bytes[13] == 0x48,
                bytes[14] == 0x44,
                bytes[15] == 0x52
            else {
                return nil
            }

            let width = readUInt32BE(bytes, offset: 16)
            let height = readUInt32BE(bytes, offset: 20)
            guard width > 0, height > 0 else {
                return nil
            }

            return CGSize(width: CGFloat(width), height: CGFloat(height))
        }
    }

    private static func readUInt32BE(
        _ bytes: UnsafeBufferPointer<UInt8>,
        offset: Int
    ) -> UInt32 {
        (UInt32(bytes[offset]) << 24)
            | (UInt32(bytes[offset + 1]) << 16)
            | (UInt32(bytes[offset + 2]) << 8)
            | UInt32(bytes[offset + 3])
    }

    private static func elapsedMilliseconds(since start: UInt64) -> Double {
        let end = DispatchTime.now().uptimeNanoseconds
        guard end >= start else {
            return 0
        }
        return Double(end - start) / 1_000_000
    }
}
