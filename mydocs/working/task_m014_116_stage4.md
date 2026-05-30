# Task M014 #116 Stage 4 보고서

## 단계 목적

Stage 3의 `bakedWatermark=true` resolved overlay adjustment skip이 실제로 `복학원서.hwp` native preview를 rhwp-studio 기준에 가깝게 만드는지 수치와 PNG artifact로 확인했다. 또한 기존 image sample set의 visual diff가 변하지 않는지 회귀 smoke를 수행했다.

## 검증 기준

- 기준 core: rhwp `v0.7.13`
- NativePolicy: `coreGraphicsOnly`
- StudioReleaseTag: `v0.7.13`
- StudioResolvedCommit: `b3e16ef212af81ef37d973ddb86d6816d3804642`
- Viewport: `1400x1800`
- SettleMs: `120`
- DiffPixelThreshold: `12`

## `복학원서.hwp` visual diff

명령:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task116-after-baked-gate --page 1 \
  samples/복학원서.hwp
```

결과:

| File | ChangedPixels | ChangedPercent | MeanRGBDelta | MaxRGBDelta | DiffBounds | StudioCapture | NativeBackend | NativeMs |
|------|--------------:|---------------:|-------------:|------------:|------------|---------------|---------------|---------:|
| `복학원서.hwp` | 279470/3562815 | 7.8441% | 6.9643 | 255 | 83,45 1436x2155 | `domComposite` | `coreGraphics` | 1038.8 |

Stage 1 baseline 대비:

| Metric | Stage 1 baseline | Stage 4 after gate | 변화 |
|--------|-----------------:|-------------------:|-----:|
| ChangedPixels | 1140771/3562815 | 279470/3562815 | -861301 |
| ChangedPercent | 32.0188% | 7.8441% | -24.1747%p |
| MeanRGBDelta | 18.2116 | 6.9643 | -11.2473 |
| NativeMs | 1168.1 | 1038.8 | -129.3ms |

해석:

- ChangedPercent가 32.0188%에서 7.8441%로 줄어 약 75.5%의 changed pixel 감소가 있었다.
- MeanRGBDelta도 18.2116에서 6.9643으로 줄어 watermark 중복 보정 제거가 실제 reference parity를 크게 개선했다.
- NativeMs 감소는 단일 smoke 관찰값이며 성능 개선 결론으로 보지 않는다.

Artifact:

- Studio PNG: `build.noindex/task116-after-baked-gate/studio/복학원서.hwp-page1-studio.png`
- Native PNG: `build.noindex/task116-after-baked-gate/native/복학원서.hwp-page1-native.png`
- Diff PNG: `build.noindex/task116-after-baked-gate/diff/복학원서.hwp-page1-diff.png`

시각 관찰:

- Stage 1 native output에서 두드러졌던 중앙 watermark의 과도한 어두움과 회색 사각형 노출이 크게 줄었다.
- Stage 4 native output은 rhwp-studio reference의 watermark 톤에 훨씬 가까워졌다.
- 남은 차이는 주로 native text/font/layout, 일부 glyph fallback, 하단 clipping/overflow 등 기존 renderer parity 문제로 보인다.

## Regression visual diff

명령:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task116-regression --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx \
  samples/tac-img-02.hwp samples/tac-img-02.hwpx \
  samples/hwp-img-001.hwp samples/img-start-001.hwp
```

결과:

| Sample | ChangedPercent | MeanRGBDelta | StudioCapture | NativeBackend | NativeMs |
|--------|---------------:|-------------:|---------------|---------------|---------:|
| `request.hwp` | 17.8542% | 11.0716 | domComposite | coreGraphics | 985.3 |
| `hwpx-01.hwpx` | 15.0285% | 15.2088 | domComposite | coreGraphics | 35.6 |
| `tac-img-02.hwp` | 4.1153% | 3.6698 | canvasDataURL | coreGraphics | 7.9 |
| `tac-img-02.hwpx` | 4.1153% | 3.6698 | domComposite | coreGraphics | 4.2 |
| `hwp-img-001.hwp` | 7.8277% | 8.1872 | domComposite | coreGraphics | 15.0 |
| `img-start-001.hwp` | 13.9805% | 13.9111 | domComposite | coreGraphics | 28.3 |

Stage 1 regression baseline과 비교:

| Sample | Stage 1 ChangedPercent | Stage 4 ChangedPercent | Stage 1 MeanRGBDelta | Stage 4 MeanRGBDelta | 판단 |
|--------|-----------------------:|-----------------------:|---------------------:|---------------------:|------|
| `request.hwp` | 17.8542% | 17.8542% | 11.0716 | 11.0716 | 변화 없음 |
| `hwpx-01.hwpx` | 15.0285% | 15.0285% | 15.2088 | 15.2088 | 변화 없음 |
| `tac-img-02.hwp` | 4.1153% | 4.1153% | 3.6698 | 3.6698 | 변화 없음 |
| `tac-img-02.hwpx` | 4.1153% | 4.1153% | 3.6698 | 3.6698 | 변화 없음 |
| `hwp-img-001.hwp` | 7.8277% | 7.8277% | 8.1872 | 8.1872 | 변화 없음 |
| `img-start-001.hwp` | 13.9805% | 13.9805% | 13.9111 | 13.9111 | 변화 없음 |

해석:

- 기존 sample set 수치가 Stage 1과 동일하다.
- 이번 변경이 일반 render tree image path나 non-baked image path에 영향을 주지 않았다는 설계 의도와 일치한다.

## Overlay metadata smoke

명령:

```bash
./scripts/overlay-metadata-smoke.sh build.noindex/task116-overlay-metadata --page 1 \
  samples/복학원서.hwp
```

결과:

| PageCount | UpstreamImages | Overlay | Behind | Front | Renderable | BinLinked | TreeImages | TreeEmbeddedAvailable | Wraps |
|----------:|---------------:|--------:|-------:|------:|-----------:|----------:|-----------:|-----------------------|-------|
| 1 | 2 | 2 | 2 | 0 | 2 | 2 | 2 | 2/2 | BehindText:2 |

중앙 watermark payload:

| binDataId | mime | effect | brightness | contrast | watermarkPreset | bakedWatermark | byteCount | bbox |
|----------:|------|--------|-----------:|---------:|-----------------|----------------|----------:|------|
| 2 | image/png | grayScale | -50 | 70 | custom | true | 253602 | 137.707,270.24 495.04x495.733 |

해석:

- Stage 3 code change는 metadata contract를 바꾸지 않았다.
- target overlay는 여전히 resolved PNG bytes와 `bakedWatermark=true`를 제공한다.

## 한계

- 이번 수정은 `RhwpPageOverlayImage` metadata path에서 resolved bytes가 있는 baked watermark만 다룬다.
- render tree fallback path에는 `bakedWatermark` 의미가 없으므로 기존 image adjustment를 유지한다.
- `bakedWatermark=false`인 legacy JPEG watermark에 대한 white/near-white transparency fallback은 구현하지 않았다.
- `복학원서.hwp`의 하단 overflow, 일부 glyph fallback, text/font/layout 차이는 여전히 남아 있으며 #116의 현재 범위가 아니다.
- upstream rhwp #1017의 장기 z-order/replay policy 공통화는 별도 축이다.

## Stage 4 결론

`bakedWatermark=true` resolved overlay bytes에서 Swift/CoreGraphics 후처리를 생략하는 변경은 target fixture에서 명확한 개선을 보였다. `복학원서.hwp` visual diff는 `32.0188% -> 7.8441%`로 크게 감소했고, regression sample set 수치는 Stage 1과 동일하게 유지됐다.

따라서 Stage 3 구현은 #116의 현재 목표인 "현재 v0.7.13 기준 baked watermark 중복 보정 제거"에 유효하다. 다음 단계에서는 최종 보고서와 PR 설명에 이 수치, 한계, #296과의 관계를 반영한다.
