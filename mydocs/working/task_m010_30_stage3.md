# Task #30 Stage 3 완료 보고서

## 단계 목적

`RustBridge`를 `edwardkim/rhwp` Demo/Preview commit-pinned git dependency로 전환하고, `.gitmodules`와 `Vendor/rhwp` gitlink를 제거한다.

## 산출물

- `RustBridge/Cargo.toml`
  - `rhwp = { path = "../Vendor/rhwp" }`를 git `rev` dependency로 전환
- `RustBridge/Cargo.lock`
  - `rhwp` package source를 `git+https://github.com/edwardkim/rhwp.git?rev=...#1e9d78a...`로 기록
- `rhwp-core.lock`
  - `rhwp_ref_kind = "commit"`
  - `rhwp_release_transition_status = "demo-commit-pin"`
  - latest checked release `v0.7.3`과 resolved commit 유지
  - artifact hash/size는 Stage 4에서 `--update-lock`로 다시 기록할 skeleton 상태
- `.gitmodules`
  - 삭제
- `Vendor/rhwp`
  - gitlink와 로컬 submodule worktree 제거
- `scripts/update-rhwp-core.sh`
  - Stage 3 실사용 중 발견한 `cargo update -p rhwp` 실패를 `cargo generate-lockfile` 방식으로 보정
- `mydocs/orders/20260426.md`
  - #30 비고를 Stage 4 승인 대기 상태로 갱신
- `mydocs/working/task_m010_30_stage3.md`
  - Stage 3 완료 보고서

## 본문 변경 정도 / 본문 무손실 여부

이번 단계는 실제 dependency source 전환 단계다. Rust FFI source code, Swift source code, render tree model, FFI symbol 목록은 변경하지 않았다.

`Cargo.lock`은 처음 `cargo generate-lockfile` 실행 시 `libc`, `zip` patch version 갱신이 함께 발생했지만, 이번 단계 범위가 아니므로 해당 registry dependency churn은 되돌렸다. 최종 `Cargo.lock` diff는 `rhwp` package source line 추가만 남겼다.

`rhwp-core.lock`은 Stage 4에서 artifact hash/size를 다시 채우기 전 skeleton 상태다. 따라서 Stage 3 완료 시점의 lock은 commit provenance를 가리키지만 artifact metadata는 아직 최종 상태가 아니다.

## 구현 요약

Demo/Preview dependency:

```toml
rhwp = { git = "https://github.com/edwardkim/rhwp.git", rev = "1e9d78a1d40c71779d81c6ec6870cd301d912626" }
```

Cargo.lock resolved source:

```text
source = "git+https://github.com/edwardkim/rhwp.git?rev=1e9d78a1d40c71779d81c6ec6870cd301d912626#1e9d78a1d40c71779d81c6ec6870cd301d912626"
```

Submodule 제거:

- `.gitmodules` 삭제
- `Vendor/rhwp` gitlink 삭제
- `git submodule status` 출력 없음

## 검증 결과

Cargo metadata:

```text
$ cargo metadata --manifest-path RustBridge/Cargo.toml --locked --format-version 1 >/tmp/rhwp-mac-cargo-metadata.json
결과: 통과
```

첫 실행은 sandbox DNS 제한으로 실패했다.

```text
error: failed to download from `https://static.crates.io/crates/zip/8.6.0/download`
Caused by:
  [6] Couldn't resolve host name (Could not resolve host: static.crates.io)
```

네트워크 권한으로 재실행해 통과했다. 이후 registry dependency churn을 되돌린 뒤 다시 실행했고, 추가 다운로드 없이 통과했다.

Cargo.lock source 확인:

```text
$ rg -n "name = \"rhwp\"|source = \"git\\+https://github.com/edwardkim/rhwp.git\" RustBridge/Cargo.lock
552:name = "rhwp"
554:source = "git+https://github.com/edwardkim/rhwp.git?rev=1e9d78a1d40c71779d81c6ec6870cd301d912626#1e9d78a1d40c71779d81c6ec6870cd301d912626"
```

`rhwp-core.lock` 확인:

```text
$ rg -n "rhwp_ref_kind|rhwp_commit|rhwp_release_transition_status|rhwp_latest_checked_release" rhwp-core.lock
3:rhwp_ref_kind = "commit"
4:rhwp_commit = "1e9d78a1d40c71779d81c6ec6870cd301d912626"
5:rhwp_release_transition_status = "demo-commit-pin"
6:rhwp_latest_checked_release_tag = "v0.7.3"
7:rhwp_latest_checked_release_commit = "c2e8a3461de800a02f76127ff4797bade1d4e532"
```

submodule 제거 확인:

```text
$ git ls-files -s Vendor/rhwp .gitmodules
결과: 출력 없음

$ git submodule status
결과: 출력 없음
```

script 문법과 shellcheck:

```text
$ bash -n scripts/update-rhwp-core.sh
결과: 통과

$ shellcheck scripts/update-rhwp-core.sh
결과: 통과
```

diff check:

```text
$ git diff --check
결과: 통과
```

## 잔여 위험

- `rhwp-core.lock` artifact hash/size는 Stage 4에서 갱신해야 한다. 현재 skeleton 상태에서 `--verify-lock`은 최종 검증 기준으로 사용할 수 없다.
- `scripts/build-rust-macos.sh`의 git dependency mode는 Stage 4에서 실제 full build와 `--update-lock`/`--verify-lock`로 다시 검증해야 한다.
- `.git/modules/Vendor/rhwp` 같은 Git 내부 submodule metadata는 로컬 부산물로 남아 있을 수 있다. git index와 working tree 기준에서는 submodule이 제거되었고, fresh checkout에는 포함되지 않는다.
- README와 매뉴얼에는 아직 submodule 기준 설명이 남아 있다. 이는 Stage 5 문서 보정 범위다.

## 다음 단계 영향

Stage 4에서는 `./scripts/build-rust-macos.sh --update-lock`로 git dependency 기준 artifact를 재생성하고 `rhwp-core.lock`의 `built_at`, static library/header hash, size를 채운다.

그 뒤 `./scripts/build-rust-macos.sh --verify-lock`, FFI symbol diff, generated header field 확인으로 build script의 git dependency mode를 검증해야 한다.

## 승인 요청

Stage 3 `RustBridge git-rev dependency 전환과 Vendor/rhwp 제거`를 완료했다. 이 보고서 기준으로 Stage 4 `build script, artifact lock, FFI symbol 검증 보강`을 진행할지 승인 요청한다.
