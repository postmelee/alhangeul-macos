# Task M020 #88 구현 계획서

수행계획서: `mydocs/plans/task_m020_88.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #88 View-based Quick Look preview visible-page lazy rendering 전환
- 마일스톤: M020 (`v0.2.x Skia Quick Look/Thumbnail Backend`)
- 브랜치: `local/task88`
- 기준 브랜치: `devel`
- 목표: Quick Look preview를 data-based 완성 PDF/PNG reply 중심 구조에서 view-based `NSViewController` preview로 전환하고, 다중 페이지 HWP/HWPX에서 첫 페이지 우선 표시와 visible page 중심 background render/cache/cancellation을 구현한다.

## 구현 원칙

- `Sources/RhwpCoreBridge`에는 AppKit/UIKit/QuickLookUI 의존을 추가하지 않는다.
- Quick Look UI와 lifecycle 코드는 `Sources/QLExtension`이 소유한다.
- 문서 open, page size 조회, page image rendering은 기존 `RhwpDocument`, `HwpPageImageRenderer` contract를 재사용한다.
- #256의 `skiaOptIn`은 이번 작업에서 기본으로 켜지 않는다. 별도 승인 전까지 page render policy는 기본 `coreGraphicsOnly`로 유지한다.
- View-based preview 전환은 Thumbnail extension 동작을 변경하지 않는다.
- `preparePreviewOfFile(at:completionHandler:)`는 main thread에서 호출되므로, 긴 parsing/render 작업은 background task로 넘기고 completion handler는 첫 표시 준비 단위에서 가능한 빨리 호출하는 방향으로 설계한다.
- request generation token과 cancellable task set을 둬서 빠른 Finder selection 전환 또는 view controller 해제 후 stale render 결과가 UI에 반영되지 않게 한다.
- fallback은 기존 Quick Look text fallback과 같은 사용자 메시지 정책을 유지하되, view-based UI 안에서 표시할 수 있는 오류 view로 연결한다.
- Stage별 산출물에는 실행 명령, 샘플, 관측 로그 위치, 남은 리스크를 기록한다.

## Stage 1. View-based Quick Look API와 현행 구조 inventory

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

## Stage 2. View-based preview skeleton과 data-based 설정 전환

### 목표

Quick Look principal class를 view-based `NSViewController`로 전환하고, 오류 view와 첫 표시용 skeleton이 compile/link되는 상태를 만든다.

### 작업

- 신규 `HwpPreviewViewController`를 `NSViewController, QLPreviewingController`로 추가한다.
- `preparePreviewOfFile(at:completionHandler:)`에서 request generation을 갱신하고 이전 작업을 취소하는 lifecycle skeleton을 만든다.
- `Sources/QLExtension/Info.plist`에서 data-based marker를 제거하거나 view-based 설정으로 바꾸고, `NSExtensionPrincipalClass`를 신규 view controller로 변경한다.
- `project.yml` 기준 source 포함과 QuickLookUI/AppKit dependency 필요 여부를 확인한다.
- 기존 `HwpPreviewProvider`의 data reply 구현은 Stage 2에서 바로 삭제하지 않고, Stage 3 fallback 참고 또는 비교용으로 남길지 Stage 1 결론에 따라 결정한다.
- 오류, loading, empty state를 view controller 안에서 표시하는 최소 view를 구성한다.
- Debug build에서 QLExtension과 HostApp compile/link를 확인한다.
- Stage 2 보고서를 작성한다.

### 산출물

- `Sources/QLExtension/HwpPreviewViewController.swift`
- `Sources/QLExtension/Info.plist`
- 필요 시 `Sources/QLExtension/HwpPreviewProvider.swift`
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
git diff --check
```

### 완료 기준

- QLExtension principal class가 view-based controller로 전환되어 compile된다.
- data-based `QLPreviewReply` 생성 경로가 기본 preview entrypoint에서 분리되어 있다.
- 아직 실제 page lazy rendering은 구현하지 않는다.

### 커밋 메시지

```text
Task #88 Stage 2: View-based Quick Look preview skeleton 추가
```

## Stage 3. 첫 페이지 우선 표시와 문서 metadata loader 구현

### 목표

HWP/HWPX 문서를 열어 page metadata를 준비하고, 첫 페이지 이미지를 우선 render해 view-based preview에 표시한다.

### 작업

- preview request별 `RhwpDocument` open과 page count/page size metadata load 흐름을 만든다.
- 파일 크기 제한, empty document, invalid page size, known fallback reason을 view-based 오류 view에 연결한다.
- 첫 페이지 render를 background task에서 수행하고, 완료 시 main thread에서 page view에 반영한다.
- 첫 페이지가 준비되는 즉시 preview UI가 보이도록 loading state와 completion handler 호출 타이밍을 조정한다.
- 단일 페이지 문서와 다중 페이지 문서 모두 같은 view-based UI에서 표시되도록 한다.
- stale generation이면 render 결과를 폐기한다.
- Stage 3 보고서를 작성한다.

### 산출물

- `Sources/QLExtension/HwpPreviewViewController.swift`
- 필요 시 신규 `Sources/QLExtension/HwpPreviewDocumentModel.swift`
- 필요 시 `Sources/Shared/HwpPreviewPDFRenderer.swift`
- `mydocs/working/task_m020_88_stage3.md`

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
./scripts/validate-stage3-render.sh output/task88-stage3-render samples/basic/KTX.hwp samples/hwp-multi-001.hwp
git diff --check
```

### 완료 기준

- 첫 페이지 render 결과가 view-based preview UI에 표시되는 source path가 구현되어 있다.
- known fallback error가 throw로 Quick Look을 깨는 대신 preview UI 안에서 설명된다.
- stale render result discard가 첫 페이지 경로에 적용되어 있다.

### 커밋 메시지

```text
Task #88 Stage 3: Quick Look 첫 페이지 우선 표시 구현
```

## Stage 4. Visible page background rendering, cache, cancellation 구현

### 목표

스크롤 viewport 변화에 따라 보이는 page와 인접 page를 background render하고, cache와 cancellation으로 빠른 selection 전환을 안전하게 처리한다.

### 작업

- Stage 1에서 선택한 container 기준으로 page placeholder layout을 구성한다.
- page index, file identity, generation을 포함하는 preview-local cache policy를 구현한다.
- visible rect 변화에서 필요한 page index set을 계산하고, 현재 page와 인접 page를 우선순위에 따라 render queue에 넣는다.
- 이미 rendering 중인 page 중 더 이상 필요 없는 작업은 cancel하거나, cancellation이 불가능한 sync render 구간은 result discard로 방어한다.
- cache size 또는 retained page image 수를 제한해 extension memory pressure를 줄인다.
- render start/end/stale discard/cache hit 로그를 `OSLog`로 남긴다.
- Stage 4 보고서를 작성한다.

### 산출물

- `Sources/QLExtension/HwpPreviewViewController.swift`
- 필요 시 신규 `Sources/QLExtension/HwpPreviewPageView.swift`
- 필요 시 신규 `Sources/QLExtension/HwpPreviewRenderScheduler.swift`
- 필요 시 신규 `Sources/QLExtension/HwpPreviewPageCache.swift`
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
git diff --check
```

### 완료 기준

- visible page와 인접 page 중심으로 background render가 예약된다.
- 빠른 request 교체 또는 view controller 해제 시 stale result가 UI에 반영되지 않는다.
- page cache가 무제한으로 커지지 않는다.

### 커밋 메시지

```text
Task #88 Stage 4: Visible page lazy render scheduler 구현
```

## Stage 5. Quick Look/Thumbnail runtime smoke와 성능 관측

### 목표

Release package 기준 Quick Look runtime에서 view-based preview가 동작하는지 확인하고, Thumbnail extension 첫 페이지 동작이 유지되는지 검증한다.

### 작업

- `build_run_guide.md`의 Finder 통합 확인 원칙에 따라 Release package 또는 smoke script 산출물로 검증한다.
- 다중 페이지 HWP/HWPX 샘플에서 최초 preview 표시, scroll 후 page render, 빠른 selection 전환을 관측한다.
- first preview latency와 page render start/end sequence를 로그 또는 수동 측정으로 기록한다.
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

- 다중 페이지 HWP/HWPX에서 첫 페이지가 view-based preview로 표시된다.
- scroll 시 후속 page render가 visible page 중심으로 발생한다는 관측 근거가 있다.
- 빠른 selection 전환에서 이전 render 결과가 새 preview에 섞이지 않는다는 관측 또는 로그가 있다.
- Thumbnail smoke가 통과한다.

### 커밋 메시지

```text
Task #88 Stage 5: View-based Quick Look smoke 검증
```

## Stage 6. 최종 정리와 PR 준비

### 목표

전체 수용 기준을 다시 확인하고, 최종 결과보고서와 오늘할일 완료 처리를 수행한 뒤 PR 게시 준비 상태로 만든다.

### 작업

- Stage 1-5 산출물과 검증 결과를 최종 보고서에 정리한다.
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
Task #88 Stage 6 + 최종 보고서: View-based Quick Look 전환 정리
```

## 승인 요청 사항

1. 위 6단계 구현계획 승인
2. Stage 1 `View-based Quick Look API와 현행 구조 inventory` 진행 승인
3. Stage 1에서는 제품 source 변경 없이 조사와 단계 보고서 작성까지만 수행하는 범위 승인
