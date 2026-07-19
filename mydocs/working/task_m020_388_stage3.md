# Task #388 Stage 3 완료 보고서

## 단계 목적

`rhwp-core.lock`과 `Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift`의 core metadata가 어긋났을 때 독립 검증 명령으로 즉시 실패하도록 한다. core pin 변경 후 Thumbnail render signature의 build info 갱신 누락을 조기에 발견하는 것이 목적이다.

## 산출물

| 파일 | 내용 |
|------|------|
| `scripts/verify-rhwp-core-build-info.sh` | 신규 검증 스크립트, 83 lines |
| `mydocs/orders/20260629.md` | #388 상태 메모를 Stage 3 완료보고서 승인 대기로 갱신 |

## 변경 내용

- `scripts/ci/read-rhwp-core-lock.sh`를 재사용해 `rhwp_release_tag`, `rhwp_commit`, `rhwp_enabled_features`를 읽는다.
- `RhwpCoreBuildInfo.releaseTag`, `RhwpCoreBuildInfo.commit`, `RhwpCoreBuildInfo.enabledFeatures` 값을 Swift source에서 읽어 lock 값과 비교한다.
- mismatch 시 어떤 `RhwpCoreBuildInfo` key가 다른지, lock key와 기대값/실제값, 갱신 대상 파일을 stderr에 출력하고 실패한다.
- `--help`와 잘못된 인자 입력 경로를 제공해 로컬 검증 명령의 사용 범위를 명확히 했다.

## 본문 변경 정도 / 본문 무손실 여부

문서 본문 변환 작업은 없다. Swift/Rust runtime 동작은 변경하지 않고, lock metadata와 Swift build info source의 정합성 검증 스크립트만 추가했다.

## 검증 결과

| 명령 | 결과 | 메모 |
|------|------|------|
| `./scripts/verify-rhwp-core-build-info.sh` | 통과 | `OK: RhwpCoreBuildInfo matches rhwp-core.lock` |
| `./scripts/verify-rhwp-core-build-info.sh --help` | 통과 | Usage와 검증 대상 설명 출력 |
| `CARGO_NET_OFFLINE=true ./scripts/build-rust-macos.sh --verify-lock` | 참고 실패 | 로컬 Cargo git cache에 `rhwp v0.7.17` checkout이 없어 offline checkout 불가 |
| `./scripts/build-rust-macos.sh --verify-lock` | 참고 실패 | 네트워크 fetch와 build는 완료했으나 `Frameworks/universal/librhwp.a` byte hash/size가 로컬 toolchain 산출물과 불일치 |
| `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1 ./scripts/build-rust-macos.sh --verify-lock` | 통과 | static archive byte hash/size만 제외하고 source provenance, Cargo.lock, generated header, FFI symbols 검증 유지. `Verified: rhwp-core.lock` |
| `git diff --check` | 통과 | whitespace error 없음 |

strict `--verify-lock`의 static archive hash mismatch는 `mydocs/manual/build_run_guide.md`와 `mydocs/manual/core_dependency_operation_guide.md`에 문서화된 Rust static archive byte reproducibility 차이다. Stage 3 범위에서는 `rhwp-core.lock`을 갱신하지 않았고, 문서화된 정책 env로 source/header/ABI 중심 검증을 유지했다.

## 잔여 위험

- `verify-rhwp-core-build-info.sh`는 Swift 파일을 `awk`로 읽는다. 현재 `RhwpCoreBuildInfo`가 단순한 `static let` string literal 구조이므로 충분하지만, 향후 computed property나 multi-line literal로 바뀌면 스크립트도 함께 갱신해야 한다.
- local strict staticlib byte hash mismatch는 기존 정책에 따라 분리 기록했다. 이 값 자체를 다시 release gate로 쓰려면 toolchain/runner/build path 고정 또는 기준 lock 재생성 정책이 먼저 필요하다.

## 다음 단계 영향

Stage 4에서는 기존 Thumbnail render signature smoke와 build 검증을 실행하면서 새 검증 스크립트를 함께 최종 검증 묶음에 포함하면 된다. 이번 단계는 runtime behavior를 바꾸지 않으므로 Thumbnail cache key 계산 결과는 Stage 2 결과와 동일해야 한다.

## 승인 요청

Stage 3 산출물과 검증 결과를 검토한 뒤 Stage 4 진입 여부를 승인해 달라.
