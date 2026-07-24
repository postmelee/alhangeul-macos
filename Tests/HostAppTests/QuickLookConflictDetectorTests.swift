import XCTest

final class QuickLookConflictDetectorTests: XCTestCase {
    private let alhangeulAppURL = URL(fileURLWithPath: "/Applications/Alhangeul.app")
    private let hopAppURL = URL(fileURLWithPath: "/Applications/HOP.app")

    func testNoHopInstallationHasNoGuidanceOrFingerprint() {
        let snapshot = makeDetector(hopAppURLs: []).detect(
            alhangeulAppBundleURL: alhangeulAppURL
        )

        XCTAssertNil(snapshot.hop)
        XCTAssertNil(snapshot.hopRhwpReleaseTag)
        XCTAssertEqual(snapshot.guidance, .none)
        XCTAssertNil(snapshot.fingerprint)
    }

    func testKnownHopPreviewPrefersNewerAlhangeulRhwp() {
        let snapshot = makeDetector().detect(
            alhangeulAppBundleURL: alhangeulAppURL
        )

        XCTAssertEqual(snapshot.hop?.app?.shortVersion, "0.3.1")
        XCTAssertEqual(snapshot.hop?.preview?.shortVersion, "0.2.0")
        XCTAssertEqual(snapshot.hopRhwpReleaseTag, "v0.7.13")
        XCTAssertEqual(snapshot.alhangeul.rhwp?.releaseTag, "v0.7.18")
        XCTAssertEqual(snapshot.guidance, .preferAlhangeul)
        XCTAssertNotNil(snapshot.fingerprint)
    }

    func testUnknownHopPreviewOnlyReportsOverlappingProvider() {
        let snapshot = makeDetector(
            hopPreview: bundleInfo(
                identifier: QuickLookConflictDetector.hopPreviewBundleIdentifier,
                version: "0.3.0"
            )
        ).detect(alhangeulAppBundleURL: alhangeulAppURL)

        XCTAssertNil(snapshot.hopRhwpReleaseTag)
        XCTAssertEqual(snapshot.guidance, .overlappingProvider)
    }

    func testUnexpectedHopPreviewBundleIdentifierOnlyReportsOverlappingProvider() {
        let snapshot = makeDetector(
            hopPreview: bundleInfo(
                identifier: "net.golbin.hop.unexpected-preview",
                version: "0.2.0"
            )
        ).detect(alhangeulAppBundleURL: alhangeulAppURL)

        XCTAssertNil(snapshot.hopRhwpReleaseTag)
        XCTAssertEqual(snapshot.guidance, .overlappingProvider)
    }

    func testUnavailableHopPreviewMetadataOnlyReportsOverlappingProvider() {
        let snapshot = makeDetector(hopPreview: .some(nil)).detect(
            alhangeulAppBundleURL: alhangeulAppURL
        )

        XCTAssertNotNil(snapshot.hop)
        XCTAssertNil(snapshot.hop?.preview)
        XCTAssertNil(snapshot.hopRhwpReleaseTag)
        XCTAssertEqual(snapshot.guidance, .overlappingProvider)
    }

    func testUnavailableAlhangeulProvenanceDoesNotClaimNewerRhwp() {
        let snapshot = makeDetector(alhangeulRhwp: .some(nil)).detect(
            alhangeulAppBundleURL: alhangeulAppURL
        )

        XCTAssertEqual(snapshot.hopRhwpReleaseTag, "v0.7.13")
        XCTAssertNil(snapshot.alhangeul.rhwp)
        XCTAssertEqual(snapshot.guidance, .overlappingProvider)
    }

    func testEqualOrNewerHopRhwpDoesNotPreferAlhangeul() {
        let equalSnapshot = makePolicySnapshot(
            hopRhwpReleaseTag: "v0.7.18",
            alhangeulRhwpReleaseTag: "v0.7.18"
        )
        let newerHopSnapshot = makePolicySnapshot(
            hopRhwpReleaseTag: "v0.8.0",
            alhangeulRhwpReleaseTag: "v0.7.18"
        )

        XCTAssertEqual(equalSnapshot.guidance, .overlappingProvider)
        XCTAssertEqual(newerHopSnapshot.guidance, .overlappingProvider)
    }

    func testFingerprintChangesWithDetectedVersionsAndRhwpProvenance() {
        let baseline = makeDetector().detect(
            alhangeulAppBundleURL: alhangeulAppURL
        )
        let changedPreview = makeDetector(
            hopPreview: bundleInfo(
                identifier: QuickLookConflictDetector.hopPreviewBundleIdentifier,
                version: "0.3.0"
            )
        ).detect(alhangeulAppBundleURL: alhangeulAppURL)
        let changedRhwp = makeDetector(
            alhangeulRhwp: provenance(
                releaseTag: "v0.7.19",
                commit: "abcdef1234567890"
            )
        ).detect(alhangeulAppBundleURL: alhangeulAppURL)

        XCTAssertNotEqual(baseline.fingerprint, changedPreview.fingerprint)
        XCTAssertNotEqual(baseline.fingerprint, changedRhwp.fingerprint)
    }

    private func makeDetector(
        hopAppURLs: [URL]? = nil,
        hopPreview: QuickLookBundleInfo?? = nil,
        alhangeulRhwp: RhwpProvenance?? = nil
    ) -> QuickLookConflictDetector {
        let hopPreviewURL = hopAppURL
            .appendingPathComponent("Contents/PlugIns", isDirectory: true)
            .appendingPathComponent("HopQuickLookPreview.appex", isDirectory: true)
        let alhangeulPreviewURL = alhangeulAppURL
            .appendingPathComponent("Contents/PlugIns", isDirectory: true)
            .appendingPathComponent("AlhangeulPreview.appex", isDirectory: true)
        let resolvedHopPreview = hopPreview ?? .some(
            bundleInfo(
                identifier: QuickLookConflictDetector.hopPreviewBundleIdentifier,
                version: "0.2.0"
            )
        )
        let resolvedAlhangeulRhwp = alhangeulRhwp ?? .some(
            provenance(
                releaseTag: "v0.7.18",
                commit: "93862a4123456789"
            )
        )

        let dependencies = QuickLookConflictDetector.Dependencies(
            applicationURLs: { bundleIdentifier in
                XCTAssertEqual(
                    bundleIdentifier,
                    QuickLookConflictDetector.hopAppBundleIdentifier
                )
                return hopAppURLs ?? [self.hopAppURL]
            },
            bundleInfo: { url in
                switch url {
                case self.hopAppURL:
                    return self.bundleInfo(
                        identifier: QuickLookConflictDetector.hopAppBundleIdentifier,
                        version: "0.3.1"
                    )
                case hopPreviewURL:
                    return resolvedHopPreview
                case self.alhangeulAppURL:
                    return self.bundleInfo(
                        identifier: "com.postmelee.alhangeul",
                        version: "0.1.8",
                        build: "14"
                    )
                case alhangeulPreviewURL:
                    return self.bundleInfo(
                        identifier: QuickLookConflictDetector.alhangeulPreviewBundleIdentifier,
                        version: "0.1.8",
                        build: "14"
                    )
                default:
                    return nil
                }
            },
            rhwpProvenance: { url in
                XCTAssertEqual(url, self.alhangeulAppURL)
                return resolvedAlhangeulRhwp
            }
        )

        return QuickLookConflictDetector(dependencies: dependencies)
    }

    private func makePolicySnapshot(
        hopRhwpReleaseTag: String,
        alhangeulRhwpReleaseTag: String
    ) -> QuickLookConflictSnapshot {
        let previewVersion = "synthetic"
        let catalog = HopRhwpVersionCatalog(
            releasesByPreviewVersion: [
                previewVersion: hopRhwpReleaseTag,
            ]
        )
        let hop = HopQuickLookInstallation(
            appBundleURL: hopAppURL,
            app: bundleInfo(
                identifier: QuickLookConflictDetector.hopAppBundleIdentifier,
                version: "test"
            ),
            preview: bundleInfo(
                identifier: QuickLookConflictDetector.hopPreviewBundleIdentifier,
                version: previewVersion
            )
        )
        let alhangeul = AlhangeulQuickLookInstallation(
            app: nil,
            preview: nil,
            rhwp: provenance(
                releaseTag: alhangeulRhwpReleaseTag,
                commit: "1234567890abcdef"
            )
        )

        return QuickLookConflictPolicy.makeSnapshot(
            hop: hop,
            alhangeul: alhangeul,
            catalog: catalog
        )
    }

    private func bundleInfo(
        identifier: String,
        version: String,
        build: String? = nil
    ) -> QuickLookBundleInfo {
        QuickLookBundleInfo(
            bundleIdentifier: identifier,
            shortVersion: version,
            buildVersion: build
        )
    }

    private func provenance(
        releaseTag: String,
        commit: String
    ) -> RhwpProvenance {
        RhwpProvenance(
            releaseTag: releaseTag,
            resolvedCommit: commit
        )
    }
}
