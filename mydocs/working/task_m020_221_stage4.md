# Task #221 Stage 4 - SVG PDF 후보 성능과 안정성 비교

## 목적

Stage 2/3에서 확인한 현재 native bitmap PDF 경로와 `rhwp` core SVG 기반 PDF 후보를 반복 측정한다. 이번 단계의 판단 기준은 다음과 같다.

- Quick Look preview reply는 계속 PDF일 때를 기준으로 비교한다.
- `core SVG 생성`만 보지 않고 `core SVG 생성 + SVG->PDF 변환` end-to-end 시간을 본다.
- Quick Look preview와 thumbnail 결론을 분리한다.

## 추가 helper

Stage 4에서 Rust example helper를 추가했다.

- `RustBridge/examples/svg_pdf_benchmark.rs`
- `scripts/benchmark-quicklook-svg-pdf.sh`

이 helper는 `DocumentCore::from_bytes` -> `render_page_svg_native` -> `rhwp::renderer::pdf::svgs_to_pdf` 경로를 반복 측정한다. `RustBridge/examples` 아래에 두었기 때문에 일반 staticlib 빌드에는 포함되지 않고, 명시적으로 `cargo run --example svg_pdf_benchmark`를 호출할 때만 빌드된다.

## 측정 환경과 샘플

측정일: 2026-05-11

샘플:

| 파일 | 의도 | 페이지 | 현재 Quick Look reply |
| --- | --- | ---: | --- |
| `group-drawing-02.hwp` | 도형/그림 단일 페이지 | 1 | png |
| `eq-01.hwp` | 수식 단일 페이지 | 1 | png |
| `footnote-01.hwp` | 다중 페이지 텍스트/각주 | 6 | pdf |
| `hwp-img-001.hwp` | 이미지 포함 단일 페이지 | 1 | png |

명령:

```sh
./scripts/compare-quicklook-pdf-renderers.sh output/task221-stage4/native-run1 /Users/melee/Desktop/files/group-drawing-02.hwp /Users/melee/Desktop/files/eq-01.hwp /Users/melee/Desktop/files/footnote-01.hwp /Users/melee/Desktop/files/hwp-img-001.hwp
./scripts/compare-quicklook-pdf-renderers.sh output/task221-stage4/native-run2 /Users/melee/Desktop/files/group-drawing-02.hwp /Users/melee/Desktop/files/eq-01.hwp /Users/melee/Desktop/files/footnote-01.hwp /Users/melee/Desktop/files/hwp-img-001.hwp
./scripts/compare-quicklook-pdf-renderers.sh output/task221-stage4/native-run3 /Users/melee/Desktop/files/group-drawing-02.hwp /Users/melee/Desktop/files/eq-01.hwp /Users/melee/Desktop/files/footnote-01.hwp /Users/melee/Desktop/files/hwp-img-001.hwp
./scripts/benchmark-quicklook-svg-pdf.sh output/task221-stage4/svg-pdf --runs 3 /Users/melee/Desktop/files/group-drawing-02.hwp /Users/melee/Desktop/files/eq-01.hwp /Users/melee/Desktop/files/footnote-01.hwp /Users/melee/Desktop/files/hwp-img-001.hwp
```

SVG PDF 결과 PDF 검증:

```text
eq-01-run3-svg-core.pdf:            PDF document, version 1.7, 1 pages
footnote-01-run3-svg-core.pdf:      PDF document, version 1.7, 6 pages
group-drawing-02-run3-svg-core.pdf: PDF document, version 1.7, 1 pages
hwp-img-001-run3-svg-core.pdf:      PDF document, version 1.7, 1 pages
```

## 반복 측정 결과

| 파일 | 페이지 | 현재 reply | native PDF 평균 | native PDF min/max | native PDF bytes | core SVG 평균 | SVG PDF 평균 total | SVG->PDF 평균 | SVG PDF bytes | 결과 |
| --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| `group-drawing-02.hwp` | 1 | png | 1.152904s | 1.097467s / 1.194654s | 43,366 | 0.000382s | 0.065145s | 0.063123s | 10,455 | SVG PDF가 빠름 |
| `eq-01.hwp` | 1 | png | 0.031272s | 0.030356s / 0.032334s | 122,218 | 0.000564s | 0.105777s | 0.104558s | 51,454 | native가 빠름 |
| `footnote-01.hwp` | 6 | pdf | 0.145567s | 0.145041s / 0.145835s | 534,723 | 0.002873s | 0.269391s | 0.265776s | 283,715 | native가 빠름 |
| `hwp-img-001.hwp` | 1 | png | 0.036032s | 0.035205s / 0.036513s | 116,119 | 0.002399s | 0.120561s | 0.116845s | 167,679 | native가 빠름 |

성공률:

- native PDF 측정: 4개 샘플 x 3회 모두 OK
- core SVG 생성: 4개 샘플 x 3회 모두 OK
- SVG PDF 생성: 4개 샘플 x 3회 모두 OK
- 생성된 PDF page count: 선택한 run3 산출물 기준 모두 기대 페이지 수와 일치

## 해석

`rhwp` core SVG 생성은 매우 빠르다. 1페이지 샘플은 0.000382s~0.002399s, 6페이지 샘플도 0.002873s 수준이다. 병목은 SVG 생성이 아니라 `svg2pdf` 기반 SVG->PDF 변환이다.

`group-drawing-02.hwp`는 native bitmap PDF가 약 1.15초로 유난히 느려 SVG PDF가 크게 유리했다. 그러나 `eq-01.hwp`, `footnote-01.hwp`, `hwp-img-001.hwp`에서는 native bitmap PDF가 더 빨랐다. 따라서 현재 수치만으로 전체 Quick Look preview를 SVG PDF로 즉시 전환하는 것은 성능 관점에서 성급하다.

출력 크기는 SVG PDF가 대체로 작았지만 항상 그런 것은 아니었다. `hwp-img-001.hwp`는 SVG PDF가 native PDF보다 컸다. 이미지가 포함된 문서에서는 SVG/PDF 내부 이미지 보존 방식에 따라 파일 크기 이점이 사라질 수 있다.

## Visual risk

이번 단계는 PDF 생성 성공, 페이지 수, 크기, 시간 중심의 측정이다. 시각적 일치성은 아직 최종 판정하지 않았다.

다만 preview 품질 목표만 보면 SVG PDF 후보는 장점이 있다. Host app이 `rhwp` core 기반 viewer를 사용한다면 Quick Look preview도 같은 core SVG renderer를 쓰는 편이 장기적으로 일관성이 높다. 현재 native bitmap PDF 경로는 Swift native renderer라서 host app과 시각 차이가 생길 가능성이 구조적으로 남는다.

반대로 SVG PDF 경로도 무위험은 아니다. `rhwp::renderer::pdf`는 자체 폰트 fallback과 `usvg/svg2pdf` 변환을 거치므로, 실제 macOS Quick Look에서 한글 폰트, 이미지, 도형, 수식이 viewer와 완전히 같다는 보장은 별도 visual regression으로 확인해야 한다.

## Thumbnail 판단

Thumbnail은 SVG PDF 전환 대상에서 분리해야 한다.

- Thumbnail은 빠른 첫 화면 응답이 중요하다.
- 이번 측정에서 SVG->PDF 변환은 단순 단일 페이지도 평균 0.10초 이상인 샘플이 있었다.
- PDF를 만든 뒤 다시 thumbnail로 쓰는 흐름은 불필요하게 무겁다.
- Swift/ImageIO 기본 SVG rasterize는 Stage 3에서 안정 후보가 아니었다.

따라서 thumbnail은 현재 fast path를 유지하고, host app/preview와의 시각 일치가 필요하면 별도 이슈에서 `core SVG -> raster thumbnail` 전용 후보를 검토하는 편이 맞다.

## Stage 4 결론

SVG PDF 후보는 기능적으로 가능하고 12회 반복 측정에서 실패하지 않았다. Quick Look preview에서 PDF reply를 유지할 수 있다는 점도 확인됐다.

하지만 성능은 문서 유형별 편차가 크다. 현재 native bitmap PDF보다 항상 빠르지 않고, 4개 샘플 중 3개에서는 native가 더 빨랐다. 따라서 즉시 기본 경로를 SVG PDF로 교체하기보다, Stage 5에서 다음 선택지를 비교해 최종 판단하는 것이 적절하다.

1. 현재 native bitmap PDF 유지
2. Quick Look preview만 Rust FFI PDF API를 추가해 core SVG PDF로 전환
3. 특정 문서 유형 또는 fallback 조건에서만 SVG PDF 사용
4. Thumbnail은 별도 fast path 유지
