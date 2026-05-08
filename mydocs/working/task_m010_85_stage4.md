# Task #85 Stage 4 완료 보고서

## 단계 목적

Quick Look 전체 페이지 preview 구현 결과를 통합 검증하고, Thumbnail 회귀 여부와 문서 설명을 정리한다. 이번 단계의 핵심 확인 지점은 다중 페이지 PDF preview가 HWP/HWPX 원본 변환이 아니라 rhwp render tree 기반 bitmap을 담는 Quick Look 표시용 컨테이너라는 경계를 검증 결과와 문서에 남기는 것이다.

## 산출물

- `mydocs/tech/project_architecture.md`
  - Quick Look preview 경로를 첫 페이지 PNG에서 전체 페이지 PDF preview container 경로로 갱신
- `Sources/README.md`
  - Shared helper 설명을 page bitmap과 Quick Look 표시용 PDF preview까지 포함하도록 갱신
- `mydocs/orders/20260429.md`
  - #85 상태를 완료로 갱신
- `mydocs/working/task_m010_85_stage4.md`
  - Stage 4 검증 결과 기록
- `mydocs/report/task_m010_85_report.md`
  - 최종 결과 보고서 작성

## 변경 내용

### 아키텍처 문서 갱신

`mydocs/tech/project_architecture.md`에서 다음 설명을 현재 구현에 맞게 정리했다.

- `QLExtension`은 첫 페이지 PNG가 아니라 전체 페이지 Quick Look preview를 만든다.
- `HwpPreviewProvider`는 `HwpPreviewPDFRenderer`에 preview 생성을 요청한다.
- `HwpPreviewPDFRenderer`는 `RhwpDocument.pageCount`만큼 순회하고, 각 페이지를 `HwpPageImageRenderer`로 bitmap 렌더링한다.
- Quick Look preview reply는 page bitmap을 담은 `.pdf` content type이다.
- 이 PDF는 사용자용 PDF export나 HWP/HWPX 구조 변환 산출물이 아니다.

`Sources/README.md`의 Shared 역할도 첫 페이지 bitmap 전용 표현에서 page bitmap 렌더링과 Quick Look 표시용 PDF preview를 포함하는 표현으로 바꿨다.

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
** BUILD SUCCEEDED ** [0.462 sec]
```

### PDF page count smoke

Stage 3에서 만든 ignored helper `build.noindex/preview_pdf_check`로 Quick Look PDF preview data를 `PDFDocument`로 다시 열어 page count를 확인했다.

```bash
build.noindex/preview_pdf_check \
  samples/basic/KTX.hwp \
  samples/hwp-multi-001.hwp \
  samples/hwpx/hwpx-01.hwpx
```

결과:

```text
OK KTX.hwp: sourcePages=1 previewPages=1 pdfPages=1 bytes=488798
OK hwp-multi-001.hwp: sourcePages=10 previewPages=10 pdfPages=10 bytes=1495345
OK hwpx-01.hwpx: sourcePages=9 previewPages=9 pdfPages=9 bytes=1457195
```

### Release package와 extension 등록

```bash
./scripts/package-release.sh 0.1.0
```

결과:

```text
** BUILD SUCCEEDED ** [15.353 sec]
a417259d0a72e08c4e87947bed33f792650a304277e28d44c5c7a01e193a7a2f  alhangeul-macos-0.1.0.zip
```

Release app을 표준 smoke 위치 `/Users/melee/Applications/AlhangeulMac.app`에 설치하고 LaunchServices/PlugInKit 등록을 수행했다.

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

설치된 app bundle도 검증했다.

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

결과:

```text
qlmanage: resetting quicklookd
qlmanage: call reset on cache
```

HWP preview:

```bash
qlmanage -p samples/hwp-multi-001.hwp
```

결과:

```text
Testing Quick Look preview with files:
	samples/hwp-multi-001.hwp
```

명령은 exit code 0으로 종료했다.

HWPX preview:

```bash
qlmanage -p samples/hwpx/hwpx-01.hwpx
```

결과:

```text
Testing Quick Look preview with files:
	samples/hwpx/hwpx-01.hwpx
2026-04-29 07:17:06.622 qlmanage[...] addTextFromVisionDocument: numWordQuads = 867, elapsedTime = 1.28031 secs
```

preview 세션이 crash 없이 유지되어 수동 interrupt로 종료했다. 자동화 환경에서 UI 스크롤을 캡처하지는 못했지만, 다중 페이지 여부는 위 PDF page count smoke에서 HWP 10 page, HWPX 9 page로 확인했다.

참고로 `qlmanage -p -o /tmp/alhangeul-ql-task85-preview ...` 출력 파일 모드는 이 환경에서 `NSInvalidArgumentException`으로 종료했다. 일반 `qlmanage -p` preview 경로와 `qlmanage -t` thumbnail 경로는 정상 동작했고, `-p -o`는 사용자-facing Finder/Quick Look 경로가 아니므로 잔여 진단 항목으로만 기록한다.

### Thumbnail smoke

```bash
qlmanage -t -x -s 512 -o /tmp/alhangeul-ql-task85-thumbnail \
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
/tmp/alhangeul-ql-task85-thumbnail/KTX.hwp.png:           PNG image data, 512 x 363, 8-bit/color RGBA, non-interlaced
/tmp/alhangeul-ql-task85-thumbnail/hwp-multi-001.hwp.png: PNG image data, 363 x 512, 8-bit/color RGBA, non-interlaced
/tmp/alhangeul-ql-task85-thumbnail/hwpx-01.hwpx.png:      PNG image data, 363 x 512, 8-bit/color RGBA, non-interlaced
```

## 잔여 위험

- Quick Look preview는 모든 페이지 bitmap을 하나의 PDF data로 만든다. 긴 문서에서 초기 표시 지연과 메모리 사용량은 후속 실사용 샘플에서 계속 관찰해야 한다.
- 자동화 환경에서는 Finder Quick Look 창 안의 스크롤 조작을 캡처하지 않았다. 다중 페이지 산출 자체는 `PDFDocument` page count로 확인했다.
- `qlmanage -p -o` 출력 파일 모드는 ExtensionFoundation 예외로 종료했다. 현재 사용자-facing smoke는 일반 `qlmanage -p`와 Finder 경로라 이번 범위의 차단 이슈로 보지 않는다.

## 다음 단계 영향

- 기능 구현 단계는 완료했다.
- 작업지시자 승인 후 최종 보고서 검토를 바탕으로 publish branch push와 devel 대상 draft PR 절차로 넘어갈 수 있다.
