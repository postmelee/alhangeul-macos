import Foundation

enum RhwpStudioOutputFontError: String, LocalizedError {
    case invalidRequest, stale, unavailable, unsupported, restricted, tooLarge, cancelled
    var errorDescription: String? {
        switch self {
        case .invalidRequest: "출력 글꼴 요청을 확인할 수 없습니다."
        case .stale: "출력 준비 중 문서나 글꼴이 변경되었습니다. 다시 시도해 주세요."
        case .unavailable: "필요한 글꼴을 읽거나 선택할 수 없습니다."
        case .unsupported: "이 글꼴 형식이나 스타일은 현재 출력에서 지원하지 않습니다."
        case .restricted: "이 글꼴의 임베딩 제한으로 PDF에 포함할 수 없습니다."
        case .tooLarge: "출력에 필요한 글꼴 데이터가 허용 크기를 초과했습니다."
        case .cancelled: "출력이 취소되었습니다."
        }
    }
}

// FontUsageEvidence와 OS/2 선언을 합쳐 새로운 허가 상태를 만들지 않는다.
enum RhwpStudioOutputFontPolicy {
    static func validate(_ bytes: StudioFontBytes) throws {
        let face = bytes.face
        guard face.applicationSupport == .staticCandidate, face.id.sfntIndex == 0,
              face.axes.isEmpty else { throw RhwpStudioOutputFontError.unsupported }
        if bytes.usageEvidence?.embedding == .restricted { throw RhwpStudioOutputFontError.restricted }
        let data = bytes.data
        func u16(_ offset: Int) throws -> UInt16 {
            guard offset >= 0, offset <= data.count - 2 else { throw RhwpStudioOutputFontError.unsupported }
            return UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
        }
        func u32(_ offset: Int) throws -> UInt32 {
            UInt32(try u16(offset)) << 16 | UInt32(try u16(offset + 2))
        }
        guard data.count >= 12 else { throw RhwpStudioOutputFontError.unsupported }
        let signature = try u32(0)
        guard signature == 0x00010000 || signature == 0x4f54544f else { throw RhwpStudioOutputFontError.unsupported }
        let count = Int(try u16(4))
        guard count > 0, count <= 256, 12 + count * 16 <= data.count else { throw RhwpStudioOutputFontError.unsupported }
        for index in 0..<count {
            let record = 12 + index * 16
            guard try u32(record) == 0x4f532f32 else { continue }
            let offset = Int(try u32(record + 8)), length = Int(try u32(record + 12))
            guard length >= 10, offset <= data.count, length <= data.count - offset else {
                throw RhwpStudioOutputFontError.unsupported
            }
            let version = try u16(offset), flags = try u16(offset + 8)
            guard version <= 5, flags == face.embeddingFlags else { throw RhwpStudioOutputFontError.unsupported }
            let permission = flags & 15
            if permission == 2 { throw RhwpStudioOutputFontError.restricted }
            guard [UInt16(0), 4, 8].contains(permission) else { throw RhwpStudioOutputFontError.unsupported }
            // version 0/1에서는 상위 bit가 아직 정의되지 않았다.
            if version >= 2, flags & 0xfff0 != 0 { throw RhwpStudioOutputFontError.unsupported }
            return
        }
        throw RhwpStudioOutputFontError.unsupported
    }
}
