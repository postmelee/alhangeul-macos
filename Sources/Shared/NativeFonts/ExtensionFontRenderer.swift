import Foundation
import CoreGraphics

/// 원본 이름의 OS 재조회로 공급 거부를 우회하지 않는다. stale/취소는 결과 자체를 폐기한다.
enum ExtensionFontRenderer {
    typealias Supply = @Sendable () async throws -> StudioFontSupplySnapshot
    static let live: Supply = { try await ExtensionFontSupply.shared.snapshot() }

    private static func failureIdentifier(_ error: Error) -> String {
        // 관리 저장소의 고정 오류 분류/errno만 기록한다. 문서 값/원본 경로는 넣지 않는다.
        if let value = error as? FontLibraryError {
            return "FontLibraryError:" + String(describing: value)
        }
        return String(describing: type(of: error))
    }

    static func isStaleOrCancelled(_ error: Error) -> Bool {
        if error is CancellationError || (error as? HwpNativeFontSupplyError) == .stale { return true }
        if let value = error as? FontLibraryError, [.staleGeneration, .inputChanged, .cancelled].contains(value) { return true }
        if let value = error as? StudioFontError, [.staleGeneration, .staleSession, .cancelled].contains(value) { return true }
        if let value = error as? InstalledFontFailure, [.staleGeneration, .changed, .cancelled].contains(value) { return true }
        return false
    }

    static func png(context: HwpPreviewDocumentContext, mode: HwpPreviewPNGReplyMode,
        supply: Supply = live, current: @escaping @Sendable () async throws -> Bool = { true }) async throws -> HwpRenderedPreviewPNG {
        do {
            let snapshot = try await supply()
            return try await HwpNativeFontPageRenderer.withPreparedPage(document: context.document,
                documentIdentity: context.sourceIdentity, filename: context.filename, pageIndex: 0,
                snapshot: snapshot, policy: mode == .coreGraphics ? .coreGraphicsOnly : .skiaOptIn,
                documentIsCurrent: current) { prepared in
                    try HwpPreviewPNGRenderer.render(context: context, mode: mode, fontContext: prepared.context)
                }
        } catch {
            if isStaleOrCancelled(error) { throw error }
            try await validate(current)
            let result = try HwpPreviewPNGRenderer.render(context: context, mode: mode, forceDefaultFonts: true)
            try await validate(current)
            var diagnostics = result.diagnostics
            diagnostics.fontSupplyFailure = failureIdentifier(error)
            return .init(data: result.data, contentSize: result.contentSize, diagnostics: diagnostics)
        }
    }

    static func pdf(context: HwpPreviewDocumentContext, supply: Supply = live,
        current: @escaping @Sendable () async throws -> Bool = { true }) async throws -> HwpRenderedPreviewPDF {
        do {
            let snapshot = try await supply()
            let result: HwpRenderedPreviewPDF
            do {
                result = try await HwpPreviewPDFRenderer.render(context: context, pageRenderer: { index in
                    let prepared = try await HwpNativeFontPageRenderer.preparePage(document: context.document,
                        documentIdentity: context.sourceIdentity, filename: context.filename, pageIndex: index,
                        snapshot: snapshot, documentIsCurrent: current)
                    return try HwpPageImageRenderer.renderPage(document: context.document, pageIndex: index,
                        fontContext: prepared.context)
                })
                guard try await snapshot.current() else { throw HwpNativeFontSupplyError.stale }
                try await validate(current)
            } catch {
                await snapshot.release()
                throw error
            }
            await snapshot.release()
            try Task.checkCancellation()
            return result
        } catch {
            if isStaleOrCancelled(error) { throw error }
            try await validate(current)
            let result = try HwpPreviewPDFRenderer.render(document: context.document,
                pageCount: context.pageCount, contentSize: context.contentSize, collectDiagnostics: true,
                forceDefaultFonts: true)
            try await validate(current)
            return .init(data: result.data, contentSize: result.contentSize, pageCount: result.pageCount,
                pageDiagnostics: result.pageDiagnostics.map { page in
                    var diagnostics = page.diagnostics
                    diagnostics.fontSupplyFailure = failureIdentifier(error)
                    return .init(pageIndex: page.pageIndex, diagnostics: diagnostics)
                })
        }
    }

    static func thumbnail(context: HwpPreviewDocumentContext, maximumPixelSize: CGSize,
        policy: HwpPageRenderPolicy, snapshot: StudioFontSupplySnapshot,
        current: @escaping @Sendable () async throws -> Bool) async throws -> HwpRenderedPage {
        do {
            return try await HwpNativeFontPageRenderer.withPreparedPage(document: context.document,
                documentIdentity: context.sourceIdentity, filename: context.filename, pageIndex: 0,
                snapshot: snapshot, maximumPixelSize: maximumPixelSize, policy: policy,
                documentIsCurrent: current) { prepared in
                    try HwpPageImageRenderer.renderPage(document: context.document, pageIndex: 0,
                        maximumPixelSize: maximumPixelSize, policy: policy, fontContext: prepared.context)
                }
        } catch {
            if isStaleOrCancelled(error) { throw error }
            return try await fallbackThumbnail(context: context, maximumPixelSize: maximumPixelSize,
                policy: policy, current: current, error: error)
        }
    }

    static func fallbackThumbnail(context: HwpPreviewDocumentContext, maximumPixelSize: CGSize,
        policy: HwpPageRenderPolicy, current: @escaping @Sendable () async throws -> Bool, error: Error) async throws -> HwpRenderedPage {
        try await validate(current)
        let page = try HwpPageImageRenderer.renderPage(document: context.document, pageIndex: 0,
            maximumPixelSize: maximumPixelSize, policy: policy, forceDefaultFonts: true)
        try await validate(current)
        var diagnostics = page.diagnostics
        diagnostics.fontSupplyFailure = failureIdentifier(error)
        return .init(image: page.image, size: page.size, diagnostics: diagnostics)
    }

    private static func validate(_ current: @Sendable () async throws -> Bool) async throws {
        try Task.checkCancellation()
        guard try await current() else { throw HwpNativeFontSupplyError.stale }
    }
}
