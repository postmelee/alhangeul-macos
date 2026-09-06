# Task M010 #492 Stage 3 완료보고서

## 단계 목적

Stage 2의 nonempty color input renderer로 표시되기 시작한 macOS WKWebView native 글자색 popover가 문서 영역 또는 형광펜 button 쪽에 잘못 배치되는 문제를 HostApp compatibility bridge에서 보정한다. upstream picker 이벤트와 bundled studio 산출물은 유지하면서 HWP/HWPX의 작은 창·확대 창에서 popover pointer가 글자색 button 중앙에 정렬되는지 검증한다.

## 산출물

- `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift`
  - `#btn-text-color`의 최신 `getBoundingClientRect()`를 기준으로 숨은 `#text-color-picker`의 fixed anchor를 계산한다.
  - input 시작점을 `rect.left`에 두고 button과 같은 width/height를 부여해 두 요소의 중심을 일치시킨다.
  - macOS WKWebView에서 관찰된 세로 반전 위치는 `window.innerHeight - rect.bottom - (2 * rect.height)`로 보정한다.
  - 초기 host override refresh, 글자색 button의 `mousedown`/`click` capture, window `resize`에서 좌표를 갱신한다.
- `Tests/HostAppTests/RhwpStudioHostBridgeScriptTests.swift`
  - 대상 DOM id, 좌표식, renderer 크기, `pointer-events: none`과 초기/click/resize 갱신 계약을 고정하는 테스트 2개를 추가했다.
- `mydocs/plans/task_m010_492_impl.md`
  - 위치 A/B, 작업지시자 후속 화면에서 발견한 1차 후보의 수평 오프셋, 최종 보정과 재검증 결과를 기록했다.
- `mydocs/orders/20260904.md`, `mydocs/orders/20260906.md`
  - Stage 3 진행 상태와 실패 판정 정정, 최종 재검증 결과를 반영했다.

## 본문 변경 정도 및 본문 무손실

제품 변경은 Swift가 소유하는 기존 HostApp bridge의 idempotent한 좌표 보정과 그 문자열 계약 테스트에 한정했다. 다음 표면은 변경하지 않았다.

- `rhwp-core.lock`과 core dependency
- `project.yml`과 생성된 `Alhangeul.xcodeproj/project.pbxproj`
- hashed JavaScript/CSS/WASM을 포함한 bundled `rhwp-studio` generated asset
- 기존 `alhangeul-wkwebview-overrides.css`
- `RhwpStudioWebView` 주입 구성, manifest와 AppKit color bridge
- upstream이 소유하는 글자색 picker activation/change listener와 형광펜 경로

UI smoke에서는 문서 내용과 서식을 변경하지 않았다. 원본 sample의 SHA-256·크기·mtime은 검증 전 기록과 동일하다.

| sample | SHA-256 | 크기 | mtime |
|--------|---------|------|-------|
| `samples/re-01-hangul-only-hancom.hwp` | `61538931d2e2cf38f35050618ce7698960823938884d0d8977812c94587e85fd` | 8704 bytes | `1777080929` |
| `samples/hwpx/ref/ref_text.hwpx` | `6e47ca7d7c1149dd1ee6db8c6f5932461c82f13cf6f9648d5c70c197f6c70e6d` | 13340 bytes | `1777080929` |

## 검증 결과

### 사용자 후속 화면과 좌표식 정정

1차 후보는 input의 `left`를 `rect.right`로 두고 button 폭을 부여했다. 2026-09-06 03:18 작업지시자 화면에서 popover pointer가 글자색 button 중앙이 아니라 오른쪽 형광펜 button 중앙을 가리키는 것이 확인됐다. 이는 input 중심을 한 button 폭만큼 오른쪽으로 이동시킨 결과이므로 통과 판정을 철회하고 `rect.left`로 수정했다.

### 자동 검증

| 검증 | 결과 |
|------|------|
| `xcodegen generate` | 성공, project diff 없음 |
| `HostAppTests` Debug test | 180개 통과, 실패·unexpected·skip 0개 |
| `HostApp` Debug build | 성공 |
| app bundle `rhwp-studio` asset verifier | 통과 |
| source/bundle `alhangeul-wkwebview-overrides.css` byte 비교 | 동일 |
| `git diff --check` | 통과 |

최종 test result는 `build.noindex/task492/tests/Logs/Test/Test-HostAppTests-2026.09.06_03-20-47-+0900.xcresult`에 있다.

### 실제 WKWebView UI 재검증

최종 Debug build를 task 전용 bundle id `com.postmelee.alhangeul.task492.stage3left` 사본으로 실행했다.

| 검증 항목 | HWP | HWPX |
|-----------|-----|------|
| 900×670 작은 창에서 popover pointer와 글자색 button 중심 정렬 | 통과 | 통과 |
| 확대 창에서 popover pointer와 글자색 button 중심 정렬 | 통과 | 통과 |
| popover 취소 후 창 크기 변경 및 재실행 | 통과 | 통과 |

1차 후보에서 이미 HWP/HWPX의 글자색 부분 적용·editor focus·undo/redo, 형광펜 기본 팔레트와 `다른 색...`, 사용자 지정 형광펜 적용·focus·undo/redo, native color well의 `색상 패널 보기` AX 동작을 검증했다. 최종 수정은 input의 수평 anchor 시작점만 변경하며 activation/change와 편집 경로는 건드리지 않는다.

최종 등록 위생 진단 `build.noindex/task492/registration-stage3-report/20260906-032734/`에는 LaunchServices 개발 등록과 PlugInKit 개발 provider가 없었다. `build.noindex`의 개발 앱 파일 존재 경고만 있으며 등록된 산출물이 아니므로 cleanup은 실행하지 않았다.

## 잔여 위험

- 세로 좌표식은 현재 macOS/WebKit 조합에서 관찰하고 HWP/HWPX 두 창 크기로 검증한 compatibility contract다. OS/WebKit 또는 upstream toolbar DOM·크기 변경 시 UI 재검증이 필요하다.
- Swift 테스트는 주입 JavaScript 문자열의 selector·좌표식·이벤트 계약을 고정하지만 native popover의 실제 위치 자체는 UI smoke로 검증한다.
- 혼합 글자색 범위에 형광펜을 적용할 때 기존 글자색이 소실되는 문제는 bundled core/studio에서도 재현되는 별도 upstream 이슈다. 작업지시자 결정에 따라 #492의 구현과 완료 조건에서 제외했으며 이 downstream 위치 보정의 선행 조건이 아니다.

## 다음 단계 영향

Stage 4에서는 Stage 2의 nonempty renderer와 Stage 3의 HostApp anchor 보정이라는 downstream 소유 경계를 최종 보고서와 PR 본문에 명시한다. 작업지시자가 발견한 1차 후보 오프셋과 `rect.left` 정정 기록을 남기고, upstream 혼합 서식 이슈가 독립적임을 구분한다. 추가 제품 구현은 예정하지 않는다.

## 승인 요청

Stage 3 구현·검증 결과를 승인하고 Stage 4 최종 보고 및 PR 게시 준비에 진입할지 승인을 요청한다.

## Stage 5 대체 사항

최종 anchor 좌표식 자체는 유지하되 갱신 경로와 테스트 방식을 보완했다. 전역 `MutationObserver`가 호출하는 `refreshHostOverrides()`와 중복 `click` capture에서는 위치 계산을 제거하고, 최초 1회·글자색 button `mousedown` capture·window `resize`에서만 수행한다. 같은 style 값은 다시 쓰지 않는다.

좌표 계산은 side effect가 없는 `textColorPickerAnchorGeometry`로 분리하고 `JavaScriptCore`에서 production JavaScript를 정상·fractional CSS 좌표로 직접 실행한다. Stage 3의 문자열 좌표식 테스트 2개·전체 180개 기록은 당시 결과로 보존하며, 최종 검증은 anchor 관련 9개·전체 181개 XCTest 및 Stage 5 실제 Debug 앱 UI smoke 결과를 기준으로 한다.
