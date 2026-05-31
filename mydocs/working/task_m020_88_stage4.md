# Task M020 #88 Stage 4 완료보고서

## 단계 개요

- 단계: Stage 4. 선택 경로 구현
- 선택 경로: 현재 Quick Look PDF UI 유지 + PDF 생성 최적화
- 수행 범위: data-based `.pdf`/`.png` `QLPreviewReply` 구조를 유지하면서, preview 생성 과정의 중복 `RhwpDocument` open을 제거
- 결론: 현재 PDF UI를 유지하는 기본 provider 설정은 보존했고, Quick Look preview와 HostApp PDF export 양쪽에서 이미 연 `RhwpDocument`를 재사용하도록 변경했다.

## 변경 내용

### `HwpPreviewPDFRenderer.load(fileURL:)` 추가

`Sources/Shared/HwpPreviewPDFRenderer.swift`에 `HwpPreviewDocumentContext`와 `load(fileURL:)`를 추가했다.

이전 Quick Look preview 경로:

1. `inspect(fileURL:)`에서 file data를 읽고 `RhwpDocument`를 열어 page count와 첫 page size를 확인한다.
2. 단일 page PNG 또는 다중 page PDF 생성 시 같은 data로 `RhwpDocument`를 다시 연다.

변경 후 Quick Look preview 경로:

1. `load(fileURL:)`가 file data, filename, page count, 첫 page size, 열린 `RhwpDocument`를 한 번에 반환한다.
2. `HwpPreviewProvider`는 이 context를 PNG/PDF 생성에 그대로 넘긴다.
3. `render(context:)`는 context 안의 `RhwpDocument`를 재사용한다.

기존 API 호환을 위해 `inspect(fileURL:)`, `render(fileURL:)`, `render(previewInfo:)`는 유지했다. 기존 script나 다른 호출자는 계속 사용할 수 있다.

### Quick Look provider 최적화

`Sources/QLExtension/HwpPreviewProvider.swift`는 `HwpPreviewPDFRenderer.inspect(fileURL:)` 대신 `load(fileURL:)`를 호출한다.

- 단일 page: context의 `document`로 첫 page bitmap을 렌더링하고 PNG reply를 만든다.
- 다중 page: context를 `HwpPreviewPDFRenderer.render(context:)`에 넘겨 PDF reply를 만든다.
- fallback mapping과 `.plainText` reply 정책은 변경하지 않았다.
- `QLPreviewReply(dataOfContentType: .pdf)` 경로를 유지하므로 macOS Quick Look의 현재 PDF preview UI가 유지된다.

### HostApp PDF export 중복 open 제거

`Sources/HostApp/Services/RhwpStudioPDFExportController.swift`도 이미 연 `RhwpDocument`를 `HwpPreviewPDFRenderer.render(document:pageCount:contentSize:)`에 직접 넘기도록 변경했다.

이 변경은 Quick Look과 같은 renderer를 쓰는 HostApp PDF export에서도 중복 document open을 줄인다.

### 문서 정리

- `mydocs/tech/project_architecture.md`의 Quick Look preview 경로를 `inspect` 중심 설명에서 `load` 후 같은 document 재사용 설명으로 갱신했다.
- `mydocs/plans/task_m020_88.md`에 작업 중 사용자 지시로 현재 PDF UI 유지 + 생성 최적화 fallback을 적용했다는 보정 내용을 추가했다.

## 검증 결과

실행한 명령:

```bash
./scripts/check-no-appkit.sh
git diff --check
xcodebuild -project Alhangeul.xcodeproj \
  -scheme QLExtension \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask88 \
  build
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask88 \
  build
./scripts/validate-stage3-render.sh \
  output/task88-stage4-render \
  samples/basic/KTX.hwp \
  samples/hwp-multi-001.hwp
plutil -p build.noindex/DerivedDataTask88/Build/Products/Debug/Alhangeul.app/Contents/PlugIns/AlhangeulPreview.appex/Contents/Info.plist
rg -n "QLIsDataBasedPreview|NSExtensionPrincipalClass|PDFKit|HwpPreviewPDFViewController|HwpPDFViewLazyProbe|HwpPreviewPDFRenderer\\.load|render\\(context|render\\(document" \
  Sources project.yml Alhangeul.xcodeproj/project.pbxproj
```

결과:

- `./scripts/check-no-appkit.sh` 성공: shared Swift code의 AppKit/UIKit 의존 없음.
- `git diff --check` 성공.
- QLExtension Debug build 성공: `** BUILD SUCCEEDED ** [6.272 sec]`.
- HostApp Debug build 성공: `** BUILD SUCCEEDED ** [0.595 sec]`.
- native render smoke 성공:
  - `OK KTX.hwp: page=1 size=1123x794 ...`
  - `OK hwp-multi-001.hwp: page=1 size=794x1123 ...`
- build 산출물 `AlhangeulPreview.appex`의 Info.plist는 `QLIsDataBasedPreview=true`, `NSExtensionPrincipalClass=AlhangeulPreview.HwpPreviewProvider` 상태다.
- `rg` 확인 결과 QLExtension/project에서 Stage 2 probe source와 `PDFKit.framework` 의존성은 제거된 상태다. HostApp의 `RhwpStudioPrintController`는 기존 PDFKit print 경로라 이번 변경과 무관하다.

## 성능 개선 근거

이번 변경은 renderer 알고리즘을 바꾸지 않고 parsing/open 비용을 제거하는 보수적 최적화다.

- Quick Look 단일 page preview: `RhwpDocument` open 2회에서 1회로 감소.
- Quick Look 다중 page PDF preview: `RhwpDocument` open 2회에서 1회로 감소.
- HostApp PDF export: `RhwpDocument` open 2회에서 1회로 감소.

page bitmap rendering과 PDF page 작성은 기존과 같은 순서로 수행된다. 따라서 현재 PDF UI와 렌더링 결과의 구조적 호환성을 유지하면서 preview reply 생성 전 지연 중 parser 중복 비용만 줄인다.

## 잔여 리스크

- data-based PDF reply 구조 자체는 유지되므로 true visible-page lazy rendering은 제공하지 않는다.
- 다중 page 문서의 총 PDF 생성 시간은 여전히 전체 page bitmap render 비용에 좌우된다.
- 실제 Finder Quick Look 창에서 현재 PDF UI 유지와 체감 지연 개선은 Stage 5 Release package smoke에서 확인해야 한다.

## 다음 단계

Stage 5에서 Release package 기준 Quick Look preview/Thumbnail smoke와 extension registration hygiene를 확인한다.
