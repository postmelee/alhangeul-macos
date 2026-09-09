import Foundation

/// 파일 전달 요청과 편집기 내부의 문서 교체는 서로 다른 세대다.
struct RhwpStudioEditorSnapshot: Codable, Equatable {
    let loadID: Int
    let sequence: Int
    let documentEpoch: Int
    let changeSeq: Int
    let dirty: Bool
    let ready: Bool
    let pageCount: Int
    let format: String

    var isValid: Bool {
        loadID >= 0 && sequence > 0 && documentEpoch > 0 && changeSeq >= 0 &&
            pageCount > 0 && ["hwp", "hwpx", "hml"].contains(format)
    }
}

struct RhwpStudioEditorSession: Equatable {
    enum SourceBinding: Equatable {
        case nativeLoad
        // 복구·내부 열기도 여기에 포함한다. 새 문서처럼 보여도 평문으로 단정하지 않는다.
        case editorOnly
    }

    let snapshot: RhwpStudioEditorSnapshot
    let sourceBinding: SourceBinding

    static func accepting(
        _ snapshot: RhwpStudioEditorSnapshot,
        after previous: Self?,
        loadID: Int,
        hasNativeDocument: Bool
    ) -> Self? {
        guard snapshot.isValid, snapshot.loadID == loadID else { return nil }
        if let previous, previous.snapshot.loadID == loadID {
            guard snapshot.sequence > previous.snapshot.sequence,
                  snapshot.documentEpoch >= previous.snapshot.documentEpoch,
                  snapshot.documentEpoch != previous.snapshot.documentEpoch ||
                    snapshot.changeSeq >= previous.snapshot.changeSeq
            else { return nil }
            return Self(
                snapshot: snapshot,
                sourceBinding: snapshot.documentEpoch == previous.snapshot.documentEpoch
                    ? previous.sourceBinding : .editorOnly
            )
        }
        return Self(snapshot: snapshot, sourceBinding: hasNativeDocument ? .nativeLoad : .editorOnly)
    }
}
