# Task M014 #281 Stage 3 보고서 - overlay metadata smoke 검증

## 단계 개요

- 이슈: #281 PageLayerTree overlay image metadata를 Swift preview 입력으로 연결
- 단계: Stage 3. metadata smoke와 bridge 검증
- 목표: Stage 2에서 추가한 overlay metadata provider가 샘플 문서에서 반복 실행 가능한 검증 명령으로 동작하는지 확인하고, sample별 metadata 결과를 기록한다.

이번 단계에서는 renderer output을 변경하지 않았다. Stage 3 산출물은 smoke script, Xcode project 재생성 반영, 검증 보고서다.

## 변경 파일

| 파일 | 변경 |
|------|------|
| `scripts/overlay-metadata-smoke.sh` | overlay metadata smoke shell wrapper 추가. Framework/modulemap 확인, Swift helper compile, 기본 sample set 실행을 담당한다. |
| `scripts/overlay_metadata_smoke.swift` | page별 overlay compact JSON, Swift provider 결과, render tree image summary를 `summary.md`, `metadata.jsonl`, per-file JSON으로 출력한다. |
| `Alhangeul.xcodeproj/project.pbxproj` | `xcodegen generate`로 `PageOverlayImages.swift`를 HostApp, QLExtension, ThumbnailExtension source phase에 반영했다. |
| `mydocs/orders/20260527.md` | #281 Stage 3 완료와 Stage 4 승인 대기 상태로 갱신했다. |

## smoke script contract

실행 예:

```bash
./scripts/overlay-metadata-smoke.sh build.noindex/task281-stage3-metadata
./scripts/overlay-metadata-smoke.sh build.noindex/task281-stage3-metadata --page 1 samples/basic/request.hwp
```

기본 입력은 #281 계획서의 page 1 sample set이다.

- `samples/basic/request.hwp`
- `samples/hwpx/hwpx-01.hwpx`
- `samples/tac-img-02.hwp`
- `samples/tac-img-02.hwpx`
- `samples/hwp-img-001.hwp`
- `samples/img-start-001.hwp`

출력:

| artifact | 내용 |
|----------|------|
| `summary.md` | sample별 status, upstream imageCount, overlay count, render tree image/bytes availability 요약 |
| `metadata.jsonl` | input당 JSON object 1개 |
| `metadata/*-overlay.json` | input별 pretty-printed metadata |

## 기본 sample 결과

실행:

```bash
./scripts/overlay-metadata-smoke.sh build.noindex/task281-stage3-metadata
```

결과:

| sample | status | pageCount | upstream imageCount | overlay | behind | front | tree images | tree embedded available | wraps |
|--------|--------|-----------|---------------------|---------|--------|-------|-------------|-------------------------|-------|
| `request.hwp` | OK | 1 | 1 | 0 | 0 | 0 | 1 | 1/1 | `TopAndBottom:1` |
| `hwpx-01.hwpx` | OK | 9 | 2 | 0 | 0 | 0 | 2 | 2/2 | `TopAndBottom:2` |
| `tac-img-02.hwp` | OK | 66 | 1 | 0 | 0 | 0 | 1 | 1/1 | `TopAndBottom:1` |
| `tac-img-02.hwpx` | OK | 69 | 1 | 0 | 0 | 0 | 1 | 1/1 | `TopAndBottom:1` |
| `hwp-img-001.hwp` | OK | 1 | 4 | 0 | 0 | 0 | 4 | 4/4 | `Square:1, TopAndBottom:3` |
| `img-start-001.hwp` | OK | 3 | 0 | 0 | 0 | 0 | 0 | 0/0 | `-` |

관찰:

- 여섯 샘플 모두 문서 open, overlay JSON 호출, Swift provider decode, render tree scan이 성공했다.
- `upstream imageCount`는 overlay 수가 아니라 page layer tree의 전체 image op count로 해석해야 한다. `request.hwp`처럼 imageCount가 1이어도 behind/front overlay count는 0일 수 있다.
- 기본 sample set에는 `BehindText`/`InFrontOfText` overlay-positive case가 없었다.
- embedded image가 있는 기본 샘플은 모두 `imageData(binDataId:)` bytes availability가 확인됐다.
- 일부 샘플에서 `LAYOUT_OVERFLOW` 로그가 출력됐지만 smoke exit status는 성공이었다. 기존 core layout diagnostic 출력이며 provider failure는 아니다.

## 추가 image-heavy 후보 scan

overlay-positive fixture가 있는지 확인하기 위해 image-heavy 후보 15개를 추가로 실행했다.

```bash
./scripts/overlay-metadata-smoke.sh build.noindex/task281-stage3-metadata-candidates \
  samples/pic-crop-01.hwp samples/pic-in-head-01.hwp samples/pic-in-head-02.hwp \
  samples/20250130-hongbo.hwp samples/20250130-hongbo-no.hwp \
  samples/20250130-hongbo_saved.hwp samples/honbo-save.hwp \
  samples/k-water-rfp.hwp samples/kps-ai.hwp samples/exam_math.hwp \
  samples/exam_kor.hwp samples/group-drawing-02.hwp samples/draw-group.hwp \
  samples/group-box.hwp samples/shape-group-02.hwp
```

결과 요약:

| 범위 | 결과 |
|------|------|
| 성공 sample | 15/15 |
| upstream imageCount 최대값 | `draw-group.hwp` 17 |
| behind/front overlay-positive sample | 0 |
| embedded image bytes availability | image가 있는 sample은 모두 available |

따라서 현재 repository sample set 기준으로는 overlay provider 호출과 bytes 보존은 검증됐지만, 실제 `BehindText`/`InFrontOfText` overlay metadata 병합은 positive fixture 없이 정적 경로 검증에 머물렀다.

## bridge와 build 검증

실행:

```bash
./scripts/verify-rhwp-studio-assets.sh
./scripts/check-no-appkit.sh
rg -n "RhwpPageOverlay|overlay|BehindText|InFrontOfText|binDataId|bytesAvailable|binDataAvailable|rhwp_page_overlay_images" \
  Sources/RhwpCoreBridge Sources/Shared scripts
swiftc -parse-as-library \
  -module-cache-path build.noindex/task281-stage3-swift-module-cache \
  -Xcc -fmodules-cache-path=build.noindex/task281-stage3-clang-module-cache \
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
  -o build.noindex/task281-stage3-syntax-check
./scripts/build-rust-macos.sh --verify-lock
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData-task281-stage3 \
  CODE_SIGNING_ALLOWED=NO \
  build
git diff --check
```

결과:

- `verify-rhwp-studio-assets.sh` 통과.
- `check-no-appkit.sh` 통과.
- Swift compile 검증 통과.
- `build-rust-macos.sh --verify-lock` 통과. `rhwp_page_overlay_images` symbol, generated header, `rhwp-core.lock` 정합성이 유지된다.
- `xcodegen generate` 후 `PageOverlayImages.swift`가 HostApp, QLExtension, ThumbnailExtension source phase에 포함됐다.
- `xcodebuild` HostApp Debug build 통과. QLExtension/ThumbnailExtension도 dependency로 함께 build됐다.

## registration hygiene 관찰

`xcodebuild`가 `build.noindex/DerivedData-task281-stage3/.../Alhangeul.app`을 LaunchServices에 등록했다. 정책상 개발 등록을 남기지 않기 위해 다음을 수행했다.

```bash
./scripts/check-extension-registration-hygiene.sh --cleanup-dev-registrations
rm -rf build.noindex/DerivedData-task281-stage3
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -gc
./scripts/check-extension-registration-hygiene.sh --check-only
```

최종 상태:

- 개발 app bundle 파일은 제거됐다.
- PlugInKit provider root는 `/Applications/Alhangeul.app`만 보였다.
- 그러나 LaunchServices dump에는 삭제된 `build.noindex/DerivedData-task281-stage3/.../Alhangeul.app` 경로가 stale entry로 계속 남아 `check-extension-registration-hygiene.sh --check-only`가 실패했다.

이번 stale entry는 Stage 3 source 변경의 기능 회귀가 아니라 local LaunchServices DB 잔류로 판단한다. 다음 Quick Look/Thumbnail registration smoke 전에 hygiene check를 다시 실행해 사라졌는지 확인해야 한다. 전역 LaunchServices reset은 수행하지 않았다.

## 한계와 다음 단계

- 현재 sample set에서는 `BehindText`/`InFrontOfText` positive case를 찾지 못했다. Stage 4 또는 #282에서는 positive fixture 확보가 필요하다.
- `v0.7.13`의 `bakedWatermark` actual payload는 현재 lock `v0.7.12`에서 관찰할 수 없다. core update 후 같은 smoke로 재측정해야 한다.
- Stage 3는 metadata 추출과 build 검증만 수행했다. native compositor 합성과 visual diff 개선은 #282 범위다.

Stage 4에서는 이 입력 contract를 #282 handoff로 정리하고, visual diff baseline과 한계를 명확히 기록한다.
