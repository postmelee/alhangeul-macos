import SwiftUI

struct ContentView: View {
    @ObservedObject var store: DocumentViewerStore

    var body: some View {
        DocumentViewerView(store: store)
    }
}
