import CoreText
import Foundation

/// 매번 새 collection을 얻는다. 등록/해제는 이 프로세스의 OFL 파일에만 적용한다.
enum ActiveCollectionExperiment {
    struct Measurement: Encodable {
        let phase: String
        let iteration: Int
        let strictCount: Int
        let collectionCount: Int
        let digest: String
        let reusable: Bool
        let strictMs: Double
        let collectionMs: Double
        let fixturePresent: Bool
    }

    static func available(explicitActive: Bool) -> [CTFontDescriptor] {
        let options = explicitActive ? [kCTFontCollectionIncludeDisabledFontsOption: false] as CFDictionary : nil
        let collection = CTFontCollectionCreateFromAvailableFonts(options)
        return CTFontCollectionCreateMatchingFontDescriptors(collection) as? [CTFontDescriptor] ?? []
    }

    private static func identities(_ descriptors: [CTFontDescriptor]) -> [[String]] {
        descriptors.map {
            [(CTFontDescriptorCopyAttribute($0, kCTFontURLAttribute) as? URL)?.standardizedFileURL.path ?? "",
             CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String ?? ""]
        }.sorted { $0.lexicographicallyPrecedes($1) }
    }

    static func run(input: URL, output: URL) async throws -> Bool {
        let changes = InstalledFontChangeEpoch(), cache = InstalledFontDescriptorCache(changes: changes)
        let source = input.appendingPathComponent("GowunBatang-Regular.ttf")
        guard let fixture = (CTFontManagerCreateFontDescriptorsFromURL(source as CFURL) as? [CTFontDescriptor])?.first,
              let name = CTFontDescriptorCopyAttribute(fixture, kCTFontNameAttribute) as? String else {
            throw PerformanceFailure.invalid("OFL descriptor")
        }
        let containsFixture: ([CTFontDescriptor]) -> Bool = { descriptors in
            descriptors.contains { (CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String) == name }
        }
        try require(!containsFixture(available(explicitActive: false)), "process fixture must not shadow an existing font")
        var measurements: [Measurement] = []
        func compare(_ phase: String, _ iteration: Int, present: Bool) throws -> InstalledFontActiveSignature {
            let start = DispatchTime.now().uptimeNanoseconds
            let strict = available(explicitActive: false).filter {
                (CTFontDescriptorCopyAttribute($0, kCTFontEnabledAttribute) as? NSNumber)?.boolValue != false
            }
            let first = try InstalledFontActiveSignature.captureActive(strict)
            let middle = DispatchTime.now().uptimeNanoseconds
            let active = available(explicitActive: true)
            let second = try InstalledFontActiveSignature.captureActive(active, cache: cache)
            let end = DispatchTime.now().uptimeNanoseconds
            try require(identities(strict) == identities(active), "fresh active multiset equivalence")
            try require(first == second, "fresh signature digest/reusable equivalence")
            measurements.append(.init(phase: phase, iteration: iteration, strictCount: strict.count,
                collectionCount: active.count, digest: first.digest, reusable: first.reusable,
                strictMs: Double(middle - start) / 1e6, collectionMs: Double(end - middle) / 1e6,
                fixturePresent: containsFixture(active)))
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(measurements).write(to: output.appendingPathComponent("collection-comparison.json"))
            try require(containsFixture(active) == present, "process enabled/disabled matching: " + phase)
            return first
        }
        var baseline: InstalledFontActiveSignature?
        for index in 0...10 {
            let value = try compare("baseline", index, present: false)
            if let baseline { try require(value == baseline, "unchanged ambient collection") }
            baseline = value
        }
        var error: Unmanaged<CFError>?
        try require(CTFontManagerRegisterFontsForURL(source as CFURL, .process, &error), "process font registration")
        var registered = true
        defer { if registered { CTFontManagerUnregisterFontsForURL(source as CFURL, .process, nil) } }
        changes.invalidate()
        let activated = try compare("registered-enabled", 0, present: true)
        try require(activated != baseline, "process activation detected")
        // GetScopeForURL은 process 등록에 none을 반환하므로 실제 matching descriptor의 scope를 확인한다.
        let owned = available(explicitActive: false).filter {
            (CTFontDescriptorCopyAttribute($0, kCTFontURLAttribute) as? URL)?.standardizedFileURL == source.standardizedFileURL &&
            (CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String) == name &&
            (CTFontDescriptorCopyAttribute($0, kCTFontRegistrationScopeAttribute) as? NSNumber)?.uint32Value == CTFontManagerScope.process.rawValue
        }
        try require(owned.count == 1, "exact URL/PS/process scope guard")
        CTFontManagerEnableFontDescriptors(owned as CFArray, false); changes.invalidate()
        try require(try compare("disabled", 0, present: false) == baseline, "disabled excluded")
        CTFontManagerEnableFontDescriptors(owned as CFArray, true); changes.invalidate()
        try require(try compare("re-enabled", 0, present: true) == activated, "activation restored")
        try require(CTFontManagerUnregisterFontsForURL(source as CFURL, .process, &error), "process font unregistration")
        registered = false; changes.invalidate()
        try require(try compare("unregistered", 0, present: false) == baseline, "process deactivation restored")
        return true
    }
}
