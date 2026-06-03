# Task M014 #110 구현계획서

## 기준

- 이슈: #110
- 브랜치: `local/task110`
- 기준 브랜치: `origin/devel` `fcdc05d`
- 수행계획서 커밋: `0cea8e7`
- core/studio 기준: rhwp `v0.7.13`, resolved commit `b3e16ef212af81ef37d973ddb86d6816d3804642`

## 구현 목표

Swift/CoreGraphics native renderer가 upstream render tree의 `Placeholder`와 `FormObject` 계열 노드를 정적 프리뷰로 표시하게 한다. 구현은 Quick Look preview, Finder thumbnail, PDF/CoreGraphics fallback이 공유하는 `CGTreeRenderer` 경로를 우선 대상으로 삼고, 실제 form interaction이나 mutation은 범위에서 제외한다.

## 사전 확인 결과

수행계획서 승인 직후 소스 변경 없이 현재 모델과 renderer 경로를 확인했다.

- `RenderTree.swift`의 `RenderNodeType`에는 `formObject`, `placeholder`, `rawSvg` case가 존재한다.
- `RenderNodeType.init(from:)`는 `FormObject`, `Placeholder`, `RawSvg`를 `.unknown` 전에 디코딩한다.
- `FormObjectNode`는 현재 `form_type`, `caption`, `text`만 디코딩한다. 이슈가 언급한 `fore_color`, `back_color`, `value`, `enabled`, `name` 등 정적 표시용 필드는 아직 없다.
- `PlaceholderNode`는 #121 결과로 `fill_color`, `stroke_color`, `label`을 디코딩한다.
- `CGTreeRenderer.renderNode`의 `.formObject` 분기는 현재 no-op이다.
- `CGTreeRenderer.renderPlaceholder`는 bbox clip, fill, dashed stroke, centered label을 이미 그린다.
- Quick Look, Thumbnail, PDF fallback은 shared CoreGraphics renderer 결과를 사용하므로 `CGTreeRenderer`에 FormObject 정적 preview를 붙이면 세 경로에서 같은 policy를 검증할 수 있다.

## Stage 구성

| Stage | 목표 | 산출물 |
|-------|------|--------|
| Stage 1 | Placeholder/FormObject current path inventory와 baseline 측정 | `mydocs/working/task_m014_110_stage1.md` |
| Stage 2 | FormObject payload 모델과 static preview 정책 설계 | `mydocs/working/task_m014_110_stage2.md` |
| Stage 3 | RenderTree 디코딩과 CoreGraphics FormObject 렌더링 구현 | `RenderTree.swift`, `CGTreeRenderer.swift` 중심 변경 |
| Stage 4 | visual diff, renderer smoke, shared path 회귀 검증 | `mydocs/working/task_m014_110_stage4.md` |
| Stage 5 | 최종 보고와 PR 게시 준비 | `mydocs/report/task_m014_110_report.md` |

## Stage 1 세부 계획

소스 코드는 변경하지 않고 현재 입력, 누락 지점, 기준 수치를 고정한다.

- `samples/form-01.hwp`, `samples/hwpx/form-002.hwpx`의 render tree/debug output을 생성한다.
- render tree output에서 `FormObject`, `Placeholder`, `form_type`, `caption`, `text`, `value`, `name`, `fore_color`, `back_color`, `enabled` key 존재 여부를 확인한다.
- target sample의 FormObject/Placeholder node count와 bbox 분포를 기록한다.
- `preview-visual-diff-harness`로 target sample baseline을 남긴다.
- `render-debug-compare`로 native PNG, core SVG, node summary를 남긴다.
- #121 Placeholder 구현이 target sample에 실제 영향을 주는지, FormObject no-op이 어떤 영역을 비우는지 분리한다.

검증:

```bash
./scripts/render-debug-compare.sh build.noindex/task110-stage1-render-debug --page 1 \
  samples/form-01.hwp samples/hwpx/form-002.hwpx

./scripts/preview-visual-diff-harness.sh build.noindex/task110-stage1-baseline --page 1 \
  samples/form-01.hwp samples/hwpx/form-002.hwpx

git diff --check
```

산출물:

- `build.noindex/task110-stage1-render-debug/`
- `build.noindex/task110-stage1-baseline/`
- `mydocs/working/task_m014_110_stage1.md`

## Stage 2 세부 계획

Stage 1 결과를 바탕으로 구현 전 정책을 문서로 고정한다.

- 실제 JSON payload shape에 맞춰 `FormObjectNode` 추가 필드를 정한다.
- `caption`, `text`, `value`, `name`의 label 우선순위를 정한다.
- `fore_color`, `back_color`, `enabled`의 기본값과 fallback 색상 정책을 정한다.
- button, checkbox, radio, edit/text input, combo/list type별 정적 preview 표현을 정한다.
- checkbox/radio 선택 상태를 `value`에서 해석할 수 있는 경우와 불명확한 경우를 분리한다.
- unsupported form type fallback의 label, dashed/solid stroke, Placeholder fallback과의 시각 구분 기준을 정한다.
- `RhwpCoreBridge`에 AppKit/UIKit/WebKit 직접 의존을 넣지 않는 helper 경계를 확인한다.

검증:

```bash
git diff --check
```

산출물:

- `mydocs/working/task_m014_110_stage2.md`

## Stage 3 세부 계획

승인된 정책에 따라 최소 구현을 적용한다.

- `RenderTree.swift`의 `FormObjectNode`에 정적 preview용 optional field를 추가한다.
- unknown/missing field가 decode 실패로 이어지지 않도록 optional decode와 기본값을 사용한다.
- `CGTreeRenderer.renderNode`의 `.formObject` no-op을 `renderFormObject` 호출로 교체한다.
- `renderFormObject`는 `shouldRenderFlowContent`, bbox validity, clipping, color conversion, label fitting helper를 기존 규칙에 맞춘다.
- button, checkbox, radio, input 계열 preview helper를 추가한다.
- unsupported type은 bbox 안에 `FORM` 또는 type/name label이 있는 fallback으로 그린다.
- 기존 Placeholder, RawSvg, Image, Equation 렌더링 범위는 의도적으로 넓히지 않는다.

검증:

```bash
./scripts/render-debug-compare.sh build.noindex/task110-stage3-render-debug --page 1 \
  samples/form-01.hwp samples/hwpx/form-002.hwpx

xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug \
  -derivedDataPath build.noindex/DerivedData-task110 CODE_SIGNING_ALLOWED=NO build

git diff --check
./scripts/check-extension-registration-hygiene.sh --check-only
```

## Stage 4 세부 계획

구현 후 target sample과 공통 sample set을 재측정한다.

- Stage 1 target sample baseline을 같은 조건으로 재측정한다.
- `render-debug-compare`로 FormObject node count, native non-white pixel, fallback 표시 여부를 확인한다.
- M014 공통 visual diff sample set에서 #116, #122, #121 관련 회귀를 확인한다.
- Quick Look/Thumbnail/PDF CoreGraphics path가 같은 renderer 결과를 쓰는지 smoke한다.
- WebKit readiness timeout, Quick Look 등록 상태, extension hygiene 같은 환경 요인은 renderer 회귀와 분리해 보고한다.

검증:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task110-stage4-target --page 1 \
  samples/form-01.hwp samples/hwpx/form-002.hwpx

./scripts/preview-visual-diff-harness.sh build.noindex/task110-stage4-regression --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx \
  samples/복학원서.hwp samples/pic-crop-01.hwp \
  samples/tac-img-02.hwp samples/tac-img-02.hwpx \
  samples/draw-group.hwp samples/eq-01.hwp

./scripts/render-debug-compare.sh build.noindex/task110-stage4-render-debug --page 1 \
  samples/form-01.hwp samples/hwpx/form-002.hwpx

git diff --check
./scripts/check-extension-registration-hygiene.sh --check-only
```

산출물:

- `mydocs/working/task_m014_110_stage4.md`

## Stage 5 세부 계획

최종 결과와 handoff를 정리하고 PR 게시 준비 상태로 만든다.

- 지원한 FormObject type과 fallback으로 남긴 type을 표로 정리한다.
- Placeholder 기존 구현의 검증 결과와 보강 여부를 분리해 기록한다.
- visual diff 전후 수치와 native PNG 시각 확인 결과를 기록한다.
- interactive form 입력, form query/edit API, mutation 제외 사항을 최종 보고서에 명시한다.
- 오늘할일을 완료 상태로 갱신한다.
- 최종 검증 명령과 `git status`를 확인한다.

검증:

```bash
git status --short
git log --oneline -5
git diff --check
```

산출물:

- `mydocs/report/task_m014_110_report.md`
- `mydocs/orders/20260603.md` 완료 상태 갱신

## 승인 필요 사항

1. Stage 1은 소스 변경 없이 Placeholder/FormObject 입력 존재 여부, FormObject no-op 영향, target sample baseline을 확인하는 단계로 진행한다.
2. Stage 2는 Stage 1에서 확인한 payload shape에 맞춰 Swift 모델과 type별 static preview/fallback 정책을 문서로 고정한다.
3. Stage 3 구현은 Swift/CoreGraphics fallback renderer에 한정하며, upstream `rhwp`, Skia 기본 경로, interactive form 입력, form mutation은 다루지 않는다.
4. #121에서 이미 들어온 Placeholder 기본 구현은 유지하고, 이번 작업에서는 target sample 검증과 필요한 보강만 수행한다.
