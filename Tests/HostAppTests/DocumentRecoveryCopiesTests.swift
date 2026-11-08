import XCTest

@MainActor
final class DocumentRecoveryCopiesTests: XCTestCase {
    let owner = UUID()
    let bytes = Data([0x50, 0x4b, 0x03, 0x04, 1, 2, 3, 4])
    let source = URL(fileURLWithPath: "/tmp/task594-source.hwpx")
    @discardableResult
    func admit(_ pool: DocumentRecoveryCopies, owner: UUID? = nil, protection: DocumentSourceProtection = .plain,
               conversion: DocumentSaveConversionIntent = .none, valid: Bool = true, current: Bool = true,
               data: Data? = nil) -> Bool {
        pool.admit(owner: owner ?? self.owner, data: data ?? bytes, format: .hwpx, sourceURL: source,
            sourceProtection: protection, conversion: conversion, parserValidated: valid,
            sessionIsCurrent: current, loadID: 4, epoch: 2, revision: 12)
    }
    func testProtectionConversionAndLateValidationNeverAdmit() {
        let pool = DocumentRecoveryCopies()
        for protection: DocumentSourceProtection in [.passwordProtected, .unsupportedProtection, .invalidOrUnknown] {
            XCTAssertFalse(admit(pool, protection: protection))
        }
        XCTAssertFalse(admit(pool, conversion: .hwp3ToHwpx))
        XCTAssertFalse(admit(pool, valid: false)); XCTAssertFalse(admit(pool, current: false))
        XCTAssertFalse(admit(pool, data: Data([1, 2, 3])))
        XCTAssertNil(pool.copy(for: owner))
    }
    func testMonotonicExpiryKeepsExistingLeaseOnly() throws {
        var clock = 100.0
        let pool = DocumentRecoveryCopies(ttl: 10, now: { clock })
        admit(pool)
        let lease = try XCTUnwrap(pool.acquire(for: owner))
        clock = 110
        XCTAssertNil(pool.copy(for: owner)); XCTAssertNil(pool.acquire(for: owner))
        XCTAssertEqual(lease.copy.data, bytes)
        XCTAssertEqual(pool.retainedByteCount, bytes.count)
        pool.release(lease)
        XCTAssertEqual(pool.retainedByteCount, 0)
    }
    func testBudgetDoesNotEvictOtherWindowsOrPriorSave() throws {
        let pool = DocumentRecoveryCopies(perWindowLimit: 16, totalLimit: 16)
        let second = UUID()
        XCTAssertTrue(admit(pool)); XCTAssertTrue(admit(pool, owner: second))
        let prior = try XCTUnwrap(pool.copy(for: owner))
        XCTAssertFalse(admit(pool, data: bytes + bytes))
        XCTAssertEqual(pool.copy(for: owner)?.id, prior.id)
        XCTAssertEqual(pool.copy(for: second)?.data, bytes)
        XCTAssertFalse(admit(pool, data: bytes + bytes + bytes))
    }
    func testLeasedOldSaveCountsAgainstReplacementBudget() throws {
        let pool = DocumentRecoveryCopies(perWindowLimit: 16, totalLimit: 16)
        admit(pool)
        let lease = try XCTUnwrap(pool.acquire(for: owner))
        XCTAssertTrue(admit(pool))
        XCTAssertEqual(pool.retainedByteCount, 16)
        let prior = pool.copy(for: owner)?.id
        XCTAssertFalse(admit(pool, data: bytes + bytes))
        XCTAssertEqual(pool.copy(for: owner)?.id, prior)
        pool.remove(owner: owner)
        XCTAssertEqual(pool.retainedByteCount, 8)
        pool.release(lease)
        XCTAssertEqual(pool.retainedByteCount, 0)
    }
    func testTimerReleasesExpiredUnleasedBytesWithoutUserInteraction() async throws {
        let pool = DocumentRecoveryCopies(ttl: 0.03)
        admit(pool)
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(pool.retainedByteCount, 0)
    }

    func testMetadataRetainsSaveTimeAndOriginalGeneration() throws {
        let pool = DocumentRecoveryCopies()
        admit(pool)
        let copy = try XCTUnwrap(pool.copy(for: owner))
        XCTAssertEqual(copy.loadID, 4); XCTAssertEqual(copy.epoch, 2); XCTAssertEqual(copy.revision, 12)
        XCTAssertEqual(copy.sourceURL, source); XCTAssertEqual(copy.format, .hwpx)
        XCTAssertLessThan(abs(copy.savedAt.timeIntervalSinceNow), 5)
        XCTAssertEqual(copy.digest.count, 32)
    }
    func testRecoveryExportNeverOverwritesSourceExistingFileOrSymlink() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let pool = DocumentRecoveryCopies()
        admit(pool)
        let copy = try XCTUnwrap(pool.copy(for: owner))
        XCTAssertThrowsError(try DocumentRecoveryExport.write(copy, to: source, currentSource: nil))
        let destination = folder.appendingPathComponent("copy.hwpx")
        try DocumentRecoveryExport.write(copy, to: destination, currentSource: nil)
        XCTAssertEqual(try Data(contentsOf: destination), bytes)
        XCTAssertThrowsError(try DocumentRecoveryExport.write(copy, to: destination, currentSource: nil))
        let link = folder.appendingPathComponent("alias.hwpx")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: destination)
        XCTAssertThrowsError(try DocumentRecoveryExport.write(copy, to: link, currentSource: destination))
        XCTAssertEqual(try Data(contentsOf: destination), bytes)
        XCTAssertThrowsError(try DocumentRecoveryExport.write(copy, to: folder.appendingPathComponent("copy.hwp"), currentSource: nil))
        XCTAssertThrowsError(try DocumentRecoveryExport.write(copy, to: folder.appendingPathComponent("missing/child.hwpx"), currentSource: nil))
        XCTAssertEqual(pool.copy(for: owner)?.id, copy.id)
    }
}
