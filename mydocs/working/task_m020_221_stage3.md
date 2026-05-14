# Task #221 Stage 3 - SVG 기반 PDF 후보 가능성 검증

## 목적

Quick Look preview를 `public.png`/native bitmap PDF가 아니라 `rhwp` core SVG 기반 PDF로 생성할 수 있는지 검증한다. 목표는 다음 두 가지다.

- Quick Look preview reply는 계속 `public.pdf`로 유지해 우측 파일/페이지 정보 UI를 보존한다.
- WebView/WKWebView를 Quick Look extension 안에 넣지 않고, 동기적이고 예측 가능한 변환 경로를 찾는다.

## 확인한 후보

### Swift/macOS 기본 SVG 처리

`ImageIO`의 `CGImageSourceCreateWithData`로 `rhwp` SVG를 확인했다.

```text
source=true type=nil count=0 image=false
```

즉, 현재 macOS 기본 ImageIO 경로만으로는 `rhwp` SVG를 PDF에 그릴 수 있는 `CGImage`를 안정적으로 얻지 못한다. 설령 일부 SVG를 rasterize할 수 있어도 이 방식은 vector PDF가 아니라 bitmap을 다시 PDF에 넣는 경로가 되므로, viewer와 Quick Look의 표현 일치를 달성하는 후보로 보기 어렵다.

`qlmanage`를 이용한 SVG rasterize도 현재 환경에서는 실패했다.

```text
sandbox initialization failed: invalid data type of path filter; expected pattern, got boolean
```

이 경로는 개발/CI/사용자 환경에 따라 Quick Look provider와 sandbox 상태의 영향을 받으므로 제품 기능의 내부 변환 경로로 쓰기 어렵다.

### WebView 기반 SVG -> PDF

Quick Look extension 내부에서 WebView/WKWebView로 SVG를 로드한 뒤 PDF화하는 방식은 이번 후보에서 제외한다.

- Quick Look extension은 짧은 시간 안에 preview/thumbnail을 반환해야 하며, WebView 초기화 비용과 프로세스/샌드박스 상태 의존성이 크다.
- HTML/SVG 렌더링 결과를 PDF로 다시 캡처하는 경로는 비동기 상태와 폰트 로딩 타이밍에 취약하다.
- hwpql 저장소의 HTML reply 방식은 Quick Look 우측 페이지 정보 UI 보존 목표와 맞지 않는다.

### Rust core `rhwp::renderer::pdf`

현재 고정된 `rhwp` v0.7.10에는 이미 SVG renderer 결과를 PDF로 변환하는 네이티브 Rust 경로가 있다.

- `rhwp::renderer::pdf::svg_to_pdf`
- `rhwp::renderer::pdf::svgs_to_pdf`

구현은 `usvg`, `svg2pdf`, `pdf-writer`를 사용한다. 시스템 폰트를 로드하고 일부 한글 폰트 fallback을 붙인 뒤, 단일/다중 페이지 PDF를 생성한다.

## 임시 spike 결과

제품 코드에 남기지 않는 임시 Rust bin으로 다음 흐름을 검증했다.

1. `DocumentCore::from_bytes`
2. `DocumentCore::render_page_svg_native`
3. `rhwp::renderer::pdf::svgs_to_pdf`
4. PDF 파일 저장

명령:

```sh
cargo run --manifest-path RustBridge/Cargo.toml --release --bin rhwp_svg_pdf_spike -- output/task221-stage3 /Users/melee/Desktop/files/group-drawing-02.hwp /Users/melee/Desktop/files/footnote-01.hwp
```

결과:

| 파일 | 페이지 | open | SVG 생성 | SVG->PDF | PDF 크기 | PDF 검증 |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| `group-drawing-02.hwp` | 1 | 0.001461s | 0.000481s | 0.309142s | 10,455 bytes | PDF 1.7, 1 page |
| `footnote-01.hwp` | 6 | 0.000621s | 0.002773s | 0.447914s | 283,715 bytes | PDF 1.7, 6 pages |

PDF 파일 자체는 macOS `file` 명령에서 각각 1페이지, 6페이지 PDF로 확인됐다.

## Stage 2 현재 경로와의 단순 비교

Stage 2에서 같은 샘플의 현재 native bitmap PDF 생성 시간은 다음과 같았다.

| 파일 | 현재 reply | NativePDFSeconds | NativePDFBytes | CoreSVGSeconds |
| --- | --- | ---: | ---: | ---: |
| `group-drawing-02.hwp` | png | 1.116109s | 43,366 bytes | 0.000376s |
| `footnote-01.hwp` | pdf | 0.149368s | 534,723 bytes | 0.002855s |

Stage 3의 core SVG PDF는 단일 페이지 샘플에서는 현재 native PDF보다 빠르고 작았다. 다만 6페이지 샘플에서는 `svgs_to_pdf` 변환이 0.447914초로, Stage 2의 native bitmap PDF 0.149368초보다 느렸다. 따라서 “core SVG 기반 PDF가 항상 더 빠르다”는 결론은 아직 낼 수 없다.

## 판단

구현 후보로는 Swift/macOS 기본 SVG 처리나 WebView가 아니라 Rust core FFI 확장이 가장 타당하다.

- 장점: viewer와 같은 core SVG renderer를 사용하므로 시각적 일치 가능성이 가장 높다.
- 장점: PDF reply를 유지할 수 있어 Quick Look의 파일 정보/페이지 정보 UI 목표와 맞다.
- 장점: 제품 extension 안에서 WebView를 띄우지 않아 초기화와 비동기 위험이 작다.
- 단점: 현재 `RhwpCoreBridge` FFI에는 PDF bytes 반환 API가 없으므로 ABI를 확장해야 한다.
- 단점: `svgs_to_pdf`가 페이지마다 시스템 폰트 DB와 SVG parse/conversion 비용을 가진다. 다중 페이지 문서에서는 현재 native bitmap PDF보다 느릴 수 있다.
- 단점: SVG->PDF 경로의 폰트 fallback과 glyph coverage가 실제 사용자 문서에서 충분한지 별도 시각 회귀가 필요하다.

## 다음 단계 기준

Stage 4에서는 같은 샘플과 문제 재현 샘플에 대해 반복 측정을 수행한다.

- cold/warm 실행을 나눠 단일 실행 오차를 줄인다.
- 단일 페이지, 다중 페이지, 이미지/도형 포함 문서를 분리한다.
- SVG 생성 시간과 SVG->PDF 변환 시간을 합산한 end-to-end 시간을 기준으로 현재 native bitmap PDF와 비교한다.
- 안정성 판단은 성공률, 페이지 수, PDF 크기, 변환 실패 여부를 함께 본다.
