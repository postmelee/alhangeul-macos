# Task M040 #376 Stage 3 완료보고서

## 단계 목적

`rhwp Upstream Sync PR` workflow의 existing automation branch/PR 확인 로직을 보강해 열린 PR, branch-only 상태, merge 완료 PR head branch 잔존 상태를 구분했다. merge 완료 PR의 head branch가 원격에 남아 있는 경우는 새 sync PR 생성을 막는 blocker가 아니라 cleanup 후보로 표시하게 했다.

## 산출물

| 파일 | 요약 |
|------|------|
| `.github/workflows/rhwp-upstream-sync-pr.yml` | existing check output과 decision summary를 open/merged/branch-only/cleanup 상태로 세분화 |
| `mydocs/working/task_m040_376_stage3.md` | Stage 3 변경 내용과 검증 결과 기록 |

## 본문 변경 정도 / 본문 무손실 여부

- workflow YAML의 `Check existing automation PR` step과 `Decide full sync execution` summary만 변경했다.
- Stage 2에서 적용한 base branch checkout 구조는 유지했다.
- upstream checkout/build, PR 생성 token, sync script 실행, artifact 흐름은 변경하지 않았다.

## 변경 내용

### job output 세분화

`resolve-target` job output에 다음 값을 추가했다.

- `existing_open_pr_url`
- `existing_merged_pr_url`
- `existing_branch_only`
- `existing_cleanup_candidate`
- `existing_blocker_reason`

기존 `existing_pr_url`은 호환성을 위해 open PR URL을 가리키도록 유지했다.

### blocker 판단 matrix

| 상태 | workflow 판단 | 이유 |
|------|---------------|------|
| open PR 존재 | blocker | 이미 리뷰 가능한 sync 후보가 있으므로 중복 PR 생성 금지 |
| 원격 branch 존재, 관련 PR 없음 | blocker | branch push 후 PR 생성 전에 실패했을 수 있어 보수적으로 중복 생성 금지 |
| 원격 branch 존재, merged PR 존재, open PR 없음 | cleanup 후보 | 이미 merge된 후보의 head branch 잔존 상태이므로 새 PR blocker로 보지 않음 |
| branch 없음, PR 없음 | blocker 아님 | 새 sync PR 생성 가능 |

### summary 가시성 보강

`Existing full sync PR check` summary에 다음 항목을 추가했다.

```text
- merged PR: ...
- branch-only blocker: ...
- cleanup candidate: ...
- blocker reason: ...
```

`rhwp full sync decision` summary에는 `existing blocker reason`을 추가했다.

## 현재 원격 상태 확인

`automation/rhwp-v0.7.17-full-sync` 기준 read-only 조회:

```text
$ gh pr list --repo postmelee/alhangeul-macos --base devel --head automation/rhwp-v0.7.17-full-sync --state open --json url,state,mergedAt --jq '.[0] // {}'
{}
```

```text
$ gh pr list --repo postmelee/alhangeul-macos --base devel --head automation/rhwp-v0.7.17-full-sync --state merged --json url,state,mergedAt --jq '.[0] // {}'
{"mergedAt":"2026-06-23T17:50:02Z","state":"MERGED","url":"https://github.com/postmelee/alhangeul-macos/pull/369"}
```

따라서 현재 `v0.7.17` branch는 Stage 3 기준으로 cleanup 후보이며 open PR blocker가 아니다.

## 검증 결과

```text
$ ruby -e 'require "psych"; Psych.parse_file(".github/workflows/rhwp-upstream-sync-pr.yml")'
Ignoring ffi-1.13.1 because its extensions are not built. Try: gem pristine ffi --version 1.13.1
```

exit code 0. YAML parse는 통과했다. `ffi` 경고는 로컬 Ruby gem 환경 경고다.

```text
$ git diff --check
```

출력 없음. 통과.

```text
$ rg -n "open_pr|merged_pr|branch_exists|existing_automation_pr|branch_only|cleanup|blocker_reason|EXISTING_REASON" .github/workflows/rhwp-upstream-sync-pr.yml
62:      existing_branch: ${{ steps.existing.outputs.branch_exists }}
63:      existing_pr_url: ${{ steps.existing.outputs.open_pr_url }}
64:      existing_open_pr_url: ${{ steps.existing.outputs.open_pr_url }}
65:      existing_merged_pr_url: ${{ steps.existing.outputs.merged_pr_url }}
66:      existing_branch_only: ${{ steps.existing.outputs.branch_only }}
67:      existing_cleanup_candidate: ${{ steps.existing.outputs.cleanup_candidate }}
68:      existing_blocker_reason: ${{ steps.existing.outputs.blocker_reason }}
274:          open_pr_url="$(gh pr list \
282:          merged_pr_url="$(gh pr list \
291:          branch_only="false"
292:          cleanup_candidate="false"
293:          blocker_reason="none"
295:          if [ -n "$open_pr_url" ]; then
297:            blocker_reason="open_pr"
298:          elif [ "$branch_exists" = "true" ] && [ -z "$merged_pr_url" ]; then
300:            branch_only="true"
301:            blocker_reason="branch_without_pr"
302:          elif [ "$branch_exists" = "true" ] && [ -n "$merged_pr_url" ]; then
303:            cleanup_candidate="true"
335:          EXISTING_REASON: ${{ steps.existing.outputs.blocker_reason || 'none' }}
348:            decision="existing_automation_pr"
365:            echo "- existing blocker reason: \`${EXISTING_REASON:-none}\`"
```

계획서 Stage 3의 검증 명령과 `gh pr list` read-only 확인은 실패 없이 완료됐다.

## 잔여 위험

- branch-only 상태는 계속 blocker로 유지했다. 실제로 branch-only가 오래 남아 있으면 수동 확인 후 cleanup이 필요할 수 있다.
- merge 완료 branch를 blocker로 보지 않게 했으므로, Stage 2의 base branch current 판정이 정확해야 중복 PR 위험이 낮다.
- `gh pr list --state merged` 동작은 로컬 gh에서 확인했지만, 최종 GitHub-hosted runner 동작은 PR merge 후 workflow run에서 확인해야 한다.

## 다음 단계 영향

Stage 4에서는 `ci_workflow_guide.md`와 `core_dependency_operation_guide.md`에 base branch current 판정, open PR/branch-only/merged branch cleanup 후보 기준을 반영한다. 최종 보고서에는 남아 있는 `automation/rhwp-v0.7.16-full-sync`, `automation/rhwp-v0.7.17-full-sync` 삭제 권고와 별도 승인 필요성을 기록한다.

## 승인 요청

Stage 3 결과를 승인하고 Stage 4 `문서 정리와 최종 검증` 단계로 진행할지 승인 요청한다.
