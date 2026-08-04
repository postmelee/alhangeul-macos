import Foundation
import XCTest

final class DocumentSaveFormatTests: XCTestCase {
    func testRawBridgeFormatsAreDecoded() {
        XCTAssertEqual(DocumentSaveFormat(rawValue: "hwp"), .hwp)
        XCTAssertEqual(DocumentSaveFormat(rawValue: "hwpx"), .hwpx)
        XCTAssertNil(DocumentSaveFormat(rawValue: "HWPX"))
        XCTAssertNil(DocumentSaveFormat(rawValue: "pdf"))
    }

    func testFilenameInferenceIsCaseInsensitive() {
        XCTAssertEqual(DocumentSaveFormat(filename: "sample.hwp"), .hwp)
        XCTAssertEqual(DocumentSaveFormat(filename: "sample.HWPX"), .hwpx)
        XCTAssertNil(DocumentSaveFormat(filename: "sample.txt"))
    }

    func testResolvePrefersSourceURLThenFilenameThenHwpDefault() {
        XCTAssertEqual(
            DocumentSaveFormat.resolve(
                sourceURL: URL(fileURLWithPath: "/tmp/source.hwpx"),
                filename: "display.hwp"
            ),
            .hwpx
        )
        XCTAssertEqual(
            DocumentSaveFormat.resolve(sourceURL: nil, filename: "display.HWPX"),
            .hwpx
        )
        XCTAssertEqual(
            DocumentSaveFormat.resolve(
                sourceURL: URL(fileURLWithPath: "/tmp/source.txt"),
                filename: "display.unknown"
            ),
            .hwp
        )
    }

    func testNormalizedFilenameReplacesSupportedExtension() {
        XCTAssertEqual(
            DocumentSaveFormat.hwpx.normalizedFilename("sample.hwp"),
            "sample.hwpx"
        )
        XCTAssertEqual(
            DocumentSaveFormat.hwp.normalizedFilename("sample.HWPX"),
            "sample.hwp"
        )
        XCTAssertEqual(
            DocumentSaveFormat.hwpx.normalizedFilename("sample.final.hwp"),
            "sample.final.hwpx"
        )
    }

    func testNormalizedFilenameCollapsesRepeatedSupportedExtensions() {
        XCTAssertEqual(
            DocumentSaveFormat.hwpx.normalizedFilename("sample.hwp.hwpx"),
            "sample.hwpx"
        )
        XCTAssertEqual(
            DocumentSaveFormat.hwp.normalizedFilename("sample.hwpx.HWP"),
            "sample.hwp"
        )
    }

    func testNormalizedFilenameUsesDefaultForBlankName() {
        XCTAssertEqual(DocumentSaveFormat.hwp.normalizedFilename("  \n"), "document.hwp")
        XCTAssertEqual(DocumentSaveFormat.hwpx.normalizedFilename(""), "document.hwpx")
    }

    func testNormalizedFilenamePreservesUnsupportedExtensionAsPartOfStem() {
        XCTAssertEqual(
            DocumentSaveFormat.hwp.normalizedFilename("sample.txt"),
            "sample.txt.hwp"
        )
        XCTAssertEqual(
            DocumentSaveFormat.hwpx.normalizedFilename("sample.final.txt"),
            "sample.final.txt.hwpx"
        )
    }

    func testNormalizedDestinationURLUsesSelectedFormat() {
        let selectedURL = URL(fileURLWithPath: "/tmp/sample.HWP")

        XCTAssertEqual(
            DocumentSaveFormat.hwpx.normalizedDestinationURL(selectedURL).path,
            "/tmp/sample.hwpx"
        )
    }

    func testHwpSignatureAcceptsCfbAndRejectsZip() {
        let cfb = Data([0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1, 0x00])
        let zip = Data([0x50, 0x4B, 0x03, 0x04, 0x00])

        XCTAssertTrue(DocumentSaveFormat.hwp.matchesPayloadSignature(cfb))
        XCTAssertFalse(DocumentSaveFormat.hwp.matchesPayloadSignature(zip))
        XCTAssertFalse(DocumentSaveFormat.hwp.matchesPayloadSignature(Data()))
    }

    func testHwpxSignatureAcceptsZipVariantsAndRejectsCfb() {
        let zipVariants = [
            Data([0x50, 0x4B, 0x03, 0x04, 0x00]),
            Data([0x50, 0x4B, 0x05, 0x06, 0x00]),
            Data([0x50, 0x4B, 0x07, 0x08, 0x00])
        ]
        let cfb = Data([0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1])

        for zip in zipVariants {
            XCTAssertTrue(DocumentSaveFormat.hwpx.matchesPayloadSignature(zip))
        }
        XCTAssertFalse(DocumentSaveFormat.hwpx.matchesPayloadSignature(cfb))
        XCTAssertFalse(DocumentSaveFormat.hwpx.matchesPayloadSignature(Data([0x50, 0x4B])))
    }
}
