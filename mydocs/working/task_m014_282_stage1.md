# Task M014 #282 Stage 1 보고서 - native compositor inventory 정리

## 단계 목적

- 이슈: #282 Quick Look/Thumbnail native compositor를 rhwp-studio flow·overlay 구조로 보강
- 단계: Stage 1. renderer/compositor 구조 inventory와 구현 경로 확정
- 목표: Quick Look PNG, Quick Look PDF, Finder Thumbnail이 공유하는 render entry point와 `CGTreeRenderer`의 현재 pass 구조를 확인하고, #282 구현 경로와 before baseline을 확정한다.

이번 단계는 조사, baseline 생성, 구현계획 문서화만 수행했다. Swift production source, Xcode project, RustBridge source는 수정하지 않았다.

## 산출물

| 파일/경로 | 내용 |
|-----------|------|
| `mydocs/plans/task_m014_282_impl.md` | 293 lines. Stage 1-5 구현계획, 검증, 완료 기준 작성 |
| `mydocs/working/task_m014_282_stage1.md` | Stage 1 inventory, baseline, 구현 결정 정리 |
| `build.noindex/task282-stage1-overlay-metadata/` | #281 overlay metadata smoke 산출물 |
| `build.noindex/task282-stage1-before-basic/` | 기본 sample visual diff baseline |
| `build.noindex/task282-stage1-before-images/` | image-heavy sample visual diff baseline |

## 본문 변경 정도 / 본문 무손실 여부

- production Swift/Rust source 변경 없음.
- `mydocs/plans/task_m014_282_impl.md` 신규 추가만 수행.
- `build.noindex/` 산출물은 검증용이며 커밋하지 않는다.

## renderer entry point inventory

| 경로 | 현재 호출 | #282 영향 |
|------|-----------|-----------|
| Quick Look 단일 페이지 PNG | `HwpPreviewProvider.pngReply` -> `HwpPageImageRenderer.renderPage(..., policy: .skiaOptIn)` | Skia 성공 시 Swift compositor를 우회한다. CoreGraphics fallback 보강 범위를 PR에 명시해야 한다. |
| Quick Look 다중 페이지 PDF | `HwpPreviewPDFRenderer.render` -> page별 `HwpPageImageRenderer.renderPage(..., policy: .skiaOptIn)` | page renderer를 고치면 PDF loop도 같은 fallback policy를 사용한다. |
| Finder Thumbnail | `HwpThumbnailRenderCache.renderedPage` -> `HwpPageImageRenderer.renderFirstPage(...)` 기본 policy `.coreGraphicsOnly` | Thumbnail은 #282 CoreGraphics compositor 변경이 직접 적용되는 경로다. |
| visual diff harness | `NativePreviewRenderer.render` -> `HwpPageImageRenderer.renderPage(..., policy: coreGraphicsOnly)` | before/after 측정은 CoreGraphics compositor 효과를 직접 본다. |

## CGTreeRenderer inventory

| 항목 | 현재 상태 | 구현 판단 |
|------|-----------|-----------|
| page pass | white fill -> page background child -> direct page `BehindText` image -> foreground children | 이미 일부 behind ordering을 한다. 하지만 direct page child 중심이며 전역 overlay pass는 아니다. |
| column pass | direct column `BehindText` image -> non-behind children | column 내부에 한정된 ordering이다. nested tree 전체의 overlay 후보를 flow에서 제외하지 않는다. |
| InFrontOfText | 별도 pass 없음 | #282에서 flow 이후 pass를 명시해야 한다. |
| wrap normalization | `isBehindTextWrap`은 case-insensitive exact `BehindText`만 처리 | #281 `RhwpPageOverlayLayer(textWrap:)`의 normalization과 통일하는 편이 안전하다. |
| image drawing | `renderImage`가 `imageData`, decode, crop, effect, transform, destination rect를 처리 | overlay drawing은 이 로직을 재사용하도록 `CGTreeRenderer` 내부 API를 확장한다. |
| image effects | grayscale/blackWhite/brightness/contrast가 이미 구현됨 | overlay image도 같은 adjustment를 사용한다. blackWhite는 현재 grayscale에 가깝다는 한계가 있다. |
| watermark | `RhwpPageOverlayImage`에는 `watermarkPreset`, `bakedWatermark`가 있으나 renderer 구현 없음 | #116과 경계를 맞춰 최소 처리 또는 명시적 handoff가 필요하다. |

## 구현 경로 결정

Stage 2 구현 경로는 `HwpPageImageRenderer`의 CoreGraphics fallback 내부에서 compositor를 호출하는 방식으로 고정한다.

1. `renderCoreGraphicsPage`에서 `document.renderPageTree(at:)`를 한 번만 호출한다.
2. 같은 `tree`를 `document.pageOverlayImages(at:renderTree:)`에 전달해 #281 overlay metadata를 얻는다.
3. `CGTreeRenderer`에 pass/filter policy를 추가하거나, 얇은 `HwpNativePageCompositor`를 두어 다음 순서로 그린다.
   - background
   - BehindText overlay
   - flow excluding overlay images
   - InFrontOfText overlay
4. overlay image drawing은 `CGTreeRenderer`의 기존 image decode/crop/effect/transform 로직을 재사용한다.
5. Skia opt-in 성공 경로는 그대로 둔다. #282 결과는 CoreGraphics fallback과 Thumbnail path에 직접 적용되고, Quick Look에서는 Skia 실패 fallback 또는 `coreGraphicsOnly` 측정에서 관찰된다.
6. `preview-visual-diff-harness.sh` 등 `HwpPageImageRenderer.swift`를 직접 compile하는 script에는 `PageOverlayImages.swift`와 신규 compositor file을 compile list에 포함한다.

## overlay metadata baseline

실행:

```bash
./scripts/build-rust-macos.sh --verify-lock
./scripts/overlay-metadata-smoke.sh build.noindex/task282-stage1-overlay-metadata
```

처음에는 새 분리 worktree에 gitignored `Frameworks/universal/librhwp.a`가 없어 smoke가 실패했다. `build-rust-macos.sh --verify-lock`로 framework 산출물을 생성한 뒤 다시 실행해 통과했다. lock 변경은 발생하지 않았다.

| sample | UpstreamImages | Overlay | Behind | Front | TreeImages | EmbeddedAvailable | Wraps |
|--------|----------------|---------|--------|-------|------------|-------------------|-------|
| `request.hwp` | `1` | `0` | `0` | `0` | `1` | `1/1` | `TopAndBottom:1` |
| `hwpx-01.hwpx` | `2` | `0` | `0` | `0` | `2` | `2/2` | `TopAndBottom:2` |
| `tac-img-02.hwp` | `1` | `0` | `0` | `0` | `1` | `1/1` | `TopAndBottom:1` |
| `tac-img-02.hwpx` | `1` | `0` | `0` | `0` | `1` | `1/1` | `TopAndBottom:1` |
| `hwp-img-001.hwp` | `4` | `0` | `0` | `0` | `4` | `4/4` | `Square:1, TopAndBottom:3` |
| `img-start-001.hwp` | `0` | `0` | `0` | `0` | `0` | `0/0` | `-` |

해석:

- 현재 default sample set은 #281과 동일하게 `BehindText`/`InFrontOfText` positive fixture가 아니다.
- Stage 2-3에서 compositor 구조와 중복 렌더 방지는 검증할 수 있지만, overlay visual improvement는 positive fixture 없이는 증명하기 어렵다.

## visual diff baseline

공통 조건:

- Page: 1
- NativePolicy: `coreGraphicsOnly`
- Studio release: `v0.7.12`
- Studio resolved commit: `1899ef9bc2dfd1c6c0c4d18b192d253a2d0a1fb5`
- Viewport: `1400x1800`
- Settle: `120ms`
- Diff pixel threshold: `12`

실행:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task282-stage1-before-basic --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx
./scripts/preview-visual-diff-harness.sh build.noindex/task282-stage1-before-images --page 1 \
  samples/tac-img-02.hwp samples/tac-img-02.hwpx \
  samples/hwp-img-001.hwp samples/img-start-001.hwp
```

결과:

| sample | Status | StudioSize | NativeSize | ChangedPixels | ChangedPercent | MeanRGBDelta | MaxRGBDelta | NativeBackend | NativeMs |
|--------|--------|------------|------------|---------------|----------------|--------------|-------------|---------------|----------|
| `request.hwp` | OK | `1133x1587` | `567x794` | `325488/1798071` | `18.1021%` | `11.5796` | `255` | `coreGraphics` | `1118.3` |
| `hwpx-01.hwpx` | OK | `1587x2245` | `794x1123` | `540973/3562815` | `15.1839%` | `15.6722` | `255` | `coreGraphics` | `40.7` |
| `tac-img-02.hwp` | OK | `1587x2245` | `794x1123` | `147412/3562815` | `4.1375%` | `3.7228` | `255` | `coreGraphics` | `1065.3` |
| `tac-img-02.hwpx` | OK | `1587x2245` | `794x1123` | `129783/3562815` | `3.6427%` | `3.3924` | `255` | `coreGraphics` | `7.3` |
| `hwp-img-001.hwp` | OK | `1587x2245` | `794x1123` | `279494/3562815` | `7.8448%` | `8.2731` | `255` | `coreGraphics` | `18.6` |
| `img-start-001.hwp` | OK | `1587x2244` | `794x1123` | `514115/3561228` | `14.4365%` | `15.4773` | `255` | `coreGraphics` | `34.0` |

수치는 #281 Stage 4 handoff와 같은 baseline이다. Stage 2-4 이후에도 같은 sample set으로 after를 측정해 regression 여부를 확인한다.

## 검증 결과

실행:

```bash
rg -n "renderPage\\(|renderCoreGraphicsPage|CGTreeRenderer|pageOverlayImages|textWrap|BehindText|InFrontOfText" \
  Sources/Shared Sources/RhwpCoreBridge Sources/QLExtension Sources/ThumbnailExtension scripts
rg -n "BehindText|InFrontOfText|behindText|inFrontOfText|behind_text|in_front" samples
rg -n "PageOverlayImages\\.swift|RhwpPageOverlay|pageOverlayImages" .github project.yml scripts Sources mydocs
./scripts/build-rust-macos.sh --verify-lock
./scripts/overlay-metadata-smoke.sh build.noindex/task282-stage1-overlay-metadata
./scripts/preview-visual-diff-harness.sh build.noindex/task282-stage1-before-basic --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx
./scripts/preview-visual-diff-harness.sh build.noindex/task282-stage1-before-images --page 1 \
  samples/tac-img-02.hwp samples/tac-img-02.hwpx \
  samples/hwp-img-001.hwp samples/img-start-001.hwp
```

결과:

- renderer entry point와 `CGTreeRenderer` pass 구조를 확인했다.
- `samples/` text search에서 `BehindText`/`InFrontOfText` 문자열은 찾지 못했다. binary HWP와 compressed HWPX 특성상 이것만으로 fixture 부재를 확정하지는 않지만, overlay metadata smoke도 positive case를 찾지 못했다.
- `build-rust-macos.sh --verify-lock`: 통과. 새 worktree framework 산출물 생성, lock 검증 완료.
- overlay metadata smoke: 6개 sample 모두 OK.
- visual diff harness: 6개 sample 모두 OK.

## 잔여 위험

- positive overlay fixture가 없어 Stage 2-3의 실제 overlay ordering 개선을 수치로 증명하기 어렵다.
- Quick Look은 `.skiaOptIn`을 사용하므로 Skia 성공 시 CoreGraphics compositor 변경을 우회한다. Thumbnail과 harness는 CoreGraphics path를 직접 탄다.
- `CGTreeRenderer` 내부 image rendering 함수가 private이라 overlay drawing 재사용을 위해 신중한 API 정리가 필요하다.
- `preview-visual-diff-harness.sh`는 현재 `PageOverlayImages.swift`를 compile list에 포함하지 않는다. Stage 2에서 `HwpPageImageRenderer`가 overlay model을 직접 참조하면 script 업데이트가 필요하다.
- watermark multiply/opacity는 현재 code path에서 구현되어 있지 않다. #116과 책임 경계를 다시 확인해야 한다.

## 다음 단계 영향

Stage 2는 다음 순서로 진행한다.

1. `renderCoreGraphicsPage`에서 tree와 overlay metadata를 한 번만 수집한다.
2. `CGTreeRenderer`에 render pass/filter policy를 추가한다.
3. flow pass에서 `BehindText`/`InFrontOfText` overlay 후보를 제외한다.
4. background/flow pass 분리까지만 먼저 안정화하고, 실제 overlay image drawing은 Stage 3에서 구현한다.
5. `preview-visual-diff-harness.sh`와 관련 smoke compile list를 함께 갱신한다.

## 승인 요청

Stage 1 결과를 기준으로 Stage 2 `native compositor policy와 pass 분리 구현` 진입 승인을 요청한다.
