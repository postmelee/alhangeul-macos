# Task #76 Stage 2 완료 보고서

## 단계 목적

Demo/Preview core pin을 `edwardkim/rhwp` PR #385 upstream merge commit `e91ecea3174a0da0ad7a1ea495cacc4f8772c31d`로 갱신하고, Rust bridge 산출물을 재생성해 `rhwp-core.lock`의 provenance와 artifact hash/size를 맞춘다.

## 산출물

- `RustBridge/Cargo.toml`
  - `rhwp` dependency rev를 `1e9d78a1d40c71779d81c6ec6870cd301d912626`에서 `e91ecea3174a0da0ad7a1ea495cacc4f8772c31d`로 갱신했다.
- `RustBridge/Cargo.lock`
  - `rhwp` package source를 upstream merge commit으로 갱신했다.
  - upstream `rhwp`가 `0.7.7`로 해석되면서 `wasm-bindgen`, `zip`, `js-sys`, `web-sys`, `libc`, futures 계열 일부 의존성이 함께 갱신되었다.
- `rhwp-core.lock`
  - `rhwp_commit`을 `e91ecea3174a0da0ad7a1ea495cacc4f8772c31d`로 갱신했다.
  - `rhwp_release_transition_status = "demo-commit-pin"`을 유지했다.
  - latest checked release를 Stage 1 확인 기준인 `v0.7.7` / `033617e23847982135c02091a62f55031a3817b5`로 보정했다.
  - `Frameworks/universal/librhwp.a` hash/size를 새 산출물 기준으로 갱신했다.
- `Frameworks/` generated artifacts
  - `Frameworks/universal/librhwp.a`, `Frameworks/generated_rhwp.h`, `Frameworks/Rhwp.xcframework`를 재생성했다.
  - `Frameworks/`는 `.gitignore` 대상이므로 tracked 변경에는 포함하지 않았다.

## 본문 변경 정도 / 본문 무손실 여부

이번 단계는 code dependency와 lock provenance 갱신이다. 문서 본문 변경은 단계 보고서 추가뿐이다.

Stable release tag 전환은 수행하지 않았다. latest release `v0.7.7`은 Stage 1에서 `build_page_render_tree` 누락으로 blocked 확인되었으므로, `rhwp_ref_kind = "commit"`과 `demo-commit-pin` 상태를 유지했다.

## 검증 결과

```bash
./scripts/update-rhwp-core.sh --channel demo --rev e91ecea3174a0da0ad7a1ea495cacc4f8772c31d
```

첫 실행은 sandbox 네트워크 제한으로 실패했다.

```text
fatal: unable to access 'https://github.com/edwardkim/rhwp.git/': Could not resolve host: github.com
ERROR: dependency fetch failure: could not fetch demo commit e91ecea3174a0da0ad7a1ea495cacc4f8772c31d
```

escalated 재실행은 통과했다.

```text
Checked rhwp core target:
  channel: demo
  rev:     e91ecea3174a0da0ad7a1ea495cacc4f8772c31d
  commit:  e91ecea3174a0da0ad7a1ea495cacc4f8772c31d
Updated: /Users/melee/Documents/projects/rhwp-mac/RustBridge/Cargo.toml
Updated: /Users/melee/Documents/projects/rhwp-mac/RustBridge/Cargo.lock
Updated: /Users/melee/Documents/projects/rhwp-mac/rhwp-core.lock
```

```bash
./scripts/build-rust-macos.sh --update-lock
```

첫 실행은 sandbox 네트워크 제한으로 crates.io 다운로드가 실패했다.

```text
error: failed to download from `https://static.crates.io/crates/wasm-bindgen-macro-support/0.2.120/download`

Caused by:
  [6] Couldn't resolve host name (Could not resolve host: static.crates.io)
```

escalated 재실행은 통과했다.

```text
[1/4] Rust staticlib (arm64 + x86_64)...
   Compiling rhwp v0.7.7 (https://github.com/edwardkim/rhwp.git?rev=e91ecea3174a0da0ad7a1ea495cacc4f8772c31d#e91ecea3)
   Compiling rhwp_mac_bridge v0.1.0 (/Users/melee/Documents/projects/rhwp-mac/RustBridge)
    Finished `release` profile [optimized] target(s) in 19.64s
   Compiling rhwp v0.7.7 (https://github.com/edwardkim/rhwp.git?rev=e91ecea3174a0da0ad7a1ea495cacc4f8772c31d#e91ecea3)
   Compiling rhwp_mac_bridge v0.1.0 (/Users/melee/Documents/projects/rhwp-mac/RustBridge)
    Finished `release` profile [optimized] target(s) in 19.07s
[2/4] Universal binary...
Architectures in the fat file: /Users/melee/Documents/projects/rhwp-mac/Frameworks/universal/librhwp.a are: x86_64 arm64
[3/4] cbindgen header check...
FFI symbols:
rhwp_close
rhwp_extract_thumbnail
rhwp_free_bytes
rhwp_free_string
rhwp_image_data
rhwp_open
rhwp_page_count
rhwp_page_size
rhwp_render_page_svg
rhwp_render_page_tree
[4/4] XCFramework...
xcframework successfully written out to: /Users/melee/Documents/projects/rhwp-mac/Frameworks/Rhwp.xcframework
Updated: /Users/melee/Documents/projects/rhwp-mac/rhwp-core.lock
```

```bash
rg -n "e91ecea3174a0da0ad7a1ea495cacc4f8772c31d|rhwp_ref_kind|rhwp_release_transition_status|rhwp_latest_checked_release|033617e23847982135c02091a62f55031a3817b5" \
  RustBridge/Cargo.toml RustBridge/Cargo.lock rhwp-core.lock
```

결과:

```text
RustBridge/Cargo.toml:11:rhwp = { git = "https://github.com/edwardkim/rhwp.git", rev = "e91ecea3174a0da0ad7a1ea495cacc4f8772c31d" }
RustBridge/Cargo.lock:586:source = "git+https://github.com/edwardkim/rhwp.git?rev=e91ecea3174a0da0ad7a1ea495cacc4f8772c31d#e91ecea3174a0da0ad7a1ea495cacc4f8772c31d"
rhwp-core.lock:3:rhwp_ref_kind = "commit"
rhwp-core.lock:4:rhwp_commit = "e91ecea3174a0da0ad7a1ea495cacc4f8772c31d"
rhwp-core.lock:5:rhwp_release_transition_status = "demo-commit-pin"
rhwp-core.lock:6:rhwp_latest_checked_release_tag = "v0.7.7"
rhwp-core.lock:7:rhwp_latest_checked_release_commit = "033617e23847982135c02091a62f55031a3817b5"
```

```bash
git status --short
```

Stage 2 변경 직후 결과:

```text
 M RustBridge/Cargo.lock
 M RustBridge/Cargo.toml
 M rhwp-core.lock
?? mydocs/working/task_m010_76_stage2.md
```

커밋 직전 재확인에서는 위 #76 변경 외 `Sources/HostApp/Assets.xcassets/AppIcon.appiconset/*.png` 변경이 추가로 감지되었다. 이 PNG 변경은 #76 Stage 2 범위가 아니므로 스테이징하지 않고 그대로 보존했다.

```bash
git diff --check
```

결과: 통과.

```bash
git status --ignored --short Frameworks
```

결과:

```text
!! Frameworks/
```

`Frameworks/`는 재생성되었지만 ignore 대상이다.

## 잔여 위험

- 이번 단계는 Rust bridge build와 artifact 갱신까지 확인했다. `--verify-lock`, FFI symbol diff, no-AppKit 검증은 Stage 3에서 별도 수행한다.
- `e91ecea`로 전환하면서 `Cargo.lock` dependency graph가 일부 갱신되었다. Stage 3/4에서 build, ABI, render smoke로 실제 영향 여부를 확인해야 한다.
- latest release `v0.7.7`은 Stable 전환 기준을 만족하지 못하므로, Stage 5 문서 보정에서 기존 `v0.7.6` 중심 설명을 새 확인 기준으로 정리해야 한다.

## 다음 단계 영향

Stage 3에서는 현재 생성된 Rust bridge artifact가 `rhwp-core.lock`과 일치하는지 `--verify-lock`으로 검증하고, generated FFI symbol set과 Swift bridge boundary 규칙을 확인한다.

## 승인 요청

Stage 2 결과를 승인하고 Stage 3: RustBridge, lock, C ABI, no-AppKit 검증으로 진행할지 승인 요청한다.
