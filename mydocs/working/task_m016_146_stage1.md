# Task M016 #146 Stage 1 보고서 - 렌더 경로 inventory 정리

## 단계 목적

HostApp viewer, PDF export, print, Quick Look preview, Finder thumbnail의 실제 코드 경로와 현재 문서 표현을 대조했다. 이 단계에서는 README, 아키텍처 문서, release note script를 수정하지 않고, Stage 2 known limitations 문구 설계에 필요한 inventory만 확정했다.

## 산출물

| 파일 | 내용 |
|------|------|
| `mydocs/working/task_m016_146_stage1.md` | 제품 표면별 실제 renderer 경로, 기존 문서 표현, 수정 필요 후보, M016 handoff 항목 정리 |

본문 소스와 공개/운영 문서는 변경하지 않았다.

## 제품 표면별 실제 경로

| 표면 | 현재 코드 경로 | 판단 |
|------|----------------|------|
| HostApp viewer/editor 화면 | `DocumentViewerStore`가 문서 bytes와 revision을 `RhwpStudioDocumentPayload`로 보관하고, `RhwpStudioWebView`가 `alhangeul-studio://app/index.html?url=alhangeul-document://current...`를 로드한다. 정적 asset은 `RhwpStudioResourceSchemeHandler`, 문서 bytes는 `RhwpStudioDocumentSchemeHandler`가 제공한다. 문서 parsing/layout/zoom/page/search UI는 bundled `rhwp-studio` Web/WASM 경로가 담당한다. | README와 아키텍처의 큰 방향은 맞다. 다만 v0.1 한계 문구가 아직 public 문서에 충분히 드러나지 않는다. |
| HostApp PDF export | `RhwpStudioHostBridgeScript.exportPDFDocument()`가 `rhwp-studio`에서 HWP export payload를 받아 native로 전달한다. Swift 쪽 `RhwpStudioPDFExportController.renderPDFData`는 해당 bytes를 `RhwpDocument`로 열고 `HwpPreviewPDFRenderer`/`HwpPageImageRenderer` render tree bitmap 경로로 PDF를 만든다. | README의 “HostApp PDF 내보내기 ... Rust bridge와 Swift 공통 계층” 표현은 현재 코드와 맞다. `project_architecture.md`의 “같은 page SVG response를 PDF save job으로 실행” 표현은 현재 코드와 어긋나 Stage 3 보정 대상이다. |
| HostApp print | `RhwpStudioHostBridgeScript.printDocument()`가 `documentPages()`에서 page payload 배열을 native로 보내고, `RhwpStudioPrintController`가 각 page HTML을 별도 `WKWebView`에 로드한 뒤 `createPDF`, `PDFDocument`, `NSPrintOperation`으로 출력한다. | README의 별도 WKWebView/PDFKit/AppKit print operation 표현은 대체로 맞다. 아키텍처의 “page SVG response” 표현은 실제 payload가 page HTML/SVG wrapper 성격임을 더 정확히 쓸 필요가 있다. |
| Quick Look preview | `HwpPreviewProvider`가 `HwpPreviewPDFRenderer.inspect`로 page count와 첫 페이지 크기를 확인한다. 단일 페이지는 `HwpPageImageRenderer.renderPage`로 PNG reply를 만들고, 다중 페이지는 `HwpPreviewPDFRenderer.render`가 각 page bitmap을 PDF page에 삽입한다. fallback 대상 오류는 plain text reply로 수렴한다. | README와 아키텍처의 설명은 대체로 맞다. 다만 smoke 통과와 visual parity 보장을 분리하는 known limitations가 필요하다. |
| Finder thumbnail | `HwpThumbnailProvider`가 `HwpThumbnailRenderRequest`를 만들고, `HwpThumbnailRenderCache`가 cache miss에서 `HwpPageImageRenderer.renderFirstPage(..., embeddedThumbnailPolicy: .never)`를 호출한다. 결과 이미지는 요청 크기에 aspect-fit으로 그려지고 fallback 대상 오류는 fallback tile로 수렴한다. | README와 아키텍처의 설명은 맞다. thumbnail 생성 성공이 문서 전체 호환성이나 preview 시각 품질 보장은 아니라는 문구가 필요하다. |

## 기존 문서 표현 대조

| 문서 | 현재 표현 | 수정 필요 후보 |
|------|-----------|----------------|
| `README.md` 소개/로드맵 | 첫 viewer는 `rhwp-studio` WKWebView, Finder/Quick Look과 PDF export는 Swift/Rust bridge 경로를 함께 사용한다고 설명한다. | 방향은 맞지만 v0.1이 완전 호환 viewer가 아니라는 사용자-facing limitation 섹션이 없다. |
| `README.md` Rendering Paths | HostApp 화면은 Web/WASM, PDF/Quick Look/Thumbnail은 Rust bridge + Swift 공통 계층, print는 별도 WKWebView/PDFKit/AppKit으로 설명한다. | PDF와 print가 viewer 화면과 같은 renderer가 아니라는 점을 더 선명하게 표 구조로 정리할 후보. |
| `project_architecture.md` HostApp/Shared | HostApp MVP viewer 화면은 native bitmap helper를 직접 호출하지 않는다고 명시한다. | `RhwpCoreBridge`가 “HostApp, Quick Look, Thumbnail이 모두 공유”한다고 쓴 부분은 HostApp PDF export/target 포함과 viewer 화면 경로를 구분하도록 보강할 후보. |
| `project_architecture.md` runtime flow | HostApp viewer 경로, Quick Look preview, Thumbnail 경로는 상세히 정리되어 있다. | PDF export를 “page SVG response” 기반으로 설명한 부분은 현재 `exportHwp` payload -> native PDF render 경로와 맞지 않는다. Stage 3 필수 보정 후보. |
| `release_distribution_guide.md` | artifact/provenance, smoke, Finder integration gate는 정리되어 있고 “알려진 한계” 체크 항목이 있다. | release note에 넣을 renderer 경로/known limitations 기준은 아직 구체적이지 않다. |
| `scripts/ci/write-release-notes.sh` | 설치, 산출물, rhwp core, viewer asset provenance, third-party notices, 검증 섹션을 생성한다. | 렌더링 경로와 known limitations가 독립 섹션으로 나오지 않고 최종 보고서 참조 문장에만 의존한다. Stage 4 보정 후보. |

## M016 handoff 수집

| 출처 | #146 입력 |
|------|-----------|
| #149 최종 보고서 | HostApp은 50 MB hard block이 없고, 50 MB 제한은 Quick Look/Thumbnail preview 제한으로 유지한다. 손상 문서 fallback은 복구가 아니라 crash/hang/raw error 방지 목적이다. HWPX preflight는 ZIP magic 수준이다. |
| #150 최종 보고서 | WKWebView viewer의 service worker registration 같은 PWA 부산물이 custom scheme에서 실패할 수 있으며, 문서 렌더와 무관한 benign runtime issue는 fatal fallback에서 제외한다. |
| #151 최종 보고서 | `qlmanage -t -x` 자동 thumbnail gate 통과와 `qlmanage -p`/Finder Space preview 수동 확인, native renderer 시각 품질 검증은 서로 다른 문제다. |
| #167 최종 보고서 | known limitations는 `rhwp-studio v0.7.10` WKWebView 경로와 native renderer smoke 결과를 기준으로 문서화한다. native renderer parity 개선은 이번 M016 범위가 아니다. |

## Stage 2 입력

Stage 2에서는 다음 범주로 문구를 설계한다.

| 범주 | 설계 입력 |
|------|-----------|
| 경로 차이 | HostApp viewer/editor 화면은 WKWebView `rhwp-studio`, Quick Look/Thumbnail/PDF export는 Rust bridge + Swift native render tree 계열, print는 별도 WKWebView/PDFKit/AppKit 경로다. |
| 품질 차이 | native renderer smoke 통과는 WebView와 pixel/visual parity를 의미하지 않는다. style, image effect/fill, text layout, body overflow, RawSvg/OLE 등은 후속 native renderer parity 범위다. |
| fallback 한계 | 손상/대용량/미지원 입력 fallback은 사용자 파일 복구나 완전 호환이 아니라 앱/extension 유지와 raw error 방지 목적이다. |
| 검증 한계 | 설치본 smoke gate는 자동 thumbnail 생성과 수동 preview 확인을 분리한다. |
| release note | release note skeleton은 provenance만이 아니라 렌더링 경로와 known limitations를 별도 섹션으로 드러내야 한다. |

## 검증 결과

Stage 1 구현계획서의 검증 명령을 실행했다.

```bash
git status --short --branch
```

결과: `## local/task146`

```bash
rg -n "rhwp-studio|WKWebView|exportPDF|PDF|print|page SVG|HwpPreviewPDFRenderer|HwpPageImageRenderer|CGTreeRenderer|Quick Look|Thumbnail" \
  Sources/HostApp Sources/Shared Sources/QLExtension Sources/ThumbnailExtension
```

결과: `Sources/HostApp`, `Sources/Shared`, `Sources/QLExtension`, `Sources/ThumbnailExtension`에서 viewer/PDF/print/Quick Look/Thumbnail 관련 경로가 확인됐다. 출력에는 bundled `rhwp-studio` minified asset match가 포함되어 길게 표시됐지만 명령은 exit code 0으로 통과했다.

```bash
rg -n "Rendering Paths|렌더링 경로|WKWebView|Quick Look|Thumbnail|PDF|인쇄|known limitation|한계|native parity|v0\\.5" \
  README.md mydocs/tech/project_architecture.md mydocs/manual/release_distribution_guide.md scripts/ci/write-release-notes.sh
```

결과: README와 아키텍처 문서의 렌더링 경로 표현, release guide의 smoke/한계 관련 표현, release note skeleton의 최종 보고서 참조 문구를 확인했다.

```bash
rg -n "#146|known limitation|한계|native renderer|WKWebView|Quick Look|Thumbnail" \
  mydocs/report/task_m016_149_report.md \
  mydocs/report/task_m016_150_report.md \
  mydocs/report/task_m016_151_report.md \
  mydocs/report/task_m016_167_report.md
```

결과: #149, #150, #151, #167의 #146 handoff와 residual risk 항목을 확인했다.

```bash
git diff --check
```

결과: Stage 1 보고서 작성 전 기준으로 whitespace error 없음.

## 잔여 위험

- Stage 1은 inventory 단계라서 README/아키텍처/release note의 실제 보정은 아직 수행하지 않았다.
- 첫 `rg` 명령은 bundled minified asset까지 검색해 출력이 길다. Stage 2 이후 검증 명령은 필요하면 source glob 제외 또는 대상 파일 축소를 검토할 수 있다.
- PDF export 경로는 현재 `rhwp-studio` export payload와 native render tree PDF 경로가 결합되어 있어 사용자 문구가 길어질 수 있다. Stage 2에서 “viewer 화면 renderer와 PDF output renderer가 다르다”는 요지를 짧게 정리해야 한다.

## 다음 단계 영향

Stage 2에서는 위 inventory를 기준으로 README/release guide/release note skeleton이 각각 소유할 known limitations 문구를 설계한다. 특히 `project_architecture.md`의 PDF export runtime flow 보정은 Stage 3 필수 후보로 둔다.

## 승인 요청

Stage 1 `현재 렌더 경로와 handoff inventory`를 완료했다. Stage 2 `known limitations와 milestone 분리 기준 설계`로 진행해도 되는지 승인 요청한다.
