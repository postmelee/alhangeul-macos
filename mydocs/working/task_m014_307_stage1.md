# Task M014 #307 Stage 1 보고서 - 텍스트 shade sentinel 원인 확인

## 목적

`samples/basic/BookReview.hwp`, `samples/복학원서.hwp`의 CoreGraphics preview에서 텍스트 뒤에 불투명한 흰색 박스가 생기는 원인을 render tree 입력과 renderer 소비 조건 기준으로 확인한다.

## 실행 명령

```bash
./scripts/render-debug-compare.sh build.noindex/task307-stage1 samples/basic/BookReview.hwp samples/복학원서.hwp
jq -r '[.. | objects | select(.node_type.TextRun? != null) | .node_type.TextRun.style.shade_color] as $shades | input_filename + "\n" + (($shades | sort | group_by(.)[] | "  count=\(length) shade=\(.[0])"))' build.noindex/task307-stage1/*page1-render-tree.json
jq -r '.. | objects | select(.node_type.TextRun? != null) | select(.node_type.TextRun.style.shade_color != 0 and .node_type.TextRun.style.shade_color != 16777215) | {file: input_filename, id, bbox, text: .node_type.TextRun.text, shade: .node_type.TextRun.style.shade_color, color: .node_type.TextRun.style.color, font: .node_type.TextRun.style.font_family, size: .node_type.TextRun.style.font_size}' build.noindex/task307-stage1/*page1-render-tree.json
rg -n "fill=\"#fff|fill=\"white|opacity|rgba|rect" build.noindex/task307-stage1/*core.svg
```

분리 worktree에는 gitignore된 `Frameworks/` 산출물이 없으므로, Stage 1 helper 실행을 위해 원본 workspace의 동일 산출물을 가리키는 symlink를 생성했다.

```bash
ln -s /Users/melee/Documents/projects/rhwp-mac/Frameworks Frameworks
```

`Frameworks/`는 gitignore 대상이며 commit 대상이 아니다.

## 산출물

```text
build.noindex/task307-stage1/BookReview-page1-render-tree.json
build.noindex/task307-stage1/BookReview-page1-core.svg
build.noindex/task307-stage1/BookReview-page1-native.png
build.noindex/task307-stage1/BookReview-page1-summary.txt
build.noindex/task307-stage1/복학원서-page1-render-tree.json
build.noindex/task307-stage1/복학원서-page1-core.svg
build.noindex/task307-stage1/복학원서-page1-native.png
build.noindex/task307-stage1/복학원서-page1-summary.txt
```

render helper 실행 중 `BookReview.hwp`에서 2.5px layout overflow 경고가 출력됐지만, 기존 문서 layout overflow이며 이번 shade 원인 확인의 blocker는 아니다.

## shade_color 분포

두 샘플의 첫 페이지 `TextRun`은 모두 `shade_color = 4294967295`를 가진다.

```text
build.noindex/task307-stage1/BookReview-page1-render-tree.json
  count=66 shade=4294967295
build.noindex/task307-stage1/복학원서-page1-render-tree.json
  count=102 shade=4294967295
```

`4294967295`는 `0xFFFFFFFF`다. 현재 `CGTreeRenderer`는 `TextStyle.shadeColor`가 `0x00FFFFFF`와 `0`이 아니면 bbox 전체를 `alpha: 0.3`으로 채운다.

```text
Sources/RhwpCoreBridge/CGTreeRenderer.swift:1533
Sources/RhwpCoreBridge/CGTreeRenderer.swift:1643
```

따라서 `0xFFFFFFFF`가 모든 일반 텍스트에서 실제 shade로 오인되어, `BookReview.hwp` 표지의 제목/큰 글자 뒤와 `복학원서.hwp` 본문 곳곳에 흰색 반투명 박스가 나타난다.

## core SVG 대조

core SVG에는 문서 배경, 도형, 표 외곽선에 해당하는 rect는 있지만, 위 `TextRun` bbox 전체를 30% 흰색으로 칠하는 shade rect는 없다. `BookReview.hwp`의 표지 제목 뒤 박스는 native PNG에서만 확인된다.

따라서 원인은 core render tree의 실제 shade 표현 누락이 아니라 Swift/CoreGraphics 소비 경로의 sentinel 해석 차이로 판단한다.

## Stage 2 구현 결정

- `0xFFFFFFFF`를 텍스트 shade 없음 sentinel로 추가한다.
- `0`, `0x00FFFFFF` no shade 판정은 유지한다.
- 같은 판정을 일반 `renderTextRun`과 centered/rotated/vertical 경로 `renderCenteredTextRun`에 공통 적용한다.
- `colorRefToCGColor`나 실제 shade alpha 정책은 변경하지 않는다.

## 검증

```bash
git diff --check -- mydocs/plans/task_m014_307_impl.md mydocs/working/task_m014_307_stage1.md
```

결과: 통과.
