import Foundation
import CoreGraphics

extension StudioFontSupply {
    // HostApp과 격리 수용은 같은 공급 원천으로 native consumer를 연다.
    // Finder의 별도 프로세스 권한·공급 진입 연결은 Stage 5에서 수행한다.
    func renderNativePage(data: Data, filename: String, pageIndex: Int = 0,
                          maximumPixelSize: CGSize? = nil, policy: HwpPageRenderPolicy = .coreGraphicsOnly) async throws -> HwpNativeFontPageResult {
        try await HwpNativeFontPageRenderer.render(data: data, filename: filename, pageIndex: pageIndex,
            snapshot: try await snapshot(), maximumPixelSize: maximumPixelSize, policy: policy)
    }

}
