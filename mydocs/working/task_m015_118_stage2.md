# Task M015 #118 Stage 2 완료보고서

## 단계 목적

`Equation.svg_content`에서 Stage 1로 확정한 SVG subset을 읽어 내부 draw item으로 변환하는 parser를 추가했다.

이번 단계는 parser 추가까지이며, `CGTreeRenderer`의 `.equation` 렌더링 분기는 아직 연결하지 않았다. native drawing은 Stage 3에서 진행한다.

## 산출물

- `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
  - `parseEquationSVG(_:)` helper 추가
  - `EquationSVGDrawItem` / `EquationSVGText` / `EquationSVGLine` / `EquationSVGPath` 모델 추가
  - `EquationSVGFragmentParser` 추가
- 단계 보고서: `mydocs/working/task_m015_118_stage2.md`

변경 규모:

```text
1 file changed, 318 insertions(+)
```

주요 위치:

```text
CGTreeRenderer.swift:278  parseEquationSVG(_:)
CGTreeRenderer.swift:562  EquationSVGDrawItem
CGTreeRenderer.swift:619  EquationSVGFragmentParser
CGTreeRenderer.swift:763  pathCommands(from:)
```

## 본문 변경 정도 / 본문 무손실 여부

소스 변경은 `Sources/RhwpCoreBridge/CGTreeRenderer.swift`에만 있다. 샘플 문서와 기존 렌더 tree 모델은 변경하지 않았다.

기존 `.equation` 분기는 아직 `break` 상태로 유지했다. 따라서 Stage 2 자체는 렌더링 결과를 바꾸지 않고, Stage 3에서 사용할 parser 기반만 추가한다.

## 검증 결과

작업 브랜치:

```text
## local/task118...origin/devel [ahead 3]
 M Sources/RhwpCoreBridge/CGTreeRenderer.swift
```

변경 파일:

```text
Sources/RhwpCoreBridge/CGTreeRenderer.swift
```

AppKit/UIKit 직접 의존 금지 검증:

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

Swift typecheck:

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

결과: 성공. 처음 typecheck에서 `fill="none"` 처리의 optional `.none` 모호성 경고가 나와 `EquationSVGPaint.none`으로 명시 수정했고, 재실행은 출력 없이 통과했다.

구현계획서 Stage 2 검증 명령:

```bash
git status --short --branch
git diff -- Sources/RhwpCoreBridge/CGTreeRenderer.swift Sources/RhwpCoreBridge/RenderTree.swift
./scripts/check-no-appkit.sh
git diff --check -- Sources/RhwpCoreBridge/CGTreeRenderer.swift Sources/RhwpCoreBridge/RenderTree.swift mydocs/working/task_m015_118_stage2.md
```

검증 상태:

- `./scripts/check-no-appkit.sh` 통과
- `git diff --check -- Sources/RhwpCoreBridge/CGTreeRenderer.swift Sources/RhwpCoreBridge/RenderTree.swift mydocs/working/task_m015_118_stage2.md` 통과
- Swift typecheck 통과

## Parser 범위

Stage 1에서 확인한 실제 수식 fragment를 기준으로 다음 subset을 parser에서 처리한다.

- element: `text`, `line`, `path`
- text attributes: `x`, `y`, `font-size`, `fill`, `font-family`, `font-style`, `text-anchor`
- line attributes: `x1`, `y1`, `x2`, `y2`, `stroke`, `stroke-width`
- path attributes: `d`, `fill`, `stroke`, `stroke-width`
- paint: `none`, `#RRGGBB`
- path command: `M`, `L`, `H`, `V`, `Z`

미지원 element와 미지원 속성은 renderer 실패로 만들지 않고 건너뛰도록 했다. path command도 현재 subset 밖의 명령은 무시하고, 파싱 가능한 command만 draw item으로 남긴다.

## 잔여 위험

- Stage 2 parser는 아직 render path에 연결되지 않았다. 실제 수식 표시 여부와 bbox/baseline 보정은 Stage 3에서 검증해야 한다.
- path parser는 `M/L/H/V/Z` subset 중심이다. 향후 core가 curve command를 포함하면 해당 곡선은 누락될 수 있다.
- lowercase path command는 현재 절대 좌표처럼 해석된다. Stage 1 샘플에서는 uppercase 중심이었지만, relative command가 실제 문서에 나오면 보정이 필요하다.
- XMLParser wrapper 방식은 정상 XML fragment에는 적합하지만, XML에서 허용되지 않는 제어문자가 들어오면 해당 fragment 전체 parsing이 실패할 수 있다.

## 다음 단계 영향

Stage 3에서는 다음 작업을 진행한다.

- `.equation` 분기에서 `renderEquation` 호출
- `EquationSVGDrawItem.text`를 CoreText로 drawing
- `EquationSVGDrawItem.line`과 `EquationSVGDrawItem.path`를 CoreGraphics stroke로 drawing
- bbox 기준 좌표 이동, optional clipping, `text-anchor`, italic, 색상 fallback 연결

## 승인 요청

Stage 2 완료를 승인해 달라. 승인 후 Stage 3 `Equation native drawing 구현`으로 진행한다.
