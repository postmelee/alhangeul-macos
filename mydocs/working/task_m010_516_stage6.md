# Task #516 Stage 6 — 새 문서 첫 저장 경고 보완

## 승인과 문제

PR #517 사용자 테스트에서 시작 문서에 `ㅇㅇ` 입력 후 ‘문서 보호 상태를 확인할 수 없습니다’가 표시됐다. 기존 구현은 파일 없는 모든 editor 문서를 미확정으로 분류했기 때문이다. 사용자 “보완을 진행해줘” 지시로 새 문서 생성 출처를 구분하고 같은 PR에 반영하는 범위를 승인받았다.

## 변경 내용

| 파일 | 내용 |
|------|------|
| `RhwpStudioEditorSessionScript.swift` | documentStart에서 공개 확장 명령으로 생성 성공 및 documentGeneration 관찰, snapshot에 createdByEditor 전달 |
| `RhwpStudioEditorSession.swift` | newDocument 분류, 세대 교체·관찰 상실 시 보수적 판정, 첫 저장 이후 native binding 유지 |
| `RhwpStudioSaveBridgeScript.swift` | 저장 경계 snapshot에 생성 출처 반영, 비동기 상태 조회 중 문서 generation 변경 거부 |
| `DocumentViewerStore.swift`, `RhwpStudioWebView.swift` | 새 문서의 이전 source 해제, newDocument만 plain 정책 적용, 저장 전후 동일 보호 판정 |
| 세션·세션 스크립트·저장 스크립트 테스트 | 생성/실패/취소/파일 로드/관찰 전 문서/저장 후 연결 회귀 |
| architecture·smoke·계획·최종 보고서·오늘할일 | 새 분류와 사용자 피드백 보완 기록 |

공개 `automation.registerCommand`의 `execute(CommandServices)`로 wasm bridge에 접근한다. 메뉴를 추가하지 않는 일회성 확장 명령을 실행한 후 바로 해제한다. 원래 `createNewDocument`를 같은 receiver/인자로 호출하여 성공 반환과 documentGeneration 증가를 확인한 경우에만 그 세대를 기록한다. 기능을 재구현하거나 개발 전용 전역·minified 식별자에 의존하지 않는다. 함수는 동기 반환이라는 고정 upstream 계약을 따른다.

문서 로드·복구는 같은 wasm bridge의 generation을 증가시키므로 이전 생성 표시와 일치하지 않는다. 관찰 전에 이미 있던 문서, API 설치 실패, 생성 실패/취소는 새 문서로 소급 판정하지 않는다. 파일명이나 본문이 새 문서와 같아도 분류 근거가 되지 않는다. 상태 조회의 await 전후 generation도 비교하여 서로 다른 문서의 출처와 snapshot을 섞지 않는다.

확인된 newDocument는 plain 정책으로 일반 파일명을 제시하고 보호 경고 없이 저장 패널을 연다. 생성 출처 미확정 editorOnly와 native 보호 문서는 기존 정책을 유지한다. 첫 저장 뒤 source를 연결하며 reload하지 않는 계약도 유지한다.

## 검증 결과

- HostAppTests 221개, 실패 0. 생성 출처·세션 분류 테스트 3개 추가.
- HostApp Debug build, AppKit 경계, 고정 Studio asset 및 문서 diff 검증 통과.
- 출처·저장 통합 boolean 검사 16개 통과, 오류 0, exit 0.
- 실제 Store·Coordinator·WKWebView에서 시작 새 문서 확인 → `ㅇㅇ` → 저장 취소 → HWP 저장·core 본문 재열기 → 후속 저장 통과. 새 문서 보호 경고 0회.
- 공개 새로 만들기 명령 → 이전 source 분리 → 새 HWPX 저장 및 본문 확인, 이전 원본 bytes 보존 통과.
- native를 거치지 않은 bytes를 `새 문서.hwp` 이름으로 로드하면 editorOnly를 유지한다. 새로 만들기 취소 뒤에도 미확정 출처를 유지하고 첫 저장 보호 확인 1회 및 저장 본문을 확인했다.
- Word/HTML 실제 회귀 50개와 조합 이벤트 2개 통과. 오류 6개는 기존 destination 보존·재시도 검증을 위한 의도적 주입이다. 최종 assertion 실패 0, exit 0.

저장 위치와 보호 확인 응답은 진단 callback으로 주입했고, 실제 exporter·atomic write·core 재열기를 확인했다. 새 보호 정책 검증은 경고 callback 호출 횟수와 일반/복사본 파일명을 함께 검사한다. 현재 보완에서 실제 암호 fixture UI·물리 IME·M1/Tahoe 26.3·Word 실기를 새로 검증하지 않았다.

초기 runner의 loadFile RPC는 `params` 대신 `args`를 전달해 실패했다. 형식을 보정했다. 또한 고정 bundle의 비활성 ‘새로 만들기’ DOM 항목을 합성 클릭한 실행은 문서를 교체하지 않아 실패했다. 이 실행들을 성공 근거에서 제외하고 공개 automation 명령으로 실제 생성 함수를 실행한 최종 로그를 사용한다. UI 메뉴 활성화 변경은 본 보완 범위가 아니다.

근거는 `build.noindex/task516/revision1/` 아래의 `tests-final.log`, `build-final.log`, `probe-final-source.jsonl`, `html-regression/probe-final-source.jsonl`과 각 runner·합성 파일·검증 요약에 보존한다. 고정 upstream `f1f9c6ae58344ee9368996d3543f76b9345cf227`의 main/wasm-bridge/automation 소스와 추가 dispatcher 소스를 대조했다. pin·bundle·Rust/FFI 변경은 없다.

## 본문 보존과 게시

사용자 원본과 실행 중인 이전 앱의 편집 내용은 수정하거나 강제 종료하지 않는다. 진단 파일은 task516 전용 경로에 한정했다. 새 앱은 별도 `DerivedDataRevision1`에서 빌드했다. 완료된 진단 앱의 정확한 등록만 해제하며, 사용자 테스트를 위해 열어 둔 앱은 테스트 종료 후 정리 대상으로 남긴다.

이 보완 보고서·소스·테스트·최종 보고서를 함께 커밋하고 승인된 PR #517에 반영한다. merge·이슈 close·릴리스는 별도 승인 범위다.
