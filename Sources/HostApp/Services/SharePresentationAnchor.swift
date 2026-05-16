import AppKit
import SwiftUI

@MainActor
enum SharePresentationAnchor {
    private static weak var anchorView: NSView?

    static func register(_ view: NSView) {
        anchorView = view
    }

    static var presentationView: NSView? {
        guard let anchorView,
              anchorView.window != nil
        else {
            return nil
        }

        return anchorView.nearestVisiblePresentationView
    }
}

struct SharePresentationAnchorView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = SharePresentationAnchorNSView(frame: .zero)
        SharePresentationAnchor.register(view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        SharePresentationAnchor.register(nsView)
    }
}

private final class SharePresentationAnchorNSView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if window != nil {
            SharePresentationAnchor.register(self)
        }
    }
}

private extension NSView {
    var nearestVisiblePresentationView: NSView {
        var candidate: NSView? = self

        while let view = candidate {
            let bounds = view.bounds
            if view.window != nil,
               !view.isHidden,
               bounds.width >= 8,
               bounds.height >= 8 {
                return view
            }
            candidate = view.superview
        }

        return self
    }
}
