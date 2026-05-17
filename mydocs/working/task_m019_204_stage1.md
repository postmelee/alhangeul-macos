# Task M019 #204 Stage 1 보고서

## 단계 목표

upstream `rhwp` release 감시와 bundled `rhwp-studio` 자동 업데이트 PR 생성 파이프라인을 구현하기 전에 현재 workflow, script, provenance, 브랜치 정책을 확인하고 자동화 정책을 고정한다.

## 확인 시각

- 2026-05-17 09:24 KST

## 확인한 현재 상태

### upstream release와 bundled 기준

| 항목 | 값 |
|------|----|
| upstream latest release | `v0.7.11` |
| upstream release URL | `https://github.com/edwardkim/rhwp/releases/tag/v0.7.11` |
| upstream published at | `2026-05-10T19:50:46Z` |
| upstream target commitish | `main` |
| `rhwp-core.lock` tag | `v0.7.11` |
| `rhwp-core.lock` commit | `a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae` |
| bundled `rhwp-studio` manifest tag | `v0.7.11` |
| bundled `rhwp-studio` manifest commit | `a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae` |

`scripts/ci/check-rhwp-upstream-release.sh --run-compatibility-check false` 실행 결과는 `outdated=false`, `compatibility_status=skipped_by_input`이었다. 즉 현재 시점에는 upstream latest와 bundled/core 기준이 같아서 자동 업데이트 PR을 만들 상태가 아니다.

### 기존 workflow와 helper

- `.github/workflows/rhwp-upstream-check.yml`은 `workflow_dispatch`와 schedule로 실행되는 read-only workflow다.
- 권한은 `contents: read`이며, `scripts/ci/check-rhwp-upstream-release.sh`를 호출한다.
- `scripts/ci/check-rhwp-upstream-release.sh`는 upstream release와 `rhwp-core.lock`을 비교하고, target이 다를 때 선택적으로 `scripts/update-rhwp-core.sh --check --channel stable --tag <tag>`를 실행한다.
- `scripts/sync-rhwp-studio.sh`는 upstream checkout 경로만 위치 인자로 받고, expected release tag와 commit은 script 내부에 하드코딩되어 있다.
- `scripts/verify-rhwp-studio-assets.sh`도 expected release tag와 commit을 내부 상수로 검사한다.

### 브랜치 정책

- repository 기본 브랜치는 `main`이다.
- 현재 제품 통합 브랜치는 `devel`이다.
- `devel-webview`는 `README.md`와 `mydocs/manual/git_workflow_guide.md`에서 퇴역한 legacy alias로 규정되어 있다.
- `git ls-remote --heads origin devel devel-webview native-viewer-editor` 확인 결과 `origin/devel`과 `origin/native-viewer-editor`만 있고 `origin/devel-webview`는 없다.
- 따라서 #204 자동 PR base는 이슈 본문의 오래된 `devel-webview`가 아니라 `devel`로 고정한다.

## Stage 1 정책 결정

### workflow 분리

read-only 감시와 write-capable PR 생성을 분리한다.

| workflow | 권한 | 역할 |
|----------|------|------|
| `rhwp-upstream-check.yml` | `contents: read` | upstream release와 현재 lock/provenance 비교, summary 기록 |
| `rhwp-upstream-sync-pr.yml` | `contents: write`, `pull-requests: write`, 필요 시 `issues: write` | viewer 영향 변경이 있을 때 automation branch push와 PR 생성 |

기존 read-only workflow는 권한을 넓히지 않는다. PR 생성 권한은 신규 workflow에만 둔다.

### 자동 PR 기준

| 항목 | 기준 |
|------|------|
| base branch | `devel` |
| branch name | `automation/rhwp-<tag>-studio-sync` |
| PR title | `Update bundled rhwp-studio to rhwp <tag>` |
| commit message | `Task #204: Update bundled rhwp-studio to <tag>` |
| maintainer 알림 | PR body `@postmelee` mention을 기본으로 하고, 가능한 경우 assignee 또는 reviewer request 추가 |
| public release | 자동 PR에서 실행하지 않음. 기존 protected release workflow 승인 후 별도 진행 |

### 중복 PR 방지

신규 workflow는 PR 생성 전에 다음을 확인해야 한다.

- 같은 `automation/rhwp-<tag>-studio-sync` branch가 이미 있는지
- 같은 head/base 조합의 열린 PR이 있는지
- 같은 title 또는 같은 target tag의 열린 sync PR이 있는지

이미 열린 PR이 있으면 새 PR을 만들지 않고 workflow summary에 existing PR 정보를 남긴다.

### scheduled workflow 한계

repository 기본 브랜치는 `main`이므로 schedule workflow는 기본 브랜치에 workflow 파일이 들어간 뒤 활성화된다. 이번 #204 작업 PR은 `devel` 대상으로 진행되므로, merge 직후 `devel`에만 존재하는 workflow의 schedule 실행 여부는 GitHub Actions 기본 브랜치 정책에 따라 바로 검증되지 않을 수 있다.

따라서 Stage 4 이후 실제 자동 PR 생성과 schedule queueing은 GitHub-hosted runner에서 다음을 별도 확인해야 한다.

- `workflow_dispatch`로 `devel` 또는 기본 브랜치 기준 실행이 가능한지
- schedule이 기본 브랜치 반영 전까지 비활성인지
- `GITHUB_TOKEN`으로 branch push, PR 생성, assignee/reviewer 설정이 가능한지

## 검증 결과

```bash
git status --short --branch
```

결과: `local/task204` 작업트리는 Stage 1 보고서 작성 전 clean이었다.

```bash
rg -n "devel-webview|rhwp-upstream|rhwp-studio|pull-requests|contents: write|workflow_dispatch|schedule" README.md mydocs/manual .github/workflows scripts
```

결과: `devel-webview` 퇴역 정책, 기존 upstream check workflow, release workflow의 write 권한, `rhwp-studio` provenance 문서 위치를 확인했다.

```bash
jq '.source_release_tag,.source_resolved_commit' Sources/HostApp/Resources/rhwp-studio/manifest.json
```

결과:

```text
"v0.7.11"
"a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae"
```

```bash
bash scripts/ci/check-rhwp-upstream-release.sh --help
```

결과: helper interface 정상.

```bash
gh release view -R edwardkim/rhwp --json tagName,url,targetCommitish,publishedAt,name,isDraft,isPrerelease
```

결과: latest release는 `v0.7.11`, draft/prerelease 아님.

```bash
bash scripts/ci/check-rhwp-upstream-release.sh --run-compatibility-check false
```

결과: `outdated=false`, `compatibility_status=skipped_by_input`.

```bash
gh repo view postmelee/alhangeul-macos --json defaultBranchRef,nameWithOwner
```

결과: default branch는 `main`.

```bash
git ls-remote --heads origin devel devel-webview native-viewer-editor
```

결과: `devel`, `native-viewer-editor`만 존재하고 `devel-webview` 원격 head는 없음.

## Stage 2 진입 조건

Stage 2에서는 `scripts/ci/detect-rhwp-studio-impact.sh`를 추가해 current/target commit 사이의 upstream diff와 viewer 영향 여부를 출력한다. 이 helper는 자동 PR workflow가 PR 생성 여부를 판단하는 첫 번째 실질 gate가 된다.

## 잔여 위험

- schedule workflow는 기본 브랜치 `main`에 workflow가 들어간 뒤 활성화되는 GitHub Actions 정책 영향을 받는다. `devel` PR merge 직후에는 수동 dispatch 또는 main 반영 전까지 실제 schedule 동작을 완전히 확인하지 못할 수 있다.
- `GITHUB_TOKEN`의 reviewer request, assignee 설정 권한은 repository 설정에 따라 다를 수 있다. 실패 시 PR body mention을 최소 알림 경로로 유지한다.
- upstream release의 `targetCommitish`는 `main`으로 표시되므로 실제 release tag object commit은 Stage 2/4에서 별도로 resolve해야 한다.
- 현재 upstream latest가 bundled 기준과 같아, 실제 새 release 기반 자동 PR 생성 end-to-end는 로컬에서 재현할 수 없다.
