# Task M015 #120 Stage 2 완료보고서

## 단계 목적

`CGTreeRenderer.renderTextRun`에 bbox, CoreText measured width, style-derived spacing을 한 곳에서 계산하는 내부 배치 helper를 추가했다.

기존 CoreText 한 줄 drawing 경로는 유지하되, bbox 폭과 CoreText 폭의 차이가 보정 가능한 범위일 때 provisional horizontal scale을 적용해 run advance를 render tree bbox에 맞추도록 했다.

## 산출물

- 변경 파일: `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- 단계 보고서: `mydocs/working/task_m015_120_stage2.md`
- 기준 산출물: `/private/tmp/rhwp-task120-stage2-hongbo`
- 추가 smoke 산출물: `/private/tmp/rhwp-task120-stage2-smoke`

`RenderTree.swift`는 변경하지 않았다. Stage 1에서 확인한 것처럼 필요한 style 필드는 이미 디코딩되고 있었다.

## 본문 변경 정도 / 본문 무손실 여부

소스 변경은 `CGTreeRenderer.swift`의 text run 렌더링 내부로 제한했다. 기존 shape, image, equation, footnote marker, decoration API는 변경하지 않았다.

## 구현 내용

### helper 분리

`renderTextRun`에서 직접 하던 font/attribute 생성과 `CTLineDraw` 호출을 다음 helper로 분리했다.

- `makeTextRunFont(style:fontSize:)`
- `makeTextRunAttributes(style:font:)`
- `makeTextRunLayoutPlan(text:style:bbox:line:)`
- `estimateTextRunSpacing(text:style:)`
- `chooseTextRunDrawStrategy(measuredWidth:targetWidth:spacing:)`
- `drawTextLine(_:layout:y:in:)`

추가한 private model:

- `TextRunLayoutPlan`
- `TextRunSpacingEstimate`
- `TextRunDrawStrategy`

### 계산식

CoreText 측정 폭:

```text
measuredWidth = CTLineGetTypographicBounds(line)
glyphBoundsWidth = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds).width
targetWidth = TextRun bbox.width
```

style-derived spacing 추정:

```text
extraCharWidth = extraCharSpacing * max(clusterCount - 1, 0)
extraWordWidth = extraWordSpacing * spaceCount
tabWidth = defaultTabWidth * tabCount
additionalWidth = extraCharWidth + extraWordWidth + tabWidth
```

적용 순서:

1. `ratio`는 기존과 같이 CTFont transform으로 반영한다.
2. `letterSpacing`은 기존과 같이 `kCTKern`으로 반영한다.
3. `extraCharSpacing`, `extraWordSpacing`, tab advance는 `kCTKern`에 섞지 않고 별도 estimate로 계산한다. 이렇게 해야 `letterSpacing`과 중복 적용되지 않는다.
4. `lineXOffset`은 Stage 1에서 bbox x에 이미 반영된 것으로 확인했으므로 drawing 시 다시 더하지 않는다.

### drawing 전략

`measuredWidth`와 `targetWidth`가 모두 0보다 클 때 scale을 계산한다.

```text
scale = targetWidth / measuredWidth
```

- `abs(scale - 1) < 0.005`: 기존 CoreText 한 줄 drawing 유지
- `0.70 ... 1.35`: CoreText 한 줄 drawing에 x scale 적용
- 그 외: cluster 단위 drawing 필요로 분류하되, Stage 2에서는 기존 한 줄 drawing fallback 유지

이번 단계의 x scale은 bbox advance를 빠르게 보존하기 위한 provisional 경로다. 글자 모양 자체도 가로로 늘어나거나 줄어들 수 있으므로, Stage 3에서 글자/cluster 단위 x 배치로 대체할 후보다.

## 검증 결과

### 상태와 diff

```text
git status --short --branch
## local/task120...origin/devel [ahead 3]
 M Sources/RhwpCoreBridge/CGTreeRenderer.swift
```

```text
git diff -- Sources/RhwpCoreBridge/CGTreeRenderer.swift Sources/RhwpCoreBridge/RenderTree.swift
```

`CGTreeRenderer.swift`만 변경됐고 `RenderTree.swift` 변경은 없다.

### 의존성 경계

```text
./scripts/check-no-appkit.sh
OK: shared Swift code has no AppKit/UIKit dependencies
```

### render-debug

```text
./scripts/render-debug-compare.sh /private/tmp/rhwp-task120-stage2-hongbo samples/20250130-hongbo.hwp
OK 20250130-hongbo.hwp: page=1 renderTreeJSON=/private/tmp/rhwp-task120-stage2-hongbo/20250130-hongbo-page1-render-tree.json coreSVG=/private/tmp/rhwp-task120-stage2-hongbo/20250130-hongbo-page1-core.svg nativePNG=/private/tmp/rhwp-task120-stage2-hongbo/20250130-hongbo-page1-native.png summary=/private/tmp/rhwp-task120-stage2-hongbo/20250130-hongbo-page1-summary.txt
```

summary:

```text
Input: /private/tmp/rhwp-mac-task120/samples/20250130-hongbo.hwp
Page: 1
PageIndex: 0
PageCount: 4
PageSizePt: 793.7x1122.5
RenderTreeJSONBytes: 99137
CoreSVGBytes: 235786
NativePNGSize: 794x1123
NativeNonWhitePixels: 88902
TextRuns: 60
HangulRuns: 35
HangulScalars: 535
MissingHangulGlyphs: 0
Diff: not generated
DiffReason: qlmanage rasterize failed
```

Stage 1 기준 `NativeNonWhitePixels`는 `84406`이었고 Stage 2는 `88902`이다. render tree와 core SVG 크기는 동일하므로, 차이는 native renderer의 text drawing 변경에서 발생했다.

### 추가 smoke

Stage 2 계획의 필수 검증은 아니지만, text drawing 변경의 범위가 넓어 기준 정렬 샘플까지 smoke를 추가 실행했다.

```text
./scripts/validate-stage3-render.sh /private/tmp/rhwp-task120-stage2-smoke samples/20250130-hongbo.hwp samples/re-align-center-hancom.hwp samples/re-align-right-hancom.hwp samples/re-align-justify-hancom.hwp
OK 20250130-hongbo.hwp: page=1 size=794x1123 textRuns=60 hangulRuns=35 hangulScalars=535 nonWhitePixels=88902 png=/private/tmp/rhwp-task120-stage2-smoke/20250130-hongbo-page1.png
OK re-align-center-hancom.hwp: page=1 size=794x1123 textRuns=3 hangulRuns=3 hangulScalars=100 nonWhitePixels=6338 png=/private/tmp/rhwp-task120-stage2-smoke/re-align-center-hancom-page1.png
OK re-align-right-hancom.hwp: page=1 size=794x1123 textRuns=3 hangulRuns=3 hangulScalars=100 nonWhitePixels=6264 png=/private/tmp/rhwp-task120-stage2-smoke/re-align-right-hancom-page1.png
OK re-align-justify-hancom.hwp: page=1 size=794x1123 textRuns=3 hangulRuns=3 hangulScalars=100 nonWhitePixels=6588 png=/private/tmp/rhwp-task120-stage2-smoke/re-align-justify-hancom-page1.png
```

### whitespace

```text
git diff --check
```

통과했다.

## 잔여 위험

- x scale은 bbox advance를 맞추지만 glyph outline 자체도 가로로 변형한다. 제목처럼 CoreText 폭과 HWP advance 차이가 큰 run은 Stage 3에서 cluster 단위 x 배치로 전환해야 한다.
- `extraCharSpacing`, `extraWordSpacing`, tab advance는 Stage 2에서 estimate로 계산하지만, 실제 개별 cluster drawing에는 아직 직접 쓰지 않는다.
- `clusterRequired` 전략은 분류만 수행하고 Stage 2에서는 기존 한 줄 drawing fallback으로 둔다. 실제 cluster drawing은 다음 단계 범위다.
- `qlmanage` rasterize 실패로 pixel diff PNG는 생성되지 않았다. Stage 3 이후에도 native PNG와 summary 중심 확인이 필요하다.

## 다음 단계 영향

Stage 3에서는 이번 단계의 `TextRunLayoutPlan`과 `TextRunSpacingEstimate`를 사용해 x scale fallback을 줄이고, run 내부 cluster별 target x를 계산하는 drawing 경로를 추가한다.

우선순위는 다음과 같다.

- bbox width와 CoreText measured width 차이가 큰 run을 cluster drawing 후보로 전환
- `extraCharSpacing`과 `extraWordSpacing`을 cluster advance에 직접 반영
- 날짜 run처럼 run이 나뉘는 텍스트에서 이전 run의 끝과 다음 run bbox 시작이 자연스럽게 이어지는지 확인
- 정렬 샘플 3종에서 center/right/justify 위치가 유지되는지 확인

## 승인 요청

Stage 2 `TextRun` 배치 계산 보강을 완료했다. Stage 3 `글자/cluster 단위 drawing 적용`에 진입해도 되는지 승인 요청한다.
