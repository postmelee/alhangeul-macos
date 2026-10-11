import Foundation

// 소비자용 메타데이터. 원본 URL, bookmark, 파일 identity는 native 안에만 둔다.
struct InstalledFontSupplyCatalog: Encodable, Sendable {
    struct Face: Encodable, Sendable {
        let resourceID: String
        let postScriptName: String
        let family: String
        let fullName: String
        let style: String
        let version: String?
        let traits: UInt32
        let axes: [InstalledFontAxis]
        let limitation: InstalledFontFailure?
    }
    let generation: UUID
    let enabled: Bool
    let failure: InstalledFontFailure?
    let omittedFaceCount: Int
    let faces: [Face]

    init(_ snapshot: InstalledFontSnapshot) {
        generation = snapshot.generation
        enabled = snapshot.enabled
        failure = snapshot.refreshFailure
        omittedFaceCount = snapshot.omittedFaceCount
        faces = snapshot.records.map {
            Face(resourceID: $0.id, postScriptName: $0.postScriptName,
                 family: $0.family, fullName: $0.fullName, style: $0.style,
                 version: $0.version, traits: $0.traits, axes: $0.axes,
                 limitation: $0.failure ?? ($0.axes.isEmpty ? nil : .unsupported))
        }
    }
}
