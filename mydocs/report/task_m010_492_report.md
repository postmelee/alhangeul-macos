# Task M010 #492 최종 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| GitHub Issue | [#492 HostApp WKWebView 글자색·형광펜 색상 선택기 호환성 안정화](https://github.com/postmelee/alhangeul-macos/issues/492) |
| 마일스톤 | `v0.1` (`M010`) |
| 통합 브랜치 | `devel` |
| 단계 수 | 4단계: 원인 확정, CSS/asset guard, HostApp anchor/UI smoke, 최종 보고·PR 게시 |
| bundled studio 기준 | `v0.8.4` / `496333b27d21ddb9114ba9ae340bcb895870c9a7` |

macOS WKWebView에서 글자색 `input[type=color]`의 0×0 renderer 때문에 native color popover가 표시되지 않는 문제를 Alhangeul 소유 호환성 계층에서 해결했다. 기존 CSS overlay는 input에 button 크기의 renderer를 제공하고, HostApp bridge는 현재 button rect를 기준으로 WKWebView의 native popover anchor 좌표를 보정한다.

형광펜의 기존 기본 팔레트와 `다른 색...` 경로, upstream picker activation/change listener는 유지했다. upstream generated asset과 core dependency를 변경하지 않았으며 관련 upstream [edwardkim/rhwp#6635](https://github.com/edwardkim/rhwp/issues/6635)의 처리 여부를 이 작업의 선행 조건으로 두지 않았다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `Sources/HostApp/Resources/rhwp-studio/alhangeul-wkwebview-overrides.css` | `#text-color-picker`에 nonempty renderer 크기와 기존 button hit-test 보존 선언 추가 |
| `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift` | button rect 기반 native popover XY anchor 계산과 초기/click/resize 갱신 추가 |
| `Tests/HostAppTests/RhwpStudioHostBridgeScriptTests.swift` | selector·좌표식·크기·event refresh 계약 테스트 2개 추가 |
| `scripts/verify-rhwp-studio-assets.sh` | exact picker DOM/CSS 계약과 좁은 dimension ownership 예외 검증 추가 |
| `scripts/ci/test-rhwp-studio-cargo-lock-verification.sh` | color picker/ownership 성공·실패 fixture 27개와 production overlay 무손실 검사 추가 |
| `mydocs/plans/task_m010_492.md` | #492 수행 범위, 단계, 검증과 downstream 소유 경계 정의 |
| `mydocs/plans/task_m010_492_impl.md` | 재현·A/B 분석, 구현 좌표식, 사용자 후속 실패 정정과 최종 검증 기록 |
| `mydocs/working/task_m010_492_stage1.md` | 0×0 renderer 직접 원인과 CSS-only A/B 단계 보고 |
| `mydocs/working/task_m010_492_stage2.md` | CSS overlay와 asset guard 구현·27개 fixture 단계 보고 |
| `mydocs/working/task_m010_492_stage3.md` | HostApp anchor 보정, HWP/HWPX UI smoke와 수평 오프셋 정정 단계 보고 |
| `mydocs/orders/20260903.md` | Stage 1 작업 상태 기록 |
| `mydocs/orders/20260904.md` | Stage 2 및 Stage 3 후속 검증 상태 기록 |
| `mydocs/orders/20260906.md` | 최종 통합 검증과 완료 시각 기록 |
| `mydocs/report/task_m010_492_report.md` | 본 최종 결과와 수용 기준 판정 기록 |

## 변경 전·후 정량 비교

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| 글자색 native popover | color well은 생성되지만 visible popover 없음 | button 클릭·AX 활성화로 표시, 취소 후 재실행 가능 |
| 세로 위치 | renderer를 단순 확장하면 문서 중하단에 표시 | toolbar의 글자색 button 바로 아래 표시 |
| 수평 위치 | 1차 `rect.right` 후보는 형광펜 button 쪽으로 한 폭 어긋남 | `rect.left`로 input/button 중심 일치 |
| 실제 UI 조합 | 미검증 | HWP/HWPX × 작은 창/확대 창 4개 조합 통과 |
| color picker/ownership fixture | 전용 사례 없음 | 27개 사례 통과 |
| Host bridge 전용 테스트 | 해당 좌표 계약 없음 | 신규 2개 포함 전체 180개 통과 |
| 최종 보고 전 diff | 기준 `devel` 대비 없음 | 13개 파일, `+1165/-7`줄; 본 보고서 추가 전 기준 |

제품·검증 코드의 핵심 변경량은 CSS `+15/-2`, HostApp bridge `+37`, HostAppTests `+49`, CI fixture `+96`, asset verifier `+94/-5`줄이다. 나머지는 재현 근거, 승인 경계와 단계별 검증을 보존한 작업 문서다.

## 검증 결과

### 수용 기준

| 수용 기준 | 판정 | 근거 |
|-----------|------|------|
| 글자색 버튼에서 native color picker가 열린다 | OK | HWP/HWPX button 및 native color well AX 경로 확인 |
| 선택한 색상이 기존 텍스트 선택 범위에 적용된다 | OK | 두 형식에서 부분 파란 글자색 적용과 editor focus 확인 |
| 형광펜 사용자 지정 색상 경로가 동작한다 | OK | 기본 팔레트와 `다른 색...`, 사용자 지정 노란색 적용 확인 |
| 취소·반복 실행과 selection/focus가 유지된다 | OK | 두 형식에서 반복 실행, 적용 후 focus와 undo/redo 통과 |
| popover가 button 위치에 정렬된다 | OK | HWP/HWPX의 900×670·확대 창에서 pointer 중심 정렬 확인 |
| HostApp 소유 및 provenance 경계를 지킨다 | OK | local overlay/bridge만 변경, generated asset·manifest·core diff 없음 |
| 자동 검증과 WKWebView smoke 근거가 남는다 | OK | 27개 fixture, 180개 XCTest, Stage 3 UI matrix와 xcresult 기록 |

### 최종 통합 검증

2026-09-06 macOS `26.5.2 (25F84)`, Xcode `26.6 (17F113)`에서 실행했다.

```text
$ bash -n scripts/verify-rhwp-studio-assets.sh scripts/ci/test-rhwp-studio-cargo-lock-verification.sh
exit 0

$ scripts/verify-rhwp-studio-assets.sh
OK: rhwp-studio assets verified

$ scripts/ci/test-rhwp-studio-cargo-lock-verification.sh
OK: rhwp-studio color picker/ownership fixtures passed (27 cases)
OK: rhwp-studio Cargo.lock fingerprint verification fixtures passed

$ xcodegen generate
Created project; project diff 없음

$ xcodebuild ... -scheme HostAppTests ... test
Executed 180 tests, 0 failures
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

최종 xcresult는 `build.noindex/task492/tests/Logs/Test/Test-HostAppTests-2026.09.06_03-33-17-+0900.xcresult`에 있다. 테스트 종료 시 WebKit process의 RunningBoard assertion 진단이 출력됐지만 XCTest 180개와 xcodebuild가 exit 0으로 완료됐고 제품 실패는 없었다.

등록 위생 진단 `build.noindex/task492/registration-final/20260906-033332/`에는 LaunchServices 개발 등록, PlugInKit 개발 provider와 issue가 없었다. `build.noindex` 아래 앱 파일은 등록되지 않은 검증 산출물이므로 다른 task·설치본·전역 cache에 영향을 주는 cleanup을 실행하지 않았다.

원본 HWP/HWPX sample은 저장하지 않았고 SHA-256·크기·mtime이 기존 기록과 동일했다.

## 잔여 위험과 후속 작업

- 세로 anchor 좌표식은 현재 macOS/WebKit에서 관찰한 compatibility contract다. OS/WebKit 또는 bundled studio toolbar DOM·크기가 바뀌면 HWP/HWPX 두 창 크기의 UI smoke를 다시 수행해야 한다.
- asset verifier가 target DOM id와 overlay declaration 변경을 조기에 차단하지만 native popover의 실제 화면 위치는 정적 테스트만으로 보장할 수 없다.
- 혼합 글자색이 포함된 선택 범위에 형광펜을 적용할 때 기존 글자색이 소실되는 현상은 bundled core/studio에서도 재현되는 독립 upstream 문제다. [edwardkim/rhwp#6635](https://github.com/edwardkim/rhwp/issues/6635)에서 별도로 추적하며 이 downstream 위치 보정의 차단 조건이 아니다.
- Intel Mac 실기기와 다른 macOS 주 버전의 native popover 위치는 이번 task에서 별도로 검증하지 않았다.

새로운 downstream 후속 이슈 제안은 없다. 향후 rhwp-studio 동기화 시 verifier 실패 또는 UI smoke 변화가 나타나면 compatibility 보정 유지·수정·제거를 해당 dependency 갱신 task에서 판단한다.

## 작업지시자 승인 요청

Task #492의 최종 결과와 `devel` 대상 PR을 검토하고 merge 여부를 승인해 주기 바란다. PR merge 전에는 이슈를 close하거나 self-merge하지 않는다.
