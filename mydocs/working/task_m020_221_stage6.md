# Task #221 Stage 6 - Native renderer와 core SVG WebKit 기준 비교

## 배경

Stage 5 비교는 `native bitmap renderer`와 `rhwp core SVG -> PDF -> PNG`를 비교했다. 이 비교는 SVG PDF 후보의 시각 품질을 판단하는 데는 의미가 있지만, `native renderer가 rhwp-studio/core SVG 기준을 얼마나 따라잡았는지`를 평가하기에는 부정확하다. 중간에 `svg2pdf`와 PDF rasterize 차이가 섞이기 때문이다.

이번 단계에서는 기준을 바로잡아 다음 경로를 비교했다.

- 기준: `rhwp core SVG`를 WebKit으로 직접 rasterize한 PNG
- 비교 대상: 현재 Swift native bitmap renderer PNG

이 경로가 rhwp-studio의 SVG 표시 결과에 가장 가깝다.

## 추가 helper

추가 파일:

- `scripts/visual-compare-core-svg-webkit.sh`
- `scripts/visual_compare_core_svg_webkit.swift`

흐름:

1. `scripts/render-debug-compare.sh`로 native PNG와 core SVG를 생성한다.
2. Swift helper가 core SVG를 `WKWebView`에 로드한다.
3. `WKWebView.takeSnapshot`으로 같은 크기의 PNG를 생성한다.
4. native PNG와 core SVG WebKit PNG를 pixel diff한다.

주의:

- `WKWebView` snapshot은 Codex sandbox 안에서 WebKit 캐시/서비스 접근 제한으로 timeout이 발생했다.
- 최종 측정은 sandbox 밖 실행 승인 후 수행했다.
- 이 helper는 제품 코드가 아니라 비교/검증용 스크립트다.

## 실행 명령

Page 1 대표 샘플:

```sh
./scripts/visual-compare-core-svg-webkit.sh output/task221-stage6-core-svg-webkit/page1-final --page 1 /Users/melee/Desktop/files/group-drawing-02.hwp /Users/melee/Desktop/files/eq-01.hwp /Users/melee/Desktop/files/footnote-01.hwp /Users/melee/Desktop/files/hwp-img-001.hwp
```

다중 페이지 샘플의 마지막 page:

```sh
./scripts/visual-compare-core-svg-webkit.sh output/task221-stage6-core-svg-webkit/footnote-page6-final --page 6 /Users/melee/Desktop/files/footnote-01.hwp
```

## 정량 결과

Page 1:

| 파일 | ChangedPercent | MeanRGBDelta | DiffBounds | 판단 |
| --- | ---: | ---: | --- | --- |
| `group-drawing-02.hwp` | 4.3279% | 1.6946 | `113,132 459x263` | 구조/도형 배치는 잘 맞음. 선과 텍스트 edge 차이 중심 |
| `eq-01.hwp` | 5.4923% | 3.4568 | `93,132 627x571` | 수식 배치는 맞음. 수식/텍스트 antialias와 굵기 차이 |
| `footnote-01.hwp` | 6.1123% | 4.4549 | `75,98 645x973` | 문서 구조는 맞음. 텍스트 굵기/antialias 차이 누적 |
| `hwp-img-001.hwp` | 6.7736% | 5.6127 | `94,99 603x658` | 이미지/본문 배치는 맞음. 이미지 edge와 텍스트 차이 |

`footnote-01.hwp` page 6:

| 파일 | ChangedPercent | MeanRGBDelta | DiffBounds | 판단 |
| --- | ---: | ---: | --- | --- |
| `footnote-01.hwp` page 6 | 0.0073% | 0.0058 | `388,1062 17x9` | 거의 동일. 페이지 번호 근처만 차이 |

## Stage 5와의 차이

Stage 5의 `SVG PDF` 후보 비교보다 Stage 6의 `core SVG WebKit` 비교가 native renderer catch-up 평가에 더 적합하다.

대표적으로 `footnote-01.hwp` page 1은 Stage 5에서 8.1387%였지만, Stage 6 기준에서는 6.1123%로 낮아졌다. Stage 5 수치에는 SVG->PDF 변환과 PDF rasterize 차이가 포함됐고, Stage 6은 core SVG 자체를 WebKit으로 렌더링했기 때문이다.

## 시각 판단

native renderer는 core SVG WebKit 기준을 구조적으로는 꽤 따라잡았다.

- 페이지 배치, 표/도형 위치, 주요 텍스트 흐름은 대체로 일치한다.
- 수식 샘플도 큰 구조 붕괴 없이 표시된다.
- 이미지 샘플도 이미지 위치와 크기가 크게 어긋나지 않는다.

남은 차이는 주로 다음 영역이다.

- WebKit과 CoreGraphics의 text antialias 차이
- font weight와 glyph metric 차이
- 굵은 글자와 수식 영역의 edge 차이
- 이미지 scaling/interpolation edge 차이

즉, 현재 native renderer가 “기능이 적어서 빠른데 많이 깨지는” 상태는 아니다. 다만 core SVG/WebKit과 pixel-level로 동일한 renderer도 아니다.

## 결론

사용자 경험 기준으로 host app과 Quick Look의 시각 일치를 최우선으로 두면, 장기적으로는 Quick Look preview를 core SVG 기반으로 맞추는 방향이 타당하다.

하지만 현재 native renderer도 core SVG 기준을 상당히 따라잡았고, Stage 4에서 native bitmap PDF가 더 빠른 샘플이 많았다. 따라서 v0.1.1 재배포 수정 범위에서는 Quick Look extension 등록/업데이트 문제를 우선 해결하고, SVG PDF 전환은 v0.2 후속 작업으로 유지하는 것이 맞다.

후속 작업 기준:

1. native renderer 유지: 단기 안정성과 속도 우선
2. core SVG PDF 전환: host app과 Quick Look preview 일치성 우선
3. 전환 전 필수 검증: 실제 Quick Look UI screenshot, WebKit golden diff, 다중 샘플 visual regression
4. thumbnail: 여전히 별도 fast path 유지
