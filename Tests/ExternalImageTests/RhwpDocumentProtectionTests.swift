import Foundation
import XCTest

final class RhwpDocumentProtectionTests: XCTestCase {
    func testRawStatusMappingFailsClosedForUnknownValues() {
        XCTAssertEqual(RhwpDocumentProtection(status: 0), .plain)
        XCTAssertEqual(RhwpDocumentProtection(status: 1), .passwordProtected)
        XCTAssertEqual(RhwpDocumentProtection(status: 2), .unsupportedProtection)
        XCTAssertEqual(RhwpDocumentProtection(status: 3), .invalidOrUnknown)
        XCTAssertEqual(RhwpDocumentProtection(status: UInt32.max), .invalidOrUnknown)
    }

    func testPlainFixtureAndInvalidInputClassification() throws {
        let plain = try ExternalImageTestSupport.sampleData(at: "samples/basic/KTX.hwp")

        XCTAssertEqual(RhwpDocumentProtection.classify(data: plain), .plain)
        XCTAssertEqual(RhwpDocumentProtection.classify(data: Data()), .invalidOrUnknown)
        XCTAssertEqual(
            RhwpDocumentProtection.classify(data: Data("not a document".utf8)),
            .invalidOrUnknown
        )
    }

    func testUnsupportedDRMSignatureClassification() {
        let drm = Data([UInt8(0x9B)] + Array(" DRMONE  test-only fixture".utf8))

        XCTAssertEqual(
            RhwpDocumentProtection.classify(data: drm),
            .unsupportedProtection
        )
    }
}
