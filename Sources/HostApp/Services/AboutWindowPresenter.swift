import AppKit
import SwiftUI

@MainActor
final class AboutWindowPresenter: NSObject, NSWindowDelegate {
    static let shared = AboutWindowPresenter()

    private let navigationModel = AboutNavigationModel()
    private var windowController: NSWindowController?

    func show(section: AboutSection = .info) {
        navigationModel.selection = section

        if let window = windowController?.window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(
            rootView: AboutView(navigationModel: navigationModel)
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 620),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "알한글에 관하여"
        window.contentViewController = hostingController
        window.minSize = NSSize(width: 540, height: 430)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()

        let controller = NSWindowController(window: window)
        windowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window === windowController?.window else {
            return
        }

        window.delegate = nil
        windowController = nil
    }
}
