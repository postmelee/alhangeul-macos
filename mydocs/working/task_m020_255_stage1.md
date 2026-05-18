# Task M020 #255 Stage 1 보고서

## 단계 목적

Stage 1의 목적은 RustBridge에 `native-skia` PNG ABI를 추가하기 전에 upstream `rhwp v0.7.11`의 실제 API, 현재 bridge ABI 패턴, generated artifact/provenance gate를 코드 기준으로 확인하는 것이다.

이 단계에서는 RustBridge source, generated header, staticlib, xcframework를 변경하지 않는다. Stage 2 이후 구현이 따라야 할 ABI 후보와 검증 기준만 고정한다.

## 산출물

| 파일 | 요약 |
|---|---|
| `mydocs/plans/task_m020_255_impl.md` | #255 구현계획서. Stage별 변경 파일, ABI 초안, feature provenance gate 보강 계획 포함. |
| `mydocs/working/task_m020_255_stage1.md` | upstream API inventory, 현재 bridge 상태, ABI 설계 입력, Stage 2 handoff 정리. |
| `mydocs/orders/20260518.md` | #255 상태를 Stage 1 완료 및 Stage 2 승인 대기 상태로 갱신. |

## upstream `native-skia` API 확인

현재 lock의 resolved checkout은 `/Users/melee/.cargo/git/checkouts/rhwp-6f8f299952213fc0/a9dcdee`이며, `rhwp-core.lock`과 `RustBridge/Cargo.lock`은 모두 `v0.7.11` tag의 commit `a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae`를 가리킨다.

upstream `Cargo.toml`의 feature 구조:

- `native-skia = ["dep:resvg", "dep:skia-safe"]`
- `skia-safe = { version = "0.93.1", optional = true, default-features = false, features = ["binary-cache", "embed-icudtl", "pdf", "textlayout"] }`
- 해당 feature는 `cfg(all(not(target_arch = "wasm32"), feature = "native-skia"))`로 native target에만 열린다.

upstream `DocumentCore`가 제공하는 PNG API:

- `render_page_png_native(&self, page_num: u32) -> Result<Vec<u8>, HwpError>`
- `render_page_png_native_with_fonts(&self, page_num: u32, font_paths: &[PathBuf]) -> Result<Vec<u8>, HwpError>`
- `render_page_png_native_with_export_options(&self, page_num: u32, options: &PngExportOptions) -> Result<Vec<u8>, HwpError>`

`PngExportOptions` 필드:

- `scale: Option<f64>`
- `max_dimension: Option<i32>`
- `vlm_target: Option<VlmTarget>`
- `dpi: Option<f64>`
- `font_paths: Vec<PathBuf>`

Quick Look/Thumbnail 초기 ABI에는 `scale`과 `max_dimension`만 노출하는 것이 맞다. `font_paths`, `dpi`, `vlm_target`은 제품 surface 요구가 아직 없고, FFI에서 path 배열과 preset enum을 추가하면 blast radius가 커진다. #256-#259 검증 뒤 별도 ABI 확장 후보로 남긴다.

## 현재 RustBridge 상태

현재 `RustBridge/Cargo.toml`은 다음 dependency만 선언한다.

```toml
rhwp = { git = "https://github.com/edwardkim/rhwp.git", tag = "v0.7.11" }
serde_json = "1"
```

즉 `rhwp/native-skia` feature가 활성화되어 있지 않다. `RustBridge/Cargo.lock`에는 resolved `rhwp` source가 `git+https://github.com/edwardkim/rhwp.git?tag=v0.7.11#a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae`로 남아 있다. 현재 lock에는 `skia-safe`/`skia-bindings` package가 없으므로 Stage 2에서 feature를 켜면 dependency graph와 lock diff가 생긴다.

현재 FFI surface는 `rhwp-ffi-symbols.txt` 기준 다음 10개다.

- `rhwp_close`
- `rhwp_extract_thumbnail`
- `rhwp_free_bytes`
- `rhwp_free_string`
- `rhwp_image_data`
- `rhwp_open`
- `rhwp_page_count`
- `rhwp_page_size`
- `rhwp_render_page_svg`
- `rhwp_render_page_tree`

기존 byte buffer 소유권 패턴은 `rhwp_extract_thumbnail`에서 확인된다. Rust가 owned slice를 caller에게 넘기고, Swift는 `rhwp_free_bytes(ptr, len)`로 `Vec::from_raw_parts(ptr, len, len)` 해제를 호출한다. Skia PNG ABI도 이 패턴을 재사용한다.

## ABI 설계 입력

Stage 2 ABI 후보는 `RhwpRenderStatus`와 `rhwp_render_page_png`로 둔다.

```c
RhwpRenderStatus rhwp_render_page_png(const struct RhwpHandle *handle,
                                      uint32_t page,
                                      double scale,
                                      uint32_t max_dimension,
                                      uint8_t **out_data,
                                      uintptr_t *out_len);
```

설계 이유:

- `bool` 반환만으로는 #256 Swift fallback taxonomy에 필요한 원인을 보존하기 어렵다.
- output pointer 실패와 render 실패를 분리해야 bridge 호출 버그와 문서 렌더 실패를 구분할 수 있다.
- `scale == 0.0`, `max_dimension == 0` sentinel을 사용하면 C ABI를 단순하게 유지하면서 upstream `Option`을 표현할 수 있다.
- 성공한 PNG bytes는 기존 `rhwp_free_bytes` 수명 규칙과 정합한다.

Stage 2에서 추가할 status 후보:

| status | Swift fallback reason 후보 | Stage 2 처리 |
|---|---|---|
| `RHWP_RENDER_OK` | 없음 | PNG bytes 반환 |
| `RHWP_RENDER_INVALID_HANDLE` | `invalidDocumentHandle` 또는 `ffiUnavailable` | null handle 방어 |
| `RHWP_RENDER_INVALID_OUTPUT` | `ffiUnavailable` | output pointer 누락 방어 |
| `RHWP_RENDER_INVALID_PAGE_INDEX` | `invalidPageIndex` | `page >= page_count` 방어 |
| `RHWP_RENDER_INVALID_OPTIONS` | `invalidPageSize` 또는 `invalidRenderOptions` | NaN/infinite/negative scale 등 방어 |
| `RHWP_RENDER_FAILURE` | `skiaRenderFailure` | upstream `HwpError` 또는 panic guard 실패 |

## build/provenance gate 확인

`scripts/build-rust-macos.sh`는 현재 다음 gate를 제공한다.

- `Cargo.lock`에서 `rhwp` repo/ref kind/tag/commit을 읽어 `rhwp-core.lock`에 기록한다.
- `cargo build --release`를 `aarch64-apple-darwin`, `x86_64-apple-darwin`로 실행한다.
- `xcrun lipo`로 `Frameworks/universal/librhwp.a`를 만든다.
- `cbindgen`으로 `Frameworks/generated_rhwp.h`를 생성한다.
- generated header의 `rhwp_*` symbol set을 `rhwp-ffi-symbols.txt`와 diff한다.
- `RhwpPageSize.width_pt/height_pt` header field 존재를 확인한다.
- `xcodebuild -create-xcframework`로 `Frameworks/Rhwp.xcframework`를 재생성한다.
- `--update-lock`은 artifact sha256/size를 `rhwp-core.lock`에 기록한다.
- `--verify-lock`은 lock source provenance와 artifact metadata를 검증한다.

확인된 gap:

- 현재 `rhwp-core.lock`은 release tag/commit과 artifact hash/size는 기록하지만 `native-skia` feature 활성화 상태를 직접 기록하지 않는다.
- #255 완료 기준에는 feature 활성화 상태가 build/provenance gate에 포함되어야 한다.
- 따라서 Stage 3에서 `scripts/build-rust-macos.sh`와 `rhwp-core.lock`에 `rhwp_enabled_features = "native-skia"` 같은 additive field를 추가하고, verify path가 `RustBridge/Cargo.toml`의 `features = ["native-skia"]`를 확인하도록 보강한다.

## Stage 2 handoff

Stage 2에서 수행할 구현 항목:

1. `RustBridge/Cargo.toml`의 `rhwp` dependency에 `features = ["native-skia"]` 추가.
2. `RustBridge/Cargo.lock` 갱신.
3. `RustBridge/src/lib.rs`에 `#[repr(C)] RhwpRenderStatus`와 `rhwp_render_page_png` 추가.
4. `RustBridge/cbindgen.toml` export include에 `RhwpRenderStatus` 추가.
5. output pointer 초기화, page range, option validation, panic guard 구현.
6. upstream `PngExportOptions`로 `render_page_png_native_with_export_options` 호출.
7. generated artifact 갱신은 Stage 3으로 넘김.

Stage 2에서는 아직 Swift wrapper나 Quick Look/Thumbnail 적용을 하지 않는다. `Frameworks/generated_rhwp.h`, `Rhwp.xcframework`, `rhwp-core.lock` 갱신도 Stage 3에서 묶어 처리한다.

## 본문 변경 정도 / 본문 무손실 여부

- RustBridge source, Cargo files, generated artifacts, lock file은 변경하지 않았다.
- 구현계획서에는 Stage 3의 feature provenance gate 보강 계획을 추가했다.
- 오늘할일은 #255 진행 상태 문구만 갱신했다.
- 기존 문서 본문 삭제나 대규모 재작성은 없다.

## 검증 결과

Stage 1 검증 명령:

```bash
rg -n "native-skia|render_page_png_native|PngExportOptions|RhwpRenderStatus|rhwp_render_page_png|provenance|rhwp_free_bytes" \
  mydocs/plans/task_m020_255_impl.md mydocs/working/task_m020_255_stage1.md RustBridge scripts/build-rust-macos.sh rhwp-ffi-symbols.txt
```

결과: 통과. 구현계획서와 Stage 1 보고서가 upstream PNG API, ABI 후보, provenance gate, buffer free 규칙을 포함함을 확인했다. 현재 RustBridge에는 아직 `rhwp_render_page_png` symbol이 없고, 이는 Stage 2 구현 범위로 남아 있다.

```bash
git diff --check -- mydocs/plans/task_m020_255_impl.md mydocs/working/task_m020_255_stage1.md mydocs/orders/20260518.md
```

결과: 통과.

추가 확인:

- upstream checkout에서 `native-skia`, `render_page_png_native*`, `PngExportOptions`, `skia-safe` feature 설정을 확인했다.
- `RustBridge/Cargo.lock`의 `rhwp` source가 `v0.7.11#a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae`임을 확인했다.
- 현재 `rhwp-ffi-symbols.txt`에 PNG ABI symbol이 없음을 확인했다.

## 잔여 위험

- `skia-safe`가 Stage 2/3 build에서 binary cache를 내려받거나 빌드할 수 있어 네트워크/환경 영향을 받을 수 있다.
- universal staticlib와 `Rhwp.xcframework` 크기 증가가 클 수 있다.
- `RhwpRenderStatus` enum이 cbindgen C header에서 원하는 이름/값으로 생성되는지 Stage 3에서 확인해야 한다.
- upstream `PngExportOptions.max_dimension`은 `i32`이고 ABI 후보는 `u32`이므로 변환 overflow guard가 필요하다.
- `rhwp-core.lock` feature provenance field 추가는 기존 verify parser와 호환되도록 additive 방식으로 설계해야 한다.

## 다음 단계 영향

Stage 2는 구현 단계다. 코드 변경 범위는 `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`, `RustBridge/src/lib.rs`, `RustBridge/cbindgen.toml`로 제한한다.

Stage 2 완료 후에는 generated artifact가 아직 구버전이므로 Xcode/Swift build 검증은 Stage 3 artifact 갱신 뒤에 수행한다. Stage 2의 핵심 검증은 `cargo check`와 source-level symbol/contract 확인이다.

## 승인 요청

Stage 1은 ABI/upstream inventory와 구현계획서 보강으로 마무리한다. Stage 2 `RustBridge native-skia feature와 PNG FFI 구현`으로 진행하려면 작업지시자 승인이 필요하다.
