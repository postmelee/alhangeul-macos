# Task M014 #281 Stage 2 보고서 - overlay metadata Swift 모델 추가

## 단계 개요

- 이슈: #281 PageLayerTree overlay image metadata를 Swift preview 입력으로 연결
- 단계: Stage 2. Swift overlay metadata 모델과 provider 구현
- 목표: #282 compositor가 사용할 page별 overlay image metadata 입력 contract를 Swift에서 호출 가능한 형태로 추가한다.

이번 단계에서는 `v0.7.13` core pin update를 하지 않았다. 현재 lock인 `v0.7.12` 위에서 upstream compact overlay API를 C ABI로 노출하고, Swift model은 `v0.7.13`의 `bakedWatermark` field를 optional로 수용하도록 구현했다.

## 변경 파일

| 파일 | 변경 |
|------|------|
| `RustBridge/src/lib.rs` | `rhwp_page_overlay_images` C ABI 추가. upstream `DocumentCore::get_page_overlay_images_native(page)` 결과 JSON을 caller-owned C string으로 반환한다. |
| `rhwp-ffi-symbols.txt` | 새 ABI symbol `rhwp_page_overlay_images` 추가. |
| `Sources/RhwpCoreBridge/RhwpDocument.swift` | `pageOverlayImagesJSON(at:)` wrapper 추가. page range를 Swift에서 먼저 검증하고 Rust string lifetime을 해제한다. |
| `Sources/RhwpCoreBridge/PageOverlayImages.swift` | Swift overlay metadata model/provider 추가. compact overlay JSON decode와 render tree supplemental merge를 담당한다. |
| `rhwp-core.lock` | 같은 `v0.7.12` resolved commit을 유지한 채 RustBridge ABI 변경으로 생성 산출물 sha256/size 갱신. |

`Frameworks/`와 `build.noindex/`는 검증 중 생성된 ignored 산출물이며 커밋 대상이 아니다.

## Swift 입력 contract

추가한 주요 타입:

| 타입 | 역할 |
|------|------|
| `RhwpPageOverlayImageSet` | page 단위 overlay metadata container. `behind`, `front`, upstream `imageCount`, 계산값 `overlayImageCount`를 제공한다. |
| `RhwpPageOverlayLayer` | `behindText`, `inFrontOfText` layer 분류. upstream compact JSON camelCase와 render tree PascalCase를 모두 normalize한다. |
| `RhwpPageOverlayImage` | bbox, source, effect/brightness/contrast, watermark, `bakedWatermark`, transform, crop/fill/original size를 보존한다. |
| `RhwpPageOverlayImageSource` | compact overlay의 decoded bytes와 render tree에서 보충한 `binDataId`/bytes availability를 함께 표현한다. |
| `RhwpPageOverlayTransform` | compact overlay JSON의 `horzFlip`/`vertFlip`과 render tree의 `horz_flip`/`vert_flip` 양쪽 key를 decode한다. |

provider 호출:

```swift
let overlays = document.pageOverlayImages(at: pageIndex)
```

처리 순서:

1. page range를 확인한다.
2. render tree를 읽어 `BehindText`/`InFrontOfText` image node의 `binDataId`, bytes availability, crop/fill/original size를 supplemental metadata로 수집한다.
3. 새 C ABI `rhwp_page_overlay_images`로 compact overlay JSON을 가져온다.
4. compact JSON의 `behind`/`front` image를 decode하고 bbox + layer 기준으로 supplemental metadata를 병합한다.
5. compact JSON이 실패하면 render tree supplemental metadata만으로 fallback image set을 만든다.

## 구현 판단

compact overlay JSON은 Studio path와 가장 가까운 입력이다. 다만 upstream `v0.7.12`와 `v0.7.13` 모두 compact overlay JSON에는 `binDataId`, `crop`, `fillMode`, `originalSize`가 없다. 그래서 Stage 2에서는 compact overlay를 primary source로 두고 render tree traversal을 supplemental source로 병합했다.

`bakedWatermark`는 현재 lock `v0.7.12`에서는 나오지 않지만 `v0.7.13`에서 추가된 field다. Swift model에 optional로 포함했으므로 core update 후 #282 compositor가 이중 watermark/filter 처리를 피할 수 있다.

PageLayerTree 전체 JSON parser는 이번 단계에서 만들지 않았다. #282의 1차 compositor 입력에는 compact overlay + render tree 보충이 더 작고 안정적이며, 전체 PageLayerTree parser는 필요한 field가 더 늘어나는 시점에 별도 판단한다.

## smoke 관찰

임시 probe를 `build.noindex/task281_overlay_probe.swift`로 작성해 커밋하지 않고 실행했다.

실행:

```bash
build.noindex/task281-overlay-probe \
  samples/basic/request.hwp \
  samples/tac-img-02.hwp \
  samples/tac-img-02.hwpx \
  samples/hwp-img-001.hwp \
  samples/img-start-001.hwp
```

결과:

| sample | upstream imageCount | overlayImageCount | behind | front | renderable | binLinked |
|--------|---------------------|-------------------|--------|-------|------------|-----------|
| `request.hwp` | 1 | 0 | 0 | 0 | 0 | 0 |
| `tac-img-02.hwp` | 1 | 0 | 0 | 0 | 0 | 0 |
| `tac-img-02.hwpx` | 1 | 0 | 0 | 0 | 0 | 0 |
| `hwp-img-001.hwp` | 4 | 0 | 0 | 0 | 0 | 0 |
| `img-start-001.hwp` | 0 | 0 | 0 | 0 | 0 | 0 |

추가 후보 샘플도 확인했다.

```bash
build.noindex/task281-overlay-probe \
  samples/pic-crop-01.hwp samples/pic-in-head-01.hwp samples/pic-in-head-02.hwp \
  samples/20250130-hongbo.hwp samples/20250130-hongbo-no.hwp \
  samples/20250130-hongbo_saved.hwp samples/honbo-save.hwp \
  samples/k-water-rfp.hwp samples/kps-ai.hwp samples/exam_math.hwp \
  samples/exam_kor.hwp samples/group-drawing-02.hwp samples/draw-group.hwp \
  samples/group-box.hwp samples/shape-group-02.hwp
```

관찰:

- 새 C ABI와 Swift provider 호출은 정상 동작했다.
- 확인한 샘플에서는 `imageCount`가 1-17인 문서가 있었지만 `behind`/`front` overlay는 모두 0이었다.
- upstream compact overlay의 `imageCount`는 behind/front overlay 수가 아니라 page의 전체 image op count를 포함할 수 있다. 그래서 Swift model에 `imageCount`와 별도로 `overlayImageCount`를 제공했다.
- 일부 샘플에서 `LAYOUT_OVERFLOW` 로그가 출력됐지만 probe 자체는 성공했다. 이 로그는 기존 core layout 진단 출력이며 새 provider 실패는 아니다.

## 검증

실행:

```bash
./scripts/build-rust-macos.sh --update-lock
./scripts/build-rust-macos.sh --verify-lock
./scripts/check-no-appkit.sh
./scripts/verify-rhwp-studio-assets.sh
swiftc -parse-as-library \
  -module-cache-path build.noindex/task281-stage2-swift-module-cache \
  -Xcc -fmodules-cache-path=build.noindex/task281-stage2-clang-module-cache \
  -I Frameworks/modulemap \
  Sources/RhwpCoreBridge/RhwpDocument.swift \
  Sources/RhwpCoreBridge/RenderTree.swift \
  Sources/RhwpCoreBridge/PageOverlayImages.swift \
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
  -o build.noindex/task281-stage2-syntax-check
rg -n "rhwp_page_overlay_images|RhwpPageOverlay|bakedWatermark|binDataAvailable|imageCount" \
  RustBridge/src/lib.rs rhwp-ffi-symbols.txt Sources/RhwpCoreBridge
rg -n "rhwp_page_overlay_images|sha256|size" \
  Frameworks/generated_rhwp.h Frameworks/modulemap/rhwp.h rhwp-core.lock rhwp-ffi-symbols.txt
git diff --check
```

결과:

- `build-rust-macos.sh --update-lock` 통과. generated header와 local `Frameworks/Rhwp.xcframework`에 `rhwp_page_overlay_images`가 포함됐다.
- `build-rust-macos.sh --verify-lock` 통과. source lock, generated header hash, FFI symbol manifest, staticlib artifact 정합성을 확인했다.
- `check-no-appkit.sh` 통과. `Sources/RhwpCoreBridge`에 AppKit/UIKit 의존은 추가하지 않았다.
- `verify-rhwp-studio-assets.sh` 통과.
- Swift compile 검증 통과.
- `git diff --check` 통과.

## 한계와 다음 단계

- Stage 2는 metadata provider까지만 구현했다. 실제 CGContext 합성 순서 변경과 visual diff 개선은 #282 범위다.
- 이번 샘플 smoke에서는 behind/front overlay-positive 문서를 찾지 못했다. Stage 3에서는 더 넓은 sample scan 또는 fixture를 통해 overlay-positive case를 확보해야 한다.
- `v0.7.13`의 resolved image payload와 `bakedWatermark` 실제 값은 현재 lock `v0.7.12`에서 관찰할 수 없다. core update task 이후 재측정이 필요하다.
- compact overlay JSON이 resource identity를 직접 주지 않기 때문에 bbox + layer matching으로 render tree metadata를 보충한다. 동일 bbox overlay가 여러 개일 경우 matching은 순서에 의존한다.

Stage 3에서는 metadata smoke를 정식 script 또는 harness output으로 고정하고, sample별 overlay count, bytes availability, `binDataId`, crop/fill/transform 보존 여부를 보고서에 남긴다.
