# Task #455 Stage 5 완료보고서

## 단계 목적

Stage 2~4에서 구현·검증한 HostApp PDF 저장 구조를 architecture 문서에 반영하고, upstream과 알한글의 ownership, 일반 인쇄와의 공용 경계, Quick Look/Thumbnail bitmap 경로와 잔여 제한을 최종 결과보고서 입력으로 정리한다.

Stage 5는 제품 소스를 추가 변경하지 않고 현재 구현과 실측 결과를 문서화하는 단계다.

## architecture 갱신 결과

`mydocs/tech/project_architecture.md`의 기존 HostApp PDF 설명을 HWP bytes/native bitmap 기반 구조에서 현재 page SVG 기반 구조로 갱신했다.

- 내부 `PDF로 저장…`의 `file:print-to-pdf`를 HostBridge에서 `file:export-pdf`로 정규화한다.
- 내부 메뉴와 titlebar toolbar는 같은 `requestPDFExport`와 native destination panel을 사용한다.
- destination 선택 뒤 현재 editor의 `pageCount`와 page별 `getPageSvg`를 순차 수집한다.
- `RhwpStudioPagePDFRenderer`가 page SVG의 geometry를 읽고 `WKWebView.createPDF`로 각 page를 변환한다.
- PDFKit이 단일-page 결과를 입력 순서대로 하나의 `PDFDocument`에 합친다.
- `RhwpStudioPDFExportController`는 `%PDF` signature를 확인하고 destination에 atomic write한다.
- `RhwpStudioPrintController`는 같은 renderer 결과를 AppKit print operation에 전달한다.
- Quick Look과 Thumbnail은 기존 `RhwpDocument`/render tree bitmap 경로를 유지한다.

## ownership 경계

| 구성요소 | 소유 책임 | 소유하지 않는 책임 |
|----------|-----------|--------------------|
| upstream `rhwp-studio` editor | current editor settle, `pageCount`, page별 `getPageSvg` | macOS save panel, destination URL, 파일 쓰기 |
| HostBridge | native command intercept와 canonicalization, page SVG payload 생성·검증 진입 | PDF 파일 생성, AppKit panel 표시 |
| `RhwpStudioWebView.Coordinator` | `requestPDFExport`, destination pending state, 중복 요청 차단, 성공·실패·취소 후 상태 정리 | SVG를 PDF로 변환하는 세부 구현 |
| `DocumentPDFExportPanel` | native destination 선택과 취소 | page SVG 수집, PDF 생성과 write |
| `RhwpStudioPagePDFRenderer` | SVG metrics, offscreen WKWebView load, `createPDF`, PDFKit page merge와 page count 검증 | command, panel, print operation, 파일 write, Finder 표시 |
| `RhwpStudioPDFExportController` | renderer lifecycle, `%PDF` 확인, atomic write | source document 저장, HWP/HWPX exporter 호출 |
| `RhwpStudioPrintController` | 공용 renderer 결과를 `PDFDocument.printOperation`에 전달, uniform orientation 초기화 | destination PDF write |
| Quick Look/Thumbnail | Rust render tree 기반 page bitmap과 Finder 표시 산출물 | HostApp 사용자 PDF 저장과 일반 인쇄 |

이 구분으로 “메뉴와 저장 UX는 알한글이 담당하되, PDF 생성은 upstream의 page SVG를 받아 `WKWebView.createPDF`로 처리”한다는 Issue #455의 목표를 architecture 진실 원천에 반영했다.

## command와 상태 전이

두 PDF 저장 진입점은 다음 하나의 경로로 수렴한다.

```text
내부 file:print-to-pdf ─┐
                        ├─> canonical file:export-pdf
toolbar file:export-pdf ┘
    -> requestPDFExport
    -> native destination panel
    -> documentPages(pageCount + SVG[])
    -> RhwpStudioPagePDFRenderer
    -> RhwpStudioPDFExportController atomic write
```

Coordinator 상태는 다음 순서로 이동한다.

```text
idle
  -> choosingDestination
  -> collectingPages(destinationURL)
  -> exporting
  -> idle
```

- panel 취소 시 page SVG를 요청하지 않고 `idle`로 복귀한다.
- choosing/collecting/exporting 중 추가 command는 새 panel이나 renderer를 만들지 않는다.
- page 수집, renderer 또는 write 실패 시 부분 결과를 성공으로 표시하지 않고 오류를 알린 뒤 `idle`로 복귀한다.
- 성공한 destination URL만 Finder 표시 대상으로 전달한다.

## HWP/HWPX 원본 불변 경계

PDF 저장은 HWP와 HWPX 모두 같은 current editor page SVG payload를 사용한다.

- HWPX를 `exportHwp`나 HWP bytes로 중간 변환하지 않는다.
- 사용자 PDF export controller는 `exportHwp`, `exportHwpBase64`, `exportHwpx`, `RhwpDocument`, `HwpPreviewPDFRenderer`를 입력으로 사용하지 않는다.
- PDF 저장은 source URL, source format과 document name을 바꾸지 않는다.
- PDF 저장 성공은 source 문서의 dirty state를 clean으로 만들거나 `notifySaved`를 호출하지 않는다.
- 디스크 원본 대신 저장 직전 current editor state의 SVG를 사용하므로 저장되지 않은 편집도 PDF에 반영된다.
- 선택한 destination PDF 외에는 source HWP/HWPX를 쓰지 않는다.

HostBridge에 남은 `exportHwp`/`exportHwpBase64` 호출은 HWP 저장·공유 기능 소유 경로이며 PDF helper에는 포함되지 않는다.

## page geometry와 일반 인쇄 정책

- page별 SVG `width`/`height` 또는 `viewBox`에서 양의 metrics를 확인한다.
- metrics에 맞춰 offscreen web view frame과 `WKPDFConfiguration.rect`를 page별로 설정한다.
- 각 `createPDF` 결과가 정확히 한 page인지 확인한 뒤 최종 문서에 삽입한다.
- 최종 PDF page count가 upstream payload page count와 일치해야 성공한다.
- 따라서 서로 다른 page size와 portrait/landscape geometry는 PDF page 단위로 유지된다.
- 일반 인쇄는 모든 non-square page 방향이 하나로 일치할 때만 print job orientation을 초기화한다.
- 가로·세로가 섞인 문서는 job orientation을 강제하지 않고 PDFKit `autoRotate`에 맡긴다.

## Stage 1~4 추적 결과

| 단계 | 확정·검증 내용 | 결과 |
|------|----------------|------|
| Stage 1 | 내부 메뉴/toolbar command matrix, bytes PDF와 SVG print의 기존 경로, target payload·renderer contract | canonical command와 page SVG 계약 확정 |
| Stage 2 | 공용 page SVG renderer 분리, PDFKit merge, 일반 인쇄 전환, uniform/mixed orientation 정책 | 합성 SVG와 print orientation 자동 테스트 통과 |
| Stage 2.1 | KTX 실제 인쇄 preview가 세로로 회전되는 회귀 | 전체 page 방향 기반 초기화로 KTX landscape 확인 |
| Stage 3 | 내부 메뉴와 toolbar의 native save panel·page SVG export 통합, HWP bytes PDF 의존 제거 | 자동 테스트와 Debug build 통과 |
| Stage 4 | 실제 HWP/HWPX/KTX, 최신 편집, text layer, 취소·대치·write failure, 원본 불변 | native UI와 산출물 통합 검증 통과 |

Stage 4 실제 측정값도 architecture 문서에 반영했다.

- KTX: 1 page, `1123 × 794 pt`, landscape, 메뉴/toolbar raster·text 동일
- HWP: upstream 9 page와 PDF 9 page 일치, 전 page `794 × 1123 pt`, nonblank
- HWPX: upstream 9 page와 PDF 9 page 일치, 전 page `794 × 1123 pt`, nonblank
- 저장되지 않은 HWPX 편집 marker가 PDF raster와 text layer에 반영됨
- macOS Preview에서 대표 한글 `보도자료` 실제 selection 성공
- HWP/HWPX 원본과 검증 복사본의 SHA-256·mtime 불변
- save panel 취소, 기존 파일 대치, permission write failure 후 재진입 통과
- 일반 인쇄 panel에서 9 page preview와 정상 방향 확인

## Quick Look/Thumbnail 경계

HostApp 사용자 PDF 저장과 Finder preview PDF는 이름만 PDF일 뿐 생성 목적과 renderer가 다르다.

- HostApp PDF 저장/일반 인쇄: upstream current editor page SVG → WebKit PDF → searchable/selectable text layer
- Quick Look 다중-page preview: Rust render tree page bitmap → Finder 표시용 PDF container
- Thumbnail: Rust render tree page bitmap → requested size의 aspect-fit image

`HwpPreviewPDFRenderer`는 Quick Look 다중-page bitmap container에 한정하고 HostApp 사용자 PDF export fallback으로 사용하지 않는다.

## 잔여 제한

- page SVG는 순차 생성·변환하지만 bridge message와 native payload가 전체 SVG 문자열 배열을 보유한다. 큰 다중-page 문서의 memory/time 비용이 남는다.
- page별 SVG RPC에는 30초 timeout이 있지만 전체 문서 단위의 별도 deadline이나 progress/cancel UI는 없다.
- SVG metrics가 없거나 0 이하인 page, 빈 SVG, page count mismatch, navigation/`createPDF`/PDFKit decode 실패는 전체 export 실패로 처리한다.
- upstream SVG가 positioned text를 사용하므로 `pdftotext -layout`에서는 시각 위치에 따라 단어 내부 공백이 생길 수 있다. Stage 4에서는 Preview text node와 실제 selection은 유지됨을 확인했다.
- 실제 가로·세로 혼합 HWP/HWPX fixture는 대표 세트에 없다. 혼합 geometry 보존과 print orientation 비강제는 합성 SVG 자동 테스트로 검증했다.
- Quartz PDF metadata에 생성 시각이 들어가 같은 본문을 다시 저장해도 file SHA-256은 달라질 수 있다. 본문 동등성은 page count, geometry, extracted text와 raster로 판정한다.
- save panel 취소는 destination 생성 없이 끝나지만 destination 선택 이후의 SVG 수집을 사용자가 중간 취소하는 UI는 없다.

## 자동 검증 결과

| 검증 | 결과 |
|------|------|
| architecture keyword/flow 대조 | 통과. command, page SVG, `createPDF`, Quick Look/Thumbnail 경계 확인. |
| PDF source dependency 대조 | 통과. PDF controller는 `createPDF` renderer와 atomic write를 사용하며 bytes/bitmap exporter 의존 없음. |
| HostBridge PDF helper 범위 대조 | 통과. PDF helper에 `exportHwp`, `exportHwpBase64`, `HwpPreviewPDFRenderer` 0건. |
| HostAppTests | 통과. 116개 테스트, 실패 0개. |
| HostApp Debug build | 통과. `CODE_SIGNING_ALLOWED=NO`, `** BUILD SUCCEEDED **`. |
| bundled rhwp-studio asset | 통과. manifest와 built asset 일치. |
| `./scripts/check-no-appkit.sh` | 통과. Shared/RhwpCoreBridge AppKit/UIKit 의존 없음. |
| extension registration hygiene | 통과. 등록된 development provider 0건. |
| `git diff --check` | 통과. |

HostAppTests 최종 결과는 다음과 같다.

```text
Executed 116 tests, with 0 failures (0 unexpected)
** TEST SUCCEEDED **
```

테스트 실행 중 WebKit 보조 process의 sandbox 진단 로그가 출력됐지만 renderer/controller 테스트와 전체 suite는 정상 완료됐다.

## 변경 파일

- 수정 `mydocs/tech/project_architecture.md`
- 신규 `mydocs/working/task_m010_455_stage5.md`
- 수정 `mydocs/orders/20260804.md`

Stage 5에서는 제품 소스, 테스트, `project.yml`, Xcode project와 bundled upstream asset을 변경하지 않았다. 검증 산출물은 git에서 제외되는 `build.noindex/task455/stage5-tests`와 `build.noindex/task455/stage5-build` 아래에 있다.

## 완료 기준 판단

- architecture 문서와 실제 native SVG PDF 경로 일치: 충족
- upstream/HostApp renderer/panel/export/print ownership 구분: 충족
- 내부 메뉴와 toolbar canonical command·pending state 문서화: 충족
- HWP/HWPX bytes exporter와 PDF 경로 분리·원본 불변 정책 문서화: 충족
- HostApp PDF/print와 Quick Look/Thumbnail bitmap 경계 구분: 충족
- page count, geometry, text semantics, 실패 조건과 잔여 제한 문서화: 충족
- Stage 1~4 결과를 최종 결과보고서에서 재추적 가능한 상태: 충족
- 전체 tests, build, asset와 dependency boundary 재검증: 충족

## 다음 단계 영향

Issue #455의 계획된 Stage 1~5가 모두 완료됐다. 다음 단계는 단계별 결과와 최종 diff를 합친 최종 결과보고서를 작성하고 `publish/task455`로 게시한 뒤 `devel` 대상 PR을 생성하는 것이다.

하이퍼-워터폴 승인 게이트에 따라 최종 결과보고서 작성과 PR 게시는 별도 승인을 받은 뒤 진행한다.

## 승인 요청

Stage 5 `PDF ownership 문서와 잔여 제한 정리`를 완료했다. 완료보고서 승인과 Issue #455 최종 결과보고서·PR 게시 진행 승인을 요청한다.
