# Task M020 #257 구현 계획서

수행계획서: `mydocs/plans/task_m020_257.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #257 Quick Look preview에서 Skia PNG backend 적용과 다중 페이지 PDF fallback 검증
- 마일스톤: M020 (`v0.2.x Skia Quick Look/Thumbnail Backend`)
- 브랜치: `local/task257`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac`
- 기준 브랜치: `devel`
- 선행 상태: #255에서 `rhwp_render_page_png` ABI가 추가되었고, #256에서 `HwpPageImageRenderer`의 `coreGraphicsOnly`/`skiaOptIn` 정책과 diagnostics/fallback contract가 구현되었다.
- 목표: Quick Look 단일 페이지 PNG reply와 다중 페이지 bitmap PDF preview가 #256 Shared renderer contract를 통해 Skia opt-in 경로를 검증하고, 실패 시 CoreGraphics fallback을 유지한다.

## 구현 원칙

- Quick Look surface만 변경한다. Finder thumbnail 적용과 cache key 변경은 #258로 남긴다.
- `Sources/RhwpCoreBridge`에는 AppKit/UIKit 의존을 추가하지 않는다.
- Skia 실패는 Quick Look text fallback으로 바로 가지 않고 #256 Shared renderer의 CoreGraphics fallback을 먼저 사용한다.
- 단일 페이지 PNG reply는 `policy: .skiaOptIn`을 명시해 Skia success/fallback diagnostics를 확보한다.
- 다중 페이지 PDF는 page render policy를 받을 수 있는 API를 추가하고, Quick Look preview 경로에서 `skiaOptIn`을 명시한다.
- 다중 페이지 PDF는 여전히 bitmap PDF container이며, vector PDF export 개선은 포함하지 않는다.
- `Skia default` 또는 `Skia first`의 release 판단은 #259에서 수행한다. 이 이슈는 Quick Look surface의 opt-in 적용과 검증 결과를 남긴다.
- 새 upstream rhwp release 반영과 #947/#976/#982/#1018 회귀 확인은 #278에서 수행한다.

## Quick Look Backend Contract

Quick Look에서 사용할 policy와 diagnostics는 #256 contract를 그대로 따른다.

| 항목 | 값/필드 | 정책 |
|---|---|---|
| 단일 페이지 PNG policy | `.skiaOptIn` | Skia PNG render를 먼저 시도하고 실패 시 CoreGraphics fallback |
| 다중 페이지 PDF policy | `.skiaOptIn` 명시 전달 | page별 Skia image 또는 fallback image를 PDF page에 삽입 |
| 최종 reply type | `.png`, `.pdf`, `.plainText` | 기존 page count/fallback classifier 정책 유지 |
| diagnostics | `backendUsed`, `fallbackReason`, `pngBytes`, `durationMs`, `pixelSize` | Quick Look 로그와 stage 보고서 입력 |
| file size guard | `hwpQuickLookMaxFileSize` | Skia 호출 전 기존 위치에서 유지 |
| empty/invalid page fallback | 기존 `HwpDocumentFallbackClassifier` | Shared renderer까지 도달하지 못한 입력 오류는 기존 text reply 정책 유지 |

로그는 filename basename만 public으로 남기고, backend/fallback/duration/byte count는 diagnostics에서 읽어 기록한다. enum은 `String(describing:)`을 사용하되, 후속 필요가 있으면 Stage 2에서 작은 formatter helper로 고정한다.

## Stage 1. Quick Look render 호출부 inventory

### 목표

Quick Look 단일 PNG reply, 다중 PDF reply, fallback classifier 흐름을 확인하고 Stage 2-3에서 변경할 API를 고정한다.

### 작업

- `HwpPreviewProvider`의 `pngReply`, `pdfReply`, text fallback 경로를 확인한다.
- `HwpPreviewPDFRenderer`의 `render(context:)`, `render(previewInfo:)`, `render(document:pageCount:contentSize:)` 호출 관계를 확인한다.
- `HwpPageImageRenderer`의 `skiaOptIn` diagnostics contract를 확인한다.
- Quick Look 관련 smoke helper와 비교 script가 compile할 수 있도록 non-breaking API 방향을 정한다.
- Stage 1 보고서에 확정된 변경 파일, API, 검증 명령을 기록한다.

### 산출물

- `mydocs/plans/task_m020_257_impl.md`
- `mydocs/working/task_m020_257_stage1.md`
- `mydocs/orders/20260521.md`

### 검증

```bash
rg -n "HwpPreviewProvider|HwpPreviewPDFRenderer|HwpPageImageRenderer|renderPage\\(|skiaOptIn|backendUsed|fallbackReason|pngBytes|durationMs" \
  Sources/QLExtension Sources/Shared scripts --glob '!**/Resources/**'
rg -n "#257|Stage 1|skiaOptIn|Quick Look|backendUsed|fallbackReason|durationMs" \
  mydocs/plans/task_m020_257_impl.md mydocs/working/task_m020_257_stage1.md mydocs/orders/20260521.md
git diff --check
```

### 완료 기준

- Stage 2-3에서 구현할 Swift API와 logging 범위가 단계 보고서에 고정된다.
- 아직 Swift source를 변경하지 않는다.

### 커밋 메시지

```text
Task #257 Stage 1: Quick Look Skia 적용 범위 확정
```

## Stage 2. Quick Look 단일 페이지 PNG Skia opt-in 적용

### 목표

단일 페이지 Quick Look PNG reply가 `HwpPageImageRenderer.renderPage(..., policy: .skiaOptIn)`을 사용하고, 최종 backend와 fallback 이유를 로그에 남기도록 한다.

### 작업

- `HwpPreviewProvider.pngReply`에서 render policy를 `.skiaOptIn`으로 명시한다.
- PNG encode 전후 로그에 `backendUsed`, `fallbackReason`, `pngBytes`, `durationMs.totalMs`, `pixelSize`를 기록한다.
- Skia fallback은 Shared renderer가 처리하므로 provider는 기존 fallback classifier 흐름을 유지한다.
- 단일 페이지 샘플에서 Skia path가 compile/runtime smoke 후보로 준비되었는지 확인한다.
- Stage 2 보고서에 변경 API와 로그 필드를 기록한다.

### 산출물

- `Sources/QLExtension/HwpPreviewProvider.swift`
- `mydocs/working/task_m020_257_stage2.md`

### 검증

```bash
./scripts/check-no-appkit.sh
rg -n "skiaOptIn|backendUsed|fallbackReason|pngBytes|durationMs|Preview PNG" Sources/QLExtension Sources/Shared
xcodebuild -project Alhangeul.xcodeproj -scheme QLExtension -configuration Debug -derivedDataPath build.noindex/DerivedDataTask257 CODE_SIGNING_ALLOWED=NO build
git diff --check
```

### 완료 기준

- 단일 페이지 PNG reply가 Skia opt-in path를 시도한다.
- Skia 실패 시 Shared renderer의 CoreGraphics fallback 결과가 PNG reply로 계속 반환될 수 있다.
- Quick Look 로그에서 실제 backend와 fallback 여부를 확인할 수 있다.

### 커밋 메시지

```text
Task #257 Stage 2: Quick Look PNG Skia opt-in 적용
```

## Stage 3. 다중 페이지 PDF Skia opt-in 경로 연결

### 목표

다중 페이지 Quick Look PDF renderer가 page render policy를 받을 수 있게 하고, Quick Look preview에서 Skia opt-in page image를 PDF page에 삽입할 수 있게 한다.

### 작업

- `HwpPreviewPDFRenderer.render(context:)`, `render(previewInfo:)`, `render(document:pageCount:contentSize:)`에 `policy` 기본 인자를 추가한다.
- 기존 call site와 scripts는 기본값 때문에 CoreGraphics 호환을 유지한다.
- `HwpPreviewProvider.pdfReply`는 `policy: .skiaOptIn`을 명시한다.
- PDF render result에 page별 diagnostics summary를 담을 수 있는 구조를 추가한다.
- `pdfReply` 로그에 page count, backend summary, fallback count, total duration 후보를 기록한다.
- Stage 3 보고서에 다중 페이지 PDF default/opt-in 판단과 #259 handoff를 기록한다.

### 산출물

- `Sources/Shared/HwpPreviewPDFRenderer.swift`
- `Sources/QLExtension/HwpPreviewProvider.swift`
- 필요 시 `scripts/quicklook_pdf_renderer_compare.swift`
- `mydocs/working/task_m020_257_stage3.md`

### 검증

```bash
./scripts/check-no-appkit.sh
rg -n "policy: HwpPageRenderPolicy|skiaOptIn|backendUsed|fallbackReason|pageDiagnostics|HwpRenderedPreviewPDF" \
  Sources/Shared Sources/QLExtension scripts
xcodebuild -project Alhangeul.xcodeproj -scheme QLExtension -configuration Debug -derivedDataPath build.noindex/DerivedDataTask257 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedDataTask257 CODE_SIGNING_ALLOWED=NO build
git diff --check
```

### 완료 기준

- 다중 페이지 PDF renderer가 page별 `skiaOptIn` render 결과를 받을 수 있다.
- 기존 PDF renderer helper와 비교 script는 기본 인자로 계속 동작한다.
- page별 backend/fallback 요약을 Quick Look 로그와 보고서에 남길 수 있다.

### 커밋 메시지

```text
Task #257 Stage 3: Quick Look PDF Skia opt-in 경로 연결
```

## Stage 4. Quick Look smoke와 fallback 검증

### 목표

대표 샘플에서 Quick Look 단일 PNG와 다중 PDF 경로의 Skia opt-in 결과, fallback 결과, latency/byte 정보를 기록한다.

### 작업

- QLExtension과 HostApp Debug build를 실행한다.
- 기존 CoreGraphics baseline smoke가 깨지지 않았는지 `validate-stage3-render.sh`로 확인한다.
- 단일 페이지 샘플은 `samples/basic/request.hwp`, `samples/basic/KTX.hwp`, 필요 시 `samples/복학원서.hwp`를 사용한다.
- 다중 페이지 샘플은 `samples/hwp-multi-001.hwp`, `samples/basic/exam_math.hwp`, `samples/hwpx/hwpx-01.hwpx` 중 최소 1개 이상을 사용한다.
- `compare-quicklook-pdf-renderers.sh` 또는 task 전용 임시 command로 PDF path 결과를 측정한다.
- 설치본/시스템 Quick Look smoke가 필요한 경우 `smoke-clean-quicklook-install.sh`는 Debug build 검증과 분리해 기록한다.
- Stage 4 보고서에 명령, 결과, 알려진 제한, #258/#259/#278 handoff를 정리한다.

### 산출물

- 필요 시 task 전용 smoke 산출물 기록
- `mydocs/working/task_m020_257_stage4.md`

### 검증

```bash
./scripts/check-no-appkit.sh
xcodebuild -project Alhangeul.xcodeproj -scheme QLExtension -configuration Debug -derivedDataPath build.noindex/DerivedDataTask257 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedDataTask257 CODE_SIGNING_ALLOWED=NO build
./scripts/validate-stage3-render.sh output/task257-stage4 samples/basic/request.hwp samples/basic/KTX.hwp
./scripts/compare-quicklook-pdf-renderers.sh output/task257-quicklook-pdf samples/hwp-multi-001.hwp samples/hwpx/hwpx-01.hwpx
git diff --check
git status --short --branch
```

필요 시 설치본 smoke:

```bash
./scripts/smoke-clean-quicklook-install.sh
```

### 완료 기준

- QLExtension Debug build가 통과한다.
- 단일 PNG와 다중 PDF path에서 Skia opt-in success 또는 CoreGraphics fallback 결과가 기록된다.
- 기존 text fallback classifier 흐름이 보존된다.
- #258 Thumbnail 적용과 #259 readiness gate에 넘길 Quick Look 결과가 정리된다.

### 커밋 메시지

```text
Task #257 Stage 4: Quick Look Skia smoke 검증
```

## Stage 5. 최종 보고서와 PR 준비

### 목표

전체 수용 기준을 다시 확인하고, 최종 결과보고서와 오늘할일 완료 처리를 수행한 뒤 PR 게시 준비 상태로 만든다.

### 작업

- Stage 1-4 산출물과 검증 결과를 최종 보고서에 정리한다.
- 다중 페이지 PDF Skia 적용의 default 보류 여부와 #259 판단 입력을 명시한다.
- #258, #259, #278 handoff를 정리한다.
- 오늘할일을 완료로 갱신한다.
- PR 게시 전 최종 build/source 검증과 `git status` 확인을 수행한다.

### 산출물

- `mydocs/report/task_m020_257_report.md`
- `mydocs/orders/20260521.md`

### 검증

```bash
./scripts/check-no-appkit.sh
xcodebuild -project Alhangeul.xcodeproj -scheme QLExtension -configuration Debug -derivedDataPath build.noindex/DerivedDataTask257 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedDataTask257 CODE_SIGNING_ALLOWED=NO build
rg -n "#257|skiaOptIn|backendUsed|fallbackReason|Quick Look|#258|#259|#278" \
  mydocs/report/task_m020_257_report.md mydocs/orders/20260521.md Sources/QLExtension Sources/Shared
git diff --check
git status --short --branch
```

### 완료 기준

- #257 완료 기준이 최종 보고서에 대응되어 있다.
- 작업 브랜치에 미커밋 변경이 없다.
- PR 생성 전 publish 준비 상태다.

### 커밋 메시지

```text
Task #257 Stage 5 + 최종 보고서: Quick Look Skia 적용 결과 정리
```
