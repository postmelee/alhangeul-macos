# Task M010 #267 Stage 2 완료 보고서

## 단계 목적

`rhwp v0.7.12` Stable release tag를 기준으로 Rust core dependency, Cargo lock, bridge artifact metadata, bundled `rhwp-studio` resource provenance를 갱신한다. ABI/Swift bridge 영향이 있으면 같은 단계에서 적응한다.

이번 단계에서는 app version/build는 변경하지 않았다. version과 release communication source 정리는 Stage 3 범위다.

## 산출물

| 파일 | 내용 |
|------|------|
| `RustBridge/Cargo.toml` | `rhwp` dependency tag를 `v0.7.12`로 갱신하고 `features = ["native-skia"]` 유지 |
| `RustBridge/Cargo.lock` | `rhwp v0.7.12` resolved commit `1899ef9bc2dfd1c6c0c4d18b192d253a2d0a1fb5`로 재해석 |
| `rhwp-core.lock` | source provenance와 `Frameworks/universal/librhwp.a` reference metadata 갱신 |
| `Sources/HostApp/Resources/rhwp-studio/**` | bundled `rhwp-studio` resource를 upstream `v0.7.12` build 산출물로 교체 |
| `scripts/update-rhwp-core.sh` | core tag/rev 교체 시 기존 `rhwp` feature 목록을 보존하도록 보정 |
| `mydocs/working/task_m010_267_stage2.md` | Stage 2 갱신 결과와 검증 기록 |
| `mydocs/orders/20260518.md` | #267 상태를 Stage 3 승인 대기로 갱신 |

## 본문 변경 정도 / 본문 무손실 여부

핵심 provenance 전후:

| 대상 | 이전 | 이후 |
|------|------|------|
| `RustBridge/Cargo.toml` | `tag = "v0.7.11"`, `features = ["native-skia"]` | `tag = "v0.7.12"`, `features = ["native-skia"]` |
| `RustBridge/Cargo.lock` | `git+https://github.com/edwardkim/rhwp.git?tag=v0.7.11#a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae` | `git+https://github.com/edwardkim/rhwp.git?tag=v0.7.12#1899ef9bc2dfd1c6c0c4d18b192d253a2d0a1fb5` |
| `rhwp-core.lock` | `rhwp_release_tag = "v0.7.11"`, `rhwp_commit = "a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae"` | `rhwp_release_tag = "v0.7.12"`, `rhwp_commit = "1899ef9bc2dfd1c6c0c4d18b192d253a2d0a1fb5"` |
| bundled `rhwp-studio` manifest | `source_release_tag = "v0.7.11"`, `source_resolved_commit = "a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae"` | `source_release_tag = "v0.7.12"`, `source_resolved_commit = "1899ef9bc2dfd1c6c0c4d18b192d253a2d0a1fb5"` |

`scripts/update-rhwp-core.sh`는 기존 구현상 `rhwp = { git = ..., tag = ... }` 라인을 통째로 교체하면서 `features = ["native-skia"]`를 제거했다. 현재 release line은 `rhwp-core.lock`의 `rhwp_enabled_features = "native-skia"`를 기준으로 검증하므로, 스크립트가 기존 feature 목록을 읽어 새 dependency line에 다시 포함하도록 보정했다.

## core / ABI 결과

`rhwp-core.lock` 결과:

| 항목 | 값 |
|------|----|
| release tag | `v0.7.12` |
| resolved commit | `1899ef9bc2dfd1c6c0c4d18b192d253a2d0a1fb5` |
| enabled features | `native-skia` |
| `Frameworks/universal/librhwp.a` sha256 | `771bfd8808c1a8a47ea4e18df8c75061d895db45c5de8ab018d767f050808eb3` |
| `Frameworks/universal/librhwp.a` size | `200487096` |
| `Frameworks/generated_rhwp.h` sha256 | `96e887f748a97223c1da04fddbd454638b0c40cf49b62dc2a55a18700c303d0c` |
| `Frameworks/generated_rhwp.h` size | `1978` |

`Frameworks/generated_rhwp.h`와 `rhwp-ffi-symbols.txt`에는 git diff가 없다. 생성된 FFI symbol set도 기존과 동일하다.

```text
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
```

따라서 Stage 2에서는 `Sources/RhwpCoreBridge` 또는 Swift renderer 적응 변경이 필요하지 않았다.

## bundled studio 결과

upstream checkout `build.noindex/rhwp-upstream-task225`를 commit `1899ef9bc2dfd1c6c0c4d18b192d253a2d0a1fb5`로 이동한 뒤 다음 산출물을 생성했다.

| 단계 | 결과 |
|------|------|
| WASM package | `docker-compose --env-file .env.docker run --rm wasm` 성공 |
| TypeScript check | `npx tsc` 성공 |
| Vite build | `npx vite build --base ./` 성공, 500kB 초과 chunk 경고만 발생 |
| sync | `scripts/sync-rhwp-studio.sh --upstream-dir build.noindex/rhwp-upstream-task225 --tag v0.7.12 --commit 1899ef9bc2dfd1c6c0c4d18b192d253a2d0a1fb5` 성공 |

manifest 결과:

| 항목 | 값 |
|------|----|
| copied file count | `54` |
| copied total bytes | `28579739` |
| main JS | `assets/index-DRLw2Nmm.js` |
| main CSS | `assets/index-C_SbAHsx.css` |
| WASM | `assets/rhwp_bg-2AkAqrUl.wasm` |

`sync-rhwp-studio.sh`는 기존 local overlay인 `alhangeul-wkwebview-overrides.css`와 `fonts/FONTS.md`를 유지했고, `index.html`의 WKWebView file URL 호환 조건도 `verify-rhwp-studio-assets.sh`로 확인했다.

## 검증 결과

| 명령 | 결과 | 비고 |
|------|------|------|
| `./scripts/update-rhwp-core.sh --channel stable --tag v0.7.12` | OK | sandbox DNS 제한으로 최초 실패 후 승인된 네트워크 실행으로 성공 |
| `./scripts/build-rust-macos.sh --update-lock` | OK | `skia-bindings` binary/source download가 필요해 승인된 네트워크 실행으로 성공 |
| `./scripts/build-rust-macos.sh --verify-lock` | OK | source provenance, header, staticlib metadata 검증 성공. CoreSimulator 관련 xcodebuild 경고는 있었지만 XCFramework 생성과 lock verify는 성공 |
| `./scripts/check-no-appkit.sh` | OK | `Sources/RhwpCoreBridge` AppKit/UIKit 의존 없음 |
| `docker-compose --env-file .env.docker run --rm wasm` | OK | Docker socket sandbox 제한으로 최초 실패 후 승인된 실행으로 성공 |
| `npm ci` | OK | upstream `rhwp-studio` lockfile 기준 428 packages 설치 |
| `npx tsc` | OK | TypeScript check 통과 |
| `npx vite build --base ./` | OK | chunk size warning만 발생 |
| `./scripts/sync-rhwp-studio.sh --upstream-dir build.noindex/rhwp-upstream-task225 --tag v0.7.12 --commit 1899ef9bc2dfd1c6c0c4d18b192d253a2d0a1fb5` | OK | sync 내부 asset verify 통과 |
| `./scripts/verify-rhwp-studio-assets.sh --tag v0.7.12 --commit 1899ef9bc2dfd1c6c0c4d18b192d253a2d0a1fb5` | OK | manifest, hashed JS/CSS/WASM, relative path, `crossorigin` 제거 확인 |
| `plutil -lint Sources/HostApp/Resources/rhwp-studio/manifest.json` | 대체 검증 | raw JSON을 plist로 해석하지 못해 `Unexpected character { at line 1` 출력. `ruby -rjson` parse와 `plutil -convert json`으로 JSON 유효성 확인 |
| `bash -n scripts/update-rhwp-core.sh scripts/build-rust-macos.sh scripts/sync-rhwp-studio.sh scripts/verify-rhwp-studio-assets.sh` | OK | shell syntax 확인 |
| `rg -n <provenance-pattern> rhwp-core.lock RustBridge/Cargo.toml RustBridge/Cargo.lock Sources/HostApp/Resources/rhwp-studio rhwp-ffi-symbols.txt` | OK | 추적 대상 provenance는 `v0.7.12` / `1899ef9...`만 확인 |
| `git diff --check` | OK | 공백 오류 없음 |

## 잔여 위험

- Stage 2는 core/studio provenance 갱신 단계이므로 HostApp Debug/Release build, render smoke, release helper dry-run은 Stage 4에서 반복 검증한다.
- upstream `rhwp-studio` Vite build는 500kB 초과 chunk 경고를 계속 출력한다. 이전 Stage 2와 동일 계열 경고이며, 현재 bundled asset verify에는 영향이 없다.
- `plutil -lint`는 raw JSON manifest에 맞지 않는 검증 명령이다. Stage 3 이후 문서나 검증 절차에서 manifest 검증은 `verify-rhwp-studio-assets.sh`와 JSON parser 기준으로 정리하는 것이 좋다.
- `RustBridge/target` 안에는 과거 build dependency 파일에 `a9dcdee` 경로가 남아 있을 수 있다. 이는 ignored build artifact이며 commit 대상이 아니다.

## 다음 단계 영향

Stage 3에서는 app 본체와 Quick Look/Thumbnail extension version을 `0.1.3` / build `9` 후보로 맞추고, release workflow default와 release note source를 `v0.1.3` / `rhwp v0.7.12` 기준으로 정리한다.

특히 release note에는 upstream release body가 비어 있다는 점을 반영해, tag message와 Stage 1 diff 결과를 바탕으로 `포함된 rhwp 변화`와 `알한글 앱 변화`를 분리해 작성해야 한다.

## 승인 요청

Stage 2 결과를 승인하면 Stage 3 `v0.1.3 version과 release communication source 정리`로 진행한다.
