# Task M014 #282 구현 계획서

수행계획서: `mydocs/plans/task_m014_282.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #282 Quick Look/Thumbnail native compositor를 rhwp-studio flow·overlay 구조로 보강
- 마일스톤: M014 (`v0.1.4 Native Preview/Viewer Parity`)
- 브랜치: `local/task282`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac-task282`
- 기준 브랜치: `devel`
- 현재 앱 core lock: `rhwp-core.lock` `v0.7.12` (`1899ef9bc2dfd1c6c0c4d18b192d253a2d0a1fb5`)
- 목표: CoreGraphics fallback renderer가 #281 overlay metadata를 사용해 `background -> BehindText overlay -> flow -> InFrontOfText overlay` 순서를 명시적으로 합성하게 만든다.

## 구현 원칙

- #282의 1차 대상은 Swift/CoreGraphics fallback compositor다.
- Quick Look `skiaOptIn` 성공 경로는 기존 Skia PNG를 유지하고, Skia 실패 또는 `coreGraphicsOnly` 경로에서 native compositor를 적용한다.
- Finder Thumbnail은 현재 `coreGraphicsOnly` 경로를 사용하므로 #282 변경이 직접 적용된다.
- `RhwpDocument.renderPageTree(at:)` 결과를 한 번만 얻고, #281의 `pageOverlayImages(at:renderTree:)` overload로 overlay metadata를 보충한다.
- 기존 `CGTreeRenderer`의 도형/텍스트/이미지 decode/crop/effect/transform 로직을 재사용한다.
- overlay 후보는 flow pass에서 중복 렌더링하지 않는다.
- `Sources/RhwpCoreBridge`에는 AppKit/UIKit/WebKit 의존을 추가하지 않는다.
- upstream rhwp 수정, unreleased commit pin, core dependency update는 하지 않는다.
- watermark/effect/fill/tile 세부 parity는 안전하게 적용 가능한 최소 범위만 반영하고, 잔여 차이는 #116/#122로 넘긴다.

## 현재 기준 관찰

| 영역 | 현재 관찰 | 구현 판단 |
|------|-----------|-----------|
| Quick Look PNG | `HwpPreviewProvider.pngReply`가 `HwpPageImageRenderer.renderPage(..., policy: .skiaOptIn)` 호출 | Skia 성공 시 compositor를 우회한다. CoreGraphics fallback을 보강하고 PR에서 범위를 명시한다. |
| Quick Look PDF | `HwpPreviewPDFRenderer.render`가 page별 `HwpPageImageRenderer.renderPage`를 호출 | 단일 page render path를 고치면 다중 페이지 PDF에도 같은 fallback policy가 적용된다. |
| Thumbnail | `HwpThumbnailRenderCache`가 `renderFirstPage(..., embeddedThumbnailPolicy: .never)` 호출, 기본 policy는 `.coreGraphicsOnly` | Thumbnail은 #282 CoreGraphics compositor 변경의 직접 수혜 경로다. |
| CoreGraphics fallback | `renderCoreGraphicsPage`가 `renderPageTree(at:)` 후 `CGTreeRenderer.render(tree:)` 1회 호출 | 이 지점에서 render tree와 overlay metadata를 한 번만 수집해 compositor에 넘긴다. |
| `CGTreeRenderer` page pass | page background -> direct page `BehindText` image -> foreground children | direct page child 중심이며 `InFrontOfText` pass가 없다. |
| `CGTreeRenderer` column pass | column direct child `BehindText` image -> non-behind children | nested tree 전체의 overlay 후보를 전역 pass로 분리하지 않는다. |
| image rendering | `renderImage`가 `imageData`, decode, crop, effect, transform, fill destination을 처리 | overlay drawing은 이 로직을 재사용하도록 `CGTreeRenderer` 내부 API를 확장한다. |
| #281 overlay provider | compact overlay JSON + render tree supplement merge 제공 | `pageOverlayImages(at:renderTree:)`로 중복 decode 없이 compositor 입력을 만든다. |
| sample fixture | 기본 6개 sample의 `BehindText`/`InFrontOfText` overlay count는 모두 0 | 합성 구조 검증은 가능하지만 positive overlay visual improvement는 별도 fixture가 필요하다. |
| harness compile list | `preview-visual-diff-harness.sh`가 아직 `PageOverlayImages.swift`를 compile list에 포함하지 않음 | #282에서 `HwpPageImageRenderer`가 overlay type을 참조하면 harness script도 함께 수정해야 한다. |

## 산출물 구조

| 파일 | 역할 |
|------|------|
| `mydocs/plans/task_m014_282_impl.md` | 단계별 구현 범위, 검증, 완료 기준 |
| `mydocs/working/task_m014_282_stage1.md` | renderer/compositor inventory와 구현 경로 결정 |
| `mydocs/working/task_m014_282_stage2.md` | compositor pass 분리 구현 보고 |
| `mydocs/working/task_m014_282_stage3.md` | overlay image drawing/effect 최소 parity 구현 보고 |
| `mydocs/working/task_m014_282_stage4.md` | Quick Look/Thumbnail smoke와 visual diff 측정 보고 |
| `mydocs/working/task_m014_282_stage5.md` | 후속 이슈 handoff 보고 |
| `mydocs/report/task_m014_282_report.md` | 최종 결과와 한계, 후속 작업 정리 |
| `build.noindex/task282-*` | 검증 산출물. 커밋하지 않는다. |

## Stage 1. renderer/compositor 구조 inventory와 구현 경로 확정

### 목표

Quick Look PNG, Quick Look PDF, Finder Thumbnail이 공유하는 render entry point와 `CGTreeRenderer`의 현재 pass 구조를 확인하고, #282 구현 경로와 before baseline을 확정한다.

### 작업

- Quick Look/Thumbnail render entry point를 확인한다.
- `HwpPageImageRenderer.renderCoreGraphicsPage`의 tree decode와 renderer 호출 지점을 확인한다.
- `CGTreeRenderer`의 page background, `BehindText`, normal flow, image effect 처리 현황을 확인한다.
- #281 overlay metadata smoke를 현재 `devel` 기준으로 다시 실행한다.
- #282 before visual diff baseline을 생성한다.
- Stage 2 이후 변경해야 할 compile script 목록을 확인한다.

### 산출물

- `mydocs/plans/task_m014_282_impl.md`
- `mydocs/working/task_m014_282_stage1.md`
- `build.noindex/task282-stage1-overlay-metadata/`
- `build.noindex/task282-stage1-before-basic/`
- `build.noindex/task282-stage1-before-images/`

### 검증

```bash
rg -n "renderPage\\(|renderCoreGraphicsPage|CGTreeRenderer|pageOverlayImages|textWrap|BehindText|InFrontOfText" \
  Sources/Shared Sources/RhwpCoreBridge Sources/QLExtension Sources/ThumbnailExtension scripts
./scripts/build-rust-macos.sh --verify-lock
./scripts/overlay-metadata-smoke.sh build.noindex/task282-stage1-overlay-metadata
./scripts/preview-visual-diff-harness.sh build.noindex/task282-stage1-before-basic --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx
./scripts/preview-visual-diff-harness.sh build.noindex/task282-stage1-before-images --page 1 \
  samples/tac-img-02.hwp samples/tac-img-02.hwpx \
  samples/hwp-img-001.hwp samples/img-start-001.hwp
git diff --check
```

### 완료 기준

- Quick Look/Thumbnail 공통 render entry point와 policy 차이가 문서화된다.
- `CGTreeRenderer` pass 분리 한계가 문서화된다.
- before visual diff baseline과 overlay metadata baseline이 생성된다.
- Stage 2 구현 경로가 확정된다.
- production source는 변경하지 않는다.

### 커밋 메시지

```text
Task #282 Stage 1: native compositor inventory 정리
```

## Stage 2. native compositor policy와 pass 분리 구현

### 목표

CoreGraphics fallback에서 render tree를 한 번만 decode하고, page background와 flow pass를 명시적으로 분리할 수 있는 renderer/compositor 구조를 추가한다.

### 작업

- `HwpPageImageRenderer.renderCoreGraphicsPage`에서 `tree`와 `overlays`를 함께 수집한다.
- 필요 시 `HwpNativePageCompositor` 또는 `CGTreeRenderer` render mode를 추가한다.
- `CGTreeRenderer`에 pass/filter policy를 추가한다.
  - page background only
  - flow excluding overlay images
  - 기존 all render fallback
- `RhwpPageOverlayLayer(textWrap:)`와 같은 normalization을 사용해 `BehindText`/`InFrontOfText` 후보를 flow pass에서 제외한다.
- 기존 `render(tree:)` 호출자는 backward-compatible하게 유지한다.
- harness compile list에 `PageOverlayImages.swift`와 신규 compositor file을 포함한다.

### 산출물

- `Sources/Shared/HwpPageImageRenderer.swift`
- `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- 필요 시 `Sources/Shared/HwpNativePageCompositor.swift`
- 필요 시 `scripts/preview-visual-diff-harness.sh`
- 필요 시 `scripts/smoke-quicklook-skia-policy.sh`, `scripts/compare-quicklook-pdf-renderers.sh`
- `mydocs/working/task_m014_282_stage2.md`

### 검증

```bash
./scripts/check-no-appkit.sh
./scripts/overlay-metadata-smoke.sh build.noindex/task282-stage2-overlay-metadata
./scripts/preview-visual-diff-harness.sh build.noindex/task282-stage2-basic --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug \
  -derivedDataPath build.noindex/DerivedData-task282-stage2 CODE_SIGNING_ALLOWED=NO build
git diff --check
```

### 완료 기준

- CoreGraphics fallback이 compositor 구조를 통해 page를 렌더한다.
- overlay 후보가 flow pass에서 중복 렌더링되지 않는다.
- 기존 `CGTreeRenderer.render(tree:)` 사용자는 깨지지 않는다.
- Quick Look/Thumbnail target build가 통과한다.

### 커밋 메시지

```text
Task #282 Stage 2: native compositor pass 분리
```

## Stage 3. overlay image drawing과 effect/watermark 최소 parity 보강

### 목표

#281 overlay image metadata를 실제 CGContext overlay pass에서 그릴 수 있게 하고, 기존 image decode/crop/effect/transform 로직을 재사용한다.

### 작업

- `RhwpPageOverlayImage` drawing path를 추가한다.
- image source 선택 순서를 구현한다.
  - `source.data` 우선
  - `source.binDataId` fallback
  - bytes가 없으면 skip
- overlay bbox, transform, crop/fill destination을 기존 image rendering과 맞춘다.
- grayscale/blackWhite/brightness/contrast는 기존 image adjustment와 같은 기준을 사용한다.
- `bakedWatermark == true`인 경우 중복 watermark 처리를 피한다.
- watermark multiply/opacity가 현재 core payload에서 관찰되지 않으면 구현 범위를 문서화하고 #116으로 넘긴다.

### 산출물

- `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- 필요 시 `Sources/Shared/HwpNativePageCompositor.swift`
- 필요 시 `Sources/RhwpCoreBridge/PageOverlayImages.swift`
- `mydocs/working/task_m014_282_stage3.md`

### 검증

```bash
./scripts/check-no-appkit.sh
./scripts/overlay-metadata-smoke.sh build.noindex/task282-stage3-overlay-metadata
./scripts/preview-visual-diff-harness.sh build.noindex/task282-stage3-images --page 1 \
  samples/tac-img-02.hwp samples/tac-img-02.hwpx \
  samples/hwp-img-001.hwp samples/img-start-001.hwp
git diff --check
```

### 완료 기준

- overlay metadata가 있을 때 behind/front pass에서 draw 시도할 수 있다.
- 기존 sample에서 regression 없이 visual diff harness가 통과한다.
- positive fixture 부재로 개선을 증명할 수 없는 경우 한계가 stage report에 기록된다.

### 커밋 메시지

```text
Task #282 Stage 3: overlay image drawing 연결
```

## Stage 4. Quick Look/Thumbnail 통합 smoke와 visual diff 측정

### 목표

Quick Look PNG/PDF와 Finder Thumbnail 경로가 같은 CoreGraphics compositor policy를 공유하는지 확인하고, before/after visual diff를 정리한다.

### 작업

- Stage 1 baseline과 같은 sample set으로 after visual diff를 생성한다.
- Thumbnail maximum pixel size 경로에서 compositor output이 생성되는지 확인한다.
- Quick Look PDF page loop에서 같은 `HwpPageImageRenderer` 경로가 쓰이는지 확인한다.
- Skia opt-in 성공 경로와 CoreGraphics fallback 적용 범위를 문서화한다.
- 필요 시 registration hygiene는 표준 smoke helper 범위 안에서만 수행한다.

### 산출물

- `build.noindex/task282-stage4-*`
- `mydocs/working/task_m014_282_stage4.md`

### 검증

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task282-stage4-basic --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx
./scripts/preview-visual-diff-harness.sh build.noindex/task282-stage4-images --page 1 \
  samples/tac-img-02.hwp samples/tac-img-02.hwpx \
  samples/hwp-img-001.hwp samples/img-start-001.hwp
./scripts/smoke-quicklook-skia-policy.sh build.noindex/task282-stage4-skia-policy \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug \
  -derivedDataPath build.noindex/DerivedData-task282-stage4 CODE_SIGNING_ALLOWED=NO build
git diff --check
```

### 완료 기준

- before/after visual diff가 같은 sample set으로 기록된다.
- Quick Look/Thumbnail 공유 policy와 Skia/CoreGraphics 적용 범위가 명확히 정리된다.
- 개발 산출물 registration 상태가 보고서에 남는다.

### 커밋 메시지

```text
Task #282 Stage 4: compositor smoke와 visual diff 정리
```

## Stage 5. 최종 handoff와 후속 이슈 정리

### 목표

#282의 결과와 한계를 정리하고, #116/#122/#121/#110에 영향을 주는 발견 사항을 다음 작업자가 바로 사용할 수 있게 남긴다.

### 작업

- Stage 2-4 결과를 통합해 최종 보고서 초안을 작성한다.
- #116 watermark/effect, #122 fill/tile/placement, #121 resource object, #110 Placeholder/FormObject에 넘길 내용을 정리한다.
- positive overlay fixture가 여전히 없으면 fixture 확보 후속을 명시한다.
- 오늘할일 #282 상태를 단계 완료/최종 보고 대기 상태로 갱신한다.

### 산출물

- `mydocs/working/task_m014_282_stage5.md`
- `mydocs/report/task_m014_282_report.md`
- `mydocs/orders/20260527.md`

### 검증

```bash
rg -n "#116|#122|#121|#110|#282|Skia|CoreGraphics|overlay|ChangedPercent" \
  mydocs/working/task_m014_282_stage*.md mydocs/report/task_m014_282_report.md
git diff --check
git status --short --branch
```

### 완료 기준

- 후속 작업의 입력/한계가 최종 보고서에 정리된다.
- PR 생성 전 필요한 검증과 잔여 위험이 명확하다.

### 커밋 메시지

```text
Task #282 Stage 5: compositor handoff 정리
```
