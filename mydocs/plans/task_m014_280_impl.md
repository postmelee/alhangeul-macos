# Task M014 #280 구현 계획서

수행계획서: `mydocs/plans/task_m014_280.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #280 rhwp-studio 기준 preview visual diff harness 구축
- 마일스톤: M014 (`v0.1.4 Native Preview/Viewer Parity`)
- 브랜치: `local/task280`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac`
- 기준 브랜치: `devel`
- 목표: bundled `rhwp-studio` 기본 렌더 결과와 Swift/native preview 출력을 같은 샘플/페이지 단위로 생성하고, diff 이미지와 수치 summary를 남기는 반복 실행 harness를 만든다.

## 구현 원칙

- renderer 자체는 변경하지 않는다. #280은 측정/비교 harness만 추가한다.
- reference는 `Sources/HostApp/Resources/rhwp-studio`에 bundled 된 정적 asset snapshot을 사용한다.
- `rhwp-core.lock`과 `rhwp-studio/manifest.json`의 release tag, resolved commit, asset hash를 summary에 기록한다.
- Finder preview/thumbnail parity 기준에서 menu, toolbar, status bar, ruler, selection/caret 등 editor chrome은 제외한다.
- `rhwp-studio` canvas 내부에 margin guide가 그려져 분리할 수 없는 경우, diff summary에서 editor chrome residual로 분류하거나 mask 후보로 남긴다. 이번 작업에서 renderer 동작을 바꿔 제거하지 않는다.
- visual diff 수치는 후속 렌더 개선의 판단 자료다. 이번 이슈에서 release hard gate threshold를 만들지 않는다.
- `Sources/RhwpCoreBridge`에 AppKit/UIKit/WebKit 의존을 추가하지 않는다. WebKit/AppKit 사용은 `scripts/` helper 안에만 둔다.
- upstream `edwardkim/rhwp` 수정, unreleased commit pin, rhwp-studio asset 갱신은 하지 않는다.

## Harness 구조

새 harness는 shell orchestration과 Swift helper로 구성한다.

| 파일 | 역할 |
|---|---|
| `scripts/preview-visual-diff-harness.sh` | staticlib/modulemap 존재 확인, Swift helper compile, 기본 sample/page 인자 전달 |
| `scripts/preview_visual_diff_harness.swift` | WebKit reference capture, native preview render, pixel diff, summary 작성 |
| `mydocs/tech/v014_preview_visual_diff_harness.md` | 사용법, sample set, editor chrome 제외 정책, 수치 해석 기준 문서화 |

기본 산출물 구조:

```text
<output-dir>/
  studio/
    {file}-page{N}-studio.png
    {file}-page{N}-studio.json
  native/
    {file}-page{N}-native.png
    {file}-page{N}-native.json
  diff/
    {file}-page{N}-diff.png
  summary.md
```

Swift helper의 기본 CLI:

```bash
./scripts/preview-visual-diff-harness.sh <output-dir> [--page N] [--policy coreGraphicsOnly|skiaOptIn] <hwp-or-hwpx> [...]
```

초기 default는 `--policy coreGraphicsOnly`로 둔다. Skia opt-in 비교는 같은 harness 옵션으로 가능하게 하되, Skia release 판단은 #259/M20 쪽 결정으로 남긴다.

## Reference Capture 설계

`rhwp-studio` reference capture는 standalone Swift/WebKit helper에서 수행한다.

1. `WKWebViewConfiguration`에 script-local URL scheme handler를 등록한다.
   - `alhangeul-studio://app/...`는 `Sources/HostApp/Resources/rhwp-studio` 파일을 제공한다.
   - `alhangeul-document://current?revision=...`는 현재 입력 문서 bytes를 제공한다.
2. `alhangeul-studio://app/index.html?url=alhangeul-document://current?revision=...&filename=...`로 로드한다.
3. navigation 완료 후 JavaScript polling으로 문서 로드 완료와 page element를 확인한다.
4. menu/toolbar/status/ruler chrome을 숨기는 CSS를 주입한다.
5. page content bounding rect를 계산하고 `WKWebView.takeSnapshot`으로 해당 rect를 PNG로 저장한다.
6. capture metadata에는 selector, rect, devicePixelRatio, viewport size, page number, load timing, reference provenance를 기록한다.

page selector는 Stage 1에서 확정한다. 후보 순서는 다음과 같다.

1. `#scroll-content` 아래 page wrapper
2. page별 canvas의 부모 element
3. 첫 번째 visible page canvas와 overlay를 포함하는 가장 가까운 block ancestor

canvas만 직접 추출하면 DOM overlay image가 빠질 수 있으므로, Stage 2 구현은 canvas 단독 `toDataURL`이 아니라 page wrapper snapshot을 우선한다.

## Native Preview Render 설계

native 출력은 기존 Shared renderer 경로를 사용한다.

- 입력: `RhwpDocument(data:filename:)`
- 기본: `HwpPageImageRenderer.renderPage(document:pageIndex:policy:)`
- 옵션: `coreGraphicsOnly`, `skiaOptIn`
- 크기 정렬: reference PNG 크기와 native PNG 크기가 다르면 native output을 reference 크기에 맞춰 rasterize한 뒤 diff한다. 원본 크기는 metadata에 따로 기록한다.
- diagnostics: `backendUsed`, `fallbackReason`, `pixelSize`, `pngBytes`, `durationMs`를 native metadata에 기록한다.

기존 `scripts/render-debug-compare.sh`는 render tree/core SVG 분석 보조 도구로 유지하고, 이번 harness의 native baseline은 Quick Look/Thumbnail이 공유하는 `HwpPageImageRenderer` 계층을 기준으로 한다.

## Diff Metrics

기존 `visual_compare_quicklook_renderers.swift`의 pixel diff 방식을 재사용하되, #280 helper 안에서 다음 값을 summary에 남긴다.

| 지표 | 의미 |
|---|---|
| `changedPixels` / `changedPercent` | threshold 초과 pixel 수와 비율 |
| `meanRGBDelta` | 전체 RGB 평균 차이 |
| `maxRGBDelta` | 가장 큰 채널 차이 |
| `diffBounds` | 차이가 발생한 bounding box |
| `studioNonWhitePixels` / `nativeNonWhitePixels` | blank/empty 회귀 감지용 |
| `studioSize` / `nativeSize` / `compareSize` | 크기 정렬 결과 |
| `studioCaptureMs` / `nativeRenderMs` / `diffMs` | 성능 관찰값 |

초기 pixel delta threshold는 기존 비교 helper와 맞춰 12로 둔다. threshold는 hard gate가 아니라 관찰 기준이다.

## Stage 1. Inventory와 capture selector 확정

### 목표

기존 script, bundled `rhwp-studio` DOM 구조, HostApp scheme handler, Shared renderer contract를 확인하고 Stage 2-4의 구현 경계를 고정한다.

### 작업

- `scripts/render-debug-compare.sh`, `visual-compare-quicklook-renderers.sh`, `smoke-quicklook-skia-policy.sh`의 입력/산출물을 정리한다.
- bundled `rhwp-studio` `index.html`, CSS, minified JS에서 page container, scroll container, canvas/overlay 구조 후보를 확인한다.
- HostApp의 `RhwpStudioResourceSchemeHandler`, `RhwpStudioDocumentSchemeHandler`, `RhwpStudioResourceLocator`를 참고해 script-local scheme handler 범위를 확정한다.
- Stage 2에서 사용할 WebKit capture readiness 조건과 selector fallback 순서를 정한다.
- Stage 1 보고서에 확정된 파일/명령/selector 후보/리스크를 남긴다.

### 산출물

- `mydocs/plans/task_m014_280_impl.md`
- `mydocs/working/task_m014_280_stage1.md`

### 검증

```bash
rg -n "scroll-container|scroll-content|canvas|overlay|ruler|status-bar|renderPageToCanvasFiltered|loadFromUrlParam" \
  Sources/HostApp/Resources/rhwp-studio/index.html \
  Sources/HostApp/Resources/rhwp-studio/assets/index-*.css \
  Sources/HostApp/Resources/rhwp-studio/assets/index-*.js
rg -n "HwpPageImageRenderer|HwpRenderedPage|backendUsed|fallbackReason|renderPage\\(" \
  Sources/Shared Sources/QLExtension scripts
git diff --check
```

### 완료 기준

- Stage 2에서 구현할 capture URL, selector, wait condition, metadata 필드가 보고서에 고정된다.
- 아직 script/source 구현은 시작하지 않는다.

### 커밋 메시지

```text
Task #280 Stage 1: preview diff harness 구조 확정
```

## Stage 2. rhwp-studio reference capture 구현

### 목표

bundled `rhwp-studio`가 실제로 문서를 열어 렌더한 첫 page content 영역을 PNG와 metadata로 저장한다.

### 작업

- `scripts/preview-visual-diff-harness.sh`를 추가해 Swift helper compile과 실행을 담당하게 한다.
- `scripts/preview_visual_diff_harness.swift`에 WebKit runner, script-local resource/document scheme handler, PNG writer를 구현한다.
- page load 완료 polling, page rect 계산, editor chrome CSS hide, `takeSnapshot` 저장을 구현한다.
- reference provenance와 capture timing metadata를 JSON으로 저장한다.
- sample 1-2개로 `studio/*.png`와 `studio/*.json`이 생성되는지 smoke한다.

### 산출물

- `scripts/preview-visual-diff-harness.sh`
- `scripts/preview_visual_diff_harness.swift`
- `mydocs/working/task_m014_280_stage2.md`

### 검증

```bash
./scripts/verify-rhwp-studio-assets.sh
./scripts/preview-visual-diff-harness.sh build.noindex/task280-stage2 --page 1 \
  samples/basic/request.hwp samples/복학원서.hwp
find build.noindex/task280-stage2/studio -maxdepth 1 -type f | sort
git diff --check
```

### 완료 기준

- `rhwp-studio` reference PNG와 metadata JSON이 생성된다.
- metadata에 selector, rect, page number, devicePixelRatio, viewport, provenance가 남는다.
- editor chrome 제외 정책이 capture CSS/metadata에 반영된다.

### 커밋 메시지

```text
Task #280 Stage 2: rhwp-studio reference capture 추가
```

## Stage 3. native preview 출력과 diff 계산 구현

### 목표

같은 입력 문서와 page에 대해 native preview PNG를 생성하고, `rhwp-studio` reference와 pixel diff를 계산한다.

### 작업

- Swift helper에 `RhwpDocument`와 `HwpPageImageRenderer` 기반 native render 경로를 추가한다.
- `--policy coreGraphicsOnly|skiaOptIn` 옵션을 구현한다.
- reference/native 크기 차이를 metadata에 기록하고, 비교용 image는 reference 크기로 정렬한다.
- diff PNG와 `summary.md`를 생성한다.
- failure row가 있는 경우에도 나머지 파일을 계속 처리하게 한다.

### 산출물

- `scripts/preview_visual_diff_harness.swift`
- 필요 시 `scripts/preview-visual-diff-harness.sh`
- `mydocs/working/task_m014_280_stage3.md`

### 검증

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task280-stage3 --page 1 \
  samples/basic/request.hwp samples/복학원서.hwp
find build.noindex/task280-stage3 -maxdepth 2 -type f | sort
sed -n '1,120p' build.noindex/task280-stage3/summary.md
git diff --check
```

### 완료 기준

- `studio`, `native`, `diff`, `summary.md` 산출물이 모두 생성된다.
- summary에 changed pixel, RGB delta, non-white pixel, backend diagnostics가 기록된다.
- 개별 파일 실패가 전체 harness 실패 원인으로 명확히 보고된다.

### 커밋 메시지

```text
Task #280 Stage 3: native preview diff 계산 추가
```

## Stage 4. sample set과 사용 문서 정리

### 목표

v0.1.4 렌더 개선 이슈들이 공통으로 재사용할 sample set, 실행 명령, 수치 해석 기준, 한계를 문서화한다.

### 작업

- 기본 sample set과 확장 sample set을 정한다.
- `mydocs/tech/v014_preview_visual_diff_harness.md`에 사용법과 산출물 설명을 작성한다.
- editor chrome 제외와 margin guide residual 처리 기준을 명시한다.
- #116, #122, #121, #110, #282에서 어떤 샘플과 수치를 봐야 하는지 handoff를 정리한다.

### 기본 sample set 후보

| 목적 | 샘플 |
|---|---|
| 일반 HWP smoke | `samples/basic/request.hwp` |
| watermark/effect | `samples/복학원서.hwp` |
| image crop/fill | `samples/pic-crop-01.hwp` |
| form/placeholder | `samples/form-01.hwp`, `samples/hwpx/form-002.hwpx` |
| HWPX smoke | `samples/hwpx/hwpx-01.hwpx` |

확장 후보는 `samples/tac-img-02.hwp`, `samples/tac-img-02.hwpx`, `samples/eq-01.hwp`, `samples/draw-group.hwp`, `samples/table-vpos-01.hwp`를 둔다.

### 산출물

- `mydocs/tech/v014_preview_visual_diff_harness.md`
- `mydocs/working/task_m014_280_stage4.md`

### 검증

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task280-stage4 --page 1 \
  samples/basic/request.hwp samples/복학원서.hwp samples/pic-crop-01.hwp \
  samples/form-01.hwp samples/hwpx/form-002.hwpx samples/hwpx/hwpx-01.hwpx
rg -n "#116|#122|#121|#110|#282|rhwp-studio|editor chrome|margin guide|changedPixels" \
  mydocs/tech/v014_preview_visual_diff_harness.md build.noindex/task280-stage4/summary.md
git diff --check
```

### 완료 기준

- 후속 이슈에서 그대로 실행할 기본 명령과 sample set이 문서화된다.
- visual diff 수치의 해석 범위와 제외 항목이 명확히 남는다.

### 커밋 메시지

```text
Task #280 Stage 4: preview diff sample set 문서화
```

## Stage 5. 최종 검증과 PR 준비

### 목표

전체 harness가 대표 샘플에서 동작하는지 확인하고, 최종 보고서와 오늘할일 완료 처리를 수행해 PR 게시 준비 상태로 만든다.

### 작업

- 대표 sample set으로 최종 smoke를 실행한다.
- shell/Swift syntax, source boundary, bundled asset verification을 수행한다.
- 최종 보고서에 관찰된 수치, 한계, 후속 이슈 handoff를 정리한다.
- 오늘할일을 완료로 갱신한다.

### 산출물

- `mydocs/report/task_m014_280_report.md`
- `mydocs/orders/20260525.md`

### 검증

```bash
./scripts/verify-rhwp-studio-assets.sh
./scripts/check-no-appkit.sh
./scripts/preview-visual-diff-harness.sh build.noindex/task280-final --page 1 \
  samples/basic/request.hwp samples/복학원서.hwp samples/pic-crop-01.hwp \
  samples/form-01.hwp samples/hwpx/form-002.hwpx samples/hwpx/hwpx-01.hwpx
swiftc -parse-as-library scripts/preview_visual_diff_harness.swift \
  -framework AppKit -framework WebKit -framework CoreGraphics -framework ImageIO -framework UniformTypeIdentifiers \
  -o /tmp/task280-syntax-check
rg -n "#280|changedPixels|meanRGBDelta|rhwp-studio|#116|#122|#121|#110|#282" \
  mydocs/report/task_m014_280_report.md mydocs/orders/20260525.md
git diff --check
git status --short --branch
```

### 완료 기준

- 대표 sample set에서 `summary.md`와 PNG/JSON 산출물이 생성된다.
- 최종 보고서에 smoke 측정 결과, 관찰, 수치 비교자료, 한계, 후속 handoff가 기록된다.
- 작업 브랜치에 미커밋 변경이 없다.

### 커밋 메시지

```text
Task #280 Stage 5: preview diff harness 최종 보고
```
