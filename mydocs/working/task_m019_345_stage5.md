# Task M019 #345 Stage 5 완료 보고서

## 단계 목적

Stage 4에서 확인한 repository-level Actions permission 차단점을 해소하고, `rhwp Upstream Sync PR` workflow가 upstream build부터 자동 PR 생성까지 end-to-end로 성공하는지 검증한다.

이번 단계는 repository 운영 설정 변경과 GitHub Actions 재실행 검증 단계이며, workflow source는 Stage 2 커밋 이후 추가로 변경하지 않았다.

## 확인 시각

- 2026-06-06 17:39 KST

## 산출물

| 파일 | 요약 |
|------|------|
| `mydocs/manual/ci_workflow_guide.md` | 자동 PR 생성을 위한 현재 repository Actions permission 운영 설정 기록 |
| `mydocs/orders/20260606.md` | #345 진행 상태를 Stage 5 완료보고서 승인 대기로 갱신 |
| `mydocs/working/task_m019_345_stage5.md` | 자동 PR 생성까지의 end-to-end 검증 결과 정리 |

## 본문 변경 정도 / 본문 무손실 여부

- 제품 source 변경 없음.
- workflow 추가 변경 없음.
- `rhwp-core.lock`, RustBridge dependency 변경 없음.
- bundled `rhwp-studio` asset 변경 없음.
- repository Actions workflow permission을 다음 값으로 변경했다.

```json
{
  "default_workflow_permissions": "read",
  "can_approve_pull_request_reviews": true
}
```

- Stage 4 실패 run이 남긴 `automation/rhwp-v0.7.14-studio-sync` 원격 branch를 삭제한 뒤 workflow가 다시 생성하게 했다.
- 자동 업데이트 PR `#346`이 생성되어 open 상태로 남아 있다.

## Stage 5 시작 상태

```bash
git status --short --branch
```

결과:

```text
## local/task345
```

원격 branch 상태:

```text
31bb88e964607773ae429afa19e2800b8d888ac8	refs/heads/automation/rhwp-v0.7.14-studio-sync
2066c09fdfc1fe3bd7d96fa30df929ff24ec79e8	refs/heads/publish/task345
```

repository Actions workflow permission:

```json
{
  "default_workflow_permissions": "read",
  "can_approve_pull_request_reviews": false
}
```

기존 PR 확인:

```bash
gh pr list \
  --repo postmelee/alhangeul-macos \
  --base devel \
  --head automation/rhwp-v0.7.14-studio-sync \
  --state all \
  --json number,title,state,url,headRefName,baseRefName
```

결과:

```json
[]
```

## 수행한 운영 조치

작업지시자가 자동 PR 생성까지 완전 검증을 승인했으므로 repository-level Actions permission을 변경했다.

```bash
gh api -X PUT \
  repos/postmelee/alhangeul-macos/actions/permissions/workflow \
  -f default_workflow_permissions=read \
  -F can_approve_pull_request_reviews=true
```

변경 후 확인:

```json
{
  "default_workflow_permissions": "read",
  "can_approve_pull_request_reviews": true
}
```

재실행이 기존 branch check에서 멈추지 않도록 Stage 4 실패 run이 만든 자동 branch를 삭제했다.

```bash
git push origin --delete automation/rhwp-v0.7.14-studio-sync
```

결과:

```text
To https://github.com/postmelee/alhangeul-macos.git
 - [deleted]         automation/rhwp-v0.7.14-studio-sync
```

## 재실행한 workflow

```bash
gh workflow run "rhwp Upstream Sync PR" \
  --repo postmelee/alhangeul-macos \
  --ref publish/task345 \
  -f target_tag=v0.7.14 \
  -f force_pr=false \
  -f dry_run=false
```

결과:

- run URL: `https://github.com/postmelee/alhangeul-macos/actions/runs/27057524066`
- event: `workflow_dispatch`
- head branch: `publish/task345`
- head SHA: `2066c09fdfc1fe3bd7d96fa30df929ff24ec79e8`
- job URL: `https://github.com/postmelee/alhangeul-macos/actions/runs/27057524066/job/79864492826`
- conclusion: `success`

## 단계별 결과

| 단계 | 결과 | 의미 |
|------|------|------|
| `Check out base branch` | success | `devel` checkout 정상 |
| `Verify helper syntax` | success | helper syntax 정상 |
| `Resolve current and target rhwp release` | success | `v0.7.13`에서 `v0.7.14` 대상 해석 |
| `Check out upstream rhwp` | success | upstream checkout 정상 |
| `Detect rhwp-studio impact` | success | viewer 영향 있음 |
| `Check existing automation PR` | success | 기존 branch/PR 없음 |
| `Stop in dry run` | skipped | `dry_run=false`로 실제 build 진행 |
| `Build upstream rhwp-studio assets` | success | `/app/Cargo.lock` permission denied 재발 없음 |
| `Sync bundled rhwp-studio and create PR` | success | 자동 branch push와 PR 생성 성공 |

## 자동 PR 생성 결과

생성된 PR:

- URL: `https://github.com/postmelee/alhangeul-macos/pull/346`
- 번호: `#346`
- 제목: `Update bundled rhwp-studio to rhwp v0.7.14`
- 상태: `OPEN`
- 작성자: `app/github-actions`
- base: `devel`
- head: `automation/rhwp-v0.7.14-studio-sync`
- assignee: `postmelee`
- review request: `postmelee`
- 생성 시각: `2026-06-06T08:37:48Z`

자동 branch:

```text
28cb70d301e1bb5044dd5d72eb8a23550937c422	refs/heads/automation/rhwp-v0.7.14-studio-sync
```

자동 update commit:

```text
28cb70d Task #204: Update bundled rhwp-studio to v0.7.14
14 files changed, 913 insertions(+), 148 deletions(-)
```

manifest 핵심 값:

```json
{
  "source_release_tag": "v0.7.14",
  "source_resolved_commit": "fb885547538dc6572a12722dd2991b553e082e0e",
  "copied_file_count": 58,
  "copied_total_bytes": 37657522
}
```

PR body에는 `Automation source: #204`가 포함되며, issue close keyword는 포함하지 않는다.

## 검증 결과

```bash
gh run view 27057524066 \
  --repo postmelee/alhangeul-macos \
  --json status,conclusion,updatedAt,jobs
```

결과:

- status: `completed`
- conclusion: `success`
- `Build upstream rhwp-studio assets`: success
- `Sync bundled rhwp-studio and create PR`: success

```bash
gh pr view 346 \
  --repo postmelee/alhangeul-macos \
  --json number,title,state,url,author,baseRefName,headRefName,commits,assignees,reviewRequests
```

결과:

- `number`: `346`
- `state`: `OPEN`
- `author`: `app/github-actions`
- `baseRefName`: `devel`
- `headRefName`: `automation/rhwp-v0.7.14-studio-sync`
- commit: `28cb70d301e1bb5044dd5d72eb8a23550937c422`

```bash
gh api repos/postmelee/alhangeul-macos/actions/permissions/workflow
```

최종 결과:

```json
{
  "default_workflow_permissions": "read",
  "can_approve_pull_request_reviews": true
}
```

## 완료 기준 확인

| 기준 | 결과 |
|------|------|
| repository Actions PR 생성 허용 설정 반영 | OK |
| 기존 automation branch 정리 | OK |
| 수정 workflow를 원격 ref에서 재실행 | OK, `publish/task345` |
| `dry_run=false` build 성공 | OK |
| `/app/Cargo.lock` permission denied 재발 없음 | OK |
| 자동 update branch 생성 | OK |
| 자동 update PR 생성 | OK, `#346` |
| assignee/reviewer 지정 | OK |

## 잔여 위험

- repository-level Actions permission 변경은 유지 상태다. 현재 값은 `default_workflow_permissions=read`, `can_approve_pull_request_reviews=true`이다.
- 자동 update PR `#346`은 실제 bundled `rhwp-studio` v0.7.14 업데이트 후보이며, 이번 #345 수정 PR과 별도로 검토해야 한다.
- `publish/task345`는 #345 수정 PR 게시용 branch이고, `automation/rhwp-v0.7.14-studio-sync`는 자동 업데이트 후보 branch다. 두 branch의 목적이 다르므로 merge/cleanup 시 구분해야 한다.

## 다음 단계 영향

#345 관점에서는 workflow 수정 검증이 완료됐다. 다음 단계에서는 최종 보고서를 작성하고 #345 수정 PR을 게시할 수 있다.

별도로 `#346` 업데이트 PR은 maintainer checklist에 따라 manifest, CI, viewer/editor smoke 필요 여부를 검토해야 한다.

## 승인 요청

Stage 5 결과를 승인하면 #345 최종 보고서 작성과 수정 PR 게시 단계로 진행한다.
