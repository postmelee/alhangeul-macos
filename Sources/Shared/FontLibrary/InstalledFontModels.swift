import Foundation

// 이 모델은 native 전용이다. URL/bookmark를 WebView 메시지로 직렬화하지 않는다.
enum InstalledFontFailure: String, Error, Codable, Sendable {
    case busy, disabled, notPrepared, inactive, missing, permissionDenied, stalePermission
    case permissionUnresolvable, changed, conflict, corrupt, unsupported, tooLarge
    case staleGeneration, storage, incompatibleStorage, catalogLimit, cancelled
}

struct InstalledFontStamp: Codable, Equatable, Sendable {
    let device: UInt64
    let inode: UInt64
    let size: Int64
    let modifiedSeconds: Int64
    let modifiedNanos: Int64
    let changedSeconds: Int64
    let changedNanos: Int64
}

struct InstalledFontAxis: Codable, Equatable, Sendable {
    let identifier: UInt32
    let minimum: Double
    let maximum: Double
    let defaultValue: Double
    let value: Double
}

struct InstalledFontRecord: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let sourceURL: URL
    let postScriptName: String
    let family: String
    let fullName: String
    let style: String
    let version: String?
    let traits: UInt32
    let axes: [InstalledFontAxis]
    var stamp: InstalledFontStamp?
    // nil은 metadata 접근 가능을 뜻한다. renderer 적용/라이선스 허가의 뜻이 아니다.
    var failure: InstalledFontFailure?
}

struct InstalledFontGrant: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let bookmark: Data
}

struct InstalledFontGrantIssue: Equatable, Sendable {
    let id: UUID
    let failure: InstalledFontFailure
}

struct InstalledFontSnapshot: Equatable, Sendable {
    let generation: UUID
    let enabled: Bool
    let records: [InstalledFontRecord]
    let grantIssues: [InstalledFontGrantIssue]
    let refreshFailure: InstalledFontFailure?
    let omittedFaceCount: Int
}

struct InstalledFontResource: Sendable {
    let resourceID: String
    let generation: UUID
    let data: Data
    // 실제 읽은 동일 bytes를 검증해 얻은 정확한 face와 SHA-256이다.
    let face: FontFace
}

struct InstalledFontScan: Sendable {
    let records: [InstalledFontRecord]
    let grantIssues: [InstalledFontGrantIssue]
    var omittedFaceCount: Int = 0
}

struct InstalledFontRead: Sendable {
    let data: Data
    let face: FontFace
}

struct InstalledFontEnvironment: Sendable {
    let scan: @Sendable ([InstalledFontGrant]) throws -> InstalledFontScan
    let read: @Sendable (InstalledFontRecord, [InstalledFontGrant]) async throws -> InstalledFontRead
    let makeBookmark: @Sendable (URL) throws -> Data
}

struct InstalledFontSavedState: Codable {
    let schema: Int
    var enabled: Bool
    var records: [InstalledFontRecord]
    var grants: [InstalledFontGrant]
}
