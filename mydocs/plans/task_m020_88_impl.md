# Task M020 #88 구현 계획서

수행계획서: `mydocs/plans/task_m020_88.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #88 View-based Quick Look preview visible-page lazy rendering 전환
- 마일스톤: M020 (`v0.2.x Skia Quick Look/Thumbnail Backend`)
- 브랜치: `local/task88`
- 기준 브랜치: `devel`
- 목표: 현재 Quick Look PDF preview와 같은 사용자 경험을 우선 유지하면서, view-based `PDFView + PDFThumbnailView` 경로가 visible page 중심 lazy rendering을 제공하는지 검증한다. 가능하면 해당 경로로 성능을 개선하고, 불가능하면 현행 data-based PDF preview UI를 유지한 채 PDF 생성 성능 최적화로 전환한다.

## 구현 원칙

- `Sources/RhwpCoreBridge`에는 AppKit/UIKit/QuickLookUI 의존을 추가하지 않는다.
- Quick Look UI와 lifecycle 코드는 `Sources/QLExtension`이 소유한다.
- 문서 open, page size 조회, page image rendering은 기존 `RhwpDocument`, `HwpPageImageRenderer` contract를 재사용한다.
- #256의 `skiaOptIn`은 이번 작업에서 기본으로 켜지 않는다. 별도 승인 전까지 page render policy는 기본 `coreGraphicsOnly`로 유지한다.
- View-based preview 전환은 Thumbnail extension 동작을 변경하지 않는다.
- `preparePreviewOfFile(at:completionHandler:)`는 main thread에서 호출되므로, 긴 parsing/render 작업은 background task로 넘기고 completion handler는 첫 표시 준비 단위에서 가능한 빨리 호출하는 방향으로 설계한다.
- request generation token과 cancellable task set을 둬서 빠른 Finder selection 전환 또는 view controller 해제 후 stale render 결과가 UI에 반영되지 않게 한다.
- fallback은 기존 Quick Look text fallback과 같은 사용자 메시지 정책을 유지하되, view-based UI 안에서 표시할 수 있는 오류 view로 연결한다.
- 사용자 경험은 현재 Quick Look PDF preview의 main page, right thumbnail rail, PDF-like scroll/zoom 동작 보존을 우선한다. 이를 보존할 수 없는 `NSScrollView` 직접 page stack은 이번 지시 이후 기본 구현 후보에서 제외한다.
- `PDFView + PDFThumbnailView`가 lazy하지 않다고 확인되면 커스텀 page stack으로 전환하지 않고, 현행 data-based PDF preview를 유지하며 PDF 생성 속도를 줄이는 최적화 단계로 전환한다.
- Stage별 산출물에는 실행 명령, 샘플, 관측 로그 위치, 남은 리스크를 기록한다.

## Stage 1. View-based Quick Look API와 현행 구조 inventory

참고: Stage 1 최초 보고서는 lazy scheduling control 기준으로 `NSScrollView` 직접 page stack을 선택했지만, 이후 작업지시자가 현재 Quick Look PDF preview와 같은 UI 유지를 명확히 요구했다. 따라서 이 구현계획서는 Stage 1의 API inventory는 유지하되, Stage 2 이후 기본 경로를 `PDFView + PDFThumbnailView` lazy 검증과 현행 PDF 생성 최적화 fallback으로 보정한다.

### 목표

현재 data-based preview 설정과 macOS SDK의 view-based preview contract를 확인하고, Stage 2 이후 실제 전환 범위를 고정한다.

### 작업

- `Sources/QLExtension/HwpPreviewProvider.swift`, `Sources/QLExtension/Info.plist`, `project.yml`의 현재 data-based preview 구조를 정리한다.
- SDK header 기준 `QLPreviewingController.preparePreviewOfFile(at:completionHandler:)`와 `providePreview(for:completionHandler:)` 차이를 기록한다.
- `QLIsDataBasedPreview=true` 제거 또는 변경 필요 여부와 `NSExtensionPrincipalClass` 변경 방식을 확정한다.
- `NSScrollView` 직접 page stack과 `PDFView` 후보를 lazy scheduling, cancellation, memory pressure 관점에서 비교한다.
- `HwpPreviewPDFRenderer.inspect`, `HwpPageImageRenderer.renderPage`, `HwpDocumentFallbackClassifier` 재사용 범위를 정한다.
- Stage 1 보고서에 최종 채택 container와 source 변경 범위를 기록한다.

### 산출물

- `mydocs/working/task_m020_88_stage1.md`

### 검증

```bash
rg -n "QLPreviewProvider|QLPreviewingController|providePreview|preparePreview|QLIsDataBasedPreview|NSExtensionPrincipalClass|QLSupportedContentTypes" \
  Sources/QLExtension project.yml
sed -n '1,130p' /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.5.sdk/System/Library/Frameworks/QuickLookUI.framework/Versions/A/Headers/QLPreviewingController.h
env CLANG_MODULE_CACHE_PATH=/private/tmp/rhwp-task88-clang-cache \
  xcrun swift -e 'import QuickLookUI; import AppKit; final class Probe: NSViewController, QLPreviewingController { func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) { handler(nil) } } ; print(Probe.self)'
git diff --check -- mydocs/working/task_m020_88_stage1.md
```

### 완료 기준

- View-based principal class 구조와 Info.plist 변경 방향이 확정되어 있다.
- `NSScrollView`/`PDFView` 중 Stage 2 이후 구현할 container가 정해져 있다.
- 아직 제품 source는 변경하지 않는다.

### 커밋 메시지

```text
Task #88 Stage 1: View-based Quick Look 구조 확정
```

## Stage 2. `PDFView + PDFThumbnailView` view-based lazy 가능성 검증

### 목표

현재 Quick Look PDF preview와 유사한 UI를 유지할 수 있는 `PDFView + PDFThumbnailView` 기반 view controller prototype을 만들고, 이 경로가 first page 우선 표시와 visible page 중심 render를 허용하는지 검증한다.

### 작업

- 신규 `HwpPreviewPDFViewController`를 `NSViewController, QLPreviewingController`로 추가한다.
- `PDFView`와 `PDFThumbnailView`를 구성해 현재 Quick Look PDF preview와 유사한 main page + right thumbnail rail 구조를 만든다.
- custom `PDFDocument`/`PDFPage` 또는 최소 probe document를 사용해 `PDFView`가 최초 load와 scroll 시점에 page draw를 어떻게 요청하는지 기록한다.
- `preparePreviewOfFile(at:completionHandler:)`에서 request generation을 갱신하고 이전 작업을 취소하는 lifecycle skeleton을 만든다.
- `Sources/QLExtension/Info.plist`의 principal class와 `QLIsDataBasedPreview` 변경은 debug/probe gate 또는 명확한 Stage 2 범위 안에서만 수행하고, Stage 2 결과에 따라 유지/복원한다.
- 기존 `HwpPreviewProvider`의 data reply 구현은 반드시 유지해 fallback 경로와 비교 기준으로 둔다.
- Debug build에서 QLExtension과 HostApp compile/link를 확인한다.
- 가능한 경우 `qlmanage -p` runtime에서 현재 PDF UI 유사성과 lazy draw 로그를 관측한다.
- Stage 2 보고서를 작성한다.

### 산출물

- `Sources/QLExtension/HwpPreviewPDFViewController.swift`
- 필요 시 신규 `Sources/QLExtension/HwpPDFViewLazyProbe.swift`
- `Sources/QLExtension/Info.plist`
- `Sources/QLExtension/HwpPreviewProvider.swift` 유지
- 필요 시 `project.yml`
- `mydocs/working/task_m020_88_stage2.md`

### 검증

```bash
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme QLExtension \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask88 \
  CODE_SIGNING_ALLOWED=NO \
  build
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask88 \
  CODE_SIGNING_ALLOWED=NO \
  build
plutil -p Sources/QLExtension/Info.plist
rg -n "PDFView|PDFThumbnailView|PDFDocument|PDFPage|draw|generation|QLIsDataBasedPreview" Sources/QLExtension mydocs/working/task_m020_88_stage2.md
git diff --check
```

### 완료 기준

- `PDFView + PDFThumbnailView` 기반 view controller가 compile된다.
- 현재 Quick Look PDF preview와 유사한 UI를 유지할 수 있는지 판단 근거가 있다.
- 최초 load와 scroll에서 `PDFView`가 page를 lazy하게 요청하는지, 또는 전체 materialization을 유도하는지 관측 근거가 있다.
- 현행 data-based provider fallback은 보존되어 있다.

### 커밋 메시지

```text
Task #88 Stage 2: PDFView lazy preview 가능성 검증
```

## Stage 3. 결정 게이트와 구현 경로 확정

### 목표

Stage 2 관측 결과에 따라 `PDFView` lazy 경로를 제품화할지, 아니면 현행 data-based PDF preview UI를 유지하면서 생성 성능 최적화로 전환할지 결정한다.

### 작업

- Stage 2 결과를 `가능`, `부분 가능`, `불가능`으로 판정한다.
- 가능이면 `PDFView + PDFThumbnailView` 제품화 범위를 고정한다.
- 불가능이면 `HwpPreviewPDFRenderer` 현행 data-based PDF reply 유지와 생성 최적화 범위를 고정한다.
- 부분 가능이면 현재 PDF UI 보존 수준, lazy 효과, 구현 위험을 비교해 둘 중 하나로 좁힌다. 기본 선택은 사용자 지시에 따라 현행 PDF UI 유지 + 생성 최적화다.
- 경로별 남은 Stage 4-5 작업 범위와 검증 명령을 Stage 3 보고서에 확정한다.
- Stage 3 보고서를 작성한다.

### 산출물

- `mydocs/working/task_m020_88_stage3.md`
- 필요 시 Stage 2 probe source 유지/제거 결정
- 필요 시 `Sources/QLExtension/Info.plist` 복원 또는 제품화 유지
- 필요 시 `mydocs/plans/task_m020_88_impl.md`의 Stage 4-5 세부 검증 보강

### 검증

```bash
./scripts/check-no-appkit.sh
xcodebuild -project Alhangeul.xcodeproj \
  -scheme QLExtension \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask88 \
  CODE_SIGNING_ALLOWED=NO \
  build
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask88 \
  CODE_SIGNING_ALLOWED=NO \
  build
rg -n "PDFView|PDFThumbnailView|HwpPreviewPDFRenderer|decision|가능|불가능|최적화" \
  Sources/QLExtension Sources/Shared mydocs/working/task_m020_88_stage3.md
git diff --check
```

### 완료 기준

- Stage 2 결과에 따른 제품화 경로가 하나로 결정되어 있다.
- `PDFView` lazy 가능성이 있으면 Stage 4가 제품화 구현으로 이어질 수 있다.
- `PDFView` lazy 가능성이 없으면 Stage 4가 현행 PDF generator 최적화로 이어질 수 있다.
- probe source와 Info.plist 상태가 결정 경로와 일치한다.

### 커밋 메시지

```text
Task #88 Stage 3: PDF preview 성능 개선 경로 확정
```

## Stage 4. 선택 경로 구현

### 목표

Stage 3에서 확정한 경로를 구현한다. `PDFView` lazy가 가능하면 PDF UI 유지 view-based path를 제품화하고, 불가능하면 현행 data-based PDF 생성 성능을 최적화한다.

### 작업

- `PDFView` lazy 가능 경로:
  - view-based principal class와 PDF UI를 제품 path로 정리한다.
  - page request/render/cancellation 로그를 제품 diagnostics로 최소화한다.
  - stale result discard와 fallback to data-based provider 여부를 확정한다.
- 현행 PDF 생성 최적화 경로:
  - `HwpPreviewPDFRenderer`에서 전체 PDF UI는 유지한다.
  - #256 `skiaOptIn` 적용 여부는 기본 off 원칙을 유지하되, Quick Look 전용 opt-in이 필요한지 별도 gate로 검토한다.
  - page render loop의 불필요한 document open, image encode, memory retention, PDF context 처리 비용을 줄인다.
  - first preview latency와 total PDF generation time을 로그로 비교할 수 있게 한다.
  - cancellation은 data reply 구조에서 제한적이므로 request-level stale discard와 빠른 실패/복구 중심으로 정리한다.
- Stage 4 보고서를 작성한다.

### 산출물

- `Sources/QLExtension/HwpPreviewPDFViewController.swift` 또는 `Sources/QLExtension/HwpPreviewProvider.swift`
- `Sources/Shared/HwpPreviewPDFRenderer.swift`
- 필요 시 `Sources/Shared/HwpPageImageRenderer.swift`
- `mydocs/working/task_m020_88_stage4.md`

### 검증

```bash
./scripts/check-no-appkit.sh
xcodebuild -project Alhangeul.xcodeproj \
  -scheme QLExtension \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask88 \
  CODE_SIGNING_ALLOWED=NO \
  build
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask88 \
  CODE_SIGNING_ALLOWED=NO \
  build
rg -n "Task|cancel|generation|stale|visible|cache|render" Sources/QLExtension mydocs/working/task_m020_88_stage4.md
./scripts/validate-stage3-render.sh output/task88-stage4-render samples/basic/KTX.hwp samples/hwp-multi-001.hwp
git diff --check
```

### 완료 기준

- 현재 Quick Look PDF preview와 같은 사용자 경험을 유지하거나, 그와 거의 같은 `PDFView` UI가 구현되어 있다.
- 선택 경로의 성능 개선 근거가 Stage 4 보고서에 기록되어 있다.
- `PDFView` 경로인 경우 lazy page 요청과 stale result 방어가 동작한다.
- 현행 PDF 생성 최적화 경로인 경우 기존 PDF UI가 유지되고 생성 시간/메모리 개선 근거가 있다.

### 커밋 메시지

```text
Task #88 Stage 4: PDF preview 성능 개선 구현
```

## Stage 5. Quick Look/Thumbnail runtime smoke와 성능 관측

### 목표

Release package 기준 Quick Look runtime에서 선택 경로가 현재 PDF preview 사용자 경험을 유지하는지 확인하고, Thumbnail extension 첫 페이지 동작이 유지되는지 검증한다.

### 작업

- `build_run_guide.md`의 Finder 통합 확인 원칙에 따라 Release package 또는 smoke script 산출물로 검증한다.
- 다중 페이지 HWP/HWPX 샘플에서 최초 preview 표시, 오른쪽 thumbnail rail, scroll, zoom 또는 fit 동작을 관측한다.
- first preview latency와 total PDF generation 또는 lazy page render sequence를 로그 또는 수동 측정으로 기록한다.
- Thumbnail smoke를 실행해 기존 첫 페이지 thumbnail 동작이 깨지지 않았는지 확인한다.
- smoke 후 개발 산출물 Quick Look/Thumbnail 등록 잔존 여부를 확인한다.
- Stage 5 보고서를 작성한다.

### 산출물

- `mydocs/working/task_m020_88_stage5.md`
- 필요 시 ignored `output/task88-*` 또는 `/private/tmp/rhwp-task88-*` 측정 산출물

### 검증

```bash
ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1 scripts/package-release.sh 0.2.0
scripts/smoke-finder-integration.sh --skip-package --app build.noindex/release/Alhangeul.app
qlmanage -p samples/hwp-multi-001.hwp
qlmanage -t -s 512 -o /private/tmp/rhwp-task88-thumb samples/hwp-multi-001.hwp
scripts/check-extension-registration-hygiene.sh --check-only
git diff --check -- mydocs/working/task_m020_88_stage5.md
```

실제 `qlmanage -p`는 사람이 창 표시와 scroll을 확인해야 하므로, 실행 시각, 샘플, 관측 결과, 종료 후 hygiene 결과를 Stage 5 보고서에 남긴다.

### 완료 기준

- 다중 페이지 HWP/HWPX에서 현재와 같은 PDF preview 사용자 경험이 유지된다.
- 선택 경로에 맞는 성능 개선 근거가 있다.
- 빠른 selection 전환에서 이전 결과가 새 preview에 섞이지 않는다는 관측 또는 로그가 있다.
- Thumbnail smoke가 통과한다.

### 커밋 메시지

```text
Task #88 Stage 5: PDF preview 성능 smoke 검증
```

## Stage 6. 최종 정리와 PR 준비

### 목표

전체 수용 기준을 다시 확인하고, 최종 결과보고서와 오늘할일 완료 처리를 수행한 뒤 PR 게시 준비 상태로 만든다.

### 작업

- Stage 1-5 산출물과 검증 결과를 최종 보고서에 정리한다.
- view-based `PDFView` 제품화 또는 data-based PDF 유지 중 최종 선택과 이유를 명확히 기록한다.
- data-based legacy code가 남아 있다면 유지 이유 또는 제거 이유를 명확히 기록한다.
- #256 Skia optional backend와의 관계, 후속 Skia default 전환 여부가 이번 작업 범위 밖임을 정리한다.
- 오늘할일 상태를 완료로 갱신한다.
- 최종 build/smoke 가능 범위를 다시 실행하고 작업트리를 clean 상태로 만든다.

### 산출물

- `mydocs/report/task_m020_88_report.md`
- `mydocs/orders/20260520.md`
- 필요 시 source cleanup

### 검증

```bash
./scripts/check-no-appkit.sh
xcodebuild -project Alhangeul.xcodeproj \
  -scheme QLExtension \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask88 \
  CODE_SIGNING_ALLOWED=NO \
  build
xcodebuild -project Alhangeul.xcodeproj \
  -scheme ThumbnailExtension \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask88 \
  CODE_SIGNING_ALLOWED=NO \
  build
scripts/check-extension-registration-hygiene.sh --check-only
git diff --check
git status --short --branch
```

### 완료 기준

- 최종 보고서에 구현 범위, 검증 결과, 잔여 리스크, 후속 이슈 후보가 정리되어 있다.
- 오늘할일 완료 처리와 최종 검증이 끝났다.
- PR 게시 전 미커밋 파일이 없다.

### 커밋 메시지

```text
Task #88 Stage 6 + 최종 보고서: PDF preview 성능 개선 정리
```

## 승인 요청 사항

1. 현재 PDF preview UI 유지를 우선하는 보정 구현계획 승인
2. Stage 2 `PDFView + PDFThumbnailView view-based lazy 가능성 검증` 진행 승인
3. `PDFView` lazy가 불가능하면 `NSScrollView` 직접 page stack으로 전환하지 않고 현행 data-based PDF preview 생성 최적화로 진행하는 fallback 방향 승인
