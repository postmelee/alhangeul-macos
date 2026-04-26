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
            "com.postmelee.alhangeulmac.QLExtension"
        case .thumbnail:
            "com.postmelee.alhangeulmac.ThumbnailExtension"
        }
    }

    var appexBundleName: String {
        switch self {
        case .preview:
            "AlhangeulMacPreview.appex"
        case .thumbnail:
            "AlhangeulMacThumbnail.appex"
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
        ExtensionStatusSnapshot(
            bundle: bundleState(for: status, appBundleURL: appBundleURL),
            registration: registrationState(for: status)
        )
    }

    nonisolated private static func bundleState(
        for status: ExtensionStatus,
        appBundleURL: URL
    ) -> ExtensionBundleState {
        let appexURL = appBundleURL
            .appendingPathComponent("Contents/PlugIns", isDirectory: true)
            .appendingPathComponent(status.appexBundleName, isDirectory: true)

        return FileManager.default.fileExists(atPath: appexURL.path) ? .bundled : .missing
    }

    nonisolated private static func registrationState(for status: ExtensionStatus) -> ExtensionRegistrationState {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        process.arguments = ["-m", "-i", status.bundleIdentifier, "-v"]

        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error

        do {
            try process.run()
            process.waitUntilExit()

            let outputText = String(
                data: output.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            ) ?? ""
            _ = error.fileHandleForReading.readDataToEndOfFile()

            guard process.terminationStatus == 0 else {
                return .unavailable
            }

            guard let line = outputText
                .split(separator: "\n")
                .first(where: { $0.contains(status.bundleIdentifier) }) else {
                return .missing
            }

            return line.trimmingCharacters(in: .whitespaces).hasPrefix("-") ? .disabled : .registered
        } catch {
            return .unavailable
        }
    }
}
