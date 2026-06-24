# Task M040 #376 Stage 2 완료보고서

## 단계 목적

`rhwp Upstream Sync PR` workflow가 schedule/manual dispatch에서 repository content를 `BASE_BRANCH=devel` 기준으로 checkout하고, 그 checkout의 `rhwp-core.lock`과 bundled `rhwp-studio` manifest로 current 판정을 수행하도록 수정했다. 이번 단계는 checkout/current 판정 기준 보정에 한정하고, existing automation branch/PR blocker 세분화는 Stage 3으로 남겼다.

## 산출물

| 파일 | 요약 |
|------|------|
| `.github/workflows/rhwp-upstream-sync-pr.yml` | `resolve-target`, `build-studio-assets`, `create-full-sync-pr` job checkout을 `github.ref`에서 `env.BASE_BRANCH`로 변경하고 summary에 workflow event ref와 repository content ref를 분리 표시 |
| `mydocs/working/task_m040_376_stage2.md` | Stage 2 변경 내용과 검증 결과 기록 |

## 본문 변경 정도 / 본문 무손실 여부

- workflow YAML의 checkout step 3곳과 summary 출력 2줄만 변경했다.
- `target_tag`, `dry_run`, `force_pr`, GitHub App token, PR 생성, artifact 흐름은 변경하지 않았다.
- existing automation branch/PR 판단 로직은 Stage 3 범위로 유지해 이번 커밋에서는 변경하지 않았다.

## 변경 내용

### base branch checkout 적용

다음 세 job의 checkout 기준을 `github.ref`에서 `env.BASE_BRANCH`로 바꿨다.

- `resolve-target`
- `build-studio-assets`
- `create-full-sync-pr`

변경 전 schedule run은 default branch `main`의 repository content를 읽어 current 판정을 수행했다. 변경 후에는 workflow file 자체는 default branch에서 실행되더라도, lock/manifest와 helper script는 `BASE_BRANCH=devel` checkout에서 읽는다.

### summary 가시성 보강

`resolve-target` summary에 다음 항목을 추가했다.

```text
- repository content ref: `$BASE_BRANCH`
- workflow event ref: `${GITHUB_REF:-unknown}`
```

이로써 workflow가 어떤 event ref로 실행되었고 어떤 branch content를 current 판정에 사용했는지 구분할 수 있다.

## 검증 결과

```text
$ ruby -e 'require "psych"; Psych.parse_file(".github/workflows/rhwp-upstream-sync-pr.yml")'
Ignoring ffi-1.13.1 because its extensions are not built. Try: gem pristine ffi --version 1.13.1
```

exit code 0. YAML parse는 통과했다. `ffi` 경고는 로컬 Ruby gem 환경 경고로, YAML parse 실패는 아니다.

```text
$ git diff --check
```

출력 없음. 통과.

```text
$ rg -n "ref:.*BASE_BRANCH|workflow event ref|repository content ref|base branch|current core tag|full sync current|Check out base branch|github.ref" .github/workflows/rhwp-upstream-sync-pr.yml
71:      - name: Check out base branch
74:          ref: ${{ env.BASE_BRANCH }}
202:            echo "- current core tag: \`$current_core_tag\`"
211:            echo "- full sync current: \`$current\`"
212:            echo "- base branch: \`$BASE_BRANCH\`"
213:            echo "- repository content ref: \`$BASE_BRANCH\`"
214:            echo "- workflow event ref: \`${GITHUB_REF:-unknown}\`"
341:      - name: Check out base branch
344:          ref: ${{ env.BASE_BRANCH }}
421:      - name: Check out base branch
424:          ref: ${{ env.BASE_BRANCH }}
```

계획서 Stage 2의 검증 명령은 실패 없이 완료됐다.

## 잔여 위험

- GitHub Actions schedule은 계속 default branch의 workflow file을 실행한다. 이번 수정은 실행된 workflow가 checkout하는 repository content를 `BASE_BRANCH`로 맞추는 방식이다.
- `env.BASE_BRANCH` expression은 GitHub-hosted runner에서 최종 확인이 필요하다. 로컬 YAML parse는 문법만 검증한다.
- 기존 `Check existing automation PR` step은 아직 `branch_exists=true`만으로 blocker를 만들 수 있다. merge 완료 branch blocker 구분은 Stage 3에서 처리한다.

## 다음 단계 영향

Stage 3에서는 existing automation branch/PR check를 열린 PR, branch-only, merge 완료 PR로 분리한다. Stage 2에서 current 판정이 base branch 기준으로 바뀌었으므로, merge 완료 branch가 남아 있어도 base branch가 이미 current이면 `decision=current`로 종료될 수 있는 기반이 마련됐다.

## 승인 요청

Stage 2 결과를 승인하고 Stage 3 `merged automation branch blocker 구분` 단계로 진행할지 승인 요청한다.
