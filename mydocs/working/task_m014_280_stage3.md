# Task M014 #280 Stage 3 보고서 - native preview와 pixel diff 구현

## 단계 개요

- 이슈: #280 rhwp-studio 기준 preview visual diff harness 구축
- 단계: Stage 3. native preview 출력과 diff 계산 구현
- 목표: Stage 2의 `rhwp-studio` reference PNG와 같은 입력/page에 대해 native preview PNG를 생성하고, pixel diff PNG와 summary 수치를 남긴다.

이번 단계에서는 sample set 문서화와 사용 문서 정리는 진행하지 않았다. 해당 범위는 Stage 4로 남겼다.

## 변경 내용

### Wrapper 확장

`scripts/preview-visual-diff-harness.sh`를 확장했다.

- `--policy coreGraphicsOnly|skiaOptIn` 옵션을 추가했다.
- Rust static lib와 modulemap 존재를 확인한다.
- Swift helper compile에 다음 source/link dependency를 추가했다.
  - `Sources/RhwpCoreBridge/RhwpDocument.swift`
  - `Sources/RhwpCoreBridge/RenderTree.swift`
  - `Sources/RhwpCoreBridge/FontFallback.swift`
  - `Sources/RhwpCoreBridge/FontResourceRegistry.swift`
  - `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
  - `Sources/Shared/HwpPageImageRenderer.swift`
  - `Frameworks/universal/librhwp.a`

### Swift helper 확장

`scripts/preview_visual_diff_harness.swift`에 native render와 diff engine을 추가했다.

- `NativePreviewRenderer`
  - `RhwpDocument(data:filename:)`로 문서를 연다.
  - `HwpPageImageRenderer.renderPage(document:pageIndex:policy:)`를 호출한다.
  - `native/{file}-page{N}-native.png`를 저장한다.
  - `native/{file}-page{N}-native.json`에 policy, backend, fallback, page size, pixel size, PNG bytes, render timing을 기록한다.
- `VisualDiffEngine`
  - `studio` reference PNG를 RGBA로 읽는다.
  - native `CGImage`를 Studio reference 크기에 맞춰 rasterize한다.
  - 기존 visual compare helper와 같은 pixel delta threshold `12`를 사용한다.
  - `diff/{file}-page{N}-diff.png`와 `summary.md` 수치를 생성한다.

산출물 구조는 다음으로 확장됐다.

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

## Smoke 결과

### 기본 정책: coreGraphicsOnly

실행:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task280-stage3 --page 1 \
  samples/basic/request.hwp samples/복학원서.hwp
```

결과:

| 파일 | StudioSize | NativeSize | CompareSize | ChangedPercent | MeanRGBDelta | MaxRGBDelta | NativeBackend | NativeMs |
|---|---:|---:|---:|---:|---:|---:|---|---:|
| `request.hwp` | `1133x1587` | `567x794` | `1133x1587` | `18.1021%` | `11.5796` | `255` | `coreGraphics` | `1018.1ms` |
| `복학원서.hwp` | `1587x2245` | `794x1123` | `1587x2245` | `32.3726%` | `42.9398` | `255` | `coreGraphics` | `404.0ms` |

관찰:

- Studio reference는 device scale 2에 가까운 backing store 크기로 생성된다.
- native CoreGraphics output은 page point size 기준 scale 1 PNG로 생성된다.
- diff는 native output을 Studio reference 크기에 맞춰 확대한 뒤 계산한다.
- `request.hwp` native render 중 기존 renderer diagnostics인 `LAYOUT_OVERFLOW` 2건이 stderr에 출력됐다.

### 옵션 정책: skiaOptIn

실행:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task280-stage3-skia --page 1 \
  --policy skiaOptIn samples/basic/request.hwp
```

결과:

| 파일 | StudioSize | NativeSize | CompareSize | ChangedPercent | MeanRGBDelta | MaxRGBDelta | NativeBackend | NativeMs |
|---|---:|---:|---:|---:|---:|---:|---|---:|
| `request.hwp` | `1133x1587` | `567x794` | `1133x1587` | `12.4856%` | `9.5936` | `255` | `skia` | `53.9ms` |

관찰:

- `--policy skiaOptIn` 경로는 Skia backend를 사용했다.
- 같은 `request.hwp` 기준으로 Stage 3 smoke에서는 CoreGraphics보다 changedPercent와 mean delta가 낮았다.
- 이 수치는 단일 샘플 관찰이며, Skia 전환 판단 기준으로 사용하지 않는다.

## 산출물 확인

확인:

```bash
find build.noindex/task280-stage3 -maxdepth 2 -type f | sort
sed -n '1,120p' build.noindex/task280-stage3/summary.md
sips -g pixelWidth -g pixelHeight \
  build.noindex/task280-stage3/studio/request-page1-studio.png \
  build.noindex/task280-stage3/native/request-page1-native.png \
  build.noindex/task280-stage3/diff/request-page1-diff.png \
  build.noindex/task280-stage3/studio/복학원서-page1-studio.png \
  build.noindex/task280-stage3/native/복학원서-page1-native.png \
  build.noindex/task280-stage3/diff/복학원서-page1-diff.png
```

결과:

- `studio`, `native`, `diff` 폴더가 생성됐다.
- 각 샘플마다 PNG와 JSON metadata가 생성됐다.
- diff PNG 크기는 Studio reference 크기와 일치했다.

## 한계와 Stage 4 반영점

- Stage 2에서 확인한 대로 reference PNG는 `canvasDataURL` 기반이므로 DOM overlay를 포함하지 않는다. summary의 `StudioCapture=canvasDataURL`와 Studio JSON의 `overlayIncluded=false`를 통해 이 사실을 추적한다.
- 현재 summary는 hard gate가 아니라 관찰 자료다. changedPercent가 높아도 Stage 3에서는 실패 처리하지 않는다.
- native output과 Studio reference의 scale이 다르므로, diff는 native를 Studio 크기로 확대해 비교한다. Stage 4 문서에 이 해석 기준을 명시해야 한다.
- `request.hwp`에서 `LAYOUT_OVERFLOW` stderr가 관찰됐다. 이는 diff harness 실패는 아니지만, 후속 렌더 개선 후보를 찾을 때 참고할 수 있다.

## 검증

실행:

```bash
./scripts/check-no-appkit.sh
git diff --check
rg -n -- "NativePolicy|DiffPixelThreshold|NativePreviewRenderer|VisualDiffEngine|captureMode|overlayIncluded|changedPercent|HwpPageImageRenderer|renderPage\\(" \
  scripts/preview_visual_diff_harness.swift scripts/preview-visual-diff-harness.sh
```

결과:

- shared Swift code의 AppKit/UIKit 의존 금지 검증 통과.
- whitespace 검증 통과.
- Stage 3에서 `Sources/` 코드는 변경하지 않았다.

## 다음 단계 승인 요청

Stage 4에서는 sample set과 사용 문서를 정리한다. 특히 `canvasDataURL` reference의 overlay 한계, scale 정렬 기준, summary 수치 해석 방법, 기본 실행 예시를 문서화한다.
