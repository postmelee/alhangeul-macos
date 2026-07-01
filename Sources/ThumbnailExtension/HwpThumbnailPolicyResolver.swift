import Foundation

enum HwpThumbnailPolicyResolver {
    static let environmentKey = "ALHANGEUL_THUMBNAIL_RENDER_POLICY"

    static func resolve(
        environment: [String: String]? = nil
    ) -> HwpPageRenderPolicy {
#if DEBUG
        let environment = environment ?? ProcessInfo.processInfo.environment
        guard let rawValue = environment[environmentKey] else {
            return .coreGraphicsOnly
        }

        switch normalizedValue(rawValue) {
        case "skia", "skiaoptin":
            return .skiaOptIn
        case "coregraphics", "coregraphicsonly":
            return .coreGraphicsOnly
        default:
            return .coreGraphicsOnly
        }
#else
        return .coreGraphicsOnly
#endif
    }

    static func identifier(for policy: HwpPageRenderPolicy) -> String {
        policy.identifier
    }

    private static func normalizedValue(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
    }
}
