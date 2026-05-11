# Task #221 Stage 5 - Quick Look 렌더러 시각 비교

## 목적

Stage 4 성능 비교만으로는 전환 판단이 부족했다. 이번 단계에서는 현재 native bitmap renderer와 `rhwp` core SVG PDF 후보의 시각 차이를 같은 픽셀 크기의 PNG로 비교한다.

보정: 이 문서는 `SVG PDF 전환 후보` 비교 문서다. `native bitmap renderer가 rhwp-studio/core SVG 기준을 얼마나 따라잡았는지`에 대한 golden 비교는 Stage 6의 `core SVG WebKit` 비교를 기준으로 한다. Stage 5에는 SVG->PDF 변환과 PDF rasterize 차이가 섞인다.

비교 대상:

- 기준: 현재 Swift native renderer PNG
- 후보: `rhwp` core SVG -> `rhwp::renderer::pdf::svgs_to_pdf` -> PDF -> PNG rasterize

Host app의 WKWebView 화면은 이번 자동 비교에 포함하지 않았다. 화면 배율, WebView 상태, 앱 UI chrome이 섞이기 때문이다. 대신 Quick Look 산출물끼리 먼저 비교하고, host app 비교는 필요 시 수동 screenshot 기준으로 별도 진행한다.

## 추가 helper

추가 파일:

- `scripts/visual-compare-quicklook-renderers.sh`
- `scripts/visual_compare_quicklook_renderers.swift`

흐름:

1. `scripts/render-debug-compare.sh`로 native renderer PNG를 생성한다.
2. `scripts/benchmark-quicklook-svg-pdf.sh`로 core SVG PDF를 생성한다.
3. Swift helper가 PDF 선택 페이지를 ImageIO로 PNG rasterize한다.
4. 두 PNG를 같은 크기의 RGBA buffer로 맞춰 pixel diff를 생성한다.
5. `visual-summary-pageN.md`와 diff PNG를 출력한다.

초기에는 `CGPDFPage` 직접 렌더링을 사용했지만, 다중 페이지 PDF의 일부 page에서 위치가 어긋나는 결과가 나왔다. `sips` 출력과 대조한 뒤 ImageIO 기반 rasterize로 바꿨다. 최종 helper는 ImageIO 경로를 사용한다.

Diff 기준:

- RGB 채널 중 하나라도 12를 초과해 차이나는 픽셀을 changed pixel로 계산한다.
- 작은 antialias 차이도 텍스트 영역 전체에 누적될 수 있으므로, changed percent는 구조적 오차의 절대 지표가 아니라 탐색 지표로만 본다.

## 실행 명령

Page 1 대표 샘플:

```sh
./scripts/visual-compare-quicklook-renderers.sh output/task221-stage5-visual/page1-imageio --page 1 /Users/melee/Desktop/files/group-drawing-02.hwp /Users/melee/Desktop/files/eq-01.hwp /Users/melee/Desktop/files/footnote-01.hwp /Users/melee/Desktop/files/hwp-img-001.hwp
```

다중 페이지 샘플의 마지막 page:

```sh
./scripts/visual-compare-quicklook-renderers.sh output/task221-stage5-visual/footnote-page6-imageio --page 6 /Users/melee/Desktop/files/footnote-01.hwp
```

## 정량 결과

Page 1:

| 파일 | ChangedPercent | MeanRGBDelta | DiffBounds | 시각 판단 |
| --- | ---: | ---: | --- | --- |
| `group-drawing-02.hwp` | 4.2595% | 1.3739 | `113,132 459x263` | 전체 배치와 도형은 거의 일치. 선/텍스트 antialias 차이 중심 |
| `eq-01.hwp` | 6.5860% | 4.6715 | `93,132 627x572` | 수식과 본문 배치는 대체로 일치. 글자 굵기/antialias 차이 큼 |
| `footnote-01.hwp` | 8.1387% | 6.1177 | `75,97 645x974` | 문서 구조는 일치. 텍스트 raster 품질과 하단 각주/페이지 번호 차이 |
| `hwp-img-001.hwp` | 7.3482% | 5.3590 | `94,99 603x659` | 이미지/본문 배치는 대체로 일치. 이미지와 글자 edge 차이 |

`footnote-01.hwp` page 6:

| 파일 | ChangedPercent | MeanRGBDelta | DiffBounds | 시각 판단 |
| --- | ---: | ---: | --- | --- |
| `footnote-01.hwp` page 6 | 0.0085% | 0.0078 | `388,1062 17x9` | 거의 동일. page number 주변만 차이 |

## 관찰

`group-drawing-02.hwp`는 성능에서도 SVG PDF가 유리했고, 시각 비교에서도 도형 구조가 잘 맞았다. 선 두께와 텍스트 antialias 차이가 주된 diff다.

`eq-01.hwp`와 `hwp-img-001.hwp`는 Stage 4에서 native bitmap PDF가 더 빨랐지만, 시각적으로 SVG PDF 후보가 심각하게 깨지는 양상은 보이지 않았다. 다만 수식/글자 edge가 native와 다르게 rasterize되어 diff 수치가 커졌다.

`footnote-01.hwp` page 1은 diff 수치가 가장 높았다. 화면으로 보면 큰 구조는 맞지만 글자가 native보다 부드럽고, 각주/하단 영역에서 차이가 누적된다. page 6처럼 내용이 거의 없는 page는 거의 동일하므로, 차이는 주로 텍스트가 많은 영역에서 발생한다.

이번 비교에서 SVG PDF 후보는 Stage 3 초기에 우려했던 “PDF 생성 후 내용이 깨지는” 상태는 아니었다. 최종 ImageIO rasterize 기준으로 텍스트와 도형은 정상 표시된다. 다만 native renderer와 완전히 같은 픽셀 결과는 아니며, 텍스트 antialias, font fallback, 일부 line metric 차이가 남는다.

## 판단

시각 품질만 보면 SVG PDF 후보는 계속 검토할 가치가 있다. Host app이 `rhwp` core 기반 화면을 사용한다면, Quick Look preview도 core SVG/PDF 경로로 맞추는 편이 장기적으로 일관성 면에서 유리하다.

하지만 이번 결과만으로 바로 기본 경로를 교체하기에는 부족하다.

- Stage 4에서 4개 샘플 중 3개는 native bitmap PDF가 더 빨랐다.
- Stage 5에서 SVG PDF가 대체로 정상 표시되지만 pixel diff는 텍스트 많은 문서에서 8% 수준까지 올라갔다.
- 실제 Quick Look 창에서 PDF vector가 표시되는 품질은 ImageIO rasterize와 다를 수 있으므로, 앱/Quick Look 실제 화면 smoke가 추가로 필요하다.

현재 권장안은 다음과 같다.

1. v0.1.1 재배포 버그 수정 범위에는 SVG PDF 전환을 넣지 않는다.
2. v0.2 후속에서 `RhwpCoreBridge`에 core SVG PDF FFI를 추가하는 spike를 이어간다.
3. 전환 전에는 실제 Quick Look UI screenshot 기준의 visual regression을 추가한다.
4. Thumbnail은 이번 후보와 분리하고 현재 fast path를 유지한다.
