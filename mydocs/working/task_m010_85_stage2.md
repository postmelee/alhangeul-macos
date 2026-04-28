# Task #85 Stage 2 완료 보고서

## 단계 목적

첫 페이지 전용 bitmap 렌더링 구현을 페이지 번호 기반 helper로 분리해 Stage 3의 전체 페이지 PDF preview 생성 기반을 마련한다. 기존 `renderFirstPage` API와 Thumbnail extension 호출 경로는 유지한다.

## 산출물

- `Sources/Shared/HwpPageImageRenderer.swift`
  - 216 lines
  - `HwpRenderError.pageOutOfRange` 추가
  - `renderFirstPage(fileURL:maximumPixelSize:embeddedThumbnailPolicy:)`가 기존 파일 읽기, embedded thumbnail, 50 MB fallback, empty document 처리를 유지한 뒤 `renderPage(document:pageIndex:maximumPixelSize:)`를 호출하도록 분리
  - `renderPage(document:pageIndex:maximumPixelSize:)` 추가
- `mydocs/working/task_m010_85_stage2.md`
  - Stage 2 변경과 검증 결과 기록

## 본문 변경 정도 / 본문 무손실 여부

코드 변경은 `Sources/Shared/HwpPageImageRenderer.swift`에 한정했다. 기존 `renderFirstPage` public API signature는 유지했고, Thumbnail extension의 호출부는 변경하지 않았다.

생성 산출물 `Frameworks/`, `RustBridge/target/`, `build.noindex/`, `output/`은 검증을 위해 생성됐지만 ignored 상태이며 커밋 대상에서 제외했다.

## 변경 내용

### page index bounds 처리

`HwpRenderError.pageOutOfRange`를 추가했다. 새 `renderPage` helper는 `pageIndex >= 0 && pageIndex < document.pageCount`를 먼저 확인한다.

### 첫 페이지 API 호환 유지

기존 API는 그대로 유지했다.

```swift
static func renderFirstPage(fileURL: URL) throws -> HwpRenderedPage

static func renderFirstPage(
    fileURL: URL,
    maximumPixelSize: CGSize?,
    embeddedThumbnailPolicy: HwpEmbeddedThumbnailPolicy = .never
) throws -> HwpRenderedPage
```

기존 첫 페이지 경로에서 유지한 동작:

- 파일 크기 resource value 조회
- 파일 data 읽기
- embedded thumbnail 정책 처리
- 50 MB 초과 시 `fileTooLarge`
- `RhwpDocument` 생성
- page count 0이면 `emptyDocument`

### 페이지 번호 기반 helper 추가

새 helper는 문서 핸들과 page index를 받아 해당 페이지를 기존 방식과 같은 bitmap으로 렌더링한다.

```swift
static func renderPage(
    document: RhwpDocument,
    pageIndex: Int,
    maximumPixelSize: CGSize? = nil
) throws -> HwpRenderedPage
```

이 helper는 다음 처리를 담당한다.

- page bounds 확인
- `document.renderPageTree(at: pageIndex)`
- `document.pageSize(at: pageIndex)`
- request pixel size에 맞춘 scale 계산
- bitmap `CGContext` 생성
- `CGTreeRenderer`를 통한 render tree drawing
- `HwpRenderedPage` 반환

## 검증 결과

### 변경 범위 확인

```bash
git diff -- Sources/Shared/HwpPageImageRenderer.swift
```

결과 요약:

- `HwpRenderError.pageOutOfRange` 추가
- `renderFirstPage` 내부의 page 0 렌더 본문을 `renderPage(document:pageIndex:maximumPixelSize:)`로 분리
- 호출부 파일 변경 없음

```bash
git diff --check
```

결과: 통과.

### AppKit/UIKit 경계 확인

```bash
./scripts/check-no-appkit.sh
```

결과:

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

### Rust bridge 산출물 준비

분리 worktree에는 generated framework가 없어 첫 render smoke와 Xcode build가 다음 이유로 실패했다.

```text
ERROR: missing /private/tmp/rhwp-mac-task85/Frameworks/universal/librhwp.a
Run: /private/tmp/rhwp-mac-task85/scripts/build-rust-macos.sh
```

```text
error: There is no XCFramework found at '/tmp/rhwp-mac-task85/Frameworks/Rhwp.xcframework'.
```

표준 준비 명령을 실행했다.

```bash
./scripts/build-rust-macos.sh
```

결과 요약:

```text
[1/4] Rust staticlib (arm64 + x86_64)...
[2/4] Universal binary...
Architectures in the fat file: /private/tmp/rhwp-mac-task85/Frameworks/universal/librhwp.a are: x86_64 arm64
[3/4] cbindgen header check...
FFI symbols:
rhwp_close
rhwp_extract_thumbnail
rhwp_free_bytes
rhwp_free_string
rhwp_image_data
rhwp_open
rhwp_page_count
rhwp_page_size
rhwp_render_page_svg
rhwp_render_page_tree
[4/4] XCFramework...
xcframework successfully written out to: /private/tmp/rhwp-mac-task85/Frameworks/Rhwp.xcframework
```

### render smoke

```bash
./scripts/validate-stage3-render.sh
```

결과:

```text
OK KTX.hwp: page=1 size=1123x794 textRuns=435 hangulRuns=76 hangulScalars=209 nonWhitePixels=449097 png=/private/tmp/rhwp-mac-task85/output/stage3-render/KTX-page1.png
OK request.hwp: page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=53220 png=/private/tmp/rhwp-mac-task85/output/stage3-render/request-page1.png
OK exam_kor.hwp: page=1 size=1123x1588 textRuns=108 hangulRuns=71 hangulScalars=1203 nonWhitePixels=159757 png=/private/tmp/rhwp-mac-task85/output/stage3-render/exam_kor-page1.png
```

### HostApp Debug build

Sandbox 안의 첫 build는 존재하는 XCFramework를 보지 못해 실패했다. 경로 확인 결과 `/private/tmp/rhwp-mac-task85/Frameworks/Rhwp.xcframework`와 `/tmp/rhwp-mac-task85/Frameworks/Rhwp.xcframework` 모두 정상 존재했다.

동일 명령을 권한 밖에서 재실행했다.

```bash
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과:

```text
** BUILD SUCCEEDED ** [10.784 sec]
```

## 잔여 위험

- `renderPage(document:pageIndex:maximumPixelSize:)`는 Stage 3에서 PDF 생성 루프가 사용할 새 내부 API다. Stage 3에서 PDF page에 bitmap을 삽입할 때 좌표계와 이미지 방향을 별도로 확인해야 한다.
- `pageOutOfRange`는 현재 새 helper에서만 발생한다. Stage 3에서 사용자 fallback으로 노출할지, 개발 오류로 throw할지 결정해야 한다.
- generated `Frameworks/`가 없는 새 worktree에서는 render smoke와 Xcode build 전에 `./scripts/build-rust-macos.sh`가 필요하다.

## 다음 단계 영향

- Stage 3은 새 `renderPage(document:pageIndex:maximumPixelSize:)`를 사용해 `0..<document.pageCount`를 순회하면 된다.
- `renderFirstPage` signature와 Thumbnail cache 호출부는 유지됐으므로 Thumbnail source 변경 없이 Stage 3으로 진행할 수 있다.

## 승인 요청

Stage 2 변경과 검증 결과를 승인 요청한다. 승인 후 Stage 3 `Quick Look 전체 페이지 PDF preview 구현`으로 진행한다.
