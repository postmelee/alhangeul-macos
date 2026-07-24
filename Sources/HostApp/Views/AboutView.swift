import AppKit
import SwiftUI

struct AboutView: View {
    @StateObject private var extensionStatus = ExtensionStatusModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AboutHeaderView()

                Divider()
                    .padding(.vertical, 18)

                VStack(alignment: .leading, spacing: 10) {
                    AboutInfoRow(title: "버전", value: BuildInfo.version)
                    AboutInfoRow(title: "빌드", value: BuildInfo.build)
                    AboutInfoRow(title: "rhwp", value: BuildInfo.rhwpDisplayVersion)
                }

                Divider()
                    .padding(.vertical, 18)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("확장")
                            .font(.headline)

                        Spacer()

                        Button {
                            extensionStatus.refresh()
                        } label: {
                            Label("상태 새로고침", systemImage: "arrow.clockwise")
                        }
                        .controlSize(.small)
                    }

                    ForEach(ExtensionStatus.allCases, id: \.self) { status in
                        AboutExtensionRow(
                            status: status,
                            snapshot: extensionStatus.snapshot(for: status)
                        )
                    }
                }

                if case let .detected(snapshot) = extensionStatus.quickLookConflictState,
                   let presentation = QuickLookConflictPresentation(snapshot: snapshot) {
                    Divider()
                        .padding(.vertical, 18)

                    AboutQuickLookConflictCard(
                        presentation: presentation,
                        settingsOpener: QuickLookSettingsOpener(),
                        onRefresh: extensionStatus.refresh
                    )
                    .id(snapshot.fingerprint)
                }
            }
            .padding(24)
        }
        .frame(minWidth: 520, minHeight: 390)
        .task {
            extensionStatus.refresh()
        }
    }
}

private struct AboutHeaderView: View {
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 5) {
                Text(BuildInfo.displayName)
                    .font(.title2.weight(.semibold))
                Text("HWP/HWPX 문서 미리보기 및 viewer")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(BuildInfo.displayVersion)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct AboutInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .font(.subheadline)
    }
}

private struct AboutExtensionRow: View {
    let status: ExtensionStatus
    let snapshot: ExtensionStatusSnapshot

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: status.aboutSymbolName)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(status.title)
                    .font(.subheadline)
                Text(status.bundleIdentifier)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                VStack(alignment: .leading, spacing: 4) {
                    AboutStatusLine(
                        title: "앱 번들",
                        label: snapshot.bundle.label,
                        symbolName: snapshot.bundle.symbolName,
                        color: snapshot.bundle.color
                    )
                    AboutStatusLine(
                        title: "시스템 등록",
                        label: snapshot.registration.label,
                        symbolName: snapshot.registration.symbolName,
                        color: snapshot.registration.color
                    )
                }
                .padding(.top, 4)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct AboutStatusLine: View {
    let title: String
    let label: String
    let symbolName: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)

            Image(systemName: symbolName)
                .foregroundStyle(color)
                .frame(width: 14)

            Text(label)
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }
}

private struct AboutQuickLookConflictCard: View {
    let presentation: QuickLookConflictPresentation
    let settingsOpener: QuickLookSettingsOpener
    let onRefresh: () -> Void

    @State private var settingsOpenResult: QuickLookSettingsOpenResult?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)

                Text(presentation.title)
                    .font(.headline)
            }

            Text(presentation.explanation)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            if let recommendation = presentation.recommendation {
                Label {
                    Text(recommendation)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            AboutQuickLookVersionComparison(presentation: presentation)

            if presentation.usesVerifiedHopRhwpMapping {
                Text("HOP rhwp는 확인된 HOP Preview 버전 매핑을 기준으로 표시합니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("알한글은 HOP 확장의 활성 상태나 macOS가 현재 선택한 미리보기 provider를 확인하거나 변경하지 않습니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 4) {
                Text("변경 경로")
                    .font(.caption.weight(.semibold))
                Text(settingsOpener.manualPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            HStack(spacing: 10) {
                Button {
                    settingsOpenResult = settingsOpener.open()
                } label: {
                    Label("Quick Look 설정 열기", systemImage: "gearshape")
                }

                Button {
                    settingsOpenResult = nil
                    onRefresh()
                } label: {
                    Label("다시 확인", systemImage: "arrow.clockwise")
                }
            }

            if let feedback = settingsOpenFeedback {
                Label(feedback.message, systemImage: feedback.symbolName)
                    .font(.caption)
                    .foregroundStyle(feedback.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.25))
        }
        .accessibilityElement(children: .contain)
    }

    private var settingsOpenFeedback: (
        message: String,
        symbolName: String,
        color: Color
    )? {
        switch settingsOpenResult {
        case .none:
            return nil
        case .openedTarget:
            return (
                "시스템 설정 열기를 요청했습니다. 표시된 경로에서 Quick Look 항목을 확인해 주세요.",
                "checkmark.circle",
                .secondary
            )
        case .openedFallback:
            return (
                "상위 설정 화면을 열었습니다. 표시된 경로로 직접 이동해 주세요.",
                "info.circle",
                .secondary
            )
        case .failed:
            return (
                "설정 앱을 열 수 없습니다. 표시된 경로로 직접 이동해 주세요.",
                "exclamationmark.circle",
                .orange
            )
        }
    }
}

private struct AboutQuickLookVersionComparison: View {
    let presentation: QuickLookConflictPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            comparisonHeader
            Divider()
            comparisonRow(
                title: "앱",
                alhangeulValue: presentation.alhangeul.app,
                hopValue: presentation.hop.app
            )
            comparisonRow(
                title: "미리보기",
                alhangeulValue: presentation.alhangeul.preview,
                hopValue: presentation.hop.preview
            )
            comparisonRow(
                title: "rhwp",
                alhangeulValue: presentation.alhangeul.rhwp,
                hopValue: presentation.hop.rhwp
            )
        }
    }

    private var comparisonHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("")
                .frame(width: 62, alignment: .leading)
                .accessibilityHidden(true)
            Text("알한글")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("HOP")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.caption.weight(.semibold))
    }

    private func comparisonRow(
        title: String,
        alhangeulValue: String,
        hopValue: String
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 62, alignment: .leading)
            comparisonValue(alhangeulValue)
            comparisonValue(hopValue)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(title), 알한글 \(alhangeulValue), HOP \(hopValue)"
        )
    }

    private func comparisonValue(_ value: String) -> some View {
        Text(value)
            .font(.system(.caption, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
    }
}

private extension ExtensionStatus {
    var aboutSymbolName: String {
        switch self {
        case .preview:
            "doc.richtext"
        case .thumbnail:
            "rectangle.on.rectangle"
        }
    }
}
