# Task M050 #123 구현 계획서

수행계획서: `mydocs/plans/task_m050_123.md`

각 단계 완료 후 `task-stage-report` 절차로 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #123 Swift native renderer Body clip overflow control 렌더링 보강
- 마일스톤: M050 (`v0.5.0 Viewer 안정화`)
- 1차 기준 브랜치: `local/task123` (`origin/devel` 기준)
- 1차 작업 위치: `/private/tmp/rhwp-mac-task123`
- 2차 적용 기준 브랜치: `origin/devel-webview`
- 2차 작업 위치: `/private/tmp/rhwp-mac-task123-webview` (Stage 6에서 생성)
- 주 대상: `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- 필요 시 보조 대상: `Sources/RhwpCoreBridge/RenderTree.swift`, `scripts/render_debug_compare.swift`, `scripts/render-debug-compare.sh`
- 공통 영향 경로: HostApp native viewer(`devel`), Quick Look preview, Thumbnail extension, PDF export(`devel-webview`)
- 목표: `Body.clip_rect` 아래 텍스트 clipping은 유지하면서, body 좌우 경계를 벗어나는 비-텍스트 control을 rhwp-studio 기준에 가깝게 다시 그리는 Swift native renderer 정책을 추가한다.

## 구현 원칙

- 제품 기준 경로는 `rhwp_render_page_tree` + Swift `RenderTree` + `CGTreeRenderer`로 유지한다.
- `Sources/RhwpCoreBridge`에는 AppKit/UIKit/WebKit 직접 의존을 추가하지 않는다.
- `devel` 기준 source 변경을 먼저 확정하고, `devel-webview`에는 같은 의미의 source patch만 선별 적용한다. 브랜치 전체 merge로 `devel`/`devel-webview`의 HostApp 구조 차이를 섞지 않는다.
- `devel-webview`의 `CGTreeRenderer`에는 bundled font registration과 font resolver 변경이 이미 있으므로, cherry-pick 충돌이 나면 해당 변경을 보존한 상태에서 body/table clip 변경만 수동 반영한다.
- body overflow replay 대상은 보수적으로 제한한다. 텍스트 계열은 기존 body clip 안에 남기고, shape/image/table/textBox/group/equation/formObject 중 rhwp-studio 기준과 render tree bbox로 확인된 control 후보만 다룬다.
- 중복 drawing과 z-order 변화가 가장 큰 리스크다. body clip 내부 pass와 overflow pass 순서를 단계 보고서에 명확히 기록한다.
- 생성 산출물인 PNG/SVG/JSON은 저장소에 커밋하지 않고, 단계 보고서에 출력 경로와 summary 핵심값을 기록한다.
- 최종 PR은 두 대상 브랜치가 필요하다. 기본 브랜치명 규칙(`publish/task123`)과 동시 2개 PR이 충돌하므로, 최종 보고 단계에서 `publish/task123-devel`, `publish/task123-webview` 같은 분기명 예외 승인을 별도로 요청한다.

## Stage 1. rhwp-studio 기준과 Swift 현행 clip 구조 조사

### 목표

- rhwp-studio의 `WebCanvasRenderer.render_overflow_controls`, `ClipKind::Body`, `ClipKind::TableCell` 동작을 기준으로 정리한다.
- Swift `CGTreeRenderer`의 body/table clip 위치, node 분류, render 순서, `RenderTree` 필드 한계를 정리한다.
- `devel`과 `devel-webview`의 공통 renderer 차이를 문서화해 후속 cherry-pick 리스크를 좁힌다.

### 작업

- `CGTreeRenderer.renderNode`의 `.body`, `.tableCell`, control node 분기를 정리한다.
- `RenderTree.swift`에서 사용 가능한 node type, bbox, table/control metadata를 확인한다.
- 기존 #90 overflow 조사 결론과 이번 #123 좌우 control overflow 범위를 분리한다.
- `origin/devel...origin/devel-webview`의 `CGTreeRenderer.swift` 차이를 기록한다.
- rhwp-studio source 또는 현재 core reference에서 overflow control 조건을 확인하고 Swift에서 재현 가능한 조건과 불가능한 조건을 분리한다.
- Stage 1 보고서에 Stage 2 구현 범위를 확정한다.

### 예상 변경 파일

- `mydocs/working/task_m050_123_stage1.md`

### 검증

```bash
git status --short --branch
rg -n "render_overflow_controls|ClipKind|WebCanvasRenderer|Body\\(|TableCell" .
git diff --unified=80 origin/devel...origin/devel-webview -- Sources/RhwpCoreBridge/CGTreeRenderer.swift
rg -n "case \\.body|case \\.tableCell|case \\.rectangle|case \\.image|case \\.group|case \\.textRun" Sources/RhwpCoreBridge/CGTreeRenderer.swift
rg -n "enum RenderNodeType|struct BodyNode|struct TableCellNode|struct TableNode|struct GroupNode" Sources/RhwpCoreBridge/RenderTree.swift
git diff --check
```

### 완료 기준

- Swift에서 재현할 overflow control 조건과 보류할 조건이 단계 보고서에 기록된다.
- Stage 2에서 추가할 helper와 render pass 구조가 확정된다.
- source code 변경 없이 기준 조사와 적용 전략만 정리된다.

### 커밋 메시지

```text
Task #123 Stage 1: body overflow 기준 조사
```

## Stage 2. Body overflow control 분류 helper와 replay 구조 추가

### 목표

- body clip 내부 일반 렌더링과 body 좌우 overflow control replay를 분리할 수 있는 내부 구조를 만든다.
- 아직 table cell clip 보정은 하지 않고, body pass 정책과 대상 분류를 좁게 구현한다.

### 작업

- `renderBody(_:node:in:)` 형태의 private helper를 도입해 `.body` 분기 복잡도를 분리한다.
- `isBodyOverflowReplayCandidate(_:)`, `isTextClipBoundNode(_:)`, `horizontallyOverflows(_:clip:)` 같은 private helper를 추가한다.
- body clip 내부에서는 기존 children 렌더링을 유지한다.
- overflow replay pass에서는 후보 node만 clip 없는 상태 또는 필요한 최소 clip 상태로 다시 그린다.
- replay 후보는 좌우 overflow에 한정하고, 상하 body overflow는 #90 계열 core layout 문제와 섞지 않는다.
- replay 중 children 중복 drawing이 생기는 node type을 확인하고 Stage 3에서 보정할 항목을 기록한다.

### 예상 변경 파일

- `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- `mydocs/working/task_m050_123_stage2.md`

### 검증

```bash
git status --short --branch
git diff -- Sources/RhwpCoreBridge/CGTreeRenderer.swift
./scripts/check-no-appkit.sh
./scripts/validate-stage3-render.sh /private/tmp/rhwp-task123-stage2-smoke samples/basic/KTX.hwp samples/basic/request.hwp samples/exam_kor.hwp
./scripts/render-debug-compare.sh /private/tmp/rhwp-task123-stage2-bokhak samples/복학원서.hwp
git diff --check
```

### 완료 기준

- body clip 내부 pass와 overflow replay pass가 코드에서 분리된다.
- 텍스트 계열 node는 기존 body clipping 안에 남는다.
- AppKit/UIKit 직접 의존 금지 검증이 통과한다.
- 기본 smoke와 대표 render-debug 산출물이 생성된다.

### 커밋 메시지

```text
Task #123 Stage 2: Body overflow replay 구조 추가
```

## Stage 3. control node replay 정확도 보강

### 목표

- shape, image, table, group, textBox, equation 등 control 후보별 replay 여부를 rhwp-studio 기준에 더 가깝게 조정한다.
- group/table children 중복 렌더링과 z-order 부작용을 줄인다.

### 작업

- Stage 2 산출물에서 replay가 필요한 node와 중복 drawing이 생기는 node를 분리한다.
- `table`, `group`, `textBox`처럼 자체 draw 없이 children을 순회하는 구조 노드의 replay 조건을 별도 helper로 정리한다.
- `rectangle`, `line`, `ellipse`, `path`, `image`, `equation`처럼 자체 drawing이 있는 node와 children 순회 정책을 확인한다.
- `pageBackground`, `header`, `footer`, `footnoteArea`, 일반 `column`은 overflow replay 대상에서 제외한다.
- 필요한 경우 render debug summary에 body clip overflow 후보 수나 replay 후보 기록을 추가하는 최소 스크립트 보강을 검토한다.
- Stage 3 보고서에 node type별 정책 표를 남긴다.

### 예상 변경 파일

- `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- 필요 시 `scripts/render_debug_compare.swift`
- 필요 시 `scripts/render-debug-compare.sh`
- `mydocs/working/task_m050_123_stage3.md`

### 검증

```bash
git status --short --branch
./scripts/check-no-appkit.sh
./scripts/render-debug-compare.sh /private/tmp/rhwp-task123-stage3-bokhak samples/복학원서.hwp
./scripts/validate-stage3-render.sh /private/tmp/rhwp-task123-stage3-smoke samples/basic/KTX.hwp samples/basic/request.hwp samples/exam_kor.hwp
test -s /private/tmp/rhwp-task123-stage3-bokhak/복학원서-page1-summary.txt
git diff --check
```

### 완료 기준

- node type별 replay 정책이 코드와 단계 보고서에 일치하게 정리된다.
- replay 대상에서 제외해야 하는 header/footer/footnote/text 계열 회귀 방지가 확인된다.
- 대표 샘플 smoke와 render-debug 산출물이 생성된다.

### 커밋 메시지

```text
Task #123 Stage 3: control replay 대상 보강
```

## Stage 4. TableCell clip 우측 여유 폭 보강

### 목표

- `TableCell.clip`의 단순 bbox clip이 rhwp-studio `ClipKind::TableCell` 우측 여유 폭과 어긋나는지 확인하고, 필요한 경우 최소 보정한다.
- 셀 내부 텍스트 보호와 우측 overflow 허용 사이의 부작용을 분리한다.

### 작업

- 현재 `TableCellNode`가 제공하는 `clip`, `row`, `col`, span, `modelCellIndex`와 bbox만으로 보정 가능한지 확인한다.
- 우측 여유 폭이 필요한 경우 `tableCellClipRect(for:)` helper를 추가하고, 보정 상수를 코드에 직접 흩뿌리지 않는다.
- 셀 하단/상단 overflow는 이번 범위에서 확장하지 않는다.
- table border와 셀 내부 text run이 셀 경계 밖으로 과도하게 새지 않는지 샘플로 확인한다.
- 보정이 불충분하면 render tree 계약 부족으로 보고서에 분리하고 무리한 추정을 피한다.

### 예상 변경 파일

- `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- 필요 시 `Sources/RhwpCoreBridge/RenderTree.swift`
- `mydocs/working/task_m050_123_stage4.md`

### 검증

```bash
git status --short --branch
git diff -- Sources/RhwpCoreBridge/CGTreeRenderer.swift Sources/RhwpCoreBridge/RenderTree.swift
./scripts/check-no-appkit.sh
./scripts/render-debug-compare.sh /private/tmp/rhwp-task123-stage4-bokhak samples/복학원서.hwp
./scripts/validate-stage3-render.sh /private/tmp/rhwp-task123-stage4-smoke samples/basic/KTX.hwp samples/basic/request.hwp samples/exam_kor.hwp
git diff --check
```

### 완료 기준

- `TableCell.clip` 보정 여부와 근거가 보고서에 기록된다.
- 보정을 적용한 경우 helper 경계가 좁고 기존 table/text rendering smoke가 통과한다.
- 보정을 보류한 경우 필요한 render tree/core 계약이 명확히 기록된다.

### 커밋 메시지

```text
Task #123 Stage 4: TableCell clip 정책 보강
```

## Stage 5. devel 기준 통합 검증과 결과 정리

### 목표

- `devel` 기준 HostApp native viewer, Quick Look, Thumbnail 공통 renderer 영향 범위를 검증한다.
- Stage 1-4 변경을 정리하고 `devel-webview` 선별 적용에 넘길 source commit 범위를 확정한다.

### 작업

- `Sources/RhwpCoreBridge` 경계 검증을 다시 실행한다.
- 기본 render smoke와 대표 샘플 render-debug를 실행한다.
- HostApp Debug build를 실행해 `devel` native viewer compile/link 회귀를 확인한다.
- Stage 1-4에서 생성한 source commit SHA와 `devel-webview`에 선별 적용할 commit 목록을 정리한다.
- 단계 보고서에는 아직 최종 결과보고서를 작성하지 않고, Stage 6 이후 양쪽 브랜치 결과를 합쳐 최종 보고한다.

### 예상 변경 파일

- `mydocs/working/task_m050_123_stage5.md`

### 검증

```bash
git status --short --branch
./scripts/check-no-appkit.sh
./scripts/validate-stage3-render.sh
./scripts/validate-stage3-render.sh /private/tmp/rhwp-task123-stage5-smoke samples/basic/KTX.hwp samples/basic/request.hwp samples/exam_kor.hwp
./scripts/render-debug-compare.sh /private/tmp/rhwp-task123-stage5-bokhak samples/복학원서.hwp
xcodegen generate
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
git diff --check
```

### 완료 기준

- `devel` 기준 공통 renderer smoke와 HostApp Debug build가 통과하거나, 환경성 실패가 근거와 함께 분리된다.
- `devel-webview`에 옮길 source commit 범위가 명확하다.
- `CGTreeRenderer.swift` 외 추가 변경 여부와 이유가 기록된다.

### 커밋 메시지

```text
Task #123 Stage 5: devel 렌더러 통합 검증
```

## Stage 6. devel-webview 선별 적용과 양쪽 브랜치 최종 정리

### 목표

- `origin/devel-webview` 기준 별도 worktree에 #123 source 변경을 선별 적용한다.
- `devel-webview`에서 HostApp은 WKWebView가 기본이지만, Quick Look/Thumbnail/PDF export가 공유하는 native renderer 경로를 검증한다.
- 양쪽 브랜치 적용 결과를 최종 보고서에 함께 정리한다.

### 작업

- `/private/tmp/rhwp-mac-task123-webview` worktree를 `origin/devel-webview` 기준으로 생성한다.
- Stage 2-4의 source commit을 cherry-pick하거나 동일 patch로 수동 반영한다. Stage 보고서와 오늘할일 문서는 1차 worktree 기준을 원본으로 유지한다.
- `devel-webview`의 `CGTreeRenderer` 폰트 등록/폰트 resolver 변경을 보존한다.
- `devel-webview` 기준 `check-no-appkit`, renderer smoke, HostApp Debug build를 실행한다.
- 1차 worktree에 최종 결과보고서와 오늘할일 완료 갱신을 작성한다.
- 최종 보고서에 `devel`/`devel-webview` 각각의 branch head, 검증 명령, 실패/성공 상태, PR branch naming 승인 필요 사항을 기록한다.

### 예상 변경 파일

1차 `devel` worktree:

- `mydocs/working/task_m050_123_stage6.md`
- `mydocs/report/task_m050_123_report.md`
- `mydocs/orders/20260505.md`

2차 `devel-webview` worktree:

- `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- 필요 시 `Sources/RhwpCoreBridge/RenderTree.swift`
- 필요 시 `scripts/render_debug_compare.swift`
- 필요 시 `scripts/render-debug-compare.sh`

### 검증

1차 `devel` worktree:

```bash
git status --short --branch
git log --oneline --decorate -8
git diff --check
```

2차 `devel-webview` worktree:

```bash
git status --short --branch
./scripts/check-no-appkit.sh
./scripts/validate-stage3-render.sh
./scripts/validate-stage3-render.sh /private/tmp/rhwp-task123-webview-smoke samples/basic/KTX.hwp samples/basic/request.hwp samples/exam_kor.hwp
xcodegen generate
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
git diff --check
```

### 완료 기준

- `devel-webview` 기준 source patch가 `devel`의 의도와 동일하게 적용된다.
- `devel-webview`의 WKWebView HostApp 변경과 font renderer 변경을 덮어쓰지 않는다.
- 최종 보고서에 양쪽 브랜치 검증 결과와 PR 분기 전략이 정리된다.
- 오늘할일이 완료 상태로 갱신된다.

### 커밋 메시지

1차 `devel` worktree:

```text
Task #123 Stage 6 + 최종 보고서: 양쪽 브랜치 적용 검증
```

2차 `devel-webview` worktree:

```text
Task #123: native renderer clip 정책 devel-webview 적용
```

## 승인 요청 사항

1. 위 6단계 구현계획으로 Stage 1 `rhwp-studio 기준과 Swift 현행 clip 구조 조사`에 착수해도 되는지 승인 요청한다.
2. Stage 1은 source code 변경 없이 기준 조사와 단계 보고서 작성으로 진행한다.
3. Stage 2부터 `Sources/RhwpCoreBridge/CGTreeRenderer.swift` 변경이 포함된다.
4. 최종 PR 단계에서 두 대상 브랜치가 필요하므로 `publish/task123-devel`, `publish/task123-webview`처럼 기본 PR branch naming 예외가 필요할 수 있다.
