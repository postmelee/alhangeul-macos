# Task M015 #108 구현 계획서

수행계획서: `mydocs/plans/task_m015_108.md`

각 단계 완료 후 `task-stage-report` 절차로 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #108 Swift native renderer 도형 children 렌더링 보강
- 마일스톤: M015 (`첫 출시 전 Swift 렌더 보강`)
- 브랜치: `local/task108`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac`
- 주 대상: `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- 기준 샘플: `samples/basic/BookReview.hwp`
- 목표: PageRenderTree에서 도형 계열 노드 children 아래에 있는 텍스트가 Swift native renderer에서 누락되지 않도록 한다.

## 구현 원칙

- 제품 기준 경로는 기존 `rhwp_render_page_tree` + Swift `RenderTree` + `CGTreeRenderer` 경로를 유지한다.
- PageLayerTree ABI 추가 또는 기본 렌더 경로 전환은 하지 않는다.
- `Sources/RhwpCoreBridge`에는 AppKit/UIKit 직접 의존을 추가하지 않는다.
- 도형 노드는 자기 자신을 먼저 그리고 children을 뒤에 그리는 순서로 맞춘다.
- 기존 `Body.clipRect`, `TableCell.clip`, `Group` clipping/transform 처리를 깨지 않는다.
- 이미지 `crop/effect/brightness/contrast` 보강은 #106 범위로 남기고 이번 작업에서 다루지 않는다.
- 구현은 `CGTreeRenderer`의 순회 정책 변경에 집중하고, 불필요한 모델 확장이나 렌더러 구조 개편은 하지 않는다.

## Stage 1. 기준 재현과 draw order 확정

### 목표

- `BookReview.hwp`에서 텍스트 누락이 도형 children 미순회 때문임을 현재 브랜치에서 재확인한다.
- core PageLayerTree builder의 own leaf 후 children 순서와 Swift renderer의 목표 순서를 맞춘다.
- 코드 변경 전에 검증 기준과 산출물 위치를 고정한다.

### 작업

- `samples/basic/BookReview.hwp`의 sample hash를 기록한다.
- `render-debug-compare.sh`로 변경 전 기준 산출물을 생성한다.
- render tree JSON에서 `Rectangle` children 아래 `TextLine`/`TextRun`이 존재하는지 확인한다.
- 현재 `CGTreeRenderer` switch에서 children을 순회하지 않는 node type을 정리한다.
- core `LayerBuilder`가 own leaf와 children을 어떤 순서로 배치하는지 확인한다.
- Stage 1 보고서에 기준 산출물, 재현 증상, 변경 대상 node type을 기록한다.

### 예상 변경 파일

- `mydocs/working/task_m015_108_stage1.md`

### 검증

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

### 완료 기준

- `BookReview.hwp`의 TextRun이 render tree/core SVG에는 있지만 native PNG에서 보이지 않는 현상이 보고서에 기록된다.
- `Rectangle`, `Line`, `Ellipse`, `Path`, `Image` children 순회 보강 필요성이 확인된다.
- source code 변경 없이 기준 산출물과 판단 근거가 정리된다.

### 커밋 메시지

```text
Task #108 Stage 1: 도형 children 누락 기준 재현
```

## Stage 2. CGTreeRenderer 도형 children 순회 보강

### 목표

- `CGTreeRenderer`가 도형/이미지 노드를 그린 뒤 children을 계속 렌더하도록 구현한다.
- draw order는 own node draw 후 children draw로 고정한다.

### 작업

- `renderNode`의 `.rectangle`, `.line`, `.ellipse`, `.path`, `.image` case에서 자기 자신을 렌더한 뒤 `renderChildren`을 호출한다.
- 필요하면 반복을 줄이는 좁은 helper를 추가하되, renderer 구조 개편은 하지 않는다.
- `Group`, `Body`, `TableCell`의 기존 clipping/transform 처리가 유지되는지 확인한다.
- `TextRun`, `FootnoteMarker`, `Equation`, `FormObject` 처리 범위를 이번 작업에서 넓히지 않는다.
- Stage 2 보고서에 변경 전후 순회 정책과 코드 변경 범위를 기록한다.

### 예상 변경 파일

- `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- `mydocs/working/task_m015_108_stage2.md`

### 검증

```bash
git status --short --branch
git diff -- Sources/RhwpCoreBridge/CGTreeRenderer.swift
./scripts/check-no-appkit.sh
git diff --check -- Sources/RhwpCoreBridge/CGTreeRenderer.swift mydocs/working/task_m015_108_stage2.md
```

### 완료 기준

- 도형/이미지 노드의 children이 Swift renderer에서 순회된다.
- 기존 구조 노드와 clip 노드의 순회 방식은 변경되지 않는다.
- AppKit/UIKit 직접 의존 금지 검증이 통과한다.

### 커밋 메시지

```text
Task #108 Stage 2: Swift renderer 도형 children 순회 보강
```

## Stage 3. BookReview render smoke 검증

### 목표

- 구현 후 `BookReview.hwp` 첫 페이지 native PNG에서 텍스트가 보이는지 확인한다.
- core SVG와 native PNG의 책임 경계가 개선됐는지 기록한다.

### 작업

- 변경 후 `render-debug-compare.sh` 산출물을 새 경로에 생성한다.
- summary의 `TextRuns`, `HangulRuns`, `MissingHangulGlyphs`, `NativeNonWhitePixels`를 기록한다.
- 변경 전 Stage 1 산출물과 변경 후 산출물을 비교해 native PNG의 텍스트 표시 개선 여부를 확인한다.
- 가능하면 core SVG rasterize/diff 결과를 기록하되, `qlmanage` 실패는 필수 실패로 보지 않는다.
- Stage 3 보고서에 전후 산출물 경로와 핵심 값을 남긴다.

### 예상 변경 파일

- `mydocs/working/task_m015_108_stage3.md`

### 검증

```bash
git status --short --branch
./scripts/render-debug-compare.sh /private/tmp/rhwp-task108-stage3 samples/basic/BookReview.hwp
test -s /private/tmp/rhwp-task108-stage3/BookReview-page1-render-tree.json
test -s /private/tmp/rhwp-task108-stage3/BookReview-page1-core.svg
test -s /private/tmp/rhwp-task108-stage3/BookReview-page1-native.png
test -s /private/tmp/rhwp-task108-stage3/BookReview-page1-summary.txt
sed -n '1,140p' /private/tmp/rhwp-task108-stage3/BookReview-page1-summary.txt
git diff --check -- mydocs/working/task_m015_108_stage3.md
```

### 완료 기준

- `BookReview.hwp` native PNG에 텍스트가 표시된다.
- render tree/core SVG에 있던 텍스트가 Swift native 경로에서도 반영됨이 보고서에 기록된다.
- 미해결 차이가 있으면 이번 작업 범위와 후속 이슈 범위로 분리되어 있다.

### 커밋 메시지

```text
Task #108 Stage 3: BookReview 렌더 smoke 검증
```

## Stage 4. 통합 검증과 최종 보고

### 목표

- HostApp, Quick Look, Thumbnail이 공유하는 renderer 변경으로서 기본 build/smoke를 확인한다.
- 최종 보고서와 오늘할일을 정리하고 PR 전 상태를 만든다.

### 작업

- `Sources/RhwpCoreBridge` 경계 검증을 다시 실행한다.
- HostApp Debug build를 실행한다.
- 가능하면 대표 render smoke를 추가로 실행해 `BookReview.hwp` 외 샘플에서 non-blank 렌더가 유지되는지 확인한다.
- Stage 1-3 결과, 변경 파일, 검증 명령, 잔여 리스크를 최종 보고서에 정리한다.
- 오늘할일 #108 행을 완료 상태로 갱신한다.

### 예상 변경 파일

- `mydocs/working/task_m015_108_stage4.md`
- `mydocs/report/task_m015_108_report.md`
- `mydocs/orders/20260501.md`

### 검증

```bash
git status --short --branch
./scripts/check-no-appkit.sh
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
./scripts/render-debug-compare.sh /private/tmp/rhwp-task108-final samples/basic/BookReview.hwp
git diff --check
```

### 완료 기준

- AppKit/UIKit 직접 의존 금지 검증이 통과한다.
- HostApp Debug build가 통과한다.
- 최종 보고서에 변경 내용, 검증 결과, 잔여 리스크가 정리된다.
- 오늘할일이 완료 상태로 갱신된다.

### 커밋 메시지

```text
Task #108 Stage 4 + 최종 보고서: 도형 children 렌더 보강 검증
```

## 승인 요청 사항

1. 위 4단계 구현계획으로 Stage 1 기준 재현과 draw order 확정에 착수해도 되는지 승인 요청한다.
2. Stage 1은 source code 변경 없이 조사와 단계 보고서 작성으로 진행한다.
3. Stage 2부터 `Sources/RhwpCoreBridge/CGTreeRenderer.swift` 코드 변경이 포함된다.
