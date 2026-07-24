import SwiftUI

struct QuickLookConflictNoticeView: View {
    let presentation: QuickLookConflictPresentation
    let onAction: (QuickLookConflictNoticeAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 7) {
                    Text(presentation.title)
                        .font(.title2.weight(.semibold))
                    Text(presentation.explanation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let recommendation = presentation.recommendation {
                Label {
                    Text(recommendation)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                }
                .font(.subheadline.weight(.medium))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            HStack(spacing: 12) {
                noticeVersion(
                    title: "알한글 rhwp",
                    value: presentation.alhangeul.rhwp
                )

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                noticeVersion(
                    title: "HOP rhwp",
                    value: presentation.hop.rhwp
                )
            }

            Text("알한글은 HOP 확장을 자동으로 끄거나 현재 Quick Look provider를 변경하지 않습니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Button("나중에") {
                    onAction(.later)
                }

                Button("자세히 보기") {
                    onAction(.showDetails)
                }

                Spacer()

                Button("Quick Look 설정 열기") {
                    onAction(.openSettings)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520, height: 390)
    }

    private func noticeVersion(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.body, design: .monospaced).weight(.semibold))
                .textSelection(.enabled)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
