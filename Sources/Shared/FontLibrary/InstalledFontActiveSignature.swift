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

    static func capture(_ descriptors: [CTFontDescriptor], cache: InstalledFontDescriptorCache? = nil) throws -> Self {
        let active = descriptors.filter {
            (CTFontDescriptorCopyAttribute($0, kCTFontEnabledAttribute) as? NSNumber)?.boolValue != false
        }
        return try captureActive(active, cache: cache)
    }

    // CoreText collection의 활성 필터를 통과한 목록은 enabled를 다시 조회하지 않는다.
    static func captureActive(_ active: [CTFontDescriptor], cache: InstalledFontDescriptorCache? = nil) throws -> Self {
        let session = cache?.begin()
        do {
            guard active.count <= InstalledFontSystem.maximumRecords else { throw InstalledFontFailure.catalogLimit }
            let result = try captureActive(active, cache: cache, session: session)
            if let cache, let session {
                guard cache.isCurrent(session) else { throw InstalledFontFailure.staleGeneration }
                if !result.reusable { cache.invalidate(session) }
            }
            return result
        } catch {
            if let cache, let session { cache.invalidate(session) }
            throw error
        }
    }

    private static func captureActive(_ active: [CTFontDescriptor], cache: InstalledFontDescriptorCache?,
                                      session: InstalledFontDescriptorCache.Session?) throws -> Self {
        var tokens: [Descriptor] = [], sources: [String: Source] = [:], reusable = true
        for descriptor in active {
            try Task.checkCancellation()
            let url = CTFontDescriptorCopyAttribute(descriptor, kCTFontURLAttribute) as? URL
            let ps = CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String
            let path = url?.standardizedFileURL.path ?? ""
            if let url, sources[path] == nil {
                do { sources[path] = .init(path: path, stamp: try InstalledFontSystem.statURL(url), failure: nil) }
                catch {
                    reusable = false
                    sources[path] = .init(path: path, stamp: nil, failure: InstalledFontSystem.failure(error).rawValue)
                }
            }
            let key: Data?
            if cache != nil, let url, let ps, let stamp = sources[path]?.stamp {
                key = InstalledFontDescriptorCache.key(attributes: CTFontDescriptorCopyAttributes(descriptor), url: url, postScriptName: ps, stamp: stamp)
            } else { key = nil }
            if let cache, let session, let key, let fields = cache.value(for: key, session: session) {
                tokens.append(.init(fields: fields)); continue
            }
            let normalized = normalizedFields(descriptor, path: path, ps: ps, hasURL: url != nil)
            reusable = reusable && normalized.reusable
            tokens.append(.init(fields: normalized.fields))
            if let cache, let session, let key, let url, normalized.reusable,
               let stamp = sources[path]?.stamp {
                guard try InstalledFontSystem.statURL(url) == stamp else { throw InstalledFontFailure.changed }
                cache.store(normalized.fields, for: key, session: session)
            }
        }
        // 중복은 보존하고 순서만 제거한다. 원본 stat은 경로별 중복 제거하며 cache miss는 저장 전 재확인한다.
        let contents = Contents(descriptors: tokens.sorted { $0.fields.lexicographicallyPrecedes($1.fields) },
                                sources: sources.values.sorted { $0.path < $1.path })
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let digest = SHA256.hash(data: try encoder.encode(contents)).map { String(format: "%02x", $0) }.joined()
        return .init(digest: digest, reusable: reusable)
    }

    private static func normalizedFields(_ descriptor: CTFontDescriptor, path: String, ps: String?,
                                         hasURL: Bool) -> (fields: [String], reusable: Bool) {
        var reusable = true
        let family = CTFontDescriptorCopyAttribute(descriptor, kCTFontFamilyNameAttribute) as? String
        let style = CTFontDescriptorCopyAttribute(descriptor, kCTFontStyleNameAttribute) as? String
        if !hasURL || ps == nil || family == nil || style == nil { reusable = false }
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
        return ([path, ps ?? "", family ?? "", style ?? "", axes, traitKey], reusable)
    }
}
