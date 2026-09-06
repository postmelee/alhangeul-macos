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

현재 `rhwp-core.lock`과 `RustBridge/Cargo.toml`은 release tag `v0.8.6`, resolved commit `f1f9c6ae58344ee9368996d3543f76b9345cf227`, feature `native-skia`를 기준으로 한다. Stable 기준은 release tag와 resolved commit을 함께 고정하며 branch/floating ref는 사용하지 않는다.

채널별 dependency 기준, lock 필드, compatibility gate 상세는 [`core_release_compatibility.md`](../mydocs/tech/core_release_compatibility.md)를 참조한다.

## 기본 명령

```bash
./scripts/build-rust-macos.sh                   # build-only
./scripts/build-rust-macos.sh --verify-portable # 일반 source/header/FFI 검증
./scripts/build-rust-macos.sh --verify-strict   # 기준 환경 staticlib byte까지 비교
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

## 문서 보호 상태 ABI

`rhwp_document_protection`은 caller-owned 문서 bytes를 호출 동안만 빌려 public parser 결과를 다음 status로 축약한다. 암호 문자열, parser 오류 문자열과 문서 handle은 반환하지 않는다.

| status | 의미 |
|--------|------|
| `RHWP_DOCUMENT_PROTECTION_PLAIN` | 암호 없이 parse 가능한 문서 |
| `RHWP_DOCUMENT_PROTECTION_PASSWORD_PROTECTED` | `ParseError::EncryptedDocument`로 확인된 암호 문서 |
| `RHWP_DOCUMENT_PROTECTION_UNSUPPORTED` | typed format 감지로 확인된 미지원 DRM/보호 컨테이너 |
| `RHWP_DOCUMENT_PROTECTION_INVALID_OR_UNKNOWN` | null/empty, 손상, parse 실패, panic 또는 알 수 없는 상태 |

알 수 없는 status와 판정 실패는 Swift에서 `invalidOrUnknown`으로 fail-closed 처리한다. 이 probe는 문서를 복호화하지 않으며 기존 `rhwp_open`의 parse 실패 계약을 변경하지 않는다.

pinned public API에는 embedded/external/missing/injected 전체 image 상태를 반환하는 함수가 없어 `rhwp_image_state_json`은 제공하지 않는다. External 상태는 refs JSON의 `loaded`로 전달하고 renderer missing/decode diagnostic은 downstream renderer 이슈에서 별도로 다룬다.

## Spotlight UTF-8 본문 ABI

`rhwp_extract_text_utf8(data, len, out_data, out_len)`은 문서 handle 없이 평문 HWP3/HWP5/HWPX를 파싱하고 검색용 본문을 반환한다. `RhwpTextStatus`는 완전/빈/부분 추출과 입력·보호·형식·파싱·panic 실패를 구분한다. `RHWP_TEXT_MAX_INPUT_BYTES`는 32 MiB다. 파싱 후 1 MiB UTF-8, 200,000 방문 단위, 깊이 64 한도를 적용한다.

반환 bytes는 NUL 종단이 아니다. 호출자가 `out_len`만큼 복사한 뒤 `rhwp_free_bytes(out_data, out_len)`로 한 번 해제한다. 유효한 output slot은 시작 시 NULL/0으로 초기화된다. 입력은 호출 중 읽기 가능해야 하며 output slots는 서로 겹치지 않는 정렬된 writable 영역이어야 한다. 파일·외부 자원·비밀번호 저장소·레이아웃을 사용하지 않는다. HWP5는 256-byte 보호 헤더만 먼저 검사한 후 본문을 한 번 파싱한다.

[검색 본문 계약](../mydocs/tech/spotlight_text_extraction_contract.md)에 포함/제외, Unicode·delimiter, 상태 번호와 자원 한계가 있다. 이 API는 parser 전체 CPU/RSS/abort를 제한하는 격리 장치가 아니다.

```sh
MACOSX_DEPLOYMENT_TARGET=12.0 cargo test --manifest-path RustBridge/Cargo.toml --locked --offline --release --target aarch64-apple-darwin
```

## 경계 규칙

- core API 변경은 먼저 `edwardkim/rhwp` 저장소에 반영한다.
- 앱 저장소 안에서 core source를 직접 수정하지 않는다.
- `rhwp_*` ABI 변경 시 `rhwp-ffi-symbols.txt`, generated header, Swift bridge 호출부, `rhwp-core.lock` 정합성을 함께 확인한다.
- `rhwp_document_protection` 입력 bytes는 caller-owned이며 호출 동안 유효해야 한다. null pointer와 0 length는 `INVALID_OR_UNKNOWN`으로 처리한다.
- Rust가 Swift에 넘긴 문자열과 byte buffer는 지정된 free 함수로 해제해야 한다.
- external resource 권한·탐색·bytes read는 Swift/macOS shell이 소유하며 RustBridge가 filesystem을 직접 탐색하지 않는다.

관련 상세 문서:

- `mydocs/tech/project_architecture.md`
- `mydocs/manual/core_dependency_operation_guide.md`
- `mydocs/manual/build_run_guide.md`
