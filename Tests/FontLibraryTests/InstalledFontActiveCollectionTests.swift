import CoreText
import Foundation
import XCTest

final class InstalledFontActiveCollectionTests: XCTestCase {
    func testFreshCollectionAndDefaultHostKeepActualMetadataAndSignature() throws {
        let host = InstalledFontSystem().environment
        let collection = InstalledFontSystem(activeListMode: .activeCollection).environment
        XCTAssertEqual(try host.scan([]).records, try collection.scan([]).records)
        XCTAssertEqual(try host.scan([]).omittedFaceCount, try collection.scan([]).omittedFaceCount)
        let strict = try XCTUnwrap(host.activeSignature), active = try XCTUnwrap(collection.activeSignature)
        XCTAssertEqual(try strict(), try active())
    }

    func testProcessActivationDisableAndUnregistrationDiscardOldSignature() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let bundled = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "regular", withExtension: "ttf", subdirectory: "Fixtures"))
        let source = root.appendingPathComponent("fixture.ttf")
        try FileManager.default.copyItem(at: bundled, to: source)
        let fileDescriptor = try XCTUnwrap((CTFontManagerCreateFontDescriptorsFromURL(source as CFURL) as? [CTFontDescriptor])?.first)
        let name = try XCTUnwrap(CTFontDescriptorCopyAttribute(fileDescriptor, kCTFontNameAttribute) as? String)
        func available() -> [CTFontDescriptor] {
            CTFontCollectionCreateMatchingFontDescriptors(CTFontCollectionCreateFromAvailableFonts(nil)) as? [CTFontDescriptor] ?? []
        }
        if available().contains(where: { CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String == name }) {
            throw XCTSkip("동명 process fixture가 이미 등록되어 기존 글꼴을 변경하지 않음")
        }
        let changes = InstalledFontChangeEpoch()
        let strict = try XCTUnwrap(InstalledFontSystem().environment.activeSignature)
        let active = try XCTUnwrap(InstalledFontSystem(descriptorCache: .init(changes: changes),
                                                     activeListMode: .activeCollection).environment.activeSignature)
        let baseline = try strict()
        XCTAssertEqual(try active(), baseline)
        var error: Unmanaged<CFError>?
        let registered = CTFontManagerRegisterFontsForURL(source as CFURL, .process, &error)
        if let error { _ = error.takeRetainedValue() }
        XCTAssertTrue(registered); guard registered else { return }
        var retained = true
        defer { if retained { CTFontManagerUnregisterFontsForURL(source as CFURL, .process, nil) } }
        let owned = try XCTUnwrap(available().first {
            (CTFontDescriptorCopyAttribute($0, kCTFontURLAttribute) as? URL)?.standardizedFileURL == source.standardizedFileURL &&
            (CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String) == name &&
            (CTFontDescriptorCopyAttribute($0, kCTFontRegistrationScopeAttribute) as? NSNumber)?.uint32Value == CTFontManagerScope.process.rawValue
        })
        let activated = try strict()
        XCTAssertNotEqual(activated, baseline); XCTAssertEqual(try active(), activated)
        CTFontManagerEnableFontDescriptors([owned] as CFArray, false)
        // 알림을 강제로 갱신하지 않아도 새 collection이 활성 상태 변경을 감지해야 한다.
        XCTAssertEqual(try active(), try strict()); XCTAssertEqual(try active(), baseline)
        CTFontManagerEnableFontDescriptors([owned] as CFArray, true)
        XCTAssertEqual(try active(), try strict()); XCTAssertEqual(try active(), activated)
        let removed = CTFontManagerUnregisterFontsForURL(source as CFURL, .process, nil)
        XCTAssertTrue(removed); guard removed else { return }; retained = false
        XCTAssertEqual(try active(), try strict()); XCTAssertEqual(try active(), baseline)
    }
}
