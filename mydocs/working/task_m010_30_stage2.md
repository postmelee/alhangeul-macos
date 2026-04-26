# Task #30 Stage 2 완료 보고서

## 단계 목적

`Vendor/rhwp` submodule update script를 git dependency update gate로 재정의하고, build script의 lock 검증을 이후 `Cargo.lock` 기반 dependency source와 대조할 수 있게 준비한다.

## 산출물

- `scripts/update-rhwp-core.sh` (462 lines)
  - `--channel demo --rev <commit-sha>`
  - `--channel stable --tag <release-tag>`
  - `--check`
  - upstream ref fetch, required API gate, Cargo.toml dependency 갱신, Cargo.lock 검증, rhwp-core.lock skeleton 갱신
  - 갱신 실패 시 `Cargo.toml`/`Cargo.lock` 원복
- `scripts/build-rust-macos.sh` (608 lines)
  - 현재 path dependency와 전환 후 git dependency를 모두 감지
  - git dependency 모드에서 `Cargo.lock`의 rhwp source repo/ref/commit/tag를 추출
  - `rhwp-core.lock`과 repo/ref kind/release tag/commit/artifact hash를 검증
  - failure prefix를 `Cargo.lock mismatch`, `artifact hash mismatch`로 분리
- `mydocs/orders/20260426.md`
  - #30 비고를 Stage 3 승인 대기 상태로 갱신
- `mydocs/working/task_m010_30_stage2.md`
  - Stage 2 완료 보고서

## 본문 변경 정도 / 본문 무손실 여부

`scripts/update-rhwp-core.sh`는 submodule update 전용 script에서 dependency update gate로 사실상 재작성했다. 기존 역할인 "core 기준 갱신 후 build lock 갱신 안내"는 유지하되, 동작 기준을 `Vendor/rhwp` checkout에서 upstream git ref와 Cargo dependency로 바꿨다.

`scripts/build-rust-macos.sh`는 build 4단계 흐름을 유지했다. 변경은 lock provenance 해석과 검증 함수에 집중했으며, 현재 path dependency에서는 기존처럼 `Vendor/rhwp` HEAD를 사용하고, git dependency 전환 뒤에는 `Cargo.lock` source를 사용한다.

## 구현 요약

`update-rhwp-core.sh`:

- `demo` channel은 full 40자 SHA만 허용한다.
- `stable` channel은 release tag를 fetch하고 resolved commit을 확인한다.
- required core API는 다음 5개를 gate로 확인한다.
  - `build_page_render_tree`
  - `get_bin_data`
  - `render_page_svg_native`
  - `get_page_info_native`
  - `extract_thumbnail_only`
- `--check`는 upstream ref/API만 검증하고 파일을 변경하지 않는다.
- 실제 갱신 모드는 `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`, `rhwp-core.lock` skeleton을 함께 갱신한다.
- `cargo update` 또는 lock 검증 실패 시 Cargo 파일을 원복한다.

`build-rust-macos.sh`:

- `RustBridge/Cargo.toml`에서 `rhwp` dependency mode를 `path` 또는 `git`으로 감지한다.
- `path` mode는 기존 submodule HEAD와 `.gitmodules` repo를 사용한다.
- `git` mode는 `RustBridge/Cargo.lock`의 `source = "git+...#<commit>"`에서 repo, query, resolved commit을 추출한다.
- `rhwp-core.lock` 검증은 repo, ref kind, release tag, commit, artifact sha256/size 순서로 수행한다.
- `Vendor/rhwp` 존재 검사는 path dependency일 때만 수행한다.

## 검증 결과

문법 검증:

```text
$ bash -n scripts/update-rhwp-core.sh
결과: 통과

$ bash -n scripts/build-rust-macos.sh
결과: 통과
```

shellcheck:

```text
$ shellcheck scripts/update-rhwp-core.sh scripts/build-rust-macos.sh
결과: 통과
```

검색 gate:

```text
$ rg -n "channel demo|channel stable|demo-commit-pin|missing core API|Cargo.lock mismatch|artifact hash mismatch|FFI symbol diff|dependency fetch failure|release lookup failure" scripts rhwp-core.lock
결과: channel interface, demo-commit-pin, missing core API, dependency fetch failure, release lookup failure, Cargo.lock mismatch, artifact hash mismatch prefix 확인.
```

Demo/Preview commit gate:

```text
$ ./scripts/update-rhwp-core.sh --channel demo --rev 1e9d78a1d40c71779d81c6ec6870cd301d912626 --check
From https://github.com/edwardkim/rhwp
 * branch            1e9d78a1d40c71779d81c6ec6870cd301d912626 -> FETCH_HEAD
Checked rhwp core target:
  channel: demo
  rev:     1e9d78a1d40c71779d81c6ec6870cd301d912626
  commit:  1e9d78a1d40c71779d81c6ec6870cd301d912626
```

Stable release gate 기대 실패:

```text
$ if ./scripts/update-rhwp-core.sh --channel stable --tag v0.7.3 --check; then echo "ERROR: stable check unexpectedly passed"; exit 1; else echo "Expected stable gate failure for v0.7.3"; fi
From https://github.com/edwardkim/rhwp
 * [new tag]         v0.7.3     -> v0.7.3
ERROR: missing core API: build_page_render_tree
ERROR: missing core API: get_bin_data
ERROR: missing core API: target c2e8a3461de800a02f76127ff4797bade1d4e532 does not satisfy RustBridge requirements
Expected stable gate failure for v0.7.3
```

현재 path dependency lock verify:

```text
$ ./scripts/build-rust-macos.sh --verify-lock
[1/4] Rust staticlib (arm64 + x86_64)...
[2/4] Universal binary...
[3/4] cbindgen header check...
[4/4] XCFramework...
Verified: /Users/melee/Documents/projects/rhwp-mac/rhwp-core.lock
```

`xcodebuild -create-xcframework` 중 CoreSimulatorService 관련 sandbox 로그가 출력됐지만, XCFramework 생성과 `rhwp-core.lock` 검증은 성공했다.

diff 검증:

```text
$ git diff --check
결과: 통과
```

## 잔여 위험

- Stage 2에서는 `RustBridge/Cargo.toml`을 아직 git dependency로 전환하지 않았다. `Cargo.lock` git source parser는 Stage 3 실제 전환 후 다시 검증해야 한다.
- `update-rhwp-core.sh`는 GitHub fetch와 Cargo dependency fetch에 네트워크가 필요하다. 네트워크 실패는 `dependency fetch failure` 또는 `release lookup failure`로 분리되지만, 실제 Stage 3 갱신 시에도 escalation이 필요할 수 있다.
- Stable tag `v0.7.3`은 의도대로 `missing core API`로 실패한다. Stable 전환은 여전히 blocked 상태다.
- Stage 5에서 문서가 git dependency 기준으로 바뀌기 전까지 README/매뉴얼에는 submodule 기준 설명이 남아 있다.

## 다음 단계 영향

Stage 3에서는 `./scripts/update-rhwp-core.sh --channel demo --rev 1e9d78a1d40c71779d81c6ec6870cd301d912626`를 사용해 `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`, `rhwp-core.lock` skeleton을 전환할 수 있다.

그 다음 `.gitmodules`와 `Vendor/rhwp` gitlink를 제거하고, `./scripts/build-rust-macos.sh --update-lock`로 artifact hash/size를 새 기준으로 기록해야 한다.

## 승인 요청

Stage 2 `git dependency update gate와 lock 정합성 설계 구현`을 완료했다. 이 보고서 기준으로 Stage 3 `RustBridge git-rev dependency 전환과 Vendor/rhwp 제거`를 진행할지 승인 요청한다.
