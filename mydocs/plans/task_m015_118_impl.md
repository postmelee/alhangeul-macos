# Task M015 #118 구현 계획서

수행계획서: `mydocs/plans/task_m015_118.md`

각 단계 완료 후 `task-stage-report` 절차로 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #118 Swift native renderer 수식(Equation) 렌더링 추가
- 마일스톤: M015 (`첫 출시 전 Swift 렌더 보강`)
- 브랜치: `local/task118`
- 작업 위치: `/private/tmp/rhwp-mac-task118`
- 주 대상: `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- 기준 샘플: `samples/exam_math_no.hwp`, `samples/eq-01.hwp`
- 목표: core PageRenderTree의 `Equation.svg_content`를 Swift native renderer에서 그려 HostApp, Quick Look, Thumbnail 공통 렌더 경로의 수식 누락을 줄인다.

## 구현 원칙

- 제품 기준 경로는 기존 `rhwp_render_page_tree` + Swift `RenderTree` + `CGTreeRenderer` 경로를 유지한다.
- PageLayerTree ABI 추가 또는 기본 렌더 경로 전환은 하지 않는다.
- `Sources/RhwpCoreBridge`에는 AppKit/UIKit/WebKit 직접 의존을 추가하지 않는다.
- HWP 수식 문법을 새로 파싱하지 않고, core가 만든 `Equation.svg_content`의 필요한 SVG subset만 처리한다.
- 임의 SVG 전체 기능을 목표로 하지 않는다. 실제 샘플에서 확인된 `text`, `line`, 기본 좌표/색상/크기/anchor/italic 속성부터 지원한다.
- 미지원 SVG 요소는 전체 렌더 실패로 만들지 않고 해당 요소만 건너뛰는 fallback으로 둔다.
- 기존 text run, image, shape 렌더링의 좌표계와 clipping 정책을 깨지 않는다.

## Stage 1. 수식 fragment 기준 조사와 누락 재현

### 목표

- `exam_math_no.hwp`와 `eq-01.hwp`의 render tree에서 `Equation` 노드와 `svg_content` 패턴을 정리한다.
- 현재 native renderer가 `.equation`에서 아무것도 그리지 않는 것을 기준 산출물로 남긴다.
- 구현할 SVG subset과 Stage 2 범위를 확정한다.

### 작업

- 두 샘플의 파일 hash를 기록한다.
- `render-debug-compare.sh`로 변경 전 기준 산출물을 생성한다.
- render tree JSON에서 `Equation` 노드 수, bbox, `svg_content` 길이, 사용 SVG element/attribute 목록을 추출한다.
- core SVG에는 수식이 포함되고 native PNG에는 빠지는 대표 위치를 기록한다.
- 현재 `CGTreeRenderer`의 `.equation` 분기와 `EquationNode` 모델을 확인한다.
- Stage 1 보고서에 기준 산출물, 누락 원인, 지원 대상 SVG subset을 기록한다.

### 예상 변경 파일

- `mydocs/working/task_m015_118_stage1.md`

### 검증

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

### 완료 기준

- 수식 누락이 Swift native renderer의 `.equation` 미구현 때문임이 보고서에 기록된다.
- 실제 샘플 기준으로 Stage 2에서 지원할 SVG element/attribute subset이 정리된다.
- source code 변경 없이 기준 산출물과 판단 근거가 정리된다.

### 커밋 메시지

```text
Task #118 Stage 1: 수식 렌더링 누락 기준 조사
```

## Stage 2. Equation SVG subset 파서 추가

### 목표

- `Equation.svg_content`에서 Stage 1로 확정한 작은 SVG subset을 안전하게 읽는 내부 파서를 추가한다.
- 파서는 Foundation/CoreGraphics/CoreText 범위 안에서 동작하며 AppKit/UIKit/WebKit에 의존하지 않는다.

### 작업

- `CGTreeRenderer` 내부 또는 좁은 private helper로 equation SVG fragment 파서 모델을 추가한다.
- XML fragment를 안전하게 wrapper로 감싼 뒤 `XMLParser` 또는 제한된 구조 파서로 `text`, `line` 요소를 읽는다.
- `x`, `y`, `font-size`, `fill`, `font-style`, `font-family`, `text-anchor`, line 좌표와 stroke 속성을 파싱한다.
- HTML entity와 XML escape 처리 결과가 수식 문자에 반영되는지 확인한다.
- 미지원 요소/속성은 실패가 아니라 skip으로 처리한다.
- Stage 2 보고서에 parser 입력, 지원 속성, fallback 정책을 기록한다.

### 예상 변경 파일

- `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- 필요 시 `Sources/RhwpCoreBridge/RenderTree.swift`
- `mydocs/working/task_m015_118_stage2.md`

### 검증

```bash
git status --short --branch
git diff -- Sources/RhwpCoreBridge/CGTreeRenderer.swift Sources/RhwpCoreBridge/RenderTree.swift
./scripts/check-no-appkit.sh
git diff --check -- Sources/RhwpCoreBridge/CGTreeRenderer.swift Sources/RhwpCoreBridge/RenderTree.swift mydocs/working/task_m015_118_stage2.md
```

### 완료 기준

- 수식 SVG fragment에서 지원 대상 요소가 내부 draw item으로 변환된다.
- 미지원 요소가 있어도 renderer 전체가 실패하지 않는다.
- AppKit/UIKit 직접 의존 금지 검증이 통과한다.

### 커밋 메시지

```text
Task #118 Stage 2: Equation SVG subset 파서 추가
```

## Stage 3. Equation native drawing 구현

### 목표

- Stage 2 파서 결과를 CoreGraphics/CoreText로 그려 `Equation` 노드를 native PNG에 표시한다.
- bbox 기준 좌표, text baseline, text-anchor, italic, 색상, 선 그리기를 안정화한다.

### 작업

- `renderNode`의 `.equation` 분기에서 `renderEquation`을 호출한다.
- equation bbox를 기준으로 local SVG 좌표를 page 좌표로 이동한다.
- 수식 텍스트는 CoreText로 그리며 `Latin Modern Math`, `STIX Two Math`, `Times New Roman`, `Times`, serif 계열 fallback을 보수적으로 매핑한다.
- `font-style="italic"`과 `text-anchor="middle"`을 반영한다.
- fraction bar 등 `line` 요소를 CoreGraphics stroke로 그린다.
- bbox 바깥으로 튀는 내용을 막기 위해 필요한 경우 equation bbox clip을 적용한다.
- Stage 3 보고서에 좌표계 처리, font fallback, 미지원 요소 처리 범위를 기록한다.

### 예상 변경 파일

- `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- 필요 시 `Sources/RhwpCoreBridge/FontFallback.swift`
- `mydocs/working/task_m015_118_stage3.md`

### 검증

```bash
git status --short --branch
git diff -- Sources/RhwpCoreBridge/CGTreeRenderer.swift Sources/RhwpCoreBridge/FontFallback.swift
./scripts/check-no-appkit.sh
./scripts/render-debug-compare.sh /private/tmp/rhwp-task118-stage3-exam samples/exam_math_no.hwp
test -s /private/tmp/rhwp-task118-stage3-exam/exam_math_no-page1-native.png
sed -n '1,140p' /private/tmp/rhwp-task118-stage3-exam/exam_math_no-page1-summary.txt
git diff --check
```

### 완료 기준

- `exam_math_no.hwp` native PNG에서 대표 수식 텍스트와 선이 표시된다.
- 기존 text run과 shape 렌더링 경로의 컴파일/의존성 검증이 깨지지 않는다.
- bbox/anchor/font 처리의 남은 차이가 보고서에 기록된다.

### 커밋 메시지

```text
Task #118 Stage 3: Equation native drawing 구현
```

## Stage 4. 샘플 검증과 보정

### 목표

- `exam_math_no.hwp`와 `eq-01.hwp`에서 구현 결과를 비교하고, Stage 3에서 드러난 bbox/font/line 보정이 필요한지 확인한다.
- native renderer의 수식 표시 개선을 수치와 산출물로 기록한다.

### 작업

- 두 샘플의 변경 후 render debug 산출물을 생성한다.
- 변경 전 Stage 1 산출물과 변경 후 native PNG의 non-white pixel, 수식 위치, 대표 식 표시 여부를 비교한다.
- core SVG와 native PNG의 차이를 확인하고, 이번 작업 범위 안에서 가능한 보정을 적용한다.
- `qlmanage` rasterize 실패는 필수 실패로 보지 않고 native PNG와 render tree 중심으로 판단한다.
- Stage 4 보고서에 전후 산출물 경로와 남은 미지원 SVG 요소를 기록한다.

### 예상 변경 파일

- 필요 시 `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- 필요 시 `Sources/RhwpCoreBridge/FontFallback.swift`
- `mydocs/working/task_m015_118_stage4.md`

### 검증

```bash
git status --short --branch
./scripts/render-debug-compare.sh /private/tmp/rhwp-task118-stage4-exam samples/exam_math_no.hwp
./scripts/render-debug-compare.sh /private/tmp/rhwp-task118-stage4-eq samples/eq-01.hwp
test -s /private/tmp/rhwp-task118-stage4-exam/exam_math_no-page1-summary.txt
test -s /private/tmp/rhwp-task118-stage4-eq/eq-01-page1-summary.txt
sed -n '1,140p' /private/tmp/rhwp-task118-stage4-exam/exam_math_no-page1-summary.txt
sed -n '1,140p' /private/tmp/rhwp-task118-stage4-eq/eq-01-page1-summary.txt
git diff --check
```

### 완료 기준

- 두 기준 샘플에서 수식이 native PNG에 표시된다.
- 수식 표시 개선과 남은 parity 차이가 보고서에 기록된다.
- 추가 보정이 필요하면 이번 stage 안에서 처리하거나 후속 범위로 명확히 분리한다.

### 커밋 메시지

```text
Task #118 Stage 4: 수식 샘플 렌더 검증과 보정
```

## Stage 5. 통합 검증과 최종 보고

### 목표

- HostApp, Quick Look, Thumbnail이 공유하는 renderer 변경으로서 기본 build/smoke를 확인한다.
- 최종 보고서와 오늘할일을 정리하고 PR 전 상태를 만든다.

### 작업

- `Sources/RhwpCoreBridge` 경계 검증을 다시 실행한다.
- 대표 render smoke와 HostApp Debug build를 실행한다.
- Stage 1-4 결과, 변경 파일, 검증 명령, 잔여 리스크를 최종 보고서에 정리한다.
- 오늘할일 #118 행을 완료 상태로 갱신한다.

### 예상 변경 파일

- `mydocs/working/task_m015_118_stage5.md`
- `mydocs/report/task_m015_118_report.md`
- `mydocs/orders/20260502.md`

### 검증

```bash
git status --short --branch
./scripts/check-no-appkit.sh
./scripts/validate-stage3-render.sh
xcodegen generate
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
./scripts/render-debug-compare.sh /private/tmp/rhwp-task118-final samples/exam_math_no.hwp
git diff --check
```

### 완료 기준

- AppKit/UIKit 직접 의존 금지 검증이 통과한다.
- 대표 render smoke와 HostApp Debug build가 통과하거나, 환경성 실패가 근거와 함께 분리된다.
- 최종 보고서에 변경 내용, 검증 결과, 잔여 리스크가 정리된다.
- 오늘할일이 완료 상태로 갱신된다.

### 커밋 메시지

```text
Task #118 Stage 5 + 최종 보고서: 수식 렌더링 보강 검증
```

## 승인 요청 사항

1. 위 5단계 구현계획으로 Stage 1 수식 fragment 기준 조사와 누락 재현에 착수해도 되는지 승인 요청한다.
2. Stage 1은 source code 변경 없이 조사와 단계 보고서 작성으로 진행한다.
3. Stage 2부터 `Sources/RhwpCoreBridge/CGTreeRenderer.swift` 코드 변경이 포함된다.
