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

    func testBundledPDFMenuIsCapturedAndCanonicalizedToNativeExportCommand() {
        let source = RhwpStudioHostBridgeScript.source
        XCTAssertTrue(source.contains("\"file:print-to-pdf\""))
        XCTAssertTrue(source.contains("command === \"file:print-to-pdf\""))
        XCTAssertTrue(source.contains("? \"file:export-pdf\""))
        XCTAssertTrue(source.contains("command: canonicalCommand"))
        XCTAssertTrue(source.contains("알한글에서 PDF 파일로 저장합니다."))
    }

    func testPDFExportUsesPageSVGsWithoutHwpBytePayload() throws {
        let section = try sourceSection(
            from: "async function exportPDFDocument(requestID)",
            to: "async function printDocument()"
        )

        XCTAssertTrue(section.contains("documentPages()"))
        XCTAssertTrue(section.contains("type: \"export-pdf-document\""))
        XCTAssertTrue(section.contains("type: \"export-pdf-error\""))
        XCTAssertTrue(section.contains("requestID,"))
        XCTAssertTrue(section.contains("pageCount,"))
        XCTAssertTrue(section.contains("pages"))
        XCTAssertTrue(
            RhwpStudioHostBridgeScript.source.contains(
                "__alhangeulHostBridgeExportPDFDocument = (requestID)"
            )
        )
        XCTAssertTrue(
            RhwpStudioHostBridgeScript.source.contains("Number.isInteger(requestID)")
        )
        XCTAssertTrue(
            RhwpStudioHostBridgeScript.source.contains("exportPDFDocument(requestID);")
        )
        XCTAssertFalse(section.contains("requestHwpExportPayload"))
        XCTAssertFalse(section.contains("exportHwp"))
        XCTAssertFalse(section.contains("base64"))
        XCTAssertFalse(section.contains("byteCount"))
    }

    func testNativePDFMenuOverrideIsReappliedAfterAttributeChanges() {
        let source = RhwpStudioHostBridgeScript.source
        XCTAssertTrue(source.contains("overrideNativePDFMenuItem();"))
        XCTAssertTrue(source.contains("nativePDFMenuItemObserver.observe(item"))
        XCTAssertTrue(source.contains("attributes: true"))
        XCTAssertTrue(
            source.contains(
                "attributeFilter: [\"class\", \"aria-disabled\", \"title\", \"aria-label\"]"
            )
        )
        XCTAssertTrue(source.contains("item.getAttribute(\"aria-label\") !== \"PDF로 저장\""))
        XCTAssertTrue(source.contains("item.setAttribute(\"aria-label\", \"PDF로 저장\")"))
        XCTAssertTrue(source.contains("if (pendingHostOverridesRefresh)"))
    }

    private func sourceSection(from start: String, to end: String) throws -> Substring {
        let source = RhwpStudioHostBridgeScript.source
        let startIndex = try XCTUnwrap(source.range(of: start)?.lowerBound)
        let endIndex = try XCTUnwrap(
            source.range(of: end, range: startIndex..<source.endIndex)?.lowerBound
        )
        return source[startIndex..<endIndex]
    }
}
