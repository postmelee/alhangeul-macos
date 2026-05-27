# Task M014 #281 최종 보고서 초안 - PageLayerTree overlay image metadata 입력 연결

## 작업 개요

- 이슈: #281 PageLayerTree overlay image metadata를 Swift preview 입력으로 연결
- 마일스톤: M014 (`v0.1.4 Native Preview/Viewer Parity`)
- 브랜치: `local/task281`
- 목표: #282 native compositor가 사용할 page overlay image metadata 입력 contract를 Swift/macOS bridge에 준비한다.

## 최종 결론 초안

#281은 renderer 출력 개선 작업이 아니라 compositor 입력 contract 작업으로 완료됐다.

- upstream `get_page_overlay_images_native`를 `rhwp_page_overlay_images` C ABI로 노출했다.
- Swift `RhwpPageOverlayImageSet` provider를 추가했다.
- compact overlay JSON을 primary source로 사용하고, render tree traversal로 `binDataId`, bytes availability, crop/fill/original size를 보충한다.
- `v0.7.13`의 `bakedWatermark` field를 optional로 수용해 core update 후 이중 watermark/filter 처리를 피할 수 있게 했다.
- smoke script로 sample별 overlay metadata와 embedded image bytes availability를 반복 측정할 수 있게 했다.
- visual diff baseline을 생성했지만, 아직 compositor가 metadata를 사용하지 않으므로 수치는 개선 결과가 아니라 #282 이전 기준값이다.

## 변경 요약

| 영역 | 내용 |
|------|------|
| RustBridge | `rhwp_page_overlay_images` ABI 추가 |
| FFI manifest/lock | `rhwp-ffi-symbols.txt`, `rhwp-core.lock` 갱신 |
| Swift bridge | `pageOverlayImagesJSON(at:)`, `RhwpPageOverlayImageSet`, `RhwpPageOverlayImage` 추가 |
| Xcode project | `PageOverlayImages.swift`를 HostApp/QLExtension/ThumbnailExtension에 포함 |
| Smoke | `scripts/overlay-metadata-smoke.sh`, `scripts/overlay_metadata_smoke.swift` 추가 |
| Reports | Stage 1-4 보고서 작성 |

## 핵심 관찰

- `v0.7.12`와 `v0.7.13` 모두 overlay/PageLayerTree native API를 제공한다.
- `v0.7.13`은 `PaintOp::Image`에 resolved payload와 `bakedWatermark` 의미를 추가한다.
- compact overlay JSON은 Studio path와 가깝지만 `binDataId`, `crop`, `fillMode`, `originalSize`를 직접 제공하지 않는다.
- 현재 repository sample set에서는 `BehindText`/`InFrontOfText` positive fixture를 찾지 못했다.
- `imageCount`는 page의 전체 image op count일 수 있으며 behind/front overlay 수와 다르다.
- Studio capture `overlayCount`는 DOM snapshot rect union용 metadata라 Swift overlay image count와 직접 비교하면 안 된다.

## Visual Baseline

| sample | ChangedPercent | MeanRGBDelta | MaxRGBDelta |
|--------|----------------|--------------|-------------|
| `request.hwp` | `18.1021%` | `11.5796` | `255` |
| `hwpx-01.hwpx` | `15.1839%` | `15.6722` | `255` |
| `tac-img-02.hwp` | `4.1375%` | `3.7228` | `255` |
| `tac-img-02.hwpx` | `3.6427%` | `3.3924` | `255` |
| `hwp-img-001.hwp` | `7.8448%` | `8.2731` | `255` |
| `img-start-001.hwp` | `14.4365%` | `15.4773` | `255` |

## #282 Handoff

#282는 다음 순서로 진행하는 것이 좋다.

1. overlay-positive fixture를 확보한다.
2. `RhwpDocument.pageOverlayImages(at:)`를 compositor 입력으로 연결한다.
3. background -> `behind` -> flow -> `front` 순서의 pass를 명시한다.
4. `source.data`를 우선 사용하고, 필요하면 `source.binDataId`로 fallback한다.
5. `bakedWatermark == true`이면 watermark/filter를 중복 적용하지 않는다.
6. 같은 sample set으로 before/after visual diff를 비교한다.

## 남은 한계

- `v0.7.13` core pin update는 아직 하지 않았다.
- `bakedWatermark` actual payload는 현재 lock에서 관찰하지 못했다.
- external linked image, filename, base directory 개선은 별도 작업이다.
- LaunchServices local DB에는 Stage 3 xcodebuild 후 삭제된 DerivedData app 경로가 stale entry로 남았다. provider root는 `/Applications/Alhangeul.app`만 보였고, 전역 reset은 수행하지 않았다.

## 검증 요약

- `./scripts/build-rust-macos.sh --update-lock`
- `./scripts/build-rust-macos.sh --verify-lock`
- `./scripts/check-no-appkit.sh`
- `./scripts/verify-rhwp-studio-assets.sh`
- `./scripts/overlay-metadata-smoke.sh build.noindex/task281-stage3-metadata`
- `./scripts/preview-visual-diff-harness.sh build.noindex/task281-stage4-basic --page 1 ...`
- `./scripts/preview-visual-diff-harness.sh build.noindex/task281-stage4-images --page 1 ...`
- `xcodegen generate`
- `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData-task281-stage3 CODE_SIGNING_ALLOWED=NO build`
- `git diff --check`
