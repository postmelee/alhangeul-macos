import Foundation
import PDFKit
import WebKit

/// 실제 첫 페이지의 화면, 출력용 SVG와 PDF/인쇄 공통 경로를 같은 편집 세대에서 관찰한다.
@MainActor
enum HFTDocumentConsumer {
    static func capture(view: WKWebView, directory: URL, document: URL, editor: RhwpStudioEditorSnapshot,
                        handler: StudioFontMessageHandler, displayReads: [[String: String]],
                        rendererDiagnostics: [String: Any], isCurrent: @escaping @MainActor () -> Bool) async throws {
        func write(_ value: Any, to name: String) throws {
            let data = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: directory.appendingPathComponent(name))
        }
        func evaluate(_ script: String) async throws -> Any? {
            try await view.callAsyncJavaScript(script, arguments: [:], in: nil, contentWorld: .page)
        }
        guard let details = try await evaluate("""
            const w = window.__hftWasm;
            return {pages:w.pageCount, canvas:w.getHostCanvasFontDiagnostics(),
                    trace:JSON.parse(w.getFontDecisionTrace(0,64)), fontState:window.rhwpStudio.fonts.getState()};
            """) as? [String: Any] else { throw CocoaError(.coderInvalidValue) }
        try write(details, to: "document.json")
        try write(rendererDiagnostics, to: "renderer.json")
        try write(displayReads, to: "display-reads.json")
        guard let base64 = try await evaluate("""
            const page = document.querySelector('canvas.document-page-canvas[data-rhwp-rendered-zoom]');
            return page.toDataURL('image/png').split(',')[1];
            """) as? String, let png = Data(base64Encoded: base64) else { throw CocoaError(.fileReadCorruptFile) }
        try png.write(to: directory.appendingPathComponent("page.png"))
        guard let svg = try await evaluate("return await window.rhwpStudio.fonts.getOutputPageSvg(0);") as? String
        else { throw CocoaError(.coderInvalidValue) }
        try svg.write(to: directory.appendingPathComponent("page.svg"), atomically: true, encoding: .utf8)

        let page = try RhwpStudioPagePayload(fileName: document.lastPathComponent, pageCount: 1, pages: [svg])
        let job = RhwpStudioOutputFontJob(
            document: .init(loadToken: "hft-probe", epoch: editor.documentEpoch, revision: editor.changeSeq),
            snapshot: try await handler.outputSnapshot(), documentIsCurrent: { isCurrent() },
            resolve: { requests in
                let args = try JSONSerialization.jsonObject(with: JSONEncoder().encode(requests))
                guard let json = try await view.callAsyncJavaScript(RhwpStudioOutputFontBridgeScript.resolve,
                    arguments: ["requests": args], in: nil, contentWorld: .page) as? String
                else { throw RhwpStudioOutputFontError.invalidRequest }
                let data = Data(json.utf8)
                try write(["requests": args, "resolution": try JSONSerialization.jsonObject(with: data)],
                          to: "pdf-font-selection.json")
                return try JSONDecoder().decode(RhwpStudioOutputFontResolution.self, from: data)
            })
        let renderer = RhwpStudioPagePDFRenderer(outputFonts: job)
        let pdf: PDFDocument
        do {
            pdf = try await withCheckedThrowingContinuation { continuation in
                renderer.render(payload: page) { continuation.resume(with: $0) }
            }
            try await job.seal()
            guard let data = pdf.dataRepresentation() else { throw CocoaError(.fileWriteUnknown) }
            try data.write(to: directory.appendingPathComponent("page.pdf"))
            try write(["pages": pdf.pageCount, "text": pdf.string ?? ""], to: "pdf-result.json")
        } catch {
            await job.close()
            try write(["error": String(describing: error)], to: "pdf-result.json")
            throw error
        }
        await job.close()
    }
}
