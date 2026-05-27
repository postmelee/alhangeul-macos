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
            renderer.render(
                tree: tree,
                in: context,
                pageHeight: pageHeight,
                document: document,
                mode: .pageOverlay(.behindText)
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
            renderer.render(
                tree: tree,
                in: context,
                pageHeight: pageHeight,
                document: document,
                mode: .pageOverlay(.inFrontOfText)
            )
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
