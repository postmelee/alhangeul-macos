# Task M014 #293 구현 계획서

수행계획서: `mydocs/plans/task_m014_293.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #293 preview visual diff harness가 rhwp-studio overlay DOM을 포함해 캡처하도록 수정
- 마일스톤: M014 (`v0.1.4 Native Preview/Viewer Parity`)
- 브랜치: `local/task293`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac-task293`
- 기준 브랜치: `devel`
- 목표: overlay DOM이 있는 `rhwp-studio` page reference를 canvas-only export가 아니라 WebView snapshot으로 캡처해 실제 웹 표시와 같은 기준 PNG를 만든다.

## 구현 원칙

- renderer/compositor production 동작은 수정하지 않는다.
- #282 compositor, #116 watermark parity 구현을 선행하지 않는다.
- #282 작업 branch나 artifact는 직접 수정하지 않는다.
- overlay 없는 문서의 canvas-only capture path는 가능한 한 유지한다.
- overlay DOM 또는 overlay union이 있는 문서는 WebView snapshot을 선택한다.
- snapshot rect는 page canvas와 overlay union을 포함해야 하며, rect가 viewport 밖이면 viewport/좌표 문제로 분리해 보고한다.
- JavaScript probe는 `WKWebView.evaluateJavaScript`가 안정적으로 받을 수 있는 JSON string/primitive 반환 원칙을 유지한다.
- metadata는 실제 capture decision을 사후 검증할 수 있게 `captureMode`, `overlayIncluded`, `overlayCount`, `usedOverlayUnion`, sample pixel 값을 일관되게 남긴다.

## 현재 기준 관찰

현재 harness의 핵심 위치는 다음이다.

| 영역 | 파일/함수 | 관찰 |
|------|-----------|------|
| wrapper | `scripts/preview-visual-diff-harness.sh` | Swift harness를 빌드하고 resource dir, viewport, settle, sample 목록을 전달한다. |
| page capture | `scripts/preview_visual_diff_harness.swift` `StudioReferenceRenderer.capture` | `pageState.canvasSampleNonWhitePixels > 0`이면 canvas export를 우선 선택한다. |
| snapshot capture | `captureSnapshotPNG` / `takeSnapshot` | WebView snapshot rect를 PNG로 인코딩한다. |
| canvas export | `exportCanvasPNG` / `canvasDataURLScript` | target page canvas의 `toDataURL()` 결과를 PNG로 사용한다. |
| page state | `currentPageState` / `pageStateScript` | canvas rect, overlay count, overlay union snapshot rect, canvas sample을 JSON string으로 반환한다. |
| metadata | `StudioCaptureMetadata` | `captureMode`, `overlayIncluded`, `overlayCount`, `usedOverlayUnion`, canvas/snapshot sample 값을 기록한다. |
| summary | `PreviewVisualDiffHarness.main` | sample별 `StudioCapture`와 diff metric을 `summary.md`에 기록한다. |

문제 후보는 `overlayCount > 0`과 `usedOverlayUnion=true`인 상태에서도 `canvasSampleNonWhitePixels > 0` 조건이 먼저 적용되어 `captureMode=canvasDataURL`, `overlayIncluded=false`가 되는 decision 순서다.

## 조사 산출물 구조

| 파일 | 역할 |
|------|------|
| `mydocs/plans/task_m014_293_impl.md` | 단계별 구현 범위, 검증, 완료 기준 |
| `mydocs/working/task_m014_293_stage1.md` | 현행 capture decision 재현과 원인 inventory |
| `mydocs/working/task_m014_293_stage2.md` | overlay-aware snapshot 선택 구현 보고 |
| `mydocs/working/task_m014_293_stage3.md` | sample set smoke와 visual diff 재측정 보고 |
| `mydocs/report/task_m014_293_report.md` | 최종 결과와 #282/#116 handoff |
| `build.noindex/task293-*` | 재현/검증 산출물. 커밋하지 않는다. |

## Stage 1. 현행 capture decision 재현과 원인 inventory

### 목표

`samples/복학원서.hwp`에서 현재 reference PNG가 overlay를 누락하는 상태를 재현하고, capture decision이 `canvasDataURL`로 가는 조건과 overlay metadata를 정리한다.

### 작업

- `rhwp-studio` asset provenance와 harness build 가능 여부를 확인한다.
- `samples/복학원서.hwp` baseline harness를 실행한다.
- baseline `summary.md`와 `*-studio.json`에서 다음 값을 수집한다.
  - `captureMode`
  - `overlayIncluded`
  - `overlayCount`
  - `usedOverlayUnion`
  - `canvasSampleNonWhitePixels`
  - `snapshotSampleNonWhitePixels`
  - `rect` / `canvasRect`
- 생성된 `*-studio.png`가 좌상단 로고와 중앙 워터마크를 포함하는지 확인한다.
- overlay 없는 대표 sample에서 현재 canvas-only path를 확인해 Stage 2 회귀 방지 기준을 잡는다.
- `StudioReferenceRenderer.capture`의 decision 순서와 `pageStateScript`의 overlay union 산출 기준을 보고서에 정리한다.

### 산출물

- `mydocs/working/task_m014_293_stage1.md`
- `build.noindex/task293-stage1-baseline/summary.md`
- `build.noindex/task293-stage1-baseline/*-studio.json`
- `build.noindex/task293-stage1-baseline/*-studio.png`

### 검증

```bash
./scripts/verify-rhwp-studio-assets.sh
./scripts/preview-visual-diff-harness.sh build.noindex/task293-stage1-baseline --page 1 \
  samples/복학원서.hwp samples/basic/request.hwp
sed -n '1,200p' build.noindex/task293-stage1-baseline/summary.md
rg -n "captureMode|overlayIncluded|overlayCount|usedOverlayUnion|canvasSampleNonWhitePixels|snapshotSampleNonWhitePixels" \
  build.noindex/task293-stage1-baseline
rg -n "captureMode|overlayIncluded|overlayCount|usedOverlayUnion|canvasSampleNonWhitePixels|captureSnapshotPNG|exportCanvasPNG" \
  scripts/preview_visual_diff_harness.swift
git diff --check
```

### 완료 기준

- `복학원서.hwp`의 현행 capture metadata와 PNG 포함/누락 여부가 보고서에 남는다.
- overlay-positive sample과 overlay 없는 sample의 capture path가 구분된다.
- Stage 2에서 수정할 최소 decision 조건이 확정된다.
- production source는 변경하지 않는다.

### 커밋 메시지

```text
Task #293 Stage 1: overlay capture decision 재현
```

## Stage 2. overlay-aware snapshot 선택 보강

### 목표

overlay DOM 또는 overlay union이 있는 page에서 canvas-only export 대신 WebView snapshot을 선택하도록 harness capture policy를 수정한다.

### 작업

- `StudioReferenceRenderer.capture`의 capture decision을 `pageState.overlayCount > 0` 또는 `pageState.usedOverlayUnion` 우선으로 재정렬한다.
- WebView snapshot 선택 시 `captureMode=webViewSnapshot`, `overlayIncluded=true`가 기록되게 한다.
- canvas-only 선택 시에도 snapshot sample을 가능한 경우 측정해 비교 정보를 유지한다.
- overlay-positive인데 snapshot이 실패하면 canvas fallback으로 조용히 넘어가지 않고 phase/error가 드러나도록 처리한다.
- 필요 시 helper를 추가해 decision 의미를 코드에서 읽기 쉽게 만든다.
- `pageStateScript`의 overlay union rect 산출은 Stage 1 결과상 부족한 경우에만 최소 보정한다.

### 산출물

- `scripts/preview_visual_diff_harness.swift`
- 필요 시 `scripts/preview-visual-diff-harness.sh`
- `mydocs/working/task_m014_293_stage2.md`
- `build.noindex/task293-stage2-smoke/summary.md`

### 검증

```bash
swiftc -parse-as-library \
  -module-cache-path build.noindex/task293-stage2-swift-module-cache \
  -Xcc -fmodules-cache-path=build.noindex/task293-stage2-clang-module-cache \
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
  -o build.noindex/task293-stage2-syntax-check
./scripts/preview-visual-diff-harness.sh build.noindex/task293-stage2-smoke --page 1 \
  samples/복학원서.hwp samples/basic/request.hwp
sed -n '1,200p' build.noindex/task293-stage2-smoke/summary.md
rg -n "captureMode|overlayIncluded|overlayCount|usedOverlayUnion|ChangedPixels|ChangedPercent|MeanRGBDelta" \
  build.noindex/task293-stage2-smoke
git diff --check
```

### 완료 기준

- Swift harness가 컴파일된다.
- `복학원서.hwp` metadata에서 overlay-positive capture가 `webViewSnapshot`과 `overlayIncluded=true`로 기록된다.
- overlay 없는 `request.hwp`는 기존 canvas-only path를 유지하거나, 변경된 경우 근거가 보고서에 남는다.
- snapshot 실패가 조용한 canvas fallback으로 숨겨지지 않는다.

### 커밋 메시지

```text
Task #293 Stage 2: overlay snapshot capture 선택 보강
```

## Stage 3. sample set smoke와 visual diff 재측정

### 목표

overlay-positive sample과 기존 v0.1.4 image sample set에서 보정 후 metadata와 visual diff metric을 다시 생성한다.

### 작업

- `복학원서.hwp` overlay snapshot smoke를 실행한다.
- 기존 v0.1.4 image sample set을 실행한다.
  - `samples/basic/request.hwp`
  - `samples/hwpx/hwpx-01.hwpx`
  - `samples/tac-img-02.hwp`
  - `samples/tac-img-02.hwpx`
  - `samples/hwp-img-001.hwp`
- `summary.md`의 `ChangedPixels`, `ChangedPercent`, `MeanRGBDelta`, `MaxRGBDelta`, `StudioCapture`, native backend를 기록한다.
- `복학원서.hwp-page1-studio.png`의 좌상단 로고와 중앙 BehindText 워터마크 포함 여부를 확인한다.
- Stage 1 baseline과 Stage 3 결과의 metadata 차이를 표로 정리한다.

### 산출물

- `mydocs/working/task_m014_293_stage3.md`
- `build.noindex/task293-stage3-overlay/summary.md`
- `build.noindex/task293-stage3-samples/summary.md`

### 검증

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task293-stage3-overlay --page 1 \
  samples/복학원서.hwp
./scripts/preview-visual-diff-harness.sh build.noindex/task293-stage3-samples --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx \
  samples/tac-img-02.hwp samples/tac-img-02.hwpx samples/hwp-img-001.hwp
sed -n '1,200p' build.noindex/task293-stage3-overlay/summary.md
sed -n '1,240p' build.noindex/task293-stage3-samples/summary.md
rg -n "captureMode|overlayIncluded|overlayCount|usedOverlayUnion|ChangedPixels|ChangedPercent|MeanRGBDelta|FAIL" \
  build.noindex/task293-stage3-overlay build.noindex/task293-stage3-samples
git diff --check
```

### 완료 기준

- `복학원서.hwp` studio reference PNG가 실제 `rhwp-studio` 웹 표시처럼 좌상단 로고와 중앙 워터마크를 포함한다.
- overlay-positive metadata에서 `captureMode=webViewSnapshot`, `overlayIncluded=true`가 기록된다.
- overlay 없는 sample의 기존 capture path가 회귀하지 않는다.
- smoke sample의 PASS/FAIL과 visual diff metric이 보고서에 남는다.

### 커밋 메시지

```text
Task #293 Stage 3: overlay snapshot smoke 재측정
```

## Stage 4. #282/#116 handoff와 최종 보고

### 목표

보정된 `rhwp-studio` reference capture 기준을 #282 후속 Stage와 #116 watermark parity 작업에서 재사용할 수 있게 정리한다.

### 작업

- 변경 전후 capture metadata를 최종 보고서에 정리한다.
- `복학원서.hwp` reference PNG 포함 여부와 visual diff 수치를 기록한다.
- #282에서 재사용할 harness 명령과 output directory convention을 남긴다.
- #116에서 해석해야 할 watermark parity 잔여 차이와 reference capture 오류가 분리됐음을 설명한다.
- 오늘할일 #293 행을 완료 상태로 갱신한다.

### 산출물

- `mydocs/report/task_m014_293_report.md`
- `mydocs/orders/20260529.md`

### 검증

```bash
rg -n "#293|overlay|captureMode|overlayIncluded|webViewSnapshot|canvasDataURL|#282|#116|ChangedPixels|MeanRGBDelta" \
  mydocs/report/task_m014_293_report.md mydocs/orders/20260529.md
git diff --check
git status --short --branch
```

### 완료 기준

- #293 완료 기준인 overlay 포함 studio reference PNG와 metadata 일치가 최종 보고서에 남는다.
- #282/#116 후속 작업에서 사용할 명령과 해석 기준이 명시된다.
- 최종 보고서와 오늘할일 갱신이 커밋된다.

### 커밋 메시지

```text
Task #293 Stage 4: overlay capture 기준 정리
```

## 승인 요청 사항

1. 위 4단계 구현계획으로 #293을 진행하는 것에 대한 승인
2. Stage 1에서 production source 수정 없이 현행 capture decision과 artifact만 재현하는 범위 승인
3. Stage 2에서 harness capture decision을 수정하되 renderer/compositor production 경로는 수정하지 않는 범위 승인
4. 승인 후 다음 단계: Stage 1 현행 capture decision 재현과 원인 inventory 진행

승인 전에는 Stage 1 조사 실행이나 source/script 변경을 진행하지 않는다.
