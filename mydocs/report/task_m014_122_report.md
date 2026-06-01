# Task M014 #122 최종 보고서 - Swift native renderer 이미지 fill mode·타일·배치 parity 보강

## 작업 개요

- 이슈: #122 Swift native renderer 이미지 fill mode·타일·배치 parity 보강
- 마일스톤: M014 (`v0.1.4 Native Preview/Viewer Parity`)
- 브랜치: `local/task122`
- 기준 브랜치: `devel`
- core/studio 기준: `edwardkim/rhwp v0.7.13`, `b3e16ef212af81ef37d973ddb86d6816d3804642`
- 목표: Quick Look/Thumbnail/PDF CoreGraphics fallback에서 upstream image `fill_mode`, placement, tile contract를 소비하도록 Swift native renderer의 image draw path를 보강한다.

## 작업 요약

#122는 Swift/CoreGraphics image draw path가 `fill_mode`를 bbox 전체 draw로만 처리하던 한계를 보강하는 작업이다. 이번 작업은 `CGTreeRenderer` 내부에 fill policy normalization, natural size 선택, placement/tile draw helper를 추가하고, render tree image와 overlay image가 같은 helper를 사용하도록 정리했다.

- Stage 1: current path inventory와 baseline visual diff를 정리했다.
- Stage 2: upstream `v0.7.13` 기준 fill/tile/placement helper 설계를 문서화했다.
- Stage 3: `CGTreeRenderer.swift`에 CoreGraphics image placement/tile helper를 구현했다.
- Stage 4: visual diff, render-debug, overlay metadata, extension registration hygiene 회귀 검증을 수행했다.

## 최종 결론

Swift native renderer는 이제 다음 image fill 정책을 처리한다.

- `nil`, empty, `fitToSize`, `stretch`, `stretchToFit`, `none`, unknown: 기존처럼 bbox 전체 draw
- placement: `leftTop`, `centerTop`, `rightTop`, `leftCenter`, `center`, `rightCenter`, `leftBottom`, `centerBottom`, `rightBottom`
- tile: `tileAll`, `tileHorzTop`, `tileHorzBottom`, `tileVertLeft`, `tileVertRight`
- alias: `tileHorizTop`, `tileHorizontalTop`, `tileHorizBottom`, `tileHorizontalBottom`, `tileVerticalLeft`, `tileVerticalRight`

known placement/tile mode는 bbox clip 안에서 natural size로 draw한다. natural size는 `originalSize`를 우선하고, 없으면 원본 decoded image size, prepared image size 순서로 폴백한다. `originalSizeHU`는 upstream crop 계산과 충돌하지 않도록 draw size 계산에 사용하지 않았다.

현재 sample set에서는 non-null `fill_mode` fixture가 없어 placement/tile positive visual proof는 확보하지 못했다. 대신 기존 image/crop sample의 bbox fallback 결과가 Stage 1 baseline과 동일하게 유지되는 것을 확인했다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `Sources/RhwpCoreBridge/CGTreeRenderer.swift` | image fill policy enum, normalization, natural size, placement/tile draw helper, top-left rect CGImage draw helper 추가 |
| `mydocs/plans/task_m014_122.md` | 수행계획서 |
| `mydocs/plans/task_m014_122_impl.md` | 구현계획서 |
| `mydocs/working/task_m014_122_stage1.md` | current path inventory와 baseline 보고 |
| `mydocs/working/task_m014_122_stage2.md` | fill helper 설계 보고 |
| `mydocs/working/task_m014_122_stage3.md` | 구현 완료 보고 |
| `mydocs/working/task_m014_122_stage4.md` | 회귀 검증 보고 |
| `mydocs/orders/20260601.md` | 오늘할일 완료 상태 갱신 |

변경하지 않은 범위:

- RustBridge C ABI
- `rhwp-core.lock`
- upstream `rhwp`
- `RenderTree.swift` model schema
- `PageOverlayImages.swift` overlay model schema
- `HwpNativePageCompositor` pass order
- `project.yml` / Xcode project

## 구현 상세

`CGTreeRenderer`의 기존 `imageDestinationRect(for:size:)` 방식은 단일 destination rect만 반환해 placement/tile draw를 표현하기 어려웠다. 이를 다음 helper 구조로 교체했다.

- `normalizedImageFillPolicy(_:)`
- `imageNaturalDrawSize(for:decodedImageSize:drawImageSize:)`
- `drawImage(_:node:bbox:decodedImageSize:in:)`
- `imagePlacementRect(_:in:size:)`
- `drawImage(_:inTopLeftRect:in:)`
- `drawTiledImage(_:bbox:tileMode:tileSize:in:)`

render tree image와 overlay image는 모두 같은 draw helper를 호출한다. 기존 bitmap 준비 단계는 유지했다.

- `preparedImage`의 crop/effect/brightness/contrast 적용 순서 유지
- #116 baked watermark의 adjustment skip gate 유지
- `applyTransform` 호출 위치 유지
- tile draw cap은 upstream CanvasKit과 같은 `4096`
- invalid size 또는 unknown mode는 bbox 전체 draw로 보수적 fallback

## 변경 전·후 정량 비교

Stage 4 visual diff는 Stage 1 baseline과 같은 세 sample을 같은 조건으로 재측정했다.

기준:

- Page: `1`
- NativePolicy: `coreGraphicsOnly`
- StudioReleaseTag: `v0.7.13`
- StudioResolvedCommit: `b3e16ef212af81ef37d973ddb86d6816d3804642`
- Viewport: `1400x1800`
- SettleMs: `120`
- DiffPixelThreshold: `12`

| 파일 | ChangedPixels | ChangedPercent | MeanRGBDelta | MaxRGBDelta | DiffBounds | StudioCapture | NativeBackend | Stage 1 NativeMs | Stage 4 NativeMs |
|------|--------------:|---------------:|-------------:|------------:|------------|---------------|---------------|-----------------:|-----------------:|
| `pic-crop-01.hwp` | `72763/3562815` | `2.0423%` | `0.8092` | `186` | `121,234 1345x1814` | `domComposite` | `coreGraphics` | `1021.7` | `1077.5` |
| `tac-img-02.hwp` | `146377/3562815` | `4.1085%` | `3.6656` | `255` | `121,159 1345x1965` | `canvasDataURL` | `coreGraphics` | `23.7` | `23.4` |
| `tac-img-02.hwpx` | `146377/3562815` | `4.1085%` | `3.6656` | `255` | `121,159 1345x1965` | `domComposite` | `coreGraphics` | `4.2` | `3.9` |

해석:

- ChangedPixels, ChangedPercent, MeanRGBDelta, MaxRGBDelta, DiffBounds가 Stage 1 baseline과 동일하다.
- 현재 sample들은 `fill_mode == null`이므로 새 placement/tile branch는 직접 시각 검증되지 않았다.
- 기존 bbox fallback path의 회귀는 관찰되지 않았다.

## Render Debug / Metadata 검증

`render-debug-compare` 결과:

| 파일 | NativePNGSize | NativeNonWhitePixels | TextRuns | HangulRuns | MissingHangulGlyphs |
|------|---------------|---------------------:|---------:|-----------:|--------------------:|
| `pic-crop-01.hwp` | `794x1123` | `39870` | `2` | `0` | `0` |
| `tac-img-02.hwp` | `794x1123` | `38410` | `18` | `6` | `0` |
| `tac-img-02.hwpx` | `794x1123` | `38410` | `18` | `6` | `0` |

`overlay-metadata-smoke` 결과:

| 파일 | UpstreamImages | Overlay | Behind | Front | Renderable | BinLinked | TreeImages | TreeEmbeddedAvailable | Wraps |
|------|---------------:|--------:|-------:|------:|-----------:|----------:|-----------:|----------------------:|-------|
| `pic-crop-01.hwp` | `2` | `0` | `0` | `0` | `0` | `0` | `2` | `2/2` | `Square:2` |
| `tac-img-02.hwp` | `1` | `0` | `0` | `0` | `0` | `0` | `1` | `1/1` | `TopAndBottom:1` |
| `tac-img-02.hwpx` | `1` | `0` | `0` | `0` | `0` | `0` | `1` | `1/1` | `TopAndBottom:1` |

fill mode fixture 확인:

| 항목 | Count |
|------|------:|
| `fill_mode == null` | `4` |
| non-null `fill_mode` | `0` |

## 검증 결과

| 검증 | 결과 |
|------|------|
| `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData-task122 CODE_SIGNING_ALLOWED=NO build` | OK |
| `./scripts/preview-visual-diff-harness.sh build.noindex/task122-stage4-visual-escalated --page 1 ...` | OK |
| `./scripts/render-debug-compare.sh build.noindex/task122-stage4-render-debug-hwp --page 1 ...` | OK |
| `./scripts/render-debug-compare.sh build.noindex/task122-stage4-render-debug-hwpx --page 1 ...` | OK |
| `./scripts/overlay-metadata-smoke.sh build.noindex/task122-stage4-overlay --page 1 ...` | OK |
| `./scripts/check-extension-registration-hygiene.sh --check-only` | OK, Issues 없음 |
| `git diff --check` | OK |

비고:

- `preview-visual-diff-harness.sh`는 sandbox 내부에서 Stage 1과 같은 WebKit readiness timeout이 발생해 sandbox 밖에서 재실행했다.
- `xcodebuild`도 Sparkle package resolve와 SwiftPM/clang cache write 권한 제한 때문에 sandbox 밖 재실행으로 최종 통과를 확인했다.
- `render-debug-compare`의 optional core SVG raster diff는 로컬 `qlmanage rasterize failed`로 생성되지 않았지만, native PNG와 summary는 정상 생성됐다.

## 산출물

```text
build.noindex/task122-stage1-baseline-escalated/
build.noindex/task122-stage3-render-debug/
build.noindex/task122-stage4-visual-escalated/
build.noindex/task122-stage4-render-debug-hwp/
build.noindex/task122-stage4-render-debug-hwpx/
build.noindex/task122-stage4-overlay/
```

## 잔여 위험과 한계

- repository sample set에서 non-null `fill_mode` fixture를 확보하지 못했다. 실제 placement/tile 문서의 visual positive proof는 후속 fixture 확보 후 보강해야 한다.
- `none` 의미는 upstream CanvasKit layer replay와 WebCanvas 사이에 차이가 있을 수 있으나, 이번 구현은 WebCanvas와 기존 Swift bbox fallback 동작을 우선했다.
- tile draw cap 도달 시 public diagnostic은 추가하지 않았다. 현재 `CGTreeRenderer`에 unsupported diagnostics surface가 없으므로 향후 필요 시 별도 이슈로 다룬다.
- CoreGraphics image interpolation과 scale 차이에 따른 pixel-level diff는 여전히 남는다.

## 후속 제안

1. non-null `fill_mode` HWP/HWPX fixture를 확보해 placement/tile positive visual test를 추가한다.
2. `render-debug-compare.sh` output naming이 같은 basename의 HWP/HWPX를 같은 directory에서 덮는 문제를 별도 보강 후보로 등록한다.
3. #121 RawSvg/OLE/chart, #110 Placeholder/FormObject 작업에서도 이번 helper가 bbox fallback을 유지하는지 sample set으로 재확인한다.

## 작업지시자 승인 요청

이 보고서를 기준으로 #122 PR을 `devel` 대상으로 게시하고 리뷰를 요청한다. PR merge 후에는 `pr-merge-cleanup` 절차로 이슈 close, publish branch 삭제, local branch/worktree 정리를 수행한다.
