# v0.1.4 preview visual diff harness

## 목적

이 문서는 v0.1.4 Native Preview/Viewer Parity 작업에서 `rhwp-studio` 기본 렌더와 native preview renderer 출력을 같은 입력/page 단위로 비교하는 방법을 정리한다.

이 harness의 1차 목적은 후속 렌더 개선 이슈가 전후 수치를 같은 형식으로 남기게 하는 것이다. `changedPixels`나 `changedPercent`는 release hard gate가 아니라 관찰 지표다.

## 기본 실행

기본 정책은 현재 native preview 기준선인 `coreGraphicsOnly`다.

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task280-stage4 --page 1 \
  samples/basic/request.hwp \
  samples/복학원서.hwp \
  samples/pic-crop-01.hwp \
  samples/form-01.hwp \
  samples/hwpx/form-002.hwpx \
  samples/hwpx/hwpx-01.hwpx
```

Skia optional backend를 비교할 때만 `--policy skiaOptIn`을 명시한다.

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task280-skia-check --page 1 \
  --policy skiaOptIn samples/basic/request.hwp
```

CLI 옵션:

| 옵션 | 기본값 | 의미 |
|---|---|---|
| `--page N` | `1` | 1-based page 번호 |
| `--policy coreGraphicsOnly|skiaOptIn` | `coreGraphicsOnly` | native renderer backend policy |
| `--viewport WIDTHxHEIGHT` | `1400x1800` | `rhwp-studio` WKWebView viewport |
| `--settle-ms N` | `120` | Studio load 후 추가 settle 시간 |
| `--resource-dir DIR` | `Sources/HostApp/Resources/rhwp-studio` | bundled Studio resource directory |

## 산출물

```text
<output-dir>/
  studio/
    {file}-page{N}-studio.png
    {file}-page{N}-studio.json
  native/
    {file}-page{N}-native.png
    {file}-page{N}-native.json
  diff/
    {file}-page{N}-diff.png
  summary.md
```

주요 파일:

| 파일 | 용도 |
|---|---|
| `summary.md` | 샘플별 Studio/native/diff 요약표 |
| `studio/*.png` | `rhwp-studio` 기준 reference PNG |
| `studio/*.json` | Studio provenance, capture mode, overlay metadata |
| `native/*.png` | `HwpPageImageRenderer` native preview PNG |
| `native/*.json` | native backend, fallback, size, timing metadata |
| `diff/*.png` | threshold 12 기준 pixel diff visualization |

## 수치 해석 기준

summary 주요 필드:

| 필드 | 의미 |
|---|---|
| `StudioSize` | Studio reference PNG 크기 |
| `NativeSize` | native renderer 원본 PNG 크기 |
| `CompareSize` | diff 계산 크기. 현재 Studio reference 크기와 같다 |
| `ChangedPixels` | threshold 12를 넘은 pixel 수와 전체 pixel 수 |
| `ChangedPercent` | `ChangedPixels / totalPixels * 100` |
| `MeanRGBDelta` | 전체 RGB 채널 평균 차이 |
| `MaxRGBDelta` | 가장 큰 채널 차이 |
| `DiffBounds` | 차이가 발생한 bounding box |
| `StudioCapture` | 현재 `canvasDataURL` |
| `NativeBackend` | `coreGraphics`, `skia`, 또는 fallback reason 포함 |
| `NativeMs` | native render duration |

현재 Studio reference는 device scale 2에 가까운 canvas backing store 크기로 생성되고, native CoreGraphics output은 page point 기준 scale 1 PNG로 생성된다. 따라서 diff는 native output을 Studio reference 크기에 맞춰 확대해 계산한다.

이 때문에 수치가 다음 요인의 영향을 받을 수 있다.

- scale 차이로 인한 antialiasing 차이
- Studio canvas와 CoreGraphics/CoreText text shaping 차이
- canvas 내부 editor guide 또는 margin guide 잔류
- DOM overlay가 reference PNG에 포함되지 않는 한계

결론을 쓸 때는 `ChangedPercent` 하나만 보지 말고 `DiffBounds`, `MeanRGBDelta`, 원본 `studio/native/diff` PNG를 같이 확인한다.

## editor chrome과 margin guide

Finder Quick Look/Thumbnail parity 기준에서 menu, toolbar, status bar, ruler, selection/caret 같은 editor chrome은 비교 대상에서 제외한다.

Stage 2-3 helper는 DOM chrome을 숨기고 Studio page canvas를 capture한다. 다만 현재 reference PNG는 `WKWebView.takeSnapshot`이 canvas 내용을 안정적으로 잡지 못해 `canvasDataURL` 기반으로 저장한다.

현재 한계:

- `captureMode=canvasDataURL`
- `overlayIncluded=false`
- DOM overlay는 PNG에 포함하지 않고 `studio/*.json`의 `overlayCount`와 `overlayIncluded`로 기록한다.
- canvas 내부 margin guide, crop mark, editor guide는 PNG에 남을 수 있다.

따라서 #282 이전에는 overlay가 빠진 차이를 native compositor 회귀로 단정하지 않는다. #282는 이 한계를 줄이기 위해 PageLayerTree overlay metadata와 native compositor 순서를 맞추는 작업이다.

## 기본 sample set

v0.1.4 렌더 개선 이슈의 공통 smoke는 다음 6개를 기본으로 둔다.

| 목적 | 샘플 | 주요 확인 포인트 |
|---|---|---|
| 일반 HWP smoke | `samples/basic/request.hwp` | 표, 이미지 로고, 붉은 텍스트, 기본 flow |
| watermark/effect | `samples/복학원서.hwp` | JPEG watermark/effect, 투명키, 큰 form layout |
| image crop/fill | `samples/pic-crop-01.hwp` | 이미지 crop, clip, 배치 |
| form/placeholder HWP | `samples/form-01.hwp` | form placeholder, 정적 form object |
| form/placeholder HWPX | `samples/hwpx/form-002.hwpx` | HWPX form/static preview |
| HWPX smoke | `samples/hwpx/hwpx-01.hwpx` | HWPX multi-page open/render smoke |

Stage 4 기준 smoke 결과:

| 파일 | ChangedPercent | MeanRGBDelta | NativeBackend | NativeMs |
|---|---:|---:|---|---:|
| `request.hwp` | `18.1021%` | `11.5796` | `coreGraphics` | `1049.1ms` |
| `복학원서.hwp` | `32.3726%` | `42.9398` | `coreGraphics` | `415.3ms` |
| `pic-crop-01.hwp` | `2.0423%` | `0.8092` | `coreGraphics` | `6.7ms` |
| `form-01.hwp` | `0.8066%` | `0.4845` | `coreGraphics` | `2.2ms` |
| `form-002.hwpx` | `16.8925%` | `17.6456` | `coreGraphics` | `35.5ms` |
| `hwpx-01.hwpx` | `15.1839%` | `15.6722` | `coreGraphics` | `29.0ms` |

Stage 4 smoke 산출물 위치:

```text
build.noindex/task280-stage4/
```

## 확장 sample set

작업 범위가 맞을 때만 추가 실행한다.

| 목적 | 샘플 |
|---|---|
| image/table anchored content | `samples/tac-img-02.hwp`, `samples/tac-img-02.hwpx` |
| equation | `samples/eq-01.hwp` |
| grouped drawing | `samples/draw-group.hwp` |
| table vertical positioning | `samples/table-vpos-01.hwp` |

## 후속 이슈 handoff

### #282 Quick Look/Thumbnail native compositor

추천 샘플:

- `samples/basic/request.hwp`
- `samples/복학원서.hwp`
- `samples/tac-img-02.hwp`
- `samples/tac-img-02.hwpx`

확인할 항목:

- `StudioCapture=canvasDataURL`, `overlayIncluded=false` 한계를 PR에 명시한다.
- `studio/*.json`의 `overlayCount`를 확인해 DOM overlay 후보가 있는 샘플을 우선 본다.
- native compositor 순서가 background, BehindText overlay, flow, InFrontOfText overlay에 가까워졌는지 diff bounds와 PNG로 확인한다.

### #116 복학원서 JPEG watermark/effect

추천 샘플:

- `samples/복학원서.hwp`
- 필요 시 `samples/20250130-hongbo.hwp`, `samples/aift.hwp`

확인할 항목:

- watermark/effect 보정 전후의 `ChangedPercent`, `MeanRGBDelta`, `DiffBounds`
- 붉은 도장/워터마크 주변 diff가 줄었는지 PNG로 확인
- canvas 내부 margin guide residual과 실제 image effect 차이를 구분

### #122 image fill mode/tile/placement

추천 샘플:

- `samples/pic-crop-01.hwp`
- `samples/tac-img-02.hwp`
- `samples/tac-img-02.hwpx`

확인할 항목:

- image crop/fill 영역의 `DiffBounds`
- tile/placement 변경 전후 `ChangedPercent`
- native `*.json`의 backend/fallback이 바뀌지 않았는지 확인

### #121 RawSvg/OLE/chart resource

추천 샘플:

- `samples/draw-group.hwp`
- `samples/eq-01.hwp`
- 이슈 작업 중 확인한 RawSvg/OLE/chart 전용 샘플

확인할 항목:

- 새 resource 렌더링 영역의 diff가 줄었는지 확인
- resource 미지원 상태와 layout/scale 차이를 분리해 기록

### #110 Placeholder/FormObject static preview

추천 샘플:

- `samples/form-01.hwp`
- `samples/hwpx/form-002.hwpx`

확인할 항목:

- placeholder/form object 영역의 `DiffBounds`
- 정적 preview 보강 전후 `ChangedPercent`
- HWP와 HWPX 모두에서 같은 방향으로 개선되는지 확인

## 보고서 기록 기준

후속 PR/단계 보고서에는 최소 다음을 남긴다.

- 실행 명령
- input sample set
- `summary.md` 전체 또는 관련 row
- `StudioCapture`, `overlayIncluded`, `NativeBackend`, fallback reason
- 변경 전후 `ChangedPercent`, `MeanRGBDelta`, `DiffBounds`
- 시각 확인한 `studio/native/diff` PNG 위치
- hard gate가 아닌 관찰 지표라는 해석

현재 harness는 반복 측정 도구다. 렌더 개선의 성공 여부는 수치, diff bounds, 실제 PNG 확인, 해당 이슈의 책임 범위를 함께 보고 판단한다.
