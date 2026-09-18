import Foundation

// 저장과 실제 renderer 적용은 서로 다른 상태다. 후보 판정은 적용 성공을 뜻하지 않는다.
enum FontFileFormat: String, Codable, Equatable, Sendable {
    case trueType, openTypeCFF, collection
}

enum FontApplicationSupport: String, Codable, Equatable, Sendable {
    case staticCandidate
    case collectionFaceSelectionUnverified
    case variableSelectionUnverified
}

struct FontObject: Codable, Equatable, Sendable {
    let sha256: String
    let byteCount: Int
    let format: FontFileFormat
    let faceCount: Int
    let validationVersion: Int
}

struct FontFaceID: Codable, Hashable, Sendable {
    let objectHash: String
    let sfntIndex: Int
}

struct FontNameRecord: Codable, Equatable, Sendable {
    let platformID: UInt16
    let encodingID: UInt16
    let languageID: UInt16
    let nameID: UInt16
    let languageTag: String?
    // 해석하지 못한 인코딩도 원문 bytes를 잃지 않는다.
    let bytes: Data
    let value: String?
}

struct FontVariationAxis: Codable, Equatable, Sendable {
    let tag: String
    let minimum: Double
    let defaultValue: Double
    let maximum: Double
    let flags: UInt16
    let nameID: UInt16
}

struct FontNamedInstance: Codable, Equatable, Sendable {
    let subfamilyNameID: UInt16
    let postScriptNameID: UInt16?
    let coordinates: [String: Double]
}

struct FontFace: Codable, Equatable, Sendable {
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

struct InspectedFont: Equatable, Sendable {
    let object: FontObject
    let faces: [FontFace]
    let filenameExtensionMismatch: Bool
}

enum FontSourceKind: String, Codable, Sendable {
    case macApplication, macInstalled, windowsTransfer, userSelected
}

struct FontSourceReceipt: Codable, Equatable, Sendable {
    let id: UUID
    let kind: FontSourceKind
    let originalFilename: String
    let localSourcePath: String?
    let bookmark: Data?
    let importedAt: Date
}

// fsType와 별개로 기록한다. unknown은 허가로 간주하지 않는다.
struct FontUsageEvidence: Codable, Equatable, Sendable {
    enum Decision: String, Codable, Sendable { case unknown, allowed, restricted }
    let localCopy: Decision
    let embedding: Decision
    let note: String?
    let licenseResourceID: String?
}

struct FontActiveSelection: Codable, Equatable, Sendable {
    let conflictGroupID: String
    let faceID: FontFaceID
    let axes: [String: Double]
}

enum FontImportStatus: String, Codable, Sendable {
    case added, alreadyPresent, selectionRequired, unsupported, corrupt, readFailure, storageFailure, cancelled
}

struct FontImportItemResult: Codable, Equatable, Sendable {
    let candidateID: UUID
    let status: FontImportStatus
    let objectHash: String?
    let reasonCode: String?
    let nextAction: NextAction
    let publication: FontPublicationState

    enum NextAction: String, Codable, Sendable {
        case none, chooseActiveFace, chooseSupportedFile, chooseReadableFile, retry, reviewSupportLimits
    }
}

// 입력값이나 절대 경로를 오류 로그에 포함하지 않는다.
enum FontInspectionError: Error, Equatable, Sendable {
    case emptyFile
    case fileTooLarge
    case unsupportedFormat
    case malformedStructure
    case unsupportedStructure
    case metadataLimitExceeded
    case coreTextRejected
    case missingPostScriptName
}

struct FontInspectionLimits: Sendable {
    var maximumFileBytes = 64 * 1024 * 1024
    var maximumFaces = 256
    var maximumTablesPerFace = 256
    var maximumNameRecords = 4096
    var maximumNameBytes = 1024 * 1024
    var maximumAxes = 64
    var maximumInstances = 4096
}

struct FontImportCandidate: Sendable {
    let id: UUID
    let sourceURL: URL
    let sourceKind: FontSourceKind
    let usageEvidence: FontUsageEvidence

    init(sourceURL: URL, id: UUID = UUID(), sourceKind: FontSourceKind = .userSelected,
         usageEvidence: FontUsageEvidence = .init(localCopy: .unknown, embedding: .unknown,
                                                  note: nil, licenseResourceID: nil)) {
        self.id = id
        self.sourceURL = sourceURL
        self.sourceKind = sourceKind
        self.usageEvidence = usageEvidence
    }
}

struct FontLibraryEntry: Codable, Equatable, Sendable {
    let object: FontObject
    let faces: [FontFace]
    let source: FontSourceReceipt
    let usageEvidence: FontUsageEvidence
    let filenameExtensionMismatch: Bool
}

struct FontConflictGroup: Codable, Equatable, Sendable {
    let id: String
    var members: [FontFaceID]
}

struct FontLibraryManifest: Codable, Equatable, Sendable {
    var schemaVersion = 1
    var generation: UInt64 = 0
    var entries: [FontLibraryEntry] = []
    var conflictGroups: [FontConflictGroup] = []
    var activeSelections: [FontActiveSelection] = []
}

struct FontImportLimits: Sendable {
    var maximumFileBytes = 64 * 1024 * 1024
    var maximumCandidates = 4096
    var maximumBatchBytes = 1024 * 1024 * 1024
}

enum FontPublicationState: String, Codable, Sendable {
    case notPublished, durable, visibleDurabilityUnconfirmed
}

enum FontLibraryError: Error, Equatable, Sendable {
    case unsafePath, notRegularFile, inputChanged, inputLimitExceeded, cancelled
    case io(Int32)
    case directoryIO(operation: String, code: Int32)
    case corruptManifest, unsupportedSchema, missingManifest, corruptObject
    case staleGeneration, invalidSelection, unsupportedSelection, capacityExceeded
    case invalidResource, releasedSnapshot, snapshotLibraryMismatch, corruptLease
    case publicationUncertain
}

enum FontLibraryWritePhase: String, CaseIterable, Sendable {
    case stagingCreated, stageWritten, stageSynced, objectPublished, objectDirectorySynced
    case manifestWritten, manifestSynced, manifestReplaced, manifestDirectorySynced
}
