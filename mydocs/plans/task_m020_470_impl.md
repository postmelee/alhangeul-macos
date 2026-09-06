# Task M020 #470 구현계획서

## Stage 1 — decode 계약

`RenderTree.swift`에 sanitized error와 `RenderTreeDecoder.decode`를 둔다. known 단일 tag는 payload를 `try`로 읽고 실패를 variant 문맥과 함께 전파한다. unknown 단일 tag는 payload를 해석하지 않는다. 기존 current/legacy/TextRun fixture를 유지하고 필드 누락·타입 오류·null·unknown·tag 형식 오류·중첩 coding path·privacy를 검사한다.

검증: `scripts/ci/test-render-tree-decoder.sh`, `check-no-appkit.sh`, `git diff --check`. 단계 보고서와 코드 커밋.

## Stage 2 — FFI wrapper와 smoke

`renderPageTreeThrowing(at:)`를 추가하고 optional API가 `try?`로 위임한다. 음수/UInt32 범위 밖 page는 변환 전에 안전하게 실패한다. null producer output과 decoder 오류를 구분하며 반환 C 문자열 복사/free 계약을 유지한다. native smoke/debug helper는 throwing decode를 사용한다. 제품 stderr/stdout logging은 추가하지 않는다.

검증: decoder fixture와 기본 native smoke, HWPX sample. bridge 운영 문서에 진단 책임과 호환 계약 명시. 단계 보고서와 코드 커밋.

### Stage 2 검증 중 확인한 core 계약 보정

KTX/request 실제 core 출력의 TextLine `para_index`는 `usize::MAX - i` marker를 포함한다. 기존 Swift Int decode 실패가 `.unknown`으로 숨겨져 있었다. pinned core `render_tree.rs`의 section/para/control/char_start는 usize이므로 해당 metadata 모델을 UInt로 맞추고 marker를 손실 없이 보존한다. 필수 필드를 optional로 완화하지 않는다. synthetic UInt.max/음수 거부 fixture와 같은 샘플 native/core 비교를 추가한다. Foundation의 비-DecodingError 실패에도 알려진 payload 경로를 유지한다.

## Stage 3 — 통합 검증·PR

no-AppKit, xcodegen/HostApp Debug build, native smoke와 diff 검증을 정리한다. 개발 산출물은 build.noindex에 둔다. 소스 변경으로 실제 앱 등록 검증을 요구하지 않는다. 계획/단계/최종보고서와 오늘할일을 완료하고 `publish/task470`에서 devel 대상으로 PR을 생성한다. 본문에 선행 PR #503 및 자신의 commit 범위를 명시한다.

## Stage 4 — PR #504 리뷰 보완

작업지시자 승인에 따라 CellContext의 남은 usize 필드를 UInt로 정렬하고 큰 정수/음수 경계를 검증한다. known tag는 CaseIterable enum과 exhaustive switch로 연결하고 모든 24종의 valid payload와 잘못된 표현을 검증한다. 다중 tag는 variant를 임의 선택하지 않으며 nil variant 진단을 중립적으로 표시한다. throwing API는 pageCount 경계도 invalid index로 분류하고 실제 FFI null 경로는 raw JSON API로 독립 검증한다.

strict known 오류 전파와 macOS 12 deploymentTarget은 유지한다. 작업지시자가 사용할 macOS 12 기기/VM이 없음을 확인했고 self-hosted runner도 없다. 현재 OS/CI 검증과 최소 OS 실행 검증을 구분하여 보고하며 macOS 12 미검증을 병합 전 잔여 조건으로 공개 코멘트에 남긴다.
