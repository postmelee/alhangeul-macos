# Task M014 #280 최종 보고서 - rhwp-studio 기준 preview visual diff harness 구축

## 작업 개요

- 이슈: #280 rhwp-studio 기준 preview visual diff harness 구축
- 마일스톤: M014 `v0.1.4 Native Preview/Viewer Parity`
- 브랜치: `local/task280`
- 목표: bundled `rhwp-studio` 기본 렌더 결과와 Swift/native preview 출력을 같은 샘플/page 단위로 생성하고, diff 이미지와 수치 summary를 반복 실행 가능한 형태로 남긴다.

## 최종 결론

`scripts/preview-visual-diff-harness.sh`와 `scripts/preview_visual_diff_harness.swift`를 추가해 v0.1.4 native 렌더 개선 작업의 기준 harness를 구축했다.

현재 harness는 다음을 생성한다.

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

기본 비교 정책은 `coreGraphicsOnly`이며, `--policy skiaOptIn`으로 Skia optional backend도 관찰할 수 있다. 최종 sample set 6개는 모두 OK로 산출물이 생성됐다.

## 주요 산출물

| 파일 | 역할 |
|---|---|
| `scripts/preview-visual-diff-harness.sh` | asset 검증, Swift helper compile, 입력/옵션 전달 |
| `scripts/preview_visual_diff_harness.swift` | Studio reference capture, native render, pixel diff, summary 생성 |
| `mydocs/tech/v014_preview_visual_diff_harness.md` | 사용법, sample set, 수치 해석, 후속 handoff 문서 |
| `mydocs/working/task_m014_280_stage1.md` | inventory와 capture selector 확정 |
| `mydocs/working/task_m014_280_stage2.md` | Studio reference capture 구현 보고 |
| `mydocs/working/task_m014_280_stage3.md` | native render와 diff 구현 보고 |
| `mydocs/working/task_m014_280_stage4.md` | sample set 문서화 보고 |

## 최종 실행 명령

```bash
./scripts/verify-rhwp-studio-assets.sh
./scripts/check-no-appkit.sh
./scripts/preview-visual-diff-harness.sh build.noindex/task280-final --page 1 \
  samples/basic/request.hwp samples/복학원서.hwp samples/pic-crop-01.hwp \
  samples/form-01.hwp samples/hwpx/form-002.hwpx samples/hwpx/hwpx-01.hwpx
swiftc -parse-as-library \
  -module-cache-path build.noindex/task280-syntax-module-cache \
  -Xcc -fmodules-cache-path=build.noindex/task280-syntax-clang-cache \
  -I Frameworks/modulemap \
  Sources/RhwpCoreBridge/RhwpDocument.swift \
  Sources/RhwpCoreBridge/RenderTree.swift \
  Sources/RhwpCoreBridge/FontFallback.swift \
  Sources/RhwpCoreBridge/FontResourceRegistry.swift \
  Sources/RhwpCoreBridge/CGTreeRenderer.swift \
  Sources/Shared/HwpPageImageRenderer.swift \
  scripts/preview_visual_diff_harness.swift \
  Frameworks/universal/librhwp.a \
  -framework AppKit -framework CoreGraphics -framework CoreText \
  -framework Foundation -framework ImageIO -framework UniformTypeIdentifiers \
  -framework Security -framework CoreFoundation -framework WebKit \
  -lc++ -liconv -lz \
  -o build.noindex/task280-syntax-check
```

최종 smoke 산출물 위치:

```text
build.noindex/task280-final/
```

## 최종 smoke 측정 결과

기준:

- Page: `1`
- NativePolicy: `coreGraphicsOnly`
- StudioReleaseTag: `v0.7.12`
- StudioResolvedCommit: `1899ef9bc2dfd1c6c0c4d18b192d253a2d0a1fb5`
- Viewport: `1400x1800`
- SettleMs: `120`
- DiffPixelThreshold: `12`

| 파일 | StudioSize | NativeSize | CompareSize | ChangedPixels | ChangedPercent | MeanRGBDelta | MaxRGBDelta | DiffBounds | NativeBackend | NativeMs |
|---|---:|---:|---:|---:|---:|---:|---:|---|---|---:|
| `request.hwp` | `1133x1587` | `567x794` | `1133x1587` | `325488/1798071` | `18.1021%` | `11.5796` | `255` | `36,36 1061x1515` | `coreGraphics` | `1037.0ms` |
| `복학원서.hwp` | `1587x2245` | `794x1123` | `1587x2245` | `1153323/3562815` | `32.3711%` | `42.9364` | `255` | `83,45 1436x2155` | `coreGraphics` | `389.4ms` |
| `pic-crop-01.hwp` | `1587x2245` | `794x1123` | `1587x2245` | `72763/3562815` | `2.0423%` | `0.8092` | `186` | `121,234 1345x1814` | `coreGraphics` | `3.1ms` |
| `form-01.hwp` | `1587x2245` | `794x1123` | `1587x2245` | `28738/3562815` | `0.8066%` | `0.4845` | `255` | `197,234 1194x1814` | `coreGraphics` | `2.1ms` |
| `form-002.hwpx` | `1587x2244` | `794x1123` | `1587x2244` | `601515/3561228` | `16.8907%` | `17.6360` | `255` | `121,159 1345x1962` | `coreGraphics` | `25.3ms` |
| `hwpx-01.hwpx` | `1587x2245` | `794x1123` | `1587x2245` | `540973/3562815` | `15.1839%` | `15.6722` | `255` | `121,159 1345x1981` | `coreGraphics` | `29.8ms` |

모든 row는 `OK`다. `studio`, `native`, `diff`, `summary.md` 산출물이 모두 생성됐다.

Studio reference metadata는 모두 `captureMode=canvasDataURL`, `overlayIncluded=false`였다. `overlayCount`는 `복학원서.hwp`가 `5`, 나머지 기본 샘플이 `1`이었다.

## 추가 Skia 관찰

Stage 3에서 `--policy skiaOptIn` smoke를 별도로 확인했다.

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task280-stage3-skia --page 1 \
  --policy skiaOptIn samples/basic/request.hwp
```

결과:

| 파일 | StudioSize | NativeSize | ChangedPercent | MeanRGBDelta | NativeBackend | NativeMs |
|---|---:|---:|---:|---:|---|---:|
| `request.hwp` | `1133x1587` | `567x794` | `12.4856%` | `9.5936` | `skia` | `53.9ms` |

단일 샘플 기준으로 Skia는 CoreGraphics보다 changedPercent와 mean delta가 낮았다. 이 수치는 관찰 자료이며, Skia default 전환 판단은 M20/#259 범위로 남긴다.

## 관찰과 얻은 점

### Studio capture

초기 설계는 `WKWebView.takeSnapshot`으로 page rect를 캡처하는 방식이었다. 실제 smoke에서는 `takeSnapshot`이 canvas 배경은 잡지만 canvas backing store의 문서 내용을 빈 화면처럼 캡처하는 현상이 있었다.

JavaScript로 canvas backing store를 샘플링하면 non-white pixel이 확인되어, `rhwp-studio` 렌더 자체는 완료된 상태임을 확인했다. 따라서 reference PNG는 다음 방식으로 고정했다.

- WebKit에서 bundled `rhwp-studio`를 실제로 로드한다.
- `#scroll-content canvas`를 page selector로 사용한다.
- canvas backing store를 `toDataURL('image/png')`로 export한다.
- 투명 배경은 흰색 임시 canvas에 합성한다.
- DOM overlay는 PNG에 포함하지 않고 metadata에 기록한다.

### Native render

native 출력은 `HwpPageImageRenderer.renderPage(document:pageIndex:policy:)`를 사용한다. JSON metadata에는 `policy`, `backendUsed`, `fallbackReason`, `pageSize`, `pixelSize`, `pngBytes`, `renderMs`가 기록된다.

### Diff

diff는 Studio reference 크기를 기준으로 한다. 현재 Studio canvas backing store는 device scale 2에 가깝고, native CoreGraphics output은 page point 기준 scale 1이다. 따라서 native output을 Studio 크기로 확대해 비교한다.

## 한계

- `captureMode=canvasDataURL`이므로 DOM overlay는 reference PNG에 포함되지 않는다.
- `overlayIncluded=false`이며, overlay 후보 수는 `studio/*.json`의 `overlayCount`로만 추적한다.
- canvas 내부 margin guide, crop mark, editor guide는 PNG에 남을 수 있다.
- `ChangedPercent`는 release hard gate가 아니다. scale 차이, antialiasing, text shaping, editor residual 영향을 함께 본다.
- Codex sandbox 안에서는 WKWebView가 WebKit/Cache/GPU/LaunchServices sandbox extension을 만들지 못해 smoke가 정상 완료되지 않았다. WKWebView smoke는 sandbox 밖 실행 승인을 받아 수행했다.
- `request.hwp`와 `pic-crop-01.hwp`에서 기존 renderer의 `LAYOUT_OVERFLOW` stderr가 관찰됐다. harness 실패는 아니지만 후속 renderer 개선에서 참고할 수 있다.

## 후속 이슈 handoff

### #282 Quick Look/Thumbnail native compositor

- 기본 샘플: `request.hwp`, `복학원서.hwp`
- 확장 샘플: `tac-img-02.hwp`, `tac-img-02.hwpx`
- `StudioCapture=canvasDataURL`, `overlayIncluded=false` 한계를 PR에 명시한다.
- `studio/*.json`의 `overlayCount`를 보고 overlay 후보가 있는 샘플을 우선 확인한다.

### #116 복학원서 JPEG watermark/effect

- 기본 샘플: `복학원서.hwp`
- 추가 후보: `20250130-hongbo.hwp`, `aift.hwp`
- watermark/effect 주변 `DiffBounds`, `ChangedPercent`, `MeanRGBDelta` 전후 비교를 남긴다.

### #122 image fill mode/tile/placement

- 기본 샘플: `pic-crop-01.hwp`
- 확장 샘플: `tac-img-02.hwp`, `tac-img-02.hwpx`
- image crop/fill 영역 diff와 tile/placement 변경 전후 수치를 남긴다.

### #121 RawSvg/OLE/chart resource

- 기본 후보: `draw-group.hwp`, `eq-01.hwp`
- 작업 중 확인한 RawSvg/OLE/chart 전용 샘플을 추가한다.
- resource 미지원과 layout/scale 차이를 분리해 기록한다.

### #110 Placeholder/FormObject static preview

- 기본 샘플: `form-01.hwp`, `hwpx/form-002.hwpx`
- placeholder/form object 영역의 diff bounds와 HWP/HWPX 양쪽 개선 여부를 확인한다.

## 검증 결과

| 검증 | 결과 |
|---|---|
| `./scripts/verify-rhwp-studio-assets.sh` | OK |
| `./scripts/check-no-appkit.sh` | OK |
| `./scripts/preview-visual-diff-harness.sh build.noindex/task280-final ...` | OK |
| full dependency `swiftc -parse-as-library ... scripts/preview_visual_diff_harness.swift ...` | OK |
| `git diff --check` | OK |

## 남은 작업

#280 자체의 harness 구축은 완료됐다. 이후 v0.1.4 렌더 품질 개선은 #283, #281, #282, #116, #122, #121, #110 순서로 이 harness의 sample set과 summary row를 재사용해 진행한다.
