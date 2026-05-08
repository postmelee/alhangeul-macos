# Task M015 #118 Stage 1 완료보고서

## 단계 목적

`samples/exam_math_no.hwp`와 `samples/eq-01.hwp`에서 `Equation` render tree 노드와 `svg_content` 패턴을 확인하고, 현재 Swift native renderer의 수식 누락 원인을 구현 전 기준으로 고정했다.

이번 단계는 코드 변경 없이 기준 산출물과 Stage 2 구현 범위를 정리하는 조사 단계다.

## 산출물

- 기준 render debug 산출물: `/private/tmp/rhwp-task118-stage1-exam/`
- 추가 수식 샘플 산출물: `/private/tmp/rhwp-task118-stage1-eq/`
- 단계 보고서: `mydocs/working/task_m015_118_stage1.md`

기준 산출물:

- `/private/tmp/rhwp-task118-stage1-exam/exam_math_no-page1-render-tree.json`
- `/private/tmp/rhwp-task118-stage1-exam/exam_math_no-page1-core.svg`
- `/private/tmp/rhwp-task118-stage1-exam/exam_math_no-page1-native.png`
- `/private/tmp/rhwp-task118-stage1-exam/exam_math_no-page1-summary.txt`
- `/private/tmp/rhwp-task118-stage1-eq/eq-01-page1-render-tree.json`
- `/private/tmp/rhwp-task118-stage1-eq/eq-01-page1-core.svg`
- `/private/tmp/rhwp-task118-stage1-eq/eq-01-page1-native.png`
- `/private/tmp/rhwp-task118-stage1-eq/eq-01-page1-summary.txt`

## 본문 변경 정도 / 본문 무손실 여부

소스 코드와 샘플 문서 본문은 변경하지 않았다. Stage 1 변경은 이 단계 보고서 추가뿐이다.

렌더 debug 실행을 위해 worktree에 `Frameworks` symlink를 임시로 만들었으나, 검증 후 제거했다. git 추적 대상에는 포함하지 않았다.

## 검증 결과

작업 브랜치:

```text
## local/task118...origin/devel [ahead 2]
```

샘플 hash:

```text
f4cb91a4deee10c7f2dd704fc96e500c9597c45cb430af9aa730014eb06bbeea  samples/exam_math_no.hwp
d4b5e4730da12395c953d16c026c979adfdf3235eee4be605cef0ab758a7e5ec  samples/eq-01.hwp
```

`exam_math_no.hwp` render debug 결과:

```text
RenderTreeJSONBytes: 217884
CoreSVGBytes: 67323
NativePNGSize: 1028x1490
NativeNonWhitePixels: 24091
TextRuns: 108
HangulRuns: 32
MissingHangulGlyphs: 0
Diff: not generated
DiffReason: qlmanage rasterize failed; see /private/tmp/rhwp-task118-stage1-exam/exam_math_no-page1-core.svg.qlmanage.log
```

`eq-01.hwp` render debug 결과:

```text
RenderTreeJSONBytes: 228819
CoreSVGBytes: 158088
NativePNGSize: 794x1123
NativeNonWhitePixels: 34514
TextRuns: 71
HangulRuns: 37
MissingHangulGlyphs: 0
Diff: not generated
DiffReason: qlmanage rasterize failed; see /private/tmp/rhwp-task118-stage1-eq/eq-01-page1-core.svg.qlmanage.log
```

`exam_math_no.hwp` 1페이지의 `Equation` 노드 통계:

```text
count: 29
min_svg_length: 170
max_svg_length: 5512
first equation bbox: x=95.80000000000001, y=304.03306784660765, width=62.36, height=30.493333333333332
first equation first element: <path d="M1.25,18.74 L2.71,19.48 L7.11,26.52 L9.31,8.92 L19.58,8.92" fill="none" stroke="#000000" stroke-width="0.59"/>
```

`eq-01.hwp` 1페이지의 `Equation` 노드 통계:

```text
count: 3
min_svg_length: 1533
max_svg_length: 3757
first equation bbox: x=198.62000000000012, y=196.70360655737707, width=396.46666666666664, height=39.2
first equation first element: <text x="0.00" y="25.48" font-size="17.33" fill="#000000" font-family="'Latin Modern Math', 'STIX Two Text', 'STIX Two Math', 'Times New Roman', 'Times', serif">평점</text>
```

수식 SVG element 사용 빈도:

```text
exam_math_no.hwp: line 4, path 4, text 99
eq-01.hwp:       line 3, path 8, text 35
```

수식 SVG attribute 사용 빈도:

```text
exam_math_no.hwp: d 4, fill 103, font-family 99, font-size 99, font-style 29, stroke 8, stroke-width 8, text-anchor 13, x 99, x1 4, x2 4, y 99, y1 4, y2 4
eq-01.hwp:       d 8, fill 43, font-family 35, font-size 35, font-style 4, stroke 11, stroke-width 11, text-anchor 5, x 35, x1 3, x2 3, y 35, y1 3, y2 3
```

코드 확인:

```text
Sources/RhwpCoreBridge/RenderTree.swift:58    case equation(EquationNode)
Sources/RhwpCoreBridge/RenderTree.swift:93    if let v = try? keyed.decode(EquationNode.self, forKey: .init("Equation")) { self = .equation(v); return }
Sources/RhwpCoreBridge/RenderTree.swift:330   struct EquationNode: Decodable
Sources/RhwpCoreBridge/CGTreeRenderer.swift:105 case .equation:
Sources/RhwpCoreBridge/CGTreeRenderer.swift:107 break
```

검증 명령:

```bash
git status --short --branch
shasum -a 256 samples/exam_math_no.hwp samples/eq-01.hwp
./scripts/render-debug-compare.sh /private/tmp/rhwp-task118-stage1-exam samples/exam_math_no.hwp
./scripts/render-debug-compare.sh /private/tmp/rhwp-task118-stage1-eq samples/eq-01.hwp
test -s /private/tmp/rhwp-task118-stage1-exam/exam_math_no-page1-render-tree.json
test -s /private/tmp/rhwp-task118-stage1-exam/exam_math_no-page1-native.png
jq '[.. | objects | select(.node_type? | type == "object" and has("Equation"))] | length' /private/tmp/rhwp-task118-stage1-exam/exam_math_no-page1-render-tree.json
rg -n "case \\.equation|struct EquationNode" Sources/RhwpCoreBridge
git diff --check
```

검증 상태:

- `render-debug-compare.sh`는 두 샘플 모두 성공했다.
- 필수 산출물 `render-tree.json`, `core.svg`, `native.png`, `summary.txt`가 생성되었다.
- `git diff --check`는 통과했다.
- `qlmanage` 기반 core SVG raster/diff는 sandbox 문제로 생성되지 않았지만, Stage 1 필수 산출물 실패로 보지 않는다.

## 잔여 위험

- 구현계획서 초안은 Stage 2 subset 예시로 `text`, `line`을 중심으로 적었지만, 실제 샘플에는 `path`도 존재한다. 특히 첫 수식이 `path`로 시작하므로 Stage 2 구현 범위에는 최소한 `M/L` 명령으로 구성된 단순 `path` stroke 처리가 포함되어야 한다.
- 수식 SVG의 `font-family`는 여러 후보를 포함하는 CSS family list 형태다. CoreText 렌더링 전 후보 선택과 fallback이 필요하다.
- `fill="none"`과 `stroke` 계열 속성, `text-anchor="middle"`, `font-style="italic"`은 대표 샘플에 실제로 나타나므로 Stage 2/3에서 누락하면 core SVG와 차이가 크게 남는다.
- `qlmanage` rasterize가 sandbox 문제로 실패해 pixel diff는 Stage 1에서 확보하지 못했다. 이후 단계도 native PNG와 render tree 중심 검증을 기본으로 두고, 가능한 환경에서만 diff를 참고한다.

## 다음 단계 영향

Stage 2는 `Equation.svg_content` parser를 추가하되, 지원 subset을 다음으로 잡는다.

- elements: `text`, `line`, `path`
- text attributes: `x`, `y`, `font-size`, `fill`, `font-family`, `font-style`, `text-anchor`
- line attributes: `x1`, `y1`, `x2`, `y2`, `stroke`, `stroke-width`
- path attributes: `d`, `fill`, `stroke`, `stroke-width`
- path command: 현재 샘플 기준 `M`, `L` 중심의 단순 stroke path 우선

Stage 2에서 이 subset을 draw item으로 변환하고, Stage 3에서 CoreGraphics/CoreText drawing을 연결한다.

## 승인 요청

Stage 1 완료를 승인해 달라. 승인 후 Stage 2 `Equation SVG subset 파서 추가`로 진행한다.
