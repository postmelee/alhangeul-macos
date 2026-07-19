# Task #398 최종 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | #398 `preview visual diff harness automation load path 추가` |
| 선행/후속 관계 | #396 Stage 4 전 선행 harness 보정 |
| 마일스톤 | M020 `v0.2.x Skia Quick Look/Thumbnail Backend` |
| 단계 수 | 5 |
| 작업 브랜치 | `local/task398` |

`preview-visual-diff-harness`의 `rhwp-studio` reference capture가 로컬 글꼴 감지 모달/토스트 같은 사용자 UI에 오염되지 않도록 automation document load path와 contamination metadata를 추가했다.

핵심 판단은 `복학원서.hwp`를 더 이상 local font modal contamination 때문에 제외할 필요가 없다는 것이다. 최종 smoke에서 `복학원서.hwp`는 `automationLoad=true`, `captureMode=domComposite`, `overlayIncluded=true`, `captureContaminated=false`, `modalCount=0`, `toastCount=0`, `localFontUIVisible=false`로 확인됐다. 다만 기존 `LAYOUT_OVERFLOW` warning은 남아 있으므로, #396에서는 renderer/layout 품질 이슈로 별도 해석해야 한다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `scripts/preview_visual_diff_harness.swift` | automation app load URL, automation runtime readiness, document load JS, non-persistent local font snapshot seed, contamination metadata, sibling canvas overlay counting 보정 |
| `mydocs/plans/task_m020_398.md` | 수행계획서. 목적, 범위, 설계 방향, 리스크 정리 |
| `mydocs/plans/task_m020_398_impl.md` | Stage 1-5 구현계획서 |
| `mydocs/working/task_m020_398_stage1.md` | current harness load/capture contamination inventory |
| `mydocs/working/task_m020_398_stage2.md` | automation load path 구현 보고 |
| `mydocs/working/task_m020_398_stage3.md` | contamination metadata와 failure 분리 보고 |
| `mydocs/working/task_m020_398_stage4.md` | target sample smoke 검증 보고 |
| `mydocs/report/task_m020_398_report.md` | 최종 보고서 |
| `mydocs/orders/20260629.md` | #398 오늘할일 완료 처리 |

제품 앱 source, RustBridge, Skia/CoreGraphics renderer source, bundled `rhwp-studio` minified asset, sample 문서는 변경하지 않았다.

## 구현 결과

### Automation load path

기존 reference load는 다음 URL로 일반 문서 열기 흐름을 탔다.

```text
alhangeul-studio://app/index.html?url=alhangeul-document://document&filename=...
```

변경 후 harness는 앱 shell만 로드한다.

```text
alhangeul-studio://app/index.html
```

문서 bytes는 기존 `StudioDocumentSchemeHandler`를 유지하고, page 안 automation JS가 `alhangeul-document://current?revision=1`를 `fetch`해 로드한다.

### Runtime strategy

구현계획서는 upstream e2e helper처럼 `window.__wasm.loadDocument(...)`와 `window.__canvasView.loadDocument()` direct path를 우선했다. current bundled production asset은 이 debug global을 노출하지 않았기 때문에 실제 smoke에서는 `rhwp-request` message API의 `ready` / `loadFile` strategy를 사용했다.

`rhwp-request loadFile`는 앱 내부 `loadBytes/initDoc` 경로를 통과하므로 local font prompt가 다시 뜰 수 있었다. 이를 막기 위해 harness 전용 non-persistent WKWebView의 `localStorage["rhwp-local-fonts"]`에 빈 complete snapshot을 문서 로드 직전에 주입했다.

이 상태는 smoke 실행 바깥으로 유지되지 않는다.

### Contamination metadata

`studio/*.json`에 다음 진단 필드를 추가했다.

| 필드 | 의미 |
|------|------|
| `automationLoad` | automation path 사용 여부 |
| `automationStrategy` | `direct-globals` 또는 `rhwp-request` |
| `automationPageCount` | automation load가 반환한 page count |
| `automationFileName` | automation load 파일명 |
| `automationSourceFormat` | source format metadata |
| `automationLocalFontsSeeded` | harness-local local font snapshot seed 여부 |
| `captureContaminated` | capture 전후 UI contamination 감지 여부 |
| `uiSuppressed` | residual UI를 숨긴 경우 |
| `modalCount` | visible modal/dialog 후보 수 |
| `toastCount` | visible toast/notification 후보 수 |
| `localFontUIVisible` | 로컬 글꼴/폰트 감지 계열 UI text 감지 여부 |
| `contaminationText` | 감지된 contamination text sample |
| `preCaptureUI` / `postCaptureUI` | capture 전후 probe detail |

`summary.md`의 `StudioCapture` column에는 column을 늘리지 않고 `;ui=clean` 또는 contamination hint를 붙이도록 했다.

### Sibling canvas overlay 보정

Stage 4 smoke 중 `복학원서.hwp`가 `captureContaminated=false`인데도 dark `webViewSnapshot` PNG로 떨어지는 문제가 드러났다. 원인은 current `rhwp-studio`가 background/behind/front layer를 sibling canvas로 렌더링하는데, harness의 page state probe가 target canvas 외 canvas를 overlay 후보에서 제외하고 있었기 때문이다.

보정 후 target 자신만 제외하고 겹치는 sibling canvas layer를 overlay 후보로 계산한다. 기존 `domComposite` exporter는 이미 intersecting canvas/img를 합성하므로 exporter 자체는 변경하지 않았다.

## 변경 전·후 정량 비교

`복학원서.hwp` 기준:

| 항목 | #390 측정 | #398 최종 |
|------|-----------|-----------|
| reference 해석 | local font UI contamination으로 품질 판단 제외 | clean capture sample 후보로 복구 |
| `captureMode` | contamination 때문에 diff 99%대 | `domComposite` |
| `overlayIncluded` | 해석 불가 | `true` |
| `captureContaminated` | metadata 없음 | `false` |
| `modalCount` | metadata 없음 | `0` |
| `toastCount` | metadata 없음 | `0` |
| `localFontUIVisible` | metadata 없음 | `false` |
| `ChangedPercent` | CoreGraphics 99.5953% / Skia 99.3883% | CoreGraphics 7.2888% |

Stage 4 smoke 최종 수치:

| sample | Status | StudioCapture | automationStrategy | automationLocalFontsSeeded | captureContaminated | modal/toast/localFont | ChangedPercent |
|--------|--------|---------------|--------------------|----------------------------|---------------------|-----------------------|----------------|
| `복학원서.hwp` | OK | `domComposite;ui=clean` | `rhwp-request` | `true` | `false` | `0 / 0 / false` | `7.2888%` |
| `request.hwp` | OK | `domComposite;ui=clean` | `rhwp-request` | `true` | `false` | `0 / 0 / false` | `17.6908%` |
| `KTX.hwp` | OK | `domComposite;ui=clean` | `rhwp-request` | `true` | `false` | `0 / 0 / false` | `30.8921%` |

## 단계 요약

| Stage | 커밋 | 요약 |
|------|------|------|
| 계획 | `3015b98` | 수행계획서 작성과 오늘할일 갱신 |
| 구현계획 | `1f4232f` | 단계별 구현계획서 작성 |
| Stage 1 | `f77a350` | current harness load/capture contamination inventory |
| Stage 2 | `f563e9a` | automation load path 구현 |
| Stage 3 | `14eba20` | contamination metadata와 failure 분리 |
| Stage 4 | `09203f3` | target sample smoke와 sibling canvas overlay 보정 |
| Stage 5 | 이번 커밋 | 최종 보고서 작성과 #396 handoff 정리 |

## 검증 결과

정적 검증:

```bash
swiftc -parse scripts/preview_visual_diff_harness.swift
git diff --check
```

결과: 둘 다 출력 없이 성공.

Target smoke:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task398-automation-load --page 1 \
  samples/복학원서.hwp samples/basic/request.hwp
```

결과:

```text
OK 복학원서.hwp
OK request.hwp
```

`복학원서.hwp`는 smoke 중 기존 `LAYOUT_OVERFLOW` warning을 출력했다. 이 warning은 capture contamination이 아니라 renderer/layout 이력으로 분리한다.

Optional KTX smoke:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task398-automation-load-ktx --page 1 \
  samples/basic/KTX.hwp
```

결과:

```text
OK KTX.hwp
```

최종 보고서 검증:

```bash
rg -n "#398|#396|automationLoad|captureContaminated|복학원서|Skia|CoreGraphics|preview visual diff" \
  mydocs/report/task_m020_398_report.md mydocs/orders/20260629.md
git diff --check
git status --short --branch
git log --oneline devel..local/task398
```

## #396 Handoff

#396 Stage 4에서 `bokhakwonseo-capture-sentinel`을 해석할 때 다음 기준을 적용한다.

| 항목 | 기준 |
|------|------|
| local font modal contamination | #398 이후 제외 사유로 보지 않는다 |
| clean capture 확인 | `automationLoad=true`, `automationStrategy=rhwp-request`, `automationLocalFontsSeeded=true`, `captureContaminated=false` 확인 |
| overlay-positive reference | `captureMode=domComposite`, `overlayIncluded=true`, `usedOverlayUnion=true` 확인 |
| residual UI | `modalCount=0`, `toastCount=0`, `localFontUIVisible=false` 확인 |
| layout warning | `LAYOUT_OVERFLOW`는 capture contamination이 아니라 renderer/layout 이슈로 별도 해석 |
| Skia default 판단 | #398 범위 밖. #396 visual suite와 renderer parity 기준에서 별도 판단 |

권장 재측정 명령:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task396-after-task398 --page 1 \
  samples/복학원서.hwp samples/basic/request.hwp samples/basic/KTX.hwp
```

해석 기준:

- `복학원서.hwp`: 더 이상 `local font modal contamination`으로 제외하지 않는다.
- `복학원서.hwp`: `LAYOUT_OVERFLOW`, watermark/effect, displayText 민감성은 renderer parity 항목으로 분리한다.
- `KTX.hwp`: #390에서 확인한 visual regression 판단은 #398로 바뀌지 않았다.
- `request.hwp`, `KTX.hwp`도 current `rhwp-studio` layered canvas rendering 때문에 `overlayIncluded=true`가 될 수 있다. 이 값은 과거 “overlay 없는 sample” 표현과 다르므로 `captureMode`만으로 sample 성격을 단정하지 않는다.

## 잔여 위험과 후속 작업

| 항목 | 상태 | 처리 |
|------|------|------|
| production asset direct globals 부재 | 잔여 | `rhwp-request` strategy를 metadata에 명시. upstream/source와 production asset 차이는 별도 추적 가능 |
| local font prompt 회피 방식 | 제한적 해결 | non-persistent local font snapshot seed로 분석용 capture에서는 해결. 일반 앱 UI 동작은 변경하지 않음 |
| sibling canvas overlay detector | 해결 | target 외 canvas layer를 overlay 후보로 포함하도록 보정 |
| `복학원서.hwp` layout overflow | 잔여 | #396 renderer/layout 해석 대상으로 이관 |
| Skia visual default 판단 | 범위 밖 | #396 visual suite, #392, #389 등 후속 이슈에서 판단 |

## PR 게시 준비 메모

권장 PR 제목:

```text
Task #398: preview visual diff harness automation load path 추가
```

권장 리뷰 포인트:

- bundled `rhwp-studio` asset을 직접 patch하지 않고 harness 쪽 automation load path로만 해결한 범위가 맞는지
- non-persistent local font snapshot seed가 분석용 reference capture에 한정되어 있는지
- `captureContaminated`, `modalCount`, `toastCount`, `localFontUIVisible` metadata로 renderer failure와 capture contamination을 구분할 수 있는지
- sibling canvas overlay counting 보정이 #293의 `domComposite` / `overlayIncluded=true` 계약을 유지하는지
- #396 handoff에서 `복학원서.hwp`를 clean capture sample 후보로 복구하되 layout overflow를 별도로 해석하는 정리가 충분한지

## 작업지시자 승인 요청

Task #398의 구현, target smoke, 최종 보고서 작성, 오늘할일 완료 처리를 완료했다. PR 게시 단계 진입 여부를 승인해 달라.
