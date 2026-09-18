import CryptoKit
import Foundation
import XCTest

final class FontFileInspectorTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        let root = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Fixtures", withExtension: nil))
        return try Data(contentsOf: root.appendingPathComponent(name))
    }

    private func inspect(_ name: String) throws -> InspectedFont {
        try FontFileInspector().inspect(fixture(name), filename: name)
    }

    private func assertError(_ data: Data, _ expected: FontInspectionError,
                             limits: FontInspectionLimits = FontInspectionLimits(),
                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try FontFileInspector(limits: limits).inspect(data, filename: "test.ttf"),
                             file: file, line: line) { error in
            XCTAssertEqual(error as? FontInspectionError, expected, file: file, line: line)
        }
    }

    private func u16(_ data: Data, _ offset: Int) -> Int {
        Int(data[offset]) << 8 | Int(data[offset + 1])
    }

    private func u32(_ data: Data, _ offset: Int) -> Int {
        u16(data, offset) << 16 | u16(data, offset + 2)
    }

    private func tableRecord(_ data: Data, _ tag: String) throws -> Int {
        try XCTUnwrap((0..<u16(data, 4)).map { 12 + $0 * 16 }.first {
            String(data: data[$0..<($0 + 4)], encoding: .ascii) == tag
        })
    }

    private func tableStart(_ data: Data, _ tag: String) throws -> Int {
        u32(data, try tableRecord(data, tag) + 8)
    }

    private func put16(_ data: inout Data, _ offset: Int, _ value: UInt16) {
        data[offset] = UInt8(value >> 8); data[offset + 1] = UInt8(value & 255)
    }

    private func put32(_ data: inout Data, _ offset: Int, _ value: UInt32) {
        put16(&data, offset, UInt16(value >> 16)); put16(&data, offset + 2, UInt16(value & 65535))
    }

    func testStaticTrueTypeMetadataAndKoreanNames() throws {
        let result = try inspect("regular.ttf")
        XCTAssertEqual(result.object.format, .trueType)
        XCTAssertEqual(result.object.faceCount, 1)
        XCTAssertEqual(result.faces[0].id.sfntIndex, 0)
        XCTAssertEqual(result.faces[0].id.objectHash, result.object.sha256)
        XCTAssertEqual(result.faces[0].postScriptName, "AlhangeulFixture-Regular")
        XCTAssertEqual(result.faces[0].weightClass, 400)
        XCTAssertEqual(result.faces[0].widthClass, 5)
        XCTAssertEqual(result.faces[0].glyphCount, 3)
        XCTAssertEqual(result.faces[0].embeddingFlags, 0)
        XCTAssertEqual(result.faces[0].applicationSupport, .staticCandidate)
        XCTAssertTrue(result.faces[0].names.contains { $0.languageID == 0x0412 && $0.value == "알한글 검증 글꼴" })
        XCTAssertFalse(result.filenameExtensionMismatch)
        let roundTrip = try JSONDecoder().decode(FontFace.self, from: JSONEncoder().encode(result.faces[0]))
        XCTAssertEqual(roundTrip, result.faces[0])
    }

    func testCFFAndBoldAreIndependentFaces() throws {
        let otf = try inspect("regular.otf"), regular = try inspect("regular.ttf"), bold = try inspect("bold.ttf")
        XCTAssertEqual(otf.object.format, .openTypeCFF)
        XCTAssertEqual(otf.faces[0].postScriptName, "AlhangeulFixtureCFF-Regular")
        XCTAssertEqual(bold.faces[0].weightClass, 700)
        XCTAssertEqual(bold.faces[0].familyName, regular.faces[0].familyName)
        XCTAssertNotEqual(bold.faces[0].id, regular.faces[0].id)
    }

    func testCollectionUsesSFNTIndexAndNeverClaimsFaceSelection() throws {
        let result = try inspect("two-face.ttc")
        XCTAssertEqual(result.object.format, .collection)
        XCTAssertEqual(result.object.faceCount, 2)
        XCTAssertEqual(result.faces.map(\.id.sfntIndex), [0, 1])
        XCTAssertEqual(result.faces.map(\.postScriptName), ["AlhangeulFixture-Regular", "AlhangeulFixture-Bold"])
        XCTAssertTrue(result.faces.allSatisfy { $0.applicationSupport == .collectionFaceSelectionUnverified })
    }

    func testVariableInstancesAreNotFaces() throws {
        let result = try inspect("variable.ttf")
        XCTAssertEqual(result.object.faceCount, 1)
        let face = result.faces[0]
        XCTAssertEqual(face.axes.count, 1)
        XCTAssertEqual(face.axes[0].tag, "wght")
        XCTAssertEqual(face.axes[0].minimum, 100)
        XCTAssertEqual(face.axes[0].defaultValue, 400)
        XCTAssertEqual(face.axes[0].maximum, 900)
        XCTAssertEqual(face.namedInstances.count, 1)
        XCTAssertEqual(face.namedInstances[0].coordinates["wght"], 700)
        XCTAssertEqual(face.applicationSupport, .variableSelectionUnverified)
    }

    func testSameBytesSameIdentityAndExtensionCannotDisguiseFormat() throws {
        let data = try fixture("regular.ttf")
        let first = try FontFileInspector().inspect(data, filename: "font.ttf")
        let second = try FontFileInspector().inspect(data, filename: "다른이름.HFT")
        XCTAssertEqual(first.object, second.object)
        XCTAssertTrue(second.filenameExtensionMismatch)
        XCTAssertEqual(first.object.sha256, SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined())
        assertError(Data("HFT unsupported bytes".utf8), .unsupportedFormat)
    }

    func testEmptyTruncatedAndSizeBoundaries() throws {
        assertError(Data(), .emptyFile)
        assertError(Data([0, 1]), .malformedStructure)
        let data = try fixture("regular.ttf")
        assertError(Data(data.prefix(40)), .malformedStructure)
        var limits = FontInspectionLimits()
        limits.maximumFileBytes = data.count - 1
        assertError(data, .fileTooLarge, limits: limits)
        limits.maximumFileBytes = data.count
        XCTAssertNoThrow(try FontFileInspector(limits: limits).inspect(data, filename: "f.ttf"))
        // Data 시작 index가 0이 아닌 입력도 처리한다.
        let prefixed = Data([1, 2, 3]) + data
        XCTAssertEqual(try FontFileInspector().inspect(prefixed.dropFirst(3), filename: "f.ttf").object,
                       try inspect("regular.ttf").object)
    }

    func testTableOverflowOverlapAndDuplicateTag() throws {
        let original = try fixture("regular.ttf")
        var data = original
        put32(&data, 20, UInt32.max)
        assertError(data, .malformedStructure)
        data = original
        put32(&data, 24, UInt32.max)
        assertError(data, .malformedStructure)
        data = original
        put32(&data, 20, 0)
        assertError(data, .malformedStructure)
        data = original
        data.replaceSubrange(28..<32, with: original[12..<16])
        assertError(data, .malformedStructure)
    }

    func testNamesStayWithinTheirOwnTableAndRespectBudget() throws {
        let original = try fixture("regular.ttf")
        var data = original
        let name = try tableStart(data, "name")
        put16(&data, name + 6 + 8, 65535)
        assertError(data, .malformedStructure)
        data = original
        put16(&data, name + 4, 0)
        assertError(data, .malformedStructure)
        var limits = FontInspectionLimits()
        limits.maximumNameBytes = 1
        assertError(original, .metadataLimitExceeded, limits: limits)
    }

    func testLanguageTagsAndUnknownEncodingPreserveOriginalNames() throws {
        let tagged = try inspect("language-tag.ttf")
        XCTAssertTrue(tagged.faces[0].names.contains {
            $0.languageID == 0x8000 && $0.languageTag == "ko-KR" && $0.value == "알한글 검증 글꼴"
        })
        var data = try fixture("regular.ttf")
        let name = try tableStart(data, "name")
        let record = try XCTUnwrap((0..<u16(data, name + 2)).map { name + 6 + $0 * 12 }.first {
            u16(data, $0 + 4) == 0x0412
        })
        // 지원하지 않는 인코딩은 Unicode로 오해하지 않고 원문을 보존한다.
        put16(&data, record + 2, 2)
        let unknown = try FontFileInspector().inspect(data, filename: "unknown.ttf")
        let preserved = try XCTUnwrap(unknown.faces[0].names.first {
            $0.languageID == 0x0412 && $0.encodingID == 2
        })
        XCTAssertNil(preserved.value)
        XCTAssertFalse(preserved.bytes.isEmpty)
    }

    func testInvalidLanguageTagReferenceAndVariableNameAreRejected() throws {
        var data = try fixture("language-tag.ttf")
        let name = try tableStart(data, "name")
        let record = try XCTUnwrap((0..<u16(data, name + 2)).map { name + 6 + $0 * 12 }.first {
            u16(data, $0 + 4) == 0x8000
        })
        put16(&data, record + 4, 0x8001)
        assertError(data, .malformedStructure)
        data = try fixture("variable.ttf")
        let fvar = try tableStart(data, "fvar")
        put16(&data, fvar + u16(data, fvar + 4) + 18, 65534)
        assertError(data, .malformedStructure)
    }

    func testCollectionCountAndOffsetsAreBounded() throws {
        var data = try fixture("two-face.ttc")
        put32(&data, 8, UInt32.max)
        assertError(data, .metadataLimitExceeded)
        data = try fixture("two-face.ttc")
        put32(&data, 16, UInt32(u32(data, 12)))
        assertError(data, .malformedStructure)
    }

    func testVariableAxisRangeAndInstanceBounds() throws {
        let original = try fixture("variable.ttf")
        var data = original
        let fvar = try tableStart(data, "fvar")
        let axes = fvar + u16(data, fvar + 4)
        put32(&data, axes + 4, 800 << 16)
        assertError(data, .malformedStructure)
        data = original
        put16(&data, fvar + 14, 1)
        assertError(data, .malformedStructure)
        var limits = FontInspectionLimits()
        limits.maximumInstances = 0
        assertError(original, .metadataLimitExceeded, limits: limits)
    }

    func testCmapAndLocaOffsetsCannotEscapeTables() throws {
        var data = try fixture("regular.ttf")
        let cmap = try tableStart(data, "cmap")
        put32(&data, cmap + 8, UInt32.max)
        assertError(data, .malformedStructure)
        data = try fixture("regular.ttf")
        let loca = try tableStart(data, "loca")
        put16(&data, loca, 65535)
        assertError(data, .malformedStructure)
    }

    func testEveryTruncatedFixturePrefixIsRejected() throws {
        // 마지막 alignment padding은 필수가 아니므로 앞부분 128 bytes의 잘림을 검사한다.
        for name in ["regular.ttf", "regular.otf", "two-face.ttc", "variable.ttf"] {
            let data = try fixture(name)
            for length in 0..<128 {
                XCTAssertThrowsError(try FontFileInspector().inspect(Data(data.prefix(length)), filename: name), "\(name):\(length)")
            }
        }
    }
}
