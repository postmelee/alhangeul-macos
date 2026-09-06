# Task M020 #470 구현계획서

## Stage 1 — decode 계약

`RenderTree.swift`에 sanitized error와 `RenderTreeDecoder.decode`를 둔다. known 단일 tag는 payload를 `try`로 읽고 실패를 variant 문맥과 함께 전파한다. unknown 단일 tag는 payload를 해석하지 않는다. 기존 current/legacy/TextRun fixture를 유지하고 필드 누락·타입 오류·null·unknown·tag 형식 오류·중첩 coding path·privacy를 검사한다.

검증: `scripts/ci/test-render-tree-decoder.sh`, `check-no-appkit.sh`, `git diff --check`. 단계 보고서와 코드 커밋.

## Stage 2 — FFI wrapper와 smoke

`renderPageTreeThrowing(at:)`를 추가하고 optional API가 `try?`로 위임한다. 음수/UInt32 범위 밖 page는 변환 전에 안전하게 실패한다. null producer output과 decoder 오류를 구분하며 반환 C 문자열 복사/free 계약을 유지한다. native smoke/debug helper는 throwing decode를 사용한다. 제품 stderr/stdout logging은 추가하지 않는다.

검증: decoder fixture와 기본 native smoke, HWPX sample. bridge 운영 문서에 진단 책임과 호환 계약 명시. 단계 보고서와 코드 커밋.

## Stage 3 — 통합 검증·PR

no-AppKit, xcodegen/HostApp Debug build, native smoke와 diff 검증을 정리한다. 개발 산출물은 build.noindex에 둔다. 소스 변경으로 실제 앱 등록 검증을 요구하지 않는다. 계획/단계/최종보고서와 오늘할일을 완료하고 `publish/task470`에서 devel 대상으로 PR을 생성한다. 본문에 선행 PR #503 및 자신의 commit 범위를 명시한다.
