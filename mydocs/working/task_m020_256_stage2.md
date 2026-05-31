# Task M020 #256 Stage 2 보고서

## 단계 목표

`RhwpDocument`에 `rhwp_render_page_png` Swift wrapper를 추가해 Skia PNG bytes와 FFI status를 Swift 계층에서 안전하게 받을 수 있게 한다.

## 변경 요약

| 파일 | 내용 |
|---|---|
| `Sources/RhwpCoreBridge/RhwpDocument.swift` | `RhwpPagePNGStatus`, `RhwpRenderedPNG`, `RhwpDocument.renderPagePNG(at:scale:maxDimension:)` 추가 |
| `mydocs/orders/20260519.md` | #256 상태를 Stage 2 완료 후 승인 대기로 갱신 |

## 구현 내용

### Swift status wrapper

`RhwpRenderStatus` C enum을 Shared renderer contract에 직접 노출하지 않고, Swift 전용 `RhwpPagePNGStatus`로 매핑했다.

| C raw value | Swift status |
|---:|---|
| 0 | `.ok` |
| 1 | `.invalidHandle` |
| 2 | `.invalidOutput` |
| 3 | `.invalidPageIndex` |
| 4 | `.invalidOptions` |
| 그 외 | `.failure` |

raw value mapping을 사용한 이유는 generated C enum의 Swift case import 표기 차이에 덜 의존하기 위해서다.

### PNG result

`RhwpRenderedPNG`는 `data`, `status`, `byteCount`를 가진다.

- 실패 시 `data`는 empty `Data`로 반환하고 status를 보존한다.
- 성공 status라도 pointer/length가 비정상이면 empty data로 반환한다.
- Stage 3에서는 `status == .ok && byteCount > 0`만 Skia 성공 후보로 취급한다.

### FFI 수명 관리

`renderPagePNG`는 다음 순서로 동작한다.

1. Swift 입력에서 음수 page, non-finite/negative scale, 음수/`UInt32.max` 초과 maxDimension을 먼저 걸러낸다.
2. `rhwp_render_page_png(handle, page, scale, max_dimension, &outData, &outLen)`를 호출한다.
3. 반환 status를 `RhwpPagePNGStatus`로 변환한다.
4. `defer`에서 Rust-owned buffer를 `rhwp_free_bytes(ptr, outLen)`로 해제한다.
5. 성공 상태와 non-empty buffer일 때만 `Data(bytes:count:)`로 복사해 반환한다.

`Sources/RhwpCoreBridge`에는 AppKit/UIKit 의존을 추가하지 않았다.

## 검증 결과

### AppKit/UIKit guard

```bash
./scripts/check-no-appkit.sh
```

결과:

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

### symbol 확인

```bash
rg -n "rhwp_render_page_png|RhwpRenderStatus|rhwp_free_bytes|renderPagePNG|RhwpPagePNGStatus|RhwpRenderedPNG|Skia" Sources/RhwpCoreBridge
```

결과: 추가 wrapper와 기존 `rhwp_free_bytes` 해제 지점이 확인됐다.

### Rust bridge 산출물 준비

새 worktree에는 `Frameworks/` 산출물이 없어서 `./scripts/build-rust-macos.sh`를 실행했다.

첫 실행은 sandbox network 제한으로 실패했다.

```text
curl: (6) Could not resolve host: github.com
curl: (6) Could not resolve host: codeload.github.com
```

승인된 네트워크 실행으로 재시도해 성공했다.

```bash
./scripts/build-rust-macos.sh
```

결과:

```text
FFI symbols:
rhwp_close
rhwp_extract_thumbnail
rhwp_free_bytes
rhwp_free_string
rhwp_image_data
rhwp_open
rhwp_page_count
rhwp_page_size
rhwp_render_page_png
rhwp_render_page_svg
rhwp_render_page_tree
Done: /private/tmp/rhwp-mac-task256/Frameworks/Rhwp.xcframework
191M    /private/tmp/rhwp-mac-task256/Frameworks/universal/librhwp.a
191M    /private/tmp/rhwp-mac-task256/Frameworks/Rhwp.xcframework
```

`Frameworks/`는 git ignored 생성 산출물이므로 commit하지 않는다.

### generated header 확인

```bash
sed -n '1,120p' Frameworks/generated_rhwp.h
```

결과: `RhwpRenderStatus` enum과 `rhwp_render_page_png` signature가 생성 header에 존재한다.

### render smoke compile

```bash
./scripts/validate-stage3-render.sh output/task256-stage2 samples/basic/KTX.hwp
```

결과:

```text
OK KTX.hwp: page=1 size=1123x794 textRuns=437 hangulRuns=77 hangulScalars=209 nonWhitePixels=453754 png=/private/tmp/rhwp-mac-task256/output/task256-stage2/KTX-page1.png
```

`KTX.hwp`에서 기존 upstream layout overflow diagnostic이 stderr에 출력됐지만 smoke 자체는 통과했다.

### wrapper 직접 smoke

커밋하지 않는 `build.noindex/task256_png_smoke.swift`를 만들어 `RhwpDocument.renderPagePNG(at:scale:maxDimension:)`를 직접 호출했다.

compile:

```bash
swiftc -parse-as-library \
  -module-cache-path build.noindex/task256-swift-module-cache \
  -Xcc -fmodules-cache-path=build.noindex/task256-clang-module-cache \
  -I Frameworks/modulemap \
  Sources/RhwpCoreBridge/RhwpDocument.swift \
  Sources/RhwpCoreBridge/RenderTree.swift \
  build.noindex/task256_png_smoke.swift \
  Frameworks/universal/librhwp.a \
  -framework CoreFoundation \
  -framework CoreGraphics \
  -framework CoreText \
  -framework ImageIO \
  -framework Security \
  -framework Metal \
  -framework QuartzCore \
  -framework IOSurface \
  -framework ColorSync \
  -lc++ \
  -liconv \
  -lz \
  -o build.noindex/task256_png_smoke
```

run:

```bash
build.noindex/task256_png_smoke samples/basic/KTX.hwp
```

결과:

```text
OK KTX.hwp: status=ok bytes=165799
```

PNG signature도 smoke 내부에서 확인했다.

### HostApp build

첫 `xcodebuild`는 Sparkle package fetch DNS 제한으로 실패했다. 네트워크 허용 재시도로 성공했다.

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask256 \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과:

```text
** BUILD SUCCEEDED ** [13.024 sec]
```

## Stage 3 handoff

Stage 3에서는 다음 contract를 사용한다.

- `RhwpDocument.renderPagePNG(at:scale:maxDimension:)`
- `RhwpRenderedPNG.status`
- `RhwpRenderedPNG.byteCount`
- 성공 조건: `status == .ok && byteCount > 0`
- 실패 mapping:
  - `.invalidHandle` -> `invalidDocumentHandle`
  - `.invalidOutput` -> `ffiUnavailable`
  - `.invalidPageIndex` -> `invalidPageIndex`
  - `.invalidOptions` -> `invalidRenderOptions`
  - `.failure` 또는 empty bytes -> `skiaRenderFailure`

## 잔여 리스크

- Stage 2는 PNG bytes 반환과 signature까지만 확인했다. `CGImageSource` decode와 `HwpRenderedPage` diagnostics 연결은 Stage 3 범위다.
- `maxDimension`은 wrapper에서 받을 수 있지만, Shared renderer의 초기 정책은 Stage 1 결정대로 0을 유지하고 #258에서 Thumbnail scale/cache 정책과 함께 확정한다.
- `build.noindex`와 `Frameworks/` 산출물은 로컬 검증용이며 commit 대상이 아니다.

## 승인 요청

Stage 2를 완료한다. 승인 후 Stage 3 `HwpPageImageRenderer` backend abstraction과 CoreGraphics fallback 구현으로 진행한다.
