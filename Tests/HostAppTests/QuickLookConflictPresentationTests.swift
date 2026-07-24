import XCTest

final class QuickLookConflictPresentationTests: XCTestCase {
    func testKnownNewerAlhangeulRhwpShowsVersionComparisonAndRecommendation() throws {
        let presentation = try XCTUnwrap(
            QuickLookConflictPresentation(
                snapshot: makeSnapshot(
                    guidance: .preferAlhangeul,
                    hopPreviewVersion: "0.2.0",
                    hopRhwpReleaseTag: "v0.7.13"
                )
            )
        )

        XCTAssertEqual(presentation.alhangeul.app, "0.1.8 (14)")
        XCTAssertEqual(presentation.alhangeul.preview, "0.1.8 (14)")
        XCTAssertEqual(presentation.alhangeul.rhwp, "v0.7.18 (93862a4)")
        XCTAssertEqual(presentation.hop.app, "0.3.1")
        XCTAssertEqual(presentation.hop.preview, "0.2.0")
        XCTAssertEqual(presentation.hop.rhwp, "v0.7.13")
        XCTAssertEqual(
            presentation.recommendation,
            """
            알한글은 HOP Preview보다 최신인 rhwp 렌더러를 포함합니다. \
            HOP Quick Look Preview를 끄고 알한글 미리보기를 켜는 것을 권장합니다.
            """
        )
        XCTAssertTrue(presentation.usesVerifiedHopRhwpMapping)
    }

    func testUnknownHopRhwpDoesNotMakeNewerVersionClaim() throws {
        let presentation = try XCTUnwrap(
            QuickLookConflictPresentation(
                snapshot: makeSnapshot(
                    guidance: .overlappingProvider,
                    hopPreviewVersion: "0.3.0",
                    hopRhwpReleaseTag: nil
                )
            )
        )

        XCTAssertEqual(presentation.hop.preview, "0.3.0")
        XCTAssertEqual(presentation.hop.rhwp, "확인 불가")
        XCTAssertNil(presentation.recommendation)
        XCTAssertFalse(presentation.usesVerifiedHopRhwpMapping)
    }

    func testUnavailableHopPreviewMetadataUsesUnknownValues() throws {
        let presentation = try XCTUnwrap(
            QuickLookConflictPresentation(
                snapshot: makeSnapshot(
                    guidance: .overlappingProvider,
                    hopPreviewVersion: nil,
                    hopRhwpReleaseTag: nil
                )
            )
        )

        XCTAssertEqual(presentation.hop.preview, "확인 불가")
        XCTAssertEqual(presentation.hop.rhwp, "확인 불가")
        XCTAssertNil(presentation.recommendation)
    }

    func testNoHopConflictDoesNotCreatePresentation() {
        let snapshot = QuickLookConflictSnapshot(
            hop: nil,
            alhangeul: alhangeulInstallation,
            hopRhwpReleaseTag: nil,
            guidance: .none,
            fingerprint: nil
        )

        XCTAssertNil(QuickLookConflictPresentation(snapshot: snapshot))
    }

    private func makeSnapshot(
        guidance: QuickLookConflictSnapshot.Guidance,
        hopPreviewVersion: String?,
        hopRhwpReleaseTag: String?
    ) -> QuickLookConflictSnapshot {
        let hopPreview = hopPreviewVersion.map { version in
            QuickLookBundleInfo(
                bundleIdentifier: QuickLookConflictDetector.hopPreviewBundleIdentifier,
                shortVersion: version,
                buildVersion: nil
            )
        }
        let hop = HopQuickLookInstallation(
            appBundleURL: URL(fileURLWithPath: "/Applications/HOP.app"),
            app: QuickLookBundleInfo(
                bundleIdentifier: QuickLookConflictDetector.hopAppBundleIdentifier,
                shortVersion: "0.3.1",
                buildVersion: nil
            ),
            preview: hopPreview
        )

        return QuickLookConflictSnapshot(
            hop: hop,
            alhangeul: alhangeulInstallation,
            hopRhwpReleaseTag: hopRhwpReleaseTag,
            guidance: guidance,
            fingerprint: "fixture"
        )
    }

    private var alhangeulInstallation: AlhangeulQuickLookInstallation {
        AlhangeulQuickLookInstallation(
            app: QuickLookBundleInfo(
                bundleIdentifier: "com.postmelee.alhangeul",
                shortVersion: "0.1.8",
                buildVersion: "14"
            ),
            preview: QuickLookBundleInfo(
                bundleIdentifier: QuickLookConflictDetector.alhangeulPreviewBundleIdentifier,
                shortVersion: "0.1.8",
                buildVersion: "14"
            ),
            rhwp: RhwpProvenance(
                releaseTag: "v0.7.18",
                resolvedCommit: "93862a4123456789"
            )
        )
    }
}
