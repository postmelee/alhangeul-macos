# Task M020 #408 구현계획서

수행계획서: `mydocs/plans/task_m020_408.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #408 `RustBridge external image context C ABI 구현`
- Parent: #407 `external image context ABI 후속 구현 추적`
- 선행 조사: #391 `filename/external image context ABI 조사 및 bridge 설계`
- 관련 측정: #404 `upstream 렌더 PR 대표 샘플 diff 측정`
- 마일스톤: M020 (`v0.2.x Skia Quick Look/Thumbnail Backend`)
- 기준 브랜치: `devel`
- 작업 브랜치: `local/task408`
- 목표: pinned `rhwp v0.7.17`의 filename context, external image references, key-based bytes injection API를 기존 ABI와 호환되는 RustBridge C ABI로 노출한다.

## 구현 전 확인 결론

pinned source `/Users/melee/.cargo/git/checkouts/rhwp-6f8f299952213fc0/0335119/src/wasm_api.rs`를 기준으로 다음을 확인했다.

| 항목 | pinned API | 구현 판단 |
|------|------------|-----------|
| native document 생성 | `HwpDocument::from_bytes(&[u8]) -> Result<HwpDocument, HwpError>` | `rhwp_open` 내부 생성 타입을 전환할 수 있다. |
| 기존 core API 접근 | `HwpDocument: Deref<Target = DocumentCore> + DerefMut` | page/render/image 함수는 기존 호출 형태를 유지할 수 있다. |
| filename context | `HwpDocument::set_file_name(&mut self, &str)` | UTF-8 setter C ABI로 직접 연결한다. |
| external refs | `HwpDocument::get_external_image_references(&self) -> String` | upstream JSON을 Rust-owned C string으로 반환한다. |
| key injection | `HwpDocument::inject_external_image_by_key(&mut self, &str, &[u8], &str) -> u32` | key/data/display path를 전달하고 결과를 status로 매핑한다. |
| refs JSON shape | `key`, `binDataId`, `originalPath`, `basename`, `extension`, `loaded` | #409 Swift decoder가 소비할 기준 shape로 사용한다. |
| 전체 image state | 별도 public API 없음 | optional `rhwp_image_state_json`은 이번 이슈에서 보류한다. |

`get_external_image_references`의 `loaded`는 external reference의 주입 여부를 나타내지만 embedded/missing/decode-failed 전체 상태를 표현하지 않는다. 따라서 이를 확장 해석해 `rhwp_image_state_json`을 만들지 않는다. external 상태는 refs JSON으로 전달하고, renderer decode failure는 #410에서 별도로 다룬다.

## 구현 원칙

- 기존 opaque `RhwpHandle`, `rhwp_open(data,len)`, 기존 공개 symbol의 signature와 의미를 유지한다.
- `RhwpHandle.doc`만 `DocumentCore`에서 `HwpDocument`로 전환하고, 기존 메서드는 `Deref/DerefMut`를 통해 호출한다.
- 신규 ABI는 setter/query/injection 세 함수와 하나의 `#[repr(C)]` status enum으로 제한한다.
- RustBridge는 external path를 열거나 directory를 탐색하지 않는다. Swift/macOS shell이 후속 #409에서 허용된 bytes를 읽어 주입한다.
- 모든 FFI entrypoint는 null/length 조합을 검사하고 panic을 C 경계 밖으로 전파하지 않는다.
- Rust가 반환한 refs JSON은 `rhwp_free_string`으로 해제한다. 입력 문자열과 bytes는 호출 동안 caller가 소유하고, upstream injection이 필요한 bytes를 document 내부로 복사한다.
- `rhwp_image_data`의 반환 포인터는 document-owned다. Swift는 즉시 `Data`로 복사하며, 특히 setter/injection 같은 mutable 호출을 넘겨 보관하지 않는다.
- upstream external refs JSON을 bridge 전용 shape로 재작성하지 않는다. 신규 필드 추가에 대응할 수 있도록 그대로 전달한다.
- exact external image fixture가 없는 상태를 숨기지 않는다. C ABI의 정상 injection visual 검증은 #409/#412로 넘기고, #408에서는 bridge contract와 기존 embedded 회귀를 필수 gate로 둔다.
- `RustBridge/Cargo.toml`, `Cargo.lock`, pinned release tag/commit은 변경하지 않는다. 추가 dependency 또는 feature가 필요해지면 해당 단계에서 범위 확장 승인을 요청한다.

## ABI 확정안

### Status enum

```c
typedef enum RhwpExternalImageStatus {
  RHWP_EXTERNAL_IMAGE_OK = 0,
  RHWP_EXTERNAL_IMAGE_INVALID_HANDLE = 1,
  RHWP_EXTERNAL_IMAGE_INVALID_INPUT = 2,
  RHWP_EXTERNAL_IMAGE_INVALID_UTF8 = 3,
  RHWP_EXTERNAL_IMAGE_REFERENCE_NOT_FOUND = 4,
  RHWP_EXTERNAL_IMAGE_ALREADY_LOADED = 5,
  RHWP_EXTERNAL_IMAGE_FAILURE = 6,
} RhwpExternalImageStatus;
```

| status | 의미 |
|--------|------|
| `OK` | filename 설정 또는 external image 주입 성공 |
| `INVALID_HANDLE` | null document handle |
| `INVALID_INPUT` | pointer/length 불일치, 빈 key 또는 빈 image bytes |
| `INVALID_UTF8` | filename, key 또는 display path가 UTF-8이 아님 |
| `REFERENCE_NOT_FOUND` | refs JSON에 전달된 key가 없음 |
| `ALREADY_LOADED` | 해당 reference의 `loaded`가 이미 `true` |
| `FAILURE` | refs JSON 해석 실패, upstream injection 0 반환, panic guard 실패 |

### Filename setter

```c
RhwpExternalImageStatus rhwp_set_file_name_utf8(
    struct RhwpHandle *handle,
    const uint8_t *name,
    uintptr_t name_len
);
```

- `name_len == 0`은 filename context를 빈 문자열로 지우는 유효 요청이다. 이 경우 `name == NULL`을 허용한다.
- `name_len > 0`이면 `name`은 non-null UTF-8 buffer여야 한다.
- upstream `set_file_name`이 page tree cache를 invalidation하는 동작을 유지한다.

### External refs query

```c
char *rhwp_external_image_refs_json(const struct RhwpHandle *handle);
```

- 성공 시 upstream JSON 배열 문자열을 반환한다. external ref가 없으면 `[]`이다.
- null handle, panic, CString 생성 실패 시 `NULL`이다.
- caller는 반환값을 `rhwp_free_string`으로 해제한다.

### Key-based injection

```c
RhwpExternalImageStatus rhwp_inject_external_image_by_key(
    struct RhwpHandle *handle,
    const uint8_t *key,
    uintptr_t key_len,
    const uint8_t *data,
    uintptr_t data_len,
    const uint8_t *display_path,
    uintptr_t display_path_len
);
```

- `key`와 `data`는 non-null, non-empty여야 한다.
- `display_path_len == 0`이면 `display_path == NULL`을 허용하고 upstream에 빈 문자열을 전달한다.
- refs JSON에서 key를 먼저 찾아 `REFERENCE_NOT_FOUND`와 `ALREADY_LOADED`를 구분한다.
- unloaded reference에 upstream `inject_external_image_by_key`가 `1`을 반환하면 `OK`, `0`이면 `FAILURE`다.
- input bytes와 strings는 호출 동안만 빌려 쓰며 RustBridge가 소유권을 해제하지 않는다.

### 이번 이슈에서 보류하는 ABI

```c
char *rhwp_image_state_json(struct RhwpHandle *handle, uint32_t bin_data_id);
```

pinned public API가 embedded/external/missing/injected 전체 상태를 제공하지 않으므로 구현하지 않는다. external reference 상태는 `rhwp_external_image_refs_json`의 `loaded`로 전달하고, 전체 image/renderer diagnostic은 #410에서 설계한다.

## Stage 1. `HwpDocument` handle 전환과 기존 ABI 호환성

### 목표

opaque C handle과 기존 symbol을 바꾸지 않고 내부 document 타입만 `HwpDocument`로 전환한다.

### 대상

- `RustBridge/src/lib.rs`
- `mydocs/working/task_m020_408_stage1.md`
- `mydocs/orders/20260710.md`

### 작업

1. `rhwp::DocumentCore` import를 `rhwp::wasm_api::HwpDocument`로 전환한다.
2. `RhwpHandle.doc` 타입을 `HwpDocument`로 변경한다.
3. `rhwp_open`이 `HwpDocument::from_bytes`를 사용하도록 변경한다.
4. `Deref/DerefMut`를 통한 기존 page count/size, SVG, render tree, overlay, Skia PNG, image data 호출이 compile되는지 확인한다.
5. 기존 공개 함수 signature와 `rhwp-ffi-symbols.txt`는 Stage 1에서 변경하지 않는다.

### 검증

```bash
cargo fmt --manifest-path RustBridge/Cargo.toml --check
cargo check --manifest-path RustBridge/Cargo.toml --locked
cargo test --manifest-path RustBridge/Cargo.toml --locked
git diff --check -- RustBridge/src/lib.rs mydocs/working/task_m020_408_stage1.md mydocs/orders/20260710.md
rg -n "HwpDocument|RhwpHandle|rhwp_open|page_count|get_page_info_native|build_page_render_tree|get_bin_data" \
  RustBridge/src/lib.rs mydocs/working/task_m020_408_stage1.md
```

### 완료 조건

- RustBridge가 pinned dependency와 lock을 유지한 채 check/test를 통과한다.
- 기존 C 함수 signature와 symbol 목록에 변경이 없다.
- handle 전환으로 확인된 수명·mutation 제약이 Stage 1 보고서에 기록되어 있다.

### 커밋

```text
Task #408 Stage 1: HwpDocument handle 전환과 기존 ABI 호환성 확인
```

## Stage 2. External image context C ABI와 Rust 검증 구현

### 목표

filename setter, external refs query, key injection과 status contract를 구현한다.

### 대상

- `RustBridge/src/lib.rs`
- `RustBridge/cbindgen.toml`
- `mydocs/working/task_m020_408_stage2.md`
- `mydocs/orders/20260710.md`

### 작업

1. `RhwpExternalImageStatus`를 `#[repr(C)]` enum으로 추가하고 cbindgen export 목록에 포함한다.
2. pointer/length 쌍을 빈 값 허용 여부에 따라 안전하게 `&[u8]`와 `&str`로 변환하는 private helper를 추가한다.
3. `rhwp_set_file_name_utf8`를 구현한다.
4. `rhwp_external_image_refs_json`을 구현하고 기존 `string_to_c`/`rhwp_free_string` 계약을 재사용한다.
5. refs JSON의 `key`와 `loaded`만 `serde_json::Value`로 preflight해 injection status를 구분한다. bridge 전용 DTO나 신규 serde dependency는 추가하지 않는다.
6. `rhwp_inject_external_image_by_key`를 구현한다.
7. `#[cfg(test)]` unit test에서 null handle, pointer/length 불일치, invalid UTF-8, empty key/data, ref 미존재, refs JSON validity를 확인한다.
8. repository 기본 샘플을 `CARGO_MANIFEST_DIR` 기준으로 읽어 `rhwp_open -> refs query -> free -> close` lifecycle을 검증한다.
9. exact external fixture가 발견되면 성공 injection과 `loaded: false -> true`를 추가 검증하고, 없으면 #412 의존성을 명시한다.

### 검증

```bash
cargo fmt --manifest-path RustBridge/Cargo.toml --check
cargo check --manifest-path RustBridge/Cargo.toml --locked
cargo test --manifest-path RustBridge/Cargo.toml --locked
rg -n "RhwpExternalImageStatus|rhwp_set_file_name_utf8|rhwp_external_image_refs_json|rhwp_inject_external_image_by_key|REFERENCE_NOT_FOUND|ALREADY_LOADED" \
  RustBridge/src/lib.rs RustBridge/cbindgen.toml mydocs/working/task_m020_408_stage2.md
git diff --check -- RustBridge/src/lib.rs RustBridge/cbindgen.toml mydocs/working/task_m020_408_stage2.md mydocs/orders/20260710.md
```

### 완료 조건

- 세 신규 함수와 status enum이 구현되어 있다.
- invalid input과 refs query lifecycle이 Rust test로 고정되어 있다.
- RustBridge가 filesystem lookup을 수행하지 않는다.
- `rhwp_image_state_json` 보류 판단이 Stage 2 보고서에 명시되어 있다.

### 커밋

```text
Task #408 Stage 2: external image context C ABI 구현
```

## Stage 3. Header, symbol, provenance와 ABI 문서 갱신

### 목표

새 ABI를 generated header와 symbol lock에 반영하고, artifact metadata와 ownership 문서를 맞춘다.

### 대상

- `rhwp-ffi-symbols.txt`
- `rhwp-core.lock`
- `RustBridge/README.md`
- `mydocs/tech/project_architecture.md`
- `Frameworks/generated_rhwp.h` 및 generated artifacts
- `mydocs/working/task_m020_408_stage3.md`
- `mydocs/orders/20260710.md`

### 작업

1. `rhwp-ffi-symbols.txt`에 다음 세 symbol을 추가한다.
   - `rhwp_set_file_name_utf8`
   - `rhwp_external_image_refs_json`
   - `rhwp_inject_external_image_by_key`
2. `./scripts/build-rust-macos.sh --update-lock`으로 universal staticlib, header, xcframework를 재생성한다.
3. generated header에서 enum 값, const/mutable handle, pointer/length 타입을 검토한다.
4. generated symbol set과 expected symbol set이 일치하는지 확인한다.
5. `rhwp-core.lock`의 source tag/commit/features는 유지하고 artifact hash/size와 build timestamp만 의도대로 갱신한다.
6. `RustBridge/README.md`와 `project_architecture.md`에 신규 ABI, refs JSON, string/input/image-data ownership과 `rhwp_image_state_json` 보류를 기록한다.
7. generated `Frameworks/**`는 검증에 사용하되 저장소 정책대로 commit하지 않는다.

### 검증

```bash
./scripts/build-rust-macos.sh --update-lock
./scripts/build-rust-macos.sh --verify-lock
rg -n "RhwpExternalImageStatus|rhwp_set_file_name_utf8|rhwp_external_image_refs_json|rhwp_inject_external_image_by_key" \
  Frameworks/generated_rhwp.h Frameworks/generated_rhwp_symbols.txt rhwp-ffi-symbols.txt
nm -gU Frameworks/universal/librhwp.a | rg "rhwp_(set_file_name_utf8|external_image_refs_json|inject_external_image_by_key)"
rg -n "v0.7.17|03351190ec35436e58cbfee0aa9278a8fdc04a59|native-skia" rhwp-core.lock
git diff --check -- rhwp-ffi-symbols.txt rhwp-core.lock RustBridge/README.md mydocs/tech/project_architecture.md mydocs/working/task_m020_408_stage3.md mydocs/orders/20260710.md
```

### 완료 조건

- generated header와 staticlib에 세 신규 symbol과 status enum이 존재한다.
- expected/generated symbol set과 lock verification이 통과한다.
- core source provenance는 변경되지 않고 artifact metadata만 갱신되어 있다.
- #409가 참조할 ABI와 ownership 규칙이 저장소 문서에 기록되어 있다.

### 커밋

```text
Task #408 Stage 3: external image ABI artifact와 계약 문서 갱신
```

## Stage 4. Swift compile/link와 embedded render 회귀 검증

### 목표

기존 Swift caller와 embedded image/render 경로가 additive ABI 변경 이후에도 정상 동작하는지 확인한다.

### 대상

- generated `Frameworks/Rhwp.xcframework`
- `Sources/RhwpCoreBridge/RhwpDocument.swift` 읽기/compile 대상
- `samples/basic/KTX.hwp`
- `samples/basic/request.hwp`
- `samples/hwp-img-001.hwp`
- `mydocs/working/task_m020_408_stage4.md`
- `mydocs/orders/20260710.md`

### 작업

1. no-AppKit 경계 검사를 실행한다.
2. `xcodegen generate` 후 HostApp Debug compile/link를 확인한다.
3. `validate-stage3-render.sh` 기본 fixture로 page count/size/render tree/native bitmap 회귀를 확인한다.
4. image fixture를 추가 지정해 기존 `bin_data_id` lookup과 embedded image가 누락되지 않는지 확인한다.
5. Rust unit test와 staticlib symbol 검사를 다시 실행한다.
6. Quick Look/Thumbnail extension 등록 smoke는 제품 경로를 바꾸지 않으므로 실행하지 않는다.
7. #409 handoff용으로 Swift import 결과의 enum/function signature를 Stage 4 보고서에 기록한다.

### 검증

```bash
./scripts/build-rust-macos.sh --verify-lock
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
./scripts/validate-stage3-render.sh
./scripts/validate-stage3-render.sh build.noindex/task408-render samples/hwp-img-001.hwp
cargo test --manifest-path RustBridge/Cargo.toml --locked
nm -gU Frameworks/universal/librhwp.a | rg "rhwp_(open|image_data|set_file_name_utf8|external_image_refs_json|inject_external_image_by_key|close)"
git diff --check
```

### 완료 조건

- HostApp Debug compile/link가 통과한다.
- 기본 및 image fixture render smoke가 통과한다.
- 기존 embedded image lookup과 기존 symbol에 회귀가 없다.
- Swift가 import한 신규 enum/function signature가 #409 구현에 충분히 기록되어 있다.

### 커밋

```text
Task #408 Stage 4: Swift 호환성과 embedded image 회귀 검증
```

## Stage 5. 최종 보고서와 #409 handoff

### 목표

구현 결과와 검증 근거를 정리하고 후속 Swift resolver 작업이 소비할 계약을 확정한다.

### 대상

- `mydocs/report/task_m020_408_report.md`
- `mydocs/orders/20260710.md`

### 작업

1. Stage 1-4 변경과 검증 결과를 최종 보고서에 요약한다.
2. 최종 공개 symbol, enum 값, refs JSON shape, pointer/length 규칙, free/lifetime 규칙을 정리한다.
3. `rhwp_image_state_json` 보류와 exact external fixture 미측정 여부를 잔여 리스크로 기록한다.
4. #409의 Swift wrapper/resolver가 구현해야 할 mapping을 명시한다.
5. 오늘할일을 완료로 갱신하고 task-final-report 전 최종 승인 지점으로 이동한다.

### 검증

```bash
rg -n "#408|#409|RhwpExternalImageStatus|rhwp_set_file_name_utf8|rhwp_external_image_refs_json|rhwp_inject_external_image_by_key|ownership|loaded|보류" \
  mydocs/report/task_m020_408_report.md mydocs/orders/20260710.md
./scripts/build-rust-macos.sh --verify-lock
cargo test --manifest-path RustBridge/Cargo.toml --locked
git diff --check
git log --oneline origin/devel..HEAD
```

### 완료 조건

- 최종 보고서가 ABI, artifact, 검증, 잔여 리스크와 #409 handoff를 포함한다.
- 오늘할일이 완료 처리되어 있다.
- working tree가 clean이고 최종 PR 게시 전 승인을 요청할 수 있다.

### 커밋

```text
Task #408 Stage 5 + 최종 보고서: external image C ABI 완료 정리
```

## 단계별 승인 지점

1. 이 구현계획서 승인 후 Stage 1을 시작한다.
2. Stage 1 완료보고서 승인 후 Stage 2를 시작한다.
3. Stage 2 완료보고서 승인 후 Stage 3을 시작한다.
4. Stage 3 완료보고서 승인 후 Stage 4를 시작한다.
5. Stage 4 완료보고서 승인 후 Stage 5를 시작한다.
6. 최종 결과보고서 승인 후 `task-final-report` 절차로 PR을 게시한다.

구현계획서 승인 전에는 `RustBridge/src/lib.rs`, cbindgen 설정, FFI symbol lock, generated artifact를 변경하지 않는다.
