import AppKit
import SwiftUI

@main
struct AlHangeulMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewerStore = DocumentViewerStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: viewerStore)
                .frame(minWidth: 900, minHeight: 620)
                .task {
                    DocumentOpenRouter.bindStore(viewerStore)
                    DocumentOpenRouter.openPendingURL()
                }
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("알한글에 관하여") {
                    AboutWindowPresenter.shared.show()
                }
            }

            CommandGroup(replacing: .newItem) {}

            CommandGroup(replacing: .saveItem) {
                Button("저장") {
                    RhwpStudioNativeCommandDispatcher.run("file:save")
                }
                .keyboardShortcut("s", modifiers: [.command])
                .disabled(!viewerStore.hasDocument)
            }

            CommandGroup(replacing: .printItem) {
                Button("인쇄...") {
                    RhwpStudioNativeCommandDispatcher.run("file:print")
                }
                .keyboardShortcut("p", modifiers: [.command])
                .disabled(!viewerStore.hasDocument)
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        DocumentOpenRouter.requestOpen(URL(fileURLWithPath: filename))
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        urls.first.map(DocumentOpenRouter.requestOpen)
    }
}
