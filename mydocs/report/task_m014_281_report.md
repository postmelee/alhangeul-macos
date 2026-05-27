# Task M014 #281 최종 보고서 - PageLayerTree overlay image metadata 입력 연결

## 작업 개요

- 이슈: #281 PageLayerTree overlay image metadata를 Swift preview 입력으로 연결
- 마일스톤: M014 (`v0.1.4 Native Preview/Viewer Parity`)
- 브랜치: `local/task281`
- 목표: #282 native compositor가 사용할 page overlay image metadata 입력 contract를 Swift/macOS bridge에 준비한다.

## 작업 요약

#281은 #282 native compositor가 사용할 overlay image 입력 contract를 Swift/macOS bridge까지 연결하는 작업이다. 이번 PR은 실제 compositor 순서나 CGContext drawing을 변경하지 않고, core가 제공하는 PageLayerTree/overlay image metadata를 Swift preview 계층에서 사용할 수 있는 구조와 smoke 측정 기반을 준비했다.

- Stage 1: `v0.7.12` lock과 upstream `v0.7.13`의 overlay/PageLayerTree API 차이를 inventory로 정리했다.
- Stage 2: RustBridge C ABI와 Swift 모델/provider를 추가했다.
- Stage 3: overlay metadata smoke script와 Xcode project 반영을 완료했다.
- Stage 4: visual diff baseline과 #282 handoff를 문서화했다.

## 최종 결론

#281은 renderer 출력 개선 작업이 아니라 compositor 입력 contract 작업으로 완료됐다. 따라서 visual diff 수치는 아직 개선값이 아니라 #282 이전 기준값이다.

- upstream `get_page_overlay_images_native`를 `rhwp_page_overlay_images` C ABI로 노출했다.
- Swift `RhwpPageOverlayImageSet` provider를 추가했다.
- compact overlay JSON을 primary source로 사용하고, render tree traversal로 `binDataId`, bytes availability, crop/fill/original size를 보충한다.
- `v0.7.13`의 `bakedWatermark` field를 optional로 수용해 core update 후 이중 watermark/filter 처리를 피할 수 있게 했다.
- smoke script로 sample별 overlay metadata와 embedded image bytes availability를 반복 측정할 수 있게 했다.
- visual diff baseline을 생성했지만, 아직 compositor가 metadata를 사용하지 않으므로 수치는 개선 결과가 아니라 #282 이전 기준값이다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 | 영향 |
|------|------|------|
| `RustBridge/src/lib.rs` | `rhwp_page_overlay_images` C ABI 추가 | Swift에서 page별 compact overlay JSON을 조회할 수 있다. |
| `rhwp-ffi-symbols.txt` | 신규 ABI symbol 추가 | FFI 표면 검증 대상에 overlay API가 포함된다. |
| `Sources/RhwpCoreBridge/RhwpDocument.swift` | `pageOverlayImagesJSON(at:)` raw JSON accessor 추가 | AppKit 의존 없이 bridge 계층에서 metadata를 읽는다. |
| `Sources/RhwpCoreBridge/PageOverlayImages.swift` | `RhwpPageOverlayImageSet`, layer/source/transform 모델과 merge provider 추가 | #282 compositor 입력으로 사용할 typed metadata를 제공한다. |
| `rhwp-core.lock` | Rust artifact hash 갱신 | core pin은 `v0.7.12` 그대로 유지하고 local RustBridge 산출물만 재생성했다. |
| `Alhangeul.xcodeproj/project.pbxproj` | `PageOverlayImages.swift` source phase 반영 | HostApp, Quick Look, Thumbnail target에서 신규 Swift 모델을 빌드한다. |
| `scripts/overlay-metadata-smoke.sh` | smoke entrypoint 추가 | sample set의 overlay/tree image metadata를 반복 측정한다. |
| `scripts/overlay_metadata_smoke.swift` | Swift smoke probe 추가 | embedded bytes availability, wrap style, layer count를 JSON/요약으로 출력한다. |
| `mydocs/plans/task_m014_281*.md` | 수행/구현 계획서 작성 | 하이퍼-워터폴 추적 문서. |
| `mydocs/working/task_m014_281_stage*.md` | Stage 1-4 보고서 작성 | 단계별 결정, 검증, handoff 기록. |

## 핵심 관찰

- `v0.7.12`와 `v0.7.13` 모두 overlay/PageLayerTree native API를 제공한다.
- `v0.7.13`은 `PaintOp::Image`에 resolved payload와 `bakedWatermark` 의미를 추가한다.
- compact overlay JSON은 Studio path와 가깝지만 `binDataId`, `crop`, `fillMode`, `originalSize`를 직접 제공하지 않는다.
- 현재 repository sample set에서는 `BehindText`/`InFrontOfText` positive fixture를 찾지 못했다.
- `imageCount`는 page의 전체 image op count일 수 있으며 behind/front overlay 수와 다르다.
- Studio capture `overlayCount`는 DOM snapshot rect union용 metadata라 Swift overlay image count와 직접 비교하면 안 된다.

## 변경 전·후 정량 비교

### Overlay Metadata Smoke

Stage 3 smoke는 기본 sample 6개와 image-heavy candidate 15개를 통과했다. 기본 sample에서는 upstream image op가 있는 문서도 compact overlay layer는 모두 `0`이었다. 이는 현재 fixture가 behind/front overlay positive case가 아니라는 뜻이며, #282에서 positive fixture 확보가 필요하다.

| sample | upstream imageCount | Swift overlay images | render tree images | embedded bytes |
|--------|---------------------|----------------------|--------------------|----------------|
| `samples/basic/request.hwp` | `1` | `0` | `1` | `1/1` |
| `samples/hwpx/hwpx-01.hwpx` | `2` | `0` | `2` | `2/2` |
| `samples/tac-img-02.hwp` | `1` | `0` | `1` | `1/1` |
| `samples/tac-img-02.hwpx` | `1` | `0` | `1` | `1/1` |
| `samples/hwp-img-001.hwp` | `4` | `0` | `4` | `4/4` |
| `samples/img-start-001.hwp` | `0` | `0` | `0` | `0/0` |

Image-heavy 추가 후보 15개도 smoke 기준은 통과했고, 관찰한 최대 upstream imageCount는 `draw-group.hwp`의 `17`이었다. 그러나 이 후보군에서도 behind/front overlay positive case는 확보하지 못했다.

### Visual Baseline

| sample | ChangedPercent | MeanRGBDelta | MaxRGBDelta |
|--------|----------------|--------------|-------------|
| `request.hwp` | `18.1021%` | `11.5796` | `255` |
| `hwpx-01.hwpx` | `15.1839%` | `15.6722` | `255` |
| `tac-img-02.hwp` | `4.1375%` | `3.7228` | `255` |
| `tac-img-02.hwpx` | `3.6427%` | `3.3924` | `255` |
| `hwp-img-001.hwp` | `7.8448%` | `8.2731` | `255` |
| `img-start-001.hwp` | `14.4365%` | `15.4773` | `255` |

Stage 4 visual diff는 #282 이전 baseline이다. #281에서 native renderer/compositor drawing path는 변경하지 않았으므로 위 수치가 개선되거나 악화되는 것을 목표로 삼지 않았다.

## #282 Handoff

#282는 다음 순서로 진행하는 것이 좋다.

1. overlay-positive fixture를 확보한다.
2. `RhwpDocument.pageOverlayImages(at:)`를 compositor 입력으로 연결한다.
3. background -> `behind` -> flow -> `front` 순서의 pass를 명시한다.
4. `source.data`를 우선 사용하고, 필요하면 `source.binDataId`로 fallback한다.
5. `bakedWatermark == true`이면 watermark/filter를 중복 적용하지 않는다.
6. 같은 sample set으로 before/after visual diff를 비교한다.

## 검증 결과

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

## 잔여 위험과 한계

- `v0.7.13` core pin update는 아직 하지 않았다. #281은 `v0.7.12` lock 기준으로 forward-compatible optional decode만 준비했다.
- `bakedWatermark` actual payload는 현재 lock에서 관찰하지 못했다. core update 후 별도 smoke가 필요하다.
- 현재 sample set에서는 `BehindText`/`InFrontOfText` positive fixture를 찾지 못했다. #282 전 또는 #282 초기에 fixture를 확보해야 compositor pass 검증이 가능하다.
- external linked image, filename, base directory 개선은 별도 upstream/downstream 작업이다.
- LaunchServices local DB에는 Stage 3 xcodebuild 후 삭제된 DerivedData app 경로가 stale entry로 남았다. provider root는 `/Applications/Alhangeul.app`만 보였고, 전역 reset은 수행하지 않았다.

## 작업지시자 승인 요청

이 보고서를 기준으로 #281 PR을 `devel` 대상으로 게시하고 리뷰를 요청한다. PR merge 후에는 `pr-merge-cleanup` 절차로 이슈 close, publish branch 삭제, local branch/worktree 정리를 수행한다.
