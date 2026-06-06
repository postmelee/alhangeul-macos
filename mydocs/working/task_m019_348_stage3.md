# Task M019 #348 Stage 3 완료 보고서

## 단계 목적

Stage 2에서 확정한 full sync 설계를 실제 workflow/helper/운영 문서에 반영한다. 이번 단계는 로컬 정적 검증까지 수행하고, 원격 `dry_run=true`/실행 검증은 Stage 4 이후로 남긴다.

## 확인 시각

- 2026-06-07 03:10 KST

## 구현 요약

| 파일 | 변경 |
|------|------|
| `.github/workflows/rhwp-upstream-sync-pr.yml` | studio-only 단일 Ubuntu job을 `resolve-target`, `build-studio-assets`, `create-full-sync-pr` split job 구조로 교체 |
| `.github/workflows/pr-ci.yml` | 새 helper와 `read-rhwp-core-lock.sh --help` interface 검증 추가 |
| `scripts/ci/write-rhwp-full-sync-pr-body.sh` | core/studio provenance를 함께 표시하는 full sync PR body helper 신규 추가 |
| `scripts/ci/read-rhwp-core-lock.sh` | `--help` 지원과 executable bit 정렬 |
| `mydocs/manual/ci_workflow_guide.md` | full sync workflow, GitHub App token, dry-run/PR 생성 경계 문서화 |
| `mydocs/manual/core_dependency_operation_guide.md` | 현재 core 기준을 `v0.7.13`으로 보정하고 full sync 자동화 경계 반영 |
| `mydocs/manual/release_distribution_guide.md` | full sync workflow와 PR body helper 설명 반영 |
| `mydocs/plans/task_m019_348.md` | Stage 3 실제 helper명과 GitHub App token variable명 보정 |
| `mydocs/working/task_m019_348_stage2.md` | Stage 3 구현 중 확인한 `client-id` 기준으로 token variable명 보정 |
| `mydocs/orders/20260607.md` | Stage 3 완료보고서 승인 대기 상태 반영 |

## workflow 변경 상세

`rhwp Upstream Sync PR` workflow는 다음 job으로 분리했다.

| job | runner | 역할 |
|-----|--------|------|
| `resolve-target` | `ubuntu-latest` | current core/studio provenance와 target release 해석, upstream impact 분석, 기존 automation branch/PR 확인, dry-run decision |
| `build-studio-assets` | `ubuntu-latest` | target upstream checkout, `update-rhwp-core.sh --check`, Docker WASM build, `rhwp-studio` Vite build, artifact upload |
| `create-full-sync-pr` | `macos-15` | GitHub App token 검증/발급, upstream checkout 복원, studio build artifact download, core update, RustBridge artifact metadata update, bundled studio sync, PR body 생성, app token push/PR 생성 |

current 판정은 다음 네 값이 모두 target과 일치할 때만 true다.

- `rhwp-core.lock`의 `rhwp_release_tag`
- `rhwp-core.lock`의 `rhwp_commit`
- bundled `rhwp-studio/manifest.json`의 `source_release_tag`
- bundled `rhwp-studio/manifest.json`의 `source_resolved_commit`

workflow 권한은 read 중심으로 낮췄다. 자동 branch push와 PR 생성은 `actions/create-github-app-token@v3.2.0`에서 발급한 GitHub App installation token으로만 수행한다.

필요 repository 설정은 다음으로 고정했다.

| 이름 | 위치 | 목적 |
|------|------|------|
| `ALHANGEUL_AUTOMATION_CLIENT_ID` | repository variable | GitHub App Client ID |
| `ALHANGEUL_AUTOMATION_APP_PRIVATE_KEY` | repository secret | GitHub App private key |

Stage 2에서는 `APP_ID`를 후보로 적었지만, `actions/create-github-app-token@v3.2.0`의 action metadata에서 `app-id`가 deprecated이고 `client-id`가 권장 입력임을 확인해 Stage 3 구현 기준을 `CLIENT_ID`로 보정했다.

## full sync PR body

신규 helper `scripts/ci/write-rhwp-full-sync-pr-body.sh`는 자동 PR에 다음 정보를 기록한다.

- previous core tag/commit
- previous studio tag/commit
- target tag/commit/release URL
- upstream changed paths
- viewer/WASM/core impact paths
- repository changed paths
- verification command 결과
- maintainer checklist
- public release가 자동 실행되지 않는 release boundary

기존 `scripts/ci/write-rhwp-studio-sync-pr-body.sh`는 삭제하지 않았다. 과거 기록과 helper interface 검증 호환성을 위해 유지하고, 새 workflow는 full sync helper만 사용한다.

## 로컬 검증

다음 검증을 수행했다.

```bash
git diff --check
ruby -e 'require "psych"; Dir[".github/workflows/*.yml"].sort.each { |path| Psych.parse_file(path); puts "Parsed #{path}" }'
actionlint .github/workflows/rhwp-upstream-sync-pr.yml .github/workflows/pr-ci.yml
for script in scripts/*.sh scripts/ci/*.sh; do bash -n "$script"; done
bash scripts/ci/classify-pr-changes.sh --help
bash scripts/ci/check-rhwp-upstream-release.sh --help
bash scripts/ci/detect-rhwp-studio-impact.sh --help
bash scripts/ci/read-rhwp-core-lock.sh --help
bash scripts/ci/write-rhwp-full-sync-pr-body.sh --help
bash scripts/ci/write-rhwp-studio-sync-pr-body.sh --help
scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.15
```

결과:

- workflow YAML parse 통과
- `actionlint` 통과
- shell syntax 통과
- helper interface 검증 통과
- full sync PR body helper 샘플 생성 확인
- `v0.7.15` core compatibility check 통과

`scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.15` 결과:

```text
Checked rhwp core target:
  channel: stable
  tag:     v0.7.15
  commit:  aa925a5954f0fd26dfcef2166cbce7877c481f44
```

Ruby workflow parse 중 기존 로컬 Ruby 환경의 `ffi-1.13.1` extension 경고가 출력됐지만 YAML parse 자체는 성공했다.

## 아직 수행하지 않은 검증

이번 Stage 3에서는 원격 workflow 실행을 하지 않았다. 다음 Stage 4에서 `publish/task348` 원격 ref를 만든 뒤 다음을 검증해야 한다.

- `dry_run=true` 수동 실행
- target/current/impact/decision summary 확인
- GitHub App token 미설정 시 실패 경계 또는 설정 완료 후 실제 build 진입 여부 확인

Stage 5에서는 token 설정을 완료한 뒤 `dry_run=false`로 자동 full sync PR 생성과 PR CI 자동 trigger까지 확인한다.

## 승인 요청 사항

Stage 3 보고서를 승인하면 Stage 4 `로컬/CI dry-run 검증`으로 진행한다.
