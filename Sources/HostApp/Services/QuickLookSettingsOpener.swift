import AppKit
import Foundation

enum QuickLookSettingsOpenResult: Equatable {
    case openedTarget
    case openedFallback
    case failed
}

struct QuickLookSettingsRoute: Equatable {
    let targetURL: URL
    let fallbackURL: URL
    let manualPath: String

    static func current(
        osMajorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
    ) -> QuickLookSettingsRoute {
        if osMajorVersion >= 13 {
            return QuickLookSettingsRoute(
                targetURL: URL(
                    string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"
                )!,
                fallbackURL: URL(
                    fileURLWithPath: "/System/Applications/System Settings.app",
                    isDirectory: true
                ),
                manualPath: "시스템 설정 > 일반 > 로그인 항목 및 확장 프로그램 > 확장 프로그램 > Quick Look"
            )
        }

        return QuickLookSettingsRoute(
            targetURL: URL(
                fileURLWithPath: "/System/Library/PreferencePanes/Extensions.prefPane",
                isDirectory: true
            ),
            fallbackURL: URL(
                fileURLWithPath: "/System/Applications/System Preferences.app",
                isDirectory: true
            ),
            manualPath: "시스템 환경설정 > 확장 프로그램 > Quick Look"
        )
    }
}

struct QuickLookSettingsOpener {
    private let route: QuickLookSettingsRoute
    private let openURL: (URL) -> Bool

    init(
        route: QuickLookSettingsRoute = .current(),
        openURL: @escaping (URL) -> Bool = { NSWorkspace.shared.open($0) }
    ) {
        self.route = route
        self.openURL = openURL
    }

    var manualPath: String {
        route.manualPath
    }

    func open() -> QuickLookSettingsOpenResult {
        if openURL(route.targetURL) {
            return .openedTarget
        }

        if openURL(route.fallbackURL) {
            return .openedFallback
        }

        return .failed
    }
}
