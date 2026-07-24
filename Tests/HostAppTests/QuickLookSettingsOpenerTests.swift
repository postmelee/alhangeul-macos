import XCTest

final class QuickLookSettingsOpenerTests: XCTestCase {
    func testModernRouteTargetsLoginItemsAndExtensionsSettings() {
        let route = QuickLookSettingsRoute.current(osMajorVersion: 13)

        XCTAssertEqual(
            route.targetURL.absoluteString,
            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"
        )
        XCTAssertEqual(
            route.fallbackURL.path,
            "/System/Applications/System Settings.app"
        )
        XCTAssertEqual(
            route.manualPath,
            "시스템 설정 > 일반 > 로그인 항목 및 확장 프로그램 > 확장 프로그램 > Quick Look"
        )
    }

    func testLegacyRouteTargetsExtensionsPreferencePane() {
        let route = QuickLookSettingsRoute.current(osMajorVersion: 12)

        XCTAssertEqual(
            route.targetURL.path,
            "/System/Library/PreferencePanes/Extensions.prefPane"
        )
        XCTAssertEqual(
            route.fallbackURL.path,
            "/System/Applications/System Preferences.app"
        )
        XCTAssertEqual(
            route.manualPath,
            "시스템 환경설정 > 확장 프로그램 > Quick Look"
        )
    }

    func testSuccessfulTargetDoesNotOpenFallback() {
        let route = QuickLookSettingsRoute.current(osMajorVersion: 13)
        var openedURLs: [URL] = []
        let opener = QuickLookSettingsOpener(route: route) { url in
            openedURLs.append(url)
            return true
        }

        XCTAssertEqual(opener.open(), .openedTarget)
        XCTAssertEqual(openedURLs, [route.targetURL])
    }

    func testFailedTargetOpensFallback() {
        let route = QuickLookSettingsRoute.current(osMajorVersion: 13)
        var openedURLs: [URL] = []
        let opener = QuickLookSettingsOpener(route: route) { url in
            openedURLs.append(url)
            return url == route.fallbackURL
        }

        XCTAssertEqual(opener.open(), .openedFallback)
        XCTAssertEqual(openedURLs, [route.targetURL, route.fallbackURL])
    }

    func testFailedTargetAndFallbackReturnsFailure() {
        let route = QuickLookSettingsRoute.current(osMajorVersion: 13)
        let opener = QuickLookSettingsOpener(route: route) { _ in false }

        XCTAssertEqual(opener.open(), .failed)
    }
}
