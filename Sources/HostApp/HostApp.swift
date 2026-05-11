import AppKit
import Combine
import SwiftUI

@main
struct AlHangeulMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var updateController = UpdateController()

    var body: some Scene {
        WindowGroup {
            DocumentWindowRootView()
        }
        .commands {
            HostAppCommands(updateController: updateController)
        }
    }
}

@MainActor
private struct DocumentWindowRootView: View {
    @StateObject private var store: DocumentViewerStore
    @StateObject private var windowLifecycle = DocumentWindowLifecycle()
    @State private var didPrepareWindow = false

    private let initialURL: URL?

    init(initialURL: URL? = nil) {
        _store = StateObject(wrappedValue: DocumentViewerStore())
        self.initialURL = initialURL
    }

    init(store: DocumentViewerStore, initialURL: URL? = nil) {
        _store = StateObject(wrappedValue: store)
        self.initialURL = initialURL
    }

    var body: some View {
        ContentView(store: store)
            .frame(minWidth: 900, minHeight: 620)
            .background(
                WindowAccessor { window in
                    windowLifecycle.update(window)
                    closeRedundantEmptyWindowIfNeeded()
                }
            )
            .task {
                prepareWindowIfNeeded()
            }
            .onChange(of: store.hasDocument) { _ in
                closeRedundantEmptyWindowIfNeeded()
            }
            .onDisappear {
                DocumentOpenRouter.unregister(store)
            }
    }

    private func prepareWindowIfNeeded() {
        guard !didPrepareWindow else {
            return
        }

        didPrepareWindow = true
        DocumentOpenRouter.register(store)

        if let initialURL {
            store.loadDocument(from: initialURL)
        } else {
            let didOpenPendingURL = DocumentOpenRouter.openPendingURL(in: store)
            if !didOpenPendingURL {
                closeRedundantEmptyWindowIfNeeded()
            }
        }
    }

    private func closeRedundantEmptyWindowIfNeeded() {
        guard initialURL == nil else {
            return
        }

        windowLifecycle.closeIfNeeded(
            DocumentOpenRouter.shouldCloseRedundantEmptyWindow(for: store)
        )
    }
}

@MainActor
private final class DocumentWindowLifecycle: ObservableObject {
    private weak var window: NSWindow?
    private var didRequestClose = false

    func update(_ window: NSWindow) {
        self.window = window
    }

    func closeIfNeeded(_ shouldClose: Bool) {
        guard shouldClose, !didRequestClose, let window else {
            return
        }

        didRequestClose = true
        DispatchQueue.main.async { [weak window] in
            window?.close()
        }
    }
}

private struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        resolveWindow(for: view)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        resolveWindow(for: view)
    }

    private func resolveWindow(for view: NSView) {
        DispatchQueue.main.async {
            guard let window = view.window else {
                return
            }
            onResolve(window)
        }
    }
}

private struct HostAppCommands: Commands {
    @ObservedObject var updateController: UpdateController

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("알한글에 관하여") {
                AboutWindowPresenter.shared.show()
            }

            CheckForUpdatesCommand(updateController: updateController)
        }

        CommandGroup(replacing: .newItem) {}

        CommandGroup(replacing: .saveItem) {
            Button("저장") {
                RhwpStudioNativeCommandDispatcher.run("file:save")
            }
            .keyboardShortcut("s", modifiers: [.command])

            Button("다른 이름으로 저장...") {
                RhwpStudioNativeCommandDispatcher.run("file:save-as")
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .printItem) {
            Button("인쇄...") {
                RhwpStudioNativeCommandDispatcher.run("file:print")
            }
            .keyboardShortcut("p", modifiers: [.command])
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        ExtensionSystemRegistrationRefresher.refreshCurrentBundle()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeMain(_:)),
            name: NSWindow.didBecomeMainNotification,
            object: nil
        )

        DispatchQueue.main.async { [weak self] in
            self?.repositionUnreachableWindowsIfNeeded()
        }
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        DocumentOpenRouter.requestOpen(URL(fileURLWithPath: filename))
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach(DocumentOpenRouter.requestOpen)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        repositionUnreachableWindowsIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func windowDidBecomeMain(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else {
            return
        }
        repositionIfUnreachable(window)
    }

    private func repositionUnreachableWindowsIfNeeded() {
        NSApp.windows.forEach(repositionIfUnreachable)
    }

    private func repositionIfUnreachable(_ window: NSWindow) {
        guard window.isVisible,
              !window.isMiniaturized,
              !isWindowReachable(window),
              let targetScreen = NSScreen.main ?? NSScreen.screens.first
        else {
            return
        }

        let visibleFrame = targetScreen.visibleFrame
        var frame = window.frame
        frame.size.width = min(frame.width, visibleFrame.width)
        frame.size.height = min(frame.height, visibleFrame.height)
        frame.origin.x = visibleFrame.midX - frame.width / 2
        frame.origin.y = visibleFrame.midY - frame.height / 2
        window.setFrame(frame.integral, display: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func isWindowReachable(_ window: NSWindow) -> Bool {
        let frame = window.frame
        guard frame.width > 0, frame.height > 0 else {
            return true
        }

        let titlebarHeight = min(44, frame.height)
        let titlebarFrame = NSRect(
            x: frame.minX,
            y: frame.maxY - titlebarHeight,
            width: frame.width,
            height: titlebarHeight
        )
        return NSScreen.screens
            .map(\.visibleFrame)
            .contains { $0.intersects(titlebarFrame) }
    }
}

@MainActor
final class DocumentWindowPresenter: NSObject, NSWindowDelegate {
    static let shared = DocumentWindowPresenter()

    private var controllers: [ObjectIdentifier: NSWindowController] = [:]
    private var toolbarControllers: [ObjectIdentifier: DocumentWindowToolbarController] = [:]

    func openDocument(_ url: URL) {
        let store = DocumentViewerStore()
        let rootView = DocumentWindowRootView(store: store, initialURL: url)
            .frame(minWidth: 900, minHeight: 620)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "알한글"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.delegate = self
        let toolbarController = DocumentWindowToolbarController(store: store, window: window)
        window.toolbar = toolbarController.makeToolbar()
        window.center()

        let controller = NSWindowController(window: window)
        let windowID = ObjectIdentifier(window)
        controllers[windowID] = controller
        toolbarControllers[windowID] = toolbarController
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else {
            return
        }

        window.delegate = nil
        let windowID = ObjectIdentifier(window)
        controllers.removeValue(forKey: windowID)
        toolbarControllers.removeValue(forKey: windowID)
    }
}

@MainActor
private final class DocumentWindowToolbarController: NSObject, NSToolbarDelegate, NSToolbarItemValidation, NSMenuDelegate {
    private enum ItemID {
        static let share = NSToolbarItem.Identifier("alhangeul.share")
        static let reveal = NSToolbarItem.Identifier("alhangeul.reveal")
        static let exportPDF = NSToolbarItem.Identifier("alhangeul.exportPDF")
        static let recent = NSToolbarItem.Identifier("alhangeul.recent")
    }

    private let store: DocumentViewerStore
    private weak var window: NSWindow?
    private var storeObservation: AnyCancellable?

    init(store: DocumentViewerStore, window: NSWindow) {
        self.store = store
        self.window = window
        super.init()
        storeObservation = store.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.window?.toolbar?.validateVisibleItems()
            }
        }
    }

    func makeToolbar() -> NSToolbar {
        let toolbar = NSToolbar(identifier: "alhangeul.document.toolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        return toolbar
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            ItemID.share,
            ItemID.reveal,
            ItemID.exportPDF,
            ItemID.recent
        ]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarAllowedItemIdentifiers(toolbar)
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case ItemID.share:
            return buttonItem(
                identifier: itemIdentifier,
                label: "공유",
                symbolName: "square.and.arrow.up",
                action: #selector(shareDocument)
            )
        case ItemID.reveal:
            return buttonItem(
                identifier: itemIdentifier,
                label: "Finder에서 보기",
                symbolName: "folder",
                action: #selector(revealInFinder)
            )
        case ItemID.exportPDF:
            return buttonItem(
                identifier: itemIdentifier,
                label: "PDF로 내보내기",
                symbolName: "doc.richtext",
                action: #selector(exportPDF)
            )
        case ItemID.recent:
            let item = NSMenuToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "최근 문서"
            item.paletteLabel = "최근 문서"
            item.toolTip = "최근 문서"
            item.image = NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: "최근 문서")
            let menu = NSMenu(title: "최근 문서")
            menu.delegate = self
            item.menu = menu
            return item
        default:
            return nil
        }
    }

    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        switch item.itemIdentifier {
        case ItemID.share, ItemID.exportPDF:
            return store.canRunWebViewCommands
        case ItemID.reveal:
            return store.canRevealInFinder
        case ItemID.recent:
            return true
        default:
            return false
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if store.recentDocuments.isEmpty {
            let item = NSMenuItem(title: "최근 문서 없음", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            return
        }

        for document in store.recentDocuments {
            let item = NSMenuItem(
                title: document.displayName,
                action: #selector(openRecentDocument(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = document
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let clearItem = NSMenuItem(
            title: "최근 문서 지우기",
            action: #selector(clearRecentDocuments),
            keyEquivalent: ""
        )
        clearItem.target = self
        menu.addItem(clearItem)
    }

    private func buttonItem(
        identifier: NSToolbarItem.Identifier,
        label: String,
        symbolName: String,
        action: Selector
    ) -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = label
        item.paletteLabel = label
        item.toolTip = label
        item.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: label)
        item.target = self
        item.action = action
        return item
    }

    @objc private func shareDocument() {
        guard RhwpStudioNativeCommandDispatcher.run("file:share", in: window) else {
            store.setWebViewError("공유할 viewer를 찾을 수 없습니다.")
            return
        }
    }

    @objc private func revealInFinder() {
        store.revealCurrentDocumentInFinder()
    }

    @objc private func exportPDF() {
        guard RhwpStudioNativeCommandDispatcher.run("file:export-pdf", in: window) else {
            store.setWebViewError("PDF로 내보낼 viewer를 찾을 수 없습니다.")
            return
        }
    }

    @objc private func openRecentDocument(_ sender: NSMenuItem) {
        guard let document = sender.representedObject as? RecentDocumentItem else {
            return
        }
        store.openRecentDocument(document)
    }

    @objc private func clearRecentDocuments() {
        store.clearRecentDocuments()
    }
}
