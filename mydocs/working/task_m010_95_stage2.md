# Task #95 Stage 2 완료 보고서

## 단계 목적

`RustBridge` core dependency를 Demo/Preview commit pin에서 `rhwp v0.7.8` Stable release tag pin으로 전환하고, `Cargo.lock`과 `rhwp-core.lock`의 provenance skeleton이 같은 release tag와 resolved commit을 가리키도록 맞춘다.

## 산출물

- `RustBridge/Cargo.toml`
  - `rhwp` dependency를 `rev = "e91ecea..."`에서 `tag = "v0.7.8"`로 변경
- `RustBridge/Cargo.lock`
  - `rhwp` package version을 `0.7.8`로 갱신
  - source를 `tag=v0.7.8#42cf91b6ba7b50fa1c853c01158a52ef68b45442`로 갱신
- `rhwp-core.lock`
  - `rhwp_ref_kind = "release-tag"`
  - `rhwp_release_tag = "v0.7.8"`
  - `rhwp_commit = "42cf91b6ba7b50fa1c853c01158a52ef68b45442"`
  - Stage 3 artifact 재생성을 위해 `built_at`, artifact `sha256`, `size`를 빈 skeleton으로 초기화
- `mydocs/working/task_m010_95_stage2.md`
  - Stage 2 변경과 검증 결과 기록

## 본문 변경 정도 / 본문 무손실 여부

- 코드 본문과 Swift/Rust ABI 구현은 수정하지 않았다.
- `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`, `rhwp-core.lock`의 dependency/provenance metadata만 갱신했다.
- generated artifact는 이번 단계에서 재생성하지 않았다.
- `rhwp-core.lock`의 artifact hash/size가 빈 값으로 바뀐 것은 Stage 3 `./scripts/build-rust-macos.sh --update-lock`에서 새 산출물 기준으로 채우기 위한 의도된 중간 상태다.

## 변경 내용

`./scripts/update-rhwp-core.sh --channel stable --tag v0.7.8` 실행 결과:

```text
Checked rhwp core target:
  channel: stable
  tag:     v0.7.8
  commit:  42cf91b6ba7b50fa1c853c01158a52ef68b45442
Updated: /Users/melee/Documents/projects/rhwp-mac/RustBridge/Cargo.toml
Updated: /Users/melee/Documents/projects/rhwp-mac/RustBridge/Cargo.lock
Updated: /Users/melee/Documents/projects/rhwp-mac/rhwp-core.lock
Next: ./scripts/build-rust-macos.sh --update-lock && ./scripts/check-no-appkit.sh
```

핵심 diff:

```text
RustBridge/Cargo.toml
- rhwp = { git = "https://github.com/edwardkim/rhwp.git", rev = "e91ecea3174a0da0ad7a1ea495cacc4f8772c31d" }
+ rhwp = { git = "https://github.com/edwardkim/rhwp.git", tag = "v0.7.8" }

RustBridge/Cargo.lock
- version = "0.7.7"
- source = "git+https://github.com/edwardkim/rhwp.git?rev=e91ecea3174a0da0ad7a1ea495cacc4f8772c31d#e91ecea3174a0da0ad7a1ea495cacc4f8772c31d"
+ version = "0.7.8"
+ source = "git+https://github.com/edwardkim/rhwp.git?tag=v0.7.8#42cf91b6ba7b50fa1c853c01158a52ef68b45442"

rhwp-core.lock
+ rhwp_ref_kind = "release-tag"
+ rhwp_release_tag = "v0.7.8"
+ rhwp_commit = "42cf91b6ba7b50fa1c853c01158a52ef68b45442"
```

Demo/Preview 전용 필드는 Stable skeleton에서 제거됐다.

- `rhwp_release_transition_status = "demo-commit-pin"` 제거
- `rhwp_latest_checked_release_tag = "v0.7.7"` 제거
- `rhwp_latest_checked_release_commit = "033617e..."` 제거

## 검증 결과

```bash
$ ./scripts/update-rhwp-core.sh --channel stable --tag v0.7.8
```

결과: 성공. `v0.7.8` tag resolved commit `42cf91b6ba7b50fa1c853c01158a52ef68b45442` 기준으로 `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`, `rhwp-core.lock`이 갱신됐다.

```bash
$ rg -n "v0\\.7\\.8|rhwp_ref_kind|rhwp_release_tag|rhwp_commit|demo-commit-pin" RustBridge/Cargo.toml RustBridge/Cargo.lock rhwp-core.lock
```

결과:

```text
RustBridge/Cargo.toml:11:rhwp = { git = "https://github.com/edwardkim/rhwp.git", tag = "v0.7.8" }
rhwp-core.lock:3:rhwp_ref_kind = "release-tag"
rhwp-core.lock:4:rhwp_release_tag = "v0.7.8"
rhwp-core.lock:5:rhwp_commit = "42cf91b6ba7b50fa1c853c01158a52ef68b45442"
RustBridge/Cargo.lock:586:source = "git+https://github.com/edwardkim/rhwp.git?tag=v0.7.8#42cf91b6ba7b50fa1c853c01158a52ef68b45442"
```

`demo-commit-pin`은 검색 결과에 나타나지 않았다.

```bash
$ git diff -- RustBridge/Cargo.toml RustBridge/Cargo.lock rhwp-core.lock
```

결과: 변경 내용은 stable tag dependency, `rhwp` Cargo package source, `rhwp-core.lock` release tag skeleton으로 제한됨을 확인했다.

```bash
$ git diff --check -- RustBridge/Cargo.toml RustBridge/Cargo.lock rhwp-core.lock
```

결과: 통과.

## 잔여 위험

- `rhwp-core.lock` artifact section은 현재 빈 skeleton이다. Stage 3에서 Rust bridge artifact를 재생성하고 `--update-lock`, `--verify-lock`을 통과해야 lock이 완성된다.
- 이번 단계에서는 `Rhwp.xcframework`를 재생성하지 않았으므로, 현재 generated artifact와 `rhwp-core.lock`은 아직 일치하지 않는다.
- `Cargo.lock`은 `v0.7.8` source로 갱신됐지만, 실제 Rust static library build와 C ABI symbol diff는 Stage 3에서 확인해야 한다.

## 다음 단계 영향

Stage 3에서 다음 작업을 수행해야 한다.

- `./scripts/build-rust-macos.sh --update-lock`
- `./scripts/build-rust-macos.sh --verify-lock`
- `diff -u rhwp-ffi-symbols.txt Frameworks/generated_rhwp_symbols.txt`
- generated header의 `rhwp_render_page_tree`, `rhwp_image_data`, `width_pt`, `height_pt` 유지 확인

## 승인 요청

Stage 2 완료를 승인하고 Stage 3 Rust bridge 산출물 재생성과 lock verify로 진행할지 승인 요청한다.
