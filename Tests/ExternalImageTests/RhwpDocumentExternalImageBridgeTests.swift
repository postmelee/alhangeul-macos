import Foundation
import XCTest

final class RhwpDocumentExternalImageBridgeTests: XCTestCase {
    func testExternalImageStatusRawValueMapping() {
        let expected: [(UInt32, RhwpExternalImageOperationStatus)] = [
            (0, .ok),
            (1, .invalidHandle),
            (2, .invalidInput),
            (3, .invalidUTF8),
            (4, .referenceNotFound),
            (5, .alreadyLoaded),
            (6, .failure),
            (UInt32.max, .unknown(UInt32.max))
        ]

        for (rawValue, status) in expected {
            XCTAssertEqual(
                RhwpExternalImageOperationStatus(rawValue: rawValue),
                status
            )
        }
    }

    func testReferenceDecoderMapsExtensionAndIgnoresAdditiveFields() throws {
        let json = """
        [
          {
            "key": "binData:7",
            "binDataId": 7,
            "originalPath": "C:\\\\images\\\\sample.png",
            "basename": "sample.png",
            "extension": "png",
            "loaded": false,
            "futureField": {"enabled": true}
          }
        ]
        """

        let references = try RhwpDocument.decodeExternalImageReferences(
            from: Data(json.utf8)
        )

        XCTAssertEqual(
            references,
            [
                RhwpExternalImageReference(
                    key: "binData:7",
                    binDataId: 7,
                    originalPath: "C:\\images\\sample.png",
                    basename: "sample.png",
                    fileExtension: "png",
                    loaded: false
                )
            ]
        )
    }

    func testReferenceDecoderRejectsInvalidShapes() {
        let invalidPayloads = [
            """
            [{"key":"binData:1","binDataId":1,"originalPath":"a.png","basename":"a.png","extension":"png"}]
            """,
            """
            [{"key":"binData:1","binDataId":65536,"originalPath":"a.png","basename":"a.png","extension":"png","loaded":false}]
            """,
            """
            {"key":"binData:1","binDataId":1,"originalPath":"a.png","basename":"a.png","extension":"png","loaded":false}
            """
        ]

        for payload in invalidPayloads {
            XCTAssertThrowsError(
                try RhwpDocument.decodeExternalImageReferences(
                    from: Data(payload.utf8)
                )
            ) { error in
                XCTAssertEqual(
                    error as? RhwpExternalImageBridgeError,
                    .invalidReferencesJSON
                )
            }
        }
    }

    func testBridgeCallsUseFilenameReferencesAndMissingKeyContracts() throws {
        let document = try RhwpDocument(
            data: ExternalImageTestSupport.sampleData(at: "samples/basic/KTX.hwp"),
            filename: "KTX.hwp"
        )

        XCTAssertEqual(document.setFileName("한글 KTX.hwp"), .ok)
        XCTAssertEqual(try document.externalImageReferences(), [])
        XCTAssertEqual(
            document.injectExternalImage(
                key: "not-a-reference",
                data: Data([0x01]),
                displayPath: nil
            ),
            .referenceNotFound
        )
    }

    func testBridgeRejectsEmptyInjectionInputs() throws {
        let document = try RhwpDocument(
            data: ExternalImageTestSupport.sampleData(at: "samples/basic/KTX.hwp"),
            filename: "KTX.hwp"
        )

        XCTAssertEqual(
            document.injectExternalImage(
                key: "",
                data: Data([0x01]),
                displayPath: ""
            ),
            .invalidInput
        )
        XCTAssertEqual(
            document.injectExternalImage(
                key: "not-a-reference",
                data: Data(),
                displayPath: ""
            ),
            .invalidInput
        )
    }

    func testRepeatedReferenceQueriesRemainStable() throws {
        let document = try RhwpDocument(
            data: ExternalImageTestSupport.sampleData(at: "samples/basic/KTX.hwp"),
            filename: "KTX.hwp"
        )

        for _ in 0..<128 {
            XCTAssertEqual(try document.externalImageReferences(), [])
        }
    }

    func testImageDataCopyAndLengthRemainStableUnderAllocationPressure() throws {
        let document = try RhwpDocument(
            data: ExternalImageTestSupport.sampleData(at: "samples/복학원서.hwp"),
            filename: "복학원서.hwp"
        )
        let expected = try XCTUnwrap(document.imageData(binDataId: 1))

        XCTAssertFalse(expected.isEmpty)
        XCTAssertEqual(document.imageDataLength(binDataId: 1), expected.count)

        for index in 0..<128 {
            let pressure = Data(
                repeating: UInt8(truncatingIfNeeded: index),
                count: expected.count + index
            )
            XCTAssertEqual(document.imageData(binDataId: 1), expected)
            XCTAssertEqual(document.imageDataLength(binDataId: 1), expected.count)
            XCTAssertEqual(pressure.count, expected.count + index)
        }
    }

    func testCopiedImageDataOutlivesDocument() throws {
        let copiedImage: Data = try {
            let document = try RhwpDocument(
                data: ExternalImageTestSupport.sampleData(at: "samples/복학원서.hwp"),
                filename: "복학원서.hwp"
            )
            return try XCTUnwrap(document.imageData(binDataId: 1))
        }()

        let expectedCount = copiedImage.count
        let expectedPrefix = Data(copiedImage.prefix(32))
        let pressure = (0..<128).map {
            Data(repeating: UInt8(truncatingIfNeeded: $0), count: expectedCount + $0)
        }
        let reopenedDocument = try RhwpDocument(
            data: ExternalImageTestSupport.sampleData(at: "samples/복학원서.hwp"),
            filename: "복학원서.hwp"
        )

        XCTAssertFalse(copiedImage.isEmpty)
        XCTAssertEqual(copiedImage.count, expectedCount)
        XCTAssertEqual(Data(copiedImage.prefix(32)), expectedPrefix)
        XCTAssertEqual(copiedImage, reopenedDocument.imageData(binDataId: 1))
        XCTAssertEqual(pressure.count, 128)
    }

    func testImageDataRejectsInvalidIdentifiers() throws {
        let document = try RhwpDocument(
            data: ExternalImageTestSupport.sampleData(at: "samples/복학원서.hwp"),
            filename: "복학원서.hwp"
        )

        XCTAssertNil(document.imageData(binDataId: 0))
        XCTAssertNil(document.imageDataLength(binDataId: 0))
        XCTAssertNil(document.imageData(binDataId: UInt16.max))
        XCTAssertNil(document.imageDataLength(binDataId: UInt16.max))
    }
}
