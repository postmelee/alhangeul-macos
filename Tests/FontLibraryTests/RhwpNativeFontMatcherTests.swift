import Foundation
import XCTest

@MainActor
final class RhwpNativeFontMatcherTests: XCTestCase {
    private func face(_ id: String, weight: Int = 400, source: String = "managed", limitation: String? = nil) -> StudioFontFace {
        .init(id: id, source: source, postScriptName: "Test-\(weight == 700 ? "Bold" : "Regular")",
            family: "Test Family", fullName: weight == 700 ? "Test Family Bold" : "Test Family",
            style: weight == 700 ? "Bold" : "Regular", aliases: ["한글 별칭"], weight: weight, traits: 0, limitation: limitation)
    }
    private func snapshot(_ faces: [StudioFontFace]) -> StudioFontSupplySnapshot {
        .init(identity: "test-catalog", faces: faces, omitted: 0, failure: nil,
            read: { _ in XCTFail("선택 단계는 bytes를 읽으면 안 됩니다"); throw StudioFontError.invalidRequest }, current: { true }, release: {})
    }
    private func resolve(_ faces: [StudioFontFace], _ family: String, weight: Int = 400) throws -> RhwpNativeFontMatcher.Selection {
        try RhwpNativeFontMatcher.resolve(snapshot: snapshot(faces), requests: [.init(key: "slot", family: family, weight: weight, slant: "normal")])[0]
    }
    func testOfficialFamilyStyleAliasesAndExactNames() throws {
        let faces = [face("regular"), face("bold", weight: 700)]
        XCTAssertEqual(try resolve(faces, "Test Family").id, "regular")
        XCTAssertEqual(try resolve(faces, "한글 별칭", weight: 700).id, "bold")
        // PS exact는 style을 억지로 바꾸지 않는다. native consumer는 이후 별도로 style을 검증한다.
        XCTAssertEqual(try resolve(faces, "Test-Regular", weight: 700).id, "regular")
        XCTAssertEqual(try resolve(faces, "missing").status, "absent")
    }
    func testManagedPriorityAndUnresolvedConflictBlockInstalledFace() throws {
        let installed = face("installed", source: "installed")
        XCTAssertEqual(try resolve([installed, face("managed")], "Test Family").id, "managed")
        let blocked = try resolve([installed, face("conflict", limitation: "conflict")], "한글 별칭")
        XCTAssertEqual(blocked.status, "unavailable"); XCTAssertNil(blocked.id)
    }
    func testAmbiguousAndDisabledInstalledDoNotSelectFirstCandidate() throws {
        XCTAssertEqual(try resolve([face("one", source: "installed"), face("two", source: "installed")], "Test Family").status, "unavailable")
        XCTAssertEqual(try resolve([face("one", source: "installed", limitation: "disabled")], "Test Family").status, "unavailable")
        XCTAssertEqual(try resolve([face("duplicate"), face("duplicate")], "Test Family").status, "unavailable")
    }
}
