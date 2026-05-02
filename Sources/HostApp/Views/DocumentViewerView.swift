import SwiftUI

struct DocumentViewerView: View {
    @ObservedObject var store: DocumentViewerStore

    var body: some View {
        ZStack {
            if let document = store.rhwpStudioDocument {
                RhwpStudioContainerView(store: store, document: document)
            } else if let error = store.errorMessage {
                ErrorStateView(message: error)
            } else if store.isLoading {
                LoadingStateView(message: "불러오는 중...")
            } else {
                EmptyDocumentView(store: store)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            StatusBarView(store: store)
        }
    }
}

private struct RhwpStudioContainerView: View {
    @ObservedObject var store: DocumentViewerStore
    let document: RhwpStudioDocumentPayload

    var body: some View {
        ZStack {
            RhwpStudioWebView(
                document: document,
                onLoadStateChange: { isLoading in
                    Task { @MainActor in
                        store.setWebViewLoading(isLoading)
                    }
                },
                onError: { message in
                    Task { @MainActor in
                        store.setWebViewError(message)
                    }
                },
                onOpenDocument: {
                    Task { @MainActor in
                        store.openDocument()
                    }
                }
            )

            if store.isLoading || store.isWebViewLoading {
                LoadingOverlayView(message: store.isLoading ? "불러오는 중..." : "웹 viewer 로딩 중...")
            }

            if let message = store.webViewErrorMessage {
                WebViewerErrorBanner(message: message)
                    .padding(.top, 12)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .id(document.revision)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct EmptyDocumentView: View {
    @ObservedObject var store: DocumentViewerStore

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("HWP 또는 HWPX 문서를 열어 주세요.")
                .font(.title3)
            HStack {
                Button("문서 열기") {
                    store.openDocument()
                }
            }
        }
    }
}

private struct LoadingStateView: View {
    let message: String

    var body: some View {
        ProgressView(message)
            .padding(24)
    }
}

private struct LoadingOverlayView: View {
    let message: String

    var body: some View {
        ProgressView(message)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
    }
}

private struct ErrorStateView: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(32)
    }
}

private struct WebViewerErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            Text(message)
                .lineLimit(2)
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 2)
    }
}

private struct StatusBarView: View {
    @ObservedObject var store: DocumentViewerStore

    var body: some View {
        HStack(spacing: 16) {
            Text(store.filename.isEmpty ? "문서 없음" : store.filename)
                .lineLimit(1)
            Spacer()
            if store.hasDocument {
                Text(store.isWebViewLoading ? "웹 viewer 로딩 중" : "rhwp-studio")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(.bar)
    }
}
