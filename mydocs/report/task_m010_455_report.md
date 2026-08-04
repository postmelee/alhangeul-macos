# Task #455 최종 결과보고서

## 작업 요약

- 이슈: [#455 rhwp-studio PDF 저장 메뉴를 SVG 기반 native PDF 내보내기로 통합](https://github.com/postmelee/alhangeul-macos/issues/455)
- 마일스톤: v0.1 (`M010`)
- 대상 통합 브랜치: `devel`
- 작업 브랜치: `local/task455` → 게시 브랜치 `publish/task455`
- 단계 수: 5개 Stage와 Stage 2.1 보완

bundled `rhwp-studio` 내부 `PDF로 저장…`과 알한글 toolbar의 PDF 내보내기를 하나의 native 저장 흐름으로 통합했다. 메뉴·toolbar command routing, `NSSavePanel`, 오류 처리, atomic write와 Finder 표시는 알한글이 소유한다. PDF 본문은 현재 editor가 제공하는 전체 page SVG를 page별 `WKWebView.createPDF`로 변환하고 PDFKit으로 병합한다.

HWPX PDF 저장에서 `exportHwp` 중간 변환과 `RhwpDocument`/bitmap PDF 의존을 제거했다. 일반 인쇄는 사용자 UX를 유지하면서 같은 page SVG renderer를 사용하고, Quick Look/Thumbnail은 기존 render tree bitmap 경로를 유지한다.

## 변경 전·후 비교

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| 내부 PDF 메뉴 | upstream `file:print-to-pdf` → browser print | HostBridge capture → canonical `file:export-pdf` |
| toolbar PDF | HostApp native panel → HWP bytes → native bitmap PDF | HostApp native panel → current page SVG → WebKit PDF |
| 메뉴/toolbar destination UX | 서로 다름 | 동일한 `NSSavePanel`과 coordinator 상태 |
| HWPX PDF 중간 변환 | `exportHwp`로 HWP bytes 생성 | 없음. HWP/HWPX 모두 `pageCount`/`getPageSvg` |
| PDF text layer | bitmap 기반으로 검색·선택 보장 없음 | upstream SVG와 WebKit 기반 searchable/selectable text |
| page geometry | native bitmap page container | SVG별 width/height/viewBox를 `WKPDFConfiguration.rect`에 반영 |
| 일반 인쇄 PDF 생성 | print controller 내부 전용 WebKit 구현 | 공용 `RhwpStudioPagePDFRenderer` 사용 |
| 인쇄 방향 초기화 | shared print info 기본 방향 영향 | 전체 page가 단일 방향일 때만 초기화, 혼합 방향은 강제하지 않음 |
| Quick Look/Thumbnail | render tree bitmap | 변경 없음 |
| HostAppTests | 100개 | 116개, 실패 0개 |

`origin/devel...HEAD` 기준 최종 보고서 작성 전 diff는 24개 파일, 2,613줄 추가, 319줄 삭제다.

## 주요 변경 파일

| 파일 | 내용 |
|------|------|
| `Sources/HostApp/Services/RhwpStudioPagePayload.swift` | page count, SVG 배열 수와 non-empty page를 검증하는 공용 payload 추가 |
| `Sources/HostApp/Services/RhwpStudioPagePDFRenderer.swift` | page별 SVG metrics, offscreen WKWebView, `createPDF`, PDFKit merge와 lifecycle 구현 |
| `Sources/HostApp/Services/RhwpStudioPrintOrientationPolicy.swift` | 전체 PDF page 방향 기반 print job orientation 정책 추가 |
| `Sources/HostApp/Services/RhwpStudioPrintController.swift` | WebKit 생성 책임을 제거하고 공용 renderer 결과를 print operation에 연결 |
| `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift` | 내부 PDF 메뉴 capture·canonical command, current page SVG payload와 menu override 구현 |
| `Sources/HostApp/Services/RhwpStudioPDFExportController.swift` | HWP bytes/bitmap 경로를 공용 SVG renderer, `%PDF` 검증과 atomic write로 교체 |
| `Sources/HostApp/Services/DocumentPDFExportPanel.swift` | controller 내부 중복 panel 경로 제거, coordinator 단일 소유로 정리 |
| `Sources/HostApp/Views/RhwpStudioWebView.swift` | native panel, pending state, page payload 수락, 중복·오류·성공 lifecycle 통합 |
| `Tests/HostAppTests/RhwpStudio*PDF*Tests.swift`와 관련 테스트 | payload, renderer, export controller, command bridge와 orientation 정책 검증 |
| `project.yml`, `Alhangeul.xcodeproj/project.pbxproj` | 신규 HostAppTests source 구성과 XcodeGen 생성 결과 |
| `mydocs/tech/project_architecture.md` | PDF/print/upstream/Quick Look/Thumbnail ownership과 잔여 제한 갱신 |
| `mydocs/plans/task_m010_455*.md` | 수행 계획과 5단계 구현 계약 기록 |
| `mydocs/working/task_m010_455_stage1.md` ~ `task_m010_455_stage5.md` | 조사, 구현, 실제 UI 통합 검증과 architecture 정리 결과 기록 |

bundled upstream asset, HWP/HWPX 문서 저장 기능, 공유 경로, `Sources/RhwpCoreBridge`, Quick Look과 Thumbnail 제품 source는 변경하지 않았다.

## 단계별 결과

| 단계 | 커밋 | 결과 |
|------|------|------|
| 수행·구현 계획 | `9616fea`, `595e629` | Issue 목표, command/payload/ownership과 5단계 승인·검증 경계 확정 |
| Stage 1 | `b764d2e` | 내부 browser print, toolbar HWP bytes/bitmap PDF, 일반 인쇄 SVG/WebKit 경로 조사와 target 계약 확정 |
| Stage 2 | `798629b` | 공용 page payload와 SVG PDF renderer 분리, 일반 인쇄가 공용 renderer를 사용하도록 전환 |
| Stage 2.1 | `e245b42` | KTX 수동 smoke에서 확인한 회전 문제를 전체 page 기반 orientation 정책으로 보완 |
| Stage 3 | `1468a67` | 내부 메뉴와 toolbar native 저장 통합, HWP bytes/bitmap PDF 의존 제거, menu observer 회귀 보완 |
| Stage 4 | `d15d2cf` | 실제 HWP/HWPX/KTX, 최신 편집, text selection, 취소·대치·write failure와 원본 불변 검증 |
| Stage 5 | `5ac8a6d` | native SVG PDF ownership, Quick Look/Thumbnail 경계와 잔여 제한 architecture 반영 |

## 구현 결과

### canonical command와 native 저장 UX

두 사용자 진입점은 다음 하나의 HostApp 경로로 수렴한다.

```text
내부 file:print-to-pdf ─┐
                        ├─> canonical file:export-pdf
toolbar file:export-pdf ┘
    -> requestPDFExport
    -> DocumentPDFExportPanel
    -> current page SVG payload
    -> RhwpStudioPagePDFRenderer
    -> RhwpStudioPDFExportController atomic write
    -> Finder 표시
```

HostBridge가 내부 메뉴 event를 upstream browser print handler보다 먼저 소비한다. 초기 `disabled`/`aria-disabled`와 browser print tooltip은 알한글 native 저장 동작에 맞게 보정한다. upstream menu DOM 갱신에 대응하는 observer는 해당 menu element 하나만 관찰하고 frame당 한 번만 복원해 document 전체 attribute 반복 갱신으로 앱이 멈추던 최초 Stage 3 회귀를 제거했다.

Coordinator는 `idle → choosingDestination → collectingPages(destinationURL) → exporting → idle` 상태를 소유한다. 취소는 SVG 요청이나 output 생성 없이 복귀하고, 진행 중 중복 command는 새 panel·renderer를 만들지 않는다. 실패 후 controller와 pending destination을 정리하며 write에 성공한 URL만 Finder에 표시한다.

### current page SVG와 공용 PDF renderer

HostBridge의 `documentPages()`는 active editor를 settle한 뒤 `pageCount`와 page index 순서의 `getPageSvg`를 수집한다. HWP/HWPX와 일반 인쇄가 같은 `{ fileName, pageCount, pages }` 계약을 사용한다.

공용 renderer는 다음 순서로 동작한다.

1. page count, SVG 배열 수와 non-empty page를 검증한다.
2. page SVG를 전용 offscreen `WKWebView`에 순차 load한다.
3. SVG width/height, viewBox와 rendered rect에서 유효한 양의 page metrics를 결정한다.
4. page 크기로 web view frame과 `WKPDFConfiguration.rect`를 설정한다.
5. `WKWebView.createPDF` 결과가 정확히 한 page인지 검증한다.
6. PDFKit으로 입력 순서대로 병합하고 최종 page count를 다시 확인한다.

renderer는 command, alert, save/print panel, destination write와 Finder 표시를 소유하지 않는다. PDF export controller는 최종 data의 `%PDF` signature와 atomic write만, print controller는 `PDFDocument.printOperation`과 print 전용 lifecycle만 담당한다.

### HWP/HWPX 원본 불변

PDF 저장은 source document 저장과 분리된 non-mutating command다.

- HWPX를 HWP bytes로 변환하지 않는다.
- PDF helper와 controller는 `exportHwp`, `exportHwpBase64`, `exportHwpx`, `RhwpDocument`, `HwpPreviewPDFRenderer`를 입력으로 사용하지 않는다.
- 저장되지 않은 최신 편집은 current editor page SVG를 통해 PDF에 반영된다.
- source URL, filename과 format을 바꾸지 않고 editor를 clean으로 만들거나 `notifySaved`를 호출하지 않는다.
- 선택한 destination PDF 외에 HWP/HWPX 원본을 쓰지 않는다.

HostBridge에 남은 HWP/HWPX bytes exporter는 문서 저장·공유 기능의 기존 경로이며 PDF export 범위 밖이다.

### 일반 인쇄와 Quick Look/Thumbnail 경계

일반 `파일 > 인쇄`의 macOS print panel UX는 유지하고 PDF 본문 생성만 공용 SVG renderer를 사용한다. 모든 non-square page가 landscape 또는 portrait 하나로 일치할 때만 print job orientation을 초기화한다. 방향이 섞이거나 square page뿐인 경우 orientation을 강제하지 않고 PDFKit auto-rotate에 맡긴다.

Quick Look 다중-page preview와 Thumbnail은 Rust render tree를 CoreGraphics bitmap으로 그리는 기존 경로를 유지한다. `HwpPreviewPDFRenderer`가 만드는 PDF는 Finder 표시용 bitmap container이며 사용자 PDF export의 fallback이나 입력이 아니다.

## Issue 완료 조건별 결과

| 완료 조건 | 결과 | 근거 |
|-----------|------|------|
| 내부 PDF 메뉴가 browser print 대신 알한글 `NSSavePanel`을 표시 | OK | Stage 3 보완 뒤 작업지시자 실제 UI 확인, Stage 4 native panel 반복 검증 |
| 내부 메뉴와 toolbar가 동일한 SVG 생성·저장 경로 사용 | OK | command bridge 테스트와 HWP/HWPX/KTX 대응 PDF의 geometry·text·raster 일치 |
| `exportHwp → RhwpDocument → bitmap PDF` 제거 | OK | PDF helper/controller 정적 대조와 공용 renderer controller 테스트 |
| HWP/HWPX 최신 편집 반영과 원본 불변 | OK | 저장 전 HWPX edit marker가 PDF에 반영되고 원본·복사본 SHA-256/mtime 유지 |
| 다중 page count, size/orientation과 nonblank 유지 | OK | HWP/HWPX upstream 9쪽과 PDF 9쪽 일치, 전 page `794 × 1123 pt`와 nonblank 확인 |
| 대표 text 검색·선택 가능 | OK | `pdftotext -layout`, PDFKit search와 macOS Preview의 `보도자료` 실제 selection 성공 |
| bundled upstream asset 직접 수정 없음 | OK | source/built asset manifest 검증 통과 |
| Quick Look/Thumbnail bitmap renderer 변경 없음 | OK | 관련 제품 source diff 없음, architecture 경계 명시 |

## 실제 PDF와 UI 통합 검증

### KTX 가로 HWP

- 내부 메뉴와 toolbar 결과 모두 1 page, `1123 × 794 pt`, rotation 0
- 두 PDF의 추출 text와 96 dpi page raster 동일
- `KTX`, 노선도, 운임과 소요 시간 text layer 확인
- 인쇄 panel에서 90도 회전 없이 landscape 표시

### 다중 HWP

- 앱 upstream page count 9쪽과 두 PDF page count 9쪽 일치
- 전 page `794 × 1123 pt`, rotation 0
- 메뉴/toolbar page별 raster와 추출 text 동일
- 9쪽 모두 nonblank, 최소 ink ratio `0.066785`
- `보도자료`, `2024년 3분기`, `해외직접투자` 검색

### 다중 HWPX와 최신 편집

- 앱 upstream page count 9쪽과 두 PDF page count 9쪽 일치
- 전 page `794 × 1123 pt`, rotation 0
- 메뉴/toolbar page별 raster와 추출 text 동일
- 9쪽 모두 nonblank, 최소 ink ratio `0.066833`
- 디스크에 저장하지 않은 `TASK455_EDIT_MARKER`가 PDF raster와 text layer에 반영
- macOS Preview 접근성 tree에서 한글 text node가 노출되고 `보도자료` 실제 selection 성공

세 fixture의 repository 원본과 smoke 복사본은 검증 전후 SHA-256과 수정 시각이 같았다.

### save lifecycle와 인쇄 회귀

- panel 취소: output 0건, editor 복귀와 다음 export 재진입 성공
- 기존 PDF 대치: native 확인 sheet 뒤 9-page PDF 재생성 성공
- read-only destination: 사용자 오류, partial output 0건, 오류 뒤 export 재진입 성공
- 일반 인쇄: 편집된 9-page HWPX의 `9페이지 모두`, 정상 portrait preview와 취소 복귀 확인

## 최종 통합 검증

| 검증 | 결과 |
|------|------|
| `xcodegen generate` | 통과. `project.yml`에서 재생성 후 Xcode project 추가 diff 0건 |
| clean HostAppTests (`build.noindex/task455/stage5-tests`) | `** TEST SUCCEEDED **`, 116개, 실패 0개 |
| clean HostApp Debug build (`build.noindex/task455/stage5-build`) | `** BUILD SUCCEEDED **` |
| built app bundled asset | manifest와 자산 일치 |
| 실제 PDF page count/geometry/text/raster | KTX, HWP, HWPX 대표 결과 모두 통과 |
| macOS Preview text selection | `보도자료` 실제 selection 통과 |
| save 취소·대치·permission failure | partial output 없이 상태 복구 통과 |
| 원본 SHA-256/mtime | smoke 전후 동일 |
| `./scripts/check-no-appkit.sh` | Shared/RhwpCoreBridge AppKit/UIKit 의존 없음 |
| extension registration hygiene | 등록된 development provider 0건 |
| `git diff --check` | 통과 |

테스트 실행 중 WebKit 보조 process의 sandbox 진단 로그가 출력됐지만 실제 renderer/controller 테스트와 전체 suite는 정상 완료됐다.

## 잔여 위험과 후속 경계

- page SVG는 순차 생성·변환하지만 bridge message와 native payload가 전체 SVG 문자열 배열을 보유한다. 큰 다중-page 문서의 memory/time 비용이 남는다.
- page별 `getPageSvg`에는 30초 timeout이 있으나 전체 export deadline, progress와 수집 중 사용자 취소 UI는 없다.
- upstream SVG의 positioned text 때문에 `pdftotext -layout`에서 한글이나 편집 marker 내부에 시각 위치 기준 공백이 추가될 수 있다. Stage 4 Preview text node와 selection은 유지됐다.
- 실제 가로·세로 혼합 HWP/HWPX fixture는 대표 세트에 없다. 혼합 geometry 보존과 print orientation 비강제는 합성 SVG 자동 테스트로 검증했다.
- Quartz PDF metadata의 생성 시각 때문에 같은 본문을 다시 저장해도 file SHA-256은 달라질 수 있다. 동등성은 page count, geometry, extracted text와 raster로 판단해야 한다.
- invalid/empty SVG, page count mismatch, navigation/`createPDF`/PDFKit decode 또는 write 실패는 전체 export 실패로 처리한다.
- PR merge 뒤 Issue #455 close와 `publish/task455`/`local/task455` 정리는 merge 확인 후 수행한다.

## 최종 결론

Issue #455의 계획된 Stage 1~5와 Stage 2.1 보완을 완료했다. 알한글이 내부 메뉴와 toolbar의 native 저장 UX를 일관되게 소유하고, PDF 본문은 upstream current page SVG를 공용 WebKit renderer로 생성한다.

HWPX 중간 HWP 변환과 사용자 PDF의 bitmap renderer 의존이 제거됐으며, 실제 HWP/HWPX/KTX에서 page geometry, nonblank 출력, 검색·선택 가능한 text, 최신 편집 반영과 원본 불변을 확인했다. 일반 인쇄는 같은 renderer를 공유하면서 기존 print panel UX를 유지하고, Quick Look/Thumbnail은 기존 bitmap 경계를 유지한다.

이 보고서 커밋 후 `publish/task455`를 `devel` 대상으로 게시한 Open PR의 리뷰와 merge를 요청한다. merge 전에는 Issue #455를 열린 상태로 유지하고, merge 확인 뒤 정리 절차를 수행한다.
