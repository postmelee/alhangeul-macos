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
- 직접 원인: 글자색 `input[type=color]`의 0×0 renderer 영역이 macOS WKWebView native color popover의 유효한 anchor를 제공하지 못함
- 구현 방식: 기존 Alhangeul 소유 WKWebView CSS overlay에서 글자색 input에 버튼 크기의 anchor 영역을 제공

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

이 A/B 결과로 글자색 실패의 충분 원인을 0×0/offset anchor geometry로 확정한다. Stage 2에서 JavaScript 또는 Swift compatibility script를 추가할 근거는 없다.

Stage 1에서는 사용자 문서와 tracked source를 수정하지 않았다. 색상 적용 후 selection, focus와 undo/redo 계약은 승인된 구현을 넣은 뒤 disposable HWP/HWPX 사본으로 Stage 3에서 검증한다.

## 구현 원칙

1. hashed `assets/index-*.js`와 `assets/index-*.css`, upstream checkout과 `rhwp-core.lock`은 수정하지 않는다.
2. 기존 `alhangeul-wkwebview-overrides.css`만 플랫폼 호환성 소유 지점으로 사용한다.
3. `#btn-text-color`의 upstream event listener와 `preventDefault()`는 변경하거나 중복 설치하지 않는다.
4. input은 버튼 전체 영역을 native popover anchor로 사용하되 `pointer-events: none`으로 hit target을 visible button에 유지한다.
5. upstream이 소유하는 전체 toolbar layout, breakpoint와 일반 control dimension은 계속 local overlay에서 금지한다.
6. 형광펜의 동적 color input은 현재 정상 경로이므로 selector 적용 대상에서 제외한다.
7. HostApp Swift source, WKUserScript와 AppKit `NSColorPanel` bridge는 CSS-only 보정이 검증에 실패할 때만 별도 범위 승인을 받고 검토한다.
8. bundled studio 변경으로 대상 DOM id 또는 구조가 사라지면 asset verifier가 조기에 실패하도록 한다.
9. UI smoke는 `build.noindex/task492/` 아래의 문서 사본으로 수행하고 원본 sample과 사용자 문서는 저장하지 않는다.
10. upstream #6635의 수정·merge 여부를 이 타스크의 선행 조건이나 완료 조건으로 사용하지 않는다.

## 판정 규칙

| 결과 | 판정 |
|------|------|
| 글자색 버튼에서 native color popover 표시 | 통과 |
| 취소 후 반복 실행 및 color well 접근성 활성화 성공 | 통과 |
| 형광펜 기본 팔레트와 `다른 색...` 유지 | 통과 |
| 색상 적용 후 기존 선택 범위 유지, focus 복귀와 undo/redo 성공 | 통과 |
| `#text-color-picker` 외 toolbar selector가 local dimension을 소유 | 범위 위반 |
| generated asset, Swift bridge 또는 core dependency 변경 | 범위 위반 |
| source/bundle overlay 불일치 또는 target DOM selector 누락 | blocking |
| HWP/HWPX 중 한 형식에서 popover·적용·undo 회귀 | blocking |
| macOS/WebKit 환경 문제로 UI smoke를 판단할 수 없음 | 환경 실패로 분리하고 같은 candidate 재검증 |

## Stage 2. 최소 CSS 보정과 asset guard 구현

### 목표

글자색 color input에 유효한 native anchor 영역을 제공하고, local overlay의 좁은 소유 경계와 target DOM 계약을 asset verifier로 고정한다.

### 대상

- `Sources/HostApp/Resources/rhwp-studio/alhangeul-wkwebview-overrides.css`
- `scripts/verify-rhwp-studio-assets.sh`
- `mydocs/working/task_m010_492_stage2.md`
- `mydocs/orders/20260903.md`

### 작업

1. override 설명을 native select presentation과 color input anchor compatibility 범위로 갱신한다.
2. `@media (pointer: fine)` 안에 exact `#text-color-picker` block을 추가한다.
3. `inset: 0`, `width: 100%`, `height: 100%`, `pointer-events: none`을 적용한다.
4. verifier가 `#btn-text-color`와 `#text-color-picker type=color` DOM 계약을 확인하게 한다.
5. verifier가 네 anchor declaration을 모두 요구하게 한다.
6. dimension ownership guard는 exact `#text-color-picker` block의 `width`와 `height`만 예외로 허용하고, 다른 upstream toolbar selector와 dimension은 계속 거부하게 한다.
7. verifier의 성공 경로와 declaration 누락/범위 밖 dimension의 실패 경로를 task 전용 임시 사본으로 확인한다.
8. source와 Stage 2 보고서를 함께 검증·커밋한다.

### 검증

```bash
bash -n scripts/verify-rhwp-studio-assets.sh
scripts/verify-rhwp-studio-assets.sh
git diff --check
```

task 전용 임시 resource 사본에서는 anchor declaration 하나를 제거한 경우와 다른 toolbar selector에 dimension을 추가한 경우 각각 verifier가 실패하는지 확인한다.

### 완료 조건

- source resource 검증이 통과한다.
- target DOM과 네 anchor declaration이 verifier에 고정돼 있다.
- color input 외 toolbar layout ownership guard가 약화되지 않는다.
- Swift, generated asset, manifest와 dependency diff가 없다.

### 커밋

```text
Task #492 Stage 2: WKWebView 글자색 picker anchor 보정
```

## Stage 3. HostApp 자동 검증과 WKWebView interaction smoke

### 목표

source overlay가 실제 Debug app bundle에 포함되는지 확인하고, HWP/HWPX에서 색상 선택·적용과 편집기 상태 계약을 검증한다.

### 대상

- Stage 2 전체 변경
- Debug `Alhangeul.app`
- task 전용 HWP/HWPX 문서 사본
- `mydocs/working/task_m010_492_stage3.md`
- `mydocs/orders/20260903.md`

### 작업

1. HostAppTests와 HostApp Debug build를 task 전용 derived data에서 실행한다.
2. app bundle의 `rhwp-studio` resource를 verifier로 재검증한다.
3. source와 bundle의 override 파일이 byte-identical한지 확인한다.
4. HWP 사본에서 editable text를 선택하고 글자색 popover 표시, 취소와 반복 실행을 확인한다.
5. color well의 접근성 활성화에서도 popover가 표시되는지 확인한다.
6. 색상을 선택해 기존 selection에 적용되는지와 editor focus가 복구되는지 확인한다.
7. 색상 적용이 한 번의 undo/redo로 일관되게 복원·재적용되는지 확인한다.
8. 형광펜 기본 팔레트와 `다른 색...` 경로에서 같은 회귀 항목을 확인한다.
9. HWPX 사본에서 4~8을 반복한다.
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
- HWP/HWPX 모두 글자색 및 형광펜 사용자 지정 색상 경로가 동작한다.
- 취소·반복 실행, selection·focus, undo/redo 회귀가 없다.
- generated asset, manifest와 dependency가 변경되지 않는다.

### 커밋

```text
Task #492 Stage 3: 색상 picker HostApp 회귀 검증 완료
```

## Stage 4. 최종 보고와 PR 게시 준비

Stage 2~3 완료 뒤 `mydocs/report/task_m010_492_report.md`를 작성하고 오늘할일을 완료 처리한다. 최종 검증과 커밋 뒤 `task-final-report` 절차로 `publish/task492`에 push하고 `devel` 대상 Open PR을 생성한다.

PR 본문에는 다음을 포함한다.

- `Closes #492`
- native color well은 생성되지만 0×0 anchor에서 popover presentation만 실패한 직접 원인
- 같은 WKWebView에서 형광펜 경로가 동작한 positive control
- CSS-only A/B 실험과 최종 local ownership 경계
- HWP/HWPX selection·focus·undo/redo smoke 결과
- upstream generated asset과 core dependency를 변경하지 않았다는 확인
- upstream #6635가 독립 이슈이며 선행 조건이 아니라는 설명

## 구현계획 승인 요청 사항

1. Stage 2를 CSS overlay와 asset verifier 두 파일의 최소 변경으로 한정하는 방향
2. `#text-color-picker`에 버튼 크기의 anchor를 주고 `pointer-events: none`으로 기존 button handler를 보존하는 방식
3. JavaScript/Swift/AppKit bridge는 이번 구현 범위에서 제외하는 판단
4. Stage 2 완료 후 단계 보고와 승인을 거쳐 Stage 3 interaction smoke로 진행하는 순서

Stage 2 승인 전에는 tracked CSS, verifier 또는 HostApp source를 변경하지 않는다.
