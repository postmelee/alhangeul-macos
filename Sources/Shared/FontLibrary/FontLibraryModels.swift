import Foundation

// 저장과 실제 renderer 적용은 서로 다른 상태다. 후보 판정은 적용 성공을 뜻하지 않는다.
enum FontFileFormat: String, Codable, Equatable {
    case trueType, openTypeCFF, collection
}

enum FontApplicationSupport: String, Codable, Equatable {
    case staticCandidate
    case collectionFaceSelectionUnverified
    case variableSelectionUnverified
}

struct FontObject: Codable, Equatable {
    let sha256: String
    let byteCount: Int
    let format: FontFileFormat
    let faceCount: Int
    let validationVersion: Int
}

struct FontFaceID: Codable, Hashable {
    let objectHash: String
    let sfntIndex: Int
}

struct FontNameRecord: Codable, Equatable {
    let platformID: UInt16
    let encodingID: UInt16
    let languageID: UInt16
    let nameID: UInt16
    let languageTag: String?
    // 해석하지 못한 인코딩도 원문 bytes를 잃지 않는다.
    let bytes: Data
    let value: String?
}

struct FontVariationAxis: Codable, Equatable {
    let tag: String
    let minimum: Double
    let defaultValue: Double
    let maximum: Double
    let flags: UInt16
    let nameID: UInt16
}

struct FontNamedInstance: Codable, Equatable {
    let subfamilyNameID: UInt16
    let postScriptNameID: UInt16?
    let coordinates: [String: Double]
}

struct FontFace: Codable, Equatable {
    let id: FontFaceID
    let names: [FontNameRecord]
    let familyName: String?
    let subfamilyName: String?
    let fullName: String?
    let postScriptName: String
    let version: String?
    let weightClass: UInt16
    let widthClass: UInt16
    let selectionFlags: UInt16
    let italicAngle: Double
    let glyphCount: UInt16
    // OS/2 선언값이며 실제 cmap 지원 문자 전체를 보증하지 않는다.
    let declaredUnicodeRanges: [UInt32]
    let embeddingFlags: UInt16
    let axes: [FontVariationAxis]
    let namedInstances: [FontNamedInstance]
    let applicationSupport: FontApplicationSupport
}

struct InspectedFont: Equatable {
    let object: FontObject
    let faces: [FontFace]
    let filenameExtensionMismatch: Bool
}

enum FontSourceKind: String, Codable {
    case macApplication, macInstalled, windowsTransfer, userSelected
}

struct FontSourceReceipt: Codable, Equatable {
    let id: UUID
    let kind: FontSourceKind
    let originalFilename: String
    let localSourcePath: String?
    let bookmark: Data?
    let importedAt: Date
}

// fsType와 별개로 기록한다. unknown은 허가로 간주하지 않는다.
struct FontUsageEvidence: Codable, Equatable {
    enum Decision: String, Codable { case unknown, allowed, restricted }
    let localCopy: Decision
    let embedding: Decision
    let note: String?
    let licenseResourceID: String?
}

struct FontActiveSelection: Codable, Equatable {
    let conflictGroupID: String
    let faceID: FontFaceID
    let axes: [String: Double]
}

enum FontImportStatus: String, Codable {
    case added, alreadyPresent, selectionRequired, unsupported, corrupt, readFailure, cancelled
}

struct FontImportItemResult: Codable, Equatable {
    let candidateID: UUID
    let status: FontImportStatus
    let objectHash: String?
    let reasonCode: String?
    let nextAction: NextAction

    enum NextAction: String, Codable {
        case none, chooseActiveFace, chooseSupportedFile, chooseReadableFile, retry, reviewSupportLimits
    }
}

// 입력값이나 절대 경로를 오류 로그에 포함하지 않는다.
enum FontInspectionError: Error, Equatable {
    case emptyFile
    case fileTooLarge
    case unsupportedFormat
    case malformedStructure
    case unsupportedStructure
    case metadataLimitExceeded
    case coreTextRejected
    case missingPostScriptName
}

struct FontInspectionLimits {
    var maximumFileBytes = 64 * 1024 * 1024
    var maximumFaces = 256
    var maximumTablesPerFace = 256
    var maximumNameRecords = 4096
    var maximumNameBytes = 1024 * 1024
    var maximumAxes = 64
    var maximumInstances = 4096
}
