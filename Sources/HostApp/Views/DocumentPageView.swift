import AppKit
import SwiftUI

struct DocumentPageView: NSViewRepresentable {
    let tree: RenderNode
    let pageSize: CGSize
    let zoomScale: CGFloat
    let document: RhwpDocument

    func makeNSView(context: Context) -> DocumentPageNSView {
        let view = DocumentPageNSView()
        view.configure(tree: tree, pageSize: pageSize, zoomScale: zoomScale, document: document)
        return view
    }

    func updateNSView(_ nsView: DocumentPageNSView, context: Context) {
        nsView.configure(tree: tree, pageSize: pageSize, zoomScale: zoomScale, document: document)
    }
}

final class DocumentPageNSView: NSView {
    private var tree: RenderNode?
    private var pageSize: CGSize = .zero
    private var zoomScale: CGFloat = 1.0
    private weak var document: RhwpDocument?
    private let renderer = CGTreeRenderer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLayer()
    }

    override var isFlipped: Bool {
        true
    }

    func configure(tree: RenderNode, pageSize: CGSize, zoomScale: CGFloat, document: RhwpDocument) {
        self.tree = tree
        self.pageSize = pageSize
        self.zoomScale = zoomScale
        self.document = document
        invalidateDrawing()
    }

    private func configureLayer() {
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        layer?.backgroundColor = NSColor.white.cgColor
    }

    override func setFrameSize(_ newSize: NSSize) {
        let oldSize = frame.size
        super.setFrameSize(newSize)
        if oldSize != newSize {
            invalidateDrawing()
        }
    }

    private func invalidateDrawing() {
        needsDisplay = true
        layer?.setNeedsDisplay()
    }

    override func draw(_ dirtyRect: NSRect) {
        guard
            let context = NSGraphicsContext.current?.cgContext,
            let tree,
            let document
        else {
            return
        }

        context.saveGState()
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(bounds)
        context.scaleBy(x: zoomScale, y: zoomScale)
        renderer.render(tree: tree, in: context, pageHeight: pageSize.height, document: document)
        context.restoreGState()
    }
}
