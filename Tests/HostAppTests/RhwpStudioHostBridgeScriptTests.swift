import JavaScriptCore
import XCTest

final class RhwpStudioHostBridgeScriptTests: XCTestCase {
    func testRuntimeRejectionKeepsErrorMessageWhenWebKitStackContainsOnlyLocations() throws {
        let context = try XCTUnwrap(JSContext())
        context.evaluateScript("""
        var messages = [], listeners = {};
        var window = {
          location: {href: 'alhangeul-studio://bundle/index.html'},
          webkit: {messageHandlers: {alhangeulHost: {postMessage: value => messages.push(value)}}},
          addEventListener: (name, handler) => { listeners[name] = handler; }
        };
        """)
        context.evaluateScript(RhwpStudioHostBridgeScript.runtimeErrorSource)
        context.evaluateScript("""
        const error = new TypeError('TASK594_REJECTION_REASON');
        error.stack = 'global code@alhangeul-studio://bundle/assets/index-test.js:1:16';
        listeners.unhandledrejection({reason: error});
        """)
        XCTAssertNil(context.exception)
        let message = try XCTUnwrap(context.evaluateScript("messages[0]")?.toDictionary())
        XCTAssertEqual(message["type"] as? String, "runtime-error")
        XCTAssertEqual(message["message"] as? String, "Unhandled promise rejection")
        XCTAssertEqual(message["reason"] as? String,
            "TypeError: TASK594_REJECTION_REASON\nglobal code@alhangeul-studio://bundle/assets/index-test.js:1:16")
    }

    func testRuntimeErrorKeepsExistingStackAndNonErrorRejectionDetails() throws {
        let context = try XCTUnwrap(JSContext())
        context.evaluateScript("""
        var messages = [], listeners = {};
        var window = {
          location: {href: 'alhangeul-studio://bundle/index.html'},
          webkit: {messageHandlers: {alhangeulHost: {postMessage: value => messages.push(value)}}},
          addEventListener: (name, handler) => { listeners[name] = handler; }
        };
        """)
        context.evaluateScript(RhwpStudioHostBridgeScript.runtimeErrorSource)
        context.evaluateScript("""
        const error = new Error('TASK594');
        error.stack = 'Error: TASK594' + String.fromCharCode(10) + 'at index-test.js:1:2';
        listeners.error({error, message: error.message, filename: 'index-test.js', lineno: 1, colno: 2});
        listeners.unhandledrejection({reason: 'plain rejection'});
        listeners.unhandledrejection({reason: {code: 'REJECTED'}});
        """)
        XCTAssertNil(context.exception)
        XCTAssertEqual(context.evaluateScript("messages[0].reason")?.toString(), "Error: TASK594\nat index-test.js:1:2")
        XCTAssertEqual(context.evaluateScript("messages[1].reason")?.toString(), "plain rejection")
        XCTAssertEqual(context.evaluateScript("messages[2].reason")?.toString(), "{\"code\":\"REJECTED\"}")
    }

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
            to: "async function handleNativeCommand(command)"
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

    func testTextColorPickerAnchorGeometryExecutesVerifiedCoordinates() throws {
        let section = try sourceSection(
            from: "function textColorPickerAnchorGeometry(viewportHeight, buttonRect)",
            to: "function positionTextColorPickerAnchor()"
        )
        let context = try XCTUnwrap(JSContext())
        _ = context.evaluateScript(String(section))

        let cases = [
            (
                viewportHeight: 670.0,
                left: 914.0,
                bottom: 179.0,
                width: 32.0,
                height: 32.0,
                expectedTop: 427.0
            ),
            (
                viewportHeight: 713.5,
                left: 410.25,
                bottom: 142.75,
                width: 28.5,
                height: 28.5,
                expectedTop: 513.75
            )
        ]

        for testCase in cases {
            let result = context.evaluateScript(
                """
                JSON.stringify(textColorPickerAnchorGeometry(
                  \(testCase.viewportHeight),
                  {
                    left: \(testCase.left),
                    bottom: \(testCase.bottom),
                    width: \(testCase.width),
                    height: \(testCase.height)
                  }
                ))
                """
            )
            let json = try XCTUnwrap(result?.toString())
            let data = try XCTUnwrap(json.data(using: .utf8))
            let geometry = try JSONDecoder().decode(TextColorPickerAnchorGeometry.self, from: data)

            XCTAssertEqual(geometry.left, testCase.left, accuracy: 0.0001)
            XCTAssertEqual(geometry.top, testCase.expectedTop, accuracy: 0.0001)
            XCTAssertEqual(geometry.width, testCase.width, accuracy: 0.0001)
            XCTAssertEqual(geometry.height, testCase.height, accuracy: 0.0001)
        }
    }

    func testTextColorPickerAnchorUsesGeometryWithoutDuplicateWrites() throws {
        let section = try sourceSection(
            from: "function positionTextColorPickerAnchor()",
            to: "function handleTextColorPickerAnchorEvent(event)"
        )

        XCTAssertTrue(section.contains("document.getElementById(\"btn-text-color\")"))
        XCTAssertTrue(section.contains("document.getElementById(\"text-color-picker\")"))
        XCTAssertTrue(section.contains("button.getBoundingClientRect()"))
        XCTAssertTrue(
            section.contains(
                "textColorPickerAnchorGeometry(window.innerHeight, buttonRect)"
            )
        )
        XCTAssertTrue(section.contains("if (picker.style[property] !== value)"))
        XCTAssertTrue(section.contains("picker.style[property] = value"))
    }

    func testTextColorPickerAnchorRefreshesBeforeActivationAndOnResize() throws {
        let source = RhwpStudioHostBridgeScript.source
        let refreshSection = try sourceSection(
            from: "function refreshHostOverrides()",
            to: "let pendingHostOverridesRefresh"
        )
        let initializationSection = try sourceSection(
            from: "window.__alhangeulHostBridgeRunNativeCommand = (command) => {",
            to: "const nativeCommandObserver"
        )

        XCTAssertFalse(refreshSection.contains("positionTextColorPickerAnchor();"))
        let refreshRange = try XCTUnwrap(
            initializationSection.range(of: "refreshHostOverrides();")
        )
        let positionRange = try XCTUnwrap(
            initializationSection.range(of: "positionTextColorPickerAnchor();")
        )
        XCTAssertLessThan(refreshRange.lowerBound, positionRange.lowerBound)
        XCTAssertTrue(
            source.contains(
                "document.addEventListener(\"mousedown\", handleTextColorPickerAnchorEvent, true)"
            )
        )
        XCTAssertFalse(
            source.contains(
                "document.addEventListener(\"click\", handleTextColorPickerAnchorEvent, true)"
            )
        )
        XCTAssertTrue(
            source.contains(
                "window.addEventListener(\"resize\", positionTextColorPickerAnchor)"
            )
        )
    }

    private func sourceSection(from start: String, to end: String) throws -> Substring {
        let source = RhwpStudioHostBridgeScript.source
        let startIndex = try XCTUnwrap(source.range(of: start)?.lowerBound)
        let endIndex = try XCTUnwrap(
            source.range(of: end, range: startIndex..<source.endIndex)?.lowerBound
        )
        return source[startIndex..<endIndex]
    }

    private struct TextColorPickerAnchorGeometry: Decodable {
        let left: Double
        let top: Double
        let width: Double
        let height: Double
    }
}
