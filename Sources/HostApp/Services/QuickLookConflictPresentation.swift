import Foundation

struct QuickLookConflictPresentation: Equatable, Sendable {
    struct Versions: Equatable, Sendable {
        let app: String
        let preview: String
        let rhwp: String
    }

    let title: String
    let explanation: String
    let recommendation: String?
    let alhangeul: Versions
    let hop: Versions
    let usesVerifiedHopRhwpMapping: Bool

    init?(snapshot: QuickLookConflictSnapshot) {
        guard let hop = snapshot.hop,
              snapshot.guidance != .none
        else {
            return nil
        }

        title = "Quick Look 미리보기 충돌 가능성"
        alhangeul = Versions(
            app: snapshot.alhangeul.app?.displayVersion ?? "확인 불가",
            preview: snapshot.alhangeul.preview?.displayVersion ?? "확인 불가",
            rhwp: Self.rhwpDisplayValue(snapshot.alhangeul.rhwp)
        )
        self.hop = Versions(
            app: hop.app?.displayVersion ?? "확인 불가",
            preview: hop.preview?.displayVersion ?? "확인 불가",
            rhwp: snapshot.hopRhwpReleaseTag ?? "확인 불가"
        )
        usesVerifiedHopRhwpMapping = snapshot.hopRhwpReleaseTag != nil

        switch snapshot.guidance {
        case .none:
            return nil
        case .overlappingProvider:
            explanation = """
            HOP과 알한글의 미리보기 확장이 같은 HWP/HWPX 형식을 지원합니다. \
            두 확장이 함께 설치되어 있으면 macOS가 예상과 다른 미리보기를 선택할 수 있습니다.
            """
            recommendation = nil
        case .preferAlhangeul:
            explanation = """
            HOP과 알한글의 미리보기 확장이 같은 HWP/HWPX 형식을 지원합니다. \
            두 확장이 함께 설치되어 있으면 macOS가 예상과 다른 미리보기를 선택할 수 있습니다.
            """
            recommendation = """
            알한글은 HOP Preview보다 최신인 rhwp 렌더러를 포함합니다. \
            HOP Quick Look Preview를 끄고 알한글 미리보기를 켜는 것을 권장합니다.
            """
        }
    }

    private static func rhwpDisplayValue(_ provenance: RhwpProvenance?) -> String {
        guard let provenance else {
            return "확인 불가"
        }

        return "\(provenance.releaseTag) (\(provenance.shortCommit))"
    }
}
