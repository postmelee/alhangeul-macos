# Task M040 #376 최종 결과보고서

## 개요

- GitHub Issue: #376
- 마일스톤: M040 (`v0.4`)
- 브랜치: `local/task376`
- 기준 브랜치: `devel`
- 작업 범위: `rhwp Upstream Sync PR` workflow의 base branch 기준 current 판정과 automation branch blocker 구분 보강

## 최종 결과

`rhwp Upstream Sync PR` workflow가 upstream sync 필요 여부를 `BASE_BRANCH=devel` content 기준으로 판단하도록 수정했다. schedule workflow file은 GitHub default branch에서 실행될 수 있지만, 실제 current 판정에 쓰는 `rhwp-core.lock`과 bundled `rhwp-studio` manifest는 base branch checkout에서 읽는다.

또한 existing automation branch 확인 로직을 열린 PR, branch-only, merge 완료 PR head branch 잔존 상태로 구분했다. 열린 PR과 branch-only 상태는 계속 중복 PR 생성 blocker로 유지하고, merge 완료 PR의 head branch가 남은 경우는 blocker가 아니라 cleanup 후보로 표시한다.

## 변경 파일

| 파일 | 변경 |
|------|------|
| `.github/workflows/rhwp-upstream-sync-pr.yml` | checkout 기준을 `env.BASE_BRANCH`로 변경, workflow event ref와 repository content ref summary 추가, existing branch/PR blocker 세분화 |
| `mydocs/manual/ci_workflow_guide.md` | upstream sync workflow의 base branch current 판정, branch-only blocker, merged branch cleanup 후보 기준 문서화 |
| `mydocs/manual/core_dependency_operation_guide.md` | full sync 후보 PR의 `devel` 기준 provenance 판정과 cleanup 경계 보강 |
| `mydocs/working/task_m040_376_stage1.md` | 현행 run과 설계 결정 기록 |
| `mydocs/working/task_m040_376_stage2.md` | base branch checkout 적용 결과 기록 |
| `mydocs/working/task_m040_376_stage3.md` | merged automation branch blocker 구분 결과 기록 |
| `mydocs/report/task_m040_376_report.md` | 최종 결과보고서 |
| `mydocs/orders/20260624.md` | 오늘할일 완료 처리 |

## 단계별 요약

### Stage 1

최신 schedule run `28075879933`이 `main` 기준 `v0.7.16`을 읽어 `CURRENT=false`, `EXISTING=true`로 판단한 사실을 확인했다. 같은 시점 `origin/devel`은 core/studio 모두 `v0.7.17`이므로, base branch 기준이면 current가 true가 되어야 한다는 설계를 확정했다.

### Stage 2

`resolve-target`, `build-studio-assets`, `create-full-sync-pr` job의 repository checkout을 `github.ref`에서 `env.BASE_BRANCH`로 바꿨다. workflow summary에는 `repository content ref`와 `workflow event ref`를 나누어 표시하도록 했다.

### Stage 3

existing automation check를 `open_pr_url`, `merged_pr_url`, `branch_only`, `cleanup_candidate`, `blocker_reason`으로 세분화했다. 현재 남아 있는 `automation/rhwp-v0.7.17-full-sync`는 open PR이 없고 merge 완료 PR #369가 있으므로 cleanup 후보로 분류되는 상태다.

### Stage 4

CI/core 운영 문서에 새 기준을 반영하고 최종 검증을 수행했다.

## 검증 결과

```text
$ git status --short --branch
## local/task376
 M mydocs/manual/ci_workflow_guide.md
 M mydocs/manual/core_dependency_operation_guide.md
```

위 상태는 최종 보고서 작성 전 문서 변경만 남은 시점의 상태다.

```text
$ git diff --check
```

출력 없음. 통과.

```text
$ ruby -e 'require "psych"; Psych.parse_file(".github/workflows/rhwp-upstream-sync-pr.yml")'
Ignoring ffi-1.13.1 because its extensions are not built. Try: gem pristine ffi --version 1.13.1
```

exit code 0. YAML parse는 통과했다. `ffi` 경고는 로컬 Ruby gem 환경 경고다.

```text
$ bash -n scripts/ci/check-rhwp-upstream-release.sh scripts/ci/detect-rhwp-studio-impact.sh scripts/ci/read-rhwp-core-lock.sh scripts/ci/write-rhwp-full-sync-pr-body.sh
```

출력 없음. 통과.

```text
$ scripts/ci/detect-rhwp-studio-impact.sh --help
$ scripts/ci/read-rhwp-core-lock.sh --help
$ scripts/ci/write-rhwp-full-sync-pr-body.sh --help
```

세 helper 모두 usage 출력을 반환하고 exit code 0으로 완료했다.

```text
$ rg -n "BASE_BRANCH|current_core_tag|current_studio_tag|existing_automation_pr|automation/rhwp|rhwp Upstream Sync PR|base branch" .github/workflows/rhwp-upstream-sync-pr.yml mydocs/manual
```

workflow와 운영 문서에서 base branch current 판정, automation branch, existing blocker 관련 항목이 확인됐다.

## 남은 운영 확인

- GitHub-hosted schedule 동작은 로컬에서 완전 재현할 수 없다. 이 변경이 `devel`에 merge된 뒤 첫 `rhwp Upstream Sync PR` schedule run에서 `repository content ref`가 `devel`로 표시되고, `v0.7.17` 기준 current 판정이 기대대로 정리되는지 확인해야 한다.
- 현재 원격에는 `automation/rhwp-v0.7.16-full-sync`, `automation/rhwp-v0.7.17-full-sync` branch가 남아 있다. 둘 다 merge 완료 PR의 head branch이므로 cleanup 후보지만, 원격 branch 삭제는 destructive 작업이므로 별도 승인 또는 merge 후 cleanup 절차에서 수행해야 한다.
- 이번 작업은 public release publish, signing/notarization, Pages/Sparkle, Homebrew 작업을 실행하지 않았다.

## PR 전 확인 사항

- PR base는 `devel`이다.
- PR body에는 #376을 해결하는 내부 workflow 수정이며 public release 작업이 아님을 명시한다.
- PR merge 후 schedule run 확인과 automation branch cleanup 승인 여부를 후속 운영 항목으로 남긴다.

## 결론

#376의 핵심 문제였던 `main` checkout 기준 stale current 판정과 merge 완료 automation branch blocker 오판을 workflow와 문서에서 보강했다. 최종 검증은 통과했으며, 다음 단계는 작업지시자 승인 후 `publish/task376` push와 `devel` 대상 PR 생성이다.
