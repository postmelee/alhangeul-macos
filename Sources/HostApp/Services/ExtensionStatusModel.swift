import Foundation
import SwiftUI

enum ExtensionStatus: CaseIterable, Hashable {
    case preview
    case thumbnail

    var title: String {
        switch self {
        case .preview:
            "빠른 보기 미리보기"
        case .thumbnail:
            "빠른 보기 썸네일"
        }
    }

    var bundleIdentifier: String {
        switch self {
        case .preview:
            "com.postmelee.alhangeul.QLExtension"
        case .thumbnail:
            "com.postmelee.alhangeul.ThumbnailExtension"
        }
    }

    var appexBundleName: String {
        switch self {
        case .preview:
            "AlhangeulPreview.appex"
        case .thumbnail:
            "AlhangeulThumbnail.appex"
        }
    }
}

struct ExtensionStatusSnapshot: Equatable {
    var bundle: ExtensionBundleState
    var registration: ExtensionRegistrationState

    static let checking = ExtensionStatusSnapshot(bundle: .checking, registration: .checking)
}

enum ExtensionBundleState: Equatable {
    case checking
    case bundled
    case missing

    var label: String {
        switch self {
        case .checking:
            "확인 중"
        case .bundled:
            "앱에 포함됨"
        case .missing:
            "앱에 포함되지 않음"
        }
    }

    var symbolName: String {
        switch self {
        case .checking:
            "clock"
        case .bundled:
            "checkmark.circle.fill"
        case .missing:
            "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .checking:
            .secondary
        case .bundled:
            .green
        case .missing:
            .orange
        }
    }
}

enum ExtensionRegistrationState: Equatable {
    case checking
    case registered
    case disabled
    case missing
    case unavailable

    var label: String {
        switch self {
        case .checking:
            "확인 중"
        case .registered:
            "시스템 등록됨"
        case .disabled:
            "시스템 등록 비활성화됨"
        case .missing:
            "시스템 등록 없음"
        case .unavailable:
            "시스템 등록 확인 불가"
        }
    }

    var symbolName: String {
        switch self {
        case .checking:
            "clock"
        case .registered:
            "checkmark.circle.fill"
        case .disabled:
            "pause.circle.fill"
        case .missing:
            "exclamationmark.triangle.fill"
        case .unavailable:
            "questionmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .checking:
            .secondary
        case .registered:
            .green
        case .disabled:
            .orange
        case .missing:
            .orange
        case .unavailable:
            .secondary
        }
    }
}

@MainActor
final class ExtensionStatusModel: ObservableObject {
    @Published private var snapshots: [ExtensionStatus: ExtensionStatusSnapshot]

    init() {
        snapshots = Self.checkingSnapshots()
    }

    func state(for status: ExtensionStatus) -> ExtensionRegistrationState {
        snapshot(for: status).registration
    }

    func snapshot(for status: ExtensionStatus) -> ExtensionStatusSnapshot {
        snapshots[status, default: .checking]
    }

    func refresh() {
        snapshots = Self.checkingSnapshots()

        let appBundleURL = Bundle.main.bundleURL
        ExtensionSystemRegistrationRefresher.refresh(appBundleURL: appBundleURL)

        Task.detached {
            let snapshots = Dictionary(
                uniqueKeysWithValues: ExtensionStatus.allCases.map { status in
                    (status, Self.snapshot(for: status, appBundleURL: appBundleURL))
                }
            )

            await MainActor.run {
                self.snapshots = snapshots
            }
        }
    }

    private static func checkingSnapshots() -> [ExtensionStatus: ExtensionStatusSnapshot] {
        Dictionary(
            uniqueKeysWithValues: ExtensionStatus.allCases.map { status in
                (status, .checking)
            }
        )
    }

    nonisolated private static func snapshot(
        for status: ExtensionStatus,
        appBundleURL: URL
    ) -> ExtensionStatusSnapshot {
        let bundleState = bundleState(for: status, appBundleURL: appBundleURL)
        return ExtensionStatusSnapshot(
            bundle: bundleState,
            registration: registrationState(for: status, bundleState: bundleState)
        )
    }

    nonisolated private static func bundleState(
        for status: ExtensionStatus,
        appBundleURL: URL
    ) -> ExtensionBundleState {
        let appexURL = appBundleURL
            .appendingPathComponent("Contents/PlugIns", isDirectory: true)
            .appendingPathComponent(status.appexBundleName, isDirectory: true)

        guard FileManager.default.fileExists(atPath: appexURL.path),
              Bundle(url: appexURL)?.bundleIdentifier == status.bundleIdentifier
        else {
            return .missing
        }

        return .bundled
    }

    nonisolated private static func registrationState(
        for status: ExtensionStatus,
        bundleState: ExtensionBundleState
    ) -> ExtensionRegistrationState {
        switch bundleState {
        case .checking:
            return .checking
        case .bundled:
            // Sandboxed apps cannot reliably run /usr/bin/pluginkit for discovery:
            // PlugInKit reports unauthorized discovery from sandboxed clients.
            // The app refreshes LaunchServices with public APIs before this check.
            return .registered
        case .missing:
            return .missing
        }
    }
}
