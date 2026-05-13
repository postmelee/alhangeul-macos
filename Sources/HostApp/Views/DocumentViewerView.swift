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
            if let failure = store.webViewFailure {
                WebViewerFallbackView(
                    failure: failure,
                    canRevealInFinder: store.canRevealInFinder,
                    onRetry: {
                        store.retryWebViewLoad()
                    },
                    onOpenDocument: {
                        store.openDocument()
                    },
                    onRevealInFinder: {
                        store.revealCurrentDocumentInFinder()
                    }
                )
            } else {
                RhwpStudioWebView(
                    document: document,
                    sourceDocument: store.sourceDocument,
                    reloadToken: store.webViewReloadToken,
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
                    onFailure: { failure in
                        Task { @MainActor in
                            store.setWebViewFailure(failure)
                        }
                    },
                    onOpenDocument: {
                        Task { @MainActor in
                            store.openDocument()
                        }
                    },
                    onDroppedDocument: { document in
                        Task { @MainActor in
                            store.loadDroppedDocument(
                                data: document.data,
                                filename: document.fileName
                            )
                        }
                    },
                    onDroppedFileURL: { url in
                        Task { @MainActor in
                            store.loadDocument(from: url)
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
                    WebViewerErrorBanner(
                        message: message,
                        onDismiss: {
                            store.dismissWebViewError()
                        }
                    )
                        .padding(.top, 12)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
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
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)

            Text(message)
                .lineLimit(2)
                .font(.caption)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("알림 닫기")
            .accessibilityLabel("알림 닫기")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 2)
    }
}

private struct WebViewerFallbackView: View {
    let failure: RhwpStudioWebViewFailure
    let canRevealInFinder: Bool
    let onRetry: () -> Void
    let onOpenDocument: () -> Void
    let onRevealInFinder: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange)

            VStack(spacing: 8) {
                Text(failure.title)
                    .font(.headline)
                Text(failure.message)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Button {
                    onRetry()
                } label: {
                    Label("다시 시도", systemImage: "arrow.clockwise")
                }

                Button {
                    onOpenDocument()
                } label: {
                    Label("다른 파일 열기", systemImage: "doc.badge.plus")
                }

                if canRevealInFinder {
                    Button {
                        onRevealInFinder()
                    } label: {
                        Label("Finder에서 보기", systemImage: "folder")
                    }
                }
            }

            DisclosureGroup("진단 정보") {
                ScrollView {
                    Text(failure.diagnosticDetail)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 140)
            }
            .frame(maxWidth: 560)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
