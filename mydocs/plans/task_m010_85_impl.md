# Task #85 구현 계획서

본 문서는 [`task_m010_85.md`](task_m010_85.md) 수행계획서를 단계별 실행 단위로 분해한 것이다. 각 단계 완료 후 [`task-stage-report`](../skills/task-stage-report/SKILL.md) skill로 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 환경

- **Worktree**: `/private/tmp/rhwp-mac-task85`
- **Branch**: `local/task85`
- **Issue**: #85
- **Milestone**: M010 (`v0.1`)
- **주 대상**: `Sources/QLExtension`, `Sources/Shared`
- **보존 대상**: `Sources/RhwpCoreBridge`의 AppKit/UIKit 비의존 경계, Thumbnail extension 첫 페이지 동작

## 구현 원칙

- HWP/HWPX 원본을 PDF로 직접 변환하지 않는다.
- Quick Look PDF는 사용자용 PDF export가 아니라 Finder preview 표시용 임시 컨테이너로 취급한다.
- 실제 렌더링 기준은 기존 rhwp render tree와 `CGTreeRenderer` 경로를 유지한다.
- 1차 구현은 페이지별 bitmap을 PDF 각 페이지에 삽입하는 보수적 방식을 사용한다.
- 기존 `HwpPageImageRenderer.renderFirstPage` API는 유지해 Thumbnail extension과 기존 첫 페이지 경로를 깨지 않는다.
- 파일 크기 50 MB 초과 fallback 정책은 유지한다.
- `Sources/RhwpCoreBridge`에는 AppKit/UIKit 직접 의존을 추가하지 않는다.
- `project.yml`이 Xcode project 원본이므로 `AlhangeulMac.xcodeproj`는 직접 수정하지 않는다.

## Stage 1. Quick Look PDF preview 설계 확정

### 목표

- macOS SDK의 `QLPreviewReply` PDF 지원 방식과 현재 Quick Look extension 구조를 확인한다.
- Stage 2와 Stage 3에서 적용할 구체 구현 방식을 확정한다.
- 페이지 수 제한을 둘지 여부를 실제 extension 안정성 관점에서 판단한다.

### 작업

- `QLPreviewReply` 헤더에서 PDF data reply와 `PDFDocument` reply 지원 범위를 확인한다.
- 현재 `HwpPreviewProvider`가 `MainActor`에서 단일 PNG data reply를 만드는 흐름을 재확인한다.
- `HwpPageImageRenderer`와 `HwpThumbnailRenderCache`의 의존 관계를 확인해 Thumbnail 회귀 위험을 정리한다.
- PDF 생성 후보를 비교한다.
  - 후보 A: `QLPreviewReply(dataOfContentType: .pdf, contentSize: ...)`
  - 후보 B: `QLPreviewReply(forPDFWithPageSize:documentCreationBlock:)`
  - 후보 C: 임시 PDF file URL reply
- 1차 구현 후보는 PDF data reply로 두되, SDK/빌드 제약이 확인되면 Stage 1 보고서에서 대체안을 제시한다.
- 모든 페이지 표시를 기본 목표로 유지한다. 다만 샘플 검증 전에는 임의 page cap을 코드에 넣지 않고, extension 안정성 문제가 확인될 때만 작업지시자에게 제한 정책을 재승인받는다.

### 완료 기준

- Quick Look reply 생성 방식이 하나로 확정된다.
- PDF가 HWP 구조 변환이 아니라 bitmap preview 컨테이너라는 경계가 단계 보고서에 정리된다.
- Stage 2와 Stage 3의 구체 코드 변경 방향이 확정된다.
- source 변경 없이 설계 확인과 단계 보고서만 남긴다.

### 검증

```bash
git status --short --branch
rg -n "QLPreviewReply|dataOfContentType|forPDF|PDFDocument" \
  /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/QuickLookUI.framework
sed -n '1,220p' Sources/QLExtension/HwpPreviewProvider.swift
sed -n '1,260p' Sources/Shared/HwpPageImageRenderer.swift
sed -n '1,220p' Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift
git diff --check
```

### 커밋 메시지

```text
Task #85 Stage 1: Quick Look PDF preview 설계 확정
```

## Stage 2. 페이지 번호 기반 렌더링 helper 분리

### 목표

- 첫 페이지 전용 bitmap 렌더링 구현을 페이지 번호 기반으로 일반화한다.
- 기존 public 호출자인 Quick Look 첫 페이지 경로와 Thumbnail extension cache 경로는 호환 API로 유지한다.

### 작업

- `HwpPageImageRenderer.renderFirstPage` 내부에서 사용하는 렌더링 본문을 `renderPage(document:pageIndex:maximumPixelSize:)` 계열 private helper로 분리한다.
- 파일 읽기, embedded thumbnail 정책, 50 MB fallback 순서를 기존 첫 페이지 동작과 동일하게 유지한다.
- page index bounds, page size, render tree nil 처리에 명확한 error case를 둔다.
- `renderFirstPage(fileURL:maximumPixelSize:embeddedThumbnailPolicy:)`는 기존 서명을 유지하고 내부에서 page index 0 helper를 호출하게 한다.
- 필요하면 `HwpRenderError`에 `pageOutOfRange` 또는 preview PDF 생성 실패 case를 추가하되, 오류 노출 방식은 기존 fallback 흐름과 맞춘다.
- Thumbnail extension이 `HwpPageImageRenderer.renderFirstPage`를 계속 호출하는지 확인한다.

### 예상 변경 파일

- `Sources/Shared/HwpPageImageRenderer.swift`
- `mydocs/working/task_m010_85_stage2.md`

### 완료 기준

- 기존 `renderFirstPage` public API가 유지된다.
- 첫 페이지 PNG render smoke가 기존 샘플에서 통과한다.
- Thumbnail extension source는 호출 변경 없이 컴파일 가능해야 한다.
- `Sources/RhwpCoreBridge`에는 변경이 없다.

### 검증

```bash
git status --short --branch
git diff -- Sources/Shared/HwpPageImageRenderer.swift
git diff --check
./scripts/check-no-appkit.sh
./scripts/validate-stage3-render.sh
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

### 커밋 메시지

```text
Task #85 Stage 2: 페이지 번호 기반 렌더링 helper 분리
```

## Stage 3. Quick Look 전체 페이지 PDF preview 구현

### 목표

- Quick Look preview provider가 HWP/HWPX 모든 페이지를 담은 PDF preview reply를 반환하도록 변경한다.
- PDF는 기존 native renderer가 만든 page bitmap을 각 PDF page에 삽입하는 방식으로 생성한다.

### 작업

- `Sources/Shared/HwpPreviewPDFRenderer.swift`를 추가하거나 `HwpPageImageRenderer` 안에 PDF 생성 helper를 둔다. Stage 1 결정에 따라 파일 위치를 확정한다.
- 파일을 한 번 읽고 `RhwpDocument`를 한 번 연 뒤 `0..<pageCount`를 순회한다.
- 각 페이지마다 Stage 2 helper로 bitmap을 만들고, PDF context에 해당 page size의 PDF page를 생성해 이미지를 그린다.
- PDF 생성 중에는 페이지별 bitmap을 배열로 누적하지 않고 루프 안에서 소비한다.
- `HwpPreviewProvider`는 기존 PNG reply 대신 `.pdf` data reply를 반환한다.
- `reply.title`은 기존처럼 원본 파일명을 유지한다.
- `HwpRenderError.fileTooLarge`는 기존 plain text fallback을 유지한다.
- empty document, invalid page size, render tree unavailable은 기존 오류 흐름과 맞추되 필요 시 명확한 fallback 문구를 검토한다.

### 예상 변경 파일

- `Sources/QLExtension/HwpPreviewProvider.swift`
- `Sources/Shared/HwpPageImageRenderer.swift`
- 필요 시 `Sources/Shared/HwpPreviewPDFRenderer.swift`
- `mydocs/working/task_m010_85_stage3.md`

### 완료 기준

- Quick Look provider가 PDF content type preview를 생성한다.
- 다중 페이지 샘플에서 page count만큼 PDF page가 생성된다.
- HWP/HWPX 원본 파일은 수정되지 않는다.
- Thumbnail extension의 첫 페이지 thumbnail 동작은 유지된다.

### 검증

```bash
git status --short --branch
git diff -- Sources/QLExtension Sources/Shared
git diff --check
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
./scripts/validate-stage3-render.sh
```

추가로 가능한 경우 PDF page count를 확인하는 임시 smoke를 수행한다. 별도 스크립트가 필요하면 Stage 3 안에서 최소 범위로 추가하고 단계 보고서에 이유를 기록한다.

### 커밋 메시지

```text
Task #85 Stage 3: Quick Look 전체 페이지 PDF preview 구현
```

## Stage 4. Quick Look/Thumbnail 통합 검증과 문서 정리

### 목표

- 구현 결과가 실제 Quick Look preview에서 다중 페이지로 표시되는지 확인한다.
- 기존 Thumbnail extension과 첫 페이지 render smoke에 회귀가 없는지 확인한다.
- PDF preview 방식의 의미와 제한을 문서와 최종 보고서에 정리한다.

### 작업

- 다중 페이지 샘플을 골라 Quick Look preview smoke를 수행한다.
- `qlmanage -p`로 preview 경로를 확인한다.
- 가능한 경우 `qlmanage -t`로 기존 thumbnail 생성 경로도 확인한다.
- Finder/Quick Look 등록 검증이 필요하면 `build_run_guide.md`의 Release package 기준 절차를 따른다.
- `mydocs/tech/project_architecture.md` 또는 `README.md`에서 Quick Look preview 경로 설명이 첫 페이지 PNG로 고정되어 있으면 현재 구현에 맞게 갱신한다.
- 최종 결과 보고서 `mydocs/report/task_m010_85_report.md`를 작성한다.
- 오늘할일 `#85` 행을 완료 상태로 갱신한다.

### 예상 변경 파일

- 필요 시 `README.md`
- 필요 시 `mydocs/tech/project_architecture.md`
- `mydocs/orders/20260429.md`
- `mydocs/report/task_m010_85_report.md`
- `mydocs/working/task_m010_85_stage4.md`

### 완료 기준

- HostApp Debug build가 성공한다.
- render smoke가 통과한다.
- Quick Look preview smoke에서 다중 페이지 preview가 확인된다.
- 기존 thumbnail smoke가 회귀 없이 동작하거나, 등록/환경 제약이 있으면 원인과 미검증 범위를 명확히 기록한다.
- 문서가 Quick Look preview를 더 이상 첫 페이지 PNG 전용으로 설명하지 않는다.

### 검증

```bash
git status --short --branch
git diff --check
./scripts/check-no-appkit.sh
./scripts/validate-stage3-render.sh
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
qlmanage -p samples/basic/KTX.hwp
qlmanage -p samples/hwp-multi-001.hwp
mkdir -p /tmp/alhangeul-ql-task85
qlmanage -t -x -s 512 -o /tmp/alhangeul-ql-task85 samples/basic/KTX.hwp
```

Release package 기준 extension 등록 검증이 필요한 경우:

```bash
./scripts/package-release.sh 0.1.0
pluginkit -mAvvv | grep com.postmelee.alhangeulmac
qlmanage -r
qlmanage -r cache
```

### 커밋 메시지

```text
Task #85 Stage 4 + 최종 보고서: Quick Look 전체 페이지 검증과 보고
```

## 승인 요청 사항

1. 본 구현계획서의 4단계 분해와 단계별 변경 범위
2. Stage 3의 1차 구현 방식을 “페이지별 bitmap을 PDF page에 삽입하는 Quick Look 표시용 PDF”로 고정하는 결정
3. 기본 목표는 모든 페이지 표시로 두고, page cap은 Stage 1 또는 Stage 3에서 실제 안정성 문제가 확인될 때만 재승인받는 결정
4. 본 구현계획서 승인 후 Stage 1 설계 확인부터 순차 진행
