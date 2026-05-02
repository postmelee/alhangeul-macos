# Task M015 #118 Stage 3 완료보고서

## 단계 목적

Stage 2에서 추가한 `Equation.svg_content` parser 결과를 CoreGraphics/CoreText drawing에 연결해 `Equation` 노드를 native PNG에 표시했다.

이번 단계의 기준 샘플은 `samples/exam_math_no.hwp`이며, 수식 텍스트, 분수선, 단순 path stroke가 실제 native renderer 결과에 나타나는지 확인했다.

## 산출물

- `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
  - `.equation` 분기에서 `renderEquation` 호출
  - bbox와 `layout_box` 기반 scale 적용
  - equation text/line/path drawing 추가
  - `text-anchor`, italic, color fallback, font fallback 처리 추가
  - path `Q/q` quadratic command와 relative command 보강
- `Sources/RhwpCoreBridge/RenderTree.swift`
  - `EquationNode.layoutBox` optional decode 추가
  - `EquationLayoutBox` 모델 추가
- Stage 3 render debug 산출물: `/private/tmp/rhwp-task118-stage3-exam/`
- 단계 보고서: `mydocs/working/task_m015_118_stage3.md`

변경 규모:

```text
Sources/RhwpCoreBridge/CGTreeRenderer.swift | 293 +++++++++++++++++++++++++++-
Sources/RhwpCoreBridge/RenderTree.swift     |  10 +
2 files changed, 294 insertions(+), 9 deletions(-)
```

## 본문 변경 정도 / 본문 무손실 여부

샘플 문서와 문서 본문 데이터는 변경하지 않았다.

`RenderTree.swift`는 기존 `EquationNode` 디코딩을 보존하면서 `layout_box`만 optional로 추가했다. 기존 JSON에 `layout_box`가 없어도 decode가 실패하지 않도록 했다.

## 검증 결과

작업 브랜치:

```text
## local/task118...origin/devel [ahead 4]
 M Sources/RhwpCoreBridge/CGTreeRenderer.swift
 M Sources/RhwpCoreBridge/RenderTree.swift
```

구현계획서 Stage 3 검증 명령:

```bash
git status --short --branch
git diff -- Sources/RhwpCoreBridge/CGTreeRenderer.swift Sources/RhwpCoreBridge/FontFallback.swift
./scripts/check-no-appkit.sh
./scripts/render-debug-compare.sh /private/tmp/rhwp-task118-stage3-exam samples/exam_math_no.hwp
test -s /private/tmp/rhwp-task118-stage3-exam/exam_math_no-page1-native.png
sed -n '1,140p' /private/tmp/rhwp-task118-stage3-exam/exam_math_no-page1-summary.txt
git diff --check
```

추가 검증:

```bash
swiftc -typecheck -parse-as-library \
  -module-cache-path /private/tmp/rhwp-task118-swift-module-cache \
  -Xcc -fmodules-cache-path=/private/tmp/rhwp-task118-clang-module-cache \
  -I /Users/melee/Documents/projects/rhwp-mac/Frameworks/modulemap \
  Sources/RhwpCoreBridge/RhwpDocument.swift \
  Sources/RhwpCoreBridge/RenderTree.swift \
  Sources/RhwpCoreBridge/FontFallback.swift \
  Sources/RhwpCoreBridge/CGTreeRenderer.swift \
  -framework CoreGraphics \
  -framework CoreText \
  -framework ImageIO \
  -framework Security \
  -framework CoreFoundation
```

검증 상태:

- `./scripts/check-no-appkit.sh` 통과
- Swift typecheck 통과
- `render-debug-compare.sh` 성공
- `test -s /private/tmp/rhwp-task118-stage3-exam/exam_math_no-page1-native.png` 통과
- `git diff --check` 통과

`exam_math_no.hwp` Stage 3 summary:

```text
RenderTreeJSONBytes: 217884
CoreSVGBytes: 67323
NativePNGSize: 1028x1490
NativeNonWhitePixels: 28151
TextRuns: 108
HangulRuns: 32
MissingHangulGlyphs: 0
Diff: not generated
DiffReason: qlmanage rasterize failed; see /private/tmp/rhwp-task118-stage3-exam/exam_math_no-page1-core.svg.qlmanage.log
```

Stage 1 기준과 비교:

```text
Stage 1 NativeNonWhitePixels: 24091
Stage 3 NativeNonWhitePixels: 28151
증가량: +4060
```

PNG 확인:

- `/private/tmp/rhwp-task118-stage3-exam/exam_math_no-page1-native.png`를 확인했다.
- 1번 문항의 세제곱근/분수 지수, 보기 숫자, 2번 문항의 함수/극한/분수식, 3번과 4번 문항의 수식이 native PNG에 표시된다.

## 구현 메모

- core SVG가 equation group에 `translate(bbox.x, bbox.y) scale(bbox.width/layout_box.width, bbox.height/layout_box.height)` 형태를 사용하므로 Swift renderer도 `EquationNode.layoutBox`를 decode해 같은 기준으로 scale한다.
- 수식 text는 local SVG 좌표의 `y`를 baseline으로 보고 CoreText drawing 직전에만 y축을 반전한다.
- `text-anchor="middle"`과 `text-anchor="end"`는 `CTLineGetTypographicBounds`의 width로 보정한다.
- 수식 path는 Stage 2의 `M/L/H/V/Z`에 더해 `Q/q` quadratic command를 추가했다. `eq-01.hwp`의 괄호 path가 `Q`를 사용하기 때문에 Stage 4 검증을 대비한 보강이다.
- 한글이 포함된 equation text는 `AppleMyungjo`를 우선 사용하고, 라틴/수학 텍스트는 CSS family list에서 `Times New Roman`, `Times`, STIX 후보를 보수적으로 매핑한다.

## 잔여 위험

- `exam_math_no.hwp` 기준으로는 수식 표시가 회복됐지만, `eq-01.hwp`의 긴 수식과 괄호 path는 Stage 4에서 별도 검증과 보정이 필요하다.
- font fallback은 완전한 math font 선택이 아니다. 설치된 STIX/Latin Modern 계열 폰트 유무에 따라 폭과 baseline이 core SVG와 다를 수 있다.
- path 지원은 `M/L/H/V/Q/Z` subset이다. cubic curve, arc, transform 같은 SVG 기능이 나오면 후속 보강이 필요하다.
- `qlmanage` rasterize가 sandbox 문제로 실패해 pixel diff는 확보하지 못했다. Stage 4에서도 native PNG와 summary 중심으로 검증한다.

## 다음 단계 영향

Stage 4에서는 다음을 확인한다.

- `samples/exam_math_no.hwp`와 `samples/eq-01.hwp` 모두에서 수식이 native PNG에 표시되는지 검증
- 긴 한글 수식, 분수선, 괄호 quadratic path, anchor 보정 상태 확인
- 필요 시 bbox/font/line/path 보정을 Stage 4 범위 안에서 추가

## 승인 요청

Stage 3 완료를 승인해 달라. 승인 후 Stage 4 `수식 샘플 렌더 검증과 보정`으로 진행한다.
