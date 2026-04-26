# Task M020 #65 Stage 3 완료보고서

## 단계 목표

Stage 2의 필수 산출물 생성 경로를 유지하면서, 가능한 환경에서는 rhwp core SVG를 PNG로 rasterize하고 native PNG와의 pixel diff 산출물을 생성한다.

## 변경 내용

### 1. 선택 산출물 생성 흐름

`scripts/render-debug-compare.sh`에 Stage 2 helper 실행 이후 선택 산출물 생성 단계를 추가했다.

추가 산출물:

- `{basename}-page{N}-core.png`
- `{basename}-page{N}-diff.png`
- summary 파일의 diff 관련 필드

현재 rasterizer는 macOS 기본 도구인 `qlmanage -t -x`를 사용한다. `qlmanage`가 없거나 실패하면 스크립트는 실패하지 않고 summary에 `DiffReason`을 남긴다.

### 2. pixel diff 모드

`scripts/render_debug_compare.swift`에 `--diff-png` 모드를 추가했다.

사용 형태:

```bash
render_debug_compare --diff-png <native-png> <core-png> <diff-png> <summary-txt>
```

동작:

- native PNG와 core raster PNG를 CoreGraphics/ImageIO로 RGBA bitmap으로 읽는다.
- 두 이미지 크기가 다르면 공통 비교 영역의 `min(width) x min(height)`를 사용한다.
- 다른 픽셀은 red 계열 diff image로 표시한다.
- summary에 비교 크기, native/core 크기, 다른 픽셀 수, 비율, max channel delta를 기록한다.

### 3. sandbox 실패 fallback

일반 샌드박스 실행에서는 `qlmanage`가 다음 오류로 실패했다.

```text
sandbox initialization failed: invalid data type of path filter; expected pattern, got boolean
```

이 경우에도 필수 산출물 4종은 생성되고, summary는 다음 형태로 남는다.

```text
CoreRasterPNG: /private/tmp/rhwp-mac-task65/output/task65-stage3/table-in-tbox-page1-core.png
DiffPNG: /private/tmp/rhwp-mac-task65/output/task65-stage3/table-in-tbox-page1-diff.png
Diff: not generated
DiffReason: qlmanage rasterize failed; see /private/tmp/rhwp-mac-task65/output/task65-stage3/table-in-tbox-page1-core.svg.qlmanage.log
```

즉, optional rasterize 실패가 필수 산출물 생성을 실패 처리하지 않는다.

## 검증

### 도구 후보 확인

```bash
which qlmanage
which rsvg-convert
which magick
```

결과:

```text
/usr/bin/qlmanage
rsvg-convert not found
magick not found
```

이번 단계에서는 `qlmanage`를 사용해 macOS 기본 환경 기준으로 SVG rasterize를 검증했다.

### shell syntax

```bash
bash -n scripts/render-debug-compare.sh
```

결과: 통과.

### diff whitespace

```bash
git diff --check -- scripts/render-debug-compare.sh scripts/render_debug_compare.swift
```

결과: 통과.

### Shared bridge 경계

```bash
./scripts/check-no-appkit.sh
```

결과:

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

### 일반 샌드박스 실행

```bash
./scripts/render-debug-compare.sh output/task65-stage3 /Users/melee/Documents/samples/table-in-tbox.hwp
```

결과:

```text
OK table-in-tbox.hwp: page=1 renderTreeJSON=/private/tmp/rhwp-mac-task65/output/task65-stage3/table-in-tbox-page1-render-tree.json coreSVG=/private/tmp/rhwp-mac-task65/output/task65-stage3/table-in-tbox-page1-core.svg nativePNG=/private/tmp/rhwp-mac-task65/output/task65-stage3/table-in-tbox-page1-native.png summary=/private/tmp/rhwp-mac-task65/output/task65-stage3/table-in-tbox-page1-summary.txt
```

summary에는 `qlmanage rasterize failed`가 기록되었다.

### qlmanage 허용 실행

```bash
./scripts/render-debug-compare.sh output/task65-stage3-escalated /Users/melee/Documents/samples/table-in-tbox.hwp
```

결과:

```text
OK table-in-tbox.hwp: page=1 renderTreeJSON=/private/tmp/rhwp-mac-task65/output/task65-stage3-escalated/table-in-tbox-page1-render-tree.json coreSVG=/private/tmp/rhwp-mac-task65/output/task65-stage3-escalated/table-in-tbox-page1-core.svg nativePNG=/private/tmp/rhwp-mac-task65/output/task65-stage3-escalated/table-in-tbox-page1-native.png summary=/private/tmp/rhwp-mac-task65/output/task65-stage3-escalated/table-in-tbox-page1-summary.txt
DIFF native=/private/tmp/rhwp-mac-task65/output/task65-stage3-escalated/table-in-tbox-page1-native.png core=/private/tmp/rhwp-mac-task65/output/task65-stage3-escalated/table-in-tbox-page1-core.png diff=/private/tmp/rhwp-mac-task65/output/task65-stage3-escalated/table-in-tbox-page1-diff.png differentPixels=179655 ratio=0.2014832974826784
```

summary 주요 값:

```text
CoreRasterPNG: /private/tmp/rhwp-mac-task65/output/task65-stage3-escalated/table-in-tbox-page1-core.png
DiffPNG: /private/tmp/rhwp-mac-task65/output/task65-stage3-escalated/table-in-tbox-page1-diff.png
Diff: generated
DiffCompareSize: 794x1123
DiffNativeSize: 794x1123
DiffCoreSize: 795x1123
DiffDifferentPixels: 179655
DiffDifferentPixelRatio: 0.201483
DiffMaxChannelDelta: 255
```

파일 타입:

```text
core.png: PNG image data, 795 x 1123, 8-bit/color RGBA, non-interlaced
diff.png: PNG image data, 794 x 1123, 8-bit/color RGBA, non-interlaced
native.png: PNG image data, 794 x 1123, 8-bit/color RGBA, non-interlaced
```

검증:

```bash
test -s output/task65-stage3-escalated/table-in-tbox-page1-core.png
test -s output/task65-stage3-escalated/table-in-tbox-page1-diff.png
rg -n "Diff: generated|DiffCompareSize|DiffDifferentPixels|DiffMaxChannelDelta|CoreRasterPNG" output/task65-stage3-escalated/table-in-tbox-page1-summary.txt
```

결과: 모두 통과.

### 기존 render smoke 회귀

```bash
./scripts/validate-stage3-render.sh output/task65-stage3-smoke
```

결과:

```text
OK KTX.hwp: page=1 size=1123x794 textRuns=435 hangulRuns=76 hangulScalars=209 nonWhitePixels=450455 png=/private/tmp/rhwp-mac-task65/output/task65-stage3-smoke/KTX-page1.png
OK request.hwp: page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=54724 png=/private/tmp/rhwp-mac-task65/output/task65-stage3-smoke/request-page1.png
OK exam_kor.hwp: page=1 size=1123x1588 textRuns=69 hangulRuns=51 hangulScalars=940 nonWhitePixels=96464 png=/private/tmp/rhwp-mac-task65/output/task65-stage3-smoke/exam_kor-page1.png
```

## 판단

- Stage 3 선택 산출물 구현 목표를 달성했다.
- macOS sandbox 제약으로 `qlmanage`가 실패해도 필수 산출물은 유지된다.
- `qlmanage` 실행이 허용된 환경에서는 core raster PNG와 diff PNG가 생성된다.
- core raster PNG가 `795x1123`, native PNG가 `794x1123`으로 1px 폭 차이를 보였고, diff는 공통 영역 `794x1123` 기준으로 생성됐다.
- SVG rasterize와 diff는 진단 보조 산출물이며 제품 fallback 경로는 아니다.

## 변경 파일

- `scripts/render-debug-compare.sh`
- `scripts/render_debug_compare.swift`
- `mydocs/working/task_m020_65_stage3.md`

## 승인 요청

Stage 3 완료를 승인하면 Stage 4 디버깅 문서 작성으로 진행한다.
