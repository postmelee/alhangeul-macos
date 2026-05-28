# Task M020 #278 Stage 2 완료 보고서

## 단계 목적

앱의 Rust core dependency를 upstream `rhwp` stable release `v0.7.13`으로 갱신하고, RustBridge 산출물과 `rhwp-core.lock` provenance metadata를 새 기준으로 재생성했다.

## 산출물

| 파일 | 변경 |
| --- | --- |
| `RustBridge/Cargo.toml` | `rhwp` dependency tag를 `v0.7.12`에서 `v0.7.13`으로 변경 |
| `RustBridge/Cargo.lock` | `rhwp` resolved source를 `v0.7.13#b3e16ef212af81ef37d973ddb86d6816d3804642`로 변경, 일부 transitive dependency patch 업데이트 반영 |
| `rhwp-core.lock` | release tag, resolved commit, build time, static library hash/size 갱신 |

diff 규모:

```text
3 files changed, 40 insertions(+), 40 deletions(-)
RustBridge/Cargo.lock  34 insertions / 34 deletions
RustBridge/Cargo.toml   1 insertion / 1 deletion
rhwp-core.lock          5 insertions / 5 deletions
```

`Frameworks/universal/librhwp.a`, `Frameworks/generated_rhwp.h`, `Frameworks/Rhwp.xcframework`는 build script가 재생성했지만 git 추적 대상은 아니며, `rhwp-core.lock`의 artifact metadata로 검증한다.

## core provenance

갱신 후 core 기준:

```text
rhwp_release_tag = "v0.7.13"
rhwp_commit = "b3e16ef212af81ef37d973ddb86d6816d3804642"
rhwp_enabled_features = "native-skia"
built_at = "2026-05-28T00:26:45Z"
```

`RustBridge/Cargo.lock`의 `rhwp` package도 같은 commit을 가리킨다.

```text
name = "rhwp"
version = "0.7.13"
source = "git+https://github.com/edwardkim/rhwp.git?tag=v0.7.13#b3e16ef212af81ef37d973ddb86d6816d3804642"
```

## dependency 변화

Cargo update 과정에서 `rhwp` 외 일부 transitive dependency가 patch 버전으로 갱신됐다.

주요 변경:

- `rhwp`: `0.7.12` -> `0.7.13`
- `skia-bindings`: `0.97.0` -> `0.97.2`
- `skia-safe`: `0.97.0` -> `0.97.2`
- `quick-xml`: `0.39.4` -> `0.40.1`
- `wasm-bindgen` 계열: `0.2.121` -> `0.2.122`
- `js-sys`/`web-sys`: `0.3.98` -> `0.3.99`
- `serde_json`: `1.0.149` -> `1.0.150`

## FFI와 header 영향

FFI symbol set은 변경되지 않았다.

```text
rhwp_close
rhwp_extract_thumbnail
rhwp_free_bytes
rhwp_free_string
rhwp_image_data
rhwp_open
rhwp_page_count
rhwp_page_overlay_images
rhwp_page_size
rhwp_render_page_png
rhwp_render_page_svg
rhwp_render_page_tree
```

`Frameworks/generated_rhwp.h` hash도 기존과 동일하다.

```text
sha256 = "31ed496ccbe86082885a82c584166669e1913a552dba26556ef5182842959601"
size = 2059
```

따라서 Stage 2 기준 Swift bridge 호출부 수정은 필요하지 않았다.

## artifact 수치

`Frameworks/universal/librhwp.a` metadata:

| 기준 | size | sha256 |
| --- | ---: | --- |
| v0.7.12 | `200488800` | `d0513faa5fddd6b1575a15756f74712686d68910a36614f61db9077caaec6360` |
| v0.7.13 | `203436808` | `e382867272a5b9fa5518c2e1a19a1f6fa1fae467627ca9dc67e19559a4fd3ffb` |

크기 변화:

```text
diff = +2,948,008 bytes
increase = +1.47%
```

build output 기준 universal archive와 xcframework는 모두 약 `194M`로 표시됐다.

## 검증 결과

실행한 명령:

```bash
./scripts/update-rhwp-core.sh --channel stable --tag v0.7.13
./scripts/build-rust-macos.sh --update-lock
./scripts/build-rust-macos.sh --verify-lock
./scripts/check-no-appkit.sh
git diff --check
```

핵심 출력:

```text
Checked rhwp core target:
  channel: stable
  tag:     v0.7.13
  commit:  b3e16ef212af81ef37d973ddb86d6816d3804642
```

```text
Architectures in the fat file: .../Frameworks/universal/librhwp.a are: x86_64 arm64
xcframework successfully written out to: .../Frameworks/Rhwp.xcframework
Verified: /Users/melee/Documents/projects/rhwp-mac-task278/rhwp-core.lock
```

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

결과:

- `update-rhwp-core.sh` 성공
- RustBridge arm64/x86_64 release build 성공
- universal static archive 생성 성공
- cbindgen header check 성공
- FFI symbol check 성공
- XCFramework 생성 성공
- `build-rust-macos.sh --verify-lock` 성공
- `check-no-appkit.sh` 성공
- `git diff --check` 성공

## 잔여 위험

- `librhwp.a` hash는 toolchain과 build path에 민감하다. 이번 Stage 2에서는 같은 로컬 환경에서 `--update-lock` 직후 `--verify-lock`을 통과했으므로 provenance 정합성은 확인됐다.
- bundled `rhwp-studio`는 아직 `v0.7.12` 기준이다. Stage 3에서 `v0.7.13` viewer/WASM asset sync를 진행해야 visual diff reference와 native core 기준이 일치한다.
- Quick Look/Thumbnail smoke와 HostApp build는 Stage 4에서 새 core와 synced viewer asset을 함께 대상으로 실행한다.

## 다음 단계 영향

Stage 3에서는 bundled `rhwp-studio` manifest/assets를 `v0.7.13` / `b3e16ef212af81ef37d973ddb86d6816d3804642` 기준으로 맞춘다. Stage 3 전까지는 WebView reference renderer가 아직 `v0.7.12`이므로 visual diff 수치를 해석하지 않는다.

## 승인 요청

Stage 3으로 진행하려면 upstream checkout에서 `pkg/`와 `rhwp-studio/dist` 준비 상태를 확인하고, 필요 시 `scripts/sync-rhwp-studio.sh`로 bundled viewer asset을 `v0.7.13` 기준으로 갱신한다.
