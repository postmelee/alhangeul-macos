# Task M020 #439 구현계획서

수행계획서: `mydocs/plans/task_m020_439.md`

각 단계 완료 후 `task-stage-report` 절차로 해당 단계 source와 단계 보고서를 함께 검증·커밋하고, 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다. Task #439가 `devel`에 merge되기 전에는 Issue #375를 시작하거나 PR #463을 갱신·폐기·재생성하지 않는다.

## 작업 개요

- 이슈: #439 `rhwp Upstream Sync PR에 RhwpCoreBuildInfo 갱신과 검증 gate 추가`
- 마일스톤: M020 `v0.2.x Skia Quick Look/Thumbnail Backend`
- 기준 브랜치: `devel`
- 작업 브랜치: `local/task439`
- 현재 core/build info: `v0.8.2` / `9b16aa9e23f476e2b335d7c029fc9f24a199d63c` / `native-skia`
- 재현 후보: PR #463은 lock `v0.8.4`와 build info `v0.8.2`가 불일치하지만 CI가 성공한 상태
- 후속 순서: Task #439 merge → Issue #375 → v0.8.4 sync PR 재생성

## 수행계획 승인 반영

1. `rhwp-core.lock`을 Swift build info의 단일 진실 원천으로 유지한다.
2. deterministic writer와 verifier를 분리하고 no-argument production contract를 보존한다.
3. tracked source를 훼손하지 않는 isolated fixture test를 추가한다.
4. upstream sync, PR CI, release rehearsal/publish에 갱신 또는 검증 gate를 연결한다.
5. stable release sync를 우선 지원하고 demo commit pin 동작은 Stage 1에서 조사해 명시적으로 지원·비지원 경계를 정한다.
6. #375, PR #463 재생성, public release는 범위 밖으로 유지한다.

## 구현 전 확인 결과

| 항목 | 현재 상태 | 계획 반영 |
|------|-----------|-----------|
| lock reader | `scripts/ci/read-rhwp-core-lock.sh <key>`가 repository root의 top-level scalar를 읽음 | writer/verifier가 같은 parsing 계약을 재사용할 수 있는지 Stage 1에서 확정한다. |
| core update | `scripts/update-rhwp-core.sh`가 Cargo dependency와 artifact가 비어 있는 lock skeleton을 생성 | build info 갱신은 artifact/feature가 채워지는 `build-rust-macos.sh --update-lock` 이후에 수행한다. |
| enabled features | `build-rust-macos.sh --update-lock`가 Cargo.toml 기준 `rhwp_enabled_features`를 lock에 기록 | writer가 incomplete skeleton을 읽어 stale/빈 값을 쓰지 않도록 precondition을 둔다. |
| verifier | `verify-rhwp-core-build-info.sh`가 current root lock과 Swift 상수 3개를 비교 | no-argument contract를 유지하면서 fixture용 명시 경로 지원 여부를 검토한다. |
| writer | 없음 | 전용 deterministic helper를 1차안으로 둔다. |
| full sync workflow | lock과 bundled studio를 갱신하지만 build info 갱신·stage·검증 없음 | build 완료 뒤 writer → verifier → explicit stage 순서로 연결한다. |
| PR CI | shared boundary와 bundled studio는 검증하지만 build info verifier 미호출 | script interface와 macOS validation 중 적절한 blocking 위치를 Stage 1에서 확정한다. |
| release workflow | `build-rust-macos.sh --verify-lock`는 실행하지만 build info verifier 미호출 | rehearsal/publish source preflight에 별도 verifier를 추가한다. |
| path classification | build-info helper와 Swift build info가 core verify trigger에 명시되지 않음 | 관련 path가 macOS/core gate를 skip하지 않게 분류와 검증을 보강한다. |
| PR body | build info 자동 갱신·검증 결과와 checklist가 없음 | generated verification summary와 maintainer checklist를 갱신한다. |
| current branch | lock과 build info가 일치하고 verifier 통과 | Stage 2 writer를 current input에 재실행해 no-diff를 확인한다. |

## 공통 구현 원칙

1. writer는 `rhwp_release_tag`, `rhwp_commit`, `rhwp_enabled_features`가 모두 존재하고 유효할 때만 Swift 파일을 갱신한다.
2. incomplete lock, demo commit pin, malformed tag/commit/features를 임의의 빈 값 또는 이전 값으로 보정하지 않는다.
3. same input에서 byte-identical Swift output을 생성하고, 임시 파일 검증 후 replacement하는 안전한 쓰기 방식을 사용한다.
4. production helper의 기본 경로는 repository root lock/build-info로 유지한다. fixture test가 필요하면 명시적 `--lock-file`·`--output` 또는 동등하게 제한된 interface를 사용하며 일반 환경 변수로 경로를 암묵 치환하지 않는다.
5. verifier의 기존 no-argument 호출은 유지한다. fixture 경로 지원을 추가하더라도 production failure message와 exit status를 바꾸지 않는다.
6. sync workflow의 순서는 core update → Rust artifact/complete lock update → build info writer → verifier → bundled studio sync/verify → stage로 고정한다.
7. PR CI와 release workflow는 writer를 실행해 drift를 고쳐주지 않고 verifier만 실행한다. CI는 잘못된 source를 자동 수정하지 않고 실패해야 한다.
8. helper test는 임시 fixture만 수정하고 tracked `rhwp-core.lock` 및 `RhwpCoreBuildInfo.swift`의 hash가 실행 전후 동일한지 확인한다.
9. `project.yml`, renderer, Thumbnail cache 구조와 bundled asset은 변경하지 않는다.
10. workflow 실제 dispatch, PR #463 mutation과 remote branch 삭제는 Task #439의 Stage에 포함하지 않는다.

## 예상 최종 변경 표면

helper와 test:

- 신규 `scripts/update-rhwp-core-build-info.sh`
- `scripts/verify-rhwp-core-build-info.sh`
- 신규 `scripts/ci/test-rhwp-core-build-info.sh`
- 필요 시 `scripts/ci/read-rhwp-core-lock.sh`
- 필요 시 `scripts/update-rhwp-core.sh`의 next-step 안내
- `scripts/ci/classify-pr-changes.sh`
- `scripts/ci/write-rhwp-full-sync-pr-body.sh`

workflow:

- `.github/workflows/rhwp-upstream-sync-pr.yml`
- `.github/workflows/pr-ci.yml`
- `.github/workflows/release-rehearsal.yml`
- `.github/workflows/release-publish.yml`

문서:

- `mydocs/manual/core_dependency_operation_guide.md`
- `mydocs/manual/ci_workflow_guide.md`
- `mydocs/manual/release_distribution_guide.md`
- 실제 계약 설명이 필요한 경우에만 `mydocs/manual/build_run_guide.md`
- `mydocs/orders/20260813.md` 또는 실제 단계 진행일의 orders 문서
- `mydocs/working/task_m020_439_stage1.md`
- `mydocs/working/task_m020_439_stage2.md`
- `mydocs/working/task_m020_439_stage3.md`
- `mydocs/working/task_m020_439_stage4.md`
- `mydocs/report/task_m020_439_report.md`

현재 값이 이미 lock과 일치하므로 `Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift`는 writer no-diff 검증 대상이며 Task #439의 의도된 최종 diff에는 포함하지 않는다. Stage 1 조사에서 더 작은 변경 표면이 가능하면 보고서에 근거를 남기고 축소한다.

## 판정 규칙

| 결과 | 판정 |
|------|------|
| 정상 stable lock에서 writer 재실행 후 diff 없음 | 통과 |
| stale tag/commit/features fixture에서 verifier 실패 후 writer 실행으로 수렴 | 통과 |
| incomplete 또는 malformed lock을 writer가 거부 | 통과 |
| writer가 tracked source를 fixture test 중 변경 | blocking |
| sync workflow가 build info를 stage하지 않음 | blocking |
| lock/build info 불일치인데 PR CI 또는 release workflow 성공 | blocking |
| workflow YAML 또는 embedded shell syntax 실패 | blocking |
| demo pin을 잘못 stable release처럼 기록 | blocking |
| Issue #375 범위가 Task #439 diff에 혼입 | 범위 위반, 분리 필요 |
| PR #463 또는 public release 상태 변경 | 범위 위반, 즉시 중단 |

## Stage 1. 호출 graph와 writer/test 계약 확정

### 목표

lock 생성·완성 시점, build info 소비 지점, PR 분류와 sync/CI/release workflow 호출 graph를 고정하고 writer/verifier/test의 exact interface와 stable/demo 경계를 확정한다.

### 대상

- `scripts/update-rhwp-core.sh`
- `scripts/build-rust-macos.sh`
- `scripts/ci/read-rhwp-core-lock.sh`
- `scripts/verify-rhwp-core-build-info.sh`
- `scripts/ci/classify-pr-changes.sh`
- `scripts/ci/write-rhwp-full-sync-pr-body.sh`
- `.github/workflows/rhwp-upstream-sync-pr.yml`
- `.github/workflows/pr-ci.yml`
- `.github/workflows/release-rehearsal.yml`
- `.github/workflows/release-publish.yml`
- `mydocs/working/task_m020_439_stage1.md`
- orders 문서

### 작업

1. stable update와 demo update에서 `rhwp-core.lock` key가 어느 명령 뒤 완성되는지 기록한다.
2. `RhwpCoreBuildInfo`의 현재 소비 지점과 stale 값의 cache 영향 경로를 확인한다.
3. writer interface, 허용 ref kind, 입력 validation, output replacement 방식을 확정한다.
4. verifier의 production no-argument contract와 fixture test용 경로 contract를 확정한다.
5. fixture case와 tracked source 무손실 검증 방식을 확정한다.
6. sync workflow에서 writer/verifier/stage 위치와 verification summary 항목을 확정한다.
7. PR CI와 release workflow의 verifier 위치, path classification trigger와 script interface check를 확정한다.
8. #375와 겹치는 Cargo.lock fingerprint 범위를 변경하지 않는지 확인한다.
9. 제품 source와 workflow를 변경하지 않고 조사 결과를 Stage 1 보고서에 기록한다.

### 검증

```bash
./scripts/verify-rhwp-core-build-info.sh
bash scripts/update-rhwp-core.sh --help
bash scripts/build-rust-macos.sh --help
bash scripts/ci/read-rhwp-core-lock.sh --help
bash scripts/ci/classify-pr-changes.sh --help
bash scripts/ci/write-rhwp-full-sync-pr-body.sh --help
rg -n "RhwpCoreBuildInfo|verify-rhwp-core-build-info|rhwp_enabled_features|update-lock" \
  Sources scripts .github/workflows
git diff --check
```

### 완료 조건

- writer/verifier/test exact interface와 stable/demo 지원 경계가 문서화돼 있다.
- sync, PR CI, release workflow별 갱신/검증 책임이 분리돼 있다.
- 예상 변경 파일과 stage별 검증 명령이 실제 호출 graph 기준으로 확정돼 있다.
- source/helper/workflow tracked file은 변경되지 않았다.

### 커밋

```text
Task #439 Stage 1: build info 자동화 계약과 검증 경계 확정
```

## Stage 2. Deterministic writer와 isolated helper test 구현

### 목표

complete stable lock에서 Swift build info를 deterministic하게 생성하는 writer와 불일치 검증 contract를 구현하고 isolated fixture로 success/failure/no-diff 동작을 고정한다.

### 대상

- 신규 `scripts/update-rhwp-core-build-info.sh`
- `scripts/verify-rhwp-core-build-info.sh`
- 신규 `scripts/ci/test-rhwp-core-build-info.sh`
- Stage 1 결론에 따라 필요한 최소 공통 helper
- `mydocs/working/task_m020_439_stage2.md`
- orders 문서

### 작업

1. stable lock 필수 key와 허용 형식을 검사하는 writer를 추가한다.
2. Swift source를 고정 형식으로 생성하고 임시 파일 검증 뒤 output을 교체한다.
3. verifier의 기존 기본 호출을 보존하면서 fixture test가 명시 경로를 사용할 수 있게 한다.
4. 정상, stale tag, stale commit, stale features, key 누락, malformed input fixture를 구현한다.
5. writer 실행 뒤 verifier 통과와 writer 재실행 no-diff를 확인한다.
6. fixture test 전후 tracked lock/build info hash가 같은지 확인한다.
7. helper `--help`, invalid argument와 failure message contract를 검증한다.

### 검증

```bash
bash -n \
  scripts/update-rhwp-core-build-info.sh \
  scripts/verify-rhwp-core-build-info.sh \
  scripts/ci/test-rhwp-core-build-info.sh
scripts/update-rhwp-core-build-info.sh --help
scripts/verify-rhwp-core-build-info.sh --help
scripts/ci/test-rhwp-core-build-info.sh
./scripts/update-rhwp-core-build-info.sh
./scripts/verify-rhwp-core-build-info.sh
git diff --exit-code -- Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift rhwp-core.lock
git diff --check
```

### 완료 조건

- current stable lock에서 writer가 no-diff이고 verifier가 통과한다.
- stale fixture가 verifier에서 실패하고 writer 실행 후 정확히 수렴한다.
- incomplete/malformed input은 source를 변경하지 않고 실패한다.
- fixture test가 tracked production file을 변경하지 않는다.

### 커밋

```text
Task #439 Stage 2: core build info writer와 fixture 검증 추가
```

## Stage 3. Sync·PR CI·release workflow gate 연결

### 목표

upstream full sync가 build info를 자동 갱신·검증·stage하고, 일반 PR과 release candidate source의 drift를 CI에서 차단하게 한다.

### 대상

- `scripts/ci/classify-pr-changes.sh`
- `scripts/ci/write-rhwp-full-sync-pr-body.sh`
- `.github/workflows/rhwp-upstream-sync-pr.yml`
- `.github/workflows/pr-ci.yml`
- `.github/workflows/release-rehearsal.yml`
- `.github/workflows/release-publish.yml`
- 필요 시 `scripts/update-rhwp-core.sh` 안내
- `mydocs/working/task_m020_439_stage3.md`
- orders 문서

### 작업

1. sync workflow에서 complete lock 생성 뒤 writer와 verifier를 실행한다.
2. `RhwpCoreBuildInfo.swift`를 generated candidate의 explicit stage 목록에 추가한다.
3. verification summary와 generated PR body/checklist에 build-info update/verify 결과를 추가한다.
4. helper·build info·core pin 변경이 필요한 CI gate를 trigger하도록 classification을 갱신한다.
5. PR CI script interface 또는 macOS validation의 blocking 위치에 verifier와 fixture test를 연결한다.
6. release rehearsal/publish source preflight에 verifier를 추가한다.
7. writer는 sync 생성 경로에서만 실행하고 PR CI/release는 drift를 수정하지 않고 실패하게 한다.
8. workflow YAML, embedded shell, classification과 generated body fixture를 정적으로 검증한다.

### 검증

```bash
bash -n \
  scripts/ci/classify-pr-changes.sh \
  scripts/ci/write-rhwp-full-sync-pr-body.sh
scripts/ci/test-rhwp-core-build-info.sh
./scripts/verify-rhwp-core-build-info.sh
ruby -e 'require "psych"; Dir[".github/workflows/*.yml"].sort.each { |path| Psych.parse_file(path) }'
bash scripts/ci/classify-pr-changes.sh --help
bash scripts/ci/write-rhwp-full-sync-pr-body.sh --help
scripts/validate-github-body.sh <task439-generated-pr-body>
rg -n "update-rhwp-core-build-info|verify-rhwp-core-build-info|RhwpCoreBuildInfo.swift" \
  .github/workflows scripts/ci
git diff --check
```

### 완료 조건

- sync candidate에 build info가 자동 포함되고 verifier 결과가 summary/body에 기록된다.
- build info drift가 PR CI와 release rehearsal/publish에서 blocking failure다.
- helper 또는 Swift build info 변경이 필요한 CI gate를 건너뛰지 않는다.
- public workflow dispatch나 PR #463 mutation 없이 local/static 검증이 통과한다.

### 커밋

```text
Task #439 Stage 3: sync와 release build info gate 연결
```

## Stage 4. 운영 문서와 전체 회귀 검증

### 목표

새 build-info 자동화 계약을 운영 문서와 maintainer checklist에 반영하고 전체 helper/workflow 회귀를 검증해 #375 및 v0.8.4 sync 재생성 handoff를 확정한다.

### 대상

- `mydocs/manual/core_dependency_operation_guide.md`
- `mydocs/manual/ci_workflow_guide.md`
- `mydocs/manual/release_distribution_guide.md`
- 필요 시 `mydocs/manual/build_run_guide.md`
- Stage 2~3 helper/workflow 전체
- `mydocs/working/task_m020_439_stage4.md`
- orders 문서

### 작업

1. core update 후 complete lock과 build info를 만드는 표준 명령 순서를 문서화한다.
2. sync workflow의 writer 책임과 PR/release verifier 책임을 구분해 기록한다.
3. generated PR checklist에 사람이 확인할 잔여 항목과 자동 gate를 구분한다.
4. helper syntax/interface/fixture, classification, workflow YAML과 current source verifier를 전체 재실행한다.
5. current tracked build info가 no-diff이며 unrelated source drift가 없는지 확인한다.
6. #375가 이어서 변경할 Cargo.lock fingerprint 범위와 겹침 파일을 handoff에 기록한다.
7. #439 merge 후 #375 완료 전에는 PR #463 재생성을 시작하지 않는 운영 순서를 확정한다.

### 검증

```bash
bash -n \
  scripts/update-rhwp-core.sh \
  scripts/update-rhwp-core-build-info.sh \
  scripts/verify-rhwp-core-build-info.sh \
  scripts/ci/test-rhwp-core-build-info.sh \
  scripts/ci/classify-pr-changes.sh \
  scripts/ci/write-rhwp-full-sync-pr-body.sh
scripts/ci/test-rhwp-core-build-info.sh
./scripts/update-rhwp-core-build-info.sh
./scripts/verify-rhwp-core-build-info.sh
ruby -e 'require "psych"; Dir[".github/workflows/*.yml"].sort.each { |path| Psych.parse_file(path) }'
git diff --exit-code -- Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift rhwp-core.lock
git diff --check
```

### 완료 조건

- helper와 모든 workflow gate가 current source에서 통과한다.
- 문서가 writer, verifier, sync, PR CI, release 책임을 같은 계약으로 설명한다.
- Task #439 최종 diff에 #375, PR #463 또는 public release mutation이 없다.
- #375 시작과 v0.8.4 sync 재생성에 필요한 handoff 조건이 명확하다.

### 커밋

```text
Task #439 Stage 4: build info 자동화 문서와 회귀 검증 완료
```

## 구현계획 승인 요청

1. 위 4개 Stage와 단계별 완료 조건·커밋 경계를 승인해 달라.
2. 전용 writer `scripts/update-rhwp-core-build-info.sh`와 isolated test를 기본 구현안으로 승인해 달라.
3. sync workflow만 writer를 실행하고 PR CI·release workflow는 verifier로 drift를 차단하는 책임 분리를 승인해 달라.
4. stable release lock을 writer 지원 대상으로 고정하고 demo commit pin의 정확한 처리 방식은 Stage 1 조사 결과에서 승인받도록 하는 경계를 승인해 달라.
5. #375와 PR #463 재생성은 Task #439 merge 뒤 별도 절차로 유지하는 것을 승인해 달라.

구현계획 승인 전에는 Stage 1 조사 보고서 작성, helper·workflow·manual 변경 또는 PR #463 상태 변경을 시작하지 않는다.
