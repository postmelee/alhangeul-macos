# Task M014 #121 구현계획서

## 기준

- 이슈: #121
- 브랜치: `local/task121`
- 기준 브랜치: `origin/devel` `1b767bd`
- 수행계획서 커밋: `c8263e2`
- core/studio 기준: rhwp `v0.7.13`, resolved commit `b3e16ef212af81ef37d973ddb86d6816d3804642`

## 구현 목표

Swift/CoreGraphics native renderer에서 upstream render tree의 `RawSvg` 계열 정적 리소스를 식별하고, 지원 가능한 payload는 bbox 안에 표시하며, 지원할 수 없는 payload는 빈 화면이나 crash 대신 명확한 fallback으로 남긴다. 구현은 Quick Look preview, Finder thumbnail, PDF/CoreGraphics fallback이 공유하는 `CGTreeRenderer` 경로를 우선 대상으로 삼는다.

## 사전 확인 결과

수행계획서 승인 직후 소스 변경 없이 현재 모델과 renderer 경로를 확인했다.

- `Sources/RhwpCoreBridge/RenderTree.swift`의 `RenderNodeType`에는 `RawSvg` case가 없다.
- `RenderNodeType.init(from:)`는 `Page`, `Image`, `Equation`, `FormObject` 등을 순서대로 디코딩하고, 매칭되지 않는 node type은 `.unknown`으로 둔다.
- `ImageNode`는 #122에서 보강한 `fill_mode`, `original_size`, `crop`, `effect`, `brightness`, `contrast`, `text_wrap`를 이미 디코딩한다.
- `EquationNode`는 `svg_content`를 갖지만, `CGTreeRenderer.renderEquation`은 equation 전용 SVG subset parser와 draw path를 사용한다. RawSvg/OLE/chart 범용 SVG payload를 여기에 섞지 않는 편이 안전하다.
- `CGTreeRenderer.renderNode`에는 `.formObject`가 아직 no-op이고, RawSvg용 분기가 없다.
- `HwpPageImageRenderer`와 `HwpPreviewPDFRenderer`의 CoreGraphics path는 `CGTreeRenderer` 결과를 공유하므로, RawSvg draw/fallback은 shared renderer에 붙이면 Quick Look/Thumbnail/PDF smoke에서 같이 확인할 수 있다.

## Stage 구성

| Stage | 목표 | 산출물 |
|-------|------|--------|
| Stage 1 | RawSvg current path inventory와 baseline 측정 | `mydocs/working/task_m014_121_stage1.md` |
| Stage 2 | RawSvg payload 모델과 fallback/rendering 정책 설계 | `mydocs/working/task_m014_121_stage2.md` |
| Stage 3 | RenderTree 디코딩과 CoreGraphics fallback 구현 | `RenderTree.swift`, `CGTreeRenderer.swift` 중심 변경 |
| Stage 4 | visual diff, renderer smoke, shared path 회귀 검증 | `mydocs/working/task_m014_121_stage4.md` |
| Stage 5 | 최종 보고와 PR 게시 준비 | `mydocs/report/task_m014_121_report.md` |

## Stage 1 세부 계획

소스 코드는 변경하지 않고 현재 입력과 누락 지점을 고정한다.

- `samples/draw-group.hwp`, `samples/eq-01.hwp`의 render tree JSON을 생성한다.
- render tree JSON에서 `RawSvg`, `rawSvg`, `raw_svg`, OLE/chart 관련 key 존재 여부를 확인한다.
- target sample에 RawSvg 양성 fixture가 부족하면 repository sample 전체를 1차 scan하고, 범위 안에서 확인 가능한 fixture 후보를 기록한다.
- `preview-visual-diff-harness`로 target sample baseline을 남긴다.
- `render-debug-compare`로 native PNG, core SVG, node summary를 남긴다.
- 현재 Swift decoder에서 RawSvg가 `.unknown`으로 흡수되는지, 아니면 upstream sample이 아직 RawSvg를 만들지 않는지 분리한다.

검증:

```bash
./scripts/render-debug-compare.sh build.noindex/task121-stage1-render-debug --page 1 \
  samples/draw-group.hwp samples/eq-01.hwp

./scripts/preview-visual-diff-harness.sh build.noindex/task121-stage1-baseline --page 1 \
  samples/draw-group.hwp samples/eq-01.hwp

git diff --check
```

산출물:

- `build.noindex/task121-stage1-render-debug/`
- `build.noindex/task121-stage1-baseline/`
- `mydocs/working/task_m014_121_stage1.md`

## Stage 2 세부 계획

Stage 1 결과를 바탕으로 구현 전 정책을 문서로 고정한다.

- 실제 JSON payload shape에 맞춰 `RawSvgNode` 필드를 정의한다.
- data URL image, inline SVG string, SVG fragment, resource reference, unknown payload를 분리한다.
- `RhwpCoreBridge`에 AppKit/WebKit 직접 의존을 넣지 않는 rasterize/fallback 경계를 결정한다.
- 지원할 payload와 placeholder fallback payload를 구분한다.
- fallback placeholder의 시각 표현, 색상, label, bbox clipping 기준을 정한다.
- diagnostics는 기존 renderer metadata에 바로 확장할지, Stage 4 보고서의 render-debug 관찰값으로만 남길지 결정한다.

검증:

```bash
git diff --check
```

산출물:

- `mydocs/working/task_m014_121_stage2.md`

## Stage 3 세부 계획

승인된 정책에 따라 최소 구현을 적용한다.

- `RenderTree.swift`에 `RawSvg` case와 `RawSvgNode` 모델을 추가한다.
- `RenderNodeType.init(from:)`가 RawSvg를 `.unknown` 전에 디코딩하도록 한다.
- `CGTreeRenderer.renderNode`에 `.rawSvg` 분기를 추가한다.
- 지원 가능한 raster image data URL payload는 기존 image draw helper와 최대한 같은 bbox/clip 규칙으로 그린다.
- SVG fragment를 직접 rasterize할 수 없는 경우 명확한 static fallback을 그린다.
- fallback draw helper는 RawSvg 전용으로 유지해 #110 Placeholder/FormObject 범위와 섞이지 않게 한다.
- 기존 `ImageNode`, `EquationNode`, `.formObject` 렌더 범위는 넓히지 않는다.

검증:

```bash
./scripts/render-debug-compare.sh build.noindex/task121-stage3-render-debug --page 1 \
  samples/draw-group.hwp samples/eq-01.hwp

xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug \
  -derivedDataPath build.noindex/DerivedData-task121 CODE_SIGNING_ALLOWED=NO build

git diff --check
./scripts/check-extension-registration-hygiene.sh --check-only
```

## Stage 4 세부 계획

구현 후 target sample과 공통 sample set을 재측정한다.

- Stage 1 target sample baseline을 같은 조건으로 재측정한다.
- M014 공통 visual diff sample set에서 회귀를 확인한다.
- `render-debug-compare`로 RawSvg node count, native non-white pixel, fallback 표시 여부를 확인한다.
- Quick Look/Thumbnail/PDF CoreGraphics path가 같은 renderer 결과를 쓰는지 smoke한다.
- WebKit readiness timeout이나 `qlmanage` rasterize 실패처럼 환경 요인이 있으면 보고서에 분리해 기록한다.

검증:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task121-stage4-target --page 1 \
  samples/draw-group.hwp samples/eq-01.hwp

./scripts/preview-visual-diff-harness.sh build.noindex/task121-stage4-regression --page 1 \
  samples/basic/request.hwp samples/복학원서.hwp samples/pic-crop-01.hwp \
  samples/form-01.hwp samples/hwpx/form-002.hwpx samples/hwpx/hwpx-01.hwpx

./scripts/render-debug-compare.sh build.noindex/task121-stage4-render-debug --page 1 \
  samples/draw-group.hwp samples/eq-01.hwp

git diff --check
./scripts/check-extension-registration-hygiene.sh --check-only
```

산출물:

- `mydocs/working/task_m014_121_stage4.md`

## Stage 5 세부 계획

최종 결과와 handoff를 정리하고 PR 게시 준비 상태로 만든다.

- 지원한 RawSvg payload 유형과 fallback으로 남긴 유형을 표로 정리한다.
- visual diff 전후 수치와 native PNG 시각 확인 결과를 기록한다.
- #110 Placeholder/FormObject, #124 HostApp viewer path에 넘길 사항을 분리한다.
- 오늘할일을 완료 상태로 갱신한다.
- 최종 검증 명령과 `git status`를 확인한다.

검증:

```bash
git status --short
git log --oneline -5
git diff --check
```

산출물:

- `mydocs/report/task_m014_121_report.md`
- `mydocs/orders/20260602.md` 완료 상태 갱신

## 승인 필요 사항

1. Stage 1은 소스 변경 없이 RawSvg 입력 존재 여부, decoder 누락 지점, target sample baseline을 확인하는 단계로 진행한다.
2. Stage 2는 Stage 1에서 확인한 payload shape에 맞춰 Swift 모델과 fallback 정책을 문서로 고정한다.
3. Stage 3 구현은 Swift/CoreGraphics fallback renderer에 한정하며, upstream `rhwp`, Skia 기본 경로, OLE/chart editing, Placeholder/FormObject 정적 프리뷰는 다루지 않는다.
