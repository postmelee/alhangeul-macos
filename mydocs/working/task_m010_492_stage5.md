# Task M010 #492 Stage 5 완료 보고서

## 단계 목적

PR #493 리뷰에서 지적된 geometry 중복 소유, 전역 observer 경로의 불필요한 layout read/write, 좌표식의 문자열 기반 테스트, 과도한 CSS fixture와 shell negative helper의 stdin 위험을 보완한다. 최종 제품 동작은 유지하면서 책임 경계와 회귀 검증을 실제 실행 경로에 맞춘다.

## 리뷰 항목별 반영 결과

| 리뷰 항목 | 판단 | 반영 |
|-----------|------|------|
| CSS와 JavaScript의 anchor geometry 중복 소유 | 수용 | `.atDocumentEnd`에서 덮이는 `#text-color-picker` CSS rule 제거, Host bridge 단일 소유로 정리 |
| OS/WebKit 변화에 대한 보정식 위험 | 부분 수용 | native popover 위치는 page JavaScript에서 관측할 수 없고 확인된 버전 경계도 없어 추측성 gate는 추가하지 않음. 순수 helper·실행형 테스트·UI smoke 경계로 격리 |
| 전역 `MutationObserver` refresh의 layout 비용 | 수용 | `refreshHostOverrides()`에서 위치 계산 제거, 최초·button `mousedown`·window `resize`로 제한 |
| source 문자열 테스트의 한계 | 수용 | production JavaScript geometry helper를 `JavaScriptCore`에서 직접 실행해 정상·fractional CSS 좌표 검증 |
| 0×0 renderer 직접 원인 표현 | 수용 | 형광펜의 정상 0×0 경로를 반례로 명시하고 hidden input anchor geometry 호환성 문제로 정정 |
| shell negative helper의 stdin·counter 취약성 | 수용 | 실패 명령 stdin을 `/dev/null`로 격리하고 DOM fixture 기대 건수 6개를 assert |
| `click` capture 중복 | 수용 | upstream `mousedown` activation 전에 좌표가 이미 적용되므로 별도 `click` listener 제거 |

## 구현 결과

### Geometry 단일 소유권

- `alhangeul-wkwebview-overrides.css`에서 color picker anchor rule을 제거했다. overlay는 다시 native select presentation만 소유한다.
- `RhwpStudioHostBridgeScript`의 `textColorPickerAnchorGeometry(viewportHeight, buttonRect)`가 `left`, `top`, `width`, `height`를 계산한다.
- 배치 함수는 pure helper 결과를 `position: fixed`, `pointer-events: none`과 함께 적용하며 현재 값과 다를 때만 인라인 style을 쓴다.
- 위치 갱신은 bridge 초기화 직후 1회, 글자색 button의 capture `mousedown`, window `resize`에서만 수행한다. 일반 DOM mutation과 `click`에서는 수행하지 않는다.

### 실행형 좌표 검증

- `HostAppTests`에 `JavaScriptCore.framework`를 연결하고 생성 원본인 `project.yml`에서 선언했다.
- 테스트가 production bridge source에서 pure helper를 추출해 `JSContext`에서 직접 실행한다.
- 정수 좌표와 fractional CSS 좌표에서 `top = viewportHeight - buttonRect.bottom - 2 × buttonRect.height` 및 나머지 geometry 결과를 수치 비교한다.
- DOM lookup, helper wiring, 조건부 style write와 초기/mousedown/resize lifecycle은 source wiring 경계로 별도 확인한다.

### Asset·shell 검증 계약

- asset verifier는 Host bridge가 의존하는 글자색 button id와 color input id/type을 계속 확인한다.
- CSS anchor 전용 parser와 declaration 예외는 제거하고 기존 local overlay의 toolbar selector·dimension 비소유 guard를 단순 검사로 유지한다.
- CI fixture는 DOM 계약 6개 사례를 실행하고 정확히 6개가 수행됐는지 확인한다.
- `expect_failure`가 실행하는 명령에는 `/dev/null`을 stdin으로 연결해 주변 heredoc 또는 loop stdin을 소비하지 않게 했다.

## 변경 범위와 무손실

- upstream generated HTML/JavaScript/CSS/WASM, manifest와 service worker는 변경하지 않았다.
- `rhwp-core.lock`, Rust bridge와 framework는 변경하지 않았다.
- Xcode project 직접 수정 없이 `project.yml` 변경 후 `xcodegen generate`로 `Alhangeul.xcodeproj/project.pbxproj`를 재생성했다.
- 실제 문서 서식은 변경하거나 저장하지 않았다. 최종 UI smoke는 tracked `ref_text.hwpx`를 읽기 전용으로 열어 popover 위치만 확인한 뒤 종료했다.
- Stage 1~3 보고서는 당시 승인·실험 이력을 보존하고 Stage 5 대체 사항을 덧붙였다.

## 검증 결과

| 검증 | 결과 |
|------|------|
| 두 shell script `bash -n` | 통과 |
| source asset verifier | 통과 |
| Cargo.lock/asset CI fixture | DOM 6개 및 기존 전체 fixture 통과 |
| `xcodegen generate` | 성공, JavaScriptCore test dependency에 해당하는 project diff만 생성 |
| Host bridge 전용 XCTest | 9개 통과 |
| HostAppTests 전체 | 181개 통과, 실패 0 |
| HostApp Debug build | 성공 |
| Debug app bundle asset verifier | 통과 |
| source/bundle override `cmp` | 동일 |
| `git diff --check` | 통과 |
| 등록 위생 `--check-only` | 개발 등록·provider·issue 없음 |

최종 XCTest 결과는 `build.noindex/task492/review-tests/Logs/Test/Test-HostAppTests-2026.09.06_17-14-39-+0900.xcresult`에 있다. Debug 앱은 `build.noindex/task492/review-build/Build/Products/Debug/Alhangeul.app`이다. 등록 위생 진단은 `/private/tmp/alhangeul-extension-registration-hygiene/20260906-171518/`에 남겼다.

실제 Debug 앱에서 `samples/hwpx/ref/ref_text.hwpx`를 열고 글자색 button을 활성화했다. native color popover가 열렸고 popover pointer가 글자색 button 아래를 가리키는 것을 확인했다. Stage 3의 HWP/HWPX × 작은 창/확대 창 결과와 함께 좌표식 유지에 대한 UI 회귀 근거로 사용한다.

## 잔여 위험

- native popover의 최종 화면 좌표는 page JavaScript에서 관측할 수 없어 자동 XCTest만으로 검증할 수 없다. 순수 좌표식은 자동화하고 실제 정렬은 지원 환경 UI smoke로 판단한다.
- 현재 확인된 macOS/WebKit 버전 경계가 없어 추측성 OS gate를 두지 않았다. 다른 macOS 주 버전, Intel Mac 또는 WebKit 동작 변경 시 UI smoke가 필요하다.
- bundled studio에서 button/input id, toolbar 크기 또는 위치가 바뀌면 DOM verifier 또는 UI smoke를 통해 보정식 유지·수정·제거를 판단해야 한다.
- 혼합 글자색 범위에 형광펜을 적용할 때 기존 글자색이 소실되는 문제는 bundled core/studio의 별도 upstream 문제이며 #492의 downstream popover 위치 보정과 분리한다.

## 완료 판정

PR #493 리뷰의 보정 대상과 자동·실제 UI 검증을 완료했다. 추가 제품 변경 없이 최종 보고서를 현 구조에 맞게 갱신하고 `publish/task492`에 반영한 뒤 리뷰 보정 코멘트를 게시한다.
