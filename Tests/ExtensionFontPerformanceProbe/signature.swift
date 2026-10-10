import CoreText
import CryptoKit
import Foundation

/// Stage 1 비용 실험용. 제품 현재성 판정에 연결하지 않는다.
enum ActiveSignatureExperiment {
    struct Descriptor: Encodable, Equatable {
        var fields: [String]
    }
    struct Source: Encodable, Equatable {
        var path: String
        var stamp: InstalledFontStamp?
        var failure: String?
    }
    struct Capture {
        let digest: String
        let descriptors: Int
        let sources: Int
    }
    private struct Contents: Encodable {
        let descriptors: [Descriptor]
        let sources: [Source]
    }

    static func digest(_ descriptors: [Descriptor], _ sources: [Source]) throws -> String {
        let value = Contents(descriptors: descriptors.sorted { $0.fields.lexicographicallyPrecedes($1.fields) },
                             sources: sources.sorted { $0.path < $1.path })
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return SHA256.hash(data: try encoder.encode(value)).map { String(format: "%02x", $0) }.joined()
    }

    static func capture() throws -> Capture {
        let collection = CTFontCollectionCreateFromAvailableFonts(nil)
        let available = CTFontCollectionCreateMatchingFontDescriptors(collection) as? [CTFontDescriptor] ?? []
        guard available.count <= InstalledFontSystem.maximumRecords else { throw InstalledFontFailure.catalogLimit }
        var tokens: [Descriptor] = [], sources: [String: Source] = [:]
        for descriptor in available {
            try Task.checkCancellation()
            guard (CTFontDescriptorCopyAttribute(descriptor, kCTFontEnabledAttribute) as? NSNumber)?.boolValue != false else { continue }
            guard let url = CTFontDescriptorCopyAttribute(descriptor, kCTFontURLAttribute) as? URL,
                  let ps = CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String else { continue }
            let path = url.standardizedFileURL.path
            let variation = CTFontDescriptorCopyAttribute(descriptor, kCTFontVariationAttribute) as? [NSNumber: NSNumber] ?? [:]
            let axes = variation.sorted { $0.key.uint32Value < $1.key.uint32Value }
                .map { "\($0.key.uint32Value)=\($0.value.doubleValue)" }.joined(separator: ";")
            let traits = CTFontDescriptorCopyAttribute(descriptor, kCTFontTraitsAttribute) as? [CFString: Any] ?? [:]
            let style = [kCTFontSymbolicTrait, kCTFontWeightTrait, kCTFontWidthTrait, kCTFontSlantTrait]
                .map { (traits[$0] as? NSNumber)?.stringValue ?? "nil" }.joined(separator: ";")
            let family = CTFontDescriptorCopyAttribute(descriptor, kCTFontFamilyNameAttribute) as? String ?? ""
            let name = CTFontDescriptorCopyAttribute(descriptor, kCTFontStyleNameAttribute) as? String ?? ""
            tokens.append(.init(fields: [path, ps, family, name, axes, style])) // 중복 descriptor도 신호로 보존한다.
            if sources[path] == nil {
                do { sources[path] = .init(path: path, stamp: try InstalledFontSystem.statURL(url), failure: nil) }
                catch { sources[path] = .init(path: path, stamp: nil, failure: InstalledFontSystem.failure(error).rawValue) }
            }
        }
        return .init(digest: try digest(tokens, Array(sources.values)), descriptors: tokens.count, sources: sources.count)
    }

    // key의 의미별 차이를 검사한다. 실제 OS 설치/삭제 수용을 대체하지 않는다.
    static func semanticChecks() throws -> Bool {
        let descriptor = Descriptor(fields: ["/fixture/font.ttf", "Fixture-Regular", "Fixture", "Regular", "", "0;0;0;0"])
        let stamp = InstalledFontStamp(device: 1, inode: 1, size: 10, modifiedSeconds: 1,
                                      modifiedNanos: 0, changedSeconds: 1, changedNanos: 0)
        let source = Source(path: "/fixture/font.ttf", stamp: stamp, failure: nil)
        let baseline = try digest([descriptor], [source])
        var changes: [[Descriptor]] = [[], [descriptor, descriptor]]
        for index in descriptor.fields.indices {
            var changed = descriptor; changed.fields[index] += "changed"; changes.append([changed])
        }
        for descriptors in changes { guard try digest(descriptors, [source]) != baseline else { return false } }
        for failure in ["missing", "permissionDenied"] {
            guard try digest([descriptor], [.init(path: source.path, stamp: nil, failure: failure)]) != baseline else { return false }
        }
        let changed = InstalledFontStamp(device: 1, inode: 2, size: 10, modifiedSeconds: 1,
                                        modifiedNanos: 0, changedSeconds: 2, changedNanos: 0)
        return try digest([descriptor], [.init(path: source.path, stamp: changed, failure: nil)]) != baseline
    }
}
