import Foundation

enum BuildInfo {
    private static var bundle: Bundle {
        Bundle.main
    }

    static var displayName: String {
        bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "알한글"
    }

    static var version: String {
        bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }

    static var build: String {
        bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    static var displayVersion: String {
        return "v\(version) (\(build))"
    }

    static var rhwpDisplayVersion: String {
        RhwpProvenanceLoader.load(bundle: bundle)?.displayValue ?? "확인 불가"
    }

    static var launchMaintenanceBuildIdentifier: String {
        "\(version)-\(build)"
    }
}
