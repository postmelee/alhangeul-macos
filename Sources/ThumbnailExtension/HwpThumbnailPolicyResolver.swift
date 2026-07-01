import Foundation

enum HwpThumbnailPolicyResolver {
    static let environmentKey = "ALHANGEUL_THUMBNAIL_RENDER_POLICY"

    static func resolve(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> HwpPageRenderPolicy {
#if DEBUG
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
        _ = environment
        return .coreGraphicsOnly
#endif
    }

    static func identifier(for policy: HwpPageRenderPolicy) -> String {
        switch policy {
        case .coreGraphicsOnly:
            return "coreGraphicsOnly"
        case .skiaOptIn:
            return "skiaOptIn"
        }
    }

    private static func normalizedValue(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
    }
}
