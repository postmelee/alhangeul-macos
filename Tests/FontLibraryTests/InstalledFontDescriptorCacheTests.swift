import CoreText
import Foundation
import XCTest

final class InstalledFontDescriptorCacheTests: XCTestCase {
    private var root: URL!
    private var font: URL!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        font = root.appendingPathComponent("fixture.ttf")
        let source = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "regular", withExtension: "ttf", subdirectory: "Fixtures"))
        try FileManager.default.copyItem(at: source, to: font)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }

    private func descriptor(_ attributes: [CFString: Any] = [:]) throws -> CTFontDescriptor {
        let all = CTFontManagerCreateFontDescriptorsFromURL(font as CFURL) as? [CTFontDescriptor]
        return CTFontDescriptorCreateCopyWithAttributes(try XCTUnwrap(all?.first), attributes as CFDictionary)
    }
    private func key(_ attributes: [String: Any], url: URL? = nil, ps: String = "Fixture-Regular") throws -> Data? {
        InstalledFontDescriptorCache.key(attributes: attributes as CFDictionary, url: url ?? font,
            postScriptName: ps, stamp: try InstalledFontSystem.statURL(url ?? font))
    }

    func testCanonicalKeyKeepsTypesNestedFieldsAndSourcesDistinct() throws {
        let first = ["name": "Fixture", "axes": [1: 2.0, 2: 3.0], "extra": ["flag": true, "data": Data([0, 1])]] as [String: Any]
        let reordered = ["extra": ["data": Data([0, 1]), "flag": true], "axes": [2: 3.0, 1: 2.0], "name": "Fixture"] as [String: Any]
        let baseline = try XCTUnwrap(key(first))
        XCTAssertEqual(try key(reordered), baseline)
        for changed in [["name": "Fixture"], ["name": "Fixture", "axes": [1: 9.0]],
                        ["name": "Fixture", "extra": false], ["name": "Fixture", "extra": 0]] as [[String: Any]] {
            XCTAssertNotEqual(try key(changed), baseline)
        }
        XCTAssertNotEqual(try key(first, ps: "Fixture-Bold"), baseline)
        let second = root.appendingPathComponent("same-bytes.ttf")
        try FileManager.default.copyItem(at: font, to: second)
        XCTAssertNotEqual(try key(first, url: second), baseline)
        XCTAssertNil(try key(["unknown": NSObject()]))
        XCTAssertNil(try key(["number": Double.nan]))
        XCTAssertNil(try key(["number": Double.infinity]))
        XCTAssertNil(try key(["data": Data(repeating: 0, count: 64 * 1024)]))
        XCTAssertNil(try key(["string": String(repeating: "x", count: 64 * 1024)]))
    }

    func testDigestKeepsOrderDuplicatesAxesTraitsAndEnabledSemantics() throws {
        let changes = InstalledFontChangeEpoch(), cache = InstalledFontDescriptorCache(changes: changes)
        let normal = try descriptor()
        let variations: [[CFString: Any]] = [
            [kCTFontFamilyNameAttribute: "Changed family"], [kCTFontStyleNameAttribute: "Changed style"],
            [kCTFontVariationAttribute: [NSNumber(value: 1): NSNumber(value: 1.0)]],
            [kCTFontTraitsAttribute: [kCTFontWeightTrait: NSNumber(value: 0.7)]],
            [kCTFontEnabledAttribute: false]
        ]
        let baseline = try InstalledFontActiveSignature.capture([normal], cache: cache)
        XCTAssertTrue(baseline.reusable)
        XCTAssertEqual(try InstalledFontActiveSignature.capture([normal]), baseline)
        for attrs in variations {
            let modified = try descriptor(attrs)
            let strict = try InstalledFontActiveSignature.capture([modified])
            XCTAssertEqual(try InstalledFontActiveSignature.capture([modified], cache: cache), strict)
            XCTAssertNotEqual(strict.digest, baseline.digest)
        }
        let bold = try descriptor([kCTFontTraitsAttribute: [kCTFontWeightTrait: NSNumber(value: 0.7)]])
        XCTAssertEqual(try InstalledFontActiveSignature.capture([normal, bold], cache: cache),
                       try InstalledFontActiveSignature.capture([bold, normal]))
        XCTAssertNotEqual(try InstalledFontActiveSignature.capture([normal, normal], cache: cache).digest, baseline.digest)
        XCTAssertLessThanOrEqual(cache.retainedState().records, 20_000)
    }

    func testOriginalReplacementFailureRecoveryAndMalformedFallback() throws {
        let changes = InstalledFontChangeEpoch(), cache = InstalledFontDescriptorCache(changes: changes)
        let original = try descriptor()
        let initial = try InstalledFontActiveSignature.capture([original], cache: cache)
        let replacement = root.appendingPathComponent("replacement.ttf")
        try FileManager.default.copyItem(at: font, to: replacement)
        try FileManager.default.removeItem(at: font)
        try FileManager.default.moveItem(at: replacement, to: font)
        let latest = try InstalledFontActiveSignature.capture([original], cache: cache)
        XCTAssertNotEqual(initial.digest, latest.digest, "notification 없이 원본 inode/ctime 변화 확인")
        XCTAssertEqual(latest, try InstalledFontActiveSignature.capture([original]))
        try FileManager.default.removeItem(at: font)
        let failed = try InstalledFontActiveSignature.capture([original], cache: cache)
        XCTAssertFalse(failed.reusable)
        XCTAssertEqual(cache.retainedState().records, 0, "원본 실패 후 과거 속성 폐기")
        let malformed = CTFontDescriptorCreateCopyWithAttributes(original, ["unknown": NSObject()] as CFDictionary)
        XCTAssertEqual(try InstalledFontActiveSignature.capture([malformed], cache: cache),
                       try InstalledFontActiveSignature.capture([malformed]))
        XCTAssertEqual(cache.retainedState().records, 0)
    }

    func testEpochFailureAndLatePublicationCannotReviveOldEntries() throws {
        let changes = InstalledFontChangeEpoch(), cache = InstalledFontDescriptorCache(changes: changes)
        let key = try XCTUnwrap(key(["name": "Fixture"]))
        let old = cache.begin(); cache.store(["old"], for: key, session: old)
        changes.invalidate()
        XCTAssertNil(cache.value(for: key, session: old))
        let current = cache.begin(); XCTAssertEqual(cache.retainedState().records, 0)
        cache.store(["late"], for: key, session: old)
        XCTAssertNil(cache.value(for: key, session: current))
        cache.store(["current"], for: key, session: current)
        cache.invalidate(old)
        XCTAssertEqual(cache.value(for: key, session: current), ["current"])
        cache.invalidate(current)
        cache.store(["late after failure"], for: key, session: current)
        XCTAssertFalse(cache.isCurrent(current)); XCTAssertEqual(cache.retainedState().records, 0)
    }

    func testPermissionLossAndRecoveryWithoutNotification() throws {
        let changes = InstalledFontChangeEpoch(), cache = InstalledFontDescriptorCache(changes: changes)
        let original = try descriptor()
        let before = try InstalledFontActiveSignature.capture([original], cache: cache)
        XCTAssertTrue(before.reusable)
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: root.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path) }
        let failed = try InstalledFontActiveSignature.capture([original], cache: cache)
        XCTAssertFalse(failed.reusable); XCTAssertEqual(cache.retainedState().records, 0)
        XCTAssertNotEqual(before.digest, failed.digest)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
        XCTAssertEqual(try InstalledFontActiveSignature.capture([original], cache: cache),
                       try InstalledFontActiveSignature.capture([original]))
    }

    func testConcurrentPopulationAndBoundedStorageKeepStrictFallback() async throws {
        let changes = InstalledFontChangeEpoch(), cache = InstalledFontDescriptorCache(changes: changes, maximumRecords: 2, maximumBytes: 1024)
        let session = cache.begin()
        await withTaskGroup(of: Void.self) { group in
            for index in 0..<100 {
                group.addTask { cache.store(["field"], for: Data("key-\(index)".utf8), session: session) }
            }
        }
        XCTAssertEqual(cache.retainedState().records, 2); XCTAssertLessThanOrEqual(cache.retainedState().bytes, 1024)
        let tiny = InstalledFontDescriptorCache(changes: changes, maximumRecords: 1, maximumBytes: 1)
        let original = try descriptor()
        XCTAssertEqual(try InstalledFontActiveSignature.capture([original], cache: tiny),
                       try InstalledFontActiveSignature.capture([original]))
        XCTAssertEqual(tiny.retainedState().records, 0)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try InstalledFontActiveSignature.capture([original], cache: cache)
        }
        do { _ = try await task.value; XCTFail("cancelled signature published") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(cache.retainedState().records, 0)
    }
}
