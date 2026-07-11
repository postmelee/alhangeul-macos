# Task M020 #408 Stage 2 보고서

## 단계 목적

Stage 2의 목적은 Stage 1에서 전환한 `HwpDocument` handle 위에 filename context setter, external image references JSON query, key-based bytes injection C ABI를 additive 방식으로 구현하고, Swift가 후속 #409에서 사용할 status와 pointer/length 계약을 Rust test로 고정하는 것이다.

이 단계에서는 generated header/staticlib/xcframework, expected symbol lock, artifact provenance를 갱신하지 않는다. 해당 작업은 Stage 3 범위다.

## 산출물

| 파일 | 변경 요약 |
|------|-----------|
| `RustBridge/src/lib.rs` | `RhwpExternalImageStatus`, 세 C ABI, pointer/length helper, refs preflight helper, unit test 4개를 추가했다. 현재 649줄이다. |
| `RustBridge/cbindgen.toml` | `RhwpExternalImageStatus`를 export include에 추가했다. 현재 14줄이다. |
| `mydocs/working/task_m020_408_stage2.md` | Stage 2 구현 계약, 검증 결과, 보류 항목과 Stage 3 handoff를 기록한다. |
| `mydocs/orders/20260711.md` | 날짜 변경에 맞춰 #408 진행 행을 만들고 Stage 2 완료 및 Stage 3 승인 대기로 갱신한다. |

## 구현 결과

### `RhwpExternalImageStatus`

`#[repr(C)]` enum을 다음 값으로 고정했다.

| 값 | 이름 | 의미 |
|----|------|------|
| 0 | `RHWP_EXTERNAL_IMAGE_OK` | filename 설정 또는 bytes injection 성공 |
| 1 | `RHWP_EXTERNAL_IMAGE_INVALID_HANDLE` | null document handle |
| 2 | `RHWP_EXTERNAL_IMAGE_INVALID_INPUT` | pointer/length 불일치, 빈 key 또는 빈 data |
| 3 | `RHWP_EXTERNAL_IMAGE_INVALID_UTF8` | filename, key 또는 display path UTF-8 오류 |
| 4 | `RHWP_EXTERNAL_IMAGE_REFERENCE_NOT_FOUND` | refs JSON에 key가 없음 |
| 5 | `RHWP_EXTERNAL_IMAGE_ALREADY_LOADED` | refs JSON의 `loaded`가 이미 `true` |
| 6 | `RHWP_EXTERNAL_IMAGE_FAILURE` | JSON shape 오류, upstream injection 실패 또는 panic |

status enum은 기존 `RhwpRenderStatus`와 독립적이며 기존 enum 값이나 ABI를 변경하지 않는다.

### `rhwp_set_file_name_utf8`

```c
RhwpExternalImageStatus rhwp_set_file_name_utf8(
    RhwpHandle *handle,
    const uint8_t *name,
    uintptr_t name_len
);
```

- null handle을 status 1로 반환한다.
- `name_len == 0`이면 null pointer를 허용하고 filename을 빈 문자열로 설정한다.
- `name_len > 0`이면 non-null UTF-8 buffer가 필요하다.
- `HwpDocument::set_file_name`을 호출해 upstream page tree cache invalidation 동작을 유지한다.
- panic은 status 6으로 격리한다.

### `rhwp_external_image_refs_json`

```c
char *rhwp_external_image_refs_json(const RhwpHandle *handle);
```

- upstream `HwpDocument::get_external_image_references()` 결과를 재가공하지 않고 Rust-owned C string으로 반환한다.
- external ref가 없으면 upstream 계약대로 `[]`를 반환한다.
- null handle 또는 panic이면 null pointer다.
- caller는 반환값을 기존 `rhwp_free_string`으로 해제한다.
- JSON 기준 필드는 `key`, `binDataId`, `originalPath`, `basename`, `extension`, `loaded`다.

### `rhwp_inject_external_image_by_key`

```c
RhwpExternalImageStatus rhwp_inject_external_image_by_key(
    RhwpHandle *handle,
    const uint8_t *key,
    uintptr_t key_len,
    const uint8_t *data,
    uintptr_t data_len,
    const uint8_t *display_path,
    uintptr_t display_path_len
);
```

- key와 data는 non-null/non-empty여야 한다.
- display path는 빈 값일 수 있고 길이가 0이면 null pointer를 허용한다.
- production path는 전달받은 bytes만 upstream에 주입하며 파일이나 directory를 열지 않는다.
- refs JSON의 `key`와 `loaded`만 `serde_json::Value`로 preflight한다.
- key 미존재와 이미 loaded 상태를 upstream의 단일 `0` 반환에서 분리해 status 4/5로 표현한다.
- unloaded reference에 upstream API가 `1`을 반환하면 status 0, `0`이면 status 6이다.
- input buffer는 호출 동안 caller-owned이며 upstream injection이 필요한 bytes를 document 내부로 복사한다.

### Private helper와 pointer 수명

`borrowed_input_bytes`와 `borrowed_input_utf8`은 pointer/length 조합을 공통 검증한다. 빈 값 허용 여부를 caller가 지정하며 non-empty buffer는 호출 동안 readable해야 한다는 safety contract를 source comment로 남겼다.

`external_image_reference_loaded`는 upstream refs JSON에서 key와 loaded boolean만 읽는다. 별도 DTO나 `serde` dependency를 추가하지 않아 pinned dependency graph를 유지한다.

### `rhwp_image_state_json` 보류

pinned `v0.7.17` public API에는 embedded/external/missing/injected 전체 image 상태를 반환하는 함수가 없다. refs JSON의 `loaded`를 전체 image 상태로 확장 해석하면 embedded missing 또는 renderer decode failure를 잘못 표현할 수 있으므로 `rhwp_image_state_json`은 구현하지 않았다.

- external reference 상태: 이번 `rhwp_external_image_refs_json`
- renderer missing/decode diagnostic: #410
- exact external/large fixture와 visual regression: #412

## Unit test

`RustBridge/src/lib.rs`의 `#[cfg(test)]` module에 다음 4개 test를 추가했다.

| test | 검증 내용 |
|------|-----------|
| `filename_context_validates_handle_and_utf8` | null handle, 빈 filename, 정상 UTF-8, invalid UTF-8, pointer/length 불일치 |
| `external_refs_json_has_owned_string_lifecycle` | repository KTX fixture open, page count, refs JSON UTF-8/array, `rhwp_free_string`, close lifecycle |
| `injection_validates_inputs_and_missing_reference` | null handle, 빈 key/data, invalid key/display UTF-8, 미존재 key status |
| `external_reference_lookup_reads_loaded_state` | synthetic refs JSON의 `loaded=false`, `loaded=true`, key 미존재, 필드/array shape 오류 |

repository 기본 sample에서는 exact external reference fixture를 확인하지 못했다. 따라서 실제 bytes injection 후 `loaded: false -> true` end-to-end test는 추가하지 않았으며 #412 fixture 의존성을 유지한다. 대신 status 5 판정의 입력인 refs preflight는 synthetic JSON test로 고정했다.

## 본문 변경 정도 / 본문 무손실 여부

- 기존 공개 함수와 enum은 수정하지 않았다.
- 신규 enum, 세 함수, private helper, test module만 additive로 추가했다.
- `RustBridge/Cargo.toml`, `Cargo.lock`, `rhwp-ffi-symbols.txt`, `rhwp-core.lock`은 변경하지 않았다.
- production RustBridge 코드에는 filesystem lookup, path normalization, logging을 추가하지 않았다.
- Quick Look/Thumbnail/Swift source와 generated framework는 변경하지 않았다.
- `cargo fmt` 결과 Stage 1에서 정규화한 기존 코드에는 추가 formatting diff가 생기지 않았다.

## 검증 결과

### 계획서 필수 gate

```bash
cargo fmt --manifest-path RustBridge/Cargo.toml --check
```

결과: 통과.

```bash
cargo check --manifest-path RustBridge/Cargo.toml --locked
```

결과: 통과.

```text
Checking rhwp_mac_bridge v0.1.0 (.../RustBridge)
Finished `dev` profile [unoptimized + debuginfo]
```

```bash
cargo test --manifest-path RustBridge/Cargo.toml --locked
```

결과: 4개 test 모두 통과.

```text
running 4 tests
test tests::external_reference_lookup_reads_loaded_state ... ok
test tests::external_refs_json_has_owned_string_lifecycle ... ok
test tests::filename_context_validates_handle_and_utf8 ... ok
test tests::injection_validates_inputs_and_missing_reference ... ok
test result: ok. 4 passed; 0 failed
```

```bash
rg -n "RhwpExternalImageStatus|rhwp_set_file_name_utf8|rhwp_external_image_refs_json|rhwp_inject_external_image_by_key|REFERENCE_NOT_FOUND|ALREADY_LOADED" \
  RustBridge/src/lib.rs RustBridge/cbindgen.toml mydocs/working/task_m020_408_stage2.md
git diff --check -- RustBridge/src/lib.rs RustBridge/cbindgen.toml \
  mydocs/working/task_m020_408_stage2.md mydocs/orders/20260710.md
git diff --check
```

결과: 통과. 구현계획서가 참조한 7월 10일 orders 파일은 Stage 1 기록으로 유지하고, 날짜가 바뀐 현재 진행 상태는 `mydocs/orders/20260711.md`에 기록했다. 전체 diff check로 신규 오늘할일도 함께 검증했다.

### cbindgen 임시 header

```bash
cbindgen --quiet --config RustBridge/cbindgen.toml --crate rhwp_mac_bridge \
  --output /private/tmp/task408_rhwp.h RustBridge
rg -n -A24 -B4 "RhwpExternalImageStatus|rhwp_set_file_name_utf8|rhwp_external_image_refs_json|rhwp_inject_external_image_by_key" \
  /private/tmp/task408_rhwp.h
```

결과: 통과. 임시 header에서 enum 값 0-6, mutable setter/injection handle, const refs query handle, `uintptr_t` length와 세 함수 선언을 확인했다. 이 임시 파일은 repository 산출물이 아니며 정식 generated artifact 갱신은 Stage 3에서 수행한다.

### Clippy 보강 검증

```bash
cargo clippy --manifest-path RustBridge/Cargo.toml --locked -- \
  -D warnings -A clippy::not_unsafe_ptr_arg_deref
```

결과: 통과.

allow 없이 실행하면 기존 모든 public safe C ABI 함수가 raw pointer를 역참조한다는 `clippy::not_unsafe_ptr_arg_deref` 38건으로 실패한다. 이는 이번 신규 함수만의 문제가 아니라 current crate의 C ABI 정책 전반에 해당한다. C ABI를 `unsafe extern`으로 바꾸는 breaking source-contract 검토는 #408 범위에 포함하지 않고, 해당 lint만 명시적으로 허용한 상태에서 나머지 warning을 `-D warnings`로 확인했다.

### 무변경 계약 확인

```bash
git diff -- RustBridge/Cargo.toml RustBridge/Cargo.lock rhwp-ffi-symbols.txt rhwp-core.lock
```

결과: 빈 diff. dependency, expected symbol set, core provenance와 artifact lock은 Stage 2에서 변경하지 않았다.

## 잔여 위험

- exact external image fixture가 없어 실제 injection 성공과 document image data/render 반영은 아직 end-to-end로 검증하지 못했다. #409 Preview 적용과 #412 fixture suite에서 검증해야 한다.
- `ALREADY_LOADED` status는 upstream refs JSON의 `loaded` 필드에 의존한다. 이번 단계에서는 synthetic JSON으로 판정 로직을 검증했으며 실제 fixture 확인은 남아 있다.
- upstream refs JSON이 array가 아니거나 `loaded` boolean을 잃으면 status 6으로 보수적으로 실패한다. #409 Swift는 이를 resolver 실패와 구분해 bridge failure로 처리해야 한다.
- current Rust FFI는 C caller 편의를 위해 safe `extern "C"` 함수가 raw pointer를 처리한다. Clippy의 해당 lint는 crate-wide 기존 정책과 충돌하며, Rust caller safety surface를 별도 정리하려면 독립 이슈가 필요하다.
- `rhwp_image_data` document-owned pointer는 injection 같은 mutable 호출을 넘겨 보관하면 안 된다. #409 Swift wrapper는 각 조회 결과를 즉시 `Data`로 복사해야 한다.
- expected symbol lock은 아직 세 신규 symbol을 포함하지 않으므로 정식 build script는 Stage 3 갱신 전까지 symbol diff로 실패하는 것이 정상이다.

## 다음 단계 영향

Stage 3에서는 다음을 수행한다.

1. `rhwp-ffi-symbols.txt`에 세 신규 symbol을 추가한다.
2. `build-rust-macos.sh --update-lock`으로 universal staticlib, generated header, generated symbol set, xcframework를 재생성한다.
3. `rhwp-core.lock`의 source tag/commit/features는 유지하고 artifact hash/size와 timestamp를 갱신한다.
4. generated header의 enum/function signature와 expected symbol set을 검증한다.
5. `RustBridge/README.md`와 `mydocs/tech/project_architecture.md`에 ABI와 ownership 계약을 문서화한다.

## 승인 요청

Stage 2 `External image context C ABI와 Rust 검증 구현`은 완료됐다. Stage 3 `Header, symbol, provenance와 ABI 문서 갱신`으로 진행하려면 작업지시자 승인이 필요하다.
