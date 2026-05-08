# Task M016 #149 구현계획서

수행계획서: `mydocs/plans/task_m016_149.md`

각 단계 완료 후 `task-stage-report` 절차로 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #149 손상·대용량 HWP/HWPX 파일 opening fallback 보강
- 마일스톤: M016 (`v0.1 출시 전 보강`)
- 브랜치: `local/task149`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac`
- 기준 브랜치: `devel-webview`
- 주 대상: HostApp 문서 열기, Quick Look preview, Finder thumbnail의 negative input fallback
- 기준 파일 크기 제한: `hwpQuickLookMaxFileSize = 50 * 1024 * 1024`
- 목표: 손상·빈 파일·미지원 입력·50 MB 초과 파일에서 앱/extension이 crash, hang, raw error 대신 명확한 fallback을 반환하고, 원본 파일을 수정하지 않는 smoke 기준을 남긴다.

## 구현 원칙

- #149는 사용자 문서 자체의 손상·대용량·미지원 입력 fallback을 다룬다.
- #150에서 구현된 WKWebView asset/document delivery failure fallback은 유지하고, asset 누락이나 scheme 실패를 이번 범위에 섞지 않는다.
- 50 MB 기준값은 변경하지 않는다. Quick Look/Thumbnail preview fallback 기준으로 유지하고, HostApp 적용 여부는 Stage 2에서 확정한다.
- 기본 방향은 HostApp viewer에는 50 MB hard block을 새로 추가하지 않고, extension preview 제한과 사용자 메시지 정합성을 먼저 맞춘다. Stage 1에서 실제 WKWebView 대용량 위험이 확인되면 Stage 2에서 제한 범위를 재승인 대상으로 분리한다.
- Quick Look/Thumbnail은 extension 환경이므로 가능한 한 Finder가 표시 가능한 reply를 반환한다. 실패를 그대로 throw하는 경로는 최소화한다.
- `Sources/RhwpCoreBridge`에는 AppKit/UIKit/WebKit 의존을 추가하지 않는다.
- shared helper 변경은 `Sources/Shared`에 두고, target별 UI/응답은 HostApp/QLExtension/ThumbnailExtension에서 처리한다.
- 사용자 화면 메시지는 짧고 행동 가능하게 유지한다. 개발자 진단은 stage report와 필요 시 internal error mapping에 남긴다.
- negative smoke는 `build.noindex/` 또는 `/private/tmp` 아래 synthetic 파일만 사용하고, 사용자 원본 파일을 수정하지 않는다.

## Stage 1. 현행 opening/fallback 경로 inventory

### 목표

- 코드 변경 없이 HostApp, Quick Look, Thumbnail의 문서 열기와 failure propagation을 정리한다.
- Stage 2에서 확정할 error mapping, helper 위치, 구현 범위를 구체화한다.

### 작업

- `DocumentViewerStore.loadDocument(from:)`와 `loadDroppedDocument(data:filename:)`의 파일 읽기, 빈 데이터, 상태 초기화, recent document 기록 순서를 정리한다.
- `RhwpStudioWebView`와 `RhwpStudioHostBridgeScript`가 upstream `rhwp-studio`의 document load 실패를 `error`, `runtime-error`, status text 중 어디로 전달하는지 확인한다.
- bundled `rhwp-studio`의 `loadFromUrlParam()` 실패 메시지와 `so(error)` 경로를 조사해 Swift bridge가 parse failure를 포착할 수 있는지 확인한다.
- `HwpPreviewPDFRenderer.inspect(fileURL:)`, `HwpPreviewProvider`, `HwpPageImageRenderer.renderFirstPage(fileURL:)`의 `fileTooLarge`, `RhwpError.parseFailure`, `HwpRenderError` 전파 경로를 정리한다.
- `HwpThumbnailProvider`와 `HwpThumbnailRenderCache`가 cache miss, parse/render 실패, 50 MB 초과를 어떻게 handler에 전달하는지 정리한다.
- README와 build/run guide의 50 MB preview fallback 문구와 실제 코드 기준을 대조한다.
- Stage 1 보고서에 current failure matrix와 Stage 2 설계 입력을 남긴다.

### 예상 변경 파일

- `mydocs/working/task_m016_149_stage1.md`

### 검증

```bash
git status --short --branch
rg -n "errorMessage|webViewErrorMessage|webViewFailure|loadDocument|loadDroppedDocument|runtime-error|type: \\\"error\\\"|loadFromUrlParam|파일 로드 실패" \
  Sources/HostApp/Stores/DocumentViewerStore.swift \
  Sources/HostApp/Views/DocumentViewerView.swift \
  Sources/HostApp/Views/RhwpStudioWebView.swift \
  Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift \
  Sources/HostApp/Resources/rhwp-studio/assets/index-*.js
rg -n "hwpQuickLookMaxFileSize|fileTooLarge|RhwpError|HwpRenderError|renderFirstPage|providePreview|provideThumbnail|renderedPage" \
  Sources/Shared Sources/QLExtension Sources/ThumbnailExtension Sources/RhwpCoreBridge
rg -n "50 MB|corrupt file fallback|fallback|preview" README.md mydocs/manual/build_run_guide.md mydocs/manual/release_distribution_guide.md
git diff --check
```

### 완료 기준

- HostApp, Quick Look, Thumbnail의 negative input 결과가 표로 정리된다.
- Stage 2에서 결정할 범위가 "HostApp 조기 validation", "WKWebView parse failure bridge", "Quick Look fallback reply", "Thumbnail fallback tile"로 분리된다.

### 커밋 메시지

```text
Task #149 Stage 1: opening fallback 경로 inventory 정리
```

## Stage 2. fallback taxonomy와 구현 기준 확정

### 목표

- 입력 실패를 사용자 fallback 문구와 코드 위치로 mapping한다.
- HostApp에 50 MB hard block을 둘지 여부와 extension fallback 범위를 확정한다.

### 작업

- 입력 실패 taxonomy를 확정한다.
  - 빈 문서
  - 파일 읽기 실패 또는 security-scoped URL 접근 실패
  - 50 MB 초과 preview 제한
  - HWP/HWPX signature mismatch
  - `RhwpError.parseFailure`
  - `HwpRenderError.emptyDocument`
  - `HwpRenderError.renderTreeUnavailable`
  - `HwpRenderError.invalidPageSize`
  - bitmap/PDF/PNG encoding failure
- 사용자 문구를 정한다.
  - HostApp opening error
  - HostApp WKWebView document parse failure fallback 또는 banner
  - Quick Look plain text fallback
  - Thumbnail fallback tile
- shared helper 후보를 정한다.
  - `HwpRenderError`의 사용자 fallback classification helper
  - 파일 크기 표시 helper
  - Quick Look plain text message helper
  - Thumbnail fallback tile 재사용 범위
- HostApp validation 방식을 확정한다.
  - 파일 bytes 읽기 후 empty check는 유지 또는 메시지 개선
  - HWP/HWPX signature preflight를 Swift 쪽에 둘지, WKWebView에 맡길지 결정
  - 50 MB 초과는 우선 extension preview 제한으로 유지하고 HostApp hard block은 도입하지 않는 방향을 Stage 2 보고서에 명시한다. 제한 도입이 필요하다고 판단되면 작업지시자 재승인 항목으로 분리한다.
- WKWebView parse failure bridge가 필요하면 message type과 failure category를 정한다. 단, upstream asset 직접 수정은 최소화하고 host script injection으로 포착 가능한 범위만 구현한다.
- Stage 2 보고서에 Stage 3/4 실제 코드 변경안을 남긴다.

### 예상 변경 파일

- `mydocs/working/task_m016_149_stage2.md`

### 검증

```bash
git status --short --branch
rg -n "빈 문서|파일 읽기 실패|50 MB|signature|parseFailure|renderTreeUnavailable|invalidPageSize|plain text|fallback tile|HostApp hard block" \
  mydocs/working/task_m016_149_stage2.md
git diff --check
```

### 완료 기준

- error taxonomy와 사용자 메시지 mapping이 확정된다.
- HostApp, Quick Look, Thumbnail 각각의 구현 파일과 제외 범위가 확정된다.
- 50 MB 기준의 적용 범위가 코드 변경 전 문서로 명확해진다.

### 커밋 메시지

```text
Task #149 Stage 2: opening fallback taxonomy 설계
```

## Stage 3. HostApp opening fallback 보강

### 목표

- HostApp에서 파일 읽기/빈 파일/미지원 signature/문서 parse failure가 빈 화면이나 generic error로 끝나지 않게 한다.
- #150의 WebView asset failure fallback과 사용자 문서 failure fallback을 구분한다.

### 작업

- `DocumentViewerStore`에 HostApp 문서 입력 failure classification을 추가한다.
  - 빈 파일 메시지 개선
  - 파일 읽기 실패 메시지 개선
  - 필요 시 HWP/HWPX signature preflight
  - filename, byte count 등 내부 진단은 사용자 메시지에 과도하게 노출하지 않음
- `loadDocument(from:)`, `loadDroppedDocument(data:filename:)`, `openRecentDocument(_:)`의 실패 메시지를 같은 taxonomy로 정리한다.
- WKWebView `rhwp-studio`의 "파일 로드 실패"가 Swift로 전달되지 않는다면 `RhwpStudioHostBridgeScript`에서 status/error path를 포착하는 최소 bridge를 구현한다.
- parse/signature failure가 HostApp fatal fallback으로 가야 한다면 `RhwpStudioWebViewFailure`에 사용자 문서 failure category를 추가할지, `DocumentViewerStore.errorMessage`를 사용할지 Stage 2 결정에 맞춰 구현한다.
- 기존 저장/공유/인쇄/PDF command error banner와 충돌하지 않게 표시 조건을 점검한다.
- 원본 파일을 읽기 외 용도로 열지 않는지 확인한다.
- Stage 3 보고서에 변경 파일, 문구, fallback 화면 또는 banner 동작을 기록한다.

### 예상 변경 파일

- `Sources/HostApp/Stores/DocumentViewerStore.swift`
- `Sources/HostApp/Views/DocumentViewerView.swift` (필요 시)
- `Sources/HostApp/Views/RhwpStudioWebView.swift` (필요 시)
- `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift` (필요 시)
- `Sources/HostApp/Services/RhwpStudioResourceLocator.swift` (failure category 확장이 필요할 때만)
- `mydocs/working/task_m016_149_stage3.md`

### 검증

```bash
git status --short --branch
./scripts/check-no-appkit.sh
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
git diff --check
```

negative smoke 후보:

```bash
mkdir -p build.noindex/task149-negative
printf '' > build.noindex/task149-negative/empty.hwp
printf 'not hwp' > build.noindex/task149-negative/corrupt.hwp
/usr/bin/open -n -a "$PWD/build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app" "$PWD/build.noindex/task149-negative/empty.hwp"
/usr/bin/open -a "$PWD/build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app" "$PWD/build.noindex/task149-negative/corrupt.hwp"
pgrep -x Alhangeul
```

### 완료 기준

- HostApp에서 empty/corrupt synthetic 파일을 열어도 앱 프로세스와 창이 유지된다.
- 사용자 메시지가 파일 읽기 실패, 빈 파일, 손상/미지원 가능성을 구분한다.
- #150의 WebView asset/document delivery failure 메시지와 사용자 문서 failure 메시지가 섞이지 않는다.

### 커밋 메시지

```text
Task #149 Stage 3: HostApp opening fallback 보강
```

## Stage 4. Quick Look/Thumbnail negative fallback 보강

### 목표

- Quick Look preview와 Finder thumbnail이 손상/미지원 문서와 render failure에서 Finder가 표시 가능한 fallback을 반환한다.
- 기존 50 MB fallback 정책은 유지하되 메시지와 구현 경로를 정리한다.

### 작업

- `HwpPreviewProvider`에서 `HwpRenderError.fileTooLarge` 외의 사용자 문서 failure를 plain text fallback으로 mapping한다.
- `HwpPreviewPDFRenderer.inspect` 단계와 PNG/PDF data creation block 단계의 실패가 모두 fallback으로 이어질 수 있는지 확인하고, 필요한 경우 data creation block 내부 error mapping을 보강한다.
- `HwpPageImageRenderer` 또는 QLExtension 쪽에 render failure classification helper를 추가한다. shared helper를 둘 경우 AppKit/UIKit 의존 없이 구현한다.
- `HwpThumbnailProvider`에서 `HwpRenderError.fileTooLarge` 외 parse/render failure도 fallback tile을 반환하도록 mapping한다.
- `HwpThumbnailRenderCache`의 in-flight failure fan-out이 fallback 반환을 방해하지 않는지 확인한다. cache에는 실패 결과를 저장하지 않는다.
- thumbnail fallback tile은 기존 `drawFallback`을 재사용하고, 사용자-visible text를 그리지 않는 현재 디자인을 유지한다.
- Stage 4 보고서에 Quick Look plain text fallback 문구와 Thumbnail fallback 기준을 기록한다.

### 예상 변경 파일

- `Sources/QLExtension/HwpPreviewProvider.swift`
- `Sources/ThumbnailExtension/HwpThumbnailProvider.swift`
- `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift` (필요 시)
- `Sources/Shared/HwpPageImageRenderer.swift` (필요 시 helper 추가)
- `Sources/Shared/HwpPreviewPDFRenderer.swift` (필요 시)
- `Sources/RhwpCoreBridge/RhwpDocument.swift` (error taxonomy 보강이 필요할 때만, AppKit/UIKit 의존 금지)
- `mydocs/working/task_m016_149_stage4.md`

### 검증

```bash
git status --short --branch
./scripts/check-no-appkit.sh
xcodebuild -project Alhangeul.xcodeproj \
  -scheme QLExtension \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
xcodebuild -project Alhangeul.xcodeproj \
  -scheme ThumbnailExtension \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
git diff --check
```

negative smoke 후보:

```bash
mkdir -p build.noindex/task149-negative /tmp/alhangeul-ql
printf '' > build.noindex/task149-negative/empty.hwp
printf 'not hwp' > build.noindex/task149-negative/corrupt.hwp
mkfile 51m build.noindex/task149-negative/large.hwp
qlmanage -p build.noindex/task149-negative/corrupt.hwp
qlmanage -t -x -s 512 -o /tmp/alhangeul-ql build.noindex/task149-negative/corrupt.hwp
qlmanage -t -x -s 512 -o /tmp/alhangeul-ql build.noindex/task149-negative/large.hwp
```

### 완료 기준

- Quick Look preview가 50 MB 초과, 손상/미지원, 빈 파일에서 raw extension error 대신 fallback reply를 반환한다.
- Finder thumbnail이 50 MB 초과와 parse/render failure에서 fallback tile을 반환한다.
- render 실패는 cache 성공 항목으로 저장되지 않는다.

### 커밋 메시지

```text
Task #149 Stage 4: Quick Look Thumbnail fallback 보강
```

## Stage 5. synthetic negative smoke와 release gate 정리

### 목표

- HostApp, Quick Look, Thumbnail의 negative smoke 결과를 남기고 v0.1 release gate 문서와 연결한다.
- #151 설치본 smoke와 #146 known limitations에 넘길 입력을 분리한다.

### 작업

- Debug build 기준 HostApp empty/corrupt 파일 open smoke를 수행한다.
- Quick Look/Thumbnail synthetic negative smoke를 수행한다.
  - empty
  - corrupt signature
  - 51 MB large file
  - 정상 sample control case
- `mydocs/manual/build_run_guide.md`에 손상/대용량 opening fallback smoke 절차가 없으면 최소 섹션을 추가한다.
- README release checklist의 `corrupt file fallback` 또는 50 MB fallback 문구가 실제 기준과 어긋나면 필요한 범위만 갱신한다.
- #151 설치본 smoke gate로 넘길 항목과 #146 렌더 경로 한계 문서화로 넘길 known limitation 후보를 Stage 5 보고서에 정리한다.
- 최종 보고서 작성 전 남은 리스크를 분리한다.

### 예상 변경 파일

- `mydocs/manual/build_run_guide.md` (필요 시)
- `README.md` (필요 시)
- `mydocs/working/task_m016_149_stage5.md`

### 검증

```bash
git status --short --branch
./scripts/check-no-appkit.sh
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
mkdir -p build.noindex/task149-negative /tmp/alhangeul-ql
printf '' > build.noindex/task149-negative/empty.hwp
printf 'not hwp' > build.noindex/task149-negative/corrupt.hwp
mkfile 51m build.noindex/task149-negative/large.hwp
qlmanage -t -x -s 512 -o /tmp/alhangeul-ql samples/basic/KTX.hwp
qlmanage -t -x -s 512 -o /tmp/alhangeul-ql build.noindex/task149-negative/corrupt.hwp
qlmanage -t -x -s 512 -o /tmp/alhangeul-ql build.noindex/task149-negative/large.hwp
rg -n "50 MB|손상|대용량|fallback|corrupt file fallback|Quick Look|Thumbnail" README.md mydocs/manual/build_run_guide.md
git diff --check
```

수동 확인:

- HostApp에서 `empty.hwp`와 `corrupt.hwp`를 열어도 프로세스와 창이 유지된다.
- Quick Look preview는 실패 이유를 설명하는 fallback을 표시한다.
- Finder thumbnail은 fallback tile을 생성한다.
- 정상 sample thumbnail smoke가 계속 성공한다.

### 완료 기준

- synthetic negative smoke 결과가 Stage 5 보고서에 기록된다.
- build/run guide 또는 README의 fallback 기준이 실제 동작과 일치한다.
- #151과 #146에 넘길 후속 입력이 최종 보고 전 정리된다.

### 커밋 메시지

```text
Task #149 Stage 5: negative opening fallback smoke 정리
```

## 최종 보고 준비

모든 Stage가 승인되면 `task-final-report` 절차로 최종 결과보고서, 오늘할일 완료 처리, 최종 커밋, `publish/task149` push, PR 생성을 진행한다.

최종 보고서에는 다음 항목을 포함한다.

- HostApp, Quick Look, Thumbnail별 fallback 결과
- 50 MB 기준 적용 범위
- 손상/미지원 synthetic input smoke 결과
- 실행한 build/test 명령과 실패/미수행 사유
- #151 설치본 smoke gate로 넘길 항목
- #146 known limitations 문서화로 넘길 항목

## 구현계획 승인 요청 사항

1. 위 5단계 구현계획 승인
2. HostApp에는 우선 50 MB hard block을 추가하지 않고, 기존 Quick Look/Thumbnail preview fallback 기준을 유지하는 방향 승인
3. Quick Look/Thumbnail은 parse/render failure에서 가능한 한 fallback reply/tile을 반환하고 raw error 전파를 줄이는 방향 승인
4. 다음 단계: 승인 후 Stage 1 inventory 진행
