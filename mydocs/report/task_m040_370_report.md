# Task M040 #370 최종 결과보고서

## 작업 요약

| 항목 | 값 |
|------|----|
| GitHub Issue | [#370](https://github.com/postmelee/alhangeul-macos/issues/370) |
| 마일스톤 | M040 (`v0.4`) |
| 작업 브랜치 | `local/task370` |
| 기준 브랜치 | `devel` |
| 단계 수 | 5단계 |
| 목적 | upstream root `Cargo.lock` 추적 전환을 downstream core/studio provenance와 locked build 검증에 반영 |

upstream `edwardkim/rhwp` root `Cargo.lock`은 downstream `RustBridge/Cargo.lock`을 대체하지 않고, upstream release checkout의 CLI/WASM/studio dependency graph fingerprint로 다루도록 정리했다. RustBridge native build는 `--locked`로 downstream lock drift를 조기에 잡고, bundled `rhwp-studio` sync manifest에는 다음 sync부터 `source_cargo_lock_sha256`을 기록할 수 있게 했다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `scripts/build-rust-macos.sh` | arm64/x86_64 Rust staticlib build에 `--locked`를 적용해 `RustBridge/Cargo.lock` drift를 build gate로 만든다. |
| `scripts/sync-rhwp-studio.sh` | upstream root `Cargo.lock` 존재를 요구하고 sha256을 `source_cargo_lock_sha256`으로 manifest에 기록한다. |
| `scripts/verify-rhwp-studio-assets.sh` | manifest에 `source_cargo_lock_sha256`이 있으면 64자 sha256 hex 형식을 검증한다. 기존 manifest는 호환 경로로 통과한다. |
| `scripts/ci/detect-rhwp-studio-impact.sh` | upstream `Cargo.lock` 변경 사유를 `Rust dependency graph lockfile`로 분리한다. |
| `scripts/ci/write-rhwp-full-sync-pr-body.sh` | full sync PR scope와 checklist에 upstream root `Cargo.lock` fingerprint 확인을 추가한다. |
| `scripts/ci/write-rhwp-studio-sync-pr-body.sh` | studio sync PR checklist에 `source_cargo_lock_sha256` 확인을 추가한다. |
| `scripts/ci/write-release-delta-checklist.sh` | sync/provenance helper 변경을 `rhwp core/viewer provenance`로 분류하고 release owner 보정 항목을 추가한다. |
| `mydocs/manual/core_dependency_operation_guide.md` | upstream root lock, downstream bridge lock, `rhwp-core.lock`, studio manifest fingerprint의 역할 차이를 문서화하고 현재 lock 기준을 `v0.7.16`으로 정리한다. |
| `mydocs/manual/build_run_guide.md` | RustBridge locked build 기준과 studio manifest fingerprint 검증 경계를 문서화한다. |
| `mydocs/tech/core_release_compatibility.md` | release compatibility 기준에서 `RustBridge/Cargo.lock`과 upstream root `Cargo.lock`을 분리하고 `source_cargo_lock_sha256` mismatch 유형을 추가한다. |
| `mydocs/plans/task_m040_370.md` | 수행계획서. |
| `mydocs/plans/task_m040_370_impl.md` | 구현계획서. |
| `mydocs/working/task_m040_370_stage1.md` | Stage 1 조사와 설계 결정 기록. |
| `mydocs/working/task_m040_370_stage2.md` | Stage 2 locked build 적용과 검증 기록. |
| `mydocs/working/task_m040_370_stage3.md` | Stage 3 studio manifest provenance 적용과 fixture 검증 기록. |
| `mydocs/working/task_m040_370_stage4.md` | Stage 4 upstream diff/PR body 가시성 보강과 fixture 검증 기록. |
| `mydocs/orders/20260624.md` | #370 작업 상태와 완료 기록. |

## 단계별 결과

| 단계 | 결과 |
|------|------|
| Stage 1 | 기존 lock/provenance 경로를 조사하고 upstream root `Cargo.lock`은 studio/WASM source fingerprint, `RustBridge/Cargo.lock`은 native bridge build lock이라는 설계를 확정했다. |
| Stage 2 | `scripts/build-rust-macos.sh`의 두 target build에 `--locked`를 적용했다. strict staticlib byte hash 실패는 기존 정책상 별도 reproducibility 이슈로 분리했다. |
| Stage 3 | `rhwp-studio` sync manifest에 `source_cargo_lock_sha256`을 기록하고, asset verify script는 새 필드 형식 검증과 기존 manifest 호환을 모두 지원하게 했다. |
| Stage 4 | upstream `Cargo.lock` diff reason, full/studio sync PR body, release delta checklist에 dependency graph/provenance 확인 항목을 추가했다. |
| Stage 5 | 운영 문서에 lockfile 역할 구분과 현재 `v0.7.16` lock 기준을 반영하고 최종 검증/보고서를 작성했다. |

## 검증 결과

| 검증 항목 | 결과 | 비고 |
|-----------|------|------|
| `git diff --check` | OK | whitespace 오류 없음 |
| `bash -n scripts/build-rust-macos.sh scripts/sync-rhwp-studio.sh scripts/verify-rhwp-studio-assets.sh scripts/ci/detect-rhwp-studio-impact.sh scripts/ci/write-rhwp-full-sync-pr-body.sh scripts/ci/write-rhwp-studio-sync-pr-body.sh scripts/ci/write-release-delta-checklist.sh` | OK | 수정한 shell script 문법 확인 |
| `scripts/verify-rhwp-studio-assets.sh` | OK | 현재 bundled `rhwp-studio` asset 검증 통과. 현재 manifest에는 `source_cargo_lock_sha256`이 없어 호환 경로로 통과 |
| `scripts/build-rust-macos.sh --verify-lock` | Expected fail | source provenance, `RustBridge/Cargo.lock`, generated header, FFI symbol 단계 통과 후 `Frameworks/universal/librhwp.a` byte hash/size에서 실패 |
| `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1 scripts/build-rust-macos.sh --verify-lock` | OK | staticlib byte hash/size 비교만 제외하고 나머지 gate 검증 통과 |
| `rg -n 'Cargo.lock|--locked|source_cargo_lock_sha256|dependency graph|provenance' scripts mydocs/manual mydocs/tech` | OK | 스크립트와 문서에 새 provenance/locked build 경계가 노출되는지 확인 |
| Stage 3 fixture sync check | OK | `/private/tmp/rhwp-mac-task370-stage3-fixture` 기준 `sync-rhwp-studio.sh --check` 통과 |
| Stage 4 fixture impact/PR body smoke | OK | `Cargo.lock` only diff가 `Rust dependency graph lockfile`로 표시되고 full/studio PR body checklist에 `source_cargo_lock_sha256` 확인 항목이 생성됨 |

strict `--verify-lock` 실패 세부:

```text
Artifact: Frameworks/universal/librhwp.a
Expected sha256: 824fee2ccd0bacd978ca043df4b576133c4a78488178c1edd0715c62aeffc9a7
Actual sha256:   bd0ba03be565305a7eca0e4287bb11690fd4e1051d40f7bcb8079f67db282535
Expected size:   202389312
Actual size:     202398800
```

이번 task는 `rhwp-core.lock` artifact metadata를 갱신하지 않는다. 위 차이는 기존 문서화된 Rust static archive byte reproducibility 정책에 따라 별도 검토 대상이며, source provenance와 ABI 검증은 통과했다.

## 실행하지 않은 항목

이번 task는 upstream `Cargo.lock` 추적 전환을 downstream 검증/문서/자동화에 반영하는 작업이므로 다음은 실행하지 않았다.

- `rhwp v0.7.17` 이상으로 core pin 갱신
- `scripts/update-rhwp-core.sh --channel stable --tag <new-tag>`
- `scripts/build-rust-macos.sh --update-lock`
- 실제 upstream release checkout 기준 bundled `rhwp-studio` asset 갱신
- signed/notarized DMG, GitHub Release, Sparkle appcast, Homebrew Cask 배포

## 잔여 위험과 후속 작업

- 현재 bundled `rhwp-studio` manifest에는 `source_cargo_lock_sha256`이 없다. 다음 실제 upstream sync부터 새 fingerprint가 기록된다.
- strict local `librhwp.a` byte hash 검증은 현재 toolchain/build path 산출물과 `rhwp-core.lock` reference metadata 차이로 실패한다. CI/release 정책은 staticlib byte hash만 제외하고 source/ABI gate를 유지한다.
- upstream root `Cargo.lock` 값 자체와 manifest fingerprint의 실제 일치는 다음 full sync 또는 studio sync PR에서 target checkout 기준으로 확인해야 한다.
- 문서의 현재 lock 기준은 `rhwp-core.lock`과 bundled manifest의 `v0.7.16`에 맞췄다. 향후 core release sync task에서는 이 기준도 함께 갱신해야 한다.

## 커밋 목록

```text
b1e293c Task #370: 수행 계획서 작성과 오늘할일 갱신
aed0ce4 Task #370: 구현 계획서 작성
14380fe Task #370 Stage 1: lock provenance 경로 조사
30afbab Task #370 Stage 2: RustBridge locked build 검증 적용
64620ad Task #370 Stage 3: rhwp-studio Cargo.lock provenance 기록
70dfc2b Task #370 Stage 4: upstream Cargo.lock diff 가시성 보강
```

Stage 5 최종 보고 커밋은 본 보고서와 문서 보강, 오늘할일 완료 처리와 함께 생성한다.

## 작업지시자 승인 요청

최종 결과보고서 기준으로 PR 게시 단계 진행 승인을 요청한다. 승인 후 `publish/task370` 원격 브랜치로 push하고 `devel` 대상 PR을 생성한다.
