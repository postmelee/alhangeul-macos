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

    func testDiscoveryRecoversFromFailedAndMalformedPolls() {
        var time: TimeInterval = 0
        var polls = 0
        let found = SpotlightReindexService.pollForDiscovery(
            importerURL: installation().importerURL, timeout: 20,
            now: { time }, sleep: { time += $0 }, readCatalog: { _ in
                polls += 1
                switch polls {
                case 1: return nil
                case 2: return "malformed catalog"
                default: return self.validCatalog
                }
            }
        )
        XCTAssertTrue(found)
        XCTAssertEqual(polls, 3)
        XCTAssertEqual(time, 10)
    }

    func testDiscoveryFailuresStopAtDeadlineAndLimitEachCommand() {
        var time: TimeInterval = 0
        var timeouts: [TimeInterval] = []
        let found = SpotlightReindexService.pollForDiscovery(
            importerURL: installation().importerURL, timeout: 38,
            now: { time }, sleep: { time += $0 }, readCatalog: { timeout in
                timeouts.append(timeout)
                time += timeout
                return nil
            }
        )
        XCTAssertFalse(found)
        XCTAssertEqual(timeouts, [30, 3])
        XCTAssertEqual(time, 38)
    }

    func testDiscoveryDoesNotAcceptOutputAfterDeadline() {
        var time: TimeInterval = 0
        let found = SpotlightReindexService.pollForDiscovery(
            importerURL: installation().importerURL, timeout: 1,
            now: { time }, sleep: { _ in XCTFail("Sleep after deadline") }, readCatalog: { _ in
                time = 2
                return self.validCatalog
            }
        )
        XCTAssertFalse(found)
    }

    func testCommandKeepsStderrOutOfCatalog() throws {
        let output = try XCTUnwrap(SpotlightReindexService.run(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "printf '%s\\n' \"$1\"; printf 'warning: diagnostic\\n' >&2", "catalog-test", validCatalog]
        ))
        XCTAssertEqual(output, validCatalog + "\n")
        XCTAssertTrue(SpotlightReindexService.catalog(output, contains: installation().importerURL))
    }

    func testCommandDoesNotAcceptNonzeroExitWithValidOutput() {
        XCTAssertNil(SpotlightReindexService.run(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "printf '%s\\n' \"$1\"; exit 1", "catalog-test", validCatalog]
        ))
    }

    func testStartSchedulesDiscoveryThenSubmissionWithInjectedDefaults() throws {
        let app = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".app")
        defer { try? FileManager.default.removeItem(at: app) }
        let importer = SpotlightReindexService.importerURL(in: app)
        try FileManager.default.createDirectory(at: importer, withIntermediateDirectories: true)
        var work: (() -> Void)?
        var events: [String] = []
        SpotlightReindexService.start(
            appBundleURL: app, buildIdentifier: "test-build", userDefaults: defaults,
            schedule: { work = $0 },
            waitForDiscovery: { url in
                XCTAssertEqual(url, importer)
                events.append("discover")
                return true
            },
            submit: { url in
                XCTAssertEqual(url, importer)
                events.append("submit")
                return true
            }
        )
        XCTAssertTrue(events.isEmpty)
        XCTAssertNil(defaults.object(forKey: SpotlightReindexService.requestedInstallationKey))
        try XCTUnwrap(work)()
        XCTAssertEqual(events, ["discover", "submit"])
        let receipt = try XCTUnwrap(defaults.dictionary(forKey: SpotlightReindexService.requestedInstallationKey))
        XCTAssertEqual(receipt["importerPath"] as? String, importer.standardizedFileURL.path)
        XCTAssertEqual(receipt["buildIdentifier"] as? String, "test-build")
    }

    func testStartWithoutBundledImporterDoesNotRunCommandsOrWriteReceipt() {
        let app = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".app")
        SpotlightReindexService.start(
            appBundleURL: app, buildIdentifier: "test-build", userDefaults: defaults,
            schedule: { $0() },
            waitForDiscovery: { _ in XCTFail("Discovery without importer"); return true },
            submit: { _ in XCTFail("Submission without importer"); return true }
        )
        XCTAssertNil(defaults.object(forKey: SpotlightReindexService.requestedInstallationKey))
    }

    func testProductImporterURLMatchesBuiltAppBundle() throws {
        // CI가 먼저 만든 HostApp 산출물과 제품의 경로 계산을 직접 대조한다.
        let app = Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("Alhangeul.app")
        let importer = try XCTUnwrap(Bundle(url: SpotlightReindexService.importerURL(in: app)))
        XCTAssertEqual(importer.bundleIdentifier, "com.postmelee.alhangeul.SpotlightImporter")
        let executable = try XCTUnwrap(importer.executableURL)
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: executable.path))
    }

    @MainActor
    func testLaunchMaintenanceStartsSpotlightEvenWithExistingReceipt() {
        defaults.set("test-build", forKey: "alhangeul.launchMaintenance.completedBuild")
        let app = URL(fileURLWithPath: "/Applications/Test.app")
        var started = 0
        let result = LaunchMaintenanceService.runIfNeeded(
            userDefaults: defaults, appBundleURL: app, buildIdentifier: "test-build",
            startSpotlight: { url, build, settings in
                started += 1
                XCTAssertEqual(url, app)
                XCTAssertEqual(build, "test-build")
                XCTAssertTrue(settings === self.defaults)
            },
            refreshRegistration: { XCTFail("Repeated registration"); return 0 },
            refreshThumbnails: { XCTFail("Repeated thumbnail refresh"); return (0, 0) }
        )
        XCTAssertEqual(started, 1)
        XCTAssertFalse(result.didRun)
    }

    @MainActor
    func testFirstLaunchStartsSpotlightBeforeOtherMaintenance() {
        var events: [String] = []
        let result = LaunchMaintenanceService.runIfNeeded(
            userDefaults: defaults, appBundleURL: URL(fileURLWithPath: "/Applications/Test.app"), buildIdentifier: "test-build",
            startSpotlight: { _, _, settings in
                XCTAssertTrue(settings === self.defaults)
                events.append("spotlight")
            },
            refreshRegistration: { events.append("registration"); return 0 },
            refreshThumbnails: { events.append("thumbnails"); return (2, 1) }
        )
        XCTAssertEqual(events, ["spotlight", "registration", "thumbnails"])
        XCTAssertTrue(result.didRun)
        XCTAssertEqual(result.refreshedDocumentCount, 2)
        XCTAssertEqual(result.skippedDocumentCount, 1)
        XCTAssertEqual(defaults.string(forKey: "alhangeul.launchMaintenance.completedBuild"), "test-build")
    }

    private var validCatalog: String {
        "Paths: id(501) (\"\(installation().importerURL.path)\")"
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
