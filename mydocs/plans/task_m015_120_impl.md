# Task M015 #120 구현 계획서

수행계획서: `mydocs/plans/task_m015_120.md`

각 단계 완료 후 `task-stage-report` 절차로 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #120 Swift native renderer 텍스트 글자별 위치와 advance 재현 개선
- 마일스톤: M015 (`첫 출시 전 Swift 렌더 보강`)
- 브랜치: `local/task120`
- 작업 위치: `/private/tmp/rhwp-mac-task120`
- 주 대상: `Sources/RhwpCoreBridge/CGTreeRenderer.swift`, `Sources/RhwpCoreBridge/RenderTree.swift`
- 기준 샘플: `samples/20250130-hongbo.hwp`, `samples/re-align-center-hancom.hwp`, `samples/re-align-right-hancom.hwp`, `samples/re-align-justify-hancom.hwp`
- 목표: Swift native renderer가 core render tree의 텍스트 bbox, baseline, 줄 내 위치, advance 관련 style 값을 더 충실히 반영해 core SVG와 native PNG의 텍스트 위치 차이를 줄인다.

## 구현 원칙

- 제품 기준 경로는 기존 `rhwp_render_page_tree` + Swift `RenderTree` + `CGTreeRenderer` 경로를 유지한다.
- PageLayerTree 기본 경로 전환, 새 렌더 엔진 도입, proprietary font 번들은 하지 않는다.
- `Sources/RhwpCoreBridge`에는 AppKit/UIKit/WebKit 직접 의존을 추가하지 않는다.
- CoreText는 glyph lookup, fallback, drawing에 계속 사용하되, HWP/rhwp core가 산출한 bbox와 style-derived advance를 우선해 배치한다.
- 한글/라틴/공백/탭/조합문자 처리를 무리하게 한 규칙으로 합치지 않고, 기준 샘플에서 확인되는 정렬/간격 문제부터 좁게 보정한다.
- render tree 계약 확장이 필요하다고 판단되면 기존 JSON 호환성을 깨지 않는 optional decoder 경계로만 설계하고, core upstream 변경 필요성은 보고서에 분리한다.
- 생성 산출물인 PNG/SVG/JSON은 저장소에 커밋하지 않고, 단계 보고서에 출력 경로와 summary 핵심값을 기록한다.

## Stage 1. 텍스트 위치 차이 기준 조사와 계약 한계 정리

### 목표

- 문제 샘플의 core SVG, render tree, native PNG를 기준 산출물로 생성한다.
- 제목, 배포일자, 정렬 샘플에서 `TextRun` bbox 폭과 CoreText 조판 폭, baseline, style 값을 비교한다.
- 현재 render tree만으로 보정 가능한 범위와 글자별 x/advance 계약 확장이 필요한 범위를 분리한다.

### 작업

- 기준 샘플 4개의 파일 hash를 기록한다.
- `render-debug-compare.sh`로 변경 전 기준 산출물을 생성한다.
- render tree JSON에서 문제 run의 text, bbox, baseline, `letter_spacing`, `ratio`, `available_width`, `line_x_offset`, `extra_word_spacing`, `extra_char_spacing`, `tab_stops`, `inline_tabs`를 추출한다.
- core SVG의 문제 텍스트 x 좌표와 native PNG의 현재 배치 차이를 기록한다.
- `CGTreeRenderer.renderTextRun`의 현재 CoreText 한 줄 drawing 방식과 `RenderTree.swift` decoder 필드 사용 여부를 정리한다.
- Stage 1 보고서에 보정 우선순위와 Stage 2 구현 범위를 확정한다.

### 예상 변경 파일

- `mydocs/working/task_m015_120_stage1.md`

### 검증

```bash
git status --short --branch
shasum -a 256 samples/20250130-hongbo.hwp samples/re-align-center-hancom.hwp samples/re-align-right-hancom.hwp samples/re-align-justify-hancom.hwp
./scripts/render-debug-compare.sh /private/tmp/rhwp-task120-stage1-hongbo samples/20250130-hongbo.hwp
./scripts/render-debug-compare.sh /private/tmp/rhwp-task120-stage1-center samples/re-align-center-hancom.hwp
./scripts/render-debug-compare.sh /private/tmp/rhwp-task120-stage1-right samples/re-align-right-hancom.hwp
./scripts/render-debug-compare.sh /private/tmp/rhwp-task120-stage1-justify samples/re-align-justify-hancom.hwp
test -s /private/tmp/rhwp-task120-stage1-hongbo/20250130-hongbo-page1-render-tree.json
test -s /private/tmp/rhwp-task120-stage1-hongbo/20250130-hongbo-page1-summary.txt
rg -n "lineXOffset|extraWordSpacing|extraCharSpacing|tabStops|availableWidth|renderTextRun" Sources/RhwpCoreBridge scripts
git diff --check
```

### 완료 기준

- 기준 샘플별 텍스트 위치 차이와 관련 style 값이 보고서에 기록된다.
- Stage 2에서 구현할 renderer 보정 범위가 확정된다.
- source code 변경 없이 기준 산출물과 판단 근거가 정리된다.

### 커밋 메시지

```text
Task #120 Stage 1: 텍스트 advance 기준 조사
```

## Stage 2. TextRun 배치 계산 보강

### 목표

- `renderTextRun`에서 bbox, baseline, 장평, 자간, 단어/글자 추가 간격, tab/space advance를 반영하는 내부 배치 계산을 추가한다.
- 기존 CoreText 한 줄 drawing을 유지할 수 있는 경우와 glyph/cluster 단위 drawing이 필요한 경우를 코드 경계에서 분리한다.

### 작업

- CoreText line width, glyph run bounds, bbox width 차이를 계산하는 private helper를 추가한다.
- `TextStyle.ratio`, `letterSpacing`, `extraWordSpacing`, `extraCharSpacing`의 적용 순서를 정리하고 중복 적용을 피한다.
- 공백과 탭이 포함된 텍스트에서 style 값을 반영한 advance 계산을 추가한다.
- bbox 폭과 CoreText 폭이 크게 다를 때 run 전체 위치를 보정할지, cluster별 advance를 보정할지 판단하는 조건을 구현한다.
- 기존 underline, strikethrough, shade drawing의 좌표가 새 배치 계산과 어긋나지 않도록 유지한다.
- Stage 2 보고서에 계산식, fallback 조건, 적용하지 않은 style 값을 기록한다.

### 예상 변경 파일

- `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- 필요 시 `Sources/RhwpCoreBridge/RenderTree.swift`
- `mydocs/working/task_m015_120_stage2.md`

### 검증

```bash
git status --short --branch
git diff -- Sources/RhwpCoreBridge/CGTreeRenderer.swift Sources/RhwpCoreBridge/RenderTree.swift
./scripts/check-no-appkit.sh
./scripts/render-debug-compare.sh /private/tmp/rhwp-task120-stage2-hongbo samples/20250130-hongbo.hwp
test -s /private/tmp/rhwp-task120-stage2-hongbo/20250130-hongbo-page1-summary.txt
sed -n '1,160p' /private/tmp/rhwp-task120-stage2-hongbo/20250130-hongbo-page1-summary.txt
git diff --check
```

### 완료 기준

- `renderTextRun` 내부에서 run 폭 차이와 style-derived spacing을 일관된 helper로 계산한다.
- AppKit/UIKit 직접 의존 금지 검증이 통과한다.
- `20250130-hongbo.hwp` 기준 산출물에서 텍스트 위치 보정 결과가 생성되고 보고서에 기록된다.

### 커밋 메시지

```text
Task #120 Stage 2: TextRun 배치 계산 보강
```

## Stage 3. 글자/cluster 단위 drawing 적용

### 목표

- run 전체를 한 번에 `CTLineDraw`하는 방식으로는 bbox/advance를 보존하기 어려운 텍스트에 대해 글자 또는 cluster 단위 drawing 경로를 적용한다.
- 중앙/우측 정렬, run 분리, 공백/탭 포함 줄에서 HWP/rhwp core가 산출한 위치를 더 가깝게 보존한다.

### 작업

- Swift `String`의 extended grapheme cluster를 기본 단위로 삼되, CoreText shaping이 필요한 경우 fallback 기준을 둔다.
- cluster별 CoreText width와 style-derived target advance를 계산한다.
- 공백에는 `extraWordSpacing`, 일반 cluster에는 `extraCharSpacing`과 `letterSpacing`을 반영한다.
- 탭은 `tabStops`, `defaultTabWidth`, `autoTabRight`, `inlineTabs` 중 현재 render tree로 안전하게 처리 가능한 범위만 적용한다.
- bbox 폭을 맞추기 위한 강제 가로 scaling은 최후의 fallback으로 제한하고, 적용 시 조건을 보고서에 기록한다.
- Stage 3 보고서에 cluster 분할 기준, 미지원 문자/조합 fallback, 샘플별 전후 차이를 정리한다.

### 예상 변경 파일

- `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- 필요 시 `Sources/RhwpCoreBridge/RenderTree.swift`
- 필요 시 `scripts/render_debug_compare.swift`
- `mydocs/working/task_m015_120_stage3.md`

### 검증

```bash
git status --short --branch
./scripts/check-no-appkit.sh
./scripts/render-debug-compare.sh /private/tmp/rhwp-task120-stage3-hongbo samples/20250130-hongbo.hwp
./scripts/render-debug-compare.sh /private/tmp/rhwp-task120-stage3-center samples/re-align-center-hancom.hwp
./scripts/render-debug-compare.sh /private/tmp/rhwp-task120-stage3-right samples/re-align-right-hancom.hwp
test -s /private/tmp/rhwp-task120-stage3-hongbo/20250130-hongbo-page1-native.png
test -s /private/tmp/rhwp-task120-stage3-center/re-align-center-hancom-page1-summary.txt
test -s /private/tmp/rhwp-task120-stage3-right/re-align-right-hancom-page1-summary.txt
git diff --check
```

### 완료 기준

- 문제 제목과 배포일자 run에서 native PNG의 위치 차이가 Stage 1 기준보다 줄어든다.
- 중앙/우측 정렬 샘플에서 기존보다 정렬 방향이 core SVG에 가깝게 보인다.
- cluster drawing이 적용되지 않는 텍스트는 기존 CoreText 한 줄 drawing fallback으로 안정적으로 남는다.

### 커밋 메시지

```text
Task #120 Stage 3: 글자 단위 텍스트 drawing 적용
```

## Stage 4. 정렬 샘플 검증과 render tree 계약 판단

### 목표

- 양끝 정렬, space/tab, 장평/자간 샘플에서 Stage 2-3 보정의 회귀 여부를 확인한다.
- 현재 Swift-only 보정의 한계를 정리하고, core render tree에 글자별 x/advance optional 필드가 필요한지 최종 판단한다.

### 작업

- 기준 샘플 4개 전체에 대해 변경 후 render debug 산출물을 생성한다.
- Stage 1 산출물과 변경 후 summary, native PNG, 가능하면 diff PNG를 비교한다.
- `MissingHangulGlyphs`, `TextRuns`, `NativeNonWhitePixels`가 예상 범위 안에 있는지 확인한다.
- Swift-only 보정으로 남는 차이가 font fallback 문제인지, render tree 계약 부족인지 분리한다.
- render tree 계약 확장이 필요하면 optional field 후보 이름, Swift decoder 호환 전략, core upstream 영향 범위를 보고서에 정리한다.
- 이번 작업에서 optional decoder를 추가할 필요가 확인되면 기존 JSON 호환을 유지하는 최소 변경만 수행한다.

### 예상 변경 파일

- 필요 시 `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- 필요 시 `Sources/RhwpCoreBridge/RenderTree.swift`
- 필요 시 `scripts/render_debug_compare.swift`
- `mydocs/working/task_m015_120_stage4.md`

### 검증

```bash
git status --short --branch
./scripts/render-debug-compare.sh /private/tmp/rhwp-task120-stage4-hongbo samples/20250130-hongbo.hwp
./scripts/render-debug-compare.sh /private/tmp/rhwp-task120-stage4-center samples/re-align-center-hancom.hwp
./scripts/render-debug-compare.sh /private/tmp/rhwp-task120-stage4-right samples/re-align-right-hancom.hwp
./scripts/render-debug-compare.sh /private/tmp/rhwp-task120-stage4-justify samples/re-align-justify-hancom.hwp
sed -n '1,160p' /private/tmp/rhwp-task120-stage4-hongbo/20250130-hongbo-page1-summary.txt
sed -n '1,160p' /private/tmp/rhwp-task120-stage4-justify/re-align-justify-hancom-page1-summary.txt
./scripts/validate-stage3-render.sh /private/tmp/rhwp-task120-stage4-smoke samples/20250130-hongbo.hwp samples/re-align-center-hancom.hwp samples/re-align-right-hancom.hwp samples/re-align-justify-hancom.hwp
git diff --check
```

### 완료 기준

- 기준 샘플 4개의 변경 후 산출물과 핵심 summary가 보고서에 기록된다.
- Swift-only 보정으로 해결된 부분과 남은 한계가 분리된다.
- render tree 계약 확장 필요 여부가 명확히 기록된다.

### 커밋 메시지

```text
Task #120 Stage 4: 텍스트 정렬 샘플 검증과 계약 판단
```

## Stage 5. 통합 검증과 최종 보고

### 목표

- HostApp, Quick Look, Thumbnail이 공유하는 renderer 변경으로서 기본 build/smoke를 확인한다.
- 최종 보고서와 오늘할일을 정리하고 PR 전 상태를 만든다.

### 작업

- `Sources/RhwpCoreBridge` 경계 검증을 다시 실행한다.
- 대표 render smoke와 HostApp Debug build를 실행한다.
- Stage 1-4 결과, 변경 파일, 검증 명령, 잔여 리스크를 최종 보고서에 정리한다.
- `mydocs/orders/20260502.md`의 #120 행을 완료 상태로 갱신한다.

### 예상 변경 파일

- `mydocs/working/task_m015_120_stage5.md`
- `mydocs/report/task_m015_120_report.md`
- `mydocs/orders/20260502.md`

### 검증

```bash
git status --short --branch
./scripts/check-no-appkit.sh
./scripts/validate-stage3-render.sh
./scripts/validate-stage3-render.sh /private/tmp/rhwp-task120-final-smoke samples/20250130-hongbo.hwp samples/re-align-center-hancom.hwp samples/re-align-right-hancom.hwp samples/re-align-justify-hancom.hwp
./scripts/render-debug-compare.sh /private/tmp/rhwp-task120-final samples/20250130-hongbo.hwp
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

- AppKit/UIKit 직접 의존 금지 검증이 통과한다.
- 대표 render smoke와 HostApp Debug build가 통과하거나, 환경성 실패가 근거와 함께 분리된다.
- 최종 보고서에 변경 내용, 검증 결과, 잔여 리스크가 정리된다.
- 오늘할일이 완료 상태로 갱신된다.

### 커밋 메시지

```text
Task #120 Stage 5 + 최종 보고서: 텍스트 advance 보강 검증
```

## 승인 요청 사항

1. 위 5단계 구현계획으로 Stage 1 텍스트 위치 차이 기준 조사와 계약 한계 정리에 착수해도 되는지 승인 요청한다.
2. Stage 1은 source code 변경 없이 기준 산출물 생성, render tree/style 값 조사, 단계 보고서 작성으로 진행한다.
3. Stage 2부터 `Sources/RhwpCoreBridge/CGTreeRenderer.swift` 변경이 포함된다.
