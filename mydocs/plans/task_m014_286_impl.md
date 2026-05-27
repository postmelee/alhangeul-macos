# Task M014 #286 구현 계획서

수행계획서: `mydocs/plans/task_m014_286.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #286 rhwp-studio preview visual diff harness readiness 안정화
- 마일스톤: M014 (`v0.1.4 Native Preview/Viewer Parity`)
- 브랜치: `local/task286`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac`
- 기준 브랜치: `devel`
- 목표: #280 harness가 `rhwp-studio` reference PNG와 native preview PNG를 안정적으로 생성하고, #281 이후 PR에서 visual diff metric을 반복 기록할 수 있게 한다.

## 구현 원칙

- renderer/compositor production 동작은 수정하지 않는다.
- #281/#282/#116/#122/#121/#110 구현을 선행하지 않는다.
- #285 PR 브랜치는 직접 수정하지 않는다. #286 merge 후 #285 보강은 별도 반영한다.
- JavaScript probe는 `WKWebView.evaluateJavaScript`가 안정적으로 반환할 수 있는 primitive 또는 JSON string만 반환한다.
- 실패를 숨기지 않는다. `navigation`, `readiness`, `settle`, `canvas export`, `snapshot`, `native render`, `diff` 중 어느 phase에서 실패했는지 summary에 남긴다.
- sample별 renderer 차이는 harness 실패와 분리한다. harness가 PASS하고 diff 수치가 큰 경우는 정상 측정 결과로 기록한다.

## 현재 기준 관찰

현재 harness의 핵심 위치는 다음이다.

| 영역 | 파일/함수 | 관찰 |
|------|-----------|------|
| wrapper | `scripts/preview-visual-diff-harness.sh` | Swift harness를 빌드한 뒤 sample 목록을 전달한다. |
| readiness wait | `scripts/preview_visual_diff_harness.swift` `waitForPageReady` | `currentPageState`가 ready를 반환할 때까지 polling한다. |
| JS bridge | `evaluateJavaScript` | WebKit callback의 `value`를 그대로 Swift `Any?`로 받는다. |
| page state | `pageStateScript` | `JSON.stringify(...)`로 state JSON string을 반환한다. |
| settle | `alignPageAndHideChrome`, `settleFlagScript` | chrome hide/scroll align 후 settle flag를 확인한다. |
| canvas export | `canvasDataURLScript` | page canvas를 data URL로 export한다. |
| summary | `PreviewVisualDiffHarness.main` | OK/FAIL row를 `summary.md`에 기록한다. |

#283에서 반복된 증상은 readiness 단계의 `WKErrorDomain Code=5`와 JavaScript unsupported result type이다. Stage 1에서 이 증상이 현재 `devel` 기준으로 재현되는지 먼저 확인한다.

## 조사 산출물 구조

| 파일 | 역할 |
|------|------|
| `mydocs/plans/task_m014_286_impl.md` | 단계별 구현 범위, 검증, 완료 기준 |
| `mydocs/working/task_m014_286_stage1.md` | 실패 재현과 phase inventory |
| `mydocs/working/task_m014_286_stage2.md` | probe/logging 보강 구현 보고 |
| `mydocs/working/task_m014_286_stage3.md` | known sample metric smoke 보고 |
| `mydocs/report/task_m014_286_report.md` | 최종 결과와 #281/#285 handoff |
| `build.noindex/task286-*` | 재현/검증 산출물. 커밋하지 않는다. |

## Stage 1. 실패 재현과 readiness phase inventory

### 목표

#283에서 관찰된 readiness 실패를 현재 `devel` 기준으로 재현하고, 실제 실패가 어느 phase와 JavaScript 반환값에서 발생하는지 정리한다.

### 작업

- #283 실패 sample set으로 baseline harness를 실행한다.
  - `samples/basic/request.hwp`
  - `samples/hwpx/hwpx-01.hwpx`
  - `samples/tac-img-02.hwp`
  - `samples/tac-img-02.hwpx`
- `summary.md`의 실패 메시지를 수집한다.
- `scripts/preview_visual_diff_harness.swift`에서 readiness 관련 함수의 현재 반환 계약을 정리한다.
- 최소 보정 후보를 분류한다.
  - JavaScript result type 보정
  - page state JSON decode 보강
  - timeout summary/log 보강
  - settle/canvas export phase 분리

### 산출물

- `mydocs/working/task_m014_286_stage1.md`
- `build.noindex/task286-stage1-baseline/summary.md` 또는 실패 로그

### 검증

```bash
./scripts/verify-rhwp-studio-assets.sh
./scripts/preview-visual-diff-harness.sh build.noindex/task286-stage1-baseline --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx \
  samples/tac-img-02.hwp samples/tac-img-02.hwpx
sed -n '1,180p' build.noindex/task286-stage1-baseline/summary.md
rg -n "WKErrorDomain|unsupported|readiness timed out|ChangedPixels|MeanRGBDelta" \
  build.noindex/task286-stage1-baseline/summary.md
rg -n "waitForPageReady|evaluateJavaScript|pageStateScript|settleFlagScript|canvasDataURLScript" \
  scripts/preview_visual_diff_harness.swift
git diff --check
```

### 완료 기준

- 현재 실패가 재현되거나, 재현되지 않을 경우 그 사실과 생성된 metric을 보고서에 남긴다.
- 실패 sample별 phase와 오류 메시지를 표로 정리한다.
- Stage 2에서 적용할 최소 변경 범위를 확정한다.
- production source는 변경하지 않는다.

### 커밋 메시지

```text
Task #286 Stage 1: harness readiness 실패 재현
```

## Stage 2. JavaScript probe와 readiness logging 보강

### 목표

readiness probe와 summary logging을 보강해 unsupported JavaScript result type 오류를 피하고, 실패 원인을 phase별로 구분할 수 있게 한다.

### 작업

- `evaluateJavaScript` 호출 결과의 오류 메시지를 WebKit domain/code/message 중심으로 정리한다.
- `currentPageState`와 `canvasDataURLScript` 결과가 항상 JSON string인지 검증하고, 예상하지 못한 type이면 type name과 phase를 남긴다.
- readiness timeout 시 마지막 state와 마지막 error를 함께 남긴다.
- sample별 FAIL row가 가능하면 `navigation/readiness/settle/canvas export/snapshot/native render/diff` 중 phase를 드러내도록 보강한다.
- 필요 시 Swift 내부 helper type을 추가하되 harness 파일 안에 한정한다.

### 산출물

- `scripts/preview_visual_diff_harness.swift`
- 필요 시 `scripts/preview-visual-diff-harness.sh`
- `mydocs/working/task_m014_286_stage2.md`

### 검증

```bash
swiftc -parse-as-library \
  -module-cache-path build.noindex/task286-stage2-swift-module-cache \
  -Xcc -fmodules-cache-path=build.noindex/task286-stage2-clang-module-cache \
  -I Frameworks/modulemap \
  Sources/RhwpCoreBridge/RhwpDocument.swift \
  Sources/RhwpCoreBridge/RenderTree.swift \
  Sources/RhwpCoreBridge/FontFallback.swift \
  Sources/RhwpCoreBridge/FontResourceRegistry.swift \
  Sources/RhwpCoreBridge/CGTreeRenderer.swift \
  Sources/Shared/HwpPageImageRenderer.swift \
  scripts/preview_visual_diff_harness.swift \
  Frameworks/universal/librhwp.a \
  -framework AppKit -framework CoreGraphics -framework CoreText \
  -framework Foundation -framework ImageIO -framework UniformTypeIdentifiers \
  -framework Security -framework CoreFoundation -framework WebKit \
  -lc++ -liconv -lz \
  -o build.noindex/task286-stage2-syntax-check
./scripts/preview-visual-diff-harness.sh build.noindex/task286-stage2-smoke --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx
sed -n '1,180p' build.noindex/task286-stage2-smoke/summary.md
git diff --check
```

### 완료 기준

- Swift harness가 컴파일된다.
- 기본 sample 2개에서 PASS metric이 생성되거나, FAIL이면 phase와 원인이 summary에서 구분된다.
- Stage 1의 unsupported result type이 같은 형태로 반복되지 않는다.

### 커밋 메시지

```text
Task #286 Stage 2: readiness probe logging 보강
```

## Stage 3. known sample smoke와 metric 생성 검증

### 목표

M014 후속 작업에서 재사용할 sample set으로 harness metric 생성 여부를 검증한다.

### 작업

- 기본 sample set smoke:
  - `samples/basic/request.hwp`
  - `samples/hwpx/hwpx-01.hwpx`
- image-heavy sample set smoke:
  - `samples/tac-img-02.hwp`
  - `samples/tac-img-02.hwpx`
  - 필요 시 `samples/hwp-img-001.hwp`
  - 필요 시 `samples/img-start-001.hwp`
- `summary.md`에서 `ChangedPixels`, `ChangedPercent`, `MeanRGBDelta`, `MaxRGBDelta`, capture mode, native backend를 기록한다.
- 실패 sample이 있다면 harness readiness 문제인지 renderer/document 문제인지 분류한다.

### 산출물

- `mydocs/working/task_m014_286_stage3.md`
- `build.noindex/task286-stage3-basic/summary.md`
- `build.noindex/task286-stage3-images/summary.md`

### 검증

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task286-stage3-basic --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx
./scripts/preview-visual-diff-harness.sh build.noindex/task286-stage3-images --page 1 \
  samples/tac-img-02.hwp samples/tac-img-02.hwpx \
  samples/hwp-img-001.hwp samples/img-start-001.hwp
sed -n '1,180p' build.noindex/task286-stage3-basic/summary.md
sed -n '1,220p' build.noindex/task286-stage3-images/summary.md
rg -n "ChangedPixels|ChangedPercent|MeanRGBDelta|FAIL|WKErrorDomain|unsupported|readiness timed out" \
  build.noindex/task286-stage3-basic/summary.md \
  build.noindex/task286-stage3-images/summary.md
git diff --check
```

### 완료 기준

- 최소 4개 target sample 중 PASS sample의 metric이 summary에 기록된다.
- 실패 sample이 있으면 readiness failure와 renderer/document failure를 구분한다.
- #281에서 사용할 smoke 명령 후보가 확정된다.

### 커밋 메시지

```text
Task #286 Stage 3: harness metric smoke 검증
```

## Stage 4. #281/#285 handoff와 최종 보고

### 목표

#286 결과를 M014 후속 작업과 #285 보강 흐름으로 넘길 수 있게 정리한다.

### 작업

- #281에서 재사용할 command/output directory convention을 정리한다.
- #285에 추가할 수 있는 #283 재측정 범위와 한계를 정리한다.
- 완료 sample과 실패 sample을 구분해 최종 보고서에 수치와 한계를 기록한다.
- 오늘할일 #286 행을 완료 상태로 갱신한다.

### 산출물

- `mydocs/report/task_m014_286_report.md`
- `mydocs/orders/20260527.md`

### 검증

```bash
rg -n "#286|readiness|ChangedPixels|ChangedPercent|MeanRGBDelta|#281|#285|#280|#283" \
  mydocs/report/task_m014_286_report.md mydocs/orders/20260527.md
git diff --check
git status --short --branch
```

### 완료 기준

- #286 완료 기준인 visual diff metric 생성 또는 phase별 실패 진단이 보고서에 남는다.
- #281 후속 PR에서 재사용할 harness 실행 명령이 명시된다.
- #285 보강 가능 범위와 merge 순서 리스크가 정리된다.

### 커밋 메시지

```text
Task #286 Stage 4: harness readiness 결과 정리
```

## 승인 요청 사항

1. 위 4단계 구현계획으로 #286을 진행하는 것에 대한 승인
2. Stage 1에서 production source 수정 없이 실패 재현과 phase inventory만 수행하는 범위 승인
3. Stage 2에서 harness script 보강을 수행하되 renderer/compositor production 경로는 수정하지 않는 범위 승인
4. 승인 후 다음 단계: Stage 1 실패 재현과 readiness phase inventory 진행

승인 전에는 Stage 1 조사 실행이나 source/script 변경을 진행하지 않는다.
