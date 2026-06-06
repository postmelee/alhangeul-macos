# Task M019 #345 Stage 4 완료 보고서

## 단계 목적

수정된 `rhwp Upstream Sync PR` workflow를 원격 ref에서 실제 `dry_run=false`로 실행해 `/app/Cargo.lock` permission denied가 해결됐는지 확인하고, 자동 업데이트 후보 branch/PR 생성 상태를 확인한다.

이번 단계는 GitHub Actions 실검증과 운영 상태 확인 단계이며, workflow source는 Stage 2 커밋 이후 추가로 변경하지 않았다.

## 확인 시각

- 2026-06-06 17:27 KST

## 산출물

| 파일 | 요약 |
|------|------|
| `mydocs/manual/ci_workflow_guide.md` | 자동 PR 생성에 필요한 repository Actions permission 조건 추가 |
| `mydocs/orders/20260606.md` | #345 진행 상태를 Stage 4 완료보고서 승인 대기로 갱신 |
| `mydocs/working/task_m019_345_stage4.md` | 실제 Actions run 결과, 자동 branch/PR 생성 상태, 잔여 운영 차단점 정리 |

## 본문 변경 정도 / 본문 무손실 여부

- 제품 source 변경 없음.
- workflow 추가 변경 없음.
- `rhwp-core.lock`, RustBridge dependency 변경 없음.
- bundled `rhwp-studio` asset 변경 없음.
- `publish/task345` 원격 branch를 Stage 4 검증 ref로 생성했다.
- workflow가 자동 생성한 `automation/rhwp-v0.7.14-studio-sync` 원격 branch가 남아 있다.

## 실행한 workflow

```bash
git push origin local/task345:publish/task345
```

결과: `publish/task345` 원격 branch 생성.

```bash
gh workflow run "rhwp Upstream Sync PR" \
  --repo postmelee/alhangeul-macos \
  --ref publish/task345 \
  -f target_tag=v0.7.14 \
  -f force_pr=false \
  -f dry_run=false
```

결과:

- run URL: `https://github.com/postmelee/alhangeul-macos/actions/runs/27057255287`
- event: `workflow_dispatch`
- head branch: `publish/task345`
- head SHA: `73e1bd0cefea52672e3f3670d69a0616d3e0c084`
- job URL: `https://github.com/postmelee/alhangeul-macos/actions/runs/27057255287/job/79863770174`
- conclusion: `failure`

## 단계별 결과

| 단계 | 결과 | 의미 |
|------|------|------|
| `Check out base branch` | success | `devel` checkout 정상 |
| `Verify helper syntax` | success | helper syntax 정상 |
| `Resolve current and target rhwp release` | success | `v0.7.13`에서 `v0.7.14` 대상 해석 |
| `Check out upstream rhwp` | success | upstream checkout 정상 |
| `Detect rhwp-studio impact` | success | viewer 영향 있음 |
| `Check existing automation PR` | success | 실행 시점에는 기존 branch/PR 없음 |
| `Stop in dry run` | skipped | `dry_run=false`로 실제 build 진행 |
| `Build upstream rhwp-studio assets` | success | `/app/Cargo.lock` permission denied 재발 없음 |
| `Sync bundled rhwp-studio and create PR` | failure | branch push 성공 후 PR 생성이 repository Actions 설정에 차단됨 |

## 권한 오류 수정 검증

Stage 4 run의 build step 로그에서 수정된 `.env.docker` 생성 block이 실행 definition에 포함됨을 확인했다.

```text
if [ ! -f .env.docker.example ]; then
  echo "ERROR: upstream rhwp is missing .env.docker.example" >&2
  exit 1
fi

{
  echo "UID=$(id -u)"
  echo "GID=$(id -g)"
} > .env.docker
```

`Build upstream rhwp-studio assets` 단계는 `2026-06-06T08:18:55Z`에 시작해 `2026-06-06T08:24:21Z`에 success로 완료했다. 이전 실패의 직접 원인인 다음 오류는 재발하지 않았다.

```text
error: failed to write /app/Cargo.lock
Caused by:
  Permission denied (os error 13)
```

따라서 #345의 직접 수정 대상인 upstream WASM build 중 `Cargo.lock` 권한 실패는 실제 `dry_run=false` workflow 실행으로 해결 검증됐다.

## 자동 업데이트 branch 생성 상태

`Sync bundled rhwp-studio and create PR` 단계는 bundled asset sync와 commit, branch push까지 진행했다.

```text
OK: rhwp-studio assets verified at /home/runner/work/alhangeul-macos/alhangeul-macos/Sources/HostApp/Resources/rhwp-studio
OK: rhwp-studio synced to /home/runner/work/alhangeul-macos/alhangeul-macos/Sources/HostApp/Resources/rhwp-studio from v0.7.14 at fb885547538dc6572a12722dd2991b553e082e0e
[automation/rhwp-v0.7.14-studio-sync 31bb88e] Task #204: Update bundled rhwp-studio to v0.7.14
14 files changed, 913 insertions(+), 148 deletions(-)
```

원격 branch:

```text
31bb88e964607773ae429afa19e2800b8d888ac8	refs/heads/automation/rhwp-v0.7.14-studio-sync
```

생성된 manifest 핵심 값:

```json
{
  "source_release_tag": "v0.7.14",
  "source_resolved_commit": "fb885547538dc6572a12722dd2991b553e082e0e",
  "copied_file_count": 58,
  "copied_total_bytes": 37657522
}
```

변경 규모:

```text
14 files changed, 913 insertions(+), 148 deletions(-)
```

주요 변경:

- hashed JS/CSS asset 교체
- `rhwp_bg` WASM asset 교체
- `NotoSansKR-ExtraLight.woff2` 추가
- `manifest.json`, `rhwp.js`, `rhwp.d.ts`, `rhwp_bg.wasm.d.ts`, `sw.js` 갱신

## 자동 PR 생성 차단점

PR 생성은 다음 오류로 실패했다.

```text
pull request create failed: GraphQL: GitHub Actions is not permitted to create or approve pull requests (createPullRequest)
```

현재 repository Actions workflow permission 조회 결과:

```json
{
  "default_workflow_permissions": "read",
  "can_approve_pull_request_reviews": false
}
```

이번 workflow는 자체 `permissions`에서 `contents: write`, `pull-requests: write`, `issues: write`를 요청하므로 automation branch push는 성공했다. 그러나 GitHub의 repository-level setting에서 Actions의 PR 생성/승인이 꺼져 있어 `gh pr create`가 차단됐다.

이 설정 변경은 repository 전체 보안 범위가 커서 작업지시자의 명시적 위험 인지 승인 없이는 수행하지 않았다.

## PR 생성 상태 확인

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

즉 자동 업데이트 branch는 존재하지만 PR은 아직 생성되지 않았다.

## 검증 결과

```bash
git status --short --branch
```

Stage 4 문서 작성 전 결과:

```text
## local/task345
```

```bash
gh run view 27057255287 --repo postmelee/alhangeul-macos --json status,conclusion,url,headBranch,headSha,event,createdAt,updatedAt,jobs
```

결과:

- status: `completed`
- conclusion: `failure`
- headBranch: `publish/task345`
- headSha: `73e1bd0cefea52672e3f3670d69a0616d3e0c084`
- failed step: `Sync bundled rhwp-studio and create PR`
- `Build upstream rhwp-studio assets`: success

```bash
git show --stat --oneline --summary origin/automation/rhwp-v0.7.14-studio-sync
```

결과: `31bb88e Task #204: Update bundled rhwp-studio to v0.7.14`, `14 files changed, 913 insertions(+), 148 deletions(-)`.

## 완료 기준 확인

| 기준 | 결과 |
|------|------|
| 수정 workflow를 원격 ref에서 실제 실행 | OK, `publish/task345` |
| `dry_run=false`로 build 실행 | OK |
| `/app/Cargo.lock` permission denied 재발 없음 | OK |
| upstream WASM build와 rhwp-studio build 성공 | OK |
| 자동 업데이트 branch 생성 | OK, `automation/rhwp-v0.7.14-studio-sync` |
| 자동 PR 생성 | 차단, repository Actions permission 설정 필요 |

## 잔여 위험

- 자동 PR 생성까지 완전 검증하려면 repository Actions setting에서 PR 생성/승인을 허용해야 한다.
- 해당 설정을 켠 뒤 full rerun을 하려면 기존 `automation/rhwp-v0.7.14-studio-sync` branch를 삭제하거나 PR로 전환해야 한다. 그대로 두면 workflow의 기존 branch check에서 중단된다.
- `publish/task345`는 Stage 4 검증용 원격 branch로 생성됐으므로, #345 최종 PR 정리 시 유지/정리 정책을 결정해야 한다.
- 현재 `automation/rhwp-v0.7.14-studio-sync` branch에는 실제 v0.7.14 update commit이 있으므로, 작업지시자 결정에 따라 수동 PR 생성 또는 branch 삭제 후 자동 재실행 중 하나를 선택해야 한다.

## 다음 단계 선택지

1. repository Actions setting 변경을 명시 승인한 뒤 `can_approve_pull_request_reviews=true`로 설정하고, `automation/rhwp-v0.7.14-studio-sync` branch를 삭제한 뒤 workflow를 재실행한다.
2. repository setting은 그대로 두고, 이미 생성된 `automation/rhwp-v0.7.14-studio-sync` branch에서 수동으로 업데이트 PR을 만든다.
3. 이번 #345는 `Cargo.lock` 권한 오류 수정 검증 완료로 닫고, 자동 PR 생성 권한 문제는 별도 운영 이슈로 분리한다.

## 승인 요청

Stage 4 결과를 승인하면 다음 조치를 작업지시자 선택에 따라 진행한다.
