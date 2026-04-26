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

현재 v0.1.0 목표는 Demo/Preview release다.

| 채널 | dependency 기준 | lock 기준 |
|------|------|------|
| Demo/Preview | `git` + `rev` | `rhwp_ref_kind = "commit"`, resolved commit, artifact hash/size |
| Stable | `git` + `tag` | `rhwp_ref_kind = "release-tag"`, release tag, resolved commit, artifact hash/size |

Demo/Preview는 필요한 bridge API가 포함된 commit을 고정할 때만 사용한다. Stable은 release tag가 같은 API를 포함할 때 별도 승격한다. branch/floating ref는 배포 기준으로 사용하지 않는다.

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

## 경계 규칙

- core API 변경은 먼저 `edwardkim/rhwp` 저장소에 반영한다.
- 앱 저장소 안에서 core source를 직접 수정하지 않는다.
- `rhwp_*` ABI 변경 시 `rhwp-ffi-symbols.txt`, generated header, Swift bridge 호출부, `rhwp-core.lock` 정합성을 함께 확인한다.
- Rust가 Swift에 넘긴 문자열과 byte buffer는 지정된 free 함수로 해제해야 한다.

관련 상세 문서:

- `mydocs/tech/project_architecture.md`
- `mydocs/manual/core_submodule_operation_guide.md`
- `mydocs/manual/build_run_guide.md`
