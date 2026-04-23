import AppKit
import SwiftUI

@main
struct AlHangeulMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewerStore = DocumentViewerStore()
    @StateObject private var extensionStatus = ExtensionStatusModel()

    var body: some Scene {
        WindowGroup {
            ContentView(store: viewerStore, extensionStatus: extensionStatus)
                .frame(minWidth: 900, minHeight: 620)
                .task {
                    DocumentOpenRouter.bindStore(viewerStore)
                    extensionStatus.refresh()
                    DocumentOpenRouter.openPendingURL()
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("문서 열기...") {
                    viewerStore.openDocument()
                }
                .keyboardShortcut("o", modifiers: [.command])
            }

            CommandMenu("보기") {
                Button("확대") {
                    viewerStore.zoomIn()
                }
                .keyboardShortcut("+", modifiers: [.command])

                Button("축소") {
                    viewerStore.zoomOut()
                }
                .keyboardShortcut("-", modifiers: [.command])

                Button("실제 크기") {
                    viewerStore.resetZoom()
                }
                .keyboardShortcut("0", modifiers: [.command])
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
