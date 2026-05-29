import CoreGraphics

enum HwpNativePageCompositor {
    static func render(
        tree: RenderNode,
        overlays: RhwpPageOverlayImageSet?,
        in context: CGContext,
        pageHeight: Double,
        document: RhwpDocument
    ) {
        let renderer = CGTreeRenderer()
        let overlayLayers = renderTreeOverlayLayers(from: overlays, tree: tree)

        renderer.render(
            tree: tree,
            in: context,
            pageHeight: pageHeight,
            document: document,
            mode: .pageBackground
        )

        if overlayLayers.contains(.behindText) {
            renderOverlayLayer(
                .behindText,
                tree: tree,
                overlays: overlays?.behind ?? [],
                renderer: renderer,
                context: context,
                pageHeight: pageHeight,
                document: document
            )
        }

        renderer.render(
            tree: tree,
            in: context,
            pageHeight: pageHeight,
            document: document,
            mode: .flowExcludingPageOverlays(overlayLayers)
        )

        if overlayLayers.contains(.inFrontOfText) {
            renderOverlayLayer(
                .inFrontOfText,
                tree: tree,
                overlays: overlays?.front ?? [],
                renderer: renderer,
                context: context,
                pageHeight: pageHeight,
                document: document
            )
        }
    }

    private static func renderOverlayLayer(
        _ layer: CGTreeOverlayLayer,
        tree: RenderNode,
        overlays: [RhwpPageOverlayImage],
        renderer: CGTreeRenderer,
        context: CGContext,
        pageHeight: Double,
        document: RhwpDocument
    ) {
        let renderableOverlays = overlays.filter(\.hasRenderableData)
        if renderableOverlays.isEmpty {
            renderer.render(
                tree: tree,
                in: context,
                pageHeight: pageHeight,
                document: document,
                mode: .pageOverlay(layer)
            )
        } else {
            let drawnCount = renderer.renderOverlayImages(renderableOverlays, in: context, document: document)
            if drawnCount == 0 {
                renderer.render(
                    tree: tree,
                    in: context,
                    pageHeight: pageHeight,
                    document: document,
                    mode: .pageOverlay(layer)
                )
            }
        }
    }

    private static func renderTreeOverlayLayers(
        from overlays: RhwpPageOverlayImageSet?,
        tree: RenderNode
    ) -> [CGTreeOverlayLayer] {
        let treeLayers = overlayLayers(in: tree)
        guard let overlays else {
            return treeLayers
        }

        var layers = treeLayers
        if !overlays.behind.isEmpty && !layers.contains(.behindText) {
            layers.append(.behindText)
        }
        if !overlays.front.isEmpty && !layers.contains(.inFrontOfText) {
            layers.append(.inFrontOfText)
        }
        return layers
    }

    private static func overlayLayers(in node: RenderNode) -> [CGTreeOverlayLayer] {
        var layers: [CGTreeOverlayLayer] = []
        collectOverlayLayers(in: node, into: &layers)
        return layers
    }

    private static func collectOverlayLayers(
        in node: RenderNode,
        into layers: inout [CGTreeOverlayLayer]
    ) {
        if case .image(let image) = node.nodeType,
           let layer = CGTreeOverlayLayer(textWrap: image.textWrap),
           !layers.contains(layer) {
            layers.append(layer)
        }

        for child in node.children {
            collectOverlayLayers(in: child, into: &layers)
        }
    }
}
