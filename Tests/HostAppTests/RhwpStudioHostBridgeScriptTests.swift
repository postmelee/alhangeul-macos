import XCTest

final class RhwpStudioHostBridgeScriptTests: XCTestCase {
    func testNativeCommandSetContainsBothExplicitSaveFormats() {
        XCTAssertTrue(RhwpStudioHostBridgeScript.source.contains("\"file:save-as-hwp\""))
        XCTAssertTrue(RhwpStudioHostBridgeScript.source.contains("\"file:save-as-hwpx\""))
    }

    func testSaveExportMapsHwpxAndIncludesResponseFormat() {
        XCTAssertTrue(
            RhwpStudioHostBridgeScript.source.contains("requestRhwp(\"exportHwpx\")")
        )
        XCTAssertTrue(
            RhwpStudioHostBridgeScript.source.contains("__alhangeulHostBridgeExportSaveDocument")
        )
        XCTAssertTrue(RhwpStudioHostBridgeScript.source.contains("type: \"save-document\""))
        XCTAssertTrue(RhwpStudioHostBridgeScript.source.contains("format,"))
    }

    func testNotifySavedUsesUpstreamRpcAndSeparateSyncError() {
        XCTAssertTrue(
            RhwpStudioHostBridgeScript.source.contains("requestRhwp(\"notifySaved\", { fileName })")
        )
        XCTAssertTrue(
            RhwpStudioHostBridgeScript.source.contains("type: \"save-sync-error\"")
        )
    }
}
