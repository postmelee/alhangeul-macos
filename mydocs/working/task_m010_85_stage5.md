# Task #85 Stage 5 완료 보고서

## 단계 목적

Stage 4 완료 후 작업지시자가 제공한 Finder Quick Look 영상에서, 목록을 빠르게 전환하는 동안 preview가 즉시 갱신되지 않고 선택 전환을 멈춘 뒤 로딩이 시작되는 현상이 확인됐다. Stage 5는 전체 페이지 preview 기능을 유지하면서 Quick Look provider의 초기 응답 지연을 줄이는 보정 단계다.

## 산출물

- `Sources/QLExtension/HwpPreviewProvider.swift`
  - `providePreview`에서 `MainActor.run` 경계를 제거
  - 파일 metadata 검사 후 page count에 따라 PNG/PDF reply를 선택
  - 단일 페이지 문서는 `.png` data reply 사용
  - 다중 페이지 문서는 `.pdf` data reply를 반환하되 PDF data 생성은 data creation block으로 지연
- `Sources/Shared/HwpPreviewPDFRenderer.swift`
  - `HwpPreviewDocumentInfo`와 `inspect(fileURL:)` 추가
  - 전체 PDF 생성 전에 필요한 정보만 먼저 수집
  - `render(previewInfo:)` 경로 추가
- `Sources/README.md`
  - Shared helper 설명을 PNG/PDF preview 경로로 갱신
- `mydocs/tech/project_architecture.md`
  - Quick Look preview 경로를 단일 페이지 PNG와 다중 페이지 PDF 분기 구조로 갱신
- `mydocs/plans/task_m010_85.md`
  - Stage 5 추가 배경과 범위 반영
- `mydocs/plans/task_m010_85_impl.md`
  - Stage 5 구현 계획 추가
- `mydocs/orders/20260429.md`
  - #85 완료 기록을 Stage 5 기준으로 갱신
- `mydocs/report/task_m010_85_report.md`
  - 최종 보고서를 Stage 5 결과와 제한 사항까지 포함하도록 갱신
- `mydocs/working/task_m010_85_stage5.md`
  - 본 단계 완료 보고서
- GitHub Issue
  - [#87 PDFKit 기반 Quick Look lazy PDF preview 가능성 검증](https://github.com/postmelee/alhangeul-macos/issues/87)
  - [#88 View-based Quick Look preview visible-page lazy rendering 전환](https://github.com/postmelee/alhangeul-macos/issues/88)

## 변경 내용

### reply 생성 전 작업 최소화

Stage 3 구현은 `HwpPreviewProvider.createPreview`에서 `HwpPreviewPDFRenderer.render(fileURL:)`를 호출해 모든 페이지 bitmap 렌더링과 PDF data 생성을 끝낸 뒤 `QLPreviewReply`를 반환했다. 이 구조에서는 다중 페이지 문서일수록 Quick Look이 provider 응답을 받기 전까지 기다려야 한다.

Stage 5에서는 `HwpPreviewPDFRenderer.inspect(fileURL:)`가 다음 정보만 먼저 수집한다.

- 50 MB 초과 여부
- 원본 file data
- filename
- `RhwpDocument.pageCount`
- 첫 페이지 size

이후 `HwpPreviewProvider`는 page count에 따라 `QLPreviewReply`를 즉시 구성한다. 실제 PNG/PDF data 생성은 Quick Look이 호출하는 data creation block 안에서 수행된다.

### 단일 페이지 PNG 경로 복원

page count가 1인 문서는 `.pdf` container를 만들지 않고 `.png` reply를 반환한다. 이 경로는 기존 PNG 기반 preview와 비슷한 특성을 가진다.

다만 이 분기는 benchmark상 명확한 속도 우위가 확인된 최적화라고 보지는 않는다. `samples/basic/KTX.hwp` 기준으로 Stage 5 이전 1 page PDF data 생성은 0.066s였고, Stage 5 이후 PNG data block 생성은 0.126s였다. 이 변경의 의미는 단일 페이지 문서를 다중 페이지 PDF container 경로에서 제외하고, reply 반환 전 전체 PDF 생성을 피하는 데 있다.

### 다중 페이지 PDF 생성 시점 지연

page count가 2 이상인 문서는 기존 전체 페이지 PDF preview 산출을 유지한다. 다만 PDF data 생성은 `QLPreviewReply(dataOfContentType:contentSize:dataCreationBlock:)`의 block 안으로 옮겼다.

현재 data reply 구조는 한 번 반환한 preview content를 나중에 append하거나, 첫 페이지만 먼저 표시한 뒤 나머지 page를 점진적으로 추가하는 API를 제공하지 않는다. true lazy pagination이 필요하면 `QLPreviewingController`의 view 기반 preview 또는 `PDFDocument`/`PDFPage` 생성 block 기반 구조를 별도 spike로 검토해야 한다.

## 조사와 기준 수치

영상 확인 결과, Finder selection은 이동하고 있지만 preview 영역은 spinner 상태로 유지되다가 선택 전환을 멈춘 뒤 표시가 시작되는 패턴이었다. 코드상 원인은 `providePreview` 경로에서 전체 PDF 렌더링을 동기적으로 끝낸 뒤 reply를 반환하는 구조로 판단했다.

Stage 5 적용 전 임시 benchmark:

| 샘플 | page count | first PNG | full PDF |
|------|------------|-----------|----------|
| `samples/basic/KTX.hwp` | 1 | 0.092s | 0.066s |
| `samples/hwp-multi-001.hwp` | 10 | 0.043s | 0.371s |
| `samples/basic/exam_math.hwp` | 20 | 0.028s | 0.586s |
| `samples/basic/exam_kor.hwp` | 30 | 0.173s | 1.491s |
| `samples/basic/aift.hwp` | 77 | 0.056s | 2.018s |
| `samples/hwpx/hwpx-01.hwpx` | 9 | 0.038s | 0.334s |

Stage 5 적용 후 임시 benchmark:

| 샘플 | page count | reply 전 inspect | data block PNG/PDF |
|------|------------|------------------|--------------------|
| `samples/basic/KTX.hwp` | 1 | 0.004s | PNG 0.126s |
| `samples/hwp-multi-001.hwp` | 10 | 0.006s | PDF 0.443s |
| `samples/basic/exam_math.hwp` | 20 | 0.006s | PDF 0.723s |
| `samples/basic/exam_kor.hwp` | 30 | 0.166s | PDF 1.882s |
| `samples/basic/aift.hwp` | 77 | 0.077s | PDF 2.511s |
| `samples/hwpx/hwpx-01.hwpx` | 9 | 0.006s | PDF 0.409s |

Stage 5는 실제 PDF 생성 비용을 없애지는 않는다. 다만 Quick Look provider가 reply를 반환하기 전에 모든 페이지를 렌더링하던 구조를 제거했고, 단일 페이지 문서는 PNG 경로로 분기한다.

## 검증 결과

### 기본 검증

```bash
git diff --check
```

결과: 통과.

```bash
./scripts/check-no-appkit.sh
```

결과:

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

### HostApp Debug build

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
** BUILD SUCCEEDED ** [6.889 sec]
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

### PDF page count smoke

```bash
build.noindex/preview_pdf_check \
  samples/basic/KTX.hwp \
  samples/hwp-multi-001.hwp \
  samples/hwpx/hwpx-01.hwpx
```

결과:

```text
OK KTX.hwp: sourcePages=1 previewPages=1 pdfPages=1
OK hwp-multi-001.hwp: sourcePages=10 previewPages=10 pdfPages=10
OK hwpx-01.hwpx: sourcePages=9 previewPages=9 pdfPages=9
```

### Release package와 extension 등록

```bash
./scripts/package-release.sh 0.1.0
```

결과:

```text
** BUILD SUCCEEDED **
640b7fb4c5d1f0df5d7a69c05ed413aeba2b8e7784025d1482b5a33e98901f10  alhangeul-macos-0.1.0.zip
```

Release app을 `/Users/melee/Applications/AlhangeulMac.app`에 설치하고 LaunchServices/PlugInKit 등록을 갱신했다.

```bash
pluginkit -mAvvv | rg -n -C 8 'com\.postmelee\.alhangeulmac|AlhangeulMac(Preview|Thumbnail)'
```

결과 요약:

```text
com.postmelee.alhangeulmac.QLExtension(0.1.0)
Path = /Users/melee/Applications/AlhangeulMac.app/Contents/PlugIns/AlhangeulMacPreview.appex
SDK = com.apple.quicklook.preview

com.postmelee.alhangeulmac.ThumbnailExtension(0.1.0)
Path = /Users/melee/Applications/AlhangeulMac.app/Contents/PlugIns/AlhangeulMacThumbnail.appex
SDK = com.apple.quicklook.thumbnail
```

```bash
codesign --verify --deep --strict /Users/melee/Applications/AlhangeulMac.app
```

결과: 통과.

### Quick Look preview smoke

Quick Look cache 갱신:

```bash
qlmanage -r
qlmanage -r cache
```

결과: 통과.

단일 페이지 HWP preview:

```bash
qlmanage -p samples/basic/KTX.hwp
```

결과: preview 세션 유지 후 수동 종료. ImageKit에서 PNG 표시 관련 로그가 출력됐지만 crash는 없었다.

다중 페이지 HWP preview:

```bash
qlmanage -p samples/hwp-multi-001.hwp
```

결과: preview 세션 유지 후 수동 종료.

### Thumbnail smoke

```bash
qlmanage -t -x -s 512 -o /tmp/alhangeul-ql-task85-stage5-thumbnail \
  samples/basic/KTX.hwp \
  samples/hwp-multi-001.hwp \
  samples/hwpx/hwpx-01.hwpx
```

결과:

```text
* /private/tmp/rhwp-mac-task85/samples/hwp-multi-001.hwp produced one thumbnail
* /private/tmp/rhwp-mac-task85/samples/hwpx/hwpx-01.hwpx produced one thumbnail
* /private/tmp/rhwp-mac-task85/samples/basic/KTX.hwp produced one thumbnail
Done producing thumbnails
```

생성 PNG 확인:

```text
/tmp/alhangeul-ql-task85-stage5-thumbnail/KTX.hwp.png:           PNG image data, 512 x 363, 8-bit/color RGBA, non-interlaced
/tmp/alhangeul-ql-task85-stage5-thumbnail/hwp-multi-001.hwp.png: PNG image data, 363 x 512, 8-bit/color RGBA, non-interlaced
/tmp/alhangeul-ql-task85-stage5-thumbnail/hwpx-01.hwpx.png:      PNG image data, 363 x 512, 8-bit/color RGBA, non-interlaced
```

## 잔여 위험

- 다중 페이지 문서는 여전히 전체 페이지 PDF data를 만들어야 표시된다. Stage 5는 provider reply 생성 전 지연을 줄이는 보정이지, true lazy pagination 구현은 아니다.
- `inspect(fileURL:)`에서도 `RhwpDocument`를 한 번 열어 page count와 첫 페이지 크기를 확인한다. 일반 샘플에서는 수 ms 수준이었지만, `exam_kor.hwp`는 0.166s가 걸렸다.
- 단일 페이지 PNG preview smoke에서 ImageKit 로그가 출력됐다. 표시 crash는 없었지만 설치본 실사용 중 같은 로그가 반복되는지 관찰 대상이다.
- `qlmanage -p -o` 출력 파일 모드는 Stage 4에서 ExtensionFoundation 예외가 확인됐다. 사용자-facing 일반 preview와 thumbnail 경로는 통과했다.
- true lazy pagination은 [#87](https://github.com/postmelee/alhangeul-macos/issues/87), [#88](https://github.com/postmelee/alhangeul-macos/issues/88) 후속 이슈로 분리했다.

## 다음 단계 영향

Stage 5 성능 보정과 최종 보고서 갱신을 완료했다. 작업지시자 승인 후 `publish/task85` 원격 브랜치 push와 devel 대상 draft PR 생성 절차로 넘어갈 수 있다. 현재 `local/task85`는 `origin/devel`보다 behind 상태이므로 PR 게시 전 devel 최신 동기화와 충돌 확인이 필요하다.
