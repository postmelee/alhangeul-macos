# Task M040 #376 Stage 1 완료보고서

## 단계 목적

`rhwp Upstream Sync PR` workflow의 현행 판정 경로를 재확인하고, Stage 2~3에서 적용할 base branch 기준 current 판정과 automation branch blocker 구분 설계를 확정했다. 이번 단계에서는 workflow source를 수정하지 않고 조사 결과와 설계 결정을 문서화했다.

## 산출물

| 파일 | 요약 |
|------|------|
| `mydocs/working/task_m040_376_stage1.md` | 현행 run, branch provenance, automation branch/PR 상태, Stage 2~3 설계 결정 기록 |

## 본문 변경 정도 / 본문 무손실 여부

- 코드와 운영 매뉴얼 본문은 변경하지 않았다.
- Stage 1 산출물은 신규 완료보고서 1개다.

## 조사 결과

### 최신 workflow run 상태

- 최신 `rhwp Upstream Sync PR` schedule run: `28075879933`
- 실행 시각: 2026-06-24T04:48:46Z
- event: `schedule`
- headBranch/headSha: `main` / `eb10d27ad802835ebd9354f47462d6ca457f3c9c`
- 결론: workflow 전체 `success`
- job 결론:
  - `Resolve rhwp full sync target`: `success`
  - `Build upstream rhwp-studio assets`: `skipped`
  - `Create rhwp full sync PR candidate`: `skipped`

로그 발췌:

```text
current_tag=v0.7.16
current_commit=de02159ab4d2c5d165d6e25568bad3f8af5ef6cb
target_tag=v0.7.17
target_commit=03351190ec35436e58cbfee0aa9278a8fdc04a59
has_viewer_impact=true
impact_reason_count=129
CURRENT: false
EXISTING: true
DRY_RUN_VALUE: false
```

이 run은 target이 `v0.7.17`임을 감지했지만, current를 `v0.7.16`으로 읽었다. 이후 `EXISTING=true` 때문에 build/PR 생성 job은 실행되지 않았다.

### `main`과 `devel` provenance 차이

원격 ref 비교 결과:

| ref | commit | core tag | core commit | studio tag | studio commit |
|-----|--------|----------|-------------|------------|---------------|
| `origin/main` | `eb10d27ad802835ebd9354f47462d6ca457f3c9c` | `v0.7.16` | `de02159ab4d2c5d165d6e25568bad3f8af5ef6cb` | `v0.7.16` | `de02159ab4d2c5d165d6e25568bad3f8af5ef6cb` |
| `origin/devel` | `093e75e2083997fc9f16475e65a575415830474d` | `v0.7.17` | `03351190ec35436e58cbfee0aa9278a8fdc04a59` | `v0.7.17` | `03351190ec35436e58cbfee0aa9278a8fdc04a59` |

upstream latest release는 `v0.7.17`이며, `origin/devel`의 core/studio provenance는 이미 target과 일치한다. 따라서 current 판정은 `devel` 기준이면 true가 되어야 한다.

### workflow의 현행 checkout/판정 경로

`rg` 확인 결과:

```text
32:  BASE_BRANCH: devel
74:          ref: ${{ github.ref }}
145:          current_core_tag="$(scripts/ci/read-rhwp-core-lock.sh rhwp_release_tag)"
147:          current_studio_tag="$(manifest_field "$manifest_path" source_release_tag)"
276:          if [ "$branch_exists" = "true" ] || [ -n "$pr_url" ]; then
312:            decision="existing_automation_pr"
342:          ref: ${{ github.ref }}
422:          ref: ${{ github.ref }}
524:          git fetch --prune origin "$BASE_BRANCH"
525:          git switch -c "$branch_name" "origin/$BASE_BRANCH"
```

`resolve-target`, `build-studio-assets`, `create-full-sync-pr`의 checkout은 모두 `github.ref` 기준이다. schedule run에서 `github.ref`는 default branch인 `main`이므로, current 판정이 `main`의 stale한 lock/manifest를 읽는다. 반면 실제 PR branch 생성은 `origin/$BASE_BRANCH`에서 이루어진다. 이 불일치가 이번 문제의 핵심이다.

### automation branch와 PR 상태

남아 있는 원격 automation branch:

```text
automation/rhwp-v0.7.16-full-sync -> 3f200c94f27c6465f430d17ac4e21e83476f4fbd
automation/rhwp-v0.7.17-full-sync -> 56096a106af39d58a938d651e3d66a4958198c77
```

관련 PR:

| PR | branch | state | mergedAt |
|----|--------|-------|----------|
| #359 | `automation/rhwp-v0.7.16-full-sync` | `MERGED` | 2026-06-20T16:18:20Z |
| #369 | `automation/rhwp-v0.7.17-full-sync` | `MERGED` | 2026-06-23T17:50:02Z |

현재 workflow는 `branch_exists=true`만으로 `exists=true`를 만들기 때문에 merge 완료 PR의 head branch도 새 PR 생성 blocker가 된다. 이 동작은 중복 PR 방지에는 보수적이지만, merge 완료 branch와 열린 PR을 구분하지 못해 stale summary와 branch cleanup 혼선을 만든다.

## 설계 결정

1. Stage 2에서는 repository content current 판정 기준을 `BASE_BRANCH=devel`로 맞춘다.
   - `resolve-target` job은 `BASE_BRANCH` ref의 `rhwp-core.lock`과 bundled `rhwp-studio` manifest를 읽어야 한다.
   - helper syntax 검증과 impact detection도 같은 base branch checkout에서 실행한다.
   - `build-studio-assets`, `create-full-sync-pr` checkout도 base branch 기준으로 맞춰 실제 PR 생성 base와 사용 script 버전이 어긋나지 않게 한다.

2. Stage 3에서는 existing check의 blocker 기준을 세분화한다.
   - 열린 PR은 계속 blocker로 둔다.
   - branch-only 상태는 PR 생성 전 실패 가능성이 있으므로 blocker로 둔다.
   - merge 완료 PR의 head branch가 남은 상태는 blocker가 아니라 cleanup 후보로 표시한다.
   - `branch_exists`, `open_pr_url`, `merged_pr_url`, blocker 여부를 summary와 output에서 구분한다.

3. 원격 branch 삭제는 이번 구현에서 자동 수행하지 않는다.
   - 원격 삭제는 destructive 작업이므로 최종 보고서에서 권고와 승인 필요성을 분리한다.
   - workflow는 먼저 merge 완료 branch를 blocker로 오판하지 않게 해야 한다.

## 검증 결과

```text
$ git status --short --branch
## local/task376
```

```text
$ git diff --check
```

출력 없음. 통과.

```text
$ rg -n "github.ref|BASE_BRANCH|current_core_tag|current_studio_tag|existing_automation_pr|branch_exists|gh pr list" .github/workflows/rhwp-upstream-sync-pr.yml
32:  BASE_BRANCH: devel
74:          ref: ${{ github.ref }}
145:          current_core_tag="$(scripts/ci/read-rhwp-core-lock.sh rhwp_release_tag)"
147:          current_studio_tag="$(manifest_field "$manifest_path" source_release_tag)"
276:          if [ "$branch_exists" = "true" ] || [ -n "$pr_url" ]; then
312:            decision="existing_automation_pr"
342:          ref: ${{ github.ref }}
422:          ref: ${{ github.ref }}
524:          git fetch --prune origin "$BASE_BRANCH"
525:          git switch -c "$branch_name" "origin/$BASE_BRANCH"
```

Stage 1의 계획 검증 명령은 실패 없이 완료됐다.

## 잔여 위험

- schedule workflow는 default branch의 workflow file로 실행되므로, Stage 2 수정이 default branch에 merge되기 전까지 실제 schedule 동작은 기존 구조를 유지한다.
- `actions/checkout`을 `BASE_BRANCH`로 바꾸면 workflow file의 실행 ref와 repository content ref가 의도적으로 분리된다. summary에 이를 명시해야 운영자가 혼동하지 않는다.
- branch-only 상태를 blocker로 유지하더라도, 이미 merge된 PR branch cleanup은 별도 승인 또는 merge cleanup 절차가 필요하다.

## 다음 단계 영향

Stage 2에서는 `.github/workflows/rhwp-upstream-sync-pr.yml`의 checkout 기준과 summary를 먼저 수정한다. Stage 3의 blocker 세분화는 Stage 2의 base branch current 판정이 정확하다는 전제 위에서 적용한다.

## 승인 요청

Stage 1 결과를 승인하고 Stage 2 `sync workflow base branch 판정 적용` 단계로 진행할지 승인 요청한다.
