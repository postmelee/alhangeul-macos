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
            }

            ToolbarItemGroup {
                Button {
                    store.zoomOut()
                } label: {
                    Label("축소", systemImage: "minus.magnifyingglass")
                }
                .disabled(!store.hasDocument)

                Slider(
                    value: $store.zoomScale,
                    in: store.minimumZoomScale...store.maximumZoomScale
                )
                .frame(width: 130)
                .disabled(!store.hasDocument)

                Button {
                    store.zoomIn()
                } label: {
                    Label("확대", systemImage: "plus.magnifyingglass")
                }
                .disabled(!store.hasDocument)

                Button {
                    store.resetZoom()
                } label: {
                    Label("실제 크기", systemImage: "arrow.up.left.and.down.right.magnifyingglass")
                }
                .disabled(!store.hasDocument)
            }
        }
    }
}
