# Task M015 #106 Stage 1 완료 보고서

## 단계 목적

`samples/복학원서.hwp`에서 Swift native renderer 이미지 출력이 core SVG와 달라지는 기준 상태를 재현하고, Stage 2/3 구현에 필요한 이미지 필드와 단위 해석을 확정했다.

이번 단계는 source code 변경 없이 render debug 산출물과 기존 Swift 구현 상태만 조사했다.

## 산출물

| 구분 | 경로 또는 값 | 요약 |
|------|--------------|------|
| 기준 샘플 | `samples/복학원서.hwp` | SHA-256 `da81b4010331bcac290f900c7cf224c97ee8355399614725ce46c197ff1a22a4` |
| render debug 출력 | `/private/tmp/rhwp-task106-stage1` | render tree JSON, core SVG, native PNG, summary 생성 |
| 단계 보고서 | `mydocs/working/task_m015_106_stage1.md` | Stage 1 조사 결과 |

## 본문 변경 정도 / 본문 무손실 여부

문서 본문 또는 코드 본문은 변경하지 않았다.

분리 worktree에는 render-debug 실행에 필요한 generated `Frameworks/` 산출물이 없어, 기존 worktree의 generated `Frameworks/`를 복사해 검증에 사용했다. 해당 산출물은 git 추적 대상이 아니며 이번 단계 커밋 범위에 포함하지 않는다.

## 조사 결과

`render-debug-compare.sh` summary 핵심값:

| 항목 | 값 |
|------|----|
| PageCount | 1 |
| PageSizePt | `793.7x1122.5` |
| RenderTreeJSONBytes | 189498 |
| CoreSVGBytes | 380803 |
| NativePNGSize | `794x1123` |
| NativeNonWhitePixels | 154266 |
| TextRuns / HangulRuns | `102 / 25` |
| MissingHangulGlyphs | 0 |
| Diff | `not generated` |
| DiffReason | `qlmanage rasterize failed; see ...core.svg.qlmanage.log` |

render tree의 이미지 노드는 2개다.

| id | bin | bbox | crop | original_size_hu | effect | brightness | contrast | 판단 |
|----|-----|------|------|------------------|--------|------------|----------|------|
| 84 | 2 | `137.7067,270.24,495.04,495.7333` | `[0,0,54600,54660]` | `[37128,37180]` | `GrayScale` | -50 | 70 | 워터마크 대상 |
| 7 | 1 | `65.4933,49.0133,77.0133,87.8933` | `[0,0,65640,74940]` | `[5776,6592]` | `RealPic` | 0 | 0 | 상단 소형 이미지, 이번 효과 보강의 주 대상 아님 |

워터마크 이미지(id 84)의 crop 값은 75 HU/px 기준으로 `54600 / 75 = 728`, `54660 / 75 = 728.8`이다. core SVG에 embedded 된 JPEG는 `728x729`로 확인되어, crop source rect 계산은 crop HU 값을 75로 나눈 뒤 원본 pixel bounds로 clamp하는 방향이 맞다.

`original_size_hu`는 bbox와 같은 display size 계열 값으로 보인다. 워터마크 bbox `495.04x495.7333`에 75를 곱하면 `37128x37180`으로 render tree의 `original_size_hu`와 일치한다. 따라서 Stage 2의 crop source rect는 `original_size_hu`가 아니라 `crop / 75`와 실제 `CGImage` pixel 크기를 기준으로 계산한다.

core SVG는 워터마크 이미지에 다음 필터를 적용한다.

```xml
<filter id="rhwp-img-grayscale"><feColorMatrix type="matrix" values="0.299 0.587 0.114 0 0 0.299 0.587 0.114 0 0 0.299 0.587 0.114 0 0 0 0 0 1 0"/></filter>
<filter id="rhwp-img-bc-b-50c70"><feComponentTransfer><feFuncR type="linear" slope="1.7000" intercept="-0.8500"/><feFuncG type="linear" slope="1.7000" intercept="-0.8500"/><feFuncB type="linear" slope="1.7000" intercept="-0.8500"/></feComponentTransfer></filter>
```

Swift 현재 구현의 누락 지점:

- `RenderTree.swift`의 `ImageNode`는 `effect`, `brightness`, `contrast`, `original_size_hu`를 디코딩하지 않는다.
- `CGTreeRenderer.renderImage`는 `crop`을 draw에 적용하지 않고 원본 `CGImage` 전체를 bbox에 그린다.
- `CGTreeRenderer.renderImage`는 색상 effect 또는 brightness/contrast 필터를 적용하지 않는다.

Stage 2 구현 방향:

- `ImageNode`에 `effect`, `brightness`, `contrast`, `originalSizeHU` optional 필드를 추가한다.
- source crop rect는 `crop` 4개 값을 75로 나눈 pixel 좌표로 계산하고, 원본 이미지 bounds로 clamp한다.
- crop rect가 비정상이거나 `cropping(to:)`가 실패하면 기존 전체 이미지 draw로 fallback한다.

Stage 3 구현 방향:

- `GrayScale`은 core SVG와 같은 luminance matrix 방향으로 처리한다.
- brightness/contrast는 core SVG의 `feComponentTransfer`와 같은 방향으로 slope/intercept를 적용한다. 현재 샘플 기준은 `contrast=70 -> slope 1.7`, `brightness=-50 -> intercept -0.85`다.
- `RealPic`은 보정 없이 원본 표시로 취급한다.

## 검증 결과

작업 브랜치 상태 확인:

```text
## local/task106...origin/devel [ahead 2]
```

샘플 hash:

```text
da81b4010331bcac290f900c7cf224c97ee8355399614725ce46c197ff1a22a4  samples/복학원서.hwp
```

render debug 실행:

```text
OK 복학원서.hwp: page=1 renderTreeJSON=/private/tmp/rhwp-task106-stage1/...-render-tree.json coreSVG=/private/tmp/rhwp-task106-stage1/...-core.svg nativePNG=/private/tmp/rhwp-task106-stage1/...-native.png summary=/private/tmp/rhwp-task106-stage1/...-summary.txt
```

필수 산출물 확인:

```text
test -s render-tree.json: 통과
test -s core.svg: 통과
test -s native.png: 통과
test -s summary.txt: 통과
```

이미지 source 확인:

```text
core-image-1: JPEG 728x729
core-image-2: PCX bounding box [0, 0] - [877, 1000], 1-bit colour
```

`git diff --check`:

```text
통과
```

## 잔여 위험

- core SVG rasterize와 pixel diff는 `qlmanage` sandbox 오류로 생성되지 않았다. 필수 산출물인 render tree JSON, core SVG, native PNG, summary는 생성됐다.
- brightness/contrast 수식은 core SVG 필터의 slope/intercept 방향으로 맞출 수 있으나, 색공간과 alpha 처리 때문에 완전 pixel parity는 Stage 3 검증에서 별도 확인이 필요하다.
- 상단 소형 이미지(id 7)는 core SVG에서 PCX로 확인됐다. 이번 이슈의 주 대상은 워터마크 crop/effect/brightness/contrast이며, PCX 변환 정책 재설계는 수행계획서 제외 범위다.

## 다음 단계 영향

Stage 2에서는 `RenderTree.swift`와 `CGTreeRenderer.swift`를 변경해 이미지 필드 디코딩과 crop source rect 적용을 구현한다. 이 단계에서는 색상 effect를 아직 적용하지 않고, crop과 draw 좌표 안정성만 검증한다.

## 승인 요청

Stage 1 완료를 승인하고 Stage 2 `ImageNode 디코딩과 crop source rect 적용`으로 진행해도 되는지 승인 요청한다.
