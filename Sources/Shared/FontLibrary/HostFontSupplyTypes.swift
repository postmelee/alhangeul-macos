import Foundation

// WebView에 전달하는 데이터에는 원본 위치와 권한 정보가 없다.
struct StudioFontFace: Encodable, Sendable {
    let id: String
    let source: String
    let postScriptName: String
    let family: String
    let fullName: String
    let style: String
    let aliases: [String]
    let weight: Int?
    let traits: UInt32
    let limitation: String?

    var validMetadata: Bool {
        [id, source, postScriptName, family, fullName, style].allSatisfy { $0.utf8.count <= 1024 }
            && aliases.count <= 32 && aliases.allSatisfy { $0.utf8.count <= 1024 }
    }
}

struct StudioFontBytes: Sendable {
    let data: Data
    let face: FontFace
    let usageEvidence: FontUsageEvidence?

    init(data: Data, face: FontFace, usageEvidence: FontUsageEvidence? = nil) {
        self.data = data; self.face = face; self.usageEvidence = usageEvidence
    }
}

struct StudioFontSupplySnapshot: Sendable {
    let identity: String
    let faces: [StudioFontFace]
    let omitted: Int
    let failure: String?
    let read: @Sendable (String) async throws -> StudioFontBytes
    let current: @Sendable () async throws -> Bool
    let release: @Sendable () async -> Void
}


enum StudioFontError: String, Error {
    case invalidRequest, unauthorized, staleSession, staleGeneration, busy, tooLarge, catalogLimit, unavailable, cancelled
}

// 읽는 중인 요청도 slot을 점유한다. 취소된 I/O가 반환할 때까지 slot을 유지한다.
actor StudioFontTransferBudget {
    static let shared = StudioFontTransferBudget()
    private var slots = Set<UUID>()
    func acquire() throws -> UUID {
        guard slots.count < 2 else { throw StudioFontError.busy }
        let id = UUID(); slots.insert(id); return id
    }
    func release(_ id: UUID) { slots.remove(id) }
}
