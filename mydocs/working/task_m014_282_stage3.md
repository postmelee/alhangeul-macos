# Task #282 Stage 3 완료 보고서

## 작업 개요

- 이슈: #282
- 브랜치: `local/task282`
- 기준 브랜치: `origin/devel`
- Stage 3 목표: overlay metadata에 renderable image bytes가 들어오는 경우 CoreGraphics fallback renderer가 해당 이미지를 `BehindText`/`InFrontOfText` pass에서 직접 그릴 수 있게 한다.

## 기준 정렬

- #278 병합 후 `local/task282`를 `origin/devel` 위로 rebase했다.
- rebase 후 기준 merge commit은 `b9365ff`이며, 작업 브랜치는 `origin/devel` 대비 3개 커밋 ahead 상태에서 Stage 3를 시작했다.
- 현재 core/studio 기준은 `rhwp-core.lock`의 `v0.7.13` / `b3e16ef212af81ef37d973ddb86d6816d3804642`이다.
- 계획서의 기존 `v0.7.12` 표기를 `v0.7.13` 기준으로 갱신하고, #278 이후 관찰 가능한 `resolved` payload, embedded bytes availability, `bakedWatermark` 상태를 Stage 3 구현 원칙에 반영했다.

## 구현 내용

- `HwpNativePageCompositor`에 overlay layer 전용 render helper를 추가했다.
- 각 overlay layer는 먼저 `RhwpPageOverlayImage.hasRenderableData`가 있는 metadata image를 찾는다.
- renderable metadata가 없으면 Stage 2의 기존 render tree overlay fallback pass를 그대로 사용한다.
- renderable metadata가 있으면 `CGTreeRenderer.renderOverlayImages`로 overlay 이미지를 직접 그린다.
- metadata image가 하나도 그려지지 못한 경우에는 render tree overlay fallback pass를 다시 수행한다.
- image bytes 해석 순서는 다음과 같다.
  - `source.data` 우선 사용
  - `source.binDataId`가 있으면 `RhwpDocument.imageData(binDataId:)` fallback
  - 둘 다 decode할 수 없으면 해당 overlay image skip
- overlay image drawing은 기존 image path와 같은 decode/crop/effect/brightness/contrast/transform/destination 계산을 재사용한다.
- `bakedWatermark == true` payload는 bytes 자체가 이미 watermark 처리를 포함한다고 보고 별도 watermark pass를 추가하지 않는다.

## 검증 결과

### 정적/빌드 검증

```bash
./scripts/check-no-appkit.sh
./scripts/verify-rhwp-studio-assets.sh
git diff --check
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData-task282-stage3 CODE_SIGNING_ALLOWED=NO build
./scripts/check-extension-registration-hygiene.sh --check-only
```

- `check-no-appkit.sh`: 통과
- `verify-rhwp-studio-assets.sh`: 통과
- `git diff --check`: 통과
- `xcodegen generate`: 통과
- `xcodebuild`: `** BUILD SUCCEEDED ** [13.754 sec]`
- extension registration hygiene: Issues 없음
  - 개발 빌드 app bundle은 `build.noindex/DerivedData-task282-stage3` 아래에 존재하지만 등록되지는 않았다.
  - PlugInKit provider path 미보고 경고는 기존 hygiene check의 관찰 항목이며 이번 Stage 3 변경으로 새로 생긴 등록 오염은 없다.

### Overlay metadata smoke

명령:

```bash
./scripts/overlay-metadata-smoke.sh build.noindex/task282-stage3-overlay-metadata
```

결과:

| File | Status | UpstreamImages | Overlay | Behind | Front | Renderable | TreeImages | TreeEmbeddedAvailable | Wraps |
|---|---|---:|---:|---:|---:|---:|---:|---|---|
| `request.hwp` | OK | 1 | 0 | 0 | 0 | 0 | 1 | 1/1 | TopAndBottom:1 |
| `hwpx-01.hwpx` | OK | 2 | 0 | 0 | 0 | 0 | 2 | 2/2 | TopAndBottom:2 |
| `tac-img-02.hwp` | OK | 1 | 0 | 0 | 0 | 0 | 1 | 1/1 | TopAndBottom:1 |
| `tac-img-02.hwpx` | OK | 1 | 0 | 0 | 0 | 0 | 1 | 1/1 | TopAndBottom:1 |
| `hwp-img-001.hwp` | OK | 4 | 0 | 0 | 0 | 0 | 4 | 4/4 | Square:1, TopAndBottom:3 |
| `img-start-001.hwp` | OK | 0 | 0 | 0 | 0 | 0 | 0 | 0/0 | - |

관찰:

- 현재 smoke sample set에는 `BehindText`/`InFrontOfText` overlay image 양성 케이스가 없다.
- 대신 render tree image의 embedded bytes availability는 `request.hwp`, `hwpx-01.hwpx`, `tac-img-02.hwp`, `tac-img-02.hwpx`, `hwp-img-001.hwp`에서 모두 확인됐다.
- Stage 3 코드는 metadata overlay가 renderable할 때 사용할 drawing path를 연결했지만, 현재 sample set만으로는 실제 overlay image pass의 픽셀 개선을 증명할 수 없다.

### Preview visual diff smoke

명령:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task282-stage3-images --page 1 samples/tac-img-02.hwp samples/tac-img-02.hwpx samples/hwp-img-001.hwp samples/img-start-001.hwp
```

결과:

| File | Status | ChangedPixels | ChangedPercent | MeanRGBDelta | MaxRGBDelta | NativeBackend | NativeMs |
|---|---|---:|---:|---:|---:|---|---:|
| `tac-img-02.hwp` | OK | 147270/3562815 | 4.1335% | 3.7157 | 255 | coreGraphics | 1051.3 |
| `tac-img-02.hwpx` | OK | 150272/3562815 | 4.2178% | 3.6095 | 255 | coreGraphics | 7.4 |
| `hwp-img-001.hwp` | OK | 281516/3562815 | 7.9015% | 8.3980 | 255 | coreGraphics | 22.2 |
| `img-start-001.hwp` | OK | 641445/3561228 | 18.0119% | 22.1834 | 255 | coreGraphics | 36.4 |

관찰:

- `StudioReleaseTag`와 `StudioResolvedCommit`은 각각 `v0.7.13`, `b3e16ef212af81ef37d973ddb86d6816d3804642`로 기록됐다.
- `tac-img-02.hwpx`에서 기존과 같은 paragraph layout overflow warning이 관찰됐다.
- overlay 양성 케이스가 없으므로 위 수치는 Stage 3의 overlay image path 개선 수치가 아니라, v0.7.13 기준의 기존 image sample smoke 기준선으로 봐야 한다.

## 결론

- Stage 3의 코드 목표였던 `source.data`/`binDataId` 기반 overlay image drawing path 연결은 완료했다.
- 기존 render tree overlay fallback은 유지했고, renderable metadata가 없거나 metadata image draw가 전부 실패하는 경우 fallback pass가 동작하도록 했다.
- 현재 fixture에서는 overlay metadata가 0건이라 실제 `BehindText`/`InFrontOfText` image overlay 픽셀 개선은 아직 측정할 수 없다.
- 따라서 Stage 3 완료 판정은 "렌더 경로 연결 + 기존 sample regression 없음 + fallback 유지" 기준으로 한다.

## 한계와 handoff

- overlay 양성 fixture가 필요하다. 현재 smoke sample만으로는 `BehindText`/`InFrontOfText` image가 실제로 metadata path에서 그려지는지 pixel diff로 증명할 수 없다.
- metadata image가 여러 개이고 일부만 draw에 성공하는 경우, 현재 구현은 성공한 image는 그리고 실패한 image만 개별적으로 render tree fallback하지 않는다. 전체 draw count가 0일 때만 fallback한다.
- watermark multiply/opacity parity는 현재 core payload에서 독립 구현할 근거가 부족하므로 #116/#122 범위로 남긴다.
- image destination은 기존 `CGTreeRenderer`의 `imageDestinationRect`와 같은 제한을 공유한다. 현재는 fit/stretch 계열 외 fill mode 차이를 적극적으로 해석하지 않는다.
- 다음 단계에서는 overlay 양성 fixture 또는 upstream metadata payload가 준비되는 즉시 Stage 3 path의 실제 픽셀 개선을 측정해야 한다.
