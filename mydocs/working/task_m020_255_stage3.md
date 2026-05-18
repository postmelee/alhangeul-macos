# Task M020 #255 Stage 3 보고서

## 단계 목적

Stage 3의 목적은 Stage 2에서 추가한 RustBridge Skia PNG ABI를 generated header, symbol lock, universal staticlib, `Rhwp.xcframework`, `rhwp-core.lock` provenance gate에 반영하는 것이다.

이 단계에서는 Swift wrapper나 Quick Look/Thumbnail 적용을 하지 않는다. generated `Frameworks/` 산출물은 로컬에 생성되지만 `.gitignore` 대상이므로 PR에는 source lock, symbol lock, build script 변경만 올라간다.

## 산출물

| 파일 | 요약 |
|---|---|
| `rhwp-ffi-symbols.txt` | `rhwp_render_page_png` symbol 추가. |
| `scripts/build-rust-macos.sh` | `rhwp_enabled_features` lock 기록과 verify 비교 추가. |
| `rhwp-core.lock` | `rhwp_enabled_features = "native-skia"`와 새 artifact hash/size 기록. |
| `Frameworks/generated_rhwp.h` | 로컬 생성 산출물. `RhwpRenderStatus`와 `rhwp_render_page_png` 포함. |
| `Frameworks/modulemap/rhwp.h` | 로컬 생성 산출물. generated header 복사본. |
| `Frameworks/generated_rhwp_symbols.txt` | 로컬 생성 산출물. `rhwp_render_page_png` 포함. |
| `Frameworks/universal/librhwp.a` | 로컬 생성 산출물. universal static archive. |
| `Frameworks/Rhwp.xcframework` | 로컬 생성 산출물. Swift import용 C module 포함. |
| `mydocs/working/task_m020_255_stage3.md` | Stage 3 구현/검증 보고서. |
| `mydocs/orders/20260518.md` | #255 상태를 Stage 3 완료 및 Stage 4 승인 대기로 갱신. |

## 변경 내용

`rhwp-ffi-symbols.txt`에 새 ABI symbol을 추가했다.

```text
rhwp_render_page_png
```

`scripts/build-rust-macos.sh`에는 다음 feature provenance gate를 추가했다.

- `Cargo.toml`의 `rhwp` dependency line에서 `features = [...]` 값을 읽는 `cargo_toml_rhwp_enabled_features` 추가
- 현재 enabled feature를 반환하는 `current_rhwp_enabled_features` 추가
- `write_lock_file`에서 `rhwp_enabled_features = "native-skia"` 기록
- `verify_lock_file`에서 lock의 `rhwp_enabled_features`와 `Cargo.toml`의 실제 feature 값을 비교

`rhwp-core.lock`은 source provenance는 유지하고 artifact metadata만 갱신했다.

| 항목 | 이전 | 이후 |
|---|---:|---:|
| `rhwp_commit` | `a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae` | 동일 |
| `rhwp_enabled_features` | 없음 | `native-skia` |
| `Frameworks/universal/librhwp.a` size | 108,417,040 bytes | 190,409,968 bytes |
| `Frameworks/generated_rhwp.h` size | 1,349 bytes | 1,978 bytes |

staticlib 크기는 81,992,928 bytes 증가했다. `du -sh` 기준 universal staticlib와 xcframework는 모두 `182M`로 확인됐다.

## generated header 확인

`Frameworks/generated_rhwp.h`와 `Frameworks/modulemap/rhwp.h`에는 다음 C surface가 생성됐다.

```c
typedef enum RhwpRenderStatus {
  RHWP_RENDER_OK = 0,
  RHWP_RENDER_INVALID_HANDLE = 1,
  RHWP_RENDER_INVALID_OUTPUT = 2,
  RHWP_RENDER_INVALID_PAGE_INDEX = 3,
  RHWP_RENDER_INVALID_OPTIONS = 4,
  RHWP_RENDER_FAILURE = 5,
} RhwpRenderStatus;

enum RhwpRenderStatus rhwp_render_page_png(const struct RhwpHandle *handle,
                                           uint32_t page,
                                           double scale,
                                           uint32_t max_dimension,
                                           uint8_t **out_data,
                                           uintptr_t *out_len);
```

생성 산출물은 `.gitignore`의 `/Frameworks/` 규칙에 의해 추적되지 않는다. 저장소에는 `rhwp-core.lock`의 hash/size와 `rhwp-ffi-symbols.txt`를 통해 artifact 정합성을 검증하는 형태를 유지한다.

## 본문 변경 정도 / 본문 무손실 여부

- RustBridge source는 Stage 3에서 추가 변경하지 않았다.
- `scripts/build-rust-macos.sh`는 lock write/verify path에 additive feature check만 추가했다.
- 기존 lock source provenance 필드(`rhwp_repo`, `rhwp_ref_kind`, `rhwp_release_tag`, `rhwp_commit`)는 유지했다.
- 기존 symbol lock에서 삭제한 symbol은 없다.

## 검증 결과

```bash
./scripts/build-rust-macos.sh --update-lock
```

결과: 통과. 최초 sandbox 실행은 `skia-bindings`가 GitHub binary/source를 다운로드하려다 DNS 제한으로 실패했다. 같은 명령을 네트워크 권한으로 재실행했고 성공했다.

```text
FFI symbols:
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
Done: /Users/melee/Documents/projects/rhwp-mac/Frameworks/Rhwp.xcframework
182M    /Users/melee/Documents/projects/rhwp-mac/Frameworks/universal/librhwp.a
182M    /Users/melee/Documents/projects/rhwp-mac/Frameworks/Rhwp.xcframework
Updated: /Users/melee/Documents/projects/rhwp-mac/rhwp-core.lock
```

```bash
./scripts/build-rust-macos.sh --verify-lock
```

결과: 통과. `xcodebuild -create-xcframework` 과정에서 CoreSimulator 관련 warning이 출력됐지만 xcframework 생성과 lock verification은 성공했다.

```text
Verified: /Users/melee/Documents/projects/rhwp-mac/rhwp-core.lock
```

```bash
rg -n "RhwpRenderStatus|rhwp_render_page_png|RHWP_RENDER_OK" \
  Frameworks/generated_rhwp.h Frameworks/modulemap/rhwp.h rhwp-ffi-symbols.txt Frameworks/generated_rhwp_symbols.txt
```

결과: 통과. generated header/modulemap/symbol file 모두 새 enum/function을 포함한다.

```bash
rg -n "rhwp_enabled_features|native-skia" rhwp-core.lock RustBridge/Cargo.toml scripts/build-rust-macos.sh
```

결과: 통과. lock, Cargo dependency, build script verify path 모두 feature provenance를 포함한다.

```bash
du -sh Frameworks/universal/librhwp.a Frameworks/Rhwp.xcframework
```

결과:

```text
182M    Frameworks/universal/librhwp.a
182M    Frameworks/Rhwp.xcframework
```

```bash
git diff --check -- rhwp-core.lock rhwp-ffi-symbols.txt Frameworks/generated_rhwp.h Frameworks/generated_rhwp_symbols.txt Frameworks/modulemap/rhwp.h scripts/build-rust-macos.sh
git diff --check
bash -n scripts/build-rust-macos.sh
```

결과: 모두 통과.

## 잔여 위험

- `native-skia` 도입으로 universal staticlib가 약 108 MB에서 190 MB로 증가했다. #259 readiness gate에서 release package size와 load time 영향 확인이 필요하다.
- `skia-bindings`는 최초 release build에서 GitHub binary cache 또는 source download가 필요하다. CI/release 환경의 네트워크 허용과 cache 전략을 #259에서 확인해야 한다.
- generated header와 xcframework는 로컬 산출물이라 새 worktree에서는 `./scripts/build-rust-macos.sh --verify-lock` 또는 `--update-lock`을 실행해야 실제 파일이 생긴다.
- feature parser는 현재 `RustBridge/Cargo.toml`의 single-line `rhwp = { ... features = [...] }` 형식을 기준으로 한다. dependency 선언을 multi-line table로 바꾸는 작업은 script parser 보강을 동반해야 한다.

## 다음 단계 영향

Stage 4에서는 ABI smoke와 실패 경로를 확인한다.

- `nm -gU Frameworks/universal/librhwp.a`로 새 symbol이 universal staticlib에 존재하는지 확인한다.
- 가능하면 작은 Rust/C smoke로 `rhwp_open -> rhwp_render_page_png -> rhwp_free_bytes -> rhwp_close` 정상 경로를 확인한다.
- null handle, invalid page index, invalid options failure status를 확인한다.
- Swift wrapper 없이도 #256이 받을 ABI handoff 제약을 정리한다.

## 승인 요청

Stage 3은 generated artifact와 provenance gate 갱신으로 마무리한다. Stage 4 `ABI smoke와 실패 경로 검증`으로 진행하려면 작업지시자 승인이 필요하다.
