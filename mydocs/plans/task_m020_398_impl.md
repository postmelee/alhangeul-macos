# Task M020 #398 구현계획서

수행계획서: `mydocs/plans/task_m020_398.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #398 `preview visual diff harness automation load path 추가`
- 차단/후속 관계: #396 Stage 4 전 선행 처리
- 마일스톤: M020 (`v0.2.x Skia Quick Look/Thumbnail Backend`)
- 기준 브랜치: `devel`
- 작업 브랜치: `local/task398`
- 목표: `preview-visual-diff-harness`의 `rhwp-studio` reference capture가 로컬 글꼴 감지 모달/토스트 같은 사용자 UI에 오염되지 않도록 automation document load path와 contamination metadata를 추가한다.

## 구현 원칙

- Skia/CoreGraphics renderer output은 변경하지 않는다.
- bundled `rhwp-studio` minified asset은 직접 patch하지 않는다.
- #293에서 보정한 `domComposite` / `overlayIncluded=true` 의미를 유지한다.
- 일반 앱 문서 열기 UI 흐름이 아니라 upstream e2e helper와 같은 direct WASM/canvas load 방식을 우선한다.
- UI를 클릭해 닫는 방식은 보조 수단으로만 둔다. 핵심은 사용자 UI가 처음부터 뜨지 않는 분석용 load path다.
- automation load 실패 시 기존 UI load로 조용히 fallback하지 않는다. 실패 phase와 원인을 드러낸다.
- `복학원서.hwp`는 capture가 깨끗해져도 기존 layout overflow/displayText/watermark 이력이 있으므로, visual metric 해석은 #396에서 별도로 한다.

## 현재 코드 관찰

현재 `StudioReferenceRenderer.capture`는 다음 흐름이다.

1. input file bytes를 읽는다.
2. `makeLoadURL(filename:revision:)`로 `alhangeul-studio://app/index.html?url=alhangeul-document://document&filename=...` URL을 만든다.
3. WebView가 URL query의 `url`을 보고 `rhwp-studio` 일반 문서 로드 경로를 탄다.
4. page ready 후 `alignAndHideChromeScript`로 메뉴/툴바/상태바/ruler만 숨긴다.
5. overlay-positive page면 `domComposite`, overlay가 없고 canvas가 비면 `webViewSnapshot`, 그 외에는 `canvasDataURL`을 쓴다.

upstream `rhwp-studio/e2e/helpers.mjs`의 `loadHwpFile()`은 다음 방식이다.

```javascript
const resp = await fetch(url);
const buf = await resp.arrayBuffer();
const docInfo = window.__wasm?.loadDocument(new Uint8Array(buf), fname);
window.__canvasView?.loadDocument?.();
```

이 방식은 `initDoc` 이후의 local font prompt, autosave/file-open UI, validation prompt 등 사용자-facing 흐름을 대부분 우회한다.

## 설계 방향

### Automation load URL

기존 `makeLoadURL`은 문서 URL query를 포함하므로 일반 앱 로드 흐름을 유발한다. #398에서는 `index.html`만 여는 URL을 추가한다.

예상 함수:

```swift
private func makeAutomationAppURL() throws -> URL
```

이 URL은 `alhangeul-studio://app/index.html`만 가리킨다. 문서 bytes는 기존 `StudioDocumentSchemeHandler`를 그대로 유지하고, page 안의 JS가 `fetch("alhangeul-document://document?revision=1")`로 읽는다. 이렇게 하면 Swift에서 큰 base64 script를 만들지 않아도 된다.

### Automation readiness

기존 `waitForPageReady`는 문서 canvas가 있어야 통과한다. automation path에서는 먼저 앱 shell만 준비된 상태를 기다린 뒤 문서를 직접 주입해야 한다.

예상 함수:

```swift
private func waitForAutomationRuntime(timeout: TimeInterval) throws
```

검사 항목:

- navigation commit/finish 또는 JS evaluation 가능
- `window.__wasm` 존재
- `window.__canvasView` 존재

### Automation document load

예상 함수:

```swift
private func loadDocumentForAutomation(documentURL: URL, filename: String) throws -> AutomationLoadInfo
```

JS 동작:

1. `fetch(documentURL)`로 document scheme bytes를 읽는다.
2. `window.__wasm.loadDocument(new Uint8Array(buf), filename)`을 호출한다.
3. `window.__canvasView.loadDocument()`를 호출한다.
4. page count, source format, status text를 JSON으로 반환한다.

성공 후에는 기존 `waitForPageReady`, `alignPageAndHideChrome`, `currentPageState`, capture decision을 그대로 사용한다.

### UI contamination metadata

capture 직전과 capture 직후에 사용자 UI 상태를 probe한다.

예상 field:

- `automationLoad: Bool`
- `captureContaminated: Bool`
- `uiSuppressed: Bool`
- `modalCount: Int`
- `toastCount: Int`
- `localFontUIVisible: Bool`
- `contaminationText: [String]`

초기 selector 후보:

- `dialog`, `[role="dialog"]`, `[aria-modal="true"]`
- `.modal`, `.toast`, `.snackbar`, `.notification`
- text probe: `로컬 글꼴`, `글꼴 감지`, `폰트 감지`

automation load가 정상이라면 suppression 없이도 `modalCount=0`, `toastCount=0`, `localFontUIVisible=false`가 기대값이다. 숨김 CSS는 잔여 UI가 있을 때만 `uiSuppressed=true`로 기록하고, 이 경우에도 report에서 contamination risk로 드러낸다.

## Stage 1. current harness load/capture contamination inventory

### 목표

현재 harness의 document load, readiness, capture decision과 upstream direct load 방식을 코드 기준으로 매핑한다.

### 대상

- `scripts/preview_visual_diff_harness.swift`
- `/Users/melee/Documents/projects/forks/rhwp/rhwp-studio/e2e/helpers.mjs`
- `mydocs/report/task_m014_293_report.md`
- `mydocs/report/task_m020_390_report.md`
- `mydocs/working/task_m020_398_stage1.md`

### 작업

1. 현재 `StudioReferenceRenderer.capture` 흐름을 navigation, document scheme, readiness, capture decision으로 분해한다.
2. upstream `loadHwpFile()` direct load 방식과 downstream WebView/WKURLSchemeHandler 차이를 정리한다.
3. #293의 `domComposite`/`overlayIncluded=true` 계약과 #390의 contamination 관찰을 연결한다.
4. Stage 2 구현 지점을 함수 단위로 확정한다.

### 검증

```bash
rg -n "makeLoadURL|waitForPageReady|alignAndHideChrome|domComposite|overlayIncluded|captureMode" \
  scripts/preview_visual_diff_harness.swift mydocs/working/task_m020_398_stage1.md
rg -n "loadHwpFile|__wasm|__canvasView|loadDocument" \
  /Users/melee/Documents/projects/forks/rhwp/rhwp-studio/e2e/helpers.mjs \
  mydocs/working/task_m020_398_stage1.md
git diff --check
```

### 완료 조건

- 기존 UI load path와 새 automation load path의 분기점이 문서화되어 있다.
- #293 overlay capture 계약을 유지해야 하는 이유가 문서화되어 있다.
- Stage 2 구현 범위가 함수 단위로 정리되어 있다.

### 커밋 메시지

```text
Task #398 Stage 1: preview harness automation load inventory
```

## Stage 2. automation load path 구현

### 목표

`StudioReferenceRenderer`가 일반 문서 열기 UI를 거치지 않고 document bytes를 direct WASM/canvas path로 로드하게 한다.

### 대상

- `scripts/preview_visual_diff_harness.swift`
- `mydocs/working/task_m020_398_stage2.md`

### 작업

1. `makeAutomationAppURL()` 또는 기존 `makeLoadURL` option을 추가한다.
2. `waitForAutomationRuntime(timeout:)`를 추가한다.
3. `loadDocumentForAutomation(documentURL:filename:)`를 추가한다.
4. `capture`에서 navigation 후 runtime readiness -> automation load -> page readiness 순서로 실행한다.
5. 기존 `domComposite`/`webViewSnapshot`/`canvasDataURL` decision은 유지한다.
6. automation load 실패 시 `.readiness` 또는 별도 detail로 실패시킨다.

### 검증

```bash
swiftc -parse scripts/preview_visual_diff_harness.swift
rg -n "automation|__wasm|__canvasView|loadDocument|domComposite|overlayIncluded" \
  scripts/preview_visual_diff_harness.swift mydocs/working/task_m020_398_stage2.md
git diff --check
```

가능하면 target smoke를 시도하되, WebKit readiness timeout이 나면 Stage 4에서 sandbox 밖 재실행 기준으로 분리한다.

### 완료 조건

- harness가 automation load path를 코드상 가진다.
- 일반 `?url=` 문서 로드 흐름을 거치지 않는다.
- 기존 capture decision이 유지된다.

### 커밋 메시지

```text
Task #398 Stage 2: preview harness automation load 구현
```

## Stage 3. contamination metadata와 failure 분리

### 목표

reference capture가 사용자 UI에 오염됐는지 summary/metadata에서 확인할 수 있게 한다.

### 대상

- `scripts/preview_visual_diff_harness.swift`
- 필요 시 `scripts/preview-visual-diff-harness.sh` help text
- `mydocs/working/task_m020_398_stage3.md`

### 작업

1. `StudioCaptureMetadata`에 automation/UI contamination field를 추가한다.
2. capture 전후 UI probe JS를 추가한다.
3. `modalCount`, `toastCount`, `localFontUIVisible`, `captureContaminated`를 JSON에 기록한다.
4. contamination이 남으면 renderer failure와 구분되는 phase/detail을 남긴다.
5. summary에 최소한 `StudioCapture` 또는 metadata path로 확인 가능한 근거를 남긴다. summary column 확장은 필요할 때만 한다.

### 검증

```bash
swiftc -parse scripts/preview_visual_diff_harness.swift
rg -n "automationLoad|captureContaminated|modalCount|toastCount|localFontUIVisible|uiSuppressed" \
  scripts/preview_visual_diff_harness.swift mydocs/working/task_m020_398_stage3.md
git diff --check
```

### 완료 조건

- `studio/*.json`에서 automation load 여부와 UI contamination 여부를 확인할 수 있다.
- contamination은 renderer diff 수치와 분리된다.
- 기존 metadata field와 capture decision이 유지된다.

### 커밋 메시지

```text
Task #398 Stage 3: capture contamination metadata 추가
```

## Stage 4. target sample smoke 검증

### 목표

`복학원서.hwp`와 overlay 없는 대표 sample에서 automation load가 실제로 capture contamination을 제거하는지 확인한다.

### 대상

- `build.noindex/task398-automation-load/`
- `mydocs/working/task_m020_398_stage4.md`

### 작업

1. `복학원서.hwp`, `request.hwp` visual diff harness를 실행한다.
2. 필요 시 `KTX.hwp`를 추가해 #396 quick suite 연동성을 확인한다.
3. `studio/*.json`에서 `automationLoad`, `captureContaminated`, `modalCount`, `toastCount`, `overlayIncluded`, `captureMode`를 확인한다.
4. `복학원서.hwp` capture가 정상 sample 후보로 복구됐는지 판단한다.
5. sandbox/WebKit 실패는 environment failure로 분리하고, 필요한 경우 승인 경로에서 재실행한다.

### 검증

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task398-automation-load --page 1 \
  samples/복학원서.hwp samples/basic/request.hwp
rg -n "captureMode|overlayIncluded|automationLoad|captureContaminated|modalCount|toastCount|localFontUIVisible|복학원서|request" \
  build.noindex/task398-automation-load mydocs/working/task_m020_398_stage4.md
git diff --check
```

### 완료 조건

- `복학원서.hwp` reference capture에 로컬 글꼴 감지 UI가 섞이지 않는다.
- `복학원서.hwp`의 overlay-positive capture 의미가 유지된다.
- `request.hwp` 같은 overlay 없는 sample이 불필요하게 악화되지 않는다.
- 실패 시 renderer failure와 capture/environment failure가 구분된다.

### 커밋 메시지

```text
Task #398 Stage 4: automation capture smoke 검증
```

## Stage 5. 최종 보고서와 #396 handoff

### 목표

#398 결과를 최종 보고서로 정리하고 #396 Stage 4에서 `bokhakwonseo-capture-sentinel`을 어떻게 해석할지 handoff한다.

### 대상

- `mydocs/report/task_m020_398_report.md`
- `mydocs/orders/20260629.md`
- 필요 시 `mydocs/working/task_m020_398_stage5.md`

### 작업

1. automation load 구현 결과와 metadata field를 요약한다.
2. target smoke 결과를 정리한다.
3. #396 manifest의 `bokhakwonseo-capture-sentinel` 해석 업데이트 방향을 정리한다.
4. 오늘할일 #398을 완료 처리한다.
5. PR body 초안에 들어갈 검증 결과를 정리한다.

### 검증

```bash
rg -n "#398|#396|automationLoad|captureContaminated|복학원서|Skia|CoreGraphics|preview visual diff" \
  mydocs/report/task_m020_398_report.md mydocs/orders/20260629.md
git diff --check
git status --short --branch
git log --oneline devel..local/task398
```

### 완료 조건

- 최종 보고서가 #398의 capture 신뢰성 보정 결과를 설명한다.
- #396으로 넘길 sample 해석이 정리되어 있다.
- PR 게시 준비가 가능하다.

### 커밋 메시지

```text
Task #398 Stage 5 + 최종 보고서: automation capture path 정리
```
