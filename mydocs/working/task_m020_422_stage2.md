# Task M020 #422 Stage 2 완료보고서

## 단계 목적

PR #421 exact automation candidate를 `local/task422`에 적용하고 current RustBridge source에서 native artifact와 lock metadata를 다시 생성한다. native core, bundled `rhwp-studio`, Swift build info와 provenance 문서를 stable `v0.7.19` / `f137b4c9468eaff5bb43e25108e9c9d39a2ed15b`로 정렬하고 기존 15개 C ABI를 보존한다.

## 산출물

### Core dependency와 native provenance

| 파일 | 변경 |
|------|------|
| `RustBridge/Cargo.toml` | `rhwp` dependency를 stable tag `v0.7.19`로 갱신 |
| `RustBridge/Cargo.lock` | `rhwp 0.7.19`, resolved commit과 신규 `svgtypes 0.16.1` dependency 기록 |
| `rhwp-core.lock` | target provenance와 local artifact hash/size 기록 |
| `Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift` | lock과 동일한 tag/commit으로 갱신 |

### Bundled studio full sync

| 파일 | 변경 |
|------|------|
| `Sources/HostApp/Resources/rhwp-studio/index.html` | 새 hashed JS/CSS, recent documents UI와 upstream HML file input 반영 |
| `Sources/HostApp/Resources/rhwp-studio/manifest.json` | source tag/commit/Cargo.lock fingerprint와 entrypoint hash 갱신 |
| `Sources/HostApp/Resources/rhwp-studio/manifest.webmanifest` | upstream HML web file handler metadata 반영 |
| `Sources/HostApp/Resources/rhwp-studio/sw.js` | 새 entrypoint/font cache revision 반영 |
| `Sources/HostApp/Resources/rhwp-studio/assets/**` | main JS/CSS, CanvasKit chunk와 WASM hashed asset 교체 |
| `Sources/HostApp/Resources/rhwp-studio/fonts/NotoSansKR-Regular.woff2` | upstream canonical font asset 교체 |

### Provenance 문서

| 파일 | 변경 |
|------|------|
| `mydocs/manual/core_dependency_operation_guide.md` | current stable 기준을 `v0.7.19`로 갱신 |
| `mydocs/tech/core_release_compatibility.md` | current lock/artifact/API/검증 기준 갱신 |
| `mydocs/tech/project_architecture.md` | RustBridge와 stable core 경계의 current provenance 갱신 |
| `mydocs/working/task_m020_422_stage2.md` | Stage 2 통합·검증 결과 기록 |
| `mydocs/orders/20260719.md` | Stage 2 완료와 Stage 3 승인 대기 기록 |

Stage 2 source/provenance diff는 19개 파일이며 text 기준 112 insertions, 101 deletions과 두 binary asset 변경이다. 단계 보고서와 orders 갱신을 포함한 Stage commit 대상은 21개 파일이다. generated `Frameworks/**`, `Alhangeul.xcodeproj`, `build.noindex/**`는 commit 대상에서 제외했다.

## Automation candidate 적용

Stage 2 직전 PR #421 상태는 Stage 1 계약과 동일했다.

| 항목 | 결과 |
|------|------|
| state | `OPEN` |
| base | `9ca9c488937bdda00fb045eb82b1ab2ecb31aa83` |
| head | `ddcc0329ae1b6bef7c6dacb51ee8375de3b6d42c` |
| merge state | `MERGEABLE`, `CLEAN` |
| PR CI | 4개 check 모두 SUCCESS |

`git cherry-pick -n ddcc0329ae1b6bef7c6dacb51ee8375de3b6d42c`으로 bot commit의 diff만 적용했다. 적용 직후 `git diff --cached --name-status`는 Stage 1 allowlist의 core dependency/lock, studio entrypoint/manifest/asset/font 15개 logical path와 정확히 일치했다. conflict나 allowlist 밖 변경은 없었다.

PR #421은 merge하지 않았다. Task #422 PR이 동일 sync diff와 local artifact 보정, downstream 검증·문서를 함께 포함하며 Task PR merge 후 PR #421을 superseded 처리한다.

## Native artifact 재생성

`scripts/build-rust-macos.sh --update-lock`을 current Task source에서 실행했다. 두 architecture 모두 `rhwp v0.7.19` / `f137b4c9...`와 `rhwp_mac_bridge` release profile compile에 성공했다.

| 항목 | 결과 |
|------|------|
| architecture | universal `x86_64 arm64` |
| `librhwp.a` SHA-256 | `4b1ce5fd99592f16b07985507b7049f78bd192d3b737d44dcef5a19b6b4110fd` |
| `librhwp.a` size | `210223376` bytes |
| generated header SHA-256 | `c4cba0728b7e443ba78541dc1184d6aa286b91b72006e423e9283d998c31d8e5` |
| generated header size | `3310` bytes |
| generated symbol count | 15 |
| XCFramework | 생성 성공 |

automation reference archive는 `433816b6...`, `210212160` bytes였다. local archive는 11,216 bytes 크고 hash가 다르다. source provenance, generated header와 symbol은 같으며 static archive metadata가 toolchain/build path에 민감하다는 repository 정책에 따라 current local 재생성 값을 final `rhwp-core.lock`에 기록했다.

generated header hash/size는 `v0.7.18`과 동일하다. `comm -3`로 expected/generated symbol을 비교한 결과 출력이 없었고 다음 15개 C ABI가 유지됐다.

```text
rhwp_close
rhwp_external_image_refs_json
rhwp_extract_thumbnail
rhwp_free_bytes
rhwp_free_string
rhwp_image_data
rhwp_inject_external_image_by_key
rhwp_open
rhwp_page_count
rhwp_page_overlay_images
rhwp_page_size
rhwp_render_page_png
rhwp_render_page_svg
rhwp_render_page_tree
rhwp_set_file_name_utf8
```

## Core/studio provenance 정렬

다섯 기준이 같은 target을 가리킨다.

| 기준 | tag | commit |
|------|-----|--------|
| `RustBridge/Cargo.toml` | `v0.7.19` | Cargo lock으로 resolve |
| `RustBridge/Cargo.lock` | `v0.7.19` | `f137b4c9468eaff5bb43e25108e9c9d39a2ed15b` |
| `rhwp-core.lock` | `v0.7.19` | `f137b4c9468eaff5bb43e25108e9c9d39a2ed15b` |
| `RhwpCoreBuildInfo.swift` | `v0.7.19` | `f137b4c9468eaff5bb43e25108e9c9d39a2ed15b` |
| bundled studio manifest | `v0.7.19` | `f137b4c9468eaff5bb43e25108e9c9d39a2ed15b` |

bundled studio final manifest:

| 항목 | 값 |
|------|----|
| source Cargo.lock SHA-256 | `401c179deada831e4445e2d2b1c7217ce8fdb31f94188c7e03979b91d009abd6` |
| copied files | 60 |
| copied bytes | 39,842,290 |
| main JS | `assets/index-D5SCeB-f.js` |
| main CSS | `assets/index-DXdWbUsL.css` |
| CanvasKit chunk | `assets/canvaskit-renderer-B7Bik_78.js` |
| WASM | `assets/rhwp_bg-chWFkZon.wasm` |

upstream tag의 root `Cargo.lock` SHA-256을 직접 계산한 결과가 manifest 값과 일치했다. `verify-rhwp-studio-assets.sh --tag v0.7.19 --commit f137...`도 entrypoint와 모든 copied asset hash를 검증했다.

local overlay `alhangeul-wkwebview-overrides.css`, `fonts/FONTS.md`에는 diff가 없고 `index.html`의 overlay link도 유지된다. upstream studio가 `.hml` file input/webmanifest metadata를 포함하지만 macOS Info.plist에 HML document type을 추가하지 않았으므로 알한글 공개 지원 형식 경계는 바뀌지 않는다.

## 본문 변경 정도 / 본문 무손실 여부

- automation candidate diff는 exact commit에서 conflict 없이 적용했다.
- bundled studio는 old hashed asset을 제거하고 candidate의 new hashed asset으로 전체 교체했다.
- local WKWebView overlay 두 파일은 수정·삭제하지 않았다.
- native core source를 앱 저장소에 복사하거나 수정하지 않았다.
- `project.yml`과 generated Xcode project는 변경하지 않았다.
- `rhwp-ffi-symbols.txt`는 expected/generated 결과가 같아 수정하지 않았다.
- 기술·운영 문서는 current provenance 문장과 artifact 값만 최소 갱신했으며 운영 원칙과 ABI contract 본문은 보존했다.

## 검증 결과

| 검증 | 결과 |
|------|------|
| PR #421 base/head 재확인 | expected SHA 일치, CLEAN |
| `cherry-pick -n` changed path allowlist | 일치, conflict 없음 |
| `build-rust-macos.sh --update-lock` | arm64/x86_64 compile, header/symbol/XCFramework/lock 생성 성공 |
| `build-rust-macos.sh --verify-lock` | final local lock 검증 성공 |
| expected/generated FFI `comm -3` | 출력 없음, 15개 일치 |
| `check-no-appkit.sh` | shared Swift code AppKit/UIKit dependency 없음 |
| `verify-rhwp-core-build-info.sh` | build info와 lock 일치 |
| `verify-rhwp-studio-assets.sh` | target tag/commit과 asset hash 검증 성공 |
| upstream Cargo.lock direct SHA-256 | manifest `401c179d...abd6`과 일치 |
| local overlay diff | 없음 |
| target provenance `rg` | Cargo/lock/build info/studio 모두 일치 |
| `git diff --check HEAD` | 통과 |

## 잔여 위험

- native bridge release compile과 lock verification은 통과했지만 Rust locked test 전체는 Stage 3에서 실행한다.
- HostApp, QLExtension, ThumbnailExtension의 Xcode compile/link는 아직 실행하지 않았다.
- representative HWP/HWPX, embedded image와 external image lifecycle runtime은 아직 검증하지 않았다.
- bundled studio asset hash는 유효하지만 실제 WKWebView entrypoint/WASM/font 로딩과 첫 페이지 렌더는 Stage 4에서 확인한다.
- upstream 저장 지오메트리, 표 페이지네이션과 BinData 변화의 visual/runtime 영향은 Stage 3·4 판정이 필요하다.
- automation archive와 local archive의 byte 차이는 정책상 허용 가능한 reference 차이지만 CI portable verification에서 source/header/symbol gate가 유지되는지 Task PR에서 다시 확인해야 한다.
- HML UI가 bundled asset에 포함되므로 release note와 macOS handler 지원을 혼동하지 않아야 한다.

## 다음 단계 영향

Stage 3는 final `v0.7.19` source/provenance를 변경하지 않고 Rust format/check/locked test, lock/studio/build-info gate, 앱 세 target compile/link와 representative HWP/HWPX runtime을 검증한다.

runtime에서 downstream integration 문제가 발견되면 Stage 3 안에서 최소 수정과 전체 재검증을 수행한다. upstream source 수정, Skia default 전환이나 HML document type 추가가 필요하면 현재 Task 범위를 넘으므로 중단하고 별도 판단을 요청한다.

## 승인 요청

Stage 2의 core/studio 통합과 provenance 고정 결과를 승인해 주시면 Stage 3에서 Rust ABI, HostApp/Quick Look/Thumbnail build와 representative runtime 회귀 검증을 진행한다.
