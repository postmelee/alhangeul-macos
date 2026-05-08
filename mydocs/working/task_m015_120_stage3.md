# Task M015 #120 Stage 3 완료보고서

## 단계 목적

Stage 2의 provisional whole-run horizontal scale을 기본 경로에서 내리고, `CGTreeRenderer`의 text run drawing을 글자/cluster 단위 위치 배치로 전환했다.

이번 단계의 기준 구현은 이슈에 추가된 구현 기준대로 rhwp-studio의 `WebCanvasRenderer`/view 계층과 core layout 동작이다. 다만 DOM/Canvas/TypeScript 구조를 이식하지 않고, Swift/AppKit 비의존 shared renderer 안에서 CoreGraphics/CoreText 기반 native 구현으로 재해석했다.

## 산출물

- 변경 파일: `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- 단계 보고서: `mydocs/working/task_m015_120_stage3.md`
- 기준 산출물: `/private/tmp/rhwp-task120-stage3-hongbo`
- 기준 산출물: `/private/tmp/rhwp-task120-stage3-center`
- 기준 산출물: `/private/tmp/rhwp-task120-stage3-right`
- 추가 smoke 산출물: `/private/tmp/rhwp-task120-stage3-smoke`

`RenderTree.swift`와 debug script는 변경하지 않았다. 현재 render tree의 style 필드만으로 구현 가능한 범위에서 진행했다.

## rhwp-studio reference 확인

`rhwp-studio` 경로는 다음 구조로 native renderer의 기준 동작을 제공한다.

- `rhwp-studio/src/view/canvas-view.ts`: zoom과 DPR 기반 render scale 계산
- `rhwp-studio/src/view/page-renderer.ts`: page별 canvas render 호출
- `rhwp-studio/src/core/wasm-bridge.ts`: WASM `renderPageToCanvas` 호출
- `rhwp/src/wasm_api.rs`: render tree cache 생성 후 `WebCanvasRenderer` 실행
- `rhwp/src/renderer/web_canvas.rs`: `draw_text`에서 cluster별 `fill_text`
- `rhwp/src/renderer/layout/text_measurement.rs`: `compute_char_positions`

핵심 차이는 다음이다.

1. rhwp-studio는 `split_into_clusters(text)`와 `compute_char_positions(text, style)`를 먼저 계산한다.
2. 각 cluster는 `x + char_positions[char_idx]`에 개별 drawing된다.
3. 공백, tab, figure space는 advance만 차지하고 실제 glyph drawing은 건너뛴다.
4. 반각 강제 구두점은 ratio가 없을 때 glyph drawing만 0.5배로 줄인다.
5. underline/strikethrough 기준 폭은 char position의 마지막 값이다.

## 구현 내용

### cluster layout plan

`TextRunLayoutPlan`에 `TextRunClusterPlan`을 추가했다. 기존 CoreText line 측정값은 fallback 판단과 진단용으로 유지하되, multi-cluster text는 기본적으로 cluster drawing 경로를 사용한다.

추가한 주요 helper:

- `makeTextRunClusterPlan(text:style:targetWidth:attributes:)`
- `splitTextRunClusters(_:)`
- `textRunClusterPositions(metrics:style:)`
- `textRunClusterAdvance(_:style:attributes:)`
- `drawTextClusters(_:style:attributes:y:in:)`
- `drawTextCluster(_:style:attributes:y:in:)`

### advance 계산

현재 Swift render tree에는 core의 `char_positions` 배열이 없으므로, Swift renderer에서 rhwp-studio/core 정책을 근사한다.

- Swift `String` extended grapheme cluster를 기본 단위로 사용한다.
- 한글 자모 cluster, CJK, 전각 문자, 주요 fullwidth symbol은 `fontSize * ratio`를 기준 폭으로 둔다.
- 그 외 문자는 CoreText 측정 폭과 `fontSize * 0.5 * ratio` 중 큰 값을 사용한다.
- 각 cluster advance에는 `letterSpacing + extraCharSpacing`을 더한다.
- 일반 space는 `extraWordSpacing`을 추가한다.
- tab은 `inlineTabs`, custom `tabStops`, `autoTabRight`, `defaultTabWidth` 순서로 처리한다.
- bbox와 raw advance 차이는 glyph outline scale이 아니라 cluster x position scale로만 보정한다.

이 방식은 Stage 2처럼 글자 모양 자체를 늘리지 않고, run 내부 시작 위치를 rhwp-studio의 `char_positions` 방식에 가깝게 분배한다.

### drawing 정책

- cluster drawing은 `CTLineDraw`를 cluster별로 호출한다.
- space, tab, figure space는 drawing하지 않는다.
- U+2018...U+2027, U+00B7 구두점은 ratio가 없을 때만 drawing 좌표계에서 x 0.5 scale을 적용한다.
- cluster plan 생성이 불가능한 단일 cluster 또는 비정상 폭에서는 기존 CoreText line drawing으로 fallback한다.
- whole-run x scale은 cluster plan이 없는 경우의 좁은 fallback으로만 남겼고 적용 범위를 `0.90...1.10`으로 줄였다.

## 검증 결과

### 상태와 diff

```text
git status --short --branch
## local/task120...origin/devel [ahead 4]
 M Sources/RhwpCoreBridge/CGTreeRenderer.swift
?? mydocs/working/task_m015_120_stage3.md
```

소스 변경은 `CGTreeRenderer.swift`로 제한했고, 문서 변경은 Stage 3 보고서 추가뿐이다.

### 의존성 경계

```text
./scripts/check-no-appkit.sh
OK: shared Swift code has no AppKit/UIKit dependencies
```

### render-debug

```text
./scripts/render-debug-compare.sh /private/tmp/rhwp-task120-stage3-hongbo samples/20250130-hongbo.hwp
OK 20250130-hongbo.hwp: page=1 renderTreeJSON=/private/tmp/rhwp-task120-stage3-hongbo/20250130-hongbo-page1-render-tree.json coreSVG=/private/tmp/rhwp-task120-stage3-hongbo/20250130-hongbo-page1-core.svg nativePNG=/private/tmp/rhwp-task120-stage3-hongbo/20250130-hongbo-page1-native.png summary=/private/tmp/rhwp-task120-stage3-hongbo/20250130-hongbo-page1-summary.txt
```

```text
./scripts/render-debug-compare.sh /private/tmp/rhwp-task120-stage3-center samples/re-align-center-hancom.hwp
OK re-align-center-hancom.hwp: page=1 renderTreeJSON=/private/tmp/rhwp-task120-stage3-center/re-align-center-hancom-page1-render-tree.json coreSVG=/private/tmp/rhwp-task120-stage3-center/re-align-center-hancom-page1-core.svg nativePNG=/private/tmp/rhwp-task120-stage3-center/re-align-center-hancom-page1-native.png summary=/private/tmp/rhwp-task120-stage3-center/re-align-center-hancom-page1-summary.txt
```

```text
./scripts/render-debug-compare.sh /private/tmp/rhwp-task120-stage3-right samples/re-align-right-hancom.hwp
OK re-align-right-hancom.hwp: page=1 renderTreeJSON=/private/tmp/rhwp-task120-stage3-right/re-align-right-hancom-page1-render-tree.json coreSVG=/private/tmp/rhwp-task120-stage3-right/re-align-right-hancom-page1-core.svg nativePNG=/private/tmp/rhwp-task120-stage3-right/re-align-right-hancom-page1-native.png summary=/private/tmp/rhwp-task120-stage3-right/re-align-right-hancom-page1-summary.txt
```

필수 산출물 존재 확인:

```text
test -s /private/tmp/rhwp-task120-stage3-hongbo/20250130-hongbo-page1-native.png
test -s /private/tmp/rhwp-task120-stage3-center/re-align-center-hancom-page1-summary.txt
test -s /private/tmp/rhwp-task120-stage3-right/re-align-right-hancom-page1-summary.txt
```

모두 통과했다.

### summary 핵심값

| 샘플 | Stage 1 NativeNonWhitePixels | Stage 2 NativeNonWhitePixels | Stage 3 NativeNonWhitePixels | MissingHangulGlyphs |
|------|------------------------------|------------------------------|------------------------------|---------------------|
| `20250130-hongbo.hwp` | 84406 | 88902 | 84306 | 0 |
| `re-align-center-hancom.hwp` | 6559 | 6338 | 6666 | 0 |
| `re-align-right-hancom.hwp` | 6500 | 6264 | 6615 | 0 |
| `re-align-justify-hancom.hwp` | 6582 | 6588 | 6652 | 0 |

Stage 3의 hongbo non-white pixel 수가 Stage 2보다 낮아진 것은 의도한 변화다. Stage 2는 run 전체 x scale로 glyph outline 자체를 늘렸고, Stage 3는 glyph outline은 유지한 채 cluster 위치만 분배한다.

### 추가 smoke

```text
./scripts/validate-stage3-render.sh /private/tmp/rhwp-task120-stage3-smoke samples/20250130-hongbo.hwp samples/re-align-center-hancom.hwp samples/re-align-right-hancom.hwp samples/re-align-justify-hancom.hwp
OK 20250130-hongbo.hwp: page=1 size=794x1123 textRuns=60 hangulRuns=35 hangulScalars=535 nonWhitePixels=84306 png=/private/tmp/rhwp-task120-stage3-smoke/20250130-hongbo-page1.png
OK re-align-center-hancom.hwp: page=1 size=794x1123 textRuns=3 hangulRuns=3 hangulScalars=100 nonWhitePixels=6666 png=/private/tmp/rhwp-task120-stage3-smoke/re-align-center-hancom-page1.png
OK re-align-right-hancom.hwp: page=1 size=794x1123 textRuns=3 hangulRuns=3 hangulScalars=100 nonWhitePixels=6615 png=/private/tmp/rhwp-task120-stage3-smoke/re-align-right-hancom-page1.png
OK re-align-justify-hancom.hwp: page=1 size=794x1123 textRuns=3 hangulRuns=3 hangulScalars=100 nonWhitePixels=6652 png=/private/tmp/rhwp-task120-stage3-smoke/re-align-justify-hancom-page1.png
```

### whitespace

```text
git diff --check
```

통과했다.

## 샘플별 확인

`20250130-hongbo.hwp`의 문제 run은 Stage 1과 같은 render tree bbox를 유지한다.

| id | text | bbox x | bbox width |
|----|------|--------|------------|
| 39 | `2026. 1. 30.(` | 588.3533 | 87.0 |
| 40 | `금)` | 675.3533 | 20.0 |
| 50 | `혹한기 봉화댐 건설 현장점검 ‘안전 온도 높인다’` | 84.88 | 624.0 |

native PNG 기준으로 Stage 1에서 보이던 `30.(`와 `금)` 사이의 과도한 빈칸은 줄었고, 제목 run은 bbox 폭에 맞게 배치된다. Stage 2와 달리 글자 자체가 가로로 늘어난 느낌은 줄었다.

center/right 정렬 샘플은 `lineXOffset`을 다시 더하지 않고 bbox x를 확정 위치로 사용하므로 기존 Stage 1 조사에서 확인한 이중 적용 위험은 만들지 않았다.

## 잔여 위험

- 현재 render tree에는 rhwp core가 계산한 `char_positions` 또는 `charX` 배열이 없다. Swift가 재계산한 fallback advance는 rhwp-studio와 방향은 같지만 완전한 reference 값은 아니다.
- rhwp-studio WASM 경로는 Canvas 측정과 core fallback metric을 함께 쓴다. Swift renderer는 내장 core font metric 테이블에 접근하지 않으므로 일부 라틴/기호/폰트 조합에서 위치 차이가 남을 수 있다.
- 긴 run의 cluster별 `CTLineDraw`는 정확도 중심 변경이다. 대량 문서 성능은 Stage 4 이후 별도 확인이 필요하다.
- `qlmanage` rasterize 실패로 diff PNG는 생성되지 않았다. 이번 단계도 native PNG와 summary 중심으로 확인했다.

## 다음 단계 영향

Stage 4에서는 기준 샘플 4개를 다시 생성해 정렬/양끝 정렬/space-tab 회귀를 확인한다.

또한 Swift-only 보정으로 남는 차이가 확인되면, render tree에 optional `char_positions` 또는 cluster advance 배열을 추가하는 계약 확장 필요 여부를 판단한다. 완전한 rhwp-studio parity는 Swift에서 metric을 다시 추정하는 방식보다 core가 계산한 위치 배열을 native renderer에 전달하는 방식이 더 안정적이다.

## 승인 요청

Stage 3 글자/cluster 단위 drawing 적용을 완료했다. Stage 4 `정렬 샘플 검증과 render tree 계약 판단`에 진입해도 되는지 승인 요청한다.
