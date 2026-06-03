# Task M014 #121 Stage 1 완료보고서

## 개요

Stage 1은 Swift/CoreGraphics native renderer의 RawSvg current path를 inventory하고, #121 target sample의 구현 전 기준선을 고정하는 단계다. 소스 코드는 변경하지 않았고, 기존 script와 bundled artifact만 사용했다.

## 기준

| 항목 | 값 |
|------|----|
| 이슈 | #121 Swift native renderer RawSvg/OLE·차트 리소스 렌더링 보강 |
| 브랜치 | `local/task121` |
| 기준 브랜치 | `origin/devel` `1b767bd` |
| core/studio 기준 | `edwardkim/rhwp v0.7.13`, `b3e16ef212af81ef37d973ddb86d6816d3804642` |
| 수행계획서 | `mydocs/plans/task_m014_121.md` |
| 구현계획서 | `mydocs/plans/task_m014_121_impl.md` |

## Current Path Inventory

### Render tree model

`Sources/RhwpCoreBridge/RenderTree.swift`의 `RenderNodeType`에는 현재 `RawSvg` case가 없다.

- `RenderNodeType` case 목록은 `Page`, `Image`, `Group`, `Equation`, `FormObject` 등을 포함하지만 `RawSvg`는 없다.
- `RenderNodeType.init(from:)`는 알려진 externally tagged enum을 순서대로 디코딩한 뒤, 매칭되지 않는 struct variant를 `.unknown`으로 둔다.
- 따라서 upstream render tree JSON에 `{"RawSvg": ...}`가 들어오면 현재 Swift model은 이를 식별하지 못하고 `.unknown`으로 흡수할 가능성이 높다.

관련 코드:

- `Sources/RhwpCoreBridge/RenderTree.swift:38`
- `Sources/RhwpCoreBridge/RenderTree.swift:79`
- `Sources/RhwpCoreBridge/RenderTree.swift:96`

### 기존 이미지/수식 경로

`ImageNode`는 binary image resource 중심의 모델이다.

- `bin_data_id`, `fill_mode`, `original_size`, `original_size_hu`, `crop`, `effect`, `brightness`, `contrast`, `text_wrap`를 디코딩한다.
- #122 이후 `CGTreeRenderer.renderImage`와 overlay image path는 같은 `drawImage` helper를 사용한다.
- RawSvg payload가 image data URL이나 inline SVG fragment로 내려오는 경우에는 `ImageNode`와 별도 모델이 필요하다.

`EquationNode`는 `svg_content`를 갖지만 equation 전용이다.

- `CGTreeRenderer.renderEquation`은 equation subset parser와 CoreGraphics draw path를 사용한다.
- OLE/chart/복합 SVG fragment를 equation parser에 섞으면 책임 경계가 흐려지므로, Stage 2에서는 RawSvg 전용 모델과 fallback을 따로 설계해야 한다.

관련 코드:

- `Sources/RhwpCoreBridge/RenderTree.swift:299`
- `Sources/RhwpCoreBridge/RenderTree.swift:339`
- `Sources/RhwpCoreBridge/CGTreeRenderer.swift:205`
- `Sources/RhwpCoreBridge/CGTreeRenderer.swift:219`
- `Sources/RhwpCoreBridge/CGTreeRenderer.swift:738`
- `Sources/RhwpCoreBridge/CGTreeRenderer.swift:766`

### Shared renderer path

`HwpNativePageCompositor`는 page background, BehindText overlay, flow, InFrontOfText overlay 순서로 `CGTreeRenderer`를 호출한다. RawSvg draw/fallback을 `CGTreeRenderer`에 붙이면 Quick Look preview, Finder thumbnail, PDF/CoreGraphics fallback 경로에서 같은 renderer 결과를 확인할 수 있다.

관련 코드:

- `Sources/Shared/HwpNativePageCompositor.swift:3`
- `Sources/Shared/HwpNativePageCompositor.swift:14`
- `Sources/Shared/HwpNativePageCompositor.swift:34`

## Target Render Debug Baseline

명령:

```bash
./scripts/render-debug-compare.sh build.noindex/task121-stage1-render-debug --page 1 \
  samples/draw-group.hwp samples/eq-01.hwp
```

결과:

| 파일 | RenderTreeJSONBytes | CoreSVGBytes | NativePNGSize | NativeNonWhitePixels | TextRuns | HangulRuns | MissingHangulGlyphs | 비고 |
|------|--------------------:|-------------:|---------------|---------------------:|---------:|-----------:|--------------------:|------|
| `draw-group.hwp` | `13998` | `19539` | `794x1123` | `7324` | `2` | `1` | `0` | `LAYOUT_OVERFLOW_DRAW` 2회 stderr |
| `eq-01.hwp` | `233539` | `262660` | `794x1123` | `45708` | `71` | `37` | `0` | Equation 3개 |

두 샘플 모두 optional core SVG raster diff는 생성되지 않았다.

```text
DiffReason: qlmanage rasterize failed
```

산출물:

```text
build.noindex/task121-stage1-render-debug/
```

## Target Node Type 확인

`draw-group.hwp` 1페이지 node type:

| NodeType | Count |
|----------|------:|
| `Body` | 1 |
| `Column` | 1 |
| `Footer` | 1 |
| `Group` | 1 |
| `Header` | 1 |
| `Image` | 17 |
| `Page` | 1 |
| `PageBackground` | 1 |
| `Rectangle` | 2 |
| `TextLine` | 2 |
| `TextRun` | 2 |

`draw-group.hwp`의 image 17개는 모두 `fill_mode=null`, `text_wrap=Square`였다. 이 샘플은 이름과 달리 현재 upstream render tree 기준으로 RawSvg가 아니라 raster image node 집합으로 내려온다.

`eq-01.hwp` 1페이지 node type:

| NodeType | Count |
|----------|------:|
| `Body` | 1 |
| `Column` | 1 |
| `Equation` | 3 |
| `Footer` | 1 |
| `Header` | 1 |
| `Line` | 8 |
| `Page` | 1 |
| `PageBackground` | 1 |
| `Rectangle` | 2 |
| `Table` | 2 |
| `TableCell` | 2 |
| `TextLine` | 20 |
| `TextRun` | 71 |

`eq-01.hwp`의 Equation node:

| id | bbox | svgLength |
|----|------|----------:|
| `18` | `198.62000000000012,196.70360655737707,396.46666666666664x39.2` | `1533` |
| `58` | `141.77333333333337,427.2428415300547,423.2x36.8` | `2072` |
| `62` | `184.25333333333344,477.37617486338803,438.2x36.8` | `3757` |

## RawSvg Key Search

다음 문자열을 target render tree JSON에서 확인했다.

```text
RawSvg
rawSvg
raw_svg
OLE
ole
Chart
chart
```

결과:

| 범위 | 결과 |
|------|------|
| `build.noindex/task121-stage1-render-debug/*-render-tree.json` | hit 없음 |

판단:

- target sample 두 개는 현재 `rhwp v0.7.13` 기준 RawSvg 양성 fixture가 아니다.
- Swift decoder 누락은 코드 inventory상 분명하지만, 이 두 샘플만으로 RawSvg `.unknown` 흡수를 실증할 수는 없다.

## Repository Sample Scan

target sample에서 RawSvg가 나오지 않아 repository sample의 page 1 render tree를 1차 scan했다.

명령:

```bash
./scripts/render-debug-compare.sh build.noindex/task121-stage1-sample-scan --page 1 \
  $(find samples -type f \( -name '*.hwp' -o -name '*.hwpx' \) -print)
```

결과:

| 항목 | 값 |
|------|---:|
| 입력 HWP/HWPX 파일 수 | `174` |
| 생성된 render tree JSON 수 | `165` |
| 생성된 summary 수 | `165` |
| scan command exit code | `1` |

비고:

- 동일 basename HWP/HWPX가 같은 output stem을 공유하는 경우가 있어 일부 산출물은 덮어쓰기 가능성이 있다.
- command는 `FAIL: one or more render debug exports failed`로 종료했다. Stage 1 목적은 RawSvg fixture scan이므로, 생성된 JSON 전체를 기준으로 key search를 수행했다.

생성된 165개 render tree JSON 전체에서 RawSvg/OLE/chart 관련 key search 결과:

| Pattern | 결과 |
|---------|------|
| `RawSvg` / `rawSvg` / `raw_svg` | hit 없음 |
| `OLE` / `ole` | hit 없음 |
| `Chart` / `chart` | hit 없음 |

생성 JSON 전체 node type aggregate:

| NodeType | Count |
|----------|------:|
| `Body` | 165 |
| `Column` | 181 |
| `Ellipse` | 39 |
| `Equation` | 148 |
| `Footer` | 165 |
| `FootnoteArea` | 5 |
| `FootnoteMarker` | 24 |
| `FormObject` | 65 |
| `Group` | 26 |
| `Header` | 162 |
| `Image` | 175 |
| `Line` | 1456 |
| `MasterPage` | 12 |
| `Page` | 165 |
| `PageBackground` | 165 |
| `Path` | 47 |
| `Rectangle` | 1540 |
| `Table` | 220 |
| `TableCell` | 3750 |
| `TextLine` | 6187 |
| `TextRun` | 10003 |

판단:

- 현재 repository sample page 1 corpus에서는 RawSvg 양성 fixture를 확보하지 못했다.
- #121 구현을 진행하려면 Stage 2에서 실제 upstream RawSvg payload shape 확인 방법을 먼저 정해야 한다.
- 선택지는 외부 fixture 확보, upstream contract/serde shape 조사 기반 모델 설계, 또는 RawSvg hit가 없는 현 corpus에서는 fallback draw path를 설계만 하고 target fixture 확보 후 구현하는 방식이다.

## Visual Diff Baseline

명령:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task121-stage1-baseline --page 1 \
  samples/draw-group.hwp samples/eq-01.hwp
```

sandbox 내부 실행 결과:

| 파일 | 결과 |
|------|------|
| `draw-group.hwp` | readiness timeout, `navigation=pending`, `resourceRequests=0`, `documentRequests=0` |
| `eq-01.hwp` | readiness timeout, `navigation=pending`, `resourceRequests=0`, `documentRequests=0` |

sandbox 밖 권한 상승 재실행:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task121-stage1-baseline-escalated --page 1 \
  samples/draw-group.hwp samples/eq-01.hwp
```

결과:

| 파일 | 결과 |
|------|------|
| `draw-group.hwp` | readiness timeout, `page canvas not found for page 1`, `status=웹폰트 로딩 중...` |
| `eq-01.hwp` | readiness timeout, `page canvas not found for page 1`, `status=웹폰트 로딩 중...` |

산출물:

```text
build.noindex/task121-stage1-baseline/
build.noindex/task121-stage1-baseline-escalated/
```

해석:

- 이번 target sample에서는 `rhwp-studio` reference PNG가 생성되지 않아 `ChangedPercent`, `MeanRGBDelta` 같은 visual diff metric을 얻지 못했다.
- 권한 상승 후에는 resource request가 발생했으므로 단순 sandbox extension 문제만은 아니며, bundled Studio page init이 `웹폰트 로딩 중...` 상태에서 멈춘다.
- `./scripts/verify-rhwp-studio-assets.sh`는 통과했고 bundled font 파일은 존재한다.
- 이 실패는 Swift native renderer의 RawSvg 구현 결함으로 해석하지 않고, Stage 2에서 target fixture와 reference capture 방법을 다시 정해야 할 harness readiness 이슈로 남긴다.

## Stage 1 결론

1. Swift `RenderNodeType`에는 RawSvg case가 없으므로, 실제 RawSvg node가 내려오면 현재 decoder는 이를 `.unknown`으로 처리할 가능성이 높다.
2. `draw-group.hwp`는 현재 upstream render tree에서 17개 Image node로 내려오며 RawSvg fixture가 아니다.
3. `eq-01.hwp`는 3개 Equation node를 포함하지만 RawSvg fixture가 아니다.
4. repository sample page 1 scan의 생성 JSON 165개에서도 RawSvg/OLE/chart key를 찾지 못했다.
5. target visual diff baseline은 Studio readiness timeout으로 metric을 만들지 못했다. render-debug baseline은 정상 생성됐다.

## Stage 2 Handoff

Stage 2에서는 구현 전 다음을 먼저 결정해야 한다.

1. RawSvg payload shape를 어디서 확보할지 정한다.
   - 실제 OLE/chart/RawSvg fixture를 작업지시자가 제공할 수 있는지 확인
   - upstream `rhwp v0.7.13` serde shape를 조사해 모델을 설계할지 결정
2. target visual diff harness가 `웹폰트 로딩 중...`에서 멈추는 문제를 Stage 2/4 검증 범위에 포함할지 결정한다.
3. RawSvg 양성 fixture가 없을 때 이번 PR을 decoder/fallback scaffold로 진행할지, fixture 확보 전까지 구현을 보류할지 결정한다.
4. `RhwpCoreBridge`는 AppKit/WebKit 직접 의존 금지이므로 SVG rasterize가 필요할 경우 Shared/AppKit 경계 또는 placeholder fallback을 우선 검토한다.

## 검증

실행한 명령:

```bash
./scripts/render-debug-compare.sh build.noindex/task121-stage1-render-debug --page 1 \
  samples/draw-group.hwp samples/eq-01.hwp

./scripts/preview-visual-diff-harness.sh build.noindex/task121-stage1-baseline --page 1 \
  samples/draw-group.hwp samples/eq-01.hwp

./scripts/preview-visual-diff-harness.sh build.noindex/task121-stage1-baseline-escalated --page 1 \
  samples/draw-group.hwp samples/eq-01.hwp

./scripts/render-debug-compare.sh build.noindex/task121-stage1-sample-scan --page 1 \
  $(find samples -type f \( -name '*.hwp' -o -name '*.hwpx' \) -print)

./scripts/verify-rhwp-studio-assets.sh

git diff --check
```

최종 결과:

- `render-debug-compare` target baseline: OK
- target visual diff harness: 실패, readiness timeout
- repository sample scan: 일부 실패, 생성된 165개 JSON에서 RawSvg hit 없음
- `verify-rhwp-studio-assets.sh`: OK
- `git diff --check`: OK
