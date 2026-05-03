import SwiftUI

struct ContentView: View {
    @ObservedObject var store: DocumentViewerStore

    var body: some View {
        DocumentViewerView(store: store)
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        shareDocument()
                    } label: {
                        Label("공유", systemImage: "square.and.arrow.up")
                            .background(
                                SharePresentationAnchorView()
                                    .allowsHitTesting(false)
                            )
                    }
                    .disabled(!store.hasDocument || store.isWebViewLoading)
                    .help("공유")

                    Button {
                        store.revealCurrentDocumentInFinder()
                    } label: {
                        Label("Finder에서 보기", systemImage: "folder")
                    }
                    .disabled(!store.canRevealInFinder)
                    .help("Finder에서 보기")

                    Button {
                        exportPDF()
                    } label: {
                        Label("PDF로 내보내기", systemImage: "doc.richtext")
                    }
                    .disabled(!store.hasDocument || store.isWebViewLoading)
                    .help("PDF로 내보내기")

                    RecentDocumentsMenu(store: store)
                }
            }
    }

    private func shareDocument() {
        guard RhwpStudioNativeCommandDispatcher.run("file:share") else {
            store.setWebViewError("공유할 viewer를 찾을 수 없습니다.")
            return
        }
    }

    private func exportPDF() {
        guard RhwpStudioNativeCommandDispatcher.run("file:export-pdf") else {
            store.setWebViewError("PDF로 내보낼 viewer를 찾을 수 없습니다.")
            return
        }
    }
}

private struct RecentDocumentsMenu: View {
    @ObservedObject var store: DocumentViewerStore

    var body: some View {
        Menu {
            if store.recentDocuments.isEmpty {
                Text("최근 문서 없음")
            } else {
                ForEach(store.recentDocuments) { document in
                    Button(document.displayName) {
                        store.openRecentDocument(document)
                    }
                }

                Divider()

                Button("최근 문서 지우기") {
                    store.clearRecentDocuments()
                }
            }
        } label: {
            Label("최근 문서", systemImage: "clock.arrow.circlepath")
        }
        .help("최근 문서")
    }
}
