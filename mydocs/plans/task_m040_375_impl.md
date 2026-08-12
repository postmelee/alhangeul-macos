# Task #375 구현계획서

## 구현 목표

`source_cargo_lock_sha256`의 형식 검증과 실제 target upstream root `Cargo.lock` byte hash 비교를 하나의 명시적 verifier 계약으로 연결한다. 일반 resource/app/release 검증은 checkout 없이 계속 동작하고, sync candidate 생성 경로는 target checkout을 제공해 fingerprint 존재와 일치를 blocking gate로 강제한다.

## 현행 기준

| 영역 | 현행 | 문제 |
|------|------|------|
| Manifest writer | `sync-rhwp-studio.sh`가 upstream root `Cargo.lock`을 `shasum -a 256`으로 기록 | 기록 직후 실제 upstream file과 다시 비교하지 않음 |
| Asset verifier | Fingerprint가 있으면 lowercase 64자 형식만 확인 | 다른 유효 SHA-256 값도 통과 |
| Legacy resource | Fingerprint가 없어도 resource-only 검증 성공 | 유지해야 하는 호환 경로 |
| Full sync workflow | Target checkout을 복원하고 sync 후 verifier 실행 | 두 verifier 호출 모두 `--upstream-dir`을 전달하지 않음 |
| PR body | Maintainer가 실제 hash 일치를 수동 checklist로 확인 | 자동 gate 결과와 책임 중복 |
| Test | Production verifier와 Stage 370 일회성 fixture만 존재 | Match/mismatch/누락 진단을 고정하는 지속 fixture 없음 |

현재 bundled manifest는 `v0.8.2`/`9b16aa9...`와 `source_cargo_lock_sha256=64ff4041...`을 기록한다. Task #375는 이 값이나 asset을 갱신하지 않는다.

## 핵심 계약

### Verifier mode

| 입력 | Manifest fingerprint | 동작 |
|------|----------------------|------|
| `--upstream-dir` 없음 | 없음 | Legacy resource-only 호환 검증 성공 |
| `--upstream-dir` 없음 | 있음 | Fingerprint 형식만 검증하고 resource integrity 검증 성공 |
| `--upstream-dir DIR` | 없음 | Strict candidate 검증 실패: 비교에 필요한 manifest field 누락 |
| `--upstream-dir DIR` | malformed | 형식 오류로 실패 |
| `--upstream-dir DIR` | valid, match | 실제 `DIR/Cargo.lock` SHA-256 일치 성공 |
| `--upstream-dir DIR` | valid, mismatch | Provenance mismatch로 실패하고 manifest/actual 값을 구분 출력 |

`--upstream-dir`이 제공되면 directory와 root `Cargo.lock` 존재를 각각 확인한다. Git repository 여부나 checkout HEAD 검증은 `sync-rhwp-studio.sh`가 이미 tag/commit 계약으로 담당하므로 asset verifier는 파일 provenance 비교에만 집중한다.

### Mutation boundary

- `verify-rhwp-studio-assets.sh`와 fixture는 tracked resource/manifest를 수정하지 않는다.
- `sync-rhwp-studio.sh`만 manifest writer다. 기록 직후 같은 upstream directory를 verifier에 전달해 writer output을 self-check한다.
- General PR CI, app bundle, rehearsal/publish는 target checkout이 없으므로 기존 resource-only verifier를 유지한다.
- `rhwp Upstream Sync PR` candidate 생성은 target checkout이 있으므로 strict verifier를 명시 실행한다.

### Failure taxonomy

- `manifest source_cargo_lock_sha256 must be a lowercase sha256 hex string`
- `missing upstream directory: <path>`
- `missing upstream root Cargo.lock: <path>`
- `manifest missing source_cargo_lock_sha256 required for upstream comparison`
- `manifest source_cargo_lock_sha256 does not match upstream root Cargo.lock`

Mismatch 진단에는 resource manifest 값, 실제 upstream 값, 비교한 `Cargo.lock` path를 함께 출력한다.

## Stage 1 — 현행 provenance 경로 조사와 계약 확정

### 산출물

- `mydocs/working/task_m040_375_stage1.md`
- `mydocs/orders/20260813.md` 상태 비고

### 작업

1. Task #370/PR #374의 writer/format-verifier 책임을 재확인한다.
2. Full sync workflow의 resolve/build/create job별 checkout lifecycle과 artifact 복원을 확인한다.
3. `sync-rhwp-studio.sh`, verifier, PR body helper, PR CI/classification 호출 graph를 기록한다.
4. 위 verifier mode, mutation boundary, failure taxonomy를 Stage 2~4 기준으로 확정한다.

### 검증

```bash
rg -n "source_cargo_lock_sha256|verify-rhwp-studio-assets|sync-rhwp-studio|upstream_dir" \
  scripts .github/workflows/rhwp-upstream-sync-pr.yml \
  mydocs/manual mydocs/tech/core_release_compatibility.md
git diff --check
```

### 커밋

`Task #375 Stage 1: Cargo.lock fingerprint 검증 경로 조사`

## Stage 2 — Verifier 실제 비교와 isolated fixture 구현

### 산출물

- `scripts/verify-rhwp-studio-assets.sh`
- `scripts/sync-rhwp-studio.sh`
- `scripts/ci/test-rhwp-studio-cargo-lock-verification.sh`
- `mydocs/working/task_m040_375_stage2.md`
- `mydocs/orders/20260813.md` 상태 비고

### 작업

1. Verifier에 optional `--upstream-dir DIR` interface와 help를 추가한다.
2. Resource-only optional field 호환과 strict candidate field 필수 조건을 분리한다.
3. Upstream directory/Cargo.lock 존재, format, actual hash match를 순서대로 검증한다.
4. Mismatch에 manifest/actual/path 진단을 출력한다.
5. Sync writer의 최종 verifier 호출에 같은 `UPSTREAM_DIR`을 전달한다.
6. 최소 resource/upstream fixture로 정상·오류·interface case와 production 무손실을 검증한다.

### 검증

```bash
bash -n scripts/verify-rhwp-studio-assets.sh \
  scripts/sync-rhwp-studio.sh \
  scripts/ci/test-rhwp-studio-cargo-lock-verification.sh
shellcheck scripts/verify-rhwp-studio-assets.sh \
  scripts/sync-rhwp-studio.sh \
  scripts/ci/test-rhwp-studio-cargo-lock-verification.sh
scripts/verify-rhwp-studio-assets.sh --help
scripts/ci/test-rhwp-studio-cargo-lock-verification.sh
scripts/verify-rhwp-studio-assets.sh
git diff --check
```

### 수용 기준

- Legacy missing field는 resource-only mode에서 성공한다.
- Strict mode의 match는 성공하고 mismatch/field 누락/Cargo.lock 누락/malformed는 구분된 메시지로 실패한다.
- Production bundled resource는 변경되지 않고 기본 verifier가 통과한다.

### 커밋

`Task #375 Stage 2: upstream Cargo.lock fingerprint 실제 비교 구현`

## Stage 3 — Sync workflow와 generated PR body 연결

### 산출물

- `.github/workflows/pr-ci.yml`
- `.github/workflows/rhwp-upstream-sync-pr.yml`
- `scripts/ci/classify-pr-changes.sh`
- `scripts/ci/write-rhwp-full-sync-pr-body.sh`
- `scripts/ci/write-rhwp-studio-sync-pr-body.sh`
- `mydocs/working/task_m040_375_stage3.md`
- `mydocs/orders/20260813.md` 상태 비고

### 작업

1. PR CI Ubuntu script-checks와 upstream sync preflight에서 신규 fixture를 실행한다.
2. Full sync candidate의 explicit verifier에 restored target `upstream_dir`을 전달한다.
3. Workflow verification summary에 strict comparison command/result를 기록한다.
4. Full/studio PR body의 수동 hash equality checkbox를 자동 verifier 결과 확인 기준으로 바꾼다.
5. 신규 fixture 변경이 macOS/Rust/release gate를 skip하지 않도록 classification을 보강한다.

### 검증

```bash
bash -n scripts/ci/classify-pr-changes.sh \
  scripts/ci/write-rhwp-full-sync-pr-body.sh \
  scripts/ci/write-rhwp-studio-sync-pr-body.sh
ruby -e 'require "psych"; Dir[".github/workflows/*.yml"].sort.each { |path| Psych.parse_file(path) }'
actionlint .github/workflows/pr-ci.yml .github/workflows/rhwp-upstream-sync-pr.yml
scripts/ci/test-rhwp-studio-cargo-lock-verification.sh
# Temporary fixture inputs로 full/studio PR body 생성
scripts/validate-github-body.sh <generated-full-body>
scripts/validate-github-body.sh <generated-studio-body>
# HEAD^..HEAD 또는 임시 commit pair로 classification flag assertion
git diff --check
```

### 수용 기준

- Workflow가 `--upstream-dir` strict 비교 실패 시 candidate PR 생성 전에 중단한다.
- Verification summary/body는 automatic match result를 포함한다.
- Maintainer checklist가 수동 hash 재계산을 요구하지 않는다.

### 커밋

`Task #375 Stage 3: upstream sync provenance gate 연결`

## Stage 4 — 운영 문서 정렬과 통합 검증

### 산출물

- `mydocs/manual/build_run_guide.md`
- `mydocs/manual/core_dependency_operation_guide.md`
- `mydocs/manual/ci_workflow_guide.md`
- `mydocs/tech/core_release_compatibility.md` 필요 구간
- `mydocs/working/task_m040_375_stage4.md`
- `mydocs/orders/20260813.md` 상태 비고

### 작업

1. Resource-only compatibility와 `--upstream-dir` strict candidate 검증 명령을 문서화한다.
2. Manual reviewer checklist 문구를 automatic gate + maintainer provenance review 경계로 바꾼다.
3. Failure taxonomy와 `RustBridge/Cargo.lock`과의 책임 차이를 정렬한다.
4. 전체 shell/workflow/body/classification/production no-mutation 검증을 재실행한다.

### 통합 검증

```bash
for script in scripts/*.sh scripts/ci/*.sh; do bash -n "$script"; done
shellcheck scripts/verify-rhwp-studio-assets.sh \
  scripts/sync-rhwp-studio.sh \
  scripts/ci/test-rhwp-studio-cargo-lock-verification.sh \
  scripts/ci/classify-pr-changes.sh \
  scripts/ci/write-rhwp-full-sync-pr-body.sh \
  scripts/ci/write-rhwp-studio-sync-pr-body.sh
scripts/ci/test-rhwp-core-build-info.sh
scripts/ci/test-rhwp-studio-cargo-lock-verification.sh
./scripts/verify-rhwp-core-build-info.sh
./scripts/verify-rhwp-studio-assets.sh
./scripts/check-no-appkit.sh
ruby -e 'require "psych"; Dir[".github/workflows/*.yml"].sort.each { |path| Psych.parse_file(path) }'
actionlint
git diff --check
```

### 수용 기준

- Issue #375의 목표·범위 항목이 각각 code/test/workflow/body/doc 증거로 충족된다.
- `rhwp-core.lock`, bundled `rhwp-studio` asset/manifest, RustBridge source/artifact는 변경하지 않는다.
- 기존 PR #463, automation branch, workflow run과 public release 상태는 변경하지 않는다.

### 커밋

`Task #375 Stage 4: Cargo.lock provenance 운영 문서와 통합 검증 완료`

## 최종 보고와 PR

모든 Stage 보고서 커밋 뒤 `task-final-report` 절차로 다음을 수행한다.

1. 통합 검증 재확인
2. `mydocs/report/task_m040_375_report.md` 작성
3. 오늘할일 #375를 `완료`와 `완료: HH:mm`으로 갱신
4. 최종 보고 커밋
5. `local/task375:publish/task375` push
6. `devel` 대상 Open PR 생성

PR 본문은 Stage 보고서/commit과 수행·구현·최종 문서를 immutable head SHA URL로 연결하고, 검증 결과와 #463 정리 → upstream sync 재실행 handoff를 명시한다.

## 변경 금지 경계

- `Sources/HostApp/Resources/rhwp-studio/**`
- `RustBridge/**`, `Frameworks/**`, `rhwp-core.lock`, `RhwpCoreBuildInfo.swift`
- PR #463과 `automation/rhwp-v0.8.4-full-sync` 상태
- Release rehearsal/publish, GitHub Release, Pages/Sparkle, Homebrew Cask

## 승인 근거

작업지시자가 Issue #375 작업과 PR 생성까지 명시했다. 본 구현계획은 수행계획 범위를 구체화하며, 별도 외부 상태 변경은 `publish/task375` push와 Task #375 PR 생성까지만 수행한다.
