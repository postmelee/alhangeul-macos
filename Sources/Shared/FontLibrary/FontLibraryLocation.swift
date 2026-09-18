import Foundation
import Security

struct FontLibrarySigningIdentity {
    let teamIdentifier: String?
    let applicationGroups: [String]
}

enum FontLibraryLocationError: Error, Equatable {
    case invalidConfiguration
    case missingEntitlement
    case signingTeamMismatch
    case containerUnavailable
}

struct FontLibraryLocation {
    static let infoKey = "AlhangeulFontLibraryGroupIdentifier"
    let groupIdentifier: String

    init(bundle: Bundle = .main) throws {
        guard let identifier = bundle.object(forInfoDictionaryKey: Self.infoKey) as? String else {
            throw FontLibraryLocationError.invalidConfiguration
        }
        try self.init(groupIdentifier: identifier)
    }

    init(groupIdentifier: String) throws {
        let components = groupIdentifier.split(separator: ".", omittingEmptySubsequences: false)
        guard let team = components.first, team.count == 10, components.count > 1,
              team.utf8.allSatisfy({ (65...90).contains($0) || (48...57).contains($0) }),
              components.dropFirst().allSatisfy({ part in
                  !part.isEmpty && part.utf8.allSatisfy {
                      (65...90).contains($0) || (97...122).contains($0)
                          || (48...57).contains($0) || $0 == 45
                  }
              }) else { throw FontLibraryLocationError.invalidConfiguration }
        self.groupIdentifier = groupIdentifier
    }

    func resolve() throws -> URL {
        try resolve(identity: Self.currentIdentity()) { identifier in
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
        }
    }

    // 테스트는 서명/컨테이너 조회를 주입한다. 제품은 위 resolve()만 사용한다.
    func resolve(identity: FontLibrarySigningIdentity, container: (String) -> URL?) throws -> URL {
        guard identity.applicationGroups.contains(groupIdentifier) else {
            throw FontLibraryLocationError.missingEntitlement
        }
        guard let team = identity.teamIdentifier, groupIdentifier.hasPrefix(team + ".") else {
            throw FontLibraryLocationError.signingTeamMismatch
        }
        guard let root = container(groupIdentifier), root.isFileURL else {
            throw FontLibraryLocationError.containerUnavailable
        }
        return root.appendingPathComponent("Library/Application Support/FontLibrary/v1", isDirectory: true)
    }

    private static func currentIdentity() -> FontLibrarySigningIdentity {
        var code: SecCode?
        var staticCode: SecStaticCode?
        var info: CFDictionary?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
              SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
              SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info)
                == errSecSuccess, let values = info as? [String: Any] else {
            return FontLibrarySigningIdentity(teamIdentifier: nil, applicationGroups: [])
        }
        let entitlements = values[kSecCodeInfoEntitlementsDict as String] as? [String: Any]
        return FontLibrarySigningIdentity(
            teamIdentifier: values[kSecCodeInfoTeamIdentifier as String] as? String,
            applicationGroups: entitlements?["com.apple.security.application-groups"] as? [String] ?? []
        )
    }
}
