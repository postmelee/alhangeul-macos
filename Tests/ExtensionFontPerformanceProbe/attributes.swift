import CoreText
import Foundation

/// 실제 descriptor 동등성과 비용을 비교한다. 사용자 OS 글꼴 설치/변경은 하지 않는다.
enum AttributeSignatureExperiment {
    struct Measurement: Encodable {
        let iteration: Int
        let descriptors: Int
        let digest: String
        let reusable: Bool
        let strictMs: Double
        let cachedMs: Double
        let retainedRecords: Int
        let retainedBytes: Int
    }

    static func run(output: URL) throws -> Bool {
        let changes = InstalledFontChangeEpoch(), cache = InstalledFontDescriptorCache(changes: changes)
        func available() -> [CTFontDescriptor] {
            let collection = CTFontCollectionCreateFromAvailableFonts(nil)
            return CTFontCollectionCreateMatchingFontDescriptors(collection) as? [CTFontDescriptor] ?? []
        }
        var measurements: [Measurement] = []
        for iteration in 0...10 {
            // 개별 getter 이후 같은 descriptor를 다시 검사하는 부작용을 피한다.
            // 실제 제품의 capture처럼 각 경로에서 새 available collection을 얻는다.
            let descriptors = available()
            let before = DispatchTime.now().uptimeNanoseconds
            let strict = try InstalledFontActiveSignature.capture(descriptors)
            let middle = DispatchTime.now().uptimeNanoseconds
            let cached = try InstalledFontActiveSignature.capture(available(), cache: cache)
            let after = DispatchTime.now().uptimeNanoseconds
            try require(strict == cached, "real CoreText strict/cached signature equivalence")
            if iteration == 0 {
                try require(try ActiveSignatureExperiment.capture().digest == strict.digest, "Stage 1 reference digest equivalence")
            }
            let state = cache.retainedState()
            measurements.append(.init(iteration: iteration, descriptors: descriptors.count, digest: strict.digest,
                reusable: strict.reusable, strictMs: Double(middle - before) / 1e6, cachedMs: Double(after - middle) / 1e6,
                retainedRecords: state.records, retainedBytes: state.bytes))
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(measurements).write(to: output.appendingPathComponent("attribute-comparison.json"))
        try require(measurements.contains { $0.retainedRecords > 0 }, "eligible actual descriptors cached")
        return true
    }
}
