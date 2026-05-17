# Task M019 #204 최종 결과보고서

## 작업 요약

- 이슈: [#204 rhwp upstream release 감지와 rhwp-studio 자동 업데이트 PR 생성 파이프라인 추가](https://github.com/postmelee/alhangeul-macos/issues/204)
- 마일스톤: M019 (`v0.1.2`)
- 브랜치: `local/task204`
- 기준 브랜치: `devel`
- 단계 수: 6단계

upstream `edwardkim/rhwp` release를 감지하고, viewer/WASM/core 영향 변경이 있을 때 bundled `rhwp-studio` 업데이트 후보 PR을 자동 생성하는 파이프라인을 추가했다. 자동 PR base는 `devel`이며, public release, signed/notarized DMG, Sparkle appcast, Homebrew Cask 배포는 실행하지 않는다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `.github/workflows/rhwp-upstream-sync-pr.yml` | upstream release 조회, impact detection, 중복 PR 방지, build/sync, automation branch push, PR 생성 workflow 추가 |
| `.github/workflows/pr-ci.yml` | 신규 helper interface 검사와 bundled `rhwp-studio` asset 검증 추가 |
| `scripts/ci/detect-rhwp-studio-impact.sh` | upstream current..target diff에서 viewer/WASM/core 영향 path 판정 |
| `scripts/ci/write-rhwp-studio-sync-pr-body.sh` | 자동 sync PR body 생성 |
| `scripts/ci/classify-pr-changes.sh` | bundled `rhwp-studio` 변경 시 macOS/Rust/release checks flag 명시 |
| `scripts/ci/check-rhwp-upstream-release.sh` | 직접 실행 가능한 helper mode로 보정 |
| `scripts/sync-rhwp-studio.sh` | target tag/commit 인자, `--check`, target dir, manifest provenance 기록 보강 |
| `scripts/verify-rhwp-studio-assets.sh` | resource dir/tag/commit 인자와 manifest 기본값 지원 |
| `mydocs/manual/ci_workflow_guide.md` | upstream sync PR workflow, PR CI flag, 로컬 재현, 실패 해석 기준 문서화 |
| `mydocs/manual/core_dependency_operation_guide.md` | `v0.7.11` pin 기준과 sync PR/core lock 경계 문서화 |
| `mydocs/manual/release_distribution_guide.md` | sync PR은 public release가 아니라는 release 경계와 자산 목록 보강 |
| `mydocs/orders/20260517.md` | #204 진행/완료 상태 관리 |
| `mydocs/plans/task_m019_204.md` | 수행계획서 |
| `mydocs/plans/task_m019_204_impl.md` | 구현계획서 |
| `mydocs/working/task_m019_204_stage1.md` | 자동화 정책 확정 보고 |
| `mydocs/working/task_m019_204_stage2.md` | impact helper 추가 보고 |
| `mydocs/working/task_m019_204_stage3.md` | sync/verify script 인자화 보고 |
| `mydocs/working/task_m019_204_stage4.md` | sync PR workflow 추가 보고 |
| `mydocs/working/task_m019_204_stage5.md` | PR CI/운영 문서 갱신 보고 |
| `mydocs/working/task_m019_204_stage6.md` | 통합 검증과 잔여 확인 시점 보고 |
| `mydocs/report/task_m019_204_report.md` | 최종 결과보고서 |

## 단계별 결과

| 단계 | 커밋 | 내용 |
|------|------|------|
| 수행계획 | `2552f3f` | 수행 계획서 작성과 오늘할일 갱신 |
| 구현계획 | `e44fde3` | 구현 계획서 작성 |
| Stage 1 | `22c5e3a` | base `devel`, workflow 분리, 권한 경계, 중복 PR 방지 정책 확정 |
| Stage 2 | `e074fa6` | upstream viewer/WASM/core 영향 변경 감지 helper 추가 |
| Stage 3 | `45b95b6` | `sync-rhwp-studio.sh`, `verify-rhwp-studio-assets.sh` 인자화와 `--check` 추가 |
| Stage 4 | `f6c21cb` | `rhwp Upstream Sync PR` workflow와 PR body helper 추가 |
| Stage 5 | `dc7824b` | PR CI 분류, bundled asset 검증, 운영 매뉴얼 보강 |
| Stage 6 | 본 커밋 | 통합 검증, helper 실행 권한 보정, 최종 보고서 작성 |

## 구현 요약

### read-only check와 write-capable sync 분리

기존 `rhwp Upstream Release Check`는 read-only 감시 workflow로 유지했다. 신규 `rhwp Upstream Sync PR`는 PR 생성을 위해 별도 workflow로 추가하고, 필요한 권한을 `contents: write`, `pull-requests: write`, `issues: write`로 제한했다.

### impact detection

`scripts/ci/detect-rhwp-studio-impact.sh`는 current bundled release commit부터 target upstream release commit까지의 변경 파일을 분류한다. 영향 path는 `rhwp-studio/**`, `pkg/**`, Rust/core source와 Cargo/toolchain 입력, web build 입력, font/license/provenance 파일을 포함한다.

### sync/verify 인자화

`scripts/sync-rhwp-studio.sh`는 upstream checkout, target tag, resolved commit, target directory를 인자로 받는다. `--check`는 임시 복사본에서 동기화와 검증만 수행해 실제 bundled resource를 바꾸지 않는다.

`scripts/verify-rhwp-studio-assets.sh`는 manifest의 `source_release_tag`, `source_resolved_commit`을 기본 기대값으로 읽고, 필요 시 `--tag`, `--commit`, `--resource-dir`로 override한다.

### 자동 PR workflow

workflow 상태 분기:

1. current bundled `rhwp-studio` manifest tag/commit을 읽는다.
2. 입력 `target_tag` 또는 upstream latest release를 target으로 정한다.
3. target tag를 resolved commit으로 해석한다.
4. current와 target이 같으면 `current` 상태로 종료한다.
5. upstream checkout에서 impact helper를 실행한다.
6. impact가 없고 `force_pr=false`이면 `no viewer impact` 상태로 종료한다.
7. 같은 automation branch 또는 open PR이 있으면 중복 생성하지 않는다.
8. `dry_run=true`이면 build, push, PR 생성 없이 종료한다.
9. `scripts/update-rhwp-core.sh --check --channel stable --tag <tag>`로 compatibility를 조회한다.
10. upstream WASM과 `rhwp-studio` dist를 build한다.
11. bundled asset을 sync하고 PR body를 생성한다.
12. `automation/rhwp-<tag>-studio-sync` branch를 push하고 `devel` 대상 PR을 생성한다.

자동 PR body에는 `Automation source: #204`만 기록하고 close keyword는 넣지 않는다. 향후 자동 update PR이 파이프라인 구축 이슈인 #204를 닫지 않게 하기 위한 경계다.

## 검증 결과

| 수용 기준 | 결과 |
|-----------|------|
| 자동 PR base가 `devel`임 | OK |
| `devel-webview`를 신규 base나 자동화 기준으로 쓰지 않음 | OK |
| upstream target이 current와 같으면 PR을 만들지 않는 분기 존재 | OK |
| viewer/WASM/core 영향 변경이 없으면 기본적으로 PR을 만들지 않는 분기 존재 | OK |
| `force_pr`, `dry_run`, 기존 branch/PR 중복 방지 존재 | OK |
| bundled `rhwp-studio` sync가 target tag/commit provenance를 기록 | OK |
| PR CI가 자동 sync PR 변경 범위에 필요한 gate를 켬 | OK |
| public release와 자동 sync PR 경계 문서화 | OK |

주요 실행 명령:

```bash
git status --short --branch
ruby -e 'require "psych"; Dir[".github/workflows/*.yml"].sort.each { |path| Psych.parse_file(path); puts "Parsed #{path}" }'
actionlint
bash -n scripts/*.sh scripts/ci/*.sh
scripts/ci/check-rhwp-upstream-release.sh --help
scripts/ci/detect-rhwp-studio-impact.sh --help
scripts/ci/write-rhwp-studio-sync-pr-body.sh --help
scripts/sync-rhwp-studio.sh --help
scripts/verify-rhwp-studio-assets.sh --help
scripts/verify-rhwp-studio-assets.sh
scripts/ci/detect-rhwp-studio-impact.sh --upstream-dir . --current-tag v0.7.11 --current-commit HEAD --target-tag v0.7.11 --target-commit HEAD --output-dir build.noindex/task204-stage6-impact
scripts/ci/classify-pr-changes.sh devel HEAD
gh release view -R edwardkim/rhwp --json tagName,url,targetCommitish
scripts/ci/check-rhwp-upstream-release.sh --run-compatibility-check false
git diff --check
```

주요 결과:

- workflow YAML parse 통과.
- `actionlint` 통과.
- shell syntax 통과.
- helper `--help` 통과.
- bundled `rhwp-studio` asset 검증 통과.
- impact helper no-change dry-run 결과 `has_viewer_impact=false`.
- PR CI classification 결과 `run_macos_build=true`, `run_rust_verify=true`, `run_release_checks=true`.
- upstream latest release는 `v0.7.11`, 현재 `rhwp-core.lock`도 `v0.7.11`로 `outdated=false`.
- `git diff --check` 통과.

## #214와 #204 잔여 검증 시점

### #214

#214의 잔여 항목은 실제 Pages deployment다.

- PR merge 후: `devel` 대상 PR CI에서 workflow YAML parse와 release checks 성공 여부를 확인한다.
- `main` 반영 후: `main`의 `docs/**` push 또는 `Docs-only Pages Deploy` 수동 실행으로 `actions/upload-pages-artifact@v5`, `actions/deploy-pages@v5`, `pages-deploy` concurrency queueing을 확인한다.
- 확인 기준: workflow summary의 public appcast source, Pages artifact 검증, deployment URL, public `https://postmelee.github.io/alhangeul-macos/appcast.xml` 보존 여부.

### #204

#204의 잔여 항목은 write-capable sync PR workflow의 repository 권한과 실제 upstream build다.

- PR merge 후: `devel` 대상 PR CI에서 helper interface, macOS validation, Rust verify, release checks가 성공하는지 확인한다.
- default branch 반영 후: `rhwp Upstream Sync PR` 수동 `dry_run=true` 실행으로 target 조회, impact detection, 기존 branch/PR 확인, concurrency summary를 확인한다.
- target release 발생 또는 명시 실행 시: `dry_run=false`로 `automation/rhwp-<tag>-studio-sync` branch push, `gh pr create`, assignee/reviewer 지정, upstream Docker/npm/Vite build 성공 여부를 확인한다.

정리하면 #214는 `main`에서 Pages deployment가 실제로 도는 시점, #204는 default branch 반영 후 workflow dispatch와 새 upstream target이 있는 시점에 최종 확인한다.

## 잔여 위험

- `rhwp Upstream Sync PR`의 branch push, PR 생성, assignee/reviewer 지정은 로컬에서 재현하지 못했다.
- schedule workflow 활성화와 concurrency queueing은 default branch 반영 후 GitHub-hosted runner에서 확인해야 한다.
- upstream 실제 build는 Docker, npm, TypeScript, Vite에 의존한다. target release가 생긴 뒤 GitHub-hosted runner에서 시간 제한과 dependency 변동을 확인해야 한다.
- 자동 sync PR은 bundled `rhwp-studio` 후보를 생성한다. public release는 여전히 별도 승인과 protected release workflow가 필요하다.

## PR close 전략

PR 본문에는 다음을 명시한다.

```text
Closes #204
```

향후 자동 생성되는 bundled `rhwp-studio` update PR은 `Automation source: #204`만 포함하고 #204를 close하지 않는다.

## 다음 절차

최종 결과보고서를 승인하면 `publish/task204` 원격 브랜치 push와 `devel` 대상 Open PR 생성 절차로 진행한다.
