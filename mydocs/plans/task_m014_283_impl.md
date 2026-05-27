# Task M014 #283 구현 계획서

수행계획서: `mydocs/plans/task_m014_283.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #283 rhwp-studio 문서 열기 normalization·external image parity 영향 조사
- 마일스톤: M014 (`v0.1.4 Native Preview/Viewer Parity`)
- 브랜치: `local/task283`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac`
- 기준 브랜치: `devel`
- 목표: `rhwp-studio` open pipeline과 native preview open/render pipeline 차이가 v0.1.4 preview parity의 blocker인지 판단하고, 필요 시 후속 bridge/open option 범위를 확정한다.

## 구현 원칙

- 이번 작업은 조사와 의사결정이 핵심이다. renderer/compositor production 경로는 직접 수정하지 않는다.
- #280의 `preview-visual-diff-harness.sh`를 우선 재사용하고, 새 script가 필요하면 조사 산출물 생성용으로만 최소화한다.
- upstream `edwardkim/rhwp` 수정, unreleased commit pin, rhwp-studio asset 갱신은 하지 않는다.
- sample/dev server 전용 external image population을 public app 기본 동작으로 그대로 복제하지 않는다.
- `Sources/RhwpCoreBridge`에는 AppKit/UIKit/WebKit 의존을 추가하지 않는다.
- 결과는 “M014 blocker”, “후속 이슈 필요”, “현재 영향 낮음”, “sample/dev 전용으로 제외” 중 하나로 분류한다.

## 현재 기준 관찰

수행계획 승인 직후 확인한 코드 기준으로 다음 경로를 Stage 1 inventory 대상으로 고정한다.

| 영역 | 현재 관찰 | 검증 포인트 |
|---|---|---|
| HostApp open | `DocumentViewerStore.loadDocument(from:)`가 security scope 안에서 `Data(contentsOf:)`와 `url.lastPathComponent`를 읽고 `RhwpStudioDocumentPayload`에 저장 | base directory가 payload에 포함되지 않음 |
| Studio URL | `RhwpStudioResourceLocator.loadURL(for:)`가 `url=alhangeul-document://current?revision=...`, `filename=...` query를 생성 | `filename`만 Web/WASM open path에 전달됨 |
| Studio document bytes | `RhwpStudioDocumentSchemeHandler`가 current revision bytes를 `application/octet-stream`으로 응답 | original file URL/base directory는 JS에 전달되지 않음 |
| bundled JS open | minified bundle에서 `Ul()`이 `url` query를 fetch하고 `Pl(bytes, filename, null)`을 호출 | open 직후 `X.loadDocument(bytes, filename)`와 editor init이 render에 미치는 영향 |
| native preview | `HwpPreviewPDFRenderer.loadDocument(fileURL:)`가 `Data(contentsOf: .mappedIfSafe)`와 `fileURL.lastPathComponent`로 `RhwpDocument` 생성 | native도 base directory를 core에 전달하지 않음 |
| Quick Look/Thumbnail | request fileURL의 `lastPathComponent`를 diagnostics에 사용하고 Shared renderer를 호출 | extension 경로도 base directory population 없음 |

이 관찰은 구현계획의 출발점이며, Stage 1에서 파일/라인 기준으로 재확인한다.

## 조사 산출물 구조

이번 작업은 다음 문서 산출물을 만든다.

| 파일 | 역할 |
|---|---|
| `mydocs/plans/task_m014_283_impl.md` | 단계별 조사 범위, 검증, 완료 기준 |
| `mydocs/working/task_m014_283_stage1.md` | open pipeline inventory와 조사 항목 고정 |
| `mydocs/working/task_m014_283_stage2.md` | normalization/editor initialization 영향 조사 |
| `mydocs/working/task_m014_283_stage3.md` | filename/base directory/external image 영향 조사와 harness 관찰 |
| `mydocs/report/task_m014_283_report.md` | 최종 결론, blocker 여부, 후속 이슈/handoff |
| 필요 시 `mydocs/tech/v014_open_pipeline_parity.md` | M014 후속 작업이 참조할 open pipeline parity 메모 |

## Stage 1. open pipeline inventory와 조사 기준 확정

### 목표

HostApp `rhwp-studio`, Quick Look, Thumbnail, Shared native renderer의 문서 open path를 파일/함수 단위로 정리하고 Stage 2-3 조사 기준을 확정한다.

### 작업

- HostApp open path inventory:
  - `DocumentViewerStore.loadDocument(from:)`
  - `RhwpStudioDocumentPayload`
  - `RhwpStudioResourceLocator.loadURL(for:)`
  - `RhwpStudioDocumentSchemeHandler`
  - `RhwpStudioWebView` documentProvider update/load 흐름
- native preview open path inventory:
  - `HwpPreviewPDFRenderer.load(fileURL:)`
  - `HwpPreviewPDFRenderer.inspect(fileURL:)`
  - `HwpPreviewPDFRenderer.render(previewInfo:)`
  - `HwpPageImageRenderer.renderFirstPage(fileURL:...)`
  - Quick Look/Thumbnail provider call site
- bundled `rhwp-studio` JS open path에서 다음 symbol/흐름을 확인한다.
  - `loadFromUrlParam`
  - `fetch(url)`
  - `loadDocument(bytes, filename)`
  - `initDoc`/canvas load
  - `convertToEditable`
  - `getExternalImageBasenames` 또는 external image population 후보
- Stage 2-3에서 확인할 sample 후보와 판단 기준을 고정한다.

### 산출물

- `mydocs/working/task_m014_283_stage1.md`

### 검증

```bash
rg -n "loadDocument|RhwpStudioDocumentPayload|RhwpStudioResourceLocator|RhwpStudioDocumentSchemeHandler|HwpPreviewPDFRenderer|HwpPageImageRenderer|providePreview|provideThumbnail" \
  Sources/HostApp Sources/Shared Sources/QLExtension Sources/ThumbnailExtension
rg -n "loadFromUrlParam|loadDocument|convertToEditable|getExternalImageBasenames|external|image|filename|url" \
  Sources/HostApp/Resources/rhwp-studio/rhwp.d.ts \
  Sources/HostApp/Resources/rhwp-studio/assets/index-*.js
git diff --check
```

### 완료 기준

- Studio/native/Quick Look/Thumbnail open path가 파일/함수 단위로 표에 정리된다.
- 각 경로가 bytes, filename, base directory, external image 정보를 어떻게 전달하는지 명시된다.
- Stage 2/3 sample 후보와 판단 기준이 보고서에 고정된다.

### 커밋 메시지

```text
Task #283 Stage 1: open pipeline inventory 정리
```

## Stage 2. normalization/editor initialization 영향 조사

### 목표

`rhwp-studio`의 editable/editor initialization 관련 처리가 preview render output에 영향을 주는지 판단한다.

### 작업

- bundled JS와 `rhwp.d.ts` 기준으로 `convertToEditable`, validation warning/reflow, stable id 관련 API가 open path에서 호출되는지 확인한다.
- `X.loadDocument(bytes, filename)` 뒤 `initDoc`/`canvasView.loadDocument()` 흐름이 render tree나 page layout을 바꾸는지 가능한 근거를 정리한다.
- native `RhwpDocument(data:filename:)` 경로와 비교해 normalization 차이를 항목별로 분류한다.
- 필요한 경우 #280 harness로 일반 샘플의 baseline 수치를 확인하되, renderer 차이와 open normalization 차이를 혼동하지 않도록 기록한다.

### 산출물

- `mydocs/working/task_m014_283_stage2.md`

### 검증

```bash
rg -n "convertToEditable|validation|reflow|stable|paragraph|loadDocument|initDoc|document-changed|canvasView" \
  Sources/HostApp/Resources/rhwp-studio/rhwp.d.ts \
  Sources/HostApp/Resources/rhwp-studio/assets/index-*.js
./scripts/verify-rhwp-studio-assets.sh
git diff --check
```

필요 시:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task283-normalization --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx
```

### 완료 기준

- `convertToEditable`/stable id/editor init 항목이 preview blocker인지 아닌지 판단된다.
- 영향이 불명확한 항목은 후속 검증 후보와 이유가 남는다.
- production renderer/source 변경 없이 문서화로 단계가 닫힌다.

### 커밋 메시지

```text
Task #283 Stage 2: normalization 영향 조사
```

## Stage 3. filename/base directory/external image 영향 조사

### 목표

filename/base directory/external linked image 차이가 `rhwp-studio` reference와 native preview output 차이의 원인이 되는지 확인한다.

### 작업

- repository sample에서 external image 후보를 식별한다.
  - `samples/tac-img-02.hwp`
  - `samples/tac-img-02.hwpx`
  - `samples/hwp-img-001.hwp`
  - `samples/img-start-001.hwp`
  - 필요 시 `samples/images/*`와 연결 후보
- core/WASM API에서 external image basename 조회나 population API가 현재 bridge에 노출되어 있는지 확인한다.
- #280 harness로 후보 샘플의 Studio/native diff를 관찰한다.
- diff가 큰 경우 원인을 external image resolution, image effect/fill/tile, overlay/compositor, font/layout 차이로 분류한다.
- base-dir-aware open 또는 external image population bridge가 필요한지 판단한다.

### 산출물

- `mydocs/working/task_m014_283_stage3.md`
- 필요 시 `build.noindex/task283-external-image/summary.md` smoke 산출물

### 검증

```bash
find samples -maxdepth 3 -type f | rg -i "(tac-img|hwp-img|img-start|images|\\.hwp$|\\.hwpx$)"
rg -n "ExternalImage|externalImage|external_image|getExternalImageBasenames|populate|imageBasename|baseDir|base directory" \
  Sources Frameworks/generated_rhwp.h Sources/HostApp/Resources/rhwp-studio/rhwp.d.ts \
  Sources/HostApp/Resources/rhwp-studio/assets/index-*.js
./scripts/preview-visual-diff-harness.sh build.noindex/task283-external-image --page 1 \
  samples/tac-img-02.hwp samples/tac-img-02.hwpx samples/hwp-img-001.hwp samples/img-start-001.hwp
sed -n '1,120p' build.noindex/task283-external-image/summary.md
git diff --check
```

### 완료 기준

- external image 관련 차이가 M014 blocker인지, #116/#122/#281/#282 범위인지, 별도 bridge/open option 이슈인지 분류된다.
- sample/dev server 전용 population은 public app 기본 동작에 넣을지 말지 판단 근거가 남는다.
- #280 harness 수치가 있을 경우 output dir, sample, 핵심 metric이 보고서에 기록된다.

### 커밋 메시지

```text
Task #283 Stage 3: external image open 영향 조사
```

## Stage 4. 결론, follow-up 범위, 최종 보고

### 목표

Stage 1-3 결과를 종합해 M014 후속 작업의 실행 순서와 blocker 여부를 정리한다.

### 작업

- open pipeline 차이 항목별 최종 판정표를 작성한다.
- #281/#282/#116/#122/#121/#110에 전달할 handoff를 정리한다.
- 별도 follow-up 이슈가 필요하면 제목, 범위, 우선순위 초안을 작성한다.
- 최종 보고서에 smoke 측정 결과, 결론, 한계, 남은 리스크를 기록한다.
- 오늘할일 #283 행을 완료 상태로 갱신한다.

### 산출물

- `mydocs/report/task_m014_283_report.md`
- 필요 시 `mydocs/tech/v014_open_pipeline_parity.md`
- `mydocs/orders/20260527.md`

### 검증

```bash
rg -n "#283|open pipeline|normalization|external image|base directory|#281|#282|#116|#122|#121|#110" \
  mydocs/report/task_m014_283_report.md mydocs/orders/20260527.md
git diff --check
git status --short --branch
```

### 완료 기준

- #283 완료 기준인 “M014 preview parity에 영향을 주는 open pipeline 차이 문서화”가 충족된다.
- 구현 필요 항목은 후속 이슈 또는 기존 M014 이슈 handoff로 분류된다.
- 영향이 낮은 항목은 M014 blocker에서 제외하는 근거가 남는다.

### 커밋 메시지

```text
Task #283 Stage 4: open pipeline parity 결론 정리
```

## 승인 요청 사항

1. 위 4단계 구현계획으로 #283을 진행하는 것에 대한 승인
2. Stage 1에서 production source 수정 없이 inventory와 조사 기준 확정만 수행하는 범위 승인
3. Stage 3에서 WKWebView 기반 #280 harness smoke는 sandbox 밖 실행 승인이 필요할 수 있다는 점 확인
4. 승인 후 다음 단계: Stage 1 open pipeline inventory 진행

승인 전에는 Stage 1 보고서 작성 외 조사 실행이나 source/script 변경을 진행하지 않는다.
