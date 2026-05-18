# Task M020 #255 Stage 2 보고서

## 단계 목적

Stage 2의 목적은 RustBridge source level에서 `rhwp/native-skia` feature를 켜고, Swift가 후속 #256에서 호출할 수 있는 Skia PNG C ABI를 추가하는 것이다.

이 단계에서는 generated header, `Rhwp.xcframework`, `rhwp-ffi-symbols.txt`, `rhwp-core.lock`을 갱신하지 않는다. 해당 artifact/provenance 갱신은 Stage 3 범위다.

## 산출물

| 파일 | 요약 |
|---|---|
| `RustBridge/Cargo.toml` | `rhwp` dependency에 `features = ["native-skia"]` 추가. |
| `RustBridge/Cargo.lock` | `skia-safe`, `skia-bindings` 등 native-skia 의존성 31개 추가. |
| `RustBridge/src/lib.rs` | `RhwpRenderStatus` enum과 `rhwp_render_page_png` FFI 추가. |
| `RustBridge/cbindgen.toml` | cbindgen export include에 `RhwpRenderStatus` 추가. |
| `mydocs/working/task_m020_255_stage2.md` | Stage 2 구현/검증 보고서. |
| `mydocs/orders/20260518.md` | #255 상태를 Stage 2 완료 및 Stage 3 승인 대기로 갱신. |

## 구현 내용

`RustBridge/Cargo.toml`의 `rhwp` dependency에 `features = ["native-skia"]`를 추가했다.

```toml
rhwp = { git = "https://github.com/edwardkim/rhwp.git", tag = "v0.7.11", features = ["native-skia"] }
```

`RustBridge/src/lib.rs`에는 `#[repr(C)] RhwpRenderStatus`를 추가했다.

- `RHWP_RENDER_OK`
- `RHWP_RENDER_INVALID_HANDLE`
- `RHWP_RENDER_INVALID_OUTPUT`
- `RHWP_RENDER_INVALID_PAGE_INDEX`
- `RHWP_RENDER_INVALID_OPTIONS`
- `RHWP_RENDER_FAILURE`

새 FFI는 다음 계약으로 구현했다.

```rust
pub extern "C" fn rhwp_render_page_png(
    handle: *const RhwpHandle,
    page: u32,
    scale: f64,
    max_dimension: u32,
    out_data: *mut *mut u8,
    out_len: *mut usize,
) -> RhwpRenderStatus
```

동작:

- `out_data` 또는 `out_len`이 null이면 `RHWP_RENDER_INVALID_OUTPUT`을 반환한다.
- 실패 경로에서는 output을 null/0으로 유지한다.
- null handle은 `RHWP_RENDER_INVALID_HANDLE`로 반환한다.
- NaN/infinite/negative scale 또는 `i32::MAX`를 넘는 `max_dimension`은 `RHWP_RENDER_INVALID_OPTIONS`로 반환한다.
- page index가 `page_count` 범위를 벗어나면 `RHWP_RENDER_INVALID_PAGE_INDEX`로 반환한다.
- `scale == 0.0`은 upstream `PngExportOptions.scale = None`으로 매핑한다.
- `max_dimension == 0`은 upstream `PngExportOptions.max_dimension = None`으로 매핑한다.
- 성공 시 PNG bytes를 caller 소유로 넘기고, 기존 `rhwp_free_bytes(ptr, len)`로 해제하게 한다.
- upstream error, empty bytes, panic guard 실패는 `RHWP_RENDER_FAILURE`로 반환한다.

## 본문 변경 정도 / 본문 무손실 여부

- RustBridge source와 Cargo dependency만 변경했다.
- generated framework/header/lock 파일은 아직 변경하지 않았다.
- 기존 FFI entrypoint 동작은 수정하지 않았고, 새 enum/function만 추가했다.
- 기존 문서 본문 삭제는 없다.

## 검증 결과

Stage 2 검증 명령:

```bash
cargo check --manifest-path RustBridge/Cargo.toml
```

결과: 통과.

최초 실행은 sandbox DNS 제한으로 `index.crates.io` resolution에 실패했다. 같은 명령을 네트워크 승인 후 재실행했고, `skia-safe v0.93.1`, `skia-bindings v0.93.1` 등을 받아 `rhwp_mac_bridge` check까지 완료했다.

```text
Checking rhwp_mac_bridge v0.1.0 (/Users/melee/Documents/projects/rhwp-mac/RustBridge)
Finished `dev` profile [unoptimized + debuginfo] target(s) in 22.07s
```

```bash
rg -n "RhwpRenderStatus|rhwp_render_page_png|native-skia|PngExportOptions|rhwp_free_bytes" RustBridge
```

결과: 통과. `RustBridge/src/lib.rs`, `Cargo.toml`, `cbindgen.toml`에서 새 ABI와 feature 설정을 확인했다.

```bash
git diff --check -- RustBridge/Cargo.toml RustBridge/Cargo.lock RustBridge/src/lib.rs RustBridge/cbindgen.toml
```

결과: 통과.

추가 확인:

```bash
rg -n 'name = "skia-safe"|name = "skia-bindings"|name = "rhwp"|source = "git\+https://github.com/edwardkim/rhwp.git' RustBridge/Cargo.lock
```

결과: `rhwp` resolved source는 기존 `v0.7.11#a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae`를 유지하고, `skia-bindings`, `skia-safe` package가 lock에 추가됐음을 확인했다.

## 잔여 위험

- `Frameworks/generated_rhwp.h`와 `Rhwp.xcframework`는 아직 구 ABI 상태다. Swift/Xcode build 검증은 Stage 3 artifact 갱신 뒤 수행해야 한다.
- `rhwp-ffi-symbols.txt`도 아직 `rhwp_render_page_png`를 포함하지 않는다. Stage 3에서 expected symbol set과 generated symbol set을 함께 갱신해야 한다.
- `RhwpRenderStatus`가 cbindgen header에서 원하는 C enum shape로 생성되는지는 Stage 3에서 확인해야 한다.
- `skia-safe` dependency로 staticlib와 package 크기가 증가할 가능성이 크며, Stage 3에서 수치를 기록해야 한다.
- `rhwp-core.lock`에는 아직 `native-skia` feature provenance가 없다. Stage 3에서 build script와 lock verification을 보강해야 한다.

## 다음 단계 영향

Stage 3에서는 generated artifact와 provenance gate를 갱신한다.

- `rhwp-ffi-symbols.txt`에 `rhwp_render_page_png` 추가
- `scripts/build-rust-macos.sh`에 `native-skia` feature provenance 기록/검증 보강
- `./scripts/build-rust-macos.sh --update-lock`
- `./scripts/build-rust-macos.sh --verify-lock`
- generated header/modulemap/staticlib/xcframework/lock diff 확인

Stage 3 전까지는 `Frameworks/generated_rhwp.h`와 `Rhwp.xcframework`가 Stage 2 source와 불일치하는 중간 상태다.

## 승인 요청

Stage 2는 RustBridge source-level PNG ABI 구현으로 마무리한다. Stage 3 `generated artifact와 provenance gate 갱신`으로 진행하려면 작업지시자 승인이 필요하다.
