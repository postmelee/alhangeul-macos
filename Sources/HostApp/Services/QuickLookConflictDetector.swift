import AppKit
import Foundation

struct QuickLookBundleInfo: Equatable, Sendable {
    let bundleIdentifier: String?
    let shortVersion: String?
    let buildVersion: String?

    init(
        bundleIdentifier: String?,
        shortVersion: String?,
        buildVersion: String?
    ) {
        self.bundleIdentifier = Self.normalized(bundleIdentifier)
        self.shortVersion = Self.normalized(shortVersion)
        self.buildVersion = Self.normalized(buildVersion)
    }

    var displayVersion: String {
        switch (shortVersion, buildVersion) {
        case let (.some(shortVersion), .some(buildVersion)):
            "\(shortVersion) (\(buildVersion))"
        case let (.some(shortVersion), .none):
            shortVersion
        case let (.none, .some(buildVersion)):
            buildVersion
        case (.none, .none):
            "확인 불가"
        }
    }

    private static func normalized(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else {
            return nil
        }

        return trimmed
    }
}

struct HopQuickLookInstallation: Equatable, Sendable {
    let appBundleURL: URL
    let app: QuickLookBundleInfo?
    let preview: QuickLookBundleInfo?
}

struct AlhangeulQuickLookInstallation: Equatable, Sendable {
    let app: QuickLookBundleInfo?
    let preview: QuickLookBundleInfo?
    let rhwp: RhwpProvenance?
}

struct QuickLookConflictSnapshot: Equatable, Sendable {
    enum Guidance: Equatable, Sendable {
        case none
        case overlappingProvider
        case preferAlhangeul
    }

    let hop: HopQuickLookInstallation?
    let alhangeul: AlhangeulQuickLookInstallation
    let hopRhwpReleaseTag: String?
    let guidance: Guidance
    let fingerprint: String?
}

struct HopRhwpVersionCatalog: Sendable {
    static let verified = HopRhwpVersionCatalog(
        releasesByPreviewVersion: [
            "0.2.0": "v0.7.13",
        ]
    )

    private let releasesByPreviewVersion: [String: String]

    init(releasesByPreviewVersion: [String: String]) {
        self.releasesByPreviewVersion = releasesByPreviewVersion
    }

    func releaseTag(for preview: QuickLookBundleInfo?) -> String? {
        guard preview?.bundleIdentifier == QuickLookConflictDetector.hopPreviewBundleIdentifier,
              let previewVersion = preview?.shortVersion
        else {
            return nil
        }

        return releasesByPreviewVersion[previewVersion]
    }
}

enum QuickLookConflictPolicy {
    static func makeSnapshot(
        hop: HopQuickLookInstallation?,
        alhangeul: AlhangeulQuickLookInstallation,
        catalog: HopRhwpVersionCatalog = .verified
    ) -> QuickLookConflictSnapshot {
        guard let hop else {
            return QuickLookConflictSnapshot(
                hop: nil,
                alhangeul: alhangeul,
                hopRhwpReleaseTag: nil,
                guidance: .none,
                fingerprint: nil
            )
        }

        let hopRhwpReleaseTag = catalog.releaseTag(for: hop.preview)
        let guidance = guidance(
            hopRhwpReleaseTag: hopRhwpReleaseTag,
            alhangeulRhwpReleaseTag: alhangeul.rhwp?.releaseTag
        )

        return QuickLookConflictSnapshot(
            hop: hop,
            alhangeul: alhangeul,
            hopRhwpReleaseTag: hopRhwpReleaseTag,
            guidance: guidance,
            fingerprint: fingerprint(
                hop: hop,
                alhangeul: alhangeul,
                hopRhwpReleaseTag: hopRhwpReleaseTag
            )
        )
    }

    private static func guidance(
        hopRhwpReleaseTag: String?,
        alhangeulRhwpReleaseTag: String?
    ) -> QuickLookConflictSnapshot.Guidance {
        guard let hopRhwpReleaseTag,
              let alhangeulRhwpReleaseTag,
              let hopVersion = NumericVersion(hopRhwpReleaseTag),
              let alhangeulVersion = NumericVersion(alhangeulRhwpReleaseTag),
              alhangeulVersion > hopVersion
        else {
            return .overlappingProvider
        }

        return .preferAlhangeul
    }

    private static func fingerprint(
        hop: HopQuickLookInstallation,
        alhangeul: AlhangeulQuickLookInstallation,
        hopRhwpReleaseTag: String?
    ) -> String {
        let components = [
            "quick-look-conflict-v1",
            hop.appBundleURL.standardizedFileURL.path,
            hop.app?.bundleIdentifier,
            hop.app?.shortVersion,
            hop.app?.buildVersion,
            hop.preview?.bundleIdentifier,
            hop.preview?.shortVersion,
            hop.preview?.buildVersion,
            hopRhwpReleaseTag,
            alhangeul.app?.bundleIdentifier,
            alhangeul.app?.shortVersion,
            alhangeul.app?.buildVersion,
            alhangeul.preview?.bundleIdentifier,
            alhangeul.preview?.shortVersion,
            alhangeul.preview?.buildVersion,
            alhangeul.rhwp?.releaseTag,
            alhangeul.rhwp?.resolvedCommit,
        ]

        return components
            .map { component in
                let value = component ?? "<unknown>"
                return "\(value.utf8.count):\(value)"
            }
            .joined(separator: "|")
    }
}

struct QuickLookConflictDetector {
    static let hopAppBundleIdentifier = "net.golbin.hop"
    static let hopPreviewBundleIdentifier = "net.golbin.hop.quicklook.preview"
    static let alhangeulPreviewBundleIdentifier = "com.postmelee.alhangeul.QLExtension"

    struct Dependencies {
        var applicationURLs: (String) -> [URL]
        var bundleInfo: (URL) -> QuickLookBundleInfo?
        var rhwpProvenance: (URL) -> RhwpProvenance?

        static let live = Dependencies(
            applicationURLs: { bundleIdentifier in
                NSWorkspace.shared.urlsForApplications(
                    withBundleIdentifier: bundleIdentifier
                )
            },
            bundleInfo: { bundleURL in
                guard let bundle = Bundle(url: bundleURL) else {
                    return nil
                }

                return QuickLookBundleInfo(
                    bundleIdentifier: bundle.bundleIdentifier,
                    shortVersion: bundle.object(
                        forInfoDictionaryKey: "CFBundleShortVersionString"
                    ) as? String,
                    buildVersion: bundle.object(
                        forInfoDictionaryKey: "CFBundleVersion"
                    ) as? String
                )
            },
            rhwpProvenance: { bundleURL in
                guard let bundle = Bundle(url: bundleURL) else {
                    return nil
                }

                return RhwpProvenanceLoader.load(bundle: bundle)
            }
        )
    }

    private let dependencies: Dependencies
    private let catalog: HopRhwpVersionCatalog

    init(
        dependencies: Dependencies = .live,
        catalog: HopRhwpVersionCatalog = .verified
    ) {
        self.dependencies = dependencies
        self.catalog = catalog
    }

    func detect(
        alhangeulAppBundleURL: URL = Bundle.main.bundleURL
    ) -> QuickLookConflictSnapshot {
        let alhangeul = alhangeulInstallation(appBundleURL: alhangeulAppBundleURL)
        let hop = hopInstallation()

        return QuickLookConflictPolicy.makeSnapshot(
            hop: hop,
            alhangeul: alhangeul,
            catalog: catalog
        )
    }

    private func hopInstallation() -> HopQuickLookInstallation? {
        let appBundleURL = dependencies.applicationURLs(
            Self.hopAppBundleIdentifier
        ).first { candidateURL in
            let bundleIdentifier = dependencies.bundleInfo(candidateURL)?.bundleIdentifier
            return bundleIdentifier == nil || bundleIdentifier == Self.hopAppBundleIdentifier
        }

        guard let appBundleURL else {
            return nil
        }

        let previewBundleURL = appBundleURL
            .appendingPathComponent("Contents/PlugIns", isDirectory: true)
            .appendingPathComponent("HopQuickLookPreview.appex", isDirectory: true)

        return HopQuickLookInstallation(
            appBundleURL: appBundleURL,
            app: dependencies.bundleInfo(appBundleURL),
            preview: dependencies.bundleInfo(previewBundleURL)
        )
    }

    private func alhangeulInstallation(
        appBundleURL: URL
    ) -> AlhangeulQuickLookInstallation {
        let previewBundleURL = appBundleURL
            .appendingPathComponent("Contents/PlugIns", isDirectory: true)
            .appendingPathComponent("AlhangeulPreview.appex", isDirectory: true)

        let previewInfo = dependencies.bundleInfo(previewBundleURL)
        let preview = previewInfo?.bundleIdentifier == Self.alhangeulPreviewBundleIdentifier
            ? previewInfo
            : nil

        return AlhangeulQuickLookInstallation(
            app: dependencies.bundleInfo(appBundleURL),
            preview: preview,
            rhwp: dependencies.rhwpProvenance(appBundleURL)
        )
    }
}

private struct NumericVersion: Comparable {
    private let components: [Int]

    init?(_ rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized: Substring

        if trimmed.first == "v" || trimmed.first == "V" {
            normalized = trimmed.dropFirst()
        } else {
            normalized = Substring(trimmed)
        }

        let segments = normalized.split(separator: ".", omittingEmptySubsequences: false)
        guard !segments.isEmpty else {
            return nil
        }

        var components: [Int] = []
        components.reserveCapacity(segments.count)

        for segment in segments {
            guard !segment.isEmpty,
                  segment.allSatisfy(\.isNumber),
                  let component = Int(segment)
            else {
                return nil
            }
            components.append(component)
        }

        self.components = components
    }

    static func < (lhs: NumericVersion, rhs: NumericVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)

        for index in 0..<count {
            let lhsComponent = index < lhs.components.count ? lhs.components[index] : 0
            let rhsComponent = index < rhs.components.count ? rhs.components[index] : 0

            if lhsComponent != rhsComponent {
                return lhsComponent < rhsComponent
            }
        }

        return false
    }
}
