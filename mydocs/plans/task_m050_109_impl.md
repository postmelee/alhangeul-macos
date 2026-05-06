# Task M050 #109 구현 계획서

수행계획서: `mydocs/plans/task_m050_109.md`

각 단계 완료 후 `task-stage-report` 절차로 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #109 Swift native renderer 도형·텍스트 스타일 1차 parity 보강
- 마일스톤: M050 (`v0.5.0 Viewer 안정화`)
- 브랜치: `local/task109`
- 기준 통합 브랜치: `devel`
- 주 대상: `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- 보조 대상: `Sources/RhwpCoreBridge/RenderTree.swift`
- 필요 시 검증 보조: `scripts/render-debug-compare.sh`, `scripts/validate-stage3-render.sh`
- 공통 영향 경로: HostApp native viewer(`devel`), Quick Look preview, Thumbnail extension
- `devel-webview` 영향: HostApp WKWebView viewer에는 직접 영향 없음. 단, 별도 백포트 시 Quick Look/Thumbnail native bitmap 결과는 바뀔 수 있음.
- 목표: render tree가 이미 제공하는 도형·텍스트 style 필드를 Swift/CoreGraphics/CoreText renderer가 더 충실히 반영하고, 안전하게 구현하지 못하는 항목은 명시 fallback으로 정리한다.

## 구현 원칙

- 제품 기준 경로는 `rhwp_render_page_tree` + Swift `RenderTree` + `CGTreeRenderer`로 유지한다.
- `Sources/RhwpCoreBridge`에는 AppKit/UIKit/WebKit 직접 의존을 추가하지 않는다.
- `devel-webview`에는 이번 작업을 직접 반영하지 않는다. 백포트가 필요하면 별도 작업지시자 승인 후 Quick Look/Thumbnail 영향 범위만 분리한다.
- rhwp-studio `WebCanvasRenderer`를 reference로 삼되, DOM/Canvas 구현 구조를 Swift로 복제하지 않는다.
- render tree에 이미 있는 필드부터 사용한다. core 계약이 부족한 항목은 Swift 추정으로 과도하게 보정하지 않는다.
- 기존 #119 font fallback, #120 text advance/cluster drawing, #123 body/table clip 정책을 흔들지 않는다.
- 도형 style은 draw order, clip, transform 영향을 단계별로 확인한다.
- 텍스트 style은 CoreText 좌표계, baseline, underline/strike, cluster drawing과 충돌하지 않는 항목부터 적용한다.
- 생성 산출물인 PNG/SVG/JSON은 저장소에 커밋하지 않고, 단계 보고서에 출력 경로와 summary 핵심값을 기록한다.

## Stage 1. rhwp-studio 기준과 Swift style 처리 현황 조사

### 목표

- issue 범위 style 항목별 reference, render tree 필드, Swift 구현 상태, fallback 상태를 표로 정리한다.
- `devel`과 `devel-webview`의 실제 영향 경로를 다시 확인하고, 이번 작업에서 백포트를 제외하는 근거를 남긴다.
- Stage 2-5에서 구현할 항목과 보류할 항목의 1차 후보를 확정한다.

### 작업

- `RenderTree.swift`의 `ShapeStyle`, `LineStyle`, `PatternFillInfo`, `ShadowStyleInfo`, `PathCommand`, `TextStyle`, `TextRunNode` 필드를 정리한다.
- `CGTreeRenderer.swift`에서 이미 구현된 dash, pattern background fallback, text advance/cluster drawing, underline/strike 처리와 미사용 필드를 분리한다.
- rhwp-studio/core 기준에서 shadow, arrow, dash, pattern, arcTo, text shadow, rotation, vertical text, superscript/subscript, emphasis dot, tab leader가 어떤 출력으로 표현되는지 조사한다.
- `origin/devel...origin/devel-webview`의 viewer/renderer 차이를 확인해 HostApp viewer 직접 영향과 Quick Look/Thumbnail 백포트 영향을 구분한다.
- 기준 샘플과 추가 샘플 후보를 고른다. 샘플이 부족한 style은 이번 단계에서 무리하게 구현하지 않고 fallback 후보로 표시한다.

### 예상 변경 파일

- `mydocs/working/task_m050_109_stage1.md`

### 검증

```bash
git status --short --branch
rg -n "shadow|arrow|dash|pattern|ArcTo|rotation|is_vertical|superscript|subscript|emphasis|tab_leader|WebCanvasRenderer|render_overflow|draw" .
rg -n "struct TextStyle|struct ShapeStyle|struct LineStyle|enum PathCommand|renderTextRun|applyShapeStyleFill|applyDash|arcTo" Sources/RhwpCoreBridge
git diff --name-status origin/devel-webview...origin/devel -- Sources/RhwpCoreBridge Sources/Shared Sources/QLExtension Sources/ThumbnailExtension Sources/HostApp/Views/DocumentViewerView.swift
./scripts/render-debug-compare.sh /private/tmp/rhwp-task109-stage1-bokhak samples/복학원서.hwp
git diff --check
```

### 완료 기준

- style 항목별 구현/보류/fallback 후보가 Stage 1 보고서에 기록된다.
- `devel-webview` 배포 viewer 직접 영향 없음과 Quick Look/Thumbnail 백포트 영향 가능성이 문서화된다.
- Stage 2-5의 구현 대상이 확정된다.
- source code 변경 없이 기준 조사와 판단 근거만 정리된다.

### 커밋 메시지

```text
Task #109 Stage 1: style parity 기준 조사
```

## Stage 2. 도형 stroke/path style 보강

### 목표

- line/path 계열의 stroke 표현을 먼저 보강한다.
- dash normalization, line arrow, path arcTo를 좁은 helper로 구현하거나 안전한 fallback으로 남긴다.

### 작업

- `applyDash(_:)`가 받는 dash 이름과 rhwp-studio/core style 이름을 대조하고, 필요한 alias를 추가한다.
- `LineStyle.startArrow`, `endArrow`, arrow size를 CoreGraphics path로 그리는 helper를 추가한다.
- line arrow는 transform 적용 후 선 끝점 기준으로 그리되, 미지원 arrow style은 명시 fallback으로 남긴다.
- `PathCommand.arcTo`가 현재 직선 fallback으로 처리되는 부분을 조사하고, SVG elliptical arc 변환을 CoreGraphics cubic curve 또는 근사 segment로 구현 가능한지 판단한다.
- arcTo 구현이 불안정하면 특정 조건에서만 적용하고 나머지는 기존 line fallback을 유지한다.
- path의 `lineStyle`과 `ShapeStyle` stroke 적용 순서를 보존한다.

### 예상 변경 파일

- `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- 필요 시 `Sources/RhwpCoreBridge/RenderTree.swift`
- `mydocs/working/task_m050_109_stage2.md`

### 검증

```bash
git status --short --branch
git diff -- Sources/RhwpCoreBridge/CGTreeRenderer.swift Sources/RhwpCoreBridge/RenderTree.swift
./scripts/check-no-appkit.sh
./scripts/render-debug-compare.sh /private/tmp/rhwp-task109-stage2-bokhak samples/복학원서.hwp
./scripts/validate-stage3-render.sh /private/tmp/rhwp-task109-stage2-smoke samples/basic/BookReview.hwp samples/basic/KTX.hwp samples/basic/request.hwp samples/exam_kor.hwp
git diff --check
```

### 완료 기준

- stroke/path 관련 helper가 `CGTreeRenderer.swift` 안에 좁게 추가된다.
- dash, arrow, arcTo 중 구현한 항목과 fallback으로 남긴 항목이 보고서에 기록된다.
- AppKit/UIKit 직접 의존 금지 검증과 대표 render smoke가 통과한다.

### 커밋 메시지

```text
Task #109 Stage 2: 도형 stroke와 path style 보강
```

## Stage 3. 도형 fill/shadow/pattern style 보강

### 목표

- rectangle, ellipse, path의 fill 계열 표현과 shadow 처리를 보강한다.
- 기존 gradient, opacity, transform, clip 동작을 흔들지 않는다.

### 작업

- `ShapeStyle.shadow`와 `LineStyle.shadow`를 공통 shadow helper로 적용할 수 있는지 확인한다.
- shape fill/stroke 전에 shadow pass를 그리는 순서를 정하고, alpha와 offset을 `ShadowStyleInfo` 기준으로 반영한다.
- pattern fill은 현재 background color만 채우는 fallback을 기준으로 pattern type, pattern color를 사용한 1차 hatch/stripe 근사를 구현할 수 있는 범위만 적용한다.
- pattern 구현이 문서별로 과도하게 튀면 background fill fallback을 유지하고 지원 범위를 보고서에 제한한다.
- `ctx.setAlpha` 같은 graphics state 변경은 `saveGState`/`restoreGState` 경계 안에 가둔다.

### 예상 변경 파일

- `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- 필요 시 `Sources/RhwpCoreBridge/RenderTree.swift`
- `mydocs/working/task_m050_109_stage3.md`

### 검증

```bash
git status --short --branch
git diff -- Sources/RhwpCoreBridge/CGTreeRenderer.swift Sources/RhwpCoreBridge/RenderTree.swift
./scripts/check-no-appkit.sh
./scripts/render-debug-compare.sh /private/tmp/rhwp-task109-stage3-bokhak samples/복학원서.hwp
./scripts/validate-stage3-render.sh /private/tmp/rhwp-task109-stage3-smoke samples/basic/BookReview.hwp samples/basic/KTX.hwp samples/basic/request.hwp samples/exam_kor.hwp
git diff --check
```

### 완료 기준

- shadow/pattern/fill 관련 지원 항목과 fallback 항목이 코드와 단계 보고서에 일치한다.
- 기존 gradient, solid fill, stroke, transform 결과가 smoke 기준으로 회귀하지 않는다.
- graphics state 누수가 없도록 helper 경계가 좁게 유지된다.

### 커밋 메시지

```text
Task #109 Stage 3: 도형 fill과 shadow style 보강
```

## Stage 4. 텍스트 저위험 style 보강

### 목표

- baseline과 run transform을 크게 흔들지 않는 텍스트 style부터 보강한다.
- text shadow, superscript/subscript, emphasis dot, tab leader를 기존 text drawing helper와 연결한다.

### 작업

- `TextStyle.shadowType`, `shadowColor`, `shadowOffsetX`, `shadowOffsetY`를 사용해 shadow text pass를 추가한다.
- superscript/subscript는 font size와 baseline offset을 좁게 조정하되, bbox/cluster advance와 충돌하면 fallback으로 남긴다.
- emphasis dot은 run bbox와 baseline 기준으로 점 위치를 계산하는 helper를 추가한다.
- `TextStyle.tabLeaders`와 `TabLeaderInfo`를 기존 tab stop/cluster drawing 경로와 연결해 leader line/dot을 그릴 수 있는 범위를 적용한다.
- underline/strike/shade drawing 좌표가 새 pass와 어긋나지 않는지 확인한다.

### 예상 변경 파일

- `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- 필요 시 `Sources/RhwpCoreBridge/RenderTree.swift`
- `mydocs/working/task_m050_109_stage4.md`

### 검증

```bash
git status --short --branch
git diff -- Sources/RhwpCoreBridge/CGTreeRenderer.swift Sources/RhwpCoreBridge/RenderTree.swift
./scripts/check-no-appkit.sh
./scripts/render-debug-compare.sh /private/tmp/rhwp-task109-stage4-bokhak samples/복학원서.hwp
./scripts/render-debug-compare.sh /private/tmp/rhwp-task109-stage4-hongbo samples/20250130-hongbo.hwp
./scripts/validate-stage3-render.sh /private/tmp/rhwp-task109-stage4-smoke samples/basic/BookReview.hwp samples/basic/KTX.hwp samples/basic/request.hwp samples/exam_kor.hwp
git diff --check
```

### 완료 기준

- 저위험 텍스트 style의 지원/fallback 항목이 보고서에 기록된다.
- #120에서 보강한 text advance/cluster drawing 경로가 유지된다.
- underline/strike/shade 기본 동작이 smoke 기준으로 회귀하지 않는다.

### 커밋 메시지

```text
Task #109 Stage 4: 텍스트 기본 style 보강
```

## Stage 5. 텍스트 rotation/vertical text 처리 판단과 보강

### 목표

- `TextRunNode.rotation`과 `isVertical`을 기존 baseline/cluster drawing과 안전하게 결합할 수 있는지 확인한다.
- 가능한 범위는 구현하고, 위험한 범위는 문서화된 fallback으로 남긴다.

### 작업

- rotation 값의 단위와 bbox 기준점을 render tree/core SVG/rhwp-studio 기준으로 확인한다.
- run 단위 rotation helper를 추가할 경우 shade, shadow, glyph, underline/strike, emphasis dot의 draw order를 함께 정리한다.
- vertical text는 CoreText vertical forms를 바로 쓰는 방식과 cluster별 세로 배치 방식을 비교한다.
- 기존 horizontal text의 baseline 계산을 건드리지 않도록 rotation/vertical 전용 분기를 둔다.
- 샘플 또는 render tree 계약이 부족하면 구현을 제한하고 fallback 정책을 단계 보고서에 남긴다.

### 예상 변경 파일

- `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- 필요 시 `Sources/RhwpCoreBridge/RenderTree.swift`
- `mydocs/working/task_m050_109_stage5.md`

### 검증

```bash
git status --short --branch
git diff -- Sources/RhwpCoreBridge/CGTreeRenderer.swift Sources/RhwpCoreBridge/RenderTree.swift
./scripts/check-no-appkit.sh
./scripts/render-debug-compare.sh /private/tmp/rhwp-task109-stage5-bokhak samples/복학원서.hwp
./scripts/render-debug-compare.sh /private/tmp/rhwp-task109-stage5-hongbo samples/20250130-hongbo.hwp
./scripts/validate-stage3-render.sh /private/tmp/rhwp-task109-stage5-smoke samples/basic/BookReview.hwp samples/basic/KTX.hwp samples/basic/request.hwp samples/exam_kor.hwp
git diff --check
```

### 완료 기준

- rotation/vertical text를 구현한 범위와 fallback으로 남긴 범위가 명확히 기록된다.
- 기존 horizontal text의 위치, baseline, decoration 결과가 smoke 기준으로 회귀하지 않는다.
- 구현을 보류한 경우 필요한 render tree/core 계약 또는 샘플 부족 사유가 기록된다.

### 커밋 메시지

```text
Task #109 Stage 5: 텍스트 변환 style 판단과 보강
```

## Stage 6. 통합 검증과 결과 정리

### 목표

- `devel` 기준 HostApp native viewer, Quick Look, Thumbnail 공통 renderer 영향 범위를 검증한다.
- 지원 항목, fallback 항목, `devel-webview` 백포트 영향 여부를 최종 보고 전에 정리한다.

### 작업

- `Sources/RhwpCoreBridge` 경계 검증을 다시 실행한다.
- 대표 render smoke와 render-debug 비교를 실행한다.
- HostApp Debug build를 실행해 native viewer compile/link 회귀를 확인한다.
- Stage 1-5 결과를 기준으로 최종 보고서에 넣을 지원/fallback 표를 정리한다.
- `mydocs/orders/20260506.md` 상태 갱신과 최종 보고서는 `task-final-report` 승인 단계에서 수행한다.

### 예상 변경 파일

- `mydocs/working/task_m050_109_stage6.md`

### 검증

```bash
git status --short --branch
./scripts/check-no-appkit.sh
./scripts/validate-stage3-render.sh
./scripts/validate-stage3-render.sh /private/tmp/rhwp-task109-final-smoke samples/basic/BookReview.hwp samples/basic/KTX.hwp samples/basic/request.hwp samples/exam_kor.hwp
./scripts/render-debug-compare.sh /private/tmp/rhwp-task109-final-bokhak samples/복학원서.hwp
./scripts/render-debug-compare.sh /private/tmp/rhwp-task109-final-hongbo samples/20250130-hongbo.hwp
xcodegen generate
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
git diff --check
```

### 완료 기준

- AppKit/UIKit 직접 의존 금지 검증이 통과한다.
- 대표 render smoke와 HostApp Debug build가 통과하거나, 환경성 실패가 근거와 함께 분리된다.
- 최종 보고서에 넣을 지원/fallback/백포트 영향 요약이 Stage 6 보고서에 정리된다.

### 커밋 메시지

```text
Task #109 Stage 6: renderer style 통합 검증
```

## 최종 보고 전 체크리스트

- Stage 1-6 단계 보고서가 모두 `mydocs/working/`에 존재한다.
- source 변경이 `Sources/RhwpCoreBridge` 중심으로 제한되어 있고, AppKit/UIKit/WebKit 직접 의존이 없다.
- `project.yml` 변경이 필요했다면 `AlhangeulMac.xcodeproj`를 직접 수정하지 않았다.
- render 산출물은 저장소에 커밋하지 않았다.
- `devel-webview`에는 직접 반영하지 않았고, 백포트 필요 여부와 영향 범위가 보고서에 남아 있다.
- 최종 보고서 작성과 PR 게시 전 `task-final-report` 절차 승인을 받는다.
