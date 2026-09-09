import XCTest

final class SpotlightReindexServiceTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "SpotlightReindexServiceTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testExistingLaunchMaintenanceReceiptDoesNotSuppressSpotlightRequest() {
        defaults.set("0.1.11-17", forKey: "alhangeul.launchMaintenance.completedBuild")
        var submitted: [URL] = []
        let result = request(installation()) { submitted.append($0); return true }
        XCTAssertEqual(result, .requested)
        XCTAssertEqual(submitted, [installation().importerURL])
    }

    func testAcceptedInstallationIsNotRequestedAgainOnRelaunch() {
        XCTAssertEqual(request(installation()) { _ in true }, .requested)
        XCTAssertEqual(request(installation()) { _ in XCTFail("Duplicate request"); return true }, .alreadyRequested)
    }

    func testFailedRequestRetriesOnNextLaunch() {
        XCTAssertEqual(request(installation()) { _ in false }, .failed)
        XCTAssertNil(defaults.object(forKey: SpotlightReindexService.requestedInstallationKey))
        XCTAssertEqual(request(installation()) { _ in true }, .requested)
    }

    func testMovedAppAndUpdatedBuildAndImporterEachRequestAgain() {
        let original = installation()
        let moved = installation(path: "/Applications/Moved.app/Contents/Library/Spotlight/Alhangeul.mdimporter")
        let updated = installation(build: "0.2.0-18")
        let rebuilt = installation(date: Date(timeIntervalSince1970: 2))
        for changed in [moved, updated, rebuilt] {
            defaults.removeObject(forKey: SpotlightReindexService.requestedInstallationKey)
            XCTAssertEqual(request(original) { _ in true }, .requested)
            XCTAssertEqual(request(changed) { _ in true }, .requested)
        }
    }

    func testFailedUpdateDoesNotOverwriteEarlierReceipt() {
        let original = installation()
        XCTAssertEqual(request(original) { _ in true }, .requested)
        XCTAssertEqual(request(installation(build: "0.2.0-18")) { _ in false }, .failed)
        XCTAssertEqual(defaults.dictionary(forKey: SpotlightReindexService.requestedInstallationKey) as? [String: String], original.receipt)
    }

    func testMissingImporterDoesNotRequestOrRecordSuccessAndCanRetry() {
        let result = SpotlightReindexService.requestIfNeeded(
            installation: installation(), userDefaults: defaults,
            waitForDiscovery: { _ in false },
            submit: { _ in XCTFail("Reimport before discovery"); return true }
        )
        XCTAssertEqual(result, .failed)
        XCTAssertNil(defaults.object(forKey: SpotlightReindexService.requestedInstallationKey))
        XCTAssertEqual(request(installation()) { _ in true }, .requested)
    }

    func testCatalogRequiresExactPathAndParsesOpenStepEscapes() {
        let path = "/Applications/한글 App.app/Contents/Library/Spotlight/Alhangeul.mdimporter"
        let url = URL(fileURLWithPath: path, isDirectory: true)
        let catalog = #"Paths: id(501) ("/Applications/\Ud55c\Uae00 App.app/Contents/Library/Spotlight/Alhangeul.mdimporter")"#
        XCTAssertTrue(SpotlightReindexService.catalog(catalog, contains: url))
        XCTAssertFalse(SpotlightReindexService.catalog(catalog, contains: installation().importerURL))
        XCTAssertFalse(SpotlightReindexService.catalog("Paths: id(501) ()", contains: url))
        XCTAssertFalse(SpotlightReindexService.catalog("invalid \(path)", contains: url))
    }

    private func request(_ installation: SpotlightReindexService.Installation, submit: (URL) -> Bool) -> SpotlightReindexService.Result {
        SpotlightReindexService.requestIfNeeded(
            installation: installation, userDefaults: defaults, waitForDiscovery: { _ in true }, submit: submit
        )
    }

    private func installation(
        path: String = "/Applications/Alhangeul.app/Contents/Library/Spotlight/Alhangeul.mdimporter",
        build: String = "0.1.11-17",
        date: Date = Date(timeIntervalSince1970: 1)
    ) -> SpotlightReindexService.Installation {
        .init(importerURL: URL(fileURLWithPath: path), buildIdentifier: build, modificationDate: date)
    }
}
