# Task M020 #470 Stage 4 — PR 리뷰 보완

CellContext.parentParaIndex와 CellPathEntry.cellIndex/cellParaIndex를 pinned Rust usize와 같은 UInt로 보존한다. known tag는 CaseIterable enum에서 파생하고 payload switch가 모든 case를 처리하여 수동 이름 집합과의 drift를 방지한다. 다중 tag는 variant를 임의 선택하지 않으며 nil variant를 unresolved로 표시한다. throwing API는 pageCount 밖도 invalidPageIndex로 분류한다. raw JSON API는 실제 FFI null-output 검증을 위해 UInt32 변환만 검사한다.

검증 결과:

- 기존 current/legacy/future/malformed/privacy 계약과 UInt.max 및 UInt.max−1 정밀도 보존 통과.
- CellContext의 네 unsigned 필드의 큰 정수 보존과 각 음수 거부 통과.
- 알려진 24종 모두의 valid wire payload/unit decode 및 반대 표현 거부 통과.
- HWP 3종/HWPX 1종 native smoke와 실제 pageCount/음수/UInt32 경계·FFI null 검증 통과. TextRun은 KTX 415, request 103, exam 133, HWPX 269로 기존 성공 결과와 같다.
- no-AppKit, xcodegen/HostApp Debug build(16.923초), shell syntax, diff 검증 통과. 최초 build의 Sparkle 다운로드 제한은 네트워크 허용 후 재실행으로 해소했다.
- core/Cargo/FFI lock과 renderer layout source는 변경하지 않았다.

로그: `build.noindex/task470/review-{decoder,native,build,registration}.log`. Xcode가 등록한 개발 bundle은 표준 등록 위생 helper의 cleanup 대상으로 처리한다. 기존 설치본은 삭제하지 않는다.

## 최소 지원 OS 잔여 조건

현재 실제 실행 OS는 macOS 26.5.2이며 PR CI는 macos-15다. 작업지시자가 macOS 12 기기/VM이 없음을 확인했고 저장소 self-hosted runner도 0개다. 따라서 macOS 12 runtime 검증은 미실행이며 병합 전 확인 조건으로 남긴다. deploymentTarget 상향 또는 known payload의 조용한 unknown 격하로 대신하지 않는다.

macOS 12 환경이 마련되면 실제 OS 버전을 기록한 뒤 `scripts/ci/test-render-tree-decoder.sh`와 `scripts/validate-stage3-render.sh`를 KTX/request/HWPX에 실행한다. #469 반영 후 producer golden도 검증한다. 컴파일 target만 12.0으로 지정하거나 최신 OS에서 성공한 결과를 최소 OS 성공으로 기재하지 않는다.
