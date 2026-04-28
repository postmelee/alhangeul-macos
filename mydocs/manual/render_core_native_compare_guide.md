# rhwp core와 native renderer 비교 디버깅 절차

## 목적

macOS viewer가 그린 결과와 rhwp core가 그린 결과를 같은 입력 파일 기준으로 비교한다.

이 절차의 목표는 한컴 viewer와의 완전 정합성을 판단하는 것이 아니다. 이 저장소의 viewer는 rhwp core를 사용하므로, 우선 rhwp core의 현재 구현 결과와 native renderer 결과가 같은지 확인하는 것이 기준이다.

## 도구 역할 요약

`validate-stage3-render.sh`와 `render-debug-compare.sh`는 목적이 다르다.

| 도구 | 역할 | 사용 시점 |
|------|------|----------|
| `validate-stage3-render.sh` | 기본 샘플의 native render pipeline이 깨지지 않았는지 빠르게 확인하는 smoke test | renderer, bridge, core pin 변경 후 최소 회귀 확인 |
| `render-debug-compare.sh` | 특정 파일에서 core SVG, render tree JSON, native PNG, pixel diff를 만들어 원인을 좁히는 진단 도구 | smoke는 통과하지만 특정 문서가 이상하거나 renderer 개선 전후 비교가 필요할 때 |

`validate-stage3-render.sh`는 blank bitmap, 한글 glyph 누락, render tree 누락 같은 기본 실패를 잡는다. 하지만 native PNG에 일부 선만 그려져도 blank는 아니므로 시각적으로 큰 누락을 모두 잡지는 못한다. 이런 경우 `render-debug-compare.sh`로 core와 native 결과를 직접 비교한다.

## 기준 경로

| 기준 | 산출물 | 의미 |
|------|--------|------|
| core 기준 | core SVG | `rhwp_render_page_svg`가 반환하는 `render_page_svg_native` 결과 |
| native 기준 | native PNG | `RenderNode` + `CGTreeRenderer`가 CoreGraphics/CoreText로 그린 결과 |
| 중간 데이터 | render tree JSON | `rhwp_render_page_tree`가 반환하고 Swift renderer가 해석하는 원문 |

주의:

- core SVG는 제품 fallback이 아니라 진단 산출물이다.
- HostApp, Quick Look, Thumbnail의 기준 렌더 경로는 render tree 기반 native renderer다.
- SVG rasterize와 pixel diff는 비교 보조 자료이며, rasterizer 환경에 따라 결과가 달라질 수 있다.

## 준비

새 worktree에는 생성 산출물인 `Frameworks/`가 없을 수 있다. 이 경우 먼저 Rust bridge 산출물을 만든다.

```bash
./scripts/build-rust-macos.sh
```

필수 파일:

- `Frameworks/universal/librhwp.a`
- `Frameworks/modulemap/module.modulemap`

이 파일이 없으면 `render-debug-compare.sh`와 `validate-stage3-render.sh`는 명확한 오류로 중단한다.

## 기본 명령

```bash
./scripts/render-debug-compare.sh output/render-debug path/to/sample.hwp
```

예시:

```bash
./scripts/render-debug-compare.sh output/render-debug /Users/melee/Documents/samples/table-in-tbox.hwp
```

특정 페이지를 비교할 때:

```bash
./scripts/render-debug-compare.sh output/render-debug --page 2 path/to/sample.hwp
```

페이지 번호는 1-based다.

## 산출물

입력 파일명이 `table-in-tbox.hwp`, 페이지가 1이면 다음 파일이 생성된다.

| 파일 | 필수 여부 | 설명 |
|------|----------|------|
| `table-in-tbox-page1-render-tree.json` | 필수 | core render tree 원문 JSON |
| `table-in-tbox-page1-core.svg` | 필수 | rhwp core SVG 렌더 결과 |
| `table-in-tbox-page1-native.png` | 필수 | native renderer PNG 결과 |
| `table-in-tbox-page1-summary.txt` | 필수 | 크기, 텍스트 통계, 산출물 경로, diff 상태 |
| `table-in-tbox-page1-core.png` | 선택 | core SVG를 rasterize한 PNG |
| `table-in-tbox-page1-diff.png` | 선택 | native PNG와 core PNG의 pixel diff |
| `table-in-tbox-page1-core.svg.qlmanage.log` | 선택 | `qlmanage` rasterize 로그 |

선택 산출물은 `qlmanage`가 동작할 때만 생성된다. sandbox나 macOS Quick Look 상태 때문에 `qlmanage`가 실패하면 summary에 `DiffReason`이 기록되고, 필수 산출물 생성은 성공으로 유지된다.

## summary 해석

summary 예시:

```text
Input: /Users/melee/Documents/samples/table-in-tbox.hwp
Page: 1
PageIndex: 0
PageCount: 2
PageSizePt: 793.7x1122.5

RenderTreeJSON: .../table-in-tbox-page1-render-tree.json
RenderTreeJSONBytes: 830673

CoreSVG: .../table-in-tbox-page1-core.svg
CoreSVGBytes: 500175

NativePNG: .../table-in-tbox-page1-native.png
NativePNGSize: 794x1123
NativeNonWhitePixels: 11845

TextRuns: 471
HangulRuns: 187
HangulScalars: 779
MissingHangulGlyphs: 0

CoreRasterPNG: .../table-in-tbox-page1-core.png
DiffPNG: .../table-in-tbox-page1-diff.png
Diff: generated
DiffCompareSize: 794x1123
DiffNativeSize: 794x1123
DiffCoreSize: 795x1123
DiffDifferentPixels: 179854
DiffDifferentPixelRatio: 0.201706
DiffMaxChannelDelta: 255
```

주요 항목:

- `PageSizePt`: core page info 기준 point 크기다.
- `NativePNGSize`: native bitmap 크기다. page size 반올림 때문에 core raster PNG와 1px 차이가 날 수 있다.
- `RenderTreeJSONBytes`: render tree 규모를 빠르게 보는 값이다.
- `MissingHangulGlyphs`: 0이 아니면 폰트 fallback 또는 glyph lookup부터 확인한다.
- `DiffCompareSize`: 두 PNG 크기가 다를 때 공통 영역 기준 비교 크기다.
- `DiffDifferentPixelRatio`: 공통 영역 중 다른 픽셀 비율이다.
- `DiffMaxChannelDelta`: 채널 차이의 최대값이다.

## 판단 흐름

### 1. core SVG와 native PNG가 모두 비정상

우선 core 구현 한계 또는 입력 파싱 문제를 의심한다.

확인:

- core SVG가 빈 화면인지 확인
- render tree JSON에 주요 노드가 있는지 확인
- 다른 rhwp Studio/WebCanvas 경로에서도 같은지 확인
- 해당 기능이 rhwp core에 아직 구현되지 않았는지 확인

### 2. core SVG는 기대에 가깝고 native PNG만 다름

Swift decoder 또는 `CGTreeRenderer` 해석 문제를 우선 의심한다.

확인:

- render tree JSON의 해당 노드가 Swift `RenderTree.swift` 모델에 디코딩되는지 확인
- `CGTreeRenderer`가 해당 node type, style, transform, clipping, image data를 처리하는지 확인
- 과거 `line transform` 누락처럼 core SVG/WebCanvas는 적용하지만 Swift renderer가 빠뜨린 처리가 있는지 확인

### 3. render tree JSON에 필요한 정보가 없음

core render tree export 계약 문제로 분리한다.

확인:

- core SVG에는 정보가 반영되는지 확인
- render tree JSON에 bbox, transform, style, image id, clipping 정보가 있는지 확인
- Swift renderer에서 보정할 수 없는 데이터 누락이면 core 이슈 또는 별도 core 작업으로 분리

### 4. 디버그 산출물은 맞고 HostApp 화면만 다름

HostApp 표시 계층 문제를 의심한다.

확인:

- `DocumentPageView`의 scale, clipping, coordinate transform 확인
- SwiftUI/AppKit view 크기, backing scale, scroll/zoom 상태 확인
- 같은 문서가 Quick Look/Thumbnail 공통 renderer에서는 어떻게 보이는지 확인

### 5. diff가 크지만 눈으로 보기엔 큰 문제가 아님

anti-aliasing, rasterizer, 1px 반올림 차이일 수 있다.

확인:

- `DiffNativeSize`와 `DiffCoreSize`가 다른지 확인
- 문서 내용 위치가 일정하게 1px 밀렸는지 확인
- text anti-aliasing 차이인지, 실제 도형/표/이미지 누락인지 구분

## 실제 활용 예시

`table-in-tbox.hwp`처럼 core와 native 결과가 크게 다른 파일을 조사할 때:

```bash
./scripts/render-debug-compare.sh output/render-debug /path/to/table-in-tbox.hwp
```

산출물을 나란히 확인한다.

- `table-in-tbox-page1-core.png`: 표, 본문, 안내 문구가 보인다.
- `table-in-tbox-page1-native.png`: 외곽 테두리만 보이고 본문 대부분이 빠져 있다.
- `table-in-tbox-page1-summary.txt`: `TextRuns`, `HangulRuns`, `MissingHangulGlyphs`를 확인한다.

이때 summary에 다음처럼 기록되어 있으면 파싱 실패나 한글 glyph 누락보다는 Swift native renderer 해석 문제를 우선 의심한다.

```text
TextRuns: 471
HangulRuns: 187
HangulScalars: 779
MissingHangulGlyphs: 0
NativeNonWhitePixels: 11845
DiffDifferentPixelRatio: 0.201706
```

판단:

1. core PNG에는 내용이 있으므로 core SVG 경로는 적어도 해당 내용 일부를 알고 있다.
2. render tree에 한글 text run이 있고 glyph 누락도 없으므로 단순 폰트 문제 가능성은 낮다.
3. native PNG가 거의 비어 있으면 `RenderTree.swift` 디코딩 누락, `CGTreeRenderer`의 node 처리, transform, clipping, image data 해석을 먼저 확인한다.
4. 수정 후 같은 명령을 다시 실행해 core/native 차이가 줄었는지 확인한다.
5. 마지막에 `validate-stage3-render.sh`로 기본 샘플 회귀를 확인한다.

## qlmanage 실패 처리

`qlmanage`는 macOS Quick Look server를 사용한다. sandbox 또는 실행 환경에 따라 다음처럼 실패할 수 있다.

```text
sandbox initialization failed: invalid data type of path filter; expected pattern, got boolean
```

이 경우 summary에는 다음이 기록된다.

```text
Diff: not generated
DiffReason: qlmanage rasterize failed; see ...core.svg.qlmanage.log
```

이 상태는 필수 산출물 실패가 아니다. core SVG, native PNG, render tree JSON을 먼저 눈으로 비교하고, pixel diff가 꼭 필요하면 `qlmanage`를 실행할 수 있는 환경에서 다시 실행한다.

## 기존 smoke test와의 관계

기본 렌더링 smoke test는 계속 유지한다.

```bash
./scripts/validate-stage3-render.sh
```

이 명령은 대표 샘플에서 문서 open, render tree, 한글 text run, glyph lookup, page size, native PNG non-white pixel이 깨지지 않았는지 빠르게 확인하는 회귀 테스트다. 반면 `render-debug-compare.sh`는 특정 파일의 렌더링 차이를 좁히기 위한 디버깅 도구다.

권장 순서:

1. 특정 파일에서 차이를 발견하면 `render-debug-compare.sh`로 산출물 생성
2. core SVG와 native PNG를 눈으로 비교
3. render tree JSON으로 누락/해석 문제 분리
4. renderer를 수정했다면 `validate-stage3-render.sh`로 기본 smoke 회귀 확인

## 한컴 viewer 비교와의 경계

한컴 viewer는 최종 사용자가 기대하는 시각 기준에 가깝지만, 이 스크립트의 자동 비교 대상은 아니다.

현재 판단 우선순위:

1. rhwp core가 현재 구현한 결과와 native renderer 결과를 맞춘다.
2. core 자체가 한컴 viewer와 다른 부분은 core 구현 한계 또는 별도 core 개선 작업으로 분리한다.
3. native renderer가 core와 다르면 앱 저장소의 Swift renderer 문제로 다룬다.

## 재현 기록 예시

`table-in-tbox.hwp` 기준 확인값:

```text
NativePNGSize: 794x1123
NativeNonWhitePixels: 11845
RenderTreeJSONBytes: 830673
CoreSVGBytes: 500175
DiffNativeSize: 794x1123
DiffCoreSize: 795x1123
DiffDifferentPixels: 179854
DiffDifferentPixelRatio: 0.201706
```

이 값은 디버깅 출발점이며 정답 기준이 아니다. renderer나 core가 개선되면 값은 달라질 수 있다.
