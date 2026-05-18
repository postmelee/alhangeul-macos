# Task M020 #255 구현 계획서

수행계획서: `mydocs/plans/task_m020_255.md`

## 작업 개요

- 이슈: #255 RustBridge native-skia PNG FFI와 build/provenance gate 추가
- 마일스톤: `v0.2.x Skia Quick Look/Thumbnail Backend`
- 브랜치: `local/task255`
- 목표: `rhwp v0.7.11`의 `native-skia` PNG renderer를 RustBridge staticlib에 포함하고, Swift가 후속 #256에서 호출할 수 있는 C ABI와 artifact/provenance 검증 기준을 추가한다.

## 구현 원칙

- 제품 surface의 기본 동작은 이 이슈에서 바꾸지 않는다. Swift wrapper, Shared renderer, Quick Look/Thumbnail provider 적용은 #256-#258 범위다.
- RustBridge ABI는 기존 `rhwp_*` 패턴을 따른다. null pointer 방어, panic 격리, Rust 소유 buffer의 `rhwp_free_bytes` 해제를 유지한다.
- upstream `rhwp` core는 수정하지 않는다. 현재 release tag `v0.7.11`와 resolved commit `a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae`를 유지한다.
- C ABI는 Swift fallback 진단이 가능한 status code를 반환한다. 실패를 단순 `false`로만 숨기지 않는다.
- 초기 PNG option은 Quick Look/Thumbnail에 필요한 `scale`, `max_dimension`에 한정한다. `font_paths`, `dpi`, `vlm_target`은 ABI 확장 후보로 남긴다.
- generated header, symbol lock, `Rhwp.xcframework`, staticlib, `rhwp-core.lock`은 같은 stage에서 함께 갱신한다.

## ABI 초안

Stage 2에서 구현할 ABI 후보는 다음 형태로 고정한다.

```c
typedef enum RhwpRenderStatus {
  RHWP_RENDER_OK = 0,
  RHWP_RENDER_INVALID_HANDLE = 1,
  RHWP_RENDER_INVALID_OUTPUT = 2,
  RHWP_RENDER_INVALID_PAGE_INDEX = 3,
  RHWP_RENDER_INVALID_OPTIONS = 4,
  RHWP_RENDER_FAILURE = 5,
} RhwpRenderStatus;

RhwpRenderStatus rhwp_render_page_png(const struct RhwpHandle *handle,
                                      uint32_t page,
                                      double scale,
                                      uint32_t max_dimension,
                                      uint8_t **out_data,
                                      uintptr_t *out_len);
```

Swift fallback mapping 후보:

| ABI status | Swift fallback reason 후보 | 의미 |
|---|---|---|
| `RHWP_RENDER_OK` | 없음 | PNG bytes가 `out_data/out_len`으로 반환됨 |
| `RHWP_RENDER_INVALID_HANDLE` | `invalidDocumentHandle` 또는 `ffiUnavailable` | null handle 또는 유효하지 않은 document handle |
| `RHWP_RENDER_INVALID_OUTPUT` | `ffiUnavailable` | caller가 output pointer를 제공하지 않음 |
| `RHWP_RENDER_INVALID_PAGE_INDEX` | `invalidPageIndex` | page index가 `page_count` 범위를 벗어남 |
| `RHWP_RENDER_INVALID_OPTIONS` | `invalidPageSize` 또는 `invalidRenderOptions` | `scale`, `max_dimension`, 계산된 page/pixel size가 유효하지 않음 |
| `RHWP_RENDER_FAILURE` | `skiaRenderFailure` | upstream Skia rendering error 또는 panic guard 실패 |

Option sentinel:

- `scale == 0.0`: upstream `PngExportOptions.scale = None`
- `scale > 0.0 && scale.is_finite()`: upstream `PngExportOptions.scale = Some(scale)`
- `scale < 0.0`, NaN, infinite: `RHWP_RENDER_INVALID_OPTIONS`
- `max_dimension == 0`: upstream `PngExportOptions.max_dimension = None`
- `max_dimension > 0`: upstream `PngExportOptions.max_dimension = Some(max_dimension as i32)`

## Stage 1. ABI와 upstream API inventory

대상:

- `RustBridge/Cargo.toml`
- `RustBridge/Cargo.lock`
- `RustBridge/src/lib.rs`
- `RustBridge/cbindgen.toml`
- `rhwp-ffi-symbols.txt`
- `Frameworks/generated_rhwp.h`
- `scripts/build-rust-macos.sh`
- upstream checkout: `/Users/melee/.cargo/git/checkouts/rhwp-6f8f299952213fc0/a9dcdee`
- `mydocs/tech/skia_quicklook_thumbnail_backend.md`

작업:

1. `native-skia` feature와 `skia-safe` dependency 조건을 확인한다.
2. `DocumentCore::render_page_png_native*`와 `PngExportOptions` signature를 확인한다.
3. 기존 RustBridge FFI pattern과 cbindgen export 방식을 확인한다.
4. build/provenance script가 source lock, symbol lock, artifact hash/size를 어떻게 검증하는지 확인한다.
5. Stage 1 보고서를 작성한다.

산출물:

- `mydocs/plans/task_m020_255_impl.md`
- `mydocs/working/task_m020_255_stage1.md`

검증:

```bash
rg -n "native-skia|render_page_png_native|PngExportOptions|RhwpRenderStatus|rhwp_render_page_png|provenance|rhwp_free_bytes" \
  mydocs/plans/task_m020_255_impl.md mydocs/working/task_m020_255_stage1.md RustBridge scripts/build-rust-macos.sh rhwp-ffi-symbols.txt
git diff --check -- mydocs/plans/task_m020_255_impl.md mydocs/working/task_m020_255_stage1.md mydocs/orders/20260518.md
```

완료 조건:

- upstream API와 앱 ABI 후보의 대응이 문서화되어 있다.
- Stage 2에서 어떤 파일을 어떻게 바꿀지 명확하다.
- 아직 RustBridge source나 generated artifact를 변경하지 않는다.

커밋:

```text
Task #255 Stage 1: Skia PNG ABI inventory 정리
```

## Stage 2. RustBridge `native-skia` feature와 PNG FFI 구현

대상:

- `RustBridge/Cargo.toml`
- `RustBridge/Cargo.lock`
- `RustBridge/src/lib.rs`
- `RustBridge/cbindgen.toml`

작업:

1. `rhwp` dependency에 `features = ["native-skia"]`를 추가한다.
2. `RhwpRenderStatus`를 `#[repr(C)]`로 추가하고 cbindgen export 대상에 포함한다.
3. `rhwp_render_page_png`를 추가한다.
4. output pointer는 실패 시 항상 null/0으로 초기화한다.
5. page range, scale, max_dimension을 먼저 검증한다.
6. upstream `PngExportOptions`를 구성해 `render_page_png_native_with_export_options`를 호출한다.
7. 성공한 PNG bytes는 boxed slice 또는 `Vec` 소유권을 caller에게 넘기고 `rhwp_free_bytes`로 해제되게 한다.

검증:

```bash
cargo check --manifest-path RustBridge/Cargo.toml
rg -n "RhwpRenderStatus|rhwp_render_page_png|native-skia|PngExportOptions|rhwp_free_bytes" RustBridge
git diff --check -- RustBridge/Cargo.toml RustBridge/Cargo.lock RustBridge/src/lib.rs RustBridge/cbindgen.toml
```

완료 조건:

- RustBridge crate가 `native-skia` feature 활성화 상태로 check를 통과한다.
- status code와 output buffer contract가 구현되어 있다.
- generated artifact는 아직 이 stage에서 갱신하지 않는다.

커밋:

```text
Task #255 Stage 2: RustBridge Skia PNG FFI 구현
```

## Stage 3. generated artifact와 provenance gate 갱신

대상:

- `rhwp-ffi-symbols.txt`
- `Frameworks/generated_rhwp.h`
- `Frameworks/generated_rhwp_symbols.txt`
- `Frameworks/modulemap/rhwp.h`
- `Frameworks/Rhwp.xcframework/**`
- `Frameworks/universal/librhwp.a`
- `rhwp-core.lock`

작업:

1. `rhwp-ffi-symbols.txt`에 새 symbol을 추가한다.
2. `./scripts/build-rust-macos.sh --update-lock`을 실행한다.
3. cbindgen header와 modulemap header에 새 enum/function이 생성됐는지 확인한다.
4. `Frameworks/generated_rhwp_symbols.txt`와 expected symbol set이 일치하는지 확인한다.
5. `rhwp-core.lock`의 source provenance가 기존 release tag/commit을 유지하면서 artifact hash/size만 의도대로 바뀌었는지 확인한다.
6. staticlib와 xcframework 크기 변화를 기록한다.

검증:

```bash
./scripts/build-rust-macos.sh --update-lock
./scripts/build-rust-macos.sh --verify-lock
rg -n "RhwpRenderStatus|rhwp_render_page_png|RHWP_RENDER_OK" \
  Frameworks/generated_rhwp.h Frameworks/modulemap/rhwp.h rhwp-ffi-symbols.txt Frameworks/generated_rhwp_symbols.txt
du -sh Frameworks/universal/librhwp.a Frameworks/Rhwp.xcframework
git diff --check -- rhwp-core.lock rhwp-ffi-symbols.txt Frameworks/generated_rhwp.h Frameworks/generated_rhwp_symbols.txt Frameworks/modulemap/rhwp.h
```

완료 조건:

- generated header와 symbol lock이 새 ABI를 반영한다.
- `Rhwp.xcframework`와 universal staticlib가 재생성된다.
- lock verification이 통과한다.
- size 변화가 Stage 3 보고서에 남는다.

커밋:

```text
Task #255 Stage 3: Skia ABI generated artifact 갱신
```

## Stage 4. ABI smoke와 실패 경로 검증

대상:

- `RustBridge/examples` 또는 임시 smoke command
- `samples/basic/KTX.hwp`
- `samples/basic/request.hwp`
- `mydocs/working/task_m020_255_stage4.md`

작업:

1. 가능한 경우 RustBridge example 또는 작은 smoke로 `rhwp_open -> rhwp_render_page_png -> rhwp_free_bytes -> rhwp_close` 호출 흐름을 검증한다.
2. 대표 정상 샘플에서 PNG signature와 byte length를 확인한다.
3. null handle, out-of-range page, invalid scale 실패 status를 확인한다.
4. smoke가 별도 example 추가 없이 shell/Rust one-off로 충분하면 generated source를 남기지 않는다.
5. Swift wrapper가 없는 상태에서 #256 handoff에 필요한 제한을 정리한다.

검증:

```bash
./scripts/build-rust-macos.sh --verify-lock
nm -gU Frameworks/universal/librhwp.a | rg "rhwp_render_page_png|rhwp_free_bytes|rhwp_open|rhwp_close"
git diff --check
```

완료 조건:

- 새 symbol이 universal staticlib에 존재한다.
- 정상/실패 경로의 ABI 결과가 최소 수준으로 확인된다.
- Swift 적용 전 잔여 위험이 문서화되어 있다.

커밋:

```text
Task #255 Stage 4: Skia PNG ABI smoke 검증
```

## Stage 5. 최종 보고서와 PR 준비

대상:

- `mydocs/report/task_m020_255_report.md`
- `mydocs/orders/20260518.md`

작업:

1. Stage 1-4 산출물과 검증 결과를 최종 보고서에 정리한다.
2. #256 handoff 조건을 명확히 남긴다.
3. 오늘할일 상태를 완료로 갱신한다.
4. 최종 커밋 후 `publish/task255` push와 PR 생성을 준비한다.

검증:

```bash
rg -n "#255|native-skia|rhwp_render_page_png|RhwpRenderStatus|Rhwp.xcframework|rhwp-core.lock|#256" \
  mydocs/report/task_m020_255_report.md mydocs/orders/20260518.md
git diff --check
git log --oneline origin/devel..HEAD
```

완료 조건:

- 최종 보고서가 ABI, artifact, provenance, size, residual risk를 포함한다.
- #256이 사용할 입력이 명확하다.
- 작업트리가 clean이고 PR 생성 준비가 끝난다.

커밋:

```text
Task #255 Stage 5 + 최종 보고서: Skia PNG ABI 정리
```
