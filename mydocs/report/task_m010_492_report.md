# Task M010 #492 최종 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| GitHub Issue | [#492 HostApp WKWebView 글자색·형광펜 색상 선택기 호환성 안정화](https://github.com/postmelee/alhangeul-macos/issues/492) |
| Pull Request | [#493](https://github.com/postmelee/alhangeul-macos/pull/493) |
| 마일스톤 | `v0.1` (`M010`) |
| 통합 브랜치 | `devel` |
| 단계 수 | 5단계: 원인 조사, 1차 CSS 실험, HostApp 위치 보정/UI smoke, 최종 보고·PR 게시, PR 리뷰 보완 |
| bundled studio 기준 | `v0.8.4` / `496333b27d21ddb9114ba9ae340bcb895870c9a7` |

macOS WKWebView와 맞지 않는 upstream hidden 글자색 input의 anchor geometry 때문에 native color popover가 열리지 않거나 toolbar 밖에 표시되는 문제를 HostApp compatibility bridge에서 보정했다. 기존 button의 rect를 기준으로 input anchor를 계산해 native popover pointer가 글자색 button을 가리키게 한다.

PR 리뷰를 반영해 geometry 소유권을 JavaScript 한 곳으로 통합했다. `.atDocumentEnd`에서 덮이는 CSS anchor rule과 전용 parser/fixture를 제거하고, 위치 계산을 전역 DOM observer에서 분리했으며, production JavaScript의 순수 geometry helper를 `JavaScriptCore`에서 직접 실행해 검증한다.

형광펜의 기존 기본 팔레트와 `다른 색...` 경로, upstream picker activation/change listener는 유지했다. upstream generated asset과 core dependency를 변경하지 않았으며 관련 upstream [edwardkim/rhwp#6635](https://github.com/edwardkim/rhwp/issues/6635)의 처리 여부를 이 작업의 선행 조건으로 두지 않았다.

## 최종 변경 파일과 영향 범위

| 파일 | 내용 |
|------|------|
| `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift` | 순수 geometry helper, 조건부 inline style 적용, 최초/mousedown/resize 갱신 |
| `Tests/HostAppTests/RhwpStudioHostBridgeScriptTests.swift` | production JavaScript 좌표 실행 및 DOM/event wiring 회귀 테스트 |
| `project.yml` | `HostAppTests`의 `JavaScriptCore.framework` 의존성 선언 |
| `Alhangeul.xcodeproj/project.pbxproj` | `xcodegen generate`로 반영된 JavaScriptCore test dependency |
| `scripts/verify-rhwp-studio-assets.sh` | Host bridge button/input DOM 계약과 local overlay 소유 경계 검증 |
| `scripts/ci/test-rhwp-studio-cargo-lock-verification.sh` | DOM fixture 6개, 기대 건수 assert, negative helper stdin 격리 |
| `mydocs/plans/task_m010_492.md` | #492 수행 범위, 단계, 검증과 downstream 소유 경계 정의 |
| `mydocs/plans/task_m010_492_impl.md` | 원인 표현 정정, 최종 단일 소유권과 Stage 5 리뷰 보완 기록 |
| `mydocs/working/task_m010_492_stage1.md` | 초기 조사 이력 및 Stage 5 원인 표현 정정 |
| `mydocs/working/task_m010_492_stage2.md` | 1차 CSS 구현 이력 및 최종 구조에서의 대체 사항 |
| `mydocs/working/task_m010_492_stage3.md` | HostApp 위치 보정/UI smoke 및 최종 lifecycle 대체 사항 |
| `mydocs/working/task_m010_492_stage5.md` | PR 리뷰 보완·검증 완료 보고 |
| `mydocs/orders/20260903.md`, `20260904.md`, `20260906.md` | 단계별 작업 상태와 완료 기록 |
| `mydocs/report/task_m010_492_report.md` | 본 최종 결과와 수용 기준 판정 |

Stage 2에서 추가했던 `alhangeul-wkwebview-overrides.css`의 color picker anchor rule은 Stage 5에서 제거됐다. 최종 overlay는 기존 native select presentation만 소유하며 color picker geometry의 제품 동작은 Host bridge가 단독 소유한다.

## 원인과 구현 판정

- 글자색 영구 input은 native color well 생성까지 도달하므로 WKWebView color input 미지원이나 JavaScript activation 실패가 아니다.
- 형광펜의 정상 `다른 색...` 경로도 0×0 input을 사용하므로 0×0 renderer 자체는 충분 원인이 아니다.
- 두 경로의 차이와 artifact-only A/B는 upstream hidden input의 DOM 배치·anchor geometry가 macOS WKWebView native popover 표시와 위치를 결정한다는 결론을 지지한다.
- 최종 좌표는 `left = buttonRect.left`, `top = viewportHeight - buttonRect.bottom - 2 × buttonRect.height`, `width/height = buttonRect.width/height`다.
- native popover 위치는 page JavaScript에서 관측할 수 없고 확인된 OS/WebKit 버전 경계도 없어 추측성 runtime gate는 추가하지 않았다. 계산은 pure helper로 격리하고 실제 화면 위치는 UI smoke로 검증한다.

## 검증 결과

### 수용 기준

| 수용 기준 | 판정 | 근거 |
|-----------|------|------|
| 글자색 button에서 native color picker가 열린다 | OK | HWP/HWPX button 및 native color well AX 경로 확인 |
| popover가 글자색 button 위치에 정렬된다 | OK | HWP/HWPX 작은 창·확대 창과 Stage 5 Debug 앱 재확인 |
| 선택한 색상이 기존 텍스트 선택 범위에 적용된다 | OK | 두 형식에서 부분 글자색 적용·focus·undo/redo 확인 |
| 형광펜 사용자 지정 색상 경로가 유지된다 | OK | 기본 팔레트와 `다른 색...`, 사용자 지정 색상 적용 확인 |
| geometry 책임이 한 계층에만 있다 | OK | CSS anchor 제거, Host bridge 단일 소유 |
| 불필요한 DOM mutation layout 작업이 없다 | OK | 최초/mousedown/resize로 제한, 동일 style 재쓰기 방지 |
| 자동 검증이 실제 좌표 계산을 실행한다 | OK | JavaScriptCore에서 production helper의 정수·fractional 좌표 실행 |
| provenance 경계를 지킨다 | OK | generated studio asset·manifest·core diff 없음 |

### 최종 통합 검증

2026-09-06 macOS `26.5.2 (25F84)`, Xcode `26.6 (17F113)`에서 실행했다.

```text
$ bash -n scripts/verify-rhwp-studio-assets.sh scripts/ci/test-rhwp-studio-cargo-lock-verification.sh
exit 0

$ scripts/verify-rhwp-studio-assets.sh
OK: rhwp-studio assets verified

$ scripts/ci/test-rhwp-studio-cargo-lock-verification.sh
OK: rhwp-studio color picker DOM fixtures passed (6 cases)
OK: rhwp-studio Cargo.lock fingerprint verification fixtures passed

$ xcodegen generate
Created project; JavaScriptCore test dependency에 해당하는 project diff만 생성

$ xcodebuild ... -scheme HostAppTests ... test
Executed 181 tests, 0 failures
** TEST SUCCEEDED **

$ xcodebuild ... -scheme HostApp ... build
** BUILD SUCCEEDED **

$ scripts/verify-rhwp-studio-assets.sh <Debug app bundle>/rhwp-studio
OK

$ cmp <source overlay> <bundle overlay>
exit 0

$ git diff --check
exit 0
```

anchor 관련 XCTest 9개와 전체 181개가 통과했다. 최종 xcresult는 `build.noindex/task492/review-tests/Logs/Test/Test-HostAppTests-2026.09.06_17-14-39-+0900.xcresult`에 있고 Debug 앱은 `build.noindex/task492/review-build/Build/Products/Debug/Alhangeul.app`이다. 테스트 종료 시 WebKit RunningBoard/sandbox 진단이 출력됐지만 XCTest와 build는 exit 0으로 완료됐고 제품 실패는 없었다.

Stage 5 실제 UI smoke에서 `samples/hwpx/ref/ref_text.hwpx`를 열고 글자색 button을 활성화해 native popover pointer가 글자색 button 아래를 가리키는 것을 재확인했다. Stage 3에서는 HWP/HWPX의 900×670 작은 창과 확대 창, 취소 후 resize·재실행까지 통과했다. 원본 sample은 저장하지 않았다.

등록 위생 `--check-only` 결과 LaunchServices 개발 등록, PlugInKit 개발 provider와 issue가 없었다. 진단은 `/private/tmp/alhangeul-extension-registration-hygiene/20260906-171518/`에 있으며 `build.noindex`의 앱 파일은 등록되지 않은 검증 산출물이다.

## 잔여 위험과 후속 작업

- native popover의 실제 위치는 자동 테스트에서 직접 관측할 수 없다. 순수 좌표식은 자동화하고 최종 정렬은 지원 환경 UI smoke로 판정한다.
- 다른 macOS 주 버전, Intel Mac 또는 WebKit 동작 변경 시 좌표식 재검증이 필요하다.
- bundled studio의 button/input id는 verifier가 차단하지만 toolbar 위치·크기 변화는 UI smoke에서 확인해야 한다.
- 혼합 글자색 범위에 형광펜을 적용할 때 기존 글자색이 소실되는 현상은 bundled core/studio에서도 재현되는 별도 upstream 문제다. [edwardkim/rhwp#6635](https://github.com/edwardkim/rhwp/issues/6635)에서 추적하며 이 downstream 위치 보정의 차단 조건이 아니다.

새로운 downstream 후속 이슈 제안은 없다. 향후 rhwp-studio 동기화 시 verifier 실패 또는 UI smoke 변화가 나타나면 compatibility 보정 유지·수정·제거를 dependency 갱신 task에서 판단한다.

## 작업지시자 승인 상태

작업지시자는 PR #493 리뷰 보정, 게시 브랜치 반영과 보정 코멘트 게시까지 승인했다. PR merge 전에는 이슈를 close하거나 self-merge하지 않는다.
