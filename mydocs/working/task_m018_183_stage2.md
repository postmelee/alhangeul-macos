# Task M018 #183 Stage 2 완료 보고서

## 단계 목적

Stage 1에서 재현한 `ResizeObserver loop completed with undelivered notifications.` fallback의 원인 경로를 분리하고, Stage 3에서 적용할 최소 수정안을 확정했다.

이번 단계는 분석 단계다. 제품 코드 변경은 하지 않았고, host bridge, WebView runtime fallback 처리, bundled `rhwp-studio` resize 경로를 대조했다.

## 산출물

| 파일 | 내용 |
|------|------|
| `mydocs/working/task_m018_183_stage2.md` | runtime error 승격 경로, resize trigger 후보, Stage 3 수정안 |
| `mydocs/orders/20260509.md` | #183 상태를 Stage 2 완료 및 Stage 3 승인 대기로 갱신 |

## 원인 경로 요약

Stage 1의 재현 값은 다음과 같다.

```text
message=ResizeObserver loop completed with undelivered notifications.
sourceURL=alhangeul-studio://app/index.html?url=alhangeul-document://current?revision%3D1&filename=KTX.hwp
line=0
column=0
```

이 값은 document route, bundled asset 누락, signing/notarization 문제가 아니라 WebView page-level `window.error` 이벤트다. unified log에는 같은 문자열이 남지 않았고, native fallback disclosure에만 표시됐다.

현재 host bridge는 `window.addEventListener("error", ...)`에서 message가 있으면 `runtime-error`를 native로 전달한다. 기존 benign filter는 `registerSW.js`만 필터링한다.

```text
RhwpStudioHostBridgeScript.runtimeErrorSource
window.error -> isBenignRuntimeIssue(sourceURL, reason) -> postNative(type: "runtime-error")
```

native 쪽은 `runtime-error`를 받으면 항상 `handleRuntimeError`로 보내고, `finishLoading()` 후 `.runtime(...)` 실패 상태로 전환한다.

```text
RhwpStudioWebView.userContentController
runtime-error -> handleRuntimeError -> onFailure(.runtime)
```

따라서 현재 증상은 resize 과정의 browser-level ResizeObserver notification이 실제 viewer 정지와 구분되지 않고 fatal runtime error로 승격되는 경로다.

## `rhwp-studio` resize 경로

bundled main JS `assets/index-BN69C-Lp.js`에는 viewport manager가 `ResizeObserver`를 등록한다.

```text
resizeObserver = new ResizeObserver(() => {
  updateViewportSize()
  eventBus.emit("viewport-resize", viewportWidth, viewportHeight)
})
```

`viewport-resize`는 canvas view와 ruler 쪽으로 이어진다.

```text
viewport-resize -> onViewportResize()
onViewportResize -> recalcLayout() -> updateVisiblePages()

viewport-resize -> ruler.resize() -> scheduleUpdate()
```

창이 작은 상태에서 큰 상태로 확대되면 `ResizeObserver` callback 안에서 layout read/write가 연쇄되고, WebKit이 loop notification을 `window.error` 형태로 보고할 수 있다. Stage 1에서 `KTX.hwp`는 이 경로가 재현됐고, `hwpx-01.hwpx`는 같은 설치본에서 재현되지 않았다. 문서별 페이지 수, 초기 viewport, layout 상태가 trigger 민감도에 영향을 주는 것으로 본다.

## 후보별 판단

| 후보 | 판단 | 근거 |
|------|------|------|
| bundled asset 누락/손상 | 제외 | 설치본, source, Debug app bundle 모두 `verify-rhwp-studio-assets.sh` 통과 |
| document URL/revision 경로 오류 | 제외 | fallback 직전 URL이 `alhangeul-document://current?revision=1` 정상 경로이며 초기 로드와 retry가 정상 |
| signing/hardened runtime 문제 | 제외 | 설치본은 정상 서명/봉인 상태이고 Debug build에서도 같은 증상 재현 |
| WASM 초기화 실패 | 제외 | 문서 로드와 페이지 수 표시가 완료된 뒤 창 확대에서 발생 |
| `rhwp-studio` ResizeObserver layout cycle | trigger 후보 | main JS에서 resize observer가 viewport resize event를 즉시 emit하고 layout 재계산/캔버스 크기 변경으로 연결 |
| host bridge의 runtime fatal 승격 | 수정 대상 | browser-level ResizeObserver notification이 `runtime-error`로 native fallback 처리됨 |

## Stage 3 수정안

Stage 3에서는 bundled minified JS를 수정하지 않고 `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift`의 runtime bridge filter만 좁게 확장한다.

수정 방향:

- `isBenignRuntimeIssue`가 `message`, `sourceURL`, `reason`, `line`, `column`을 함께 판단하게 변경한다.
- 기존 `registerSW.js` benign rule은 유지한다.
- 다음 ResizeObserver loop notification만 benign으로 처리한다.
  - `ResizeObserver loop completed with undelivered notifications.`
  - `ResizeObserver loop limit exceeded`
- ResizeObserver benign 판정은 `reason`이 비어 있고 `line`/`column`이 `0`인 browser-level notification에 한정한다.
- 실제 JavaScript/WASM exception, stack이 있는 error, source line이 있는 error, promise rejection은 계속 fatal로 둔다.

이 접근을 선택한 이유:

- 이슈 증상은 host bridge가 browser notification을 fatal로 승격하는 문제이므로 host 경계에서 분리하는 것이 최소 수정이다.
- bundled `rhwp-studio` main JS는 minified third-party-like asset 성격이고, 직접 패치하면 출처/재생성 흐름이 흐려진다.
- `handleRuntimeError` 전체를 nonfatal로 낮추면 #150에서 도입한 실제 JS/WASM runtime failure 감지가 약해진다.

## Stage 3 검증 기준

Stage 3 완료 조건은 다음이다.

- `KTX.hwp`를 열고 초기 작은 창에서 창 확대를 실행해도 fatal fallback이 표시되지 않는다.
- 같은 문서에서 retry 없이 status text가 유지된다.
- `hwpx-01.hwpx` 창 확대도 기존처럼 fallback 없이 유지된다.
- `scripts/verify-rhwp-studio-assets.sh`가 통과한다.
- `xcodebuild -project Alhangeul.xcodeproj -scheme Alhangeul -configuration Debug -derivedDataPath build.noindex/DerivedData build`가 통과한다.

## 잔여 위험

- WebKit의 ResizeObserver loop notification 발생 여부는 viewport 크기, 문서 layout, 장치 배율에 따라 달라질 수 있다.
- 필터는 browser-level notification만 무시하므로 viewer 내부의 실제 resize 버그가 별도 exception으로 드러나면 여전히 fallback 처리된다.
- Stage 4에서 UI smoke 범위를 넓혀 창 확대, 원복, retry, HWP/HWPX sample을 다시 확인해야 한다.

## 본문 변경 정도 / 본문 무손실 여부

- 제품 코드 변경 없음.
- 기존 문서 본문 삭제 없음.
- `mydocs/orders/20260509.md`는 #183 비고만 Stage 2 완료 상태로 갱신한다.

## 검증 결과

```bash
git status --short --branch
```

결과:

```text
## local/task183
```

```bash
rg -n "runtime-error|unhandledrejection|isBenignRuntimeIssue|ResizeObserver|viewport-resize|handleRuntimeError" \
  Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift \
  Sources/HostApp/Views/RhwpStudioWebView.swift \
  Sources/HostApp/Resources/rhwp-studio --glob '*.swift' --glob '*.js'
```

확인한 핵심 match:

- `RhwpStudioHostBridgeScript.swift`: `isBenignRuntimeIssue`, `window.error`, `unhandledrejection`, `runtime-error`
- `RhwpStudioWebView.swift`: `runtime-error`, `handleRuntimeError`
- `index-BN69C-Lp.js`: `ResizeObserver`, `viewport-resize`, `onViewportResize`, ruler `resize()`

```bash
git diff --check
```

결과: 출력 없음. 공백 오류 없음.

## 다음 단계

Stage 3에서는 승인 후 위 수정안에 따라 host bridge benign filter를 구현한다. 구현 파일은 `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift`로 제한하고, 필요 시 reviewer가 읽기 쉬운 형태의 작은 JavaScript helper만 추가한다.
