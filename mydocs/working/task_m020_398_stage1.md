# Task M020 #398 Stage 1 완료보고서

## 단계 목적

현재 `preview-visual-diff-harness`의 `rhwp-studio` reference load/capture 경로를 inventory하고, #398 Stage 2에서 추가할 automation load path의 함수 단위 구현 지점을 고정한다.

이번 단계는 조사와 보고서 작성만 수행했다. 제품 Swift/Rust renderer source와 harness script는 수정하지 않았다.

## 조사 대상

| 대상 | 확인 내용 |
|------|-----------|
| `scripts/preview_visual_diff_harness.swift` | `StudioReferenceRenderer.capture`, URL scheme, readiness, capture decision |
| `/Users/melee/Documents/projects/forks/rhwp/rhwp-studio/e2e/helpers.mjs` | upstream `loadHwpFile()` direct load 방식 |
| `/Users/melee/Documents/projects/forks/rhwp/rhwp-studio/src/main.ts` | 일반 load path에서 local font prompt/toast가 발생하는 지점 |
| `mydocs/report/task_m014_293_report.md` | `domComposite` / `overlayIncluded=true` overlay capture 계약 |
| `mydocs/report/task_m020_390_report.md` | `복학원서.hwp` reference capture contamination 관찰 |

## 현재 downstream harness 흐름

`StudioReferenceRenderer.capture`의 현재 흐름은 다음과 같다.

1. input file bytes를 읽어 `StudioDocumentSchemeHandler`에 넣는다.
2. `makeLoadURL(filename:revision:)`가 `alhangeul-studio://app/index.html?url=alhangeul-document://document&filename=...` URL을 만든다.
3. WebView가 `index.html`을 로드하고, bundled `rhwp-studio` 앱이 query의 `url`을 보고 일반 문서 로드 path를 수행한다.
4. `waitForPageReady(pageNumber:timeout:)`가 `#scroll-content canvas` 기반 page ready를 기다린다.
5. `alignAndHideChromeScript(pageNumber:)`가 메뉴/툴바/상태바/ruler를 CSS로 숨긴다.
6. `currentPageState(pageNumber:)`가 canvas와 overlay DOM 후보를 조사한다.
7. capture decision을 수행한다.
   - overlay DOM 또는 union이 있으면 `domComposite`
   - canvas sample이 비어 있으면 `webViewSnapshot`
   - 그 외에는 `canvasDataURL`

현재 chrome hide selector는 다음 UI만 숨긴다.

| selector |
|----------|
| `#menu-bar` |
| `#icon-toolbar` |
| `#style-bar` |
| `#status-bar` |
| `#ruler-corner` |
| `#h-ruler` |
| `#v-ruler` |

따라서 local font modal/toast, validation modal, autosave recovery prompt 같은 사용자-facing UI는 현재 selector 정책만으로는 구조적으로 차단되지 않는다.

## contamination 발생 경로

bundled `rhwp-studio`의 일반 load path는 문서 load 후 `initDoc` 계열 side effect를 수행한다.

확인한 일반 path side effect:

| 단계 | side effect |
|------|-------------|
| web font load | status text가 `폰트 로딩 중...`으로 변경 |
| `canvasView.loadDocument()` | page canvas render |
| toolbar enable/init | font/style dropdown 초기화 |
| validation warning | 필요 시 validation modal 표시 |
| `promptLocalFontsIfNeeded` | 필요 시 local font modal 표시 |
| local font detect success/failure | `로컬 글꼴 ...` status/toast 표시 |

#390에서 `복학원서.hwp`는 CoreGraphics/Skia visual diff가 모두 99%대로 튀었고, 최종 보고서는 이를 `reference capture contamination`으로 분리했다. 이 수치는 renderer output 자체보다 reference PNG에 사용자 UI가 섞였다는 신호로 해석해야 한다.

## upstream direct load 방식

upstream `rhwp-studio/e2e/helpers.mjs`의 `loadHwpFile()`은 일반 file input/UI path를 거치지 않는다.

핵심 흐름:

1. sample URL을 `fetch`한다.
2. `arrayBuffer()`를 `Uint8Array`로 만든다.
3. `window.__wasm.loadDocument(new Uint8Array(buf), fname)`를 직접 호출한다.
4. `window.__canvasView.loadDocument()`를 직접 호출한다.
5. canvas selector가 나타날 때까지 기다린다.

이 경로는 `src/main.ts`의 `initDoc`에서 수행하는 validation prompt, local font prompt/toast, toolbar init 같은 사용자 UI side effect를 우회한다. #398 Stage 2에서 downstream harness가 따라야 할 기준은 이 direct WASM/canvas load 방식이다.

## #293 overlay capture 계약

#293은 `복학원서.hwp`의 DOM overlay가 reference PNG에서 누락되던 문제를 이미 해결했다.

유지해야 하는 계약:

| 항목 | 기대값 |
|------|--------|
| overlay-positive reference | `captureMode=domComposite` |
| overlay metadata | `overlayIncluded=true` |
| `복학원서.hwp` 역할 | BehindText overlay positive fixture |
| overlay 없는 회귀 기준 | `canvasDataURL`, `overlayIncluded=false` 유지 |

따라서 #398은 capture decision을 canvas-only로 되돌리면 안 된다. 수정 지점은 document load path와 contamination metadata이며, `domComposite` 합성 방식은 유지해야 한다.

## Stage 2 구현 지점

| 구현 지점 | 결정 |
|-----------|------|
| app URL 생성 | 기존 `makeLoadURL(filename:revision:)`와 별도로 `makeAutomationAppURL()`을 추가한다 |
| document URL 생성 | `StudioDocumentSchemeHandler`는 유지하고 `makeDocumentURL(revision:)` 같은 작은 helper로 분리한다 |
| WebView navigation | `alhangeul-studio://app/index.html`만 로드한다. `url` query를 넣지 않는다 |
| runtime readiness | 문서 canvas가 아니라 `window.__wasm`와 `window.__canvasView` 존재를 기다리는 `waitForAutomationRuntime(timeout:)`를 추가한다 |
| document load | page JS에서 `fetch(documentURL)` 후 `window.__wasm.loadDocument(...)`, `window.__canvasView.loadDocument()`를 호출한다 |
| post-load readiness | 기존 `waitForPageReady(pageNumber:timeout:)`와 `currentPageState`를 재사용한다 |
| capture decision | 기존 `domComposite` / `webViewSnapshot` / `canvasDataURL` 순서를 유지한다 |
| fallback | automation load 실패 시 기존 UI load로 조용히 fallback하지 않는다 |

예상 Stage 2 흐름:

```text
createWebView(documentData, revision)
-> load(makeAutomationAppURL())
-> waitForAutomationRuntime()
-> loadDocumentForAutomation(documentURL, filename)
-> waitForPageReady(pageNumber)
-> alignPageAndHideChrome(pageNumber)
-> currentPageState(pageNumber)
-> existing capture decision
```

## Stage 3 metadata 입력

Stage 1 기준으로 Stage 3에서 추가해야 할 metadata 후보는 다음과 같다.

| field | 의미 |
|-------|------|
| `automationLoad` | automation direct load path 사용 여부 |
| `captureContaminated` | capture 전후 사용자 UI contamination 감지 여부 |
| `uiSuppressed` | residual UI를 숨긴 경우 |
| `modalCount` | visible modal/dialog 후보 수 |
| `toastCount` | visible toast/notification 후보 수 |
| `localFontUIVisible` | `로컬 글꼴`, `글꼴 감지`, `폰트 감지` 계열 text 감지 |
| `contaminationText` | 감지된 contamination text sample |

Stage 2 구현만으로 contamination이 사라져야 하지만, Stage 3 metadata가 있어야 #396 Stage 4에서 `복학원서.hwp` 결과를 정상 sample로 해석할지 근거를 남길 수 있다.

## 본문 변경 정도 / 본문 무손실 여부

해당 없음. 이번 단계는 inventory 보고서 작성과 오늘할일 비고 갱신만 수행했다. 기존 문서와 source는 수정하지 않았다.

## 검증 결과

| 명령 | 결과 |
|------|------|
| downstream harness keyword `rg` | 통과: load URL, readiness, chrome hide, capture decision keyword 확인 |
| upstream direct load keyword `rg` | 통과: `loadHwpFile`, `__wasm`, `__canvasView`, `loadDocument` 확인 |
| `git diff --check` | 통과 |

## 잔여 위험

- 현재 workspace context에서는 upstream fork가 조사용 read target으로 접근 가능했지만, #398의 실제 변경은 downstream repo에만 적용한다.
- direct load가 `initDoc`의 toolbar/font dropdown side effect를 우회하므로, renderer reference에 필요한 side effect와 사용자 UI side effect를 Stage 2 smoke에서 구분해야 한다.
- `복학원서.hwp`는 capture contamination을 제거해도 layout overflow, displayText, watermark/effect 이력이 남아 있다. clean capture가 곧 Skia default 통과를 의미하지 않는다.
- WebKit readiness timeout은 renderer failure가 아니라 environment failure로 계속 분리해야 한다.

## 다음 단계 영향

Stage 2에서는 `scripts/preview_visual_diff_harness.swift`에 automation app URL, automation runtime readiness, direct document load JS를 추가한다. Stage 2는 metadata 확장까지 한 번에 하지 않고, 기존 capture decision 유지와 direct load 성공을 먼저 닫는다.

## 승인 요청

Stage 1 결과에 따라 Stage 2 `automation load path 구현`으로 진행해도 되는지 승인 요청한다.
