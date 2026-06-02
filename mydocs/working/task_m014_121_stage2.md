# Task M014 #121 Stage 2 완료보고서

## 개요

Stage 2는 RawSvg 양성 fixture가 없는 상태에서 구현을 바로 시작하지 않고, upstream `rhwp v0.7.13`의 RawSvg payload contract와 Swift/CoreGraphics fallback 정책을 고정하는 단계다. 소스 코드는 변경하지 않았고, 로컬 Cargo git checkout에 있는 resolved core source를 기준으로 조사했다.

## 기준

| 항목 | 값 |
|------|----|
| 이슈 | #121 Swift native renderer RawSvg/OLE·차트 리소스 렌더링 보강 |
| 브랜치 | `local/task121` |
| 기준 브랜치 | `origin/devel` `1b767bd` |
| core/studio 기준 | `edwardkim/rhwp v0.7.13`, `b3e16ef212af81ef37d973ddb86d6816d3804642` |
| Stage 1 보고서 | `mydocs/working/task_m014_121_stage1.md` |
| 구현계획서 | `mydocs/plans/task_m014_121_impl.md` |

## Stage 1 입력 재확인

Stage 1에서 target sample과 repository sample page 1 scan을 수행했지만 RawSvg 양성 JSON은 확보하지 못했다.

| 범위 | 결과 |
|------|------|
| `samples/draw-group.hwp` page 1 | `Image` 17개, RawSvg 없음 |
| `samples/eq-01.hwp` page 1 | `Equation` 3개, RawSvg 없음 |
| repository sample scan 생성 JSON 165개 | RawSvg/OLE/chart key hit 없음 |
| visual diff harness | `웹폰트 로딩 중...` readiness timeout으로 metric 없음 |

따라서 Stage 2의 판단은 실제 fixture 실측이 아니라 upstream source contract 기반이다. visual diff harness 재시도는 RawSvg positive 입력이 없는 상태에서는 metric을 만들어도 #121 구현 여부를 판정할 수 없으므로 Stage 4로 미룬다.

## Upstream RawSvg contract

### Render tree node shape

`src/renderer/render_tree.rs` 기준 `RenderNodeType`에는 다음 variant가 있다.

```rust
RawSvg(RawSvgNode)
```

`RawSvgNode`는 단일 필드 모델이다.

```rust
pub struct RawSvgNode {
    pub svg: String,
}
```

Swift `RenderTree.swift`가 소비하는 PageRenderTree JSON은 serde 기본 externally tagged enum이므로, 예상 JSON shape는 다음과 같다.

```json
{
  "node_type": {
    "RawSvg": {
      "svg": "<image x=\"...\" y=\"...\" width=\"...\" height=\"...\" href=\"data:image/png;base64,...\"/>"
    }
  },
  "bbox": {
    "x": 10.0,
    "y": 20.0,
    "width": 100.0,
    "height": 50.0
  }
}
```

Stage 3의 Swift model은 이 shape만 우선 대상으로 삼는다.

### PaintOp JSON shape

`src/paint/paint_op.rs`와 `src/paint/json.rs` 기준 PageLayerTree/paint op 경로의 RawSvg는 별도 shape다.

```json
{
  "type": "rawSvg",
  "bbox": { "x": 10.0, "y": 20.0, "width": 100.0, "height": 50.0 },
  "svg": "<rect .../>"
}
```

현재 macOS bridge의 주 경로는 `RhwpDocument.renderPageTreeJSON(at:)`가 반환하는 PageRenderTree다. Stage 3에서는 PaintOp/PageLayerTree parser를 추가하지 않는다. PageLayerTree 전환이나 full paint op replay가 필요해지는 시점에 별도 task로 다루는 편이 안전하다.

## RawSvg 생성 경로

upstream `src/renderer/layout/shape_layout.rs`에서 RawSvg는 OLE 중심으로 생성된다.

| 경로 | payload 형태 | 비고 |
|------|--------------|------|
| HWPX 직접 `ooxml_chart` | OOXML 차트가 만든 복합 SVG fragment | `<g class="hwp-ooxml-chart">...` 계열 |
| OLE container 내부 OOXML chart | OOXML 차트가 만든 복합 SVG fragment | 위와 동일 |
| OLE container EMF preview | EMF 변환기가 만든 복합 SVG fragment | `<g transform="matrix(...)">...` 안에 rect/path/text 등 |
| OLE native image | 단일 `<image ... data:.../>` fragment | BMP는 upstream에서 PNG 재인코딩 후 data URL로 들어간다 |

`src/renderer/svg_fragment.rs`의 설명에 따르면 RawSvg fragment는 페이지 절대 좌표계를 사용한다. WebCanvas 경로는 복합 SVG를 `<svg width height viewBox="bbox">...</svg>`로 감싼 뒤 bbox 위치에 image로 draw한다. Swift Stage 3에서는 복합 SVG 직접 래스터라이즈를 구현하지 않지만, 향후 실제 래스터라이저를 붙일 때도 bbox 기반 viewBox 정책을 유지해야 한다.

## Swift native renderer 현재 경계

현재 `Sources/RhwpCoreBridge/RenderTree.swift`에는 `RawSvg` case가 없다. unknown struct variant는 `.unknown`으로 흡수된다.

`Sources/RhwpCoreBridge/CGTreeRenderer.swift`는 `CoreGraphics`, `CoreText`, `Foundation`, `ImageIO` 기반이며 AppKit/UIKit/WebKit를 import하지 않는다. 이 경계는 `Sources/RhwpCoreBridge`에 AppKit/UIKit 직접 의존 금지 규칙과 맞다.

기존 equation renderer는 equation 전용 SVG subset parser를 갖지만, RawSvg는 OLE/차트/EMF까지 포함하는 범용 SVG fragment다. equation parser에 RawSvg를 섞으면 지원 범위와 보안 경계가 불명확해지므로 재사용하지 않는다.

## Stage 3 구현 정책

### 지원할 payload

Stage 3에서는 다음 payload만 실제 이미지로 표시한다.

| 유형 | 판정 | 처리 |
|------|------|------|
| 단일 `<image ... xlink:href="data:..."/>` | 지원 | base64 data URL을 디코드하고 기존 `decodeImage`/`drawImage` 계열로 bbox에 그린다 |
| 단일 `<image ... href="data:..."/>` | 지원 | `xlink:href`가 없을 때만 `href` 사용 |
| PNG/JPEG/GIF 등 ImageIO가 디코딩 가능한 data image | 지원 | 기존 image pipeline과 같은 bbox/clip 기준 적용 |
| BMP data image | 조건부 | upstream native image 경로는 BMP를 PNG로 재인코딩하므로 보통 PNG로 들어온다. 직접 BMP가 들어오면 `decodeImage` 성공 여부에 맡기고 실패 시 fallback |

내부 `<image>`의 `x`, `y`, `width`, `height`는 draw 위치로 사용하지 않는다. upstream WebCanvas도 data URL만 추출한 뒤 `node.bbox`에 그리므로, Swift도 `node.bbox`를 단일 배치 기준으로 둔다.

### fallback할 payload

다음 payload는 Stage 3에서 직접 렌더링하지 않고 RawSvg 전용 placeholder로 표시한다.

| 유형 | 이유 |
|------|------|
| OOXML chart 복합 SVG | CoreGraphics/ImageIO만으로 안전하고 예측 가능한 SVG rasterize를 보장하기 어렵다 |
| EMF 변환 복합 SVG | path/text/transform/filter 등 SVG subset 범위가 넓다 |
| `<svg>...</svg>` full document | 외부 resource/script/style 가능성을 포함하므로 bridge 내부에서 직접 로드하지 않는다 |
| 외부 `file:`, `http:`, `https:` href | 외부 리소스 로딩 금지 |
| 비-base64 data URL | upstream helper도 비-base64 data URL은 지원하지 않는다 |
| malformed XML, 중첩 image, 복수 element image fragment | 단일 data image 판정 실패 |
| 크기/좌표가 비정상인 bbox | draw 생략 또는 fallback |

fallback은 upstream `Placeholder` node를 Swift에 구현한다는 의미가 아니다. #121에서는 RawSvg 렌더 실패 시 그리는 RawSvg 전용 fallback만 추가하고, upstream `RenderNodeType::Placeholder`/FormObject 정적 프리뷰는 #110 범위와 섞지 않는다.

### 보안·리소스 guard

upstream Skia path는 `MAX_SVG_FRAGMENT_BYTES = 4 MiB`, `MAX_SVG_RASTER_PIXELS = 67,108,864`를 두고, `resources_dir = None`, `resolve_string = None`으로 외부 href 로딩을 막는다. Swift Stage 3도 같은 방향으로 축소 적용한다.

| guard | Stage 3 정책 |
|-------|--------------|
| RawSvg string size | 4 MiB 초과 시 fallback |
| bbox | finite, width/height > 0인 경우만 draw/fallback |
| bbox raster pixels | `ceil(width) * ceil(height)`가 67,108,864 초과면 fallback 또는 draw 생략 |
| XML parse | `XMLParser` 사용, `shouldResolveExternalEntities = false` |
| image href | `xlink:href` 우선, 없으면 `href`; `data:` scheme만 허용 |
| data URL | `;base64`만 허용 |
| external resource | 어떤 경우에도 로드하지 않음 |

문자열 검색/정규식으로 payload를 해석하지 않는다. 단일 image 판정은 XMLParser 기반의 좁은 parser로 구현한다.

### placeholder 시각 정책

RawSvg fallback placeholder는 bbox 안에서만 그린다.

| 속성 | 정책 |
|------|------|
| fill | 옅은 회색 계열 반투명 fill |
| stroke | 회색 dashed stroke |
| label | `SVG` |
| clipping | bbox clip 적용 |
| text | bbox가 충분히 클 때만 중앙 표시. 작은 bbox에서는 stroke/fill만 표시 |

목표는 빈 영역이나 crash 대신 “여기에 지원되지 않은 SVG 리소스가 있음”을 보이는 것이다. upstream Skia도 RawSvg rasterize 실패 시 `"svg"` placeholder로 떨어진다.

## Visual diff harness 판단

지금 visual diff harness를 다시 시도해 metric을 만드는 것보다 RawSvg payload shape case를 확보하는 쪽이 우선이다.

이유:

1. Stage 1 target sample과 repository sample scan에서 RawSvg node가 없었다.
2. RawSvg positive 입력이 없으면 visual diff metric은 harness readiness나 일반 renderer 회귀만 측정하고, #121의 성공 여부를 판정하지 못한다.
3. Stage 1 harness는 `웹폰트 로딩 중...` readiness timeout이 있어 현재 기준으로 reference PNG 생성 자체가 불안정하다.
4. 구현 전 가장 큰 불확실성은 Swift decoder가 받아야 할 JSON shape와 bridge 내부에서 허용할 payload 범위다. 이 부분은 upstream source로 확정 가능하다.

따라서 Stage 3은 synthetic JSON/decode/render smoke로 RawSvg case를 강제 주입해 최소 동작을 확인하고, Stage 4에서 harness를 다시 시도한다. 실제 OLE/chart fixture가 추가되면 Stage 4 metric의 판정력이 올라간다.

## Stage 3 Handoff

승인되면 Stage 3에서 다음 범위만 소스 변경한다.

1. `Sources/RhwpCoreBridge/RenderTree.swift`
   - `case rawSvg(RawSvgNode)` 추가
   - `RawSvgNode { svg: String }` 추가
   - externally tagged `"RawSvg"` decode를 `.unknown` 전에 추가

2. `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
   - `.rawSvg` match arm 추가
   - RawSvg string/bbox guard 추가
   - XMLParser 기반 단일 data image parser 추가
   - data image decode 성공 시 기존 image drawing helper를 재사용
   - 복합 SVG/실패 케이스는 RawSvg 전용 placeholder로 fallback

3. 검증
   - synthetic RawSvg JSON 또는 helper-level smoke로 decoder/fallback/data image path 확인
   - 기존 target sample `draw-group.hwp`, `eq-01.hwp` render-debug smoke 재실행
   - `xcodebuild` Debug build
   - `git diff --check`
   - extension registration hygiene check

Stage 3에서도 `RhwpCoreBridge`에 AppKit/WebKit 의존을 추가하지 않는다. 복합 SVG를 실제로 래스터라이즈하는 기능은 별도 renderer backend 또는 Shared/AppKit 경계 설계가 필요할 때 후속 task로 분리한다.

## 검증

실행한 확인:

```bash
rg -n "RawSvg|raw_svg|rawSvg|PaintOp::RawSvg|RenderNodeType::RawSvg|struct RawSvg|enum RenderNodeType|enum PaintOp" \
  /Users/melee/.cargo/git/checkouts /Users/melee/.cargo/registry/src

nl -ba /Users/melee/.cargo/git/checkouts/rhwp-6f8f299952213fc0/b3e16ef/src/renderer/render_tree.rs
nl -ba /Users/melee/.cargo/git/checkouts/rhwp-6f8f299952213fc0/b3e16ef/src/paint/paint_op.rs
nl -ba /Users/melee/.cargo/git/checkouts/rhwp-6f8f299952213fc0/b3e16ef/src/paint/json.rs
nl -ba /Users/melee/.cargo/git/checkouts/rhwp-6f8f299952213fc0/b3e16ef/src/renderer/svg_fragment.rs
nl -ba /Users/melee/.cargo/git/checkouts/rhwp-6f8f299952213fc0/b3e16ef/src/renderer/web_canvas.rs
nl -ba /Users/melee/.cargo/git/checkouts/rhwp-6f8f299952213fc0/b3e16ef/src/renderer/layout/shape_layout.rs
nl -ba /Users/melee/.cargo/git/checkouts/rhwp-6f8f299952213fc0/b3e16ef/src/renderer/skia/image_conv.rs
nl -ba /Users/melee/.cargo/git/checkouts/rhwp-6f8f299952213fc0/b3e16ef/src/renderer/skia/renderer.rs

rg -n "RawSvg|rawSvg|Placeholder|RenderNodeType|CGImage|XMLParser|AppKit|UIKit|WKWebView" \
  Sources/RhwpCoreBridge Sources/Shared scripts mydocs
```

최종 Stage 2 검증:

```bash
git diff --check
```
