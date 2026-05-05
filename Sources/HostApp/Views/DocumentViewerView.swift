import SwiftUI

struct DocumentViewerView: View {
    @ObservedObject var store: DocumentViewerStore

    var body: some View {
        ZStack {
            if let error = store.errorMessage {
                ErrorStateView(message: error)
            } else {
                RhwpStudioContainerView(store: store, document: store.rhwpStudioDocument)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct RhwpStudioContainerView: View {
    @ObservedObject var store: DocumentViewerStore
    let document: RhwpStudioDocumentPayload?

    var body: some View {
        ZStack {
            RhwpStudioWebView(
                document: document,
                sourceDocument: store.sourceDocument,
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
                },
                onDocumentSaved: { url in
                    Task { @MainActor in
                        store.recordSavedDocument(at: url)
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
        .id(document?.revision ?? 0)
        .background(Color(nsColor: .windowBackgroundColor))
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
