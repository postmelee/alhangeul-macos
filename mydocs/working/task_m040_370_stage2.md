# Task M040 #370 Stage 2 완료보고서

## 단계 목적

RustBridge staticlib build가 downstream `RustBridge/Cargo.lock`을 실제 build gate로 사용하도록 `scripts/build-rust-macos.sh`의 cargo build 명령에 `--locked`를 적용했다. 기존 `rhwp-core.lock` source provenance, generated header, FFI symbol 검증 흐름은 유지했다.

## 산출물

| 파일 | 변경 | 요약 |
|------|------|------|
| `scripts/build-rust-macos.sh` | 수정 | arm64/x86_64 Rust staticlib build에 `--locked` 추가 |
| `mydocs/working/task_m040_370_stage2.md` | 신규 | Stage 2 변경과 검증 결과 기록 |
| `mydocs/orders/20260624.md` | 수정 | #370 비고를 Stage 2 완료보고서 승인 대기로 갱신 |

## 변경 내용

`scripts/build-rust-macos.sh`의 두 target build 명령을 다음 형태로 바꾸었다.

```text
cargo build --release --locked --manifest-path "$BRIDGE_ROOT/Cargo.toml" --target aarch64-apple-darwin
cargo build --release --locked --manifest-path "$BRIDGE_ROOT/Cargo.toml" --target x86_64-apple-darwin
```

이 변경은 dependency graph를 갱신하지 않는다. `Cargo.toml`과 `RustBridge/Cargo.lock`이 drift된 상태면 build가 실패하도록 하는 검증 강화다.

## 본문 변경 정도 / 본문 무손실 여부

`scripts/build-rust-macos.sh`의 cargo build 호출 두 줄에 `--locked` 옵션만 추가했다. lock 파싱, `rhwp-core.lock` 검증, artifact metadata 검증, FFI symbol diff, xcframework 생성 흐름은 변경하지 않았다.

## 검증 결과

```text
$ bash -n scripts/build-rust-macos.sh
통과
```

```text
$ git diff --check
통과
```

```text
$ rg -n "cargo build --release --locked" scripts/build-rust-macos.sh
623:cargo build --release --locked --manifest-path "$BRIDGE_ROOT/Cargo.toml" --target aarch64-apple-darwin
624:cargo build --release --locked --manifest-path "$BRIDGE_ROOT/Cargo.toml" --target x86_64-apple-darwin
```

```text
$ scripts/build-rust-macos.sh --verify-lock
[1/4] Rust staticlib (arm64 + x86_64)...
Finished `release` profile [optimized] target(s) in 0.29s
Finished `release` profile [optimized] target(s) in 0.12s
...
ERROR: artifact hash mismatch: artifact differs from /Users/melee/Documents/projects/rhwp-mac/rhwp-core.lock
Artifact: Frameworks/universal/librhwp.a
Expected sha256: 824fee2ccd0bacd978ca043df4b576133c4a78488178c1edd0715c62aeffc9a7
Actual sha256:   bd0ba03be565305a7eca0e4287bb11690fd4e1051d40f7bcb8079f67db282535
Expected size:   202389312
Actual size:     202398800
```

strict `--verify-lock`는 local static archive byte hash/size 차이로 실패했다. 이 실패는 이번 `--locked` 변경 전에 문서화되어 있던 Rust static archive reproducibility 정책과 같은 유형이다. source provenance, Cargo lock, generated header, FFI symbol 단계는 strict 실행에서도 모두 통과한 뒤 staticlib byte hash에서만 중단됐다. `rhwp-core.lock`은 이번 task 범위 밖이므로 갱신하지 않았다.

문서화된 정책 env로 staticlib byte hash 비교만 제외하면 나머지 gate는 통과했다.

```text
$ ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1 scripts/build-rust-macos.sh --verify-lock
[1/4] Rust staticlib (arm64 + x86_64)...
Finished `release` profile [optimized] target(s) in 0.12s
Finished `release` profile [optimized] target(s) in 0.11s
...
WARNING: skipping byte-for-byte hash verification for Frameworks/universal/librhwp.a
Only the Rust static archive sha256/size comparison is skipped.
Source provenance, Cargo.lock, generated header, and FFI symbols remain verified.
Verified: /Users/melee/Documents/projects/rhwp-mac/rhwp-core.lock
```

## 잔여 위험

- local strict staticlib byte hash 검증은 현재 toolchain/build path 산출물과 `rhwp-core.lock` reference metadata 차이로 실패한다.
- 이번 Stage 2는 `--locked` 적용만 수행하므로 `rhwp-core.lock` artifact metadata를 갱신하지 않았다.
- `--locked` 적용 후 개발자가 `RustBridge/Cargo.toml`을 변경하고 `RustBridge/Cargo.lock`을 갱신하지 않으면 build가 중단된다. 이는 의도한 drift 감지다.

## 다음 단계 영향

Stage 3에서는 `rhwp-studio` manifest에 upstream root `Cargo.lock` fingerprint를 기록하는 경로를 보강한다. Stage 2 변경은 RustBridge build script에만 국한되므로 Stage 3의 bundled asset manifest schema와 충돌하지 않는다.

## 승인 요청

Stage 2 결과를 승인받은 뒤 Stage 3 — rhwp-studio manifest Cargo.lock provenance 보강으로 진행한다.
