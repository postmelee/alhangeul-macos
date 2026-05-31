# Task M014 #281 구현 계획서

수행계획서: `mydocs/plans/task_m014_281.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #281 PageLayerTree overlay image metadata를 Swift preview 입력으로 연결
- 마일스톤: M014 (`v0.1.4 Native Preview/Viewer Parity`)
- 브랜치: `local/task281`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac-task281`
- 기준 브랜치: `devel`
- 현재 앱 core lock: `rhwp-core.lock` `v0.7.12` (`1899ef9bc2dfd1c6c0c4d18b192d253a2d0a1fb5`)
- 비교 대상 upstream release: `v0.7.13` (`b3e16ef212af81ef37d973ddb86d6816d3804642`)
- 목표: Quick Look preview, Finder thumbnail, HostApp native viewer가 #282에서 같은 compositor 입력을 사용할 수 있도록 page overlay image metadata를 Swift 모델로 안정화한다.

## 구현 원칙

- 이번 작업의 1차 산출물은 overlay image metadata 입력 contract다. 실제 CGContext 합성 순서 변경은 #282에서 수행한다.
- upstream 미릴리즈 commit pin은 사용하지 않는다.
- `v0.7.13`은 Stage 1 비교 대상으로 포함하되, core dependency update가 필요하면 별도 작업으로 분리한다.
- filename field context, base directory, external linked image discovery/injection은 이번 범위에서 제외한다.
- `Sources/RhwpCoreBridge`에는 AppKit/UIKit/WebKit 의존을 추가하지 않는다.
- RustBridge ABI를 추가하는 경우 generated header, `rhwp-ffi-symbols.txt`, staticlib, `rhwp-core.lock` 정합성을 함께 검증한다.
- dedicated overlay/PageLayerTree API를 쓸 수 있으면 그 경로를 우선한다. 사용할 수 없거나 schema가 부족하면 render tree traversal fallback으로 Swift 모델을 먼저 안정화한다.

## 현재 기준 관찰

| 영역 | 현재 관찰 | 구현 판단 |
|------|-----------|-----------|
| Swift document wrapper | `RhwpDocument.renderPageTree(at:)`와 `imageData(binDataId:)`가 존재 | render tree fallback으로 overlay 후보와 bytes availability를 만들 수 있다. |
| Swift render tree model | `ImageNode`가 `binDataId`, `textWrap`, `effect`, `brightness`, `contrast`, `transform`, `crop`을 decode | #282에 필요한 최소 metadata가 이미 일부 존재한다. |
| CoreGraphics renderer | `CGTreeRenderer`가 `BehindText` 이미지를 별도 순서로 일부 처리 | 기존 renderer 동작은 이번 작업에서 바꾸지 않는다. |
| RustBridge ABI | 현재 C ABI는 `rhwp_render_page_tree`, `rhwp_image_data`, `rhwp_render_page_png` 중심 | dedicated overlay/PageLayerTree ABI는 Stage 1에서 추가 가능성을 확인한다. |
| upstream `v0.7.13` | 정식 release이며 HWPX 렌더링/저장 및 조판 회귀 정정 중심 | #281 입력 contract에 schema 개선이 있는지 Stage 1에서 비교한다. |

## 산출물 구조

| 파일 | 역할 |
|------|------|
| `mydocs/plans/task_m014_281_impl.md` | 단계별 구현 범위, 검증, 완료 기준 |
| `mydocs/working/task_m014_281_stage1.md` | `v0.7.12`/`v0.7.13` API inventory와 구현 경로 결정 |
| `mydocs/working/task_m014_281_stage2.md` | Swift overlay metadata 모델/provider 구현 보고 |
| `mydocs/working/task_m014_281_stage3.md` | sample metadata smoke와 compile/ABI 검증 보고 |
| `mydocs/working/task_m014_281_stage4.md` | visual diff baseline과 #282 handoff 보고 |
| `mydocs/report/task_m014_281_report.md` | 최종 결과와 한계, 후속 작업 정리 |
| `build.noindex/task281-*` | 검증 산출물. 커밋하지 않는다. |

## Stage 1. API inventory와 구현 경로 확정

### 목표

현재 앱 lock `v0.7.12`와 upstream `v0.7.13`의 overlay/PageLayerTree API와 JSON schema를 비교하고, #281에서 사용할 구현 경로를 확정한다.

### 작업

- `rhwp-core.lock`, `RustBridge/Cargo.toml`, `Cargo.lock`의 현재 core 기준을 확인한다.
- upstream `v0.7.13` release/tag/resolved commit을 기록한다.
- `v0.7.12` source cache와 `v0.7.13` remote code에서 다음 API를 확인한다.
  - `get_page_overlay_images_native`
  - `get_page_layer_tree_native`
  - `build_page_layer_tree`
  - PageLayerTree image paint op JSON schema
  - `wrap`, `bbox`, `binDataId` 또는 image resource reference, `mime`, `effect`, `brightness`, `contrast`, `watermark`, `transform`, `crop`에 해당하는 필드
- RustBridge에서 dedicated API를 C ABI로 노출할 수 있는지 확인한다.
- dedicated ABI가 과한 변경이면 render tree fallback으로 진행할지 결정한다.
- `v0.7.13` pin 반영이 #281 안에서 필요한지, 별도 core update 작업으로 분리할지 판단한다.

### 산출물

- `mydocs/working/task_m014_281_stage1.md`

### 검증

```bash
rg -n "rhwp_release_tag|rhwp_commit|rhwp_ref_kind" rhwp-core.lock
rg -n "rhwp =|source = .*rhwp|name = \"rhwp\"" RustBridge/Cargo.toml RustBridge/Cargo.lock
git ls-remote --tags https://github.com/edwardkim/rhwp.git 'refs/tags/v0.7.13'
gh release view v0.7.13 --repo edwardkim/rhwp --json tagName,name,publishedAt,isDraft,isPrerelease,body
rg -n "get_page_overlay_images_native|get_page_layer_tree_native|build_page_layer_tree|PageLayerTree|PaintOp::Image|BehindText|InFrontOfText" \
  RustBridge/src/lib.rs Sources/RhwpCoreBridge /Users/melee/.cargo/git/checkouts/rhwp-*
git diff --check
```

### 완료 기준

- `v0.7.12`와 `v0.7.13`의 #281 관련 API/schema 차이가 표로 정리된다.
- 이번 이슈에서 core pin update를 수행할지 여부가 명확히 결정된다.
- Stage 2 구현 경로가 dedicated ABI 또는 render tree fallback 중 하나로 고정된다.
- production source는 변경하지 않는다.

### 커밋 메시지

```text
Task #281 Stage 1: overlay metadata API inventory 정리
```

## Stage 2. Swift overlay metadata 모델과 provider 구현

### 목표

#282 compositor가 사용할 Swift overlay image metadata 모델과 page별 조회 API를 추가한다.

### 작업

- Swift model을 추가한다.
  - `RhwpPageOverlayImage`
  - `RhwpPageOverlayLayer`
  - `RhwpPageOverlayImageSource`
  - 필요 시 `RhwpPageOverlayImageSet`
- page별 metadata 조회 API를 추가한다.
  - dedicated ABI 경로: RustBridge JSON을 decode
  - fallback 경로: `renderPageTree(at:)` 결과를 순회해 `ImageNode` 후보 추출
- metadata에 다음 정보를 보존한다.
  - layer/wrap
  - bbox
  - binDataId
  - embedded bytes availability
  - effect, brightness, contrast
  - transform, crop
- 실패/빈 결과 semantics를 정리한다.
  - page out of range
  - render tree unavailable
  - overlay 없음
  - image bytes 없음

### 산출물

- `Sources/RhwpCoreBridge/RhwpDocument.swift`
- `Sources/RhwpCoreBridge/RenderTree.swift`
- 필요 시 `Sources/RhwpCoreBridge/PageOverlayImages.swift`
- 필요 시 `RustBridge/src/lib.rs`
- 필요 시 `Frameworks/generated_rhwp.h`, `rhwp-ffi-symbols.txt`, `Frameworks/universal/librhwp.a`, `rhwp-core.lock`
- `mydocs/working/task_m014_281_stage2.md`

### 검증

```bash
swiftc -parse-as-library \
  -module-cache-path build.noindex/task281-stage2-swift-module-cache \
  -Xcc -fmodules-cache-path=build.noindex/task281-stage2-clang-module-cache \
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
  -o build.noindex/task281-stage2-syntax-check
./scripts/check-no-appkit.sh
git diff --check
```

RustBridge ABI를 변경하는 경우 추가 검증:

```bash
./scripts/build-rust-macos.sh --verify-lock
rg -n "rhwp_.*overlay|rhwp_.*layer|rhwp_render_page_tree|rhwp_image_data" \
  Frameworks/generated_rhwp.h rhwp-ffi-symbols.txt
```

### 완료 기준

- Swift compile이 통과한다.
- overlay metadata API가 page별로 호출 가능한 형태가 된다.
- 기존 `renderPageTree`, CoreGraphics render, Skia optional render fallback contract를 깨지 않는다.

### 커밋 메시지

```text
Task #281 Stage 2: overlay metadata Swift 모델 추가
```

## Stage 3. metadata smoke와 bridge 검증

### 목표

image-heavy sample에서 overlay metadata가 기대 필드를 보존하는지 확인한다.

### 작업

- sample set에서 page 1 overlay metadata를 추출한다.
  - `samples/basic/request.hwp`
  - `samples/hwpx/hwpx-01.hwpx`
  - `samples/tac-img-02.hwp`
  - `samples/tac-img-02.hwpx`
  - `samples/hwp-img-001.hwp`
  - `samples/img-start-001.hwp`
- metadata smoke helper가 필요하면 `scripts/`에 최소 script를 추가하거나 기존 harness output에 metadata summary를 추가한다.
- sample별 overlay count, layer, bbox, binDataId, bytes availability, effect/brightness/contrast/crop/transform 보존 여부를 기록한다.
- dedicated ABI 경로를 택한 경우 generated C header와 Swift wrapper의 수명/해제 규칙을 검증한다.

### 산출물

- 필요 시 metadata smoke script
- `build.noindex/task281-stage3-metadata/`
- `mydocs/working/task_m014_281_stage3.md`

### 검증

```bash
./scripts/verify-rhwp-studio-assets.sh
rg -n "RhwpPageOverlay|overlay|BehindText|InFrontOfText|binDataId|bytesAvailable" \
  Sources/RhwpCoreBridge Sources/Shared scripts
swiftc -parse-as-library \
  -module-cache-path build.noindex/task281-stage3-swift-module-cache \
  -Xcc -fmodules-cache-path=build.noindex/task281-stage3-clang-module-cache \
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
  -o build.noindex/task281-stage3-syntax-check
git diff --check
```

### 완료 기준

- sample별 overlay metadata 결과가 보고서에 표로 기록된다.
- overlay가 없는 sample과 추출 실패 sample이 구분된다.
- `binDataId`가 있는 embedded image의 bytes availability가 확인된다.

### 커밋 메시지

```text
Task #281 Stage 3: overlay metadata smoke 검증
```

## Stage 4. visual diff baseline과 #282 handoff

### 목표

#281이 renderer output을 직접 개선하지 않는 한계를 명확히 하고, #282가 사용할 입력 contract와 baseline 수치를 정리한다.

### 작업

- #286 harness로 #282 이전 baseline을 기록한다.
- `studio/*.json` overlay metadata와 Swift metadata smoke 결과를 연결해 차이를 정리한다.
- #282에서 사용할 compositor 입력 contract를 명시한다.
  - background
  - BehindText overlay
  - flow
  - InFrontOfText overlay
- 이번 작업에서 제외한 external linked image, filename, base directory 문제를 다시 명시한다.
- 오늘할일 #281 상태를 단계 완료 상태로 갱신한다.

### 산출물

- `mydocs/working/task_m014_281_stage4.md`
- `mydocs/report/task_m014_281_report.md` 초안 또는 최종 보고 직전 handoff 메모
- `mydocs/orders/20260527.md`

### 검증

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task281-stage4-basic --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx
./scripts/preview-visual-diff-harness.sh build.noindex/task281-stage4-images --page 1 \
  samples/tac-img-02.hwp samples/tac-img-02.hwpx \
  samples/hwp-img-001.hwp samples/img-start-001.hwp
sed -n '1,180p' build.noindex/task281-stage4-basic/summary.md
sed -n '1,220p' build.noindex/task281-stage4-images/summary.md
rg -n "ChangedPixels|ChangedPercent|MeanRGBDelta|Overlay|#282|BehindText|InFrontOfText|v0.7.13" \
  mydocs/working/task_m014_281_stage4.md mydocs/orders/20260527.md
git diff --check
git status --short --branch
```

### 완료 기준

- #282가 바로 참조할 overlay metadata contract와 sample 관찰값이 남는다.
- visual diff 수치가 개선되지 않아도 그 이유가 “compositor 미구현”으로 설명된다.
- `v0.7.13` 비교 결론과 core update 분리 여부가 최종 handoff에 남는다.

### 커밋 메시지

```text
Task #281 Stage 4: overlay metadata handoff 정리
```

## 승인 요청 사항

1. 위 4단계 구현계획으로 #281을 진행하는 것에 대한 승인
2. Stage 1에서 `v0.7.12`와 upstream `v0.7.13`을 비교하되 core pin 변경은 하지 않는 범위 승인
3. Stage 2에서 dedicated ABI가 과하면 render tree fallback으로 Swift metadata contract를 먼저 구현하는 방향 승인
4. Stage 4까지 실제 compositor 출력 변경은 하지 않고 #282 handoff로 넘기는 방향 승인

승인 전에는 Stage 1 inventory 보고서 작성 외 Swift/Rust source 변경을 진행하지 않는다.
