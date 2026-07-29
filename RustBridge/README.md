# RustBridge

`RustBridge/`는 `edwardkim/rhwp` Rust core를 macOS Swift target에서 사용할 수 있도록 C ABI로 노출하는 이 저장소 소유 crate다. Swift 코드는 Rust core를 직접 호출하지 않고 generated `Rhwp.xcframework`의 `Rhwp` C module을 import한다.

## 주요 파일

| 파일 | 역할 |
|------|------|
| `Cargo.toml` | `edwardkim/rhwp` git dependency 선언 |
| `Cargo.lock` | Cargo가 해석한 실제 resolved commit 고정 |
| `src/lib.rs` | Swift가 호출하는 `rhwp_*` FFI entrypoint |
| `cbindgen.toml` | generated C header 설정 |

## 생성 산출물

`RustBridge/`와 build script가 원본이고, 다음 파일은 생성 산출물이다.

- `Frameworks/Rhwp.xcframework`
- `Frameworks/generated_rhwp.h`
- `Frameworks/module.modulemap`
- `Frameworks/universal/librhwp.a`

생성 산출물의 hash/size와 core provenance는 저장소 루트의 `rhwp-core.lock`에 기록한다.

## Core dependency 기준

현재 `rhwp-core.lock`과 `RustBridge/Cargo.toml`은 release tag `v0.8.2`, resolved commit `9b16aa9e23f476e2b335d7c029fc9f24a199d63c`, feature `native-skia`를 기준으로 한다. Stable 기준은 release tag와 resolved commit을 함께 고정하며 branch/floating ref는 사용하지 않는다.

채널별 dependency 기준, lock 필드, compatibility gate 상세는 [`core_release_compatibility.md`](../mydocs/tech/core_release_compatibility.md)를 참조한다.

## 기본 명령

```bash
./scripts/build-rust-macos.sh
./scripts/build-rust-macos.sh --verify-lock
./scripts/build-rust-macos.sh --update-lock
```

core 기준을 바꿀 때는 저장소 루트에서 다음 스크립트를 사용한다.

```bash
./scripts/update-rhwp-core.sh --channel demo --rev <commit-sha>
./scripts/update-rhwp-core.sh --channel stable --tag <release-tag>
```

## External image context ABI

RustBridge는 external image 파일을 직접 찾거나 읽지 않는다. Swift/macOS shell이 source URL 권한, basename-only resolver, size 제한과 bytes read를 소유하고, 허용된 context와 bytes만 다음 ABI로 전달한다.

| ABI | 역할 |
|-----|------|
| `rhwp_set_file_name_utf8` | UTF-8 filename context를 document에 설정한다. |
| `rhwp_external_image_refs_json` | `key`, `binDataId`, `originalPath`, `basename`, `extension`, `loaded`를 포함한 upstream JSON 배열을 반환한다. |
| `rhwp_inject_external_image_by_key` | refs JSON의 key로 caller가 읽은 image bytes를 document에 주입한다. |

세터와 injection은 `RhwpExternalImageStatus`를 반환한다. status는 성공, invalid handle/input/UTF-8, reference 미존재, 이미 loaded, 일반 failure를 구분한다.

메모리와 수명 규칙:

- filename, key, data, display path 입력 pointer는 caller-owned이며 호출 동안만 빌려 쓴다.
- `rhwp_external_image_refs_json` 반환 문자열은 Rust-owned이며 `rhwp_free_string`으로 해제한다.
- injection에 성공하면 upstream document가 image bytes를 복사해 소유한다.
- `rhwp_image_data`가 반환한 non-null pointer는 caller-owned Rust allocation이다. caller는 bytes를 복사한 뒤 반환받은 동일 pointer와 length를 `rhwp_free_bytes`에 정확히 한 번 전달한다.
- `rhwp_image_data` allocation은 document handle과 독립이며 `rhwp_free_bytes` 호출 전까지 유효하다. free 뒤 pointer를 보관하거나 다시 해제하지 않는다.
- `originalPath`와 `display_path`는 bridge가 filesystem 접근 경로로 해석하지 않는다.

pinned public API에는 embedded/external/missing/injected 전체 image 상태를 반환하는 함수가 없어 `rhwp_image_state_json`은 제공하지 않는다. External 상태는 refs JSON의 `loaded`로 전달하고 renderer missing/decode diagnostic은 downstream renderer 이슈에서 별도로 다룬다.

## 경계 규칙

- core API 변경은 먼저 `edwardkim/rhwp` 저장소에 반영한다.
- 앱 저장소 안에서 core source를 직접 수정하지 않는다.
- `rhwp_*` ABI 변경 시 `rhwp-ffi-symbols.txt`, generated header, Swift bridge 호출부, `rhwp-core.lock` 정합성을 함께 확인한다.
- Rust가 Swift에 넘긴 문자열과 byte buffer는 지정된 free 함수로 해제해야 한다.
- external resource 권한·탐색·bytes read는 Swift/macOS shell이 소유하며 RustBridge가 filesystem을 직접 탐색하지 않는다.

관련 상세 문서:

- `mydocs/tech/project_architecture.md`
- `mydocs/manual/core_dependency_operation_guide.md`
- `mydocs/manual/build_run_guide.md`
