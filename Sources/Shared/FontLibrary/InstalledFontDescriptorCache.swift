import CoreText
import Foundation

/// 확장의 계산 속성만 보관한다. 활성 목록·enabled·URL·원본 stat은 호출마다 다시 읽는다.
final class InstalledFontDescriptorCache: @unchecked Sendable {
    struct Session: Equatable { let epoch: UInt64; let revision: UInt64 }
    private let changes: InstalledFontChangeEpoch
    private let lock = NSLock()
    private let maximumRecords: Int
    private let maximumBytes: Int
    private var epoch: UInt64?
    private var revision: UInt64 = 0
    private var values: [Data: [String]] = [:]
    private var bytes = 0

    init(changes: InstalledFontChangeEpoch, maximumRecords: Int = InstalledFontSystem.maximumRecords,
         maximumBytes: Int = 16 * 1024 * 1024) {
        self.changes = changes; self.maximumRecords = max(0, maximumRecords); self.maximumBytes = max(0, maximumBytes)
    }

    func begin() -> Session {
        let current = changes.current()
        lock.lock(); defer { lock.unlock() }
        if epoch != current { reset(); epoch = current }
        return .init(epoch: current, revision: revision)
    }

    func isCurrent(_ session: Session) -> Bool {
        guard changes.current() == session.epoch else { return false }
        lock.lock(); defer { lock.unlock() }
        return epoch == session.epoch && revision == session.revision
    }

    func value(for key: Data, session: Session) -> [String]? {
        guard changes.current() == session.epoch else { return nil }
        lock.lock(); defer { lock.unlock() }
        guard epoch == session.epoch, revision == session.revision else { return nil }
        return values[key]
    }

    func store(_ fields: [String], for key: Data, session: Session) {
        guard changes.current() == session.epoch else { return }
        lock.lock(); defer { lock.unlock() }
        guard epoch == session.epoch, revision == session.revision, values[key] == nil,
              values.count < maximumRecords else { return }
        let size = key.count + fields.reduce(0) { $0 + $1.utf8.count + 8 }
        guard size <= maximumBytes - bytes else { return }
        values[key] = fields; bytes += size
    }

    func invalidate(_ session: Session) {
        lock.lock(); defer { lock.unlock() }
        guard epoch == session.epoch, revision == session.revision else { return }
        reset()
    }

    func retainedState() -> (records: Int, bytes: Int) {
        lock.lock(); defer { lock.unlock() }
        return (values.count, bytes)
    }

    private func reset() { values.removeAll(keepingCapacity: false); bytes = 0; revision &+= 1 }

    /// 최소 속성 dictionary 전체를 보존한다. 알 수 없는 값은 cache 불가로 처리한다.
    /// 해시 충돌을 cache 일치로 간주하지 않도록 직렬화한 key 자체를 비교한다.
    static func key(attributes: CFDictionary, url: URL, postScriptName: String, stamp: InstalledFontStamp) -> Data? {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        guard let attributes = encode(attributes, depth: 0), attributes.count <= 64 * 1024,
              let source = try? encoder.encode(Source(url: url.absoluteString, postScriptName: postScriptName, stamp: stamp)) else { return nil }
        var key = Data(); append(attributes, to: &key); append(source, to: &key)
        return key
    }

    private struct Source: Encodable { let url: String; let postScriptName: String; let stamp: InstalledFontStamp }
    private static func append(_ value: Data, to data: inout Data) {
        var length = UInt64(value.count).bigEndian
        withUnsafeBytes(of: &length) { data.append(contentsOf: $0) }
        data.append(value)
    }

    private static func encode(_ value: Any, depth: Int) -> Data? {
        guard depth < 16 else { return nil }
        let type = CFGetTypeID(value as CFTypeRef)
        if type == CFStringGetTypeID(), let string = value as? String {
            guard string.utf8.count < 64 * 1024 else { return nil }
            return Data(("s" + string).utf8)
        }
        if type == CFBooleanGetTypeID(), let number = value as? NSNumber {
            return Data((number.boolValue ? "b1" : "b0").utf8)
        }
        if type == CFNumberGetTypeID(), let number = value as? NSNumber, number.doubleValue.isFinite {
            // NSNumber의 타입과 값을 함께 보존해 축/traits의 서로 다른 입력을 합치지 않는다.
            return Data(("n" + String(cString: number.objCType) + ":" + number.stringValue).utf8)
        }
        if type == CFURLGetTypeID(), let url = value as? URL {
            guard url.absoluteString.utf8.count < 64 * 1024 else { return nil }
            return Data(("u" + url.absoluteString).utf8)
        }
        if type == CFDataGetTypeID(), let data = value as? Data {
            guard data.count < 64 * 1024 else { return nil }
            var result = Data([100]); result.append(data); return result
        }
        if type == CFArrayGetTypeID(), let array = value as? NSArray, array.count <= 20_000 {
            var result = Data([97])
            for element in array {
                guard let item = encode(element, depth: depth + 1) else { return nil }
                append(item, to: &result); guard result.count <= 64 * 1024 else { return nil }
            }
            return result
        }
        if type == CFDictionaryGetTypeID(), let dictionary = value as? NSDictionary, dictionary.count <= 20_000 {
            var entries: [(Data, Data)] = []
            var size = 1
            for (key, value) in dictionary {
                guard let key = encode(key, depth: depth + 1), let value = encode(value, depth: depth + 1) else { return nil }
                size += key.count + value.count + 16
                guard size <= 64 * 1024 else { return nil }
                entries.append((key, value))
            }
            entries.sort { $0.0.lexicographicallyPrecedes($1.0) }
            var result = Data([109])
            for (key, value) in entries {
                append(key, to: &result); append(value, to: &result)
                guard result.count <= 64 * 1024 else { return nil }
            }
            return result
        }
        return nil
    }
}
