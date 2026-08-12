# Task #375 Stage 3 완료보고서

## 단계 목적

Stage 2의 upstream `Cargo.lock` actual hash 비교를 PR CI와 upstream full sync candidate 생성 경로에 연결하고, generated full/studio PR body와 path classification을 automatic provenance gate 기준으로 정렬했다.

## 산출물

| 파일 | 변경 | 요약 |
|------|------|------|
| `.github/workflows/pr-ci.yml` | 수정 | Ubuntu script-checks에서 studio Cargo.lock fixture 실행 |
| `.github/workflows/rhwp-upstream-sync-pr.yml` | 수정 | Preflight fixture, candidate strict verifier와 verification summary 연결 |
| `scripts/ci/classify-pr-changes.sh` | 수정 | 신규 fixture에 macOS/Rust/release gate 활성화 |
| `scripts/ci/write-rhwp-full-sync-pr-body.sh` | 수정 | Automatic fingerprint comparison scope/checklist 반영 |
| `scripts/ci/write-rhwp-studio-sync-pr-body.sh` | 수정 | 수동 hash 대조를 automatic verifier 결과 확인으로 변경 |
| `mydocs/working/task_m040_375_stage3.md` | 신규 | Workflow/body/classification 검증 기록 |
| `mydocs/orders/20260813.md` | 수정 | #375를 Stage 3 완료, Stage 4 진행 상태로 갱신 |

## 변경 내용

### PR CI 조기 fixture gate

Ubuntu `script-checks`는 core build-info fixture 뒤에 다음 단계를 실행한다.

```yaml
- name: Check studio Cargo.lock verification fixtures
  run: scripts/ci/test-rhwp-studio-cargo-lock-verification.sh
```

순수 shell/minimal fixture이므로 macOS Rust build 전 수 초 내에 compatibility/strict contract 회귀를 차단한다. 기존 macOS bundled resource verifier는 checkout 없는 resource-only integrity gate로 유지한다.

### Upstream sync preflight와 candidate strict verification

`resolve-target` helper preflight에 신규 fixture의 `bash -n`과 실제 실행을 추가했다. 따라서 workflow가 target build를 시작하기 전에 verifier contract 자체를 확인한다.

`create-full-sync-pr` job은 restored target checkout의 `upstream_dir`을 explicit verifier에 전달한다.

```text
scripts/verify-rhwp-studio-assets.sh \
  --tag <target-tag> \
  --commit <target-commit> \
  --upstream-dir <restored-target-checkout>
```

Sync writer self-check와 candidate explicit verifier가 모두 strict comparison을 수행한다. Verification file과 Actions summary에는 다음 의미를 고정했다.

```text
Cargo.lock fingerprint match OK
```

Mismatch가 발생하면 `git diff --check`, stage, commit, branch push와 PR 생성 전에 job이 중단된다.

### Generated PR body

Full sync scope는 manifest가 fingerprint를 기록할 뿐 아니라 workflow verifier가 target checkout과 자동 비교한다고 설명한다. Maintainer checklist는 다음 automatic result 확인으로 바뀌었다.

```text
automatic bundled studio verifier reports that source_cargo_lock_sha256
matches the target upstream root Cargo.lock
```

Studio helper의 한국어 checklist도 같은 책임으로 정렬했다. 작업자가 SHA-256을 수동 재계산하는 것은 필수 checklist가 아니며, target release/source identity와 자동 check 결과를 검토한다.

### Path classification

신규 fixture는 `scripts/ci/**` 공통 release 분류에 더해 별도 provenance case를 갖는다.

```text
run_macos_build=true
run_rust_verify=true
run_release_checks=true
```

분류 사유는 build-info가 아니라 `bundled studio Cargo.lock provenance verification`, `bundled studio/core provenance verification`으로 표시해 진단 의미를 맞췄다.

## 본문 변경 정도 / 본문 무손실 여부

Workflow, classifier와 generated PR body 문구만 변경했다. `Sources/**`, `RustBridge/**`, `Frameworks/**`, `rhwp-core.lock`, production bundled `rhwp-studio` asset/manifest는 변경하지 않았다. Generated body fixture는 `build.noindex/`에만 만들었다.

## 검증 결과

```text
$ bash -n <classifier/full body/studio body/verifier/sync/fixture>
통과

$ shellcheck -e SC2129 <Stage 2~3 관련 helper>
통과
SC2129는 기존 body writer의 반복 append style에 대한 기존 제외다.

$ ruby -e 'require "psych"; Dir[".github/workflows/*.yml"].sort.each { |path| Psych.parse_file(path) }'
전체 6개 workflow parse 통과

$ actionlint .github/workflows/pr-ci.yml .github/workflows/rhwp-upstream-sync-pr.yml
통과

$ scripts/ci/test-rhwp-studio-cargo-lock-verification.sh
OK: rhwp-studio Cargo.lock fingerprint verification fixtures passed

$ scripts/ci/classify-pr-changes.sh HEAD^ HEAD
run_macos_build=true
run_rust_verify=true
run_release_checks=true

$ scripts/validate-github-body.sh build.noindex/task375-stage3-full-body.md
통과

$ scripts/validate-github-body.sh build.noindex/task375-stage3-studio-body.md
통과

$ rg -n "automatic bundled studio verifier|자동 bundled studio verifier|Cargo.lock fingerprint match OK" <generated bodies>
Full/studio verification과 automatic checklist 문구 확인

$ git diff --check
통과
```

## 잔여 위험

- Actual remote upstream release와 GitHub-hosted workflow execution은 Task #375 PR merge 뒤 default branch workflow에서 최종 확인해야 한다.
- PR CI는 target checkout을 보유하지 않으므로 candidate manifest의 actual hash를 재계산하지 않는다. Candidate 생성 workflow의 strict verifier와 isolated fixture가 이 계약의 진실 원천이다.
- Studio body helper는 현재 full sync workflow에서 직접 사용되지 않지만 별도 studio sync 재사용을 위해 동일 automatic gate 문구를 유지한다.

## 다음 단계 영향

Stage 4에서는 build/core/CI/compatibility 문서를 strict/compatibility mode와 automatic gate 기준으로 갱신한다. 그 뒤 전체 shell, fixture, production verifier, workflow, body, classification no-mutation 통합 검증을 실행한다.

## 승인 요청

작업지시자가 PR 생성까지 진행하도록 승인한 범위에 따라 Stage 4 — 운영 문서 정렬과 통합 검증으로 진행한다.
