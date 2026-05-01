# Task #104 Stage 2 완료 보고서 - rhwp v0.7.9 stable tag dependency 전환

## 목적

`RustBridge`의 `edwardkim/rhwp` dependency와 앱 저장소의 core provenance skeleton을 `v0.7.9` Stable release tag 기준으로 갱신한다.

## 변경 파일

- `RustBridge/Cargo.toml`
- `RustBridge/Cargo.lock`
- `rhwp-core.lock`

## 변경 내용

### 1. Cargo dependency 전환

`RustBridge/Cargo.toml`의 `rhwp` dependency를 다음과 같이 갱신했다.

```toml
rhwp = { git = "https://github.com/edwardkim/rhwp.git", tag = "v0.7.9" }
```

`RustBridge/Cargo.lock`의 `rhwp` package도 `v0.7.9`와 resolved commit을 가리킨다.

```text
name = "rhwp"
version = "0.7.9"
source = "git+https://github.com/edwardkim/rhwp.git?tag=v0.7.9#0fb3e6758b8ad11d2f3c3849c83b914684e83863"
```

### 2. `rhwp-core.lock` provenance skeleton 갱신

`rhwp-core.lock`의 core 기준을 `v0.7.9` Stable release tag로 갱신했다.

```text
rhwp_ref_kind = "release-tag"
rhwp_release_tag = "v0.7.9"
rhwp_commit = "0fb3e6758b8ad11d2f3c3849c83b914684e83863"
```

Stage 2는 artifact 재생성 전 단계이므로 다음 필드는 의도적으로 비어 있다.

```text
built_at = ""
Frameworks/universal/librhwp.a sha256 = "", size = 0
Frameworks/generated_rhwp.h sha256 = "", size = 0
```

이 값은 Stage 3에서 `./scripts/build-rust-macos.sh --update-lock` 실행 후 실제 산출물 기준으로 채운다.

## 실행 결과

최초 sandbox 실행은 GitHub host resolution 실패로 중단됐다.

```text
fatal: unable to access 'https://github.com/edwardkim/rhwp.git/': Could not resolve host: github.com
ERROR: release lookup failure: could not fetch release tag v0.7.9
```

동일 명령을 네트워크 권한으로 재실행해 성공했다.

```text
Checked rhwp core target:
  channel: stable
  tag:     v0.7.9
  commit:  0fb3e6758b8ad11d2f3c3849c83b914684e83863
Updated: /Users/melee/Documents/projects/rhwp-mac/RustBridge/Cargo.toml
Updated: /Users/melee/Documents/projects/rhwp-mac/RustBridge/Cargo.lock
Updated: /Users/melee/Documents/projects/rhwp-mac/rhwp-core.lock
```

## 검증

실행한 명령:

```bash
./scripts/update-rhwp-core.sh --channel stable --tag v0.7.9
rg -n "v0\\.7\\.9|0fb3e6758b8ad11d2f3c3849c83b914684e83863|rhwp_ref_kind|rhwp_release_tag|rhwp_commit|demo-commit-pin|built_at|sha256|size" \
  RustBridge/Cargo.toml RustBridge/Cargo.lock rhwp-core.lock
git diff -- RustBridge/Cargo.toml RustBridge/Cargo.lock rhwp-core.lock
git diff --check -- RustBridge/Cargo.toml RustBridge/Cargo.lock rhwp-core.lock
git status --short
```

검증 결과:

- `RustBridge/Cargo.toml`은 `tag = "v0.7.9"`를 사용한다.
- `RustBridge/Cargo.lock`은 `tag=v0.7.9#0fb3e6758b8ad11d2f3c3849c83b914684e83863`를 기록한다.
- `rhwp-core.lock`은 `rhwp_ref_kind = "release-tag"`, `rhwp_release_tag = "v0.7.9"`, `rhwp_commit = "0fb3e6758b8ad11d2f3c3849c83b914684e83863"`를 기록한다.
- `demo-commit-pin` 상태값은 남지 않았다.
- `git diff --check`는 통과했다.

## 다음 단계

Stage 3에서는 Rust bridge 산출물을 재생성하고, `rhwp-core.lock`의 `built_at`, artifact `sha256`, `size`를 실제 산출물 기준으로 갱신한 뒤 `--verify-lock`으로 검증한다.
