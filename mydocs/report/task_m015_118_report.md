# Task M015 #118 최종 보고서

## 작업 개요

- 이슈: #118 Swift native renderer 수식(Equation) 렌더링 추가
- 마일스톤: M015 (`첫 출시 전 Swift 렌더 보강`)
- 브랜치: `local/task118`
- 핵심 변경: core PageRenderTree의 `Equation.svg_content`를 Swift native renderer에서 제한된 SVG subset으로 파싱하고 CoreGraphics/CoreText로 렌더링
- 기준 샘플: `samples/exam_math_no.hwp`, `samples/eq-01.hwp`

## 완료 내용

`exam_math_no.hwp`에서 수식이 보이지 않던 원인은 Swift native renderer가 `Equation` node를 아무것도 그리지 않고 건너뛰는 동작 때문으로 확인했다.

render tree에는 `Equation` node와 `svg_content`가 존재했고, core SVG에는 수식이 포함되어 있었다. 이번 작업에서는 HWP 수식 문법을 새로 파싱하지 않고, core가 만든 equation SVG fragment 중 실제 샘플에 필요한 subset을 Swift renderer에서 처리하도록 했다.

구현 내용:

- `EquationNode`가 core의 `layout_box`를 optional로 decode하도록 보강
- `CGTreeRenderer`의 `.equation` 분기에서 `renderEquation` 호출
- equation `layout_box`와 node `bbox`를 이용한 좌표 scale 적용
- SVG fragment의 `text`, `line`, `path` 요소 파싱
- text 속성 `x`, `y`, `font-size`, `fill`, `font-family`, `font-style`, `text-anchor` 처리
- line/path stroke와 fill의 `#RRGGBB`, `none` 처리
- path command `M/L/H/V/Q/Z`와 relative variant 처리
- CoreText 기반 수식 텍스트 drawing, `text-anchor`와 italic 보정
- AppKit/UIKit/WebKit 의존 없이 Foundation/CoreGraphics/CoreText 범위에서 구현

미지원 SVG 요소나 속성은 전체 렌더 실패로 만들지 않고 해당 요소만 건너뛰도록 했다.

## 변경 파일과 영향 범위

| 파일 | 내용 |
|------|------|
| `Sources/RhwpCoreBridge/CGTreeRenderer.swift` | Equation node의 SVG subset 파싱과 CoreGraphics/CoreText 기반 native drawing을 추가 |
| `Sources/RhwpCoreBridge/RenderTree.swift` | Equation node에서 core `layout_box`를 optional로 decode하도록 보강 |
| `mydocs/plans/task_m015_118.md` | Task #118 수행 계획과 승인 요청 사항 기록 |
| `mydocs/plans/task_m015_118_impl.md` | Stage 1-5 구현 계획, 검증 명령, 완료 기준 기록 |
| `mydocs/working/task_m015_118_stage1.md` | 기준 샘플 render tree와 기존 수식 누락 원인 정리 |
| `mydocs/working/task_m015_118_stage2.md` | Equation SVG subset 파서 범위와 fallback 정책 정리 |
| `mydocs/working/task_m015_118_stage3.md` | native drawing 구현 결과와 좌표/font 처리 기록 |
| `mydocs/working/task_m015_118_stage4.md` | `exam_math_no.hwp`, `eq-01.hwp` 샘플 검증과 보정 결과 기록 |
| `mydocs/working/task_m015_118_stage5.md` | 통합 검증 결과와 최종 보고 준비 상태 기록 |
| `mydocs/report/task_m015_118_report.md` | 최종 작업 결과, 정량 비교, 검증 결과, 잔여 위험 정리 |
| `mydocs/orders/20260502.md` | 오늘할일 #118 완료 상태 기록 |

## 검증 요약

### Stage 1 기준 재현

```text
exam_math_no.hwp Equation nodes: 29
eq-01.hwp Equation nodes: 3
exam_math_no.hwp NativeNonWhitePixels: 24091
eq-01.hwp NativeNonWhitePixels: 34514
```

core SVG에는 수식이 있었지만 native PNG에는 수식이 표시되지 않았다.

### Stage 3 구현 후 검증

```text
exam_math_no.hwp NativeNonWhitePixels: 28151
TextRuns: 108
HangulRuns: 32
MissingHangulGlyphs: 0
```

`exam_math_no.hwp` native PNG에서 1번 문항의 세제곱근/분수 지수, 2번 문항의 함수/극한/분수식, 3번과 4번 문항의 수식이 표시되는 것을 확인했다.

### Stage 4 샘플 검증

```text
exam_math_no.hwp NativeNonWhitePixels: 28151
eq-01.hwp       NativeNonWhitePixels: 45341
```

Stage 1 대비 변화:

```text
exam_math_no.hwp: 24091 -> 28151 (+4060)
eq-01.hwp:       34514 -> 45341 (+10827)
```

`eq-01.hwp` native PNG에서 긴 평가식, 분수선, 괄호 path, `2x` 항이 표시되는 것을 확인했다.

### Stage 5 통합 검증

```text
./scripts/check-no-appkit.sh
OK: shared Swift code has no AppKit/UIKit dependencies
```

```text
./scripts/validate-stage3-render.sh
OK KTX.hwp: page=1 size=1123x794 textRuns=436 hangulRuns=76 hangulScalars=209 nonWhitePixels=452058
OK request.hwp: page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=67872
OK exam_kor.hwp: page=1 size=1123x1588 textRuns=133 hangulRuns=86 hangulScalars=1368 nonWhitePixels=176579
```

```text
xcodegen generate
Created project at /tmp/rhwp-mac-task118/AlhangeulMac.xcodeproj
```

```text
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
** BUILD SUCCEEDED ** [12.417 sec]
```

```text
./scripts/render-debug-compare.sh /private/tmp/rhwp-task118-final samples/exam_math_no.hwp
NativeNonWhitePixels: 28151
TextRuns: 108
HangulRuns: 32
MissingHangulGlyphs: 0
```

`git diff --check`도 통과했다.

## 제한 사항

- 이번 작업은 core `Equation.svg_content` 중 확인된 SVG subset 렌더링만 다룬다.
- SVG 전체 구현이 아니며 `text`, `line`, `path`의 제한된 속성과 path command만 지원한다.
- PageLayerTree ABI 추가나 기본 렌더 경로 전환은 하지 않았다.
- 수식 편집, MathML, LaTeX, HWP 수식 문법 직접 파싱은 범위가 아니다.
- core SVG rasterize는 로컬 `qlmanage` sandbox 오류로 실패해 pixel diff를 생성하지 못했다.

## 잔여 위험

- CoreText font fallback 차이로 core SVG 또는 한컴 viewer와 글자 폭, baseline, 괄호 곡선 모양이 완전히 같지 않을 수 있다.
- cubic curve, arc, nested transform, complex paint 같은 SVG 기능이 포함된 수식은 후속 보강이 필요하다.
- `origin/devel`이 작업 브랜치보다 9 commit 앞서 있으므로 PR 게시 전 최신 `devel`과의 통합 상태를 확인해야 한다.

## 결론

Issue #118의 목표인 Swift native renderer의 수식 누락은 기준 샘플 범위에서 해결됐다.

HostApp, Quick Look, Thumbnail이 공유하는 renderer 경로에서 `Equation` node가 native PNG에 표시되며, bridge 경계 검증과 HostApp Debug build도 통과했다.
