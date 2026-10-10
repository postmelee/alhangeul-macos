import CoreText
import CryptoKit
import Foundation

/// 전체 CTFont 이름/축 정규화 없이 현재 활성 descriptor와 원본 상태를 확인한다.
struct InstalledFontActiveSignature: Equatable, Sendable {
    let digest: String
    let reusable: Bool

    private struct Descriptor: Encodable { let fields: [String] }
    private struct Source: Encodable {
        let path: String
        let stamp: InstalledFontStamp?
        let failure: String?
    }
    private struct Contents: Encodable {
        let descriptors: [Descriptor]
        let sources: [Source]
    }

    static func capture(_ descriptors: [CTFontDescriptor]) throws -> Self {
        let active = descriptors.filter {
            (CTFontDescriptorCopyAttribute($0, kCTFontEnabledAttribute) as? NSNumber)?.boolValue != false
        }
        return try captureActive(active)
    }

    // CoreText collection의 활성 필터를 통과한 목록은 enabled를 다시 조회하지 않는다.
    static func captureActive(_ active: [CTFontDescriptor]) throws -> Self {
        guard active.count <= InstalledFontSystem.maximumRecords else { throw InstalledFontFailure.catalogLimit }
        var tokens: [Descriptor] = [], sources: [String: Source] = [:], reusable = true
        for descriptor in active {
            try Task.checkCancellation()
            let url = CTFontDescriptorCopyAttribute(descriptor, kCTFontURLAttribute) as? URL
            let ps = CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String
            let family = CTFontDescriptorCopyAttribute(descriptor, kCTFontFamilyNameAttribute) as? String
            let style = CTFontDescriptorCopyAttribute(descriptor, kCTFontStyleNameAttribute) as? String
            if url == nil || ps == nil || family == nil || style == nil { reusable = false }
            let path = url?.standardizedFileURL.path ?? ""
            let rawVariation = CTFontDescriptorCopyAttribute(descriptor, kCTFontVariationAttribute)
            let variation = rawVariation as? [NSNumber: NSNumber] ?? [:]
            if rawVariation != nil && rawVariation as? [NSNumber: NSNumber] == nil { reusable = false }
            let axes = variation.sorted { $0.key.uint32Value < $1.key.uint32Value }.map {
                if !$0.value.doubleValue.isFinite { reusable = false }
                return "\($0.key.uint32Value)=\($0.value.doubleValue)"
            }.joined(separator: ";")
            let rawTraits = CTFontDescriptorCopyAttribute(descriptor, kCTFontTraitsAttribute)
            let traits = rawTraits as? [CFString: Any] ?? [:]
            if rawTraits != nil && rawTraits as? [CFString: Any] == nil { reusable = false }
            let traitKey = [kCTFontSymbolicTrait, kCTFontWeightTrait, kCTFontWidthTrait, kCTFontSlantTrait].map { key in
                guard let raw = traits[key] else { return "nil" }
                guard let value = raw as? NSNumber, value.doubleValue.isFinite else { reusable = false; return "invalid" }
                return value.stringValue
            }.joined(separator: ";")
            tokens.append(.init(fields: [path, ps ?? "", family ?? "", style ?? "", axes, traitKey]))
            if let url, sources[path] == nil {
                do { sources[path] = .init(path: path, stamp: try InstalledFontSystem.statURL(url), failure: nil) }
                catch {
                    reusable = false
                    sources[path] = .init(path: path, stamp: nil, failure: InstalledFontSystem.failure(error).rawValue)
                }
            }
        }
        // 중복은 보존하고 순서만 제거한다. 원본 stat은 경로별 한 번이다.
        let contents = Contents(descriptors: tokens.sorted { $0.fields.lexicographicallyPrecedes($1.fields) },
                                sources: sources.values.sorted { $0.path < $1.path })
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let digest = SHA256.hash(data: try encoder.encode(contents)).map { String(format: "%02x", $0) }.joined()
        return .init(digest: digest, reusable: reusable)
    }
}
