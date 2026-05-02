import SwiftUI

struct ContentView: View {
    @ObservedObject var store: DocumentViewerStore

    var body: some View {
        DocumentViewerView(store: store)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    store.openDocument()
                } label: {
                    Label("문서 열기", systemImage: "folder")
                }
                .disabled(store.isLoading)
            }
        }
    }
}
