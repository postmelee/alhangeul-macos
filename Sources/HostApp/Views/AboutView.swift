import AppKit
import SwiftUI

struct AboutView: View {
    @StateObject private var extensionStatus = ExtensionStatusModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AboutHeaderView()

            Divider()
                .padding(.vertical, 18)

            VStack(alignment: .leading, spacing: 10) {
                AboutInfoRow(title: "버전", value: BuildInfo.version)
                AboutInfoRow(title: "빌드", value: BuildInfo.build)
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
        }
        .padding(24)
        .frame(width: 520)
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
