# Task M020 #408 Stage 1 보고서

## 단계 목적

Stage 1의 목적은 opaque C handle과 기존 공개 ABI를 유지하면서 `RhwpHandle` 내부 document 타입을 `DocumentCore`에서 pinned `rhwp v0.7.17`의 `HwpDocument`로 전환하고, 기존 page/render/image 호출이 계속 compile되는지 확인하는 것이다.

이 단계에서는 filename, external refs, bytes injection symbol을 아직 추가하지 않는다. 신규 ABI 구현은 Stage 2 범위로 유지한다.

## 산출물

| 파일 | 변경 요약 |
|------|-----------|
| `RustBridge/src/lib.rs` | `HwpDocument` import, `RhwpHandle.doc` 타입, `rhwp_open` 생성자를 전환했다. 기존 formatting drift도 rustfmt로 정규화했다. 현재 325줄이다. |
| `RustBridge/examples/svg_pdf_benchmark.rs` | crate 전체 formatter gate를 통과하기 위해 기존 formatting drift만 rustfmt로 정규화했다. 동작 변경은 없으며 현재 302줄이다. |
| `mydocs/working/task_m020_408_stage1.md` | Stage 1 변경, 검증, 잔여 위험과 Stage 2 handoff를 기록한다. |
| `mydocs/orders/20260710.md` | #408을 Stage 1 완료 및 Stage 2 승인 대기 상태로 갱신한다. |

## 구현 결과

### Handle 내부 타입 전환

Stage 1의 의미 변경은 다음 세 항목이다.

1. `use rhwp::DocumentCore`를 `use rhwp::wasm_api::HwpDocument`로 변경했다.
2. `RhwpHandle.doc`을 `DocumentCore`에서 `HwpDocument`로 변경했다.
3. `rhwp_open`에서 `DocumentCore::from_bytes(bytes)` 대신 `HwpDocument::from_bytes(bytes)`를 호출한다.

`RhwpHandle` 자체는 계속 opaque struct이며 `rhwp_open`/`rhwp_close` signature도 바뀌지 않는다. `HwpDocument`는 내부에 `DocumentCore`를 소유하고 `Deref<Target = DocumentCore>` 및 `DerefMut`를 제공하므로 다음 기존 호출은 코드 변경 없이 compile됐다.

- `page_count`
- `get_page_info_native`
- `render_page_svg_native`
- `build_page_render_tree`
- `get_page_overlay_images_native`
- `render_page_png_native_with_export_options`
- `get_bin_data`

### ABI 무변경 확인

Stage 1에서는 다음 파일을 변경하지 않았다.

- `rhwp-ffi-symbols.txt`
- `RustBridge/cbindgen.toml`
- `RustBridge/Cargo.toml`
- `RustBridge/Cargo.lock`
- `rhwp-core.lock`

따라서 기존 공개 symbol 집합, generated header 계약, pinned release tag `v0.7.17`, resolved commit `03351190ec35436e58cbfee0aa9278a8fdc04a59`, `native-skia` feature 기준은 그대로다.

### 수명과 mutation 계약

- `rhwp_open`은 입력 bytes를 `HwpDocument::from_bytes`로 파싱하고, 완성된 `HwpDocument`를 `Box<RhwpHandle>` 안에 소유한다.
- `Box`가 유지되는 동안 opaque handle 주소는 안정적이며 `rhwp_close`가 같은 box를 해제한다.
- `HwpDocument` 내부의 `DocumentCore`가 BinData를 계속 소유하므로 기존 `rhwp_image_data` pointer ownership은 바뀌지 않는다.
- Swift는 `rhwp_image_data` 반환 pointer를 즉시 `Data`로 복사한다. Stage 2에서 mutable setter/injection이 추가되면 mutable 호출 전후로 pointer를 보관하지 않는 제약을 ABI 문서에 명시해야 한다.

## 본문 변경 정도 / 본문 무손실 여부

- 제품 동작 의미 변경은 `RustBridge/src/lib.rs`의 document wrapper 전환 세 항목뿐이다.
- `RustBridge/src/lib.rs`의 나머지 diff와 `svg_pdf_benchmark.rs` 전체 diff는 `cargo fmt`가 적용한 줄바꿈·block formatting 정규화다.
- benchmark 계산, 파일 입출력, SVG/PDF 생성, summary 계산 로직은 바뀌지 않았다.
- 기존 C 함수 signature, status enum 값, page/render/image data 처리 본문은 무손실이다.
- Swift source, Quick Look/Thumbnail 제품 경로, generated framework는 변경하지 않았다.

## 검증 결과

### Rust formatting

```bash
cargo fmt --manifest-path RustBridge/Cargo.toml --check
```

결과: 최종 통과.

첫 실행에서는 이번 변경 전부터 남아 있던 `RustBridge/src/lib.rs`와 `RustBridge/examples/svg_pdf_benchmark.rs`의 formatting drift가 검출됐다. `cargo fmt`가 library target만 선택하는 옵션을 제공하지 않아 두 파일을 formatter로 정규화한 뒤 같은 명령을 다시 실행해 통과했다.

### Rust compile

```bash
cargo check --manifest-path RustBridge/Cargo.toml --locked
```

결과: 통과.

```text
Checking rhwp_mac_bridge v0.1.0 (.../RustBridge)
Finished `dev` profile [unoptimized + debuginfo]
```

첫 sandbox 실행은 `skia-bindings v0.99.0` binary cache를 내려받는 과정에서 DNS가 제한되어 실패했다. 네트워크 권한이 있는 동일 명령으로 Skia binary cache를 준비한 뒤 성공했고, 이후 cached 재검증도 통과했다. 이는 source compatibility 실패가 아니다.

### Rust test profile

```bash
cargo test --manifest-path RustBridge/Cargo.toml --locked
```

결과: 통과.

```text
running 0 tests
test result: ok. 0 passed; 0 failed; 0 ignored
```

현재 RustBridge에는 unit test가 없으므로 이 결과는 test profile compile/link gate다. Stage 2에서 external ABI invalid-input/JSON lifecycle unit test를 추가한다.

### 변경 및 계약 점검

```bash
git diff --check -- RustBridge/src/lib.rs RustBridge/examples/svg_pdf_benchmark.rs \
  mydocs/working/task_m020_408_stage1.md mydocs/orders/20260710.md
rg -n "HwpDocument|RhwpHandle|rhwp_open|page_count|get_page_info_native|build_page_render_tree|get_bin_data" \
  RustBridge/src/lib.rs mydocs/working/task_m020_408_stage1.md
```

결과: 통과. `HwpDocument` 전환과 기존 호출 경로가 source/report에 존재하고 whitespace 오류가 없음을 확인했다.

추가 확인:

- `git diff -- rhwp-ffi-symbols.txt RustBridge/Cargo.toml RustBridge/Cargo.lock RustBridge/cbindgen.toml rhwp-core.lock`은 빈 결과다.
- 변경 파일은 Stage 1 source/formatter 두 파일과 보고서/오늘할일뿐이다.
- generated framework와 Xcode project는 변경하지 않았다.

## 잔여 위험

- Stage 1은 compile/test profile까지 확인했으며 generated `Rhwp.xcframework`를 재생성하지 않았다. staticlib/header 갱신은 신규 symbol이 추가되는 Stage 3에서 수행한다.
- 현재 RustBridge unit test가 없어 기존 page/render/image ABI의 runtime 호출은 Stage 4 render smoke에서 확인해야 한다.
- `HwpDocument`가 `DerefMut`를 제공하므로 Stage 2 mutation은 compile 가능하지만, injection 이후 page tree cache와 document-owned image pointer 수명은 별도 테스트와 문서화가 필요하다.
- exact external image fixture가 없어 성공 injection의 `loaded: false -> true` end-to-end 검증은 Stage 2에서 fixture 존재 여부를 다시 확인하고, 없으면 #412에 남긴다.
- formatter 정규화가 포함되어 Stage 1 diff가 의미 변경 세 줄보다 크다. 보고서에서 semantic diff와 formatting-only diff를 분리했고 동작 변경이 없는지 검토했다.

## 다음 단계 영향

Stage 2는 전환된 `HwpDocument`에 다음 additive ABI를 구현한다.

- `RhwpExternalImageStatus`
- `rhwp_set_file_name_utf8`
- `rhwp_external_image_refs_json`
- `rhwp_inject_external_image_by_key`

Stage 2에서는 `serde_json::Value`로 refs JSON의 `key`와 `loaded`만 preflight하고 신규 dependency를 추가하지 않는다. pinned public API에 전체 image state 조회가 없으므로 `rhwp_image_state_json`은 구현하지 않는다.

## 승인 요청

Stage 1 `HwpDocument handle 전환과 기존 ABI 호환성 확인`은 완료됐다. Stage 2 `External image context C ABI와 Rust 검증 구현`으로 진행하려면 작업지시자 승인이 필요하다.
