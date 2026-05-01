# Task M015 #108 Stage 1 완료 보고서

## 단계 목적

`samples/basic/BookReview.hwp`에서 텍스트가 보이지 않는 현상을 현재 브랜치에서 재현하고, 원인이 Swift native renderer의 도형 children 미순회인지 확인했다.

이번 단계는 조사와 기준 산출물 고정만 수행했으며 source code는 변경하지 않았다.

## 산출물

기준 산출물 위치:

- `/private/tmp/rhwp-task108-stage1/BookReview-page1-render-tree.json`
- `/private/tmp/rhwp-task108-stage1/BookReview-page1-core.svg`
- `/private/tmp/rhwp-task108-stage1/BookReview-page1-native.png`
- `/private/tmp/rhwp-task108-stage1/BookReview-page1-summary.txt`
- `/private/tmp/rhwp-task108-stage1/BookReview-page1-core.svg.qlmanage.log`

산출물 크기:

| 파일 | 크기 |
|------|------|
| render tree JSON | 100,010 bytes |
| core SVG | 70,430 bytes |
| native PNG | 21,816 bytes, 794x1123 |
| summary | 812 bytes |

샘플 hash:

```text
042aeac46996c035dfb6ce83e8b383dd66f7ae5377281d9c797917ba1b1d7d8f  samples/basic/BookReview.hwp
```

## 본문 변경 정도 / 본문 무손실 여부

문서 본문과 source code 변경은 없다.

이번 단계의 저장소 변경 대상은 이 단계 보고서뿐이다.

## 조사 결과

`BookReview.hwp` page 1의 render tree에는 텍스트 노드가 존재한다.

```text
TextLine: 34
TextRun: 66
HangulRuns: 28
MissingHangulGlyphs: 0
```

render tree의 `Rectangle` 노드 4개 중 3개가 children을 가진다.

| Rectangle id | bbox 요약 | child count | 대표 text |
|--------------|-----------|-------------|-----------|
| 32 | x=0.36, y=0.00, w=792.0, h=469.0 | 4 | `단순`, `하면서도`, `강력`, `재테크` |
| 50 | x=40.36, y=509.00, w=714.0, h=503.0 | 15 | `프롤로그_부자로 은퇴하려면...`, `1장_...`, `2장_...` |
| 100 | x=552.13, y=990.28, w=191.96, h=57.95 | 2 | `강우신 지음`, `원앤원북스 / 2006년...` |
| 111 | x=37.80, y=37.80, w=718.11, h=277.33 | 0 | 없음 |

core SVG에도 텍스트가 있다.

```text
rg -c '<text' /private/tmp/rhwp-task108-stage1/BookReview-page1-core.svg
247
```

반면 native PNG를 시각 확인하면 상단 salmon 색 도형, 하단 점선 사각형, 우하단 작은 사각형만 보이고 텍스트는 보이지 않는다.

Swift renderer의 현재 순회 정책은 다음과 같다.

- `.rectangle`, `.line`, `.ellipse`, `.path`, `.image`는 자기 자신만 렌더하고 children을 순회하지 않는다.
- `.page`, `.body`, `.tableCell`, `.group`, default 구조 노드는 children을 순회한다.
- 따라서 `Rectangle` children 아래의 `TextLine`/`TextRun`은 현재 native renderer에서 도달하지 못한다.

core PageLayerTree builder의 목표 순서는 own leaf 후 children이다.

- `LayerBuilder`는 renderable node에 대해 own `PaintOp` leaf를 먼저 만든다.
- children이 있으면 `children.push(own_leaf)` 후 `children.extend(self.build_children(node))` 순서로 group을 만든다.
- Stage 2 구현은 이 순서에 맞춰 Swift에서도 도형 자신을 먼저 그리고 children을 뒤에 그리는 방향이 적절하다.

## 검증 결과

검증 명령:

```bash
git status --short --branch
shasum -a 256 samples/basic/BookReview.hwp
./scripts/render-debug-compare.sh /private/tmp/rhwp-task108-stage1 samples/basic/BookReview.hwp
test -s /private/tmp/rhwp-task108-stage1/BookReview-page1-render-tree.json
test -s /private/tmp/rhwp-task108-stage1/BookReview-page1-core.svg
test -s /private/tmp/rhwp-task108-stage1/BookReview-page1-native.png
sed -n '1,120p' /private/tmp/rhwp-task108-stage1/BookReview-page1-summary.txt
sed -n '40,120p' Sources/RhwpCoreBridge/CGTreeRenderer.swift
sed -n '45,125p' /Users/melee/.cargo/git/checkouts/rhwp-6f8f299952213fc0/0fb3e67/src/paint/builder.rs
git diff --check
```

핵심 출력:

```text
OK BookReview.hwp: page=1 renderTreeJSON=/private/tmp/rhwp-task108-stage1/BookReview-page1-render-tree.json coreSVG=/private/tmp/rhwp-task108-stage1/BookReview-page1-core.svg nativePNG=/private/tmp/rhwp-task108-stage1/BookReview-page1-native.png summary=/private/tmp/rhwp-task108-stage1/BookReview-page1-summary.txt

PageCount: 2
PageSizePt: 793.7x1122.5
RenderTreeJSONBytes: 100010
CoreSVGBytes: 70430
NativePNGSize: 794x1123
NativeNonWhitePixels: 377463
TextRuns: 66
HangulRuns: 28
MissingHangulGlyphs: 0
Diff: not generated
DiffReason: qlmanage rasterize failed; see /private/tmp/rhwp-task108-stage1/BookReview-page1-core.svg.qlmanage.log
```

`qlmanage` rasterize 실패 로그:

```text
sandbox initialization failed: invalid data type of path filter; expected pattern, got boolean
```

`git diff --check`는 오류 없이 통과했다.

## 잔여 위험

- Stage 2에서 도형 children을 순회하면 일부 문서의 draw order가 기존보다 달라질 수 있다. 다만 이는 core PageLayerTree builder의 own leaf 후 children 순서와 일치하는 방향이다.
- 도형 내부 clipping은 이번 단계에서 별도 clipping 근거를 확인하지 않았다. Stage 2는 clipping 일반화 없이 순회 누락만 보강하는 것이 안전하다.
- `Image` children 순회까지 같이 적용할 때 image 위/아래 draw order 차이를 Stage 3에서 smoke로 확인해야 한다.
- core SVG rasterize가 `qlmanage` sandbox 오류로 실패해 Stage 1에서는 pixel diff를 생성하지 못했다.

## 다음 단계 영향

Stage 2에서는 `Sources/RhwpCoreBridge/CGTreeRenderer.swift`의 다음 node type에서 self draw 후 `renderChildren`을 호출하도록 보강한다.

- `Rectangle`
- `Line`
- `Ellipse`
- `Path`
- `Image`

이 변경은 `TextRun`, `Equation`, `FormObject`, `FootnoteMarker`의 렌더링 범위를 넓히지 않는다.

## 승인 요청

Stage 1 결과, `BookReview.hwp` 텍스트 누락은 core text export 문제가 아니라 Swift native renderer의 도형 children 미순회 문제로 판단한다.

Stage 2 `CGTreeRenderer` 도형 children 순회 보강으로 진행할지 승인 요청한다.
