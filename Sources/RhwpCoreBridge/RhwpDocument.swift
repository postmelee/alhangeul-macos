import Foundation
import Rhwp

struct RhwpEmbeddedThumbnail {
    let data: Data
    let width: Int
    let height: Int
    let format: String?
}

/// Rust FFI 호출 에러
enum RhwpError: LocalizedError {
    case parseFailure(filename: String?)
    case invalidData
    case fileReadFailure(filename: String?)
    case accessDenied(filename: String?)

    var errorDescription: String? {
        switch self {
        case .parseFailure(let name):
            let n = name.map { " (\($0))" } ?? ""
            return "이 파일은 HWP/HWPX 형식이 아니거나 손상되었습니다\(n)."
        case .invalidData:
            return "유효하지 않은 데이터입니다."
        case .fileReadFailure(let name):
            let n = name.map { " (\($0))" } ?? ""
            return "파일을 읽을 수 없습니다\(n)."
        case .accessDenied(let name):
            let n = name.map { " (\($0))" } ?? ""
            return "파일에 접근할 수 없습니다\(n). 파일앱에서 다시 선택해 주세요."
        }
    }
}

/// Rust rhwp 엔진의 Swift 래퍼. 문서 핸들의 수명을 관리한다.
///
/// - `rhwp_open`이 데이터를 파싱 후 IR로 복사하므로,
///   `Data.withUnsafeBytes` 밖에서 핸들을 사용해도 안전하다.
/// - 향후 zero-copy 파싱 도입 시 이 가정을 재검토할 것.
class RhwpDocument {
    // 불완전 C 구조체(opaque type)이므로 rhwp_open 반환 타입 그대로 보관
    private let handle: OpaquePointer

    /// HWP/HWPX 파일 데이터를 파싱하여 문서를 연다.
    init(data: Data, filename: String? = nil) throws {
        guard !data.isEmpty else {
            throw RhwpError.invalidData
        }
        let result = data.withUnsafeBytes { rawBuffer -> OpaquePointer? in
            guard let base = rawBuffer.baseAddress else { return nil }
            return rhwp_open(
                base.assumingMemoryBound(to: UInt8.self),
                UInt(data.count)
            )
        }
        guard let validHandle = result else {
            throw RhwpError.parseFailure(filename: filename)
        }
        self.handle = validHandle
    }

    deinit {
        rhwp_close(handle)
    }

    /// 문서의 총 페이지 수
    var pageCount: Int {
        Int(rhwp_page_count(handle))
    }

    /// 특정 페이지의 크기 (포인트 단위)
    func pageSize(at page: Int) -> (width: Double, height: Double) {
        let size = rhwp_page_size(handle, UInt32(page))
        return (size.width_pt, size.height_pt)
    }

    /// 특정 페이지를 SVG 문자열로 렌더링한다.
    func renderPageSVG(at page: Int) -> String? {
        guard let svgPtr = rhwp_render_page_svg(handle, UInt32(page)) else {
            return nil
        }
        let svg = String(cString: svgPtr)
        rhwp_free_string(svgPtr)
        return svg
    }

    /// 특정 페이지의 렌더 트리를 반환한다.
    func renderPageTree(at page: Int) -> RenderNode? {
        guard let json = renderPageTreeJSON(at: page),
              let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(RenderNode.self, from: data)
    }

    /// 특정 페이지의 렌더 트리 원본 JSON 문자열을 반환한다.
    func renderPageTreeJSON(at page: Int) -> String? {
        guard let jsonPtr = rhwp_render_page_tree(handle, UInt32(page)) else {
            return nil
        }
        let json = String(cString: jsonPtr)
        rhwp_free_string(jsonPtr)
        return json
    }

    /// 이미지 바이너리 데이터를 반환한다 (bin_data_id는 1-indexed).
    func imageData(binDataId: UInt16) -> Data? {
        var len: Int = 0
        guard let ptr = rhwp_image_data(handle, binDataId, &len), len > 0 else {
            return nil
        }
        return Data(bytes: ptr, count: len)
    }

    static func extractEmbeddedThumbnail(from data: Data) -> RhwpEmbeddedThumbnail? {
        guard !data.isEmpty else {
            return nil
        }

        var outData: UnsafeMutablePointer<UInt8>?
        var outLen: UInt = 0
        var outWidth: UInt32 = 0
        var outHeight: UInt32 = 0
        var outFormat: UnsafeMutablePointer<CChar>?

        let success = data.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress else { return false }
            return rhwp_extract_thumbnail(
                base.assumingMemoryBound(to: UInt8.self),
                UInt(data.count),
                &outData,
                &outLen,
                &outWidth,
                &outHeight,
                &outFormat
            )
        }

        defer {
            if let ptr = outData, outLen > 0 {
                rhwp_free_bytes(ptr, outLen)
            }
            if let formatPtr = outFormat {
                rhwp_free_string(formatPtr)
            }
        }

        guard success, let thumbnailPtr = outData, outLen > 0 else {
            return nil
        }

        return RhwpEmbeddedThumbnail(
            data: Data(bytes: thumbnailPtr, count: Int(outLen)),
            width: Int(outWidth),
            height: Int(outHeight),
            format: outFormat.map { String(cString: $0) }
        )
    }
}
