# Task M020 #221 Stage 1 완료보고서

## 단계 목적

rhwp core SVG 기반 PDF 생성 후보를 비교하기 전에 현재 Quick Look preview 경로, rhwp SVG 산출 경로, hwpql 참고 구조의 차이를 코드 기준으로 확정한다.

이번 단계는 제품 코드 변경 없이 조사와 측정 기준 확정만 수행한다.

## 조사 내용

### 1. 현재 Quick Look preview 경로

현재 `HwpPreviewProvider`는 `HwpPreviewPDFRenderer.inspect(fileURL:)`로 파일 크기, page count, 첫 페이지 크기를 먼저 확인한다.

이후 page count 기준으로 reply가 갈린다.

| 조건 | reply | 생성 경로 |
|------|-------|----------|
| `pageCount == 1` | `.png` | `HwpPageImageRenderer.renderPage`가 첫 페이지를 bitmap으로 그리고 PNG encoding |
| `pageCount >= 2` | `.pdf` | `HwpPreviewPDFRenderer.render`가 모든 페이지 bitmap을 만들고 PDF page에 삽입 |

중요한 점은 현재 다중 페이지 PDF가 문서 구조를 vector PDF로 변환하는 방식이 아니라는 것이다. 각 페이지는 `RenderNode` + `CGTreeRenderer`로 bitmap 렌더링되고, 그 bitmap이 PDF page 안에 그려진다.

따라서 현재 기준선은 다음으로 정의한다.

```text
rhwp_open
-> pageCount/pageSize/renderPageTree
-> Swift CGTreeRenderer bitmap
-> PNG 또는 bitmap PDF reply
```

### 2. 현재 rhwp SVG 산출 경로

`RhwpDocument.renderPageSVG(at:)`는 `rhwp_render_page_svg`를 호출한다. 이 경로는 기존 #65 작업에서 디버깅 산출물로 이미 쓰이고 있으며, `scripts/render-debug-compare.sh`는 한 입력에 대해 다음 산출물을 만들 수 있다.

- render tree JSON
- rhwp core SVG
- native renderer PNG
- summary
- 가능한 경우 core SVG rasterize PNG와 diff

즉 Stage 2에서 새 측정 helper를 만들 때, core SVG 산출 자체를 새로 설계할 필요는 없다. 필요한 것은 기존 core SVG 생성 시간을 native bitmap PDF 생성 시간과 같은 표 안에 기록하는 측정 계층이다.

### 3. hwpql 참고 구조

`hulryung/hwpql`의 preview provider는 Swift에서 `hwp_parse_to_html`을 호출하고, 반환된 HTML을 `QLPreviewReply(dataOfContentType: UTType.html, ...)`로 전달한다.

Rust FFI 쪽 `hwp_parse_to_html`은 다음 흐름이다.

```text
DocumentCore::from_bytes
-> page_count
-> render_page_svg_native(i) for every page
-> <div class="page">{svg}</div> HTML wrapping
-> HTML string 반환
```

thumbnail provider는 `hwp_get_preview_image`를 호출해 HWP 내부 preview image를 추출한다.

hwpql에서 참고할 점은 rhwp core SVG를 Quick Look에 연결한 구조다. 하지만 그대로 채택할 수 없는 이유도 명확하다.

- hwpql preview는 HTML reply다.
- 우리는 현재 다중 페이지에서 Quick Look의 PDF식 우측 페이지 정보/페이지 썸네일 UI를 유지하고 싶다.
- 따라서 최종 후보는 HTML reply가 아니라 `.pdf` reply여야 한다.

## 비교 기준

이번 spike의 비교 대상은 다음 세 가지로 나눈다.

| 후보 | 의미 | Stage 1 판단 |
|------|------|--------------|
| 현재 native bitmap PDF | Swift `CGTreeRenderer` bitmap을 PDF page에 삽입 | 기준선 |
| hwpql식 SVG HTML reply | core SVG를 HTML로 감싸 Quick Look에 전달 | PDF UI 유지 목표와 맞지 않아 제품 후보 제외 |
| rhwp SVG 기반 PDF reply | core SVG를 PDF page로 변환해 `.pdf` reply로 전달 | Stage 2~4 비교 후보 |

WebView/WKWebView로 SVG를 PDF화하는 방식은 측정 후보에서 제외한다. Quick Look extension 안에서 WebView cold start, asset/font/layout settle, async rendering, sandbox/메모리 리스크가 커서 빠른 preview/thumbnail 목표와 맞지 않는다.

## Stage 2 측정 항목

Stage 2 helper는 최소 다음 metrics를 기록해야 한다.

| 항목 | 설명 |
|------|------|
| `fileBytes` | 입력 파일 크기 |
| `pageCount` | rhwp page count |
| `firstPageSize` | 첫 페이지 logical size |
| `nativeInspectSeconds` | 현재 `HwpPreviewPDFRenderer.inspect` 시간 |
| `nativePDFSeconds` | 현재 `HwpPreviewPDFRenderer.render` 시간 |
| `nativePDFBytes` | 현재 PDF data 크기 |
| `coreOpenSeconds` | SVG 측정용 `RhwpDocument` open 시간 |
| `coreSVGSeconds` | 모든 페이지 SVG 생성 시간 |
| `coreSVGBytes` | 전체 SVG 문자열 bytes 합계 |
| `coreSVGFailures` | SVG 생성 실패 page |

Stage 3 이후 SVG 기반 PDF 후보가 생기면 다음 항목을 추가한다.

| 항목 | 설명 |
|------|------|
| `svgPDFSeconds` | SVG 기반 PDF 후보 생성 시간 |
| `svgPDFBytes` | SVG 기반 PDF 후보 data 크기 |
| `svgPDFPageCount` | 생성 PDF page count |
| `svgPDFFailure` | 변환 실패 이유 |

## 샘플 기준

초기 측정 샘플은 사용자가 실제 Quick Look 동작을 확인한 Desktop sample을 우선 사용한다.

| 샘플 | 목적 |
|------|------|
| `/Users/melee/Desktop/files/group-drawing-02.hwp` | 단일 페이지, 도형 중심 |
| `/Users/melee/Desktop/files/eq-01.hwp` | 단일 페이지, 수식/한글 포함 |
| `/Users/melee/Desktop/files/footnote-01.hwp` | 다중 페이지, footnote 포함 |
| `/Users/melee/Desktop/files/[붙임1]백남준 이후의 백남준_개요.hwp` | 다중 페이지, 실제 사용자 확인 문서 |

Stage 4에서는 필요하면 저장소 sample을 추가해 반복 측정 범위를 넓힌다.

## 다음 단계 변경 범위

Stage 2는 제품 코드를 바꾸지 않고 측정 helper를 추가하는 범위로 둔다.

필요 파일:

- `scripts/quicklook_pdf_renderer_compare.swift`
- `scripts/compare-quicklook-pdf-renderers.sh`
- `mydocs/working/task_m020_221_stage2.md`

Stage 2 helper는 현재 제품 helper를 직접 호출해 native bitmap PDF 기준선을 측정하고, 같은 입력에서 `RhwpDocument.renderPageSVG(at:)`를 순회해 core SVG 생성 비용을 측정한다.

## 검증

```bash
test -f /private/tmp/hwpql/HWPPreviewer/PreviewProvider.swift
test -f /private/tmp/hwpql/rhwp-ffi/src/lib.rs
git diff --check -- mydocs/plans/task_m020_221_impl.md mydocs/working/task_m020_221_stage1.md
```

결과:

- `test -f /private/tmp/hwpql/HWPPreviewer/PreviewProvider.swift`: 통과
- `test -f /private/tmp/hwpql/rhwp-ffi/src/lib.rs`: 통과
- `git diff --check`: 통과

## 변경 파일

- `mydocs/plans/task_m020_221_impl.md`
- `mydocs/working/task_m020_221_stage1.md`

## 잔여 위험

- Stage 1은 가능성 조사 단계라 실제 SVG 기반 PDF bytes 생성 가능성은 아직 검증하지 않았다.
- macOS 기본 API만으로 SVG를 PDF page에 vector로 넣을 수 있는지는 Stage 3에서 별도 판단해야 한다.
- hwpql의 HTML reply 성공 사례는 PDF reply UI 유지 가능성을 직접 증명하지 않는다.

## 다음 단계 영향

Stage 2는 native bitmap PDF와 core SVG 생성 비용을 같은 샘플에서 측정하는 helper 구현으로 진행한다. 이 결과가 있어야 Stage 3의 SVG -> PDF 후보가 실제로 빠를 가능성이 있는지 판단할 수 있다.

## 승인 요청

Stage 1 완료를 승인하면 Stage 2 native bitmap PDF와 core SVG 생성 측정 helper 작성으로 진행한다.
