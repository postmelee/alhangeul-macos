import XCTest

final class DocumentHTMLExportFormatTests: XCTestCase {
    private let html = Data("<!DOCTYPE html><html><body><p>한글</p></body></html>".utf8)

    func testFormatAndMIMEContracts() throws {
        XCTAssertEqual(DocumentHTMLExportFormat.doc.filename(for:"문서.hwpx"), "문서.doc")
        XCTAssertEqual(DocumentHTMLExportFormat.html.filename(for:"문서.hwp"), "문서.html")
        try DocumentHTMLExportFormat.doc.validateResponse(mime:"application/msword;charset=utf-8", filename:"문서.doc")
        XCTAssertThrowsError(try DocumentHTMLExportFormat.doc.validateResponse(mime:"text/html", filename:"문서.doc"))
        XCTAssertThrowsError(try DocumentHTMLExportFormat.html.validateResponse(mime:"text/html", filename:"문서.hwp"))
    }

    func testOutputMustBeHTMLWithMatchingDestination() throws {
        try DocumentHTMLExportFormat.doc.validate(data:html, destination:URL(fileURLWithPath:"/tmp/문서.doc"), source:nil)
        XCTAssertThrowsError(try DocumentHTMLExportFormat.html.validate(data:html, destination:URL(fileURLWithPath:"/tmp/문서.hwp"), source:nil))
        XCTAssertThrowsError(try DocumentHTMLExportFormat.doc.validate(data:Data("wrong".utf8), destination:URL(fileURLWithPath:"/tmp/문서.doc"), source:nil))
    }

    func testSourceAliasesCannotBeExportDestinations() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root, withIntermediateDirectories:false)
        defer { try? FileManager.default.removeItem(at:root) }
        let source = root.appendingPathComponent("source.hwp")
        let symlink = root.appendingPathComponent("symlink.doc")
        let hardlink = root.appendingPathComponent("hardlink.doc")
        try Data("original".utf8).write(to:source)
        try FileManager.default.createSymbolicLink(at:symlink, withDestinationURL:source)
        try FileManager.default.linkItem(at:source, to:hardlink)
        for url in [symlink, hardlink] {
            XCTAssertThrowsError(try DocumentHTMLExportFormat.doc.validate(data:html, destination:url, source:source))
        }
        XCTAssertEqual(try Data(contentsOf:source), Data("original".utf8))
    }
}
