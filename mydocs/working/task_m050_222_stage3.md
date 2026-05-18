# Task M050 #222 Stage 3 완료보고서

## 단계 목표

Stage 2의 `BehindText` page-level image pass가 실제 샘플 렌더링에서 동작하는지 확인하고, `복학원서.hwp`의 남은 시각 차이를 z-order 문제와 이미지 effect parity 문제로 분리한다.

## 검증 대상

- `samples/복학원서.hwp`
- `samples/hwp-img-001.hwp`

## 실행 명령

```bash
./scripts/render-debug-compare.sh /private/tmp/rhwp-bokhak-watermark-task222 --page 1 samples/복학원서.hwp
./scripts/render-debug-compare.sh /private/tmp/rhwp-task222-image-smoke --page 1 samples/hwp-img-001.hwp
./scripts/check-no-appkit.sh
```

## `복학원서.hwp` 결과

산출물:

- render tree: `/private/tmp/rhwp-bokhak-watermark-task222/복학원서-page1-render-tree.json`
- native PNG: `/private/tmp/rhwp-bokhak-watermark-task222/복학원서-page1-native.png`
- summary: `/private/tmp/rhwp-bokhak-watermark-task222/복학원서-page1-summary.txt`

요약:

| 항목 | 값 |
|------|----|
| PageCount | 1 |
| PageSizePt | 793.7x1122.5 |
| RenderTreeJSONBytes | 189322 |
| CoreSVGBytes | 414839 |
| NativePNGSize | 794x1123 |
| NativeNonWhitePixels | 275116 |
| TextRuns | 102 |
| HangulRuns | 25 |
| MissingHangulGlyphs | 0 |

render tree의 page top-level 순서는 기존과 같이 `PageBackground -> Header -> Body -> Image(id 84) -> Ellipse -> Footer`이며, id 84 중앙 워터마크는 `text_wrap: "BehindText"`다. Stage 2 이후 Swift renderer는 이 top-level `BehindText` 이미지를 body pass 전에 그린다.

생성된 native PNG를 확인한 결과, body/table/text pass는 워터마크 이후에 실행되는 상태로 정렬됐다. 다만 현재 앱 경로는 `GrayScale`, `brightness`, `contrast` image effect를 아직 rhwp-studio 최신 수준으로 반영하지 않으므로, 검은 워터마크 위의 검은 본문 텍스트는 시각적으로 여전히 잘 구분되지 않는다. 이 잔여 현상은 이번 stage의 z-order 수정 범위가 아니라 upstream rhwp 갱신 후 반영할 이미지 effect parity 문제로 분리한다.

기존 layout overflow 진단은 동일하게 출력됐다.

```text
LAYOUT_OVERFLOW: page=0, col=0, para=16, type=PartialParagraph, y=1087.2, bottom=1084.7, overflow=2.5px
LAYOUT_OVERFLOW: page=0, col=0, para=16, type=Shape, y=1087.2, bottom=1084.7, overflow=2.5px
```

이 overflow는 하단 안내 문구 주변의 기존 진단이며 중앙 워터마크 z-order와 별개다.

## 이미지 포함 샘플 smoke

`samples/hwp-img-001.hwp`도 같은 helper로 render smoke를 실행했다.

산출물:

- render tree: `/private/tmp/rhwp-task222-image-smoke/hwp-img-001-page1-render-tree.json`
- native PNG: `/private/tmp/rhwp-task222-image-smoke/hwp-img-001-page1-native.png`
- summary: `/private/tmp/rhwp-task222-image-smoke/hwp-img-001-page1-summary.txt`

요약:

| 항목 | 값 |
|------|----|
| PageCount | 1 |
| RenderTreeJSONBytes | 115988 |
| CoreSVGBytes | 300633 |
| NativePNGSize | 794x1123 |
| NativeNonWhitePixels | 58483 |
| TextRuns | 66 |
| HangulRuns | 35 |
| MissingHangulGlyphs | 0 |
| Image nodes | 4 |

이 샘플의 이미지 `text_wrap` 값은 `TopAndBottom`, `Square`이며 `BehindText`가 아니다. Stage 2의 pass 조건에 걸리지 않으므로 기존 렌더 순서를 유지한다. helper는 정상 종료했다.

## qlmanage diff 상태

두 render-debug-compare 실행 모두 core SVG raster PNG와 diff PNG는 생성되지 않았다.

- `복학원서.hwp`: `qlmanage rasterize failed`
- `hwp-img-001.hwp`: `qlmanage rasterize failed`

native PNG와 summary 생성은 성공했으므로 Stage 3 smoke 판단에는 영향을 주지 않는다.

## 판단

- Stage 2의 `text_wrap` 디코딩과 top-level `BehindText` image pass는 `복학원서.hwp` 재현 조건에 적용된다.
- 일반 이미지 샘플의 non-`BehindText` 이미지는 새 pass 대상에서 제외되어 기존 순서를 유지한다.
- 사용자가 제외한 흑백/GrayScale/effect parity가 아직 남아 있어, 최종 시각 결과는 rhwp-studio 최신 화면과 완전히 같지 않다.

## 다음 단계

Stage 4에서 최종 보고서를 작성하고 오늘할일 상태를 완료로 갱신한다.
