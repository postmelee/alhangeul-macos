# Task M020 #447 Stage 2 완료보고서

## 단계 목적

`rhwp_image_data`가 rhwp v0.8.2의 owned `Vec<u8>`에서 해제될 임시 pointer를
반환하지 않도록 RustBridge를 수정한다. 성공 bytes를 caller-owned allocation으로
전환하고 invalid input, allocator pressure, 동시 allocation과 document handle
종료 경계를 Rust unit test로 고정한다.

Stage 2는 RustBridge source와 Rust test만 소유한다. Swift free caller,
generated header/XCFramework, artifact lock과 ownership 문서는 Stage 3에서
같은 regenerated artifact를 기준으로 갱신한다.

## 산출물

| 파일 | 변경 | 요약 |
|------|------|------|
| `RustBridge/src/lib.rs` | `+123 / -24` | `rhwp_image_data` owned pointer 전환, panic/null/empty 정규화, RAII test buffer와 3개 lifetime test 추가 |
| `mydocs/working/task_m020_447_stage2.md` | 신규 | Stage 2 구현·검증과 잔여 위험 기록 |
| `mydocs/orders/20260729.md` | 1행 갱신 | #447을 Stage 2 완료·Stage 3 승인 대기로 전환 |

### FFI 변경

기존 구현은 core가 반환한 local `Vec<u8>`의 `as_ptr()`를 반환하고 함수
종료 시 Vec를 drop했다. 새 구현은 다음 순서를 사용한다.

1. `out_len`이 null이면 즉시 null pointer를 반환한다.
2. non-null `out_len`은 함수 진입 시 0으로 초기화한다.
3. null handle과 `bin_data_id == 0`은 null/0으로 반환한다.
4. core lookup을 `catch_unwind(AssertUnwindSafe(...))` 안에서 실행한다.
5. non-empty `Vec<u8>`를 `Box<[u8]>`로 전환한다.
6. mutable pointer와 exact length를 얻은 뒤 box를 `forget`해 caller에게
   allocation ownership을 넘긴다.
7. empty/missing/panic은 null/0으로 정규화한다.

반환형은 `*const u8`에서 `*mut u8`로 바뀌었다. symbol 이름과 parameter
목록은 유지하며, mutable pointer는 기존 `rhwp_free_bytes`로 해제할 수 있음을
source type에 드러낸다.

### Test support

`TestBytes` RAII wrapper를 추가했다.

- `rhwp_image_data`에서 non-null/non-zero allocation을 받는다.
- `as_slice()`는 explicit free 전 범위에서만 raw bytes를 읽는다.
- `Drop`은 pointer와 exact length를 `rhwp_free_bytes`에 전달한다.

기존 `open_fixture()`는 그대로 KTX fixture를 열며, 공통
`open_fixture_at(relative_path:)`를 추가해 image lifetime fixture로
`samples/복학원서.hwp`를 사용한다.

### 신규 test

| Test | 검증 내용 |
|------|-----------|
| `image_data_owned_buffer_survives_allocator_pressure_and_handle_close` | id 1 expected bytes, 64개 유사 크기 allocation pressure 두 차례, handle close 뒤 pointer 유효성 |
| `repeated_image_data_allocations_are_independently_owned` | 같은 id의 두 allocation 동시 유지, 첫 allocation free 뒤 두 번째 bytes 보존 |
| `image_data_invalid_inputs_reset_output_length` | null handle, id 0, missing id, null out-length와 null/0 계약 |

기존 filename, external refs JSON, injection과 loaded-state test 4개도 같은 전체
suite에서 다시 통과했다.

## 본문 변경 정도 / 본문 무손실 여부

- 제품 source 변경은 `RustBridge/src/lib.rs` 한 파일로 제한했다.
- upstream `rhwp` source와 사용자 fork 변경은 건드리지 않았다.
- `RustBridge/Cargo.toml`, `Cargo.lock`, `rhwp-core.lock`의 tag, commit,
  feature와 artifact metadata는 변경하지 않았다.
- `rhwp-ffi-symbols.txt`, generated header/XCFramework와 Swift source는
  Stage 2에서 변경하지 않았다.
- 기존 4개 Rust test는 삭제·완화하지 않고 3개를 추가했다.
- KTX test helper의 의미는 유지하고 fixture path만 공통 helper로 분리했다.
- app, Preview, Thumbnail 실행·등록과 사용자 Applications 상태는 변경하지
  않았다.

## 검증 결과

구현계획서 Stage 2에 고정한 검증을 최종 source 상태에서 다시 실행했다.

| 검증 | 결과 | 핵심 출력 |
|------|------|-----------|
| `cargo fmt --check` | PASS | 출력 없음, exit 0 |
| `cargo check --locked` | PASS | `rhwp_mac_bridge` dev profile 완료 |
| `cargo test --locked` | PASS | 7 passed, 0 failed, 0 ignored |
| ownership/source marker | PASS | owned box, free ABI, fixture와 allocator-pressure test 위치 확인 |
| `git diff --check` | PASS | whitespace 오류 없음 |

최종 Rust test:

```text
running 7 tests
test tests::external_reference_lookup_reads_loaded_state ... ok
test tests::external_refs_json_has_owned_string_lifecycle ... ok
test tests::image_data_owned_buffer_survives_allocator_pressure_and_handle_close ... ok
test tests::image_data_invalid_inputs_reset_output_length ... ok
test tests::filename_context_validates_handle_and_utf8 ... ok
test tests::injection_validates_inputs_and_missing_reference ... ok
test tests::repeated_image_data_allocations_are_independently_owned ... ok

test result: ok. 7 passed; 0 failed; 0 ignored
```

첫 병렬 검증의 `cargo check`는 sandbox에서 Skia binary 다운로드 DNS가
차단돼 실패했다. 같은 source의 `cargo test`는 cached artifact로 7/7
통과했고, `cargo check --locked`를 네트워크 허용 환경에서 재실행해
`skia-bindings`, `rhwp v0.8.2`, `rhwp_mac_bridge` 전체 check가 통과했다.
이후 Stage 2 종료 검증에서 동일 `cargo check --locked`가 cache 상태에서도
다시 exit 0으로 완료됐다. 제품/source 실패로 판정하지 않는다.

## 잔여 위험

- checked-in generated header는 아직 `const uint8_t *rhwp_image_data`를
  나타내고, `Frameworks/Rhwp.xcframework`도 Stage 2 이전 archive다.
  Rust source와 generated artifact는 Stage 3 재생성 전까지 의도적으로
  비동기 상태다.
- Swift `RhwpDocument.imageData`와 `imageDataLength`는 아직 owned pointer를
  free하지 않는다. Stage 2 source로 XCFramework만 재생성해 기존 Swift와
  결합하면 leak이 발생하므로 Stage 3에서 원자적으로 갱신해야 한다.
- Rust unit test는 explicit free와 handle 독립성을 검증하지만 실제 Swift
  `Data` copy, ImageIO decode와 Finder extension process는 아직 검증하지
  않았다.
- `imageDataLength`가 전체 lazy bytes allocation을 요구하는 기존 비용은
  그대로다. 별도 length metadata ABI는 이번 단계에서 추가하지 않았다.
- `rhwp_free_bytes`에는 caller가 exact pointer와 length를 전달해야 한다.
  Stage 3 Swift wrapper와 generated header test가 이 계약을 고정해야 한다.

## 다음 단계 영향

Stage 3은 Rust source와 앱이 소비하는 artifact/caller를 다시 일치시킨다.

1. `RhwpDocument.imageData`와 `imageDataLength`에 성공 pointer
   `defer rhwp_free_bytes`를 추가한다.
2. `복학원서.hwp` 기반 Swift copy/length/repeated/deinit test를 기존
   `ExternalImageTests`에 추가한다.
3. RustBridge README와 project architecture의 borrowed pointer 설명을
   caller-owned/free 계약으로 바꾼다.
4. Rust static archive와 generated header/XCFramework를 재생성한다.
5. `rhwp-core.lock`의 artifact hash, size와 built_at을 새 source 기준으로
   갱신한다.
6. generated header의 mutable pointer, 15개 symbol 불변과
   ExternalImageTests 전체 통과를 확인한다.

Stage 3에서 core tag/commit/features, Cargo dependency, `project.yml` 또는
symbol 집합 변경이 필요하면 계획대로 중단하고 재승인을 요청한다.

## 승인 요청

Stage 2 RustBridge owned buffer 구현과 7/7 Rust test 결과를 승인하고,
구현계획서의 Stage 3 `Swift free 계약, 문서와 artifact 정합성`에 진입할지
승인 요청한다.

Stage 3 승인 전에는 Swift caller, ownership 문서, generated framework와
`rhwp-core.lock`을 변경하지 않는다.
