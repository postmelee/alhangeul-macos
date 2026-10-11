import Foundation
import XCTest

final class FontLibraryLocationTests: XCTestCase {
    private let group = "XH6JHKYXV8.com.postmelee.alhangeul.font-library"

    func testAuthorizedContainerLocation() throws {
        let location = try FontLibraryLocation(groupIdentifier: group)
        let root = URL(fileURLWithPath: "/isolated/group", isDirectory: true)
        let url = try location.resolve(identity: .init(teamIdentifier: "XH6JHKYXV8", applicationGroups: [group])) {
            XCTAssertEqual($0, group)
            return root
        }
        XCTAssertEqual(url.path, "/isolated/group/Library/Application Support/FontLibrary/v1")
    }

    func testMissingEntitlementDoesNotEvenRequestContainer() throws {
        let location = try FontLibraryLocation(groupIdentifier: group)
        XCTAssertThrowsError(try location.resolve(identity: .init(teamIdentifier: "XH6JHKYXV8", applicationGroups: [])) { _ in
            XCTFail("권한 없는 컨테이너 조회 금지")
            return nil
        }) { XCTAssertEqual($0 as? FontLibraryLocationError, .missingEntitlement) }
    }

    func testWrongTeamCannotResolveGroup() throws {
        let location = try FontLibraryLocation(groupIdentifier: group)
        for team in [nil, "OTHERTEAM1", "XH6JHK"] as [String?] {
            XCTAssertThrowsError(try location.resolve(identity: .init(teamIdentifier: team, applicationGroups: [group])) { _ in
                XCTFail("다른 팀의 컨테이너 조회 금지")
                return nil
            }) { XCTAssertEqual($0 as? FontLibraryLocationError, .signingTeamMismatch) }
        }
    }

    func testUnavailableContainerNeverFallsBack() throws {
        let location = try FontLibraryLocation(groupIdentifier: group)
        let identity = FontLibrarySigningIdentity(teamIdentifier: "XH6JHKYXV8", applicationGroups: [group])
        XCTAssertThrowsError(try location.resolve(identity: identity) { _ in nil }) {
            XCTAssertEqual($0 as? FontLibraryLocationError, .containerUnavailable)
        }
        XCTAssertThrowsError(try location.resolve(identity: identity) { _ in URL(string: "https://example.com") }) {
            XCTAssertEqual($0 as? FontLibraryLocationError, .containerUnavailable)
        }
    }

    func testMalformedConfigurationIsRejected() {
        for value in ["", "$(GROUP)", "group.com.test", "XH6JHKYXV8", "XH6JHKYXV8..font", "XH6JHKYXV8../font"] {
            XCTAssertThrowsError(try FontLibraryLocation(groupIdentifier: value)) {
                XCTAssertEqual($0 as? FontLibraryLocationError, .invalidConfiguration)
            }
        }
    }

    func testUnentitledTestRunnerCannotUseProductionContainer() throws {
        let location = try FontLibraryLocation(groupIdentifier: group)
        XCTAssertThrowsError(try location.resolve()) {
            XCTAssertEqual($0 as? FontLibraryLocationError, .missingEntitlement)
        }
    }
}
