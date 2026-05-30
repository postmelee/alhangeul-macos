# Task M014 #116 Stage 1 보고서

## 단계 목적

`복학원서.hwp` 중앙 watermark 문제를 수정하기 전에 최신 `devel` 기준 baseline, overlay metadata, native renderer path를 다시 고정한다. #282 PR #297이 merge된 뒤의 compositor 기준에서 #116 구현 방향이 여전히 유효한지도 확인했다.

## 기준 정렬

- 작업 브랜치: `local/task116`
- rebase 기준: `origin/devel` `2b852af`
- 선행 merge:
  - #297: #282 native compositor 보강
  - #298: #79 release runbook
- rebase 중 `mydocs/orders/20260530.md` add/add 충돌이 발생했고, #79/#282/#116/#296 행을 모두 보존해 해결했다.
- Rust bridge artifact는 새 worktree에 없어서 `./scripts/build-rust-macos.sh`로 생성했다.

## Baseline smoke 결과

### `복학원서.hwp` visual diff

명령:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task116-stage1-visual --page 1 \
  samples/복학원서.hwp
```

조건:

- NativePolicy: `coreGraphicsOnly`
- StudioReleaseTag: `v0.7.13`
- StudioResolvedCommit: `b3e16ef212af81ef37d973ddb86d6816d3804642`
- Viewport: `1400x1800`
- SettleMs: `120`
- DiffPixelThreshold: `12`

| File | ChangedPixels | ChangedPercent | MeanRGBDelta | MaxRGBDelta | DiffBounds | StudioCapture | NativeBackend | NativeMs |
|------|--------------:|---------------:|-------------:|------------:|------------|---------------|---------------|---------:|
| `복학원서.hwp` | 1140771/3562815 | 32.0188% | 18.2116 | 255 | 83,45 1436x2155 | `domComposite` | `coreGraphics` | 1168.1 |

관찰:

- native output에는 중앙 watermark의 gray rectangle이 뚜렷하게 보인다.
- studio reference는 watermark가 훨씬 옅고 rectangle이 덜 드러난다.
- Stage 4 #282 수치 32.0086%와 거의 같은 수준이므로 #282 merge 이후에도 문제는 유지된다.
- `MeanRGBDelta`는 Stage 4 보고값과 달라졌으므로 같은 branch/run 기준에서 비교해야 한다.

### Overlay metadata

명령:

```bash
./scripts/overlay-metadata-smoke.sh build.noindex/task116-stage1-overlay-metadata --page 1 \
  samples/복학원서.hwp
```

| PageCount | UpstreamImages | Overlay | Behind | Front | Renderable | BinLinked | TreeImages | TreeEmbeddedAvailable | Wraps |
|----------:|---------------:|--------:|-------:|------:|-----------:|----------:|-----------:|-----------------------|-------|
| 1 | 2 | 2 | 2 | 0 | 2 | 2 | 2 | 2/2 | BehindText:2 |

중앙 watermark payload:

| binDataId | mime | effect | brightness | contrast | watermarkPreset | bakedWatermark | byteCount | bbox |
|----------:|------|--------|-----------:|---------:|-----------------|----------------|----------:|------|
| 2 | image/png | grayScale | -50 | 70 | custom | true | 253602 | 137.707,270.24 495.04x495.733 |

좌상단 로고 payload:

| binDataId | mime | effect | brightness | contrast | bakedWatermark | byteCount | bbox |
|----------:|------|--------|-----------:|---------:|----------------|----------:|------|
| 1 | image/png | realPic | 0 | 0 | false | 44860 | 65.493,49.013 77.013x87.893 |

핵심 발견:

- 수행계획서 작성 당시의 전제였던 `mime=image/jpeg`, `bakedWatermark=false`가 최신 `devel` Stage 1 기준에서는 맞지 않는다.
- 현재 중앙 watermark는 이미 `image/png`, `bakedWatermark=true`다.
- 그런데 `effect=grayScale`, `brightness=-50`, `contrast=70` 값도 같이 남아 있다.

### Native render debug

명령:

```bash
./scripts/render-debug-compare.sh build.noindex/task116-stage1-render-debug --page 1 \
  samples/복학원서.hwp
```

결과:

| 항목 | 값 |
|------|----|
| PageSizePt | 793.7x1122.5 |
| NativePNGSize | 794x1123 |
| NativeNonWhitePixels | 277497 |
| TextRuns | 102 |
| HangulRuns | 25 |
| HangulScalars | 143 |
| MissingHangulGlyphs | 0 |
| DiffDifferentPixels | 342189 |
| DiffDifferentPixelRatio | 0.383765 |
| DiffMaxChannelDelta | 255 |

Render tree image node for `bin_data_id=2`:

```json
{
  "bin_data_id": 2,
  "effect": "GrayScale",
  "brightness": -50,
  "contrast": 70,
  "text_wrap": "BehindText",
  "crop": [0, 0, 54600, 54660]
}
```

## 기존 sample set 회귀 baseline

명령:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task116-stage1-regression-baseline --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx \
  samples/tac-img-02.hwp samples/tac-img-02.hwpx \
  samples/hwp-img-001.hwp samples/img-start-001.hwp
```

| Sample | ChangedPercent | MeanRGBDelta | StudioCapture | NativeBackend | NativeMs |
|--------|---------------:|-------------:|---------------|---------------|---------:|
| `request.hwp` | 17.8542% | 11.0716 | domComposite | coreGraphics | 959.5 |
| `hwpx-01.hwpx` | 15.0285% | 15.2088 | domComposite | coreGraphics | 34.4 |
| `tac-img-02.hwp` | 4.1153% | 3.6698 | canvasDataURL | coreGraphics | 7.6 |
| `tac-img-02.hwpx` | 4.1153% | 3.6698 | domComposite | coreGraphics | 3.9 |
| `hwp-img-001.hwp` | 7.8277% | 8.1872 | domComposite | coreGraphics | 15.1 |
| `img-start-001.hwp` | 13.9805% | 13.9111 | domComposite | coreGraphics | 28.4 |

## Current renderer path inventory

현재 path:

1. `HwpNativePageCompositor.render`가 `overlays.behind`를 `renderOverlayLayer(.behindText, ...)`로 전달한다.
2. `HwpNativePageCompositor.renderOverlayLayer`는 `hasRenderableData` overlay를 골라 `CGTreeRenderer.renderOverlayImages`를 호출한다.
3. `CGTreeRenderer.renderOverlayImage`는 `RhwpPageOverlayImage`를 `ImageNode`로 다시 구성한다.
4. 이때 `bakedWatermark`는 `ImageNode`에 전달되지 않는다.
5. `preparedImage(for:node:)` -> `adjustedImage(for:node:)`는 `effect`, `brightness`, `contrast`를 적용한다.

문제 가능성이 높은 지점:

- 중앙 watermark는 이미 `bakedWatermark=true` PNG인데, Swift renderer가 같은 `effect/brightness/contrast`를 다시 적용할 수 있다.
- `bakedWatermark`를 무시하는 구조 때문에 resolved/baked payload의 의도가 render path에 반영되지 않는다.
- render tree fallback에는 `bakedWatermark` 정보가 없으므로 metadata overlay path에서만 gate를 둘 수 있다.

## 설계 결론

Stage 2의 첫 후보는 JPEG white background transparency fallback이 아니라 `bakedWatermark=true` overlay의 duplicate adjustment 방지다.

권장 방향:

1. `RhwpPageOverlayImage.bakedWatermark == true`이면 `effect`, `brightness`, `contrast`를 Swift에서 다시 적용하지 않는다.
2. crop, transform, destination rect는 기존대로 유지한다.
3. `bakedWatermark == false`인 overlay나 일반 render tree image는 기존 adjustment path를 유지한다.
4. white/near-white transparency fallback은 현재 positive fixture가 없으므로 보류한다.

#296과의 관계:

- #296은 "upstream release 이후 compatibility"로 만든 이슈였지만, 현재 `v0.7.13` 기준으로 이미 `bakedWatermark=true` payload가 관찰된다.
- 따라서 현재 release의 duplicate adjustment gate는 #116에 포함하는 편이 자연스럽다.
- #296은 이후 upstream payload shape 변경 또는 core update 시 중복 적용 방지 회귀 이슈로 남길 수 있다.

## 검증

실행:

```bash
./scripts/build-rust-macos.sh
./scripts/overlay-metadata-smoke.sh build.noindex/task116-stage1-overlay-metadata --page 1 samples/복학원서.hwp
./scripts/render-debug-compare.sh build.noindex/task116-stage1-render-debug --page 1 samples/복학원서.hwp
./scripts/preview-visual-diff-harness.sh build.noindex/task116-stage1-visual --page 1 samples/복학원서.hwp
./scripts/preview-visual-diff-harness.sh build.noindex/task116-stage1-regression-baseline --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx \
  samples/tac-img-02.hwp samples/tac-img-02.hwpx \
  samples/hwp-img-001.hwp samples/img-start-001.hwp
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug \
  -derivedDataPath build.noindex/DerivedData-task116-stage1 CODE_SIGNING_ALLOWED=NO build
```

결과:

- Rust bridge artifacts 생성 성공
- overlay metadata smoke 성공
- render debug smoke 성공
- visual diff harness 성공
- HostApp Debug build 성공: `** BUILD SUCCEEDED ** [11.537 sec]`

registration hygiene:

```bash
./scripts/check-extension-registration-hygiene.sh --check-only
./scripts/check-extension-registration-hygiene.sh --cleanup-dev-registrations
```

- `xcodebuild`가 `build.noindex/DerivedData-task116-stage1/.../Alhangeul.app`을 LaunchServices에 등록했다.
- cleanup script가 `pluginkit -r`, `lsregister -u`, `qlmanage -r cache`를 수행했지만 LaunchServices stale registration이 남았다.
- 생성된 Debug app bundle은 삭제했으나 stale registration은 계속 보고됐다.
- 이 문제는 #116 renderer 구현과 직접 관련은 없고 로컬 LaunchServices 상태 문제로 보인다. 다음 smoke 전에 별도 hygiene 정리가 필요할 수 있다.

## 다음 단계 승인 요청

Stage 2에서는 기존 계획을 수정해 다음 방향으로 진행하고자 한다.

1. `bakedWatermark=true` overlay image에는 Swift `effect/brightness/contrast`를 중복 적용하지 않는 gate를 설계한다.
2. JPEG white background transparency fallback은 현재 positive fixture가 없으므로 보류한다.
3. #296은 future upstream/core update compatibility follow-up으로 유지한다.

