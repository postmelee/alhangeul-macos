import Foundation

enum HwpQuickLookPNGReplyModeResolver {
    static let environmentKey = "ALHANGEUL_QUICKLOOK_PNG_REPLY_MODE"

    static func resolve(
        environment: [String: String]? = nil
    ) -> HwpPreviewPNGReplyMode {
#if DEBUG
        let environment = environment ?? ProcessInfo.processInfo.environment
        guard let rawValue = environment[environmentKey] else {
            return .coreGraphics
        }

        switch normalizedValue(rawValue) {
        case "skia", "skiadecode", "skiaoptin":
            return .skiaDecode
        case "direct", "skiadirect":
            return .skiaDirect
        case "coregraphics", "coregraphicsonly":
            return .coreGraphics
        default:
            return .coreGraphics
        }
#else
        return .coreGraphics
#endif
    }

    static func identifier(for mode: HwpPreviewPNGReplyMode) -> String {
        mode.identifier
    }

    private static func normalizedValue(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
    }
}
