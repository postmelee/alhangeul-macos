# Task #55 Stage 4 완료 보고서

## 단계 목적

Demo/Preview commit pin과 Stable release tag 기준을 update architecture와 #30 진행 기준에 반영한다. 현재 submodule 기반 script는 유지하되, 후속 #30에서 `Vendor/rhwp` 제거와 함께 script를 어떻게 재정의할지 문서화한다.

## 산출물

- `mydocs/tech/core_release_compatibility.md`: update script architecture, 실패 prefix, build script lock 검증 기준 추가
- `mydocs/manual/core_submodule_operation_guide.md`: git dependency 전환 후 `update-rhwp-core.sh` 역할 보강
- `mydocs/manual/build_run_guide.md`: `--channel demo --rev`, `--channel stable --tag` 사용 형태 추가
- GitHub Issue #30 본문 갱신: Demo/Preview commit-pinned 전환 경로와 Stable release tag 전환 경로 분리
- `mydocs/working/task_m010_55_stage4.md`: Stage 4 완료 보고서

변경 규모:

```text
mydocs/manual/build_run_guide.md                |  9 ++++
mydocs/manual/core_submodule_operation_guide.md |  1 +
mydocs/tech/core_release_compatibility.md       | 69 +++++++++++++++++++++++++
```

## 본문 변경 정도 / 본문 무손실 여부

기존 Stage 3 기준을 유지하면서 update architecture를 추가했다. 기존 script 본문은 변경하지 않았다.

script를 지금 변경하지 않은 이유:

- 현재 `scripts/build-rust-macos.sh`와 `scripts/update-rhwp-core.sh`는 `Vendor/rhwp` submodule 존재를 전제로 한다.
- Demo/Preview git dependency 전환은 `Vendor/rhwp` 제거, `RustBridge/Cargo.toml`, `Cargo.lock`, `rhwp-core.lock` 변경과 함께 일어나야 한다.
- 따라서 #55에서 script를 부분 변경하면 현재 submodule 검증 경로와 후속 git dependency 경로가 섞일 위험이 있다.
- #55에서는 후속 #30에서 구현할 interface, lock 기준, 실패 유형만 확정한다.

## update architecture 요약

후속 #30에서 `scripts/update-rhwp-core.sh`는 다음 형태의 dependency update gate로 재정의한다.

```bash
./scripts/update-rhwp-core.sh --channel demo --rev <commit-sha>
./scripts/update-rhwp-core.sh --channel stable --tag <release-tag>
./scripts/update-rhwp-core.sh --check --channel stable --tag <release-tag>
```

처리 순서:

1. channel과 ref 입력 검증
2. upstream ref 확인
3. required core API 확인
4. `RustBridge/Cargo.toml` dependency 갱신
5. `Cargo.lock` 갱신과 resolved commit 추출
6. `rhwp-core.lock` skeleton 갱신
7. RustBridge build와 FFI symbol diff
8. `build-rust-macos.sh --update-lock` 또는 `--verify-lock` 안내

실패 prefix:

- `ERROR: release lookup failure`
- `ERROR: missing core API`
- `ERROR: dependency fetch failure`
- `ERROR: Cargo.lock mismatch`
- `ERROR: artifact hash mismatch`
- `ERROR: FFI symbol diff`
- `ERROR: render smoke failure`

## #30 본문 갱신

GitHub Issue #30 본문을 갱신했다.

갱신 내용:

- 목표를 `release tag dependency` 단일 경로에서 `git dependency` 전환으로 보정
- Demo/Preview: `git` + `rev` commit pin 경로 추가
- Stable: `git` + `tag` release tag 경로 유지
- 현재 lock commit `1e9d78a1d40c71779d81c6ec6870cd301d912626`을 Demo/Preview 후보로 명시
- `scripts/update-rhwp-core.sh`의 `--channel demo --rev`, `--channel stable --tag` 역할 정리
- fresh checkout에서 `Vendor/rhwp` 없이 빌드되어야 한다는 검증 기준 유지

확인:

```text
$ gh issue edit 30 --body-file /tmp/issue30_body.md
https://github.com/postmelee/alhangeul-macos/issues/30

$ gh issue view 30 --json body,url
결과: Demo/Preview commit-pinned 전환 경로와 Stable release tag 전환 경로가 본문에 반영됨.
```

## 검증 결과

diff check:

```text
$ git diff --check
결과: 통과.
```

script syntax:

```text
$ bash -n scripts/update-rhwp-core.sh
결과: 통과.

$ bash -n scripts/build-rust-macos.sh
결과: 통과.
```

검색 게이트:

```text
$ rg -n "missing core API|Cargo.lock mismatch|artifact hash mismatch|FFI symbol diff|render smoke failure|release tag|resolved commit|Demo/Preview|demo-commit-pin|--channel demo|--channel stable|rhwp_ref_kind" scripts mydocs/tech/core_release_compatibility.md mydocs/manual/core_submodule_operation_guide.md mydocs/manual/build_run_guide.md
결과: 실패 유형, Demo/Preview channel, Stable channel, lock ref kind 기준 확인.
```

라인 수:

```text
$ wc -l mydocs/tech/core_release_compatibility.md mydocs/manual/core_submodule_operation_guide.md mydocs/manual/build_run_guide.md
403 mydocs/tech/core_release_compatibility.md
 72 mydocs/manual/core_submodule_operation_guide.md
222 mydocs/manual/build_run_guide.md
697 total
```

## 잔여 위험

- #30 본문은 갱신했지만 실제 `Vendor/rhwp` 제거와 git dependency 전환은 아직 수행하지 않았다.
- script 재정의는 #30에서 `Cargo.toml`, `Cargo.lock`, `rhwp-core.lock` 변경과 함께 수행해야 한다.
- `gh issue edit`은 네트워크 접근이 필요해 escalation으로 실행했다.

## 다음 단계 영향

Stage 5에서는 전체 검증과 최종 보고를 수행한다. 문서 변경 중심 작업이므로 `git diff --check`, `build-rust-macos.sh --verify-lock`, `check-no-appkit.sh`, script syntax, 검색 게이트를 수행하고 오늘할일과 최종 보고서를 정리한다.

## 승인 요청

Stage 4 update architecture와 #30 기준 정리를 완료했다. Stage 5 전체 검증과 최종 보고로 진행할지 승인 요청한다.
