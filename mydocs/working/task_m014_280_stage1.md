# Task M014 #280 Stage 1 보고서 - preview diff harness 구조 확정

## 단계 개요

- 이슈: #280 rhwp-studio 기준 preview visual diff harness 구축
- 단계: Stage 1. Inventory와 capture selector 확정
- 목표: 기존 비교 script, bundled `rhwp-studio` 렌더 표면, HostApp scheme handler, Shared renderer contract를 확인하고 Stage 2-4 구현 경계를 고정한다.

이번 단계는 조사와 구조 확정만 수행했다. Swift source와 script 구현은 시작하지 않았다.

## 확인한 현재 구조

### 기존 비교와 smoke script

`scripts/render-debug-compare.sh`는 Swift helper를 compile해 render tree JSON, core SVG, native PNG, 선택적 core PNG와 diff 산출물을 생성한다. 문서 내부 render tree와 core renderer를 진단하기에는 유용하지만, bundled `rhwp-studio`가 실제 WebView에서 보여주는 기본 화면을 reference로 캡처하지는 않는다.

`scripts/visual-compare-quicklook-renderers.sh`는 native PNG와 SVG-PDF raster 결과를 비교한다. diff 계산에는 이미 다음 지표가 있다.

| 지표 | 현재 의미 |
|---|---|
| `changedPixels` / `changedPercent` | threshold 초과 pixel 수와 비율 |
| `meanRGBDelta` | RGB 평균 차이 |
| `maxRGBDelta` | 최대 채널 차이 |
| `bounds` | 차이가 발생한 bounding box |

`scripts/smoke-quicklook-skia-policy.sh`는 `coreGraphicsOnly`와 `skiaOptIn` 정책별 backend count, PNG bytes, render time을 측정한다. #280 harness는 이 정책 옵션과 diagnostics 표현을 재사용하되, 기준 이미지는 `rhwp-studio` WebKit snapshot으로 둔다.

### rhwp-studio DOM과 렌더 표면

`Sources/HostApp/Resources/rhwp-studio/index.html`의 viewer/editor 영역은 다음 구조다.

```html
<div id="editor-area">
  <div id="ruler-corner"></div>
  <canvas id="h-ruler"></canvas>
  <canvas id="v-ruler"></canvas>
  <div id="scroll-container">
    <div id="scroll-content"></div>
  </div>
</div>
<div id="status-bar">...</div>
```

CSS 기준으로 문서 page canvas는 `#scroll-content canvas`에 absolute 배치되고, `left: 50%`와 `transform: translate(-50%)`로 가운데 정렬된다. `#scroll-container`는 scrollable viewport이고, `#scroll-content`는 여러 page를 포함하는 문서 content root다.

minified JS 조사 결과 문서 로드는 `?url=...&filename=...` query를 읽어 입력 bytes를 fetch한 뒤 `loadDocument()`로 진행된다. `window.postMessage` 기반 `rhwp-request` API에는 `ready`, `loadFile`, `pageCount`, `getPageSvg` 등이 있지만, 기본 화면 기준 diff에는 `getPageSvg`보다 실제 page 영역 snapshot이 더 적합하다. Studio 기본 렌더는 canvas와 DOM overlay가 함께 보일 수 있기 때문이다.

### HostApp의 Studio resource와 document scheme

HostApp은 다음 custom scheme을 사용한다.

| Scheme | 구현 | 역할 |
|---|---|---|
| `alhangeul-studio://app/...` | `RhwpStudioResourceSchemeHandler` | bundled `rhwp-studio` 정적 asset 제공 |
| `alhangeul-document://current?...` | `RhwpStudioDocumentSchemeHandler` | 현재 문서 bytes 제공 |

`RhwpStudioResourceLocator`는 다음 형태의 URL을 만든다.

```text
alhangeul-studio://app/index.html?url=alhangeul-document://current?revision=<N>&filename=<name>
```

다만 HostApp 구현은 `Bundle.main` resource lookup을 전제로 한다. Stage 2의 standalone Swift helper는 앱 bundle 안에서 실행되지 않으므로 HostApp handler를 직접 재사용하지 않고, 같은 scheme과 MIME/CORS/no-store 정책을 script-local handler로 재현한다.

### Native preview renderer contract

`Sources/Shared/HwpPageImageRenderer.swift`는 `HwpPageRenderPolicy.coreGraphicsOnly`와 `skiaOptIn`을 제공한다. 반환값 `HwpRenderedPage`에는 `image`, `size`, `diagnostics`가 있고 diagnostics에는 `backendUsed`, `fallbackReason`, `pageSize`, `pixelSize`, `pngBytes`, `durationMs`가 포함된다.

#280 harness의 native baseline은 Quick Look/Thumbnail이 공유할 이 계층으로 둔다. 기본 정책은 현재 preview 기준과 맞춰 `coreGraphicsOnly`이며, `skiaOptIn`은 옵션으로만 제공한다.

## 확정한 구현 방향

### Reference capture 방식

Stage 2에서는 standalone Swift/WebKit helper를 추가한다.

1. `WKWebViewConfiguration`에 script-local `alhangeul-studio`와 `alhangeul-document` scheme handler를 등록한다.
2. `Sources/HostApp/Resources/rhwp-studio`의 `index.html`을 `alhangeul-studio://app/index.html?url=...&filename=...`로 연다.
3. navigation 완료 후 JavaScript polling으로 `#scroll-content canvas` 수와 대상 page canvas의 bounding rect를 확인한다.
4. `requestAnimationFrame` 두 번과 짧은 settle delay를 둬 비동기 canvas redraw와 image decode 직후의 흔들림을 줄인다.
5. editor chrome을 숨기는 CSS를 주입한 뒤 `WKWebView.takeSnapshot`으로 page rect를 PNG 저장한다.

canvas 자체의 `toDataURL`은 사용하지 않는다. page rect snapshot을 사용해야 canvas 위/주변의 DOM overlay가 reference에 포함될 수 있다.

### Selector와 rect 기준

Stage 2 기본 selector 기준은 `#scroll-content canvas`의 page index다.

| 우선순위 | 기준 | 판단 |
|---|---|---|
| 1 | 대상 page canvas의 bounding rect | page 단위 캡처의 안정적 기준 |
| 2 | 같은 vertical span과 교차하는 `#scroll-content` 하위 overlay rect를 포함한 union rect | DOM overlay가 확인되는 문서에서 확장 |
| 3 | `#scroll-content` 전체 | page rect 계산 실패 시 metadata에 fallback으로 기록 |

여러 page 문서에서 `#scroll-content` 전체를 바로 캡처하면 page 간 공백과 다른 page가 섞일 수 있으므로 기본값으로 사용하지 않는다.

### Chrome 제외 정책

Finder Quick Look/Thumbnail parity 기준에서 menu, toolbar, status bar, ruler, selection/caret은 reference에서 제외한다. Stage 2 helper는 다음 DOM chrome을 `display: none !important`로 숨긴다.

```css
#menu-bar,
#icon-toolbar,
#style-bar,
#status-bar,
#ruler-corner,
#h-ruler,
#v-ruler {
  display: none !important;
}
```

canvas 내부에 이미 그려진 margin guide나 editor guide는 DOM CSS로 제거할 수 없다. 이번 이슈에서는 renderer 동작을 바꾸지 않고, metadata와 summary에서 `editorChromeResidual` 또는 mask 후보로 남긴다.

### Native render와 diff

Stage 3의 native 출력은 다음 경로로 생성한다.

```swift
HwpPageImageRenderer.renderPage(
    document: document,
    pageIndex: pageIndex,
    policy: policy
)
```

Studio reference PNG와 native PNG 크기가 다르면 원본 크기는 metadata에 보존하고, 비교용 raster는 Studio reference 크기에 맞춘다. diff threshold는 기존 `visual_compare_quicklook_renderers.swift`와 같은 pixel delta `12`를 초기 관찰 기준으로 사용한다. hard gate threshold는 #280 범위에서 만들지 않는다.

## Stage 2 구현 범위

Stage 2에서 추가할 파일:

- `scripts/preview-visual-diff-harness.sh`
- `scripts/preview_visual_diff_harness.swift`

Stage 2에서 다룰 산출물:

- `studio/{file}-page{N}-studio.png`
- `studio/{file}-page{N}-studio.json`

Stage 2 metadata 필드:

| 필드 | 목적 |
|---|---|
| `sourcePath`, `filename`, `page` | 입력 식별 |
| `loadURL`, `selector`, `rect` | capture 재현성 |
| `devicePixelRatio`, `viewportSize` | WebKit raster 조건 |
| `captureMs`, `settleMs` | 측정 시간 |
| `studioReleaseTag`, `studioResolvedCommit`, `assetHash` | reference provenance |
| `chromeHidden`, `editorChromeResidual` | 제외/잔류 chrome 판단 |

Stage 2에서는 아직 native render와 diff 계산을 구현하지 않는다.

## 리스크와 보류 판단

- `rhwp-studio` page canvas는 minified asset 내부 구현에 의존한다. selector는 public DOM id인 `#scroll-content`와 canvas 배치에만 기대도록 좁힌다.
- DOM overlay가 page canvas의 형제/자식 중 어떤 형태로 붙는지는 문서별로 다를 수 있다. Stage 2는 overlay union rect metadata를 남기고, 실제 overlay 캡처 품질은 Stage 3 sample diff에서 다시 확인한다.
- Studio canvas 내부 guide는 CSS로 제거할 수 없으므로 이번 harness의 diff에는 잔류 chrome noise가 남을 수 있다. 이는 후속 mask나 Studio capture mode 조정 후보로 남긴다.
- `getPageSvg` API는 reference 후보로 남길 수 있지만, 이번 harness의 기본 reference는 사용자가 보는 Studio WebView snapshot으로 둔다.

## Stage 1 검증

실행:

```bash
rg -n "scroll-container|scroll-content|canvas|overlay|ruler|status-bar|renderPageToCanvasFiltered|loadFromUrlParam" \
  Sources/HostApp/Resources/rhwp-studio/index.html \
  Sources/HostApp/Resources/rhwp-studio/assets/index-*.css \
  Sources/HostApp/Resources/rhwp-studio/assets/index-*.js
rg -n "HwpPageImageRenderer|HwpRenderedPage|backendUsed|fallbackReason|renderPage\\(" \
  Sources/Shared Sources/QLExtension scripts
```

결과:

- bundled `rhwp-studio`의 문서 표시 root가 `#scroll-container`와 `#scroll-content`임을 확인했다.
- page별 렌더 표면은 `#scroll-content canvas`이며, page 단위 snapshot rect 계산의 기준으로 사용할 수 있음을 확인했다.
- HostApp의 custom scheme URL 구조와 MIME/CORS/no-store 정책을 확인했다.
- HostApp scheme handler는 `Bundle.main` 의존이 있으므로 standalone helper에서는 script-local handler로 재현해야 함을 확인했다.
- `HwpPageImageRenderer` diagnostics가 native render backend와 fallback, size, timing 기록에 필요한 필드를 이미 제공함을 확인했다.
- Stage 1에서는 source/script 구현을 시작하지 않았다.

## 다음 단계 승인 요청

Stage 2에서는 위 구조를 기준으로 `scripts/preview-visual-diff-harness.sh`와 `scripts/preview_visual_diff_harness.swift`를 추가해 `rhwp-studio` reference PNG와 metadata JSON 생성까지만 구현한다.
