import AppKit
import SwiftUI
import XCTest

@MainActor
final class ErrorReportDisclosureTests: XCTestCase {
    private func elements(_ value: AnyObject) -> [AnyObject] {
        let children = value.accessibilityChildren?() ?? []
        return [value] + children.flatMap { elements($0 as AnyObject) }
    }
    private func find(_ identifier: String, in view: NSView) -> AnyObject? {
        elements(view).first { $0.accessibilityIdentifier?() == identifier }
    }
    func testDisclosureStartsCollapsedThenCopiesExactlyTheDisplayedReport() async throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.regular)
        NSApp.accessibilitySetValue(true, forAttribute: .init(rawValue: "AXEnhancedUserInterface"))
        let report = "알한글 오류 보고서\nerrorID=test-event\nmessage=경로가 비어있습니다\nline=1"
        var copied: [String] = []
        let pasteboard = NSPasteboard(name: .init("task594-test-" + UUID().uuidString))
        defer { pasteboard.releaseGlobally() }
        let view = NSHostingView(rootView: ErrorReportDisclosure(report: report, copyReport: {
            copied.append($0); return ErrorReportDisclosure.writeReport($0, to: pasteboard)
        })
            .padding(20).frame(width: 480))
        let window = NSWindow(contentRect: .init(x: 50, y: 50, width: 520, height: 400),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        window.makeKeyAndOrderFront(nil)
        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()
        defer { window.orderOut(nil); window.contentView = nil }
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertNil(find("copy-error-report", in: view))
        let disclosure = try XCTUnwrap(elements(view).first {
            $0.accessibilityRole?() == .disclosureTriangle && $0.accessibilityLabel?() == "오류 세부정보"
        })
        XCTAssertEqual(disclosure.accessibilityPerformPress?(), true)
        try await Task.sleep(nanoseconds: 600_000_000)
        let button = try XCTUnwrap(find("copy-error-report", in: view))
        if let output = ProcessInfo.processInfo.environment["TASK594_ERROR_UI_OUTPUT"] {
            view.displayIfNeeded()
            let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: bitmap)
            let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: output))
        }
        XCTAssertEqual(button.accessibilityPerformPress?(), true)
        XCTAssertEqual(copied, [report])
        XCTAssertEqual(pasteboard.string(forType: .string), report)
        XCTAssertNotNil(find("error-report-text", in: view))
        XCTAssertEqual(disclosure.accessibilityPerformPress?(), true)
        try await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertNil(find("copy-error-report", in: view))
        XCTAssertEqual(copied.count, 1)
    }
}
