import AppKit
import SwiftUI

enum QuickLookConflictNoticeAction {
    case openSettings
    case showDetails
    case later
}

@MainActor
final class QuickLookConflictNoticePresenter: NSObject, NSWindowDelegate {
    static let shared = QuickLookConflictNoticePresenter()

    private var windowController: NSWindowController?
    private var onAction: ((QuickLookConflictNoticeAction) -> Void)?

    func show(
        presentation: QuickLookConflictPresentation,
        onAction: @escaping (QuickLookConflictNoticeAction) -> Void
    ) {
        if let window = windowController?.window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        self.onAction = onAction
        let hostingController = NSHostingController(
            rootView: QuickLookConflictNoticeView(
                presentation: presentation,
                onAction: { [weak self] action in
                    self?.finish(with: action)
                }
            )
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 430),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Quick Look 미리보기 안내"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.delegate = self
        window.center()

        let controller = NSWindowController(window: window)
        windowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window === windowController?.window
        else {
            return
        }

        let callback = onAction
        onAction = nil
        window.delegate = nil
        windowController = nil
        callback?(.later)
    }

    private func finish(with action: QuickLookConflictNoticeAction) {
        guard let callback = onAction else {
            return
        }

        onAction = nil
        windowController?.window?.close()
        callback(action)
    }
}
