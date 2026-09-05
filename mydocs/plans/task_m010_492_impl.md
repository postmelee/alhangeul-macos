# Task M010 #492 구현계획서

수행계획서: `mydocs/plans/task_m010_492.md`

각 단계 완료 후 `task-stage-report` 절차로 단계 보고서와 해당 단계 변경을 함께 커밋하고, 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다. upstream `edwardkim/rhwp#6635`는 일반 웹 UI의 활성화 의미론을 독립적으로 추적하며, 이 타스크의 구현 또는 완료를 차단하지 않는다.

## 작업 개요

- 이슈: #492 `HostApp WKWebView 글자색·형광펜 색상 선택기 호환성 안정화`
- 마일스톤: M010 (`v0.1`)
- 기준 브랜치: `devel`
- 작업 브랜치: `local/task492`
- 게시 브랜치: `publish/task492`
- bundled studio: `v0.8.4` / `496333b27d21ddb9114ba9ae340bcb895870c9a7`
- 1차 직접 원인: 글자색 `input[type=color]`의 0×0 renderer 영역이 macOS WKWebView native color popover의 유효한 anchor를 제공하지 못함
- 2차 직접 원인: 유효한 renderer 영역을 toolbar 위치에 그대로 두면 native popover의 세로 anchor가 WKWebView 높이에 대해 반전된 위치로 표시됨
- 구현 방식: 기존 CSS overlay로 nonempty renderer를 유지하고, 기존 HostApp bridge가 클릭 직전 button rect를 기준으로 WKWebView 전용 보정 anchor를 설정

## Stage 1 재현 결과

### 기준 구현

bundled `index.html`의 글자색 UI는 `.sb-color-wrap` 안에 `#btn-text-color` 버튼과 영구적인 형제 요소 `#text-color-picker`를 둔다. pinned upstream `toolbar.ts`는 버튼의 `mousedown`에서 기본 동작을 막고 `this.colorPicker.click()`을 호출한다.

upstream CSS의 글자색 input은 다음 특성을 가진다.

- `position: absolute`
- `left: 0`, `top: 100%`
- `width: 0`, `height: 0`
- `opacity: 0`
- `border: none`, `padding: 0`

형광펜의 `다른 색...` 경로는 실행 시점에 숨은 color input을 생성해 해당 버튼의 자식으로 추가한다. 이 input도 0×0이지만 별도 absolute offset을 갖지 않고 visible button 내부에 renderer가 놓인다.

### 실제 WKWebView 동작

source 기준 Debug HostApp과 기존 앱에서 다음을 확인했다.

| 경로 | native color well 생성 | visible popover | 판정 |
|------|-------------------------|-----------------|------|
| 글자색 버튼, 원본 CSS | 생성됨 | 열리지 않음 | color input activation까지 도달하지만 presentation 실패 |
| 글자색 color well AX 활성화, 원본 CSS | 대상은 존재 | 열리지 않음 | 유효하지 않은 anchor 상태와 일치 |
| 형광펜 `다른 색...`, 원본 CSS | 생성됨 | 정상적으로 열림 | 같은 WKWebView process의 positive control |

따라서 WKWebView의 color input 미지원, user activation 소실 또는 HostApp native delegate 부재를 직접 원인으로 보지 않는다. 글자색의 영구 input도 native color well 생성까지 도달하므로 JavaScript handler와 WebKit bridge는 동작한다. 두 경로의 결정적인 차이는 native popover가 기준으로 삼을 renderer의 DOM 배치와 영역이다.

### CSS-only A/B 실험

tracked source를 변경하지 않고 task 전용 Debug app bundle 사본에 다음 실험 CSS만 적용했다.

```css
#text-color-picker {
  inset: 0;
  width: 100%;
  height: 100%;
  pointer-events: none;
}
```

`pointer-events: none`은 input이 visible button의 마우스 이벤트를 가로채지 않게 해 기존 `mousedown` 및 `preventDefault()` 계약을 보존한다. `inset`과 크기만 `.sb-color-wrap`에 맞춰 native anchor를 유효하게 만든다.

동일 앱 binary와 동일 HWP 문서에서 다음 결과를 확인했다.

- 글자색 버튼으로 native color popover가 즉시 표시됨
- popover 취소 후 같은 버튼으로 다시 열림
- 숨은 color well의 접근성 활성화로도 popover가 표시됨
- 형광펜 팔레트와 `다른 색...` native popover가 그대로 동작함
- CSS가 input의 change/input event 또는 formatting command를 변경하지 않음

이 A/B 결과로 최초의 "열리지 않음" 실패 원인은 0×0/offset anchor geometry로 확정했다. 그러나 Stage 3 사용자 검증에서 표시된 popover가 toolbar가 아닌 문서 중하단에 열리는 2차 위치 결함이 확인됐으므로, CSS만으로 전체 호환성 요구를 충족한다는 판정은 철회한다.

Stage 1에서는 사용자 문서와 tracked source를 수정하지 않았다. 색상 적용 후 selection, focus와 undo/redo 계약은 승인된 구현을 넣은 뒤 disposable HWP/HWPX 사본으로 Stage 3에서 검증한다.

## 구현 원칙

1. hashed `assets/index-*.js`와 `assets/index-*.css`, upstream checkout과 `rhwp-core.lock`은 수정하지 않는다.
2. 기존 `alhangeul-wkwebview-overrides.css`는 nonempty renderer와 hit-test 계약을, 기존 `RhwpStudioHostBridgeScript`는 동적 anchor 좌표 보정을 소유한다.
3. `#btn-text-color`의 upstream event listener와 `preventDefault()`는 변경하거나 중복 설치하지 않는다.
4. input은 버튼 전체 영역을 native popover anchor로 사용하되 `pointer-events: none`으로 hit target을 visible button에 유지한다.
5. upstream이 소유하는 전체 toolbar layout, breakpoint와 일반 control dimension은 계속 local overlay에서 금지한다.
6. 형광펜의 동적 color input은 현재 정상 경로이므로 selector 적용 대상에서 제외한다.
7. 기존 `.atDocumentEnd` HostApp bridge에는 idempotent한 좌표 보정만 추가하고, 별도 WKUserScript·AppKit `NSColorPanel` bridge는 추가하지 않는다.
8. bundled studio 변경으로 대상 DOM id 또는 구조가 사라지면 asset verifier가 조기에 실패하도록 한다.
9. UI smoke는 `build.noindex/task492/` 아래의 문서 사본으로 수행하고 원본 sample과 사용자 문서는 저장하지 않는다.
10. upstream #6635의 수정·merge 여부를 이 타스크의 선행 조건이나 완료 조건으로 사용하지 않는다.

## 판정 규칙

| 결과 | 판정 |
|------|------|
| 글자색 버튼에서 native color popover 표시 | 통과 |
| 작은 창과 확대 창에서 popover pointer가 글자색 button 바로 아래에 정렬 | 통과 |
| 취소 후 반복 실행 및 color well 접근성 활성화 성공 | 통과 |
| 형광펜 기본 팔레트와 `다른 색...` 유지 | 통과 |
| 색상 적용 후 기존 선택 범위 유지, focus 복귀와 undo/redo 성공 | 통과 |
| `#text-color-picker` 외 toolbar selector가 local dimension을 소유 | 범위 위반 |
| generated asset, AppKit color bridge 또는 core dependency 변경 | 범위 위반 |
| source/bundle overlay 불일치 또는 target DOM selector 누락 | blocking |
| HWP/HWPX 중 한 형식에서 popover·적용·undo 회귀 | blocking |
| macOS/WebKit 환경 문제로 UI smoke를 판단할 수 없음 | 환경 실패로 분리하고 같은 candidate 재검증 |

## Stage 2. 최소 CSS 보정과 asset guard 구현

### 목표

글자색 color input에 유효한 native anchor 영역을 제공하고, local overlay의 좁은 소유 경계와 target DOM 계약을 asset verifier로 고정한다.

### 승인된 범위 보정 (2026-09-04)

기존 `scripts/ci/test-rhwp-studio-cargo-lock-verification.sh`가 최소 HTML/CSS fixture로 같은 verifier와 sync self-check를 실행한다. 새 DOM·anchor 필수 조건을 적용하면 이 fixture가 먼저 실패하므로 작업지시자 승인에 따라 해당 테스트 파일의 resource/upstream fixture와 회귀 사례를 Stage 2에 포함한다. 제품 변경은 기존 CSS overlay와 verifier에 한정하고, CI workflow·sync helper·generated asset은 변경하지 않는다.

### 대상

- `Sources/HostApp/Resources/rhwp-studio/alhangeul-wkwebview-overrides.css`
- `scripts/verify-rhwp-studio-assets.sh`
- `scripts/ci/test-rhwp-studio-cargo-lock-verification.sh`
- `mydocs/working/task_m010_492_stage2.md`
- `mydocs/orders/20260904.md`

### 작업

1. override 설명을 native select presentation과 color input anchor compatibility 범위로 갱신한다.
2. `@media (pointer: fine)` 안에 exact `#text-color-picker` block을 추가한다.
3. `inset: 0`, `width: 100%`, `height: 100%`, `pointer-events: none`을 적용한다.
4. verifier가 `#btn-text-color`와 `#text-color-picker type=color` DOM 계약을 확인하게 한다.
5. verifier가 네 anchor declaration을 모두 요구하게 한다.
6. dimension ownership guard는 exact `#text-color-picker` block의 `width`와 `height`만 예외로 허용하고, 다른 upstream toolbar selector와 dimension은 계속 거부하게 한다.
7. 기존 CI fixture를 새 DOM·CSS 계약에 맞추고, verifier의 성공 경로와 declaration 누락/범위 밖 dimension/DOM 변경의 실패 경로를 task 전용 임시 사본으로 확인한다. 기존 Cargo.lock·sync 검증과 production manifest/overlay 무손실 검사도 유지한다.
8. source와 Stage 2 보고서를 함께 검증·커밋한다.

### 검증

```bash
bash -n scripts/verify-rhwp-studio-assets.sh scripts/ci/test-rhwp-studio-cargo-lock-verification.sh
scripts/verify-rhwp-studio-assets.sh
scripts/ci/test-rhwp-studio-cargo-lock-verification.sh
git diff --check
```

task 전용 임시 resource 사본에서는 anchor declaration 하나를 제거한 경우와 다른 toolbar selector에 dimension을 추가한 경우 각각 verifier가 실패하는지 확인한다.

### 완료 조건

- source resource 검증이 통과한다.
- target DOM과 네 anchor declaration이 verifier에 고정돼 있다.
- color input 외 toolbar layout ownership guard가 약화되지 않는다.
- 신규 color picker 회귀 사례와 기존 Cargo.lock·sync fixture가 모두 통과한다.
- Swift, generated asset, manifest와 dependency diff가 없다.

### 커밋

```text
Task #492 Stage 2: WKWebView 글자색 picker anchor 보정
```

## Stage 3. HostApp anchor 보완과 WKWebView interaction smoke

### 목표

CSS 보정으로 열린 native popover의 잘못된 위치를 기존 HostApp compatibility bridge에서 바로잡고, source overlay와 bridge가 포함된 실제 Debug app으로 HWP/HWPX 색상 선택 계약을 재검증한다.

### 대상

- Stage 2 전체 변경
- `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift`
- `Tests/HostAppTests/RhwpStudioHostBridgeScriptTests.swift`
- Debug `Alhangeul.app`
- task 전용 HWP/HWPX 문서 사본
- `mydocs/working/task_m010_492_stage3.md`
- `mydocs/orders/20260906.md`

### 작업

1. bridge에 `#btn-text-color`와 `#text-color-picker` 존재 여부를 확인하는 좌표 보정 함수를 추가한다.
2. button의 최신 `getBoundingClientRect()`를 기준으로 picker를 `position: fixed`로 두고, `left = rect.left`, `top = window.innerHeight - rect.bottom - (2 * rect.height)`, button과 동일한 width/height를 설정한다. input 중심과 button 중심을 일치시켜 native popover pointer가 글자색 button을 가리키게 한다.
3. 초기 host override refresh, button `mousedown`/`click` capture와 `resize`에서 보정을 다시 적용한다. upstream의 picker `click()`·`change` listener는 교체하거나 중복 설치하지 않는다.
4. HostBridgeScriptTests가 대상 DOM id, 좌표식, pointer-events 보존, 초기/click/resize 갱신 계약을 고정하게 한다.
5. HostAppTests와 HostApp Debug build를 task 전용 derived data에서 실행한다.
6. app bundle의 `rhwp-studio` resource를 verifier로 재검증하고 source와 bundle의 override 파일이 byte-identical한지 확인한다.
7. HWP/HWPX 사본의 작은 창과 확대 창에서 popover pointer가 글자색 button 바로 아래에 정렬되는지 확인한다.
8. 각 문서에서 취소·반복 실행, color well 접근성 활성화, 일부 선택 범위 적용, focus와 undo/redo를 재검증한다.
9. 형광펜 기본 팔레트와 `다른 색...` 경로가 기존과 동일하게 동작하는지 확인한다.
10. task 전용 앱/extension 등록이 생겼다면 표준 cleanup 절차로 해당 산출물만 해제한다.

### 검증

```bash
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostAppTests \
  -configuration Debug \
  -derivedDataPath build.noindex/task492/tests \
  CODE_SIGNING_ALLOWED=NO \
  test
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/task492/app \
  CODE_SIGNING_ALLOWED=NO \
  build
scripts/verify-rhwp-studio-assets.sh \
  build.noindex/task492/app/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
cmp \
  Sources/HostApp/Resources/rhwp-studio/alhangeul-wkwebview-overrides.css \
  build.noindex/task492/app/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio/alhangeul-wkwebview-overrides.css
git diff --check
```

### 완료 조건

- HostAppTests와 HostApp Debug build가 통과한다.
- source와 app bundle overlay가 동일하다.
- HWP/HWPX의 작은 창과 확대 창 모두 native popover가 글자색 button 아래에 정렬된다.
- HWP/HWPX 모두 글자색 및 형광펜 사용자 지정 색상 경로가 동작한다.
- 취소·반복 실행, selection·focus, undo/redo 회귀가 없다.
- generated asset, manifest와 dependency가 변경되지 않는다.

### 커밋

```text
Task #492 Stage 3: 색상 picker 위치 보완 및 회귀 검증
```

### 진행 기록 (2026-09-04, 완료 판정 전)

Stage 2 커밋 `664b5aa`를 기준으로 검증했다. 제품 source는 추가 변경하지 않았다.

- 환경: macOS 26.5.2 (`25F84`), arm64.
- `xcodegen generate`: 성공, generated project 변경 없음.
- 계획된 HostAppTests: 178개 통과, 실패·skip 0개. 첫 sandbox 실행의 dependency/cache 접근 실패는 권한을 갖춘 동일 명령 재실행에서 해소됐다.
- 계획된 HostApp Debug build: 성공.
- source·Debug app·UI 검증용 app의 asset verifier 통과. 세 overlay는 byte-identical하며 원본 Debug app과 UI 검증용 app의 실행 파일·debug dylib도 동일하다.
- UI 검증용 app은 `build.noindex/task492/smoke.zUKuE5/Alhangeul.app`이다. 기존 앱과 분리하기 위해 사본의 bundle identifier만 `com.postmelee.alhangeul.task492.stage3`으로 바꿨다. CSS 또는 JavaScript를 사본에서 추가 패치하지 않았다.
- 같은 디렉터리의 `color-hwp.hwp`와 `color-hwpx.hwpx` 사본만 편집·저장했다.

| 검증 항목 | HWP | HWPX |
|-----------|-----|------|
| 글자색 버튼으로 native popover 표시·취소·재실행 | 통과 | 통과 |
| 글자색 color well 접근성 활성화 | 통과 | 통과 |
| 선택한 일부 글자에만 파란색 적용, selection·editor focus 유지 | `다라마` 세 글자 통과 | `안녕` 두 글자 통과 |
| 글자색 한 번 undo 및 한 번 redo | 통과 | 통과 |
| 형광펜 기본 팔레트 표시 | 통과 | 통과 |
| `다른 색...` native popover 표시·취소·재실행 | 통과 | 통과 |
| 사용자 지정 노란 형광펜 부분 적용·undo/redo (선택 안 기존 서식이 동일한 경우) | 통과 | 통과 |
| 기본 팔레트 `색 없음` 부분 적용·focus·undo/redo (선택 안 기존 서식이 동일한 경우) | 통과 | 통과 |
| 기본 팔레트 개별 색상 칸의 직접 마우스 클릭·적용 | 도구 오류로 미판정 | 도구 오류로 미판정 |

저장된 HWP 사본을 다시 열어 부분 글자색·형광펜 보존을 확인했다. 저장된 HWPX의 XML에서도 `안녕`과 ` Hello 123`의 run이 분리되고, 전자는 `#0433FF`, 후자는 원래 검정색인 것을 확인했다. `색 없음` 적용 후 저장한 사본이므로 최종 HWPX run의 형광펜 값은 `#FFFFFF`이며, 사용자 지정 노랑 `#FFFB00`의 적용·undo/redo는 저장 전 화면으로 검증했다.

원본 sample 두 개의 SHA-256·크기·mtime은 검증 전후 동일하다.

- `samples/re-01-hangul-only-hancom.hwp`: `61538931d2e2cf38f35050618ce7698960823938884d0d8977812c94587e85fd`, 8704 bytes, mtime `1777080929`.
- `samples/hwpx/ref/ref_text.hwpx`: `6e47ca7d7c1149dd1ee6db8c6f5932461c82f13cf6f9648d5c70c197f6c70e6d`, 13340 bytes, mtime `1777080929`.

검증 자료:

- 테스트 결과: `build.noindex/task492/tests/Logs/Test/Test-HostAppTests-2026.09.04_22-35-19-+0900.xcresult`.
- 등록 진단: `build.noindex/task492/registration/20260904-225831/`.
- 등록 위생 check-only는 과거 다른 타스크의 개발 등록과 두 설치본 provider 경로도 발견해 전체 환경 기준으로 실패했다. 광범위 cleanup은 실행하지 않고, 확인된 #492 앱·extension·Sparkle 하위 앱 등록만 표준 `pluginkit -r`/`lsregister -u` 방식으로 해제했다. 마지막 `lsregister -dump`에서 #492 경로가 더 이상 검색되지 않았고, PlugInKit에는 기존 두 설치본 provider만 남았다. 앱 파일, 다른 타스크 등록, 두 설치본과 전역 cache는 변경하지 않았다.

초기 자동화에서는 기본 형광펜 색상 칸이 접근성 요소로 노출되지 않았고, 좌표 클릭이 `windowNotFoundAtPosition`으로 실패했다. 창 raise·확대/축소·bundle identifier/full path 재시도에서도 같았다. 이후 아래의 사용자 수동 검증에서 실제 결함이 보고됐으므로, 현재 상태를 단순한 자동화 미검증으로 취급하지 않는다.

### 사용자 후속 검증: Stage 3 실패 (2026-09-04 23:27 화면)

작업지시자가 다음 두 결함을 보고했다.

1. 일부 주황색 글자를 포함한 더 넓은 범위에 기본 노란 형광펜을 적용하면 기존 주황색이 검정으로 바뀐다.
2. 글자색 native popover가 toolbar 버튼 근처가 아닌 문서 중하단에서 열린다.

앞선 테스트는 선택 범위 내부의 기존 글자색이 동일한 경우와 popover의 표시 여부를 확인했을 뿐, 혼합 서식 보존과 실제 anchor 위치를 충분히 검증하지 못했다. 따라서 위 제한된 사례의 관찰 결과는 보존하되, 이를 일반적인 색상 호환성 통과로 확대 해석한 판정은 정정한다.

#### 혼합 글자색 소실: bundled WASM에서 재현

제품 파일을 수정하지 않고, `assets/index-2K8l69fn.js`의 WASM glue 구간과 `assets/rhwp_bg-CKllGEX8.wasm`을 Node 메모리에서 실행했다. DOM·WKWebView·local CSS 없이 원본 HWP/HWPX sample을 메모리로 읽고 `applyCharFormat`에 `shadeColor`만 전달했다. 디스크 문서는 저장하지 않았다.

| 기존 색상과 적용 범위 | HWP | HWPX |
|----------------------|-----|------|
| offset 2~4를 주황으로 지정하고 같은 2~4에 형광펜 적용 | 주황 유지 | 주황 유지 |
| 검정–주황–검정인 offset 0~6 전체에 형광펜 적용 | 전체 검정으로 통일 | 전체 검정으로 통일 |
| 주황–검정인 offset 0~6 전체에 형광펜 적용 | 전체 주황으로 통일 | 전체 주황으로 통일 |

고정 commit `496333b27d21ddb9114ba9ae340bcb895870c9a7`에서 확인한 경로는 다음과 같다.

- `rhwp-studio/src/ui/toolbar.ts`: 기본 swatch와 사용자 지정 색상 모두 `{ shadeColor: ... }`만 전달한다.
- `src/document_core/commands/formatting.rs`의 `apply_char_mods_to_paragraph`: `start_offset`의 char shape 하나를 기준으로 새 서식을 만들고 선택 전체에 같은 ID를 적용한다. 선택 내부의 다른 글자색·서식 구간을 보존하지 않는다.
- `rhwp-studio/src/engine/command.ts`의 `ApplyCharFormatCommand`: undo/redo용 ID도 문단별 선택 시작점 하나만 저장·복원한다. 동일 복원 API 경로를 메모리 재현에 적용해도 원래 혼합 글자색은 복구되지 않았다. 실제 UI의 혼합 서식 undo/redo는 별도 회귀 검증에 포함해야 한다.

이는 이번 CSS 보정이 만든 현상이 아니라 현재 bundled core/studio의 혼합 서식 적용 계약 결함이다. 작업지시자 지시에 따라 이 항목은 다른 세션에서 upstream 타스크로 진행하며, #492의 남은 구현·검증·완료 조건에서는 제외한다.

#### Popover 위치: artifact-only 보정안 검증 완료

현재 `inset: 0; width: 100%; height: 100%` 보정은 popover를 표시하지만 toolbar의 renderer 좌표를 그대로 anchor로 사용하면 세로 위치가 WKWebView 높이에 대해 반전된 형태로 문서 중하단에 열린다. tracked source를 바꾸지 않고 Debug app bundle 사본에서 세 변형을 A/B했다.

| artifact-only 변형 | 작은 창 결과 | 판정 |
|--------------------|-------------|------|
| color input을 button 자식 0×0 요소로 이동 | native color well은 생성되나 visible popover 없음 | 기각 |
| button rect를 `position: fixed` input으로 세로 반사 | popover가 toolbar 영역으로 이동하나 button 일부를 덮고 가로 pointer가 어긋남 | 방향 확인 |
| 클릭 직전 `left = rect.right`, `top = innerHeight - rect.bottom - 2 * rect.height`, button 크기 적용 | popover를 toolbar로 이동시키지만 input 중심이 button 한 폭만큼 오른쪽으로 이동 | 수평 위치 재보정 필요 |
| 클릭 직전 `left = rect.left`, `top = innerHeight - rect.bottom - 2 * rect.height`, button 크기 적용 | input 중심과 글자색 button 중심을 일치시킴 | 최종 후보 |

초기 `rect.right` 후보는 900×670 작은 창과 확대 창에서 popover를 toolbar까지 이동시키고 취소 후 재실행도 가능했지만, 2026-09-06 작업지시자 화면 검증에서 pointer가 글자색 button 중앙이 아니라 오른쪽의 형광펜 button 중앙을 가리키는 것이 확인됐다. input에 button과 같은 폭을 부여하면서 시작점을 `rect.right`로 둬 input 중심이 정확히 한 button 폭 오른쪽으로 이동한 결과다. 따라서 시작점을 `rect.left`로 바꿔 input과 글자색 button의 중심을 일치시키는 후보로 교체하고 UI 검증을 다시 수행한다. 이는 현재 macOS/WKWebView 조합에서 관찰한 host compatibility 좌표 계약이며 WebKit 내부 구현의 일반 원인까지 확정하는 주장은 아니다.

이 문제는 #492에서 계속 추적한다. Stage 3 보완은 기존 `RhwpStudioHostBridgeScript.source` 안에 위 좌표 계산을 idempotent하게 넣고, 초기 refresh·button capture·window resize에서만 갱신한다. 기존 CSS의 nonempty renderer와 `pointer-events: none`은 유지하며 generated studio asset, 별도 local JavaScript asset, `RhwpStudioWebView`의 주입 구성과 AppKit color bridge는 변경하지 않는다. 작업지시자 승인 전에는 제품 source 추가 수정, 완료 보고·커밋, PR 게시와 Stage 4 진입을 보류한다.

### Stage 3 보완 구현·검증 진행 기록 (2026-09-06)

작업지시자의 Stage 3 보완 구현 승인 후 기존 `RhwpStudioHostBridgeScript.source`에만 위치 보정을 추가했다. `#btn-text-color`의 최신 rect에서 `left = rect.left`와 세로 반전 보정값으로 `#text-color-picker`의 fixed 좌표를 계산하고 button과 같은 크기를 부여하며, 초기 host override refresh, button `mousedown`/`click` capture와 window `resize`에서 갱신한다. upstream의 picker activation·change listener와 generated studio asset은 변경하지 않았다.

- `RhwpStudioHostBridgeScriptTests`에 대상 DOM id, 좌표식, 크기, `pointer-events: none`, 초기/click/resize 갱신 계약 2개를 추가했다.
- `xcodegen generate`: 성공, `Alhangeul.xcodeproj/project.pbxproj` 변경 없음.
- `HostAppTests`: 180개 통과, 실패·skip 0개.
- HostApp Debug build: 성공.
- source와 Debug app bundle의 `alhangeul-wkwebview-overrides.css`: byte-identical.
- Debug app bundle의 `rhwp-studio` asset verifier: 통과.
- `rhwp-core.lock`, generated studio asset, manifest, `RhwpStudioWebView`와 AppKit bridge: 변경 없음.

1차 후보 앱 `build.noindex/task492/app-stage3-fix/Build/Products/Debug/Alhangeul.app`의 실제 WKWebView에서 다음을 확인했다. 이후 작업지시자 화면 검증에서 수평 pointer 위치가 형광펜 button 쪽으로 한 button 폭 어긋난 것이 확인돼 위치 관련 통과 판정은 철회하며, `rect.left` 최종 후보로 재검증한다.

| 검증 항목 | HWP | HWPX |
|-----------|-----|------|
| 작은 창에서 글자색 popover가 toolbar 아래에 표시 | 통과했으나 pointer 수평 위치 재검증 필요 | 통과했으나 pointer 수평 위치 재검증 필요 |
| 확대 창에서 글자색 popover가 toolbar 아래에 표시 | pointer가 형광펜 button 쪽을 가리켜 실패 | pointer가 형광펜 button 쪽을 가리켜 실패 |
| 취소 후 반복 실행 | 통과 | 통과 |
| 일부 선택 범위 파란 글자색 적용·editor focus | 통과 | 통과 |
| 글자색 undo/redo | 통과 | 통과 |
| 형광펜 기본 팔레트와 `다른 색...` native popover | 통과 | 통과 |
| 사용자 지정 노란 형광펜 부분 적용·editor focus | 통과 | 통과 |
| 사용자 지정 형광펜 undo/redo | 통과 | 통과 |
| native color well `색상 패널 보기` AX 동작 | 통과 | 통과 |

첫 UI 검증 중 Mac 잠금으로 HWP 형광펜 undo/redo 반복과 native color well AX 동작 확인이 중단됐으나, 잠금 해제 후 같은 1차 후보에서 재개해 모두 통과했다. HWP/HWPX 문서는 최종적으로 원래 상태까지 undo했고 저장하지 않은 채 스모크 창을 닫았다. 다만 이후 발견된 pointer 수평 위치 실패 때문에 Stage 3 기술 검증 완료 판정과 완료 보고·커밋을 보류하고 `rect.left` 최종 후보를 재검증한다.

#### 수평 anchor 재보정과 최종 UI 검증

작업지시자의 2026-09-06 03:18 화면을 기준으로 1차 후보의 수평 오프셋을 재분석하고 `rect.right`를 `rect.left`로 교체했다. 최종 빌드를 독립 bundle id `com.postmelee.alhangeul.task492.stage3left`의 task 전용 앱 사본으로 실행해 다음을 다시 확인했다.

| 최종 검증 항목 | HWP | HWPX |
|----------------|-----|------|
| 900×670 작은 창에서 popover pointer와 글자색 button 중심 정렬 | 통과 | 통과 |
| 확대 창에서 popover pointer와 글자색 button 중심 정렬 | 통과 | 통과 |
| popover 취소 후 창 크기 변경 및 재실행 | 통과 | 통과 |

최종 후보에서는 pointer가 형광펜 button 쪽이 아니라 글자색 button의 중앙을 가리킨다. 문서 내용이나 서식은 변경하지 않았고 popover를 취소한 뒤 스모크 창을 닫았다. 수평 보정 후 `HostAppTests` 180개와 HostApp Debug build를 재실행해 모두 통과했으며, test result는 `build.noindex/task492/tests/Logs/Test/Test-HostAppTests-2026.09.06_03-20-47-+0900.xcresult`에 남겼다.

원본 sample은 저장하지 않았으며 SHA-256·크기·mtime이 기존 기록과 동일하다.

- `samples/re-01-hangul-only-hancom.hwp`: `61538931d2e2cf38f35050618ce7698960823938884d0d8977812c94587e85fd`, 8704 bytes, mtime `1777080929`.
- `samples/hwpx/ref/ref_text.hwpx`: `6e47ca7d7c1149dd1ee6db8c6f5932461c82f13cf6f9648d5c70c197f6c70e6d`, 13340 bytes, mtime `1777080929`.

등록 위생 진단 `build.noindex/task492/registration-stage3-report/20260906-032734/`은 최종 빌드·UI 재검증 후에도 LaunchServices 개발 등록과 PlugInKit 개발 provider가 없음을 확인했다. 따라서 앱 파일, 다른 타스크 등록, 설치본 또는 전역 cache를 변경하는 cleanup은 실행하지 않았다.

## Stage 4. 최종 보고와 PR 게시 준비

Stage 2~3 완료 뒤 `mydocs/report/task_m010_492_report.md`를 작성하고 오늘할일을 완료 처리한다. 최종 검증과 커밋 뒤 `task-final-report` 절차로 `publish/task492`에 push하고 `devel` 대상 Open PR을 생성한다.

PR 본문에는 다음을 포함한다.

- `Closes #492`
- native color well은 생성되지만 0×0 anchor에서 popover presentation만 실패한 직접 원인
- 같은 WKWebView에서 형광펜 경로가 동작한 positive control
- CSS nonempty renderer와 HostApp bridge 좌표 보정의 local ownership 경계
- 작은 창·확대 창 artifact-only 위치 A/B 결과
- HWP/HWPX selection·focus·undo/redo smoke 결과
- upstream generated asset과 core dependency를 변경하지 않았다는 확인
- upstream #6635가 독립 이슈이며 선행 조건이 아니라는 설명

## Stage 3 보완 구현 승인 사항

1. 기존 CSS는 nonempty renderer와 `pointer-events: none` 계약으로 유지하고, 좌표 보정만 `RhwpStudioHostBridgeScript.source`에 추가하는 방향
2. 작은 창·확대 창에서 검증한 button rect 기반 XY 계산과 초기/click/resize 갱신 계약
3. `RhwpStudioHostBridgeScriptTests`로 대상 DOM·좌표식·이벤트 갱신을 고정하고 기존 전체 HostAppTests를 재실행하는 범위
4. 혼합 글자색 소실은 다른 upstream 세션의 범위로 분리하고 #492 완료 조건에서 제외하는 판단
5. generated studio asset, 별도 JavaScript asset, `RhwpStudioWebView`, AppKit color bridge와 core dependency는 변경하지 않는 경계

작업지시자가 2026-09-06 같은 세션에서 진행을 승인했고, 위 범위대로 제품 source와 테스트를 변경했다. Stage 3 완료 보고·커밋과 Stage 4 진입은 남은 UI 재검증 뒤 별도 승인받는다.
