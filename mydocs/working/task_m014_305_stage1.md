# Task M014 #305 Stage 1 보고서 - 복학원서 PUA 입력 경로 확인

## 목적

`samples/복학원서.hwp`의 CoreGraphics preview에서 깨져 보이는 PUA 문자의 render tree 입력과 현재 renderer 소비 지점을 확인하고, Stage 2의 최소 보정 위치를 확정한다.

## 실행 명령

```bash
./scripts/render-debug-compare.sh build.noindex/task305-stage1 samples/복학원서.hwp
jq -r '
  .. | objects | select(.node_type?.TextRun?.text? != null) |
  (.node_type.TextRun.text | explode) as $cps |
  select(any($cps[]; (. >= 57344 and . <= 63743) or (. >= 983040 and . <= 1048573) or (. >= 1048576 and . <= 1114109))) |
  {id, bbox, text: .node_type.TextRun.text, codepoints: $cps, font: .node_type.TextRun.style.font_family, fontSize: .node_type.TextRun.style.font_size, charPositions: .node_type.TextRun.char_positions, baseline: .node_type.TextRun.baseline}
' build.noindex/task305-stage1/*render-tree.json
rg -n "NSAttributedString\\(string: run.text|makeTextRunLayoutPlan|charPositions" \
  Sources/RhwpCoreBridge/CGTreeRenderer.swift
```

분리 worktree에는 gitignore된 `Frameworks/` 산출물이 없으므로, Stage 1 helper 실행을 위해 원본 workspace의 동일 산출물을 가리키는 symlink를 생성했다.

```bash
ln -s /Users/melee/Documents/projects/rhwp-mac/Frameworks Frameworks
```

`Frameworks/`는 gitignore 대상이므로 commit 대상이 아니다.

## 산출물

```text
build.noindex/task305-stage1/복학원서-page1-render-tree.json
build.noindex/task305-stage1/복학원서-page1-core.svg
build.noindex/task305-stage1/복학원서-page1-native.png
build.noindex/task305-stage1/복학원서-page1-summary.txt
```

summary 주요 값:

```text
PageSizePt: 793.7x1122.5
RenderTreeJSONBytes: 196151
CoreSVGBytes: 791753
NativePNGSize: 794x1123
TextRuns: 102
HangulRuns: 25
HangulScalars: 143
MissingHangulGlyphs: 0
```

`qlmanage` 기반 core SVG rasterize는 sandbox/Quick Look 환경 영향으로 실패했지만, Stage 1의 목적은 render tree와 CoreGraphics 입력 확인이므로 blocker로 보지 않는다.

## PUA TextRun inventory

render tree에서 확인된 Private Use codepoint 포함 `TextRun`은 두 개다.

| id | codepoints | bbox | font | fontSize | baseline | charPositions | 판단 |
|---:|---|---|---|---:|---:|---|---|
| 119 | `U+F012B` (`983339`) | `x=367.6333, y=585.4874, w=27.0, h=14.6667` | `HY신명조` | 13.3333 | 12.4667 | 없음 | 서명란 `(인)` 의도 |
| 235 | `U+F081C`, `U+F081C` (`985116`, `985116`) | `x=56.6933, y=793.6533, w=0.0, h=283.9467` | `HY신명조` | 13.3333 | 241.36 | 없음 | 하단 안내문 앞 filler, 숨김 의도 |

core SVG에는 같은 문서에서 `U+F012B`가 원문 PUA가 아니라 `(인)` 표시 문자열로 출력된다. 서명란 인근에서는 `(`, `인`, `)`이 같은 cell clip 안에서 분리된 text node로 확인되었다.

```text
<text x="367.6333333333334" y="597.954060150376" ...>(</text>
<text x="374.30000000000007" y="597.954060150376" ... font-size="13.333333333333334" ...>인</text>
<text x="387.6333333333334" y="597.954060150376" ...>)</text>
```

따라서 upstream core 쪽 표시 문자열 계약은 존재하지만, 현재 Swift/CoreGraphics 기본 경로가 해당 표시 문자열을 소비하지 못하는 상태로 판단한다.

## 현재 CoreGraphics 소비 지점

`CGTreeRenderer.renderTextRun`은 `run.text`를 그대로 CoreText attributed string과 layout plan에 넘긴다.

```text
Sources/RhwpCoreBridge/CGTreeRenderer.swift:1547: NSAttributedString(string: run.text, ...)
Sources/RhwpCoreBridge/CGTreeRenderer.swift:1550: text: run.text
Sources/RhwpCoreBridge/CGTreeRenderer.swift:1555: charPositions: run.charPositions
Sources/RhwpCoreBridge/CGTreeRenderer.swift:1570: NSAttributedString(string: run.text, ...)
Sources/RhwpCoreBridge/CGTreeRenderer.swift:1573: text: run.text
Sources/RhwpCoreBridge/CGTreeRenderer.swift:1578: charPositions: run.charPositions
```

회전/세로쓰기 경로인 `renderCenteredTextRun`도 같은 방식으로 `run.text`를 사용한다.

`TextRunNode` 모델에는 현재 `displayText` 필드가 없고, `text`, `style`, `charPositions`, `baseline` 등을 decode한다.

## Stage 2 구현 결정

- 보정 위치는 `CGTreeRenderer` 내부의 CoreText 문자열 생성 직전으로 제한한다.
- `renderTextRun`과 `renderCenteredTextRun` 모두 같은 helper를 사용한다.
- `U+F012B`는 `(인)`으로 변환한다.
- `U+F081C`는 제거한다.
- 변환 결과가 빈 문자열이면 text run drawing을 생략한다.
- 변환 전후 unicode scalar count가 다르면 `charPositions`를 nil로 처리한다.
- 이번 작업은 확인된 두 codepoint만 다루며, 일반 PUA 전체 매핑은 하지 않는다.

## 리스크와 대응

- `U+F012B`는 원문 1 codepoint에서 `(인)` 3글자로 바뀌므로 bbox 폭과 CoreText 측정값이 기존과 달라진다. 해당 run에는 `charPositions`가 없고 bbox 폭이 27pt로 넉넉하므로 Stage 2에서는 line/cluster layout의 기존 폭 보정 로직에 맡긴다.
- `U+F081C` run은 bbox width가 0이고 filler 성격이므로 숨김 처리해도 사용자-facing 내용 손실 가능성이 낮다.
- long-term 해법은 PageLayerTree `displayText` 소비이며, 이 임시 보정은 v0.1.4 release-blocking 결함 해소로 범위를 제한한다.

## 검증

```bash
git diff --check -- mydocs/plans/task_m014_305_impl.md mydocs/working/task_m014_305_stage1.md
```

결과: 통과.
