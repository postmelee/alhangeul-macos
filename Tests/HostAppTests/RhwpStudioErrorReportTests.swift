import XCTest

final class RhwpStudioErrorReportTests: XCTestCase {
    func testReportIncludesStableErrorIdentityVersionAndSession() {
        let id = UUID()
        let date = Date(timeIntervalSince1970: 1234567890)
        let session = RhwpStudioEditorSnapshot(loadID: 4, sequence: 9, documentEpoch: 2,
            changeSeq: 6, dirty: true, ready: true, pageCount: 3, format: "hwpx")
        let report = RhwpStudioErrorReport.make(errorID: id, occurredAt: date, category: "runtime",
            detail: "message=렌더링 오류: 경로가 비어있습니다\nline=1\ncolumn=234",
            additionalDetail: "code=513", session: session, loadID: 4, reloadToken: 1,
            environment: .init(appVersion: "0.4.0", appBuild: "300", osVersion: "macOS test", architecture: "arm64",
                core: .init(releaseTag: "v0.8.7", resolvedCommit: String(repeating: "a", count: 40))), privateValues: [])
        for value in [id.uuidString, "occurredAt=2009-02-13T23:31:30Z", "appVersion=0.4.0", "appBuild=300",
                      "architecture=arm64", "rhwpRelease=v0.8.7", "rhwpCommit=" + String(repeating: "a", count: 40),
                      "documentEpoch=2", "changeSeq=6", "dirty=true", "format=hwpx", "code=513",
                      "message=렌더링 오류: 경로가 비어있습니다", "line=1", "column=234"] {
            XCTAssertTrue(report.contains(value), value)
        }
    }
    func testRedactsNamesPathsAndURLParametersWhileKeepingStackLocation() {
        let detail = """
        filename=비공개 문서.hwpx
        payloadFilename=다른 문서.hwp
        lastURL=alhangeul-studio://app/index.html?filename=%EB%B9%84%EA%B3%B5%EA%B0%9C&token=secret#private
        sourceURL=alhangeul-studio://app/assets/index-ABC.js
        resolvedFilePath=/Users/test/Documents/비공개 문서.hwpx
        message=파일 접근 오류 '/Users/test/Documents/비공개 문서.hwpx'
        stack=TypeError at alhangeul-studio://app/assets/index-ABC.js:1:1234
        fileURL=file:///Users/test/Documents/other.hwpx
        """
        let output = RhwpStudioErrorReport.sanitize(detail, privateValues: ["비공개 문서.hwpx", "/Users/test"])
        for secret in ["비공개", "다른 문서", "/Users/", "other.hwpx", "secret", "#private", "filename=%"] {
            XCTAssertFalse(output.contains(secret), secret)
        }
        XCTAssertTrue(output.contains("index-ABC.js:1:1234"))
        XCTAssertTrue(output.contains("message=파일 접근 오류"))
    }
    func testUnknownMetadataAndMissingSessionStillProduceReadableReport() {
        let report = RhwpStudioErrorReport.make(errorID: UUID(), occurredAt: Date(), category: "navigation",
            detail: "domain=WebKitErrorDomain\ncode=102", additionalDetail: nil, session: nil,
            loadID: 0, reloadToken: 0, environment: .init(appVersion: "unknown", appBuild: "unknown",
                osVersion: "test", architecture: "arm64", core: nil), privateValues: [])
        XCTAssertTrue(report.contains("rhwpCommit=unknown"))
        XCTAssertTrue(report.contains("code=102"))
        XCTAssertFalse(report.contains("documentEpoch="))
    }
    func testExcessiveDiagnosticIsBoundedAndMarked() {
        let output = RhwpStudioErrorReport.sanitize(String(repeating: "가", count: 100_000), privateValues: [])
        XCTAssertLessThan(output.utf8.count, 17_000)
        XCTAssertTrue(output.hasSuffix("[이하 생략]"))
    }
}
