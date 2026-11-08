import SwiftUI

struct DocumentViewerView: View {
    @ObservedObject var store: DocumentViewerStore
    // 현재 제품 번들은 공개 producer가 없어 미지원이다. native 초기화 의존성으로만 설정한다.
    var commandFailureSupport: RhwpStudioCommandFailureSupport = .upstreamVersion1

    var body: some View {
        RhwpStudioContainerView(store: store, document: store.rhwpStudioDocument, commandFailureSupport: commandFailureSupport)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .sheet(
                item: recoverableDocumentOpenFailure,
                onDismiss: {
                    store.handleRecoverableDocumentOpenFailureDismissal()
                }
            ) { failure in
                RecoverableDocumentOpenFailureView(
                    failure: failure,
                    onDismiss: {
                        store.dismissRecoverableDocumentOpenFailure()
                    },
                    onRetry: {
                        store.retryDocumentOpen()
                    }
                )
            }
    }

    private var recoverableDocumentOpenFailure: Binding<RecoverableDocumentOpenFailure?> {
        Binding(
            get: {
                store.recoverableDocumentOpenFailure
            },
            set: { failure in
                guard failure == nil,
                      store.recoverableDocumentOpenFailure != nil else {
                    return
                }
                store.dismissRecoverableDocumentOpenFailure()
            }
        )
    }
}

private struct RecoverableDocumentOpenFailureView: View {
    let failure: RecoverableDocumentOpenFailure
    let onDismiss: () -> Void
    let onRetry: () -> Void

    @FocusState private var isRetryFocused: Bool

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.badge.ellipsis")
                .font(.system(size: 38))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(failure.title)
                    .font(.headline)
                Text(failure.message)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Button(role: .cancel) {
                    onDismiss()
                } label: {
                    Text("닫기")
                }
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("닫기")
                .accessibilityHint("문서 열기 오류 안내를 닫습니다.")

                Button {
                    onRetry()
                } label: {
                    Label("다시 시도", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut(.defaultAction)
                .focused($isRetryFocused)
                .accessibilityLabel("다시 시도")
                .accessibilityHint("다른 HWP 또는 HWPX 파일을 선택합니다.")
            }
        }
        .padding(28)
        .frame(width: 440)
        .onAppear {
            isRetryFocused = true
        }
    }
}

private struct RhwpStudioContainerView: View {
    @ObservedObject var store: DocumentViewerStore
    let document: RhwpStudioDocumentPayload?
    let commandFailureSupport: RhwpStudioCommandFailureSupport

    var body: some View {
        ZStack {
            if let failure = store.webViewFailure {
                WebViewerFallbackView(
                    failure: failure,
                    store: store,
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
                    loadID: store.webViewLoadID,
                    onEditorSessionChange: { session in store.updateEditorSession(session) },
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
                    onFailure: { failure in store.setWebViewFailure(failure) },
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
                            store.loadDocument(from: url, source: .fileDrop)
                        }
                    },
                    onDocumentSaved: { savedDocument in store.recordSavedDocument(savedDocument) },
                    onCommandFailure: { failure in
                        // 성공 통지를 지연 Task로 넘겨 문서 교체 뒤 표시하지 않도록 한다.
                        store.presentCommandFailure(failure)
                    },
                    onEditorImage: { store.preserveEditorImage($0) },
                    commandFailureSupport: commandFailureSupport
                )
                .allowsHitTesting(!store.isLoading)

                if store.isLoading || store.isWebViewLoading {
                    LoadingOverlayView(message: store.isLoading ? "불러오는 중..." : "웹 viewer 로딩 중...")
                }

                if store.commandFailurePresentation.isVisible {
                    CommandFailureBanner(presentation: store.commandFailurePresentation,
                                         onDismiss: store.dismissCommandFailure)
                        .padding(.top, 12)
                        .frame(maxHeight: .infinity, alignment: .top)
                } else if let message = store.webViewErrorMessage {
                    WebViewerErrorBanner(
                        message: message,
                        onDismiss: {
                            store.dismissWebViewError()
                        }
                    )
                        .padding(.top, 12)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
                if !store.commandFailurePresentation.isVisible,
                   store.webViewErrorMessage == nil,
                   store.commandFailurePresentation.failure != nil {
                    Button("최근 오류 진단", action: store.showCommandFailure)
                        .padding(12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
        }
        // Studio 내부 생성·저장의 bytes 변경은 같은 편집 세션이다.
        // WebView 교체로 epoch/sequence를 초기화하지 않고 명시적 loadID로만 로드한다.
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

private struct CommandFailureBanner: View {
    let presentation: RhwpStudioCommandFailurePresentation
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                Text(presentation.message).fixedSize(horizontal: false, vertical: true)
                Button(action: onDismiss) { Image(systemName: "xmark") }
                    .buttonStyle(.plain).accessibilityLabel("알림 닫기")
            }
            if presentation.occurrenceCount > 1 {
                Text("같은 작업 오류 \(presentation.occurrenceCount)회").foregroundStyle(.secondary)
            }
            DisclosureGroup("진단 정보") {
                Text(presentation.failure?.diagnostic ?? "")
                    .font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                Button("진단 복사") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(presentation.failure?.diagnostic ?? "", forType: .string)
                }
            }
        }
        .font(.caption)
        .padding(12)
        .frame(maxWidth: 520, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
    }
}

private struct WebViewerFallbackView: View {
    let failure: RhwpStudioWebViewFailure
    @ObservedObject var store: DocumentViewerStore
    let canRevealInFinder: Bool
    let onRetry: () -> Void
    let onOpenDocument: () -> Void
    let onRevealInFinder: () -> Void
    @State private var showsReferenceImage = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { _ in
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32))
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text("문서를 계속 편집할 수 없습니다")
                        .font(.title3.weight(.semibold))
                    if let copy = store.previousSave {
                        Text("\(copy.savedAt.formatted(date: .omitted, time: .shortened)) 저장본을 보관하고 있습니다.\n그 이후의 변경사항은 포함되지 않습니다.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("마지막 저장 이후의 변경사항은 복구할 수 없습니다.")
                            .foregroundStyle(.secondary)
                    }
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    if store.previousSave != nil {
                        Button("저장본 복사…") { Task { await store.exportPreviousSave() } }
                            .buttonStyle(.borderedProminent)
                        Button("다시 열기", action: onRetry)
                    } else {
                        Button(store.rhwpStudioDocument == nil ? "다시 시작" : "다시 열기", action: onRetry)
                            .buttonStyle(.borderedProminent)
                    }
                }
                .controlSize(.large)
                .disabled(store.isRecoveryExporting || store.isConfirmingRecovery)

                if let message = store.recoveryMessage {
                    Text(message).font(.callout).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Menu("다른 작업") {
                    Button("다른 파일 열기…", action: onOpenDocument)
                    if canRevealInFinder { Button("Finder에서 보기", action: onRevealInFinder) }
                    if store.lastEditorImage != nil {
                        Divider()
                        Button("중단 시점 화면…") { showsReferenceImage = true }
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .disabled(store.isRecoveryExporting || store.isConfirmingRecovery)

                ErrorReportDisclosure(report: store.errorReport)
            }
            .padding(32)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showsReferenceImage) {
            VStack(alignment: .leading, spacing: 16) {
                Text("중단 시점 화면").font(.headline)
                if let image = store.lastEditorImage {
                    Image(nsImage: image).resizable().scaledToFit().frame(maxHeight: 300)
                }
                Text("참고용 화면이며 문서로 저장하거나 편집할 수 없습니다.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    Button("닫기") { showsReferenceImage = false }.keyboardShortcut(.cancelAction)
                }
            }
            .padding(24)
            .frame(width: 520)
        }
    }
}
