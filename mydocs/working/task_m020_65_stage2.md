# Task M020 #65 Stage 2 완료보고서

## 단계 목표

같은 HWP/HWPX 입력에서 render tree JSON, rhwp core SVG, native renderer PNG, summary를 한 번에 생성하는 디버깅 helper를 구현한다.

## 변경 내용

### 1. render tree raw JSON API

`Sources/RhwpCoreBridge/RhwpDocument.swift`에 `renderPageTreeJSON(at:)`를 추가했다.

- `rhwp_render_page_tree`가 반환하는 JSON 문자열을 그대로 Swift `String`으로 반환한다.
- 기존 `renderPageTree(at:)`는 새 API를 호출한 뒤 `RenderNode`로 디코딩하도록 정리했다.
- 기존 제품 렌더링 경로의 입력과 동작 의미는 유지했다.

### 2. shell wrapper

`scripts/render-debug-compare.sh`를 추가했다.

기본 사용법:

```bash
./scripts/render-debug-compare.sh <output-dir> [--page N] <hwp-or-hwpx> [...]
```

동작:

- `Frameworks/universal/librhwp.a`와 `Frameworks/modulemap/module.modulemap` 존재를 확인한다.
- Swift/Clang module cache를 output directory 아래에 만든다.
- `scripts/render_debug_compare.swift`를 `RhwpDocument`, `RenderTree`, `FontFallback`, `CGTreeRenderer`와 함께 컴파일한다.
- 컴파일한 helper를 실행해 산출물을 생성한다.

### 3. Swift helper

`scripts/render_debug_compare.swift`를 추가했다.

생성하는 필수 산출물:

- `{basename}-page{N}-render-tree.json`
- `{basename}-page{N}-core.svg`
- `{basename}-page{N}-native.png`
- `{basename}-page{N}-summary.txt`

native PNG는 `stage3_render_check.swift`와 같은 `RenderNode` + `CGTreeRenderer` + CoreGraphics bitmap context 경로로 생성한다.

summary에는 다음 정보를 기록한다.

- input path
- page number/index/count
- page size
- render tree JSON path/byte size
- core SVG path/byte size
- native PNG path/size/non-white pixel count
- text/Hangul/glyph stats
- Stage 2에서는 diff 미생성 상태

## 검증

### shell syntax

```bash
bash -n scripts/render-debug-compare.sh
```

결과: 통과.

### diff whitespace

```bash
git diff --check -- Sources/RhwpCoreBridge/RhwpDocument.swift scripts/render_debug_compare.swift scripts/render-debug-compare.sh
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

### table-in-tbox 디버그 산출물

```bash
./scripts/render-debug-compare.sh output/task65-stage2 /Users/melee/Documents/samples/table-in-tbox.hwp
```

결과:

```text
OK table-in-tbox.hwp: page=1 renderTreeJSON=/private/tmp/rhwp-mac-task65/output/task65-stage2/table-in-tbox-page1-render-tree.json coreSVG=/private/tmp/rhwp-mac-task65/output/task65-stage2/table-in-tbox-page1-core.svg nativePNG=/private/tmp/rhwp-mac-task65/output/task65-stage2/table-in-tbox-page1-native.png summary=/private/tmp/rhwp-mac-task65/output/task65-stage2/table-in-tbox-page1-summary.txt
```

필수 산출물 존재 확인:

```bash
test -s output/task65-stage2/table-in-tbox-page1-render-tree.json
test -s output/task65-stage2/table-in-tbox-page1-core.svg
test -s output/task65-stage2/table-in-tbox-page1-native.png
test -s output/task65-stage2/table-in-tbox-page1-summary.txt
```

결과: 모두 통과.

summary 주요 값:

```text
PageCount: 2
PageSizePt: 793.7x1122.5
RenderTreeJSONBytes: 826451
CoreSVGBytes: 434334
NativePNGSize: 794x1123
NativeNonWhitePixels: 11845
TextRuns: 472
HangulRuns: 187
HangulScalars: 779
MissingHangulGlyphs: 0
Diff: not generated in Stage 2
```

파일 타입과 크기:

```text
render-tree.json: UTF-8 text, 826451 bytes
core.svg: SVG Scalable Vector Graphics image, 434334 bytes
native.png: PNG image data, 794 x 1123, 19487 bytes
summary.txt: ASCII text, 606 bytes
```

### 저장소 fixture 상대 경로 확인

```bash
./scripts/render-debug-compare.sh output/task65-stage2-ktx samples/basic/KTX.hwp
```

결과:

```text
OK KTX.hwp: page=1 renderTreeJSON=/private/tmp/rhwp-mac-task65/output/task65-stage2-ktx/KTX-page1-render-tree.json coreSVG=/private/tmp/rhwp-mac-task65/output/task65-stage2-ktx/KTX-page1-core.svg nativePNG=/private/tmp/rhwp-mac-task65/output/task65-stage2-ktx/KTX-page1-native.png summary=/private/tmp/rhwp-mac-task65/output/task65-stage2-ktx/KTX-page1-summary.txt
```

### 기존 render smoke 회귀

`table-in-tbox.hwp` 단일 smoke:

```bash
./scripts/validate-stage3-render.sh output/task65-stage2-smoke /Users/melee/Documents/samples/table-in-tbox.hwp
```

결과:

```text
OK table-in-tbox.hwp: page=1 size=794x1123 textRuns=472 hangulRuns=187 hangulScalars=779 nonWhitePixels=11845 png=/private/tmp/rhwp-mac-task65/output/task65-stage2-smoke/table-in-tbox-page1.png
```

기본 smoke fixture:

```bash
./scripts/validate-stage3-render.sh output/task65-stage2-smoke-default
```

결과:

```text
OK KTX.hwp: page=1 size=1123x794 textRuns=435 hangulRuns=76 hangulScalars=209 nonWhitePixels=450455 png=/private/tmp/rhwp-mac-task65/output/task65-stage2-smoke-default/KTX-page1.png
OK request.hwp: page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=54724 png=/private/tmp/rhwp-mac-task65/output/task65-stage2-smoke-default/request-page1.png
OK exam_kor.hwp: page=1 size=1123x1588 textRuns=69 hangulRuns=51 hangulScalars=940 nonWhitePixels=96464 png=/private/tmp/rhwp-mac-task65/output/task65-stage2-smoke-default/exam_kor-page1.png
```

## 판단

- 필수 산출물 4종을 한 명령으로 생성하는 Stage 2 목표를 달성했다.
- 기존 `validate-stage3-render.sh` 동작과 기본 fixture smoke는 유지된다.
- `Sources/RhwpCoreBridge`에는 AppKit/UIKit 직접 의존이 없다.
- SVG rasterize와 pixel diff는 아직 생성하지 않는다. 이는 Stage 3의 선택 산출물 범위로 남긴다.

## 변경 파일

- `Sources/RhwpCoreBridge/RhwpDocument.swift`
- `scripts/render-debug-compare.sh`
- `scripts/render_debug_compare.swift`
- `mydocs/working/task_m020_65_stage2.md`

## 승인 요청

Stage 2 완료를 승인하면 Stage 3 SVG rasterize와 pixel diff 선택 산출물 구현으로 진행한다.
