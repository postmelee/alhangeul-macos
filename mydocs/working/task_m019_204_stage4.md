# Task M019 #204 Stage 4 보고서

## 단계 목표

viewer/WASM/core 영향 변경이 있을 때 `devel` 대상 bundled `rhwp-studio` 업데이트 후보 PR을 생성하는 write-capable workflow와 PR body helper를 추가한다.

## 확인 시각

- 2026-05-17 09:41 KST

## 변경 요약

### 신규 workflow

`.github/workflows/rhwp-upstream-sync-pr.yml`을 추가했다.

주요 속성:

| 항목 | 값 |
|------|----|
| workflow name | `rhwp Upstream Sync PR` |
| trigger | `workflow_dispatch`, schedule |
| base branch | `devel` |
| automation branch | `automation/rhwp-<tag>-studio-sync` |
| 권한 | `contents: write`, `pull-requests: write`, `issues: write` |
| maintainer 알림 | PR body `@postmelee`, 가능한 경우 assignee/reviewer 설정 |
| public release | 실행하지 않음 |

`workflow_dispatch` 입력:

| input | 기본값 | 의미 |
|-------|--------|------|
| `target_tag` | 빈 값 | 비우면 upstream latest release를 사용 |
| `force_pr` | `false` | viewer impact가 없어도 PR 생성 후보로 진행 |
| `dry_run` | `false` | resolve/classify만 수행하고 build, push, PR 생성은 하지 않음 |

### 신규 PR body helper

`scripts/ci/write-rhwp-studio-sync-pr-body.sh`를 추가했다.

helper는 다음 값을 받아 자동 PR 본문을 생성한다.

- previous/new bundled tag와 commit
- upstream release URL
- upstream changed paths
- viewer/WASM/core impact paths와 reason
- repository changed paths
- 실행한 검증
- maintainer checklist
- public release는 별도 승인과 protected workflow가 필요하다는 경계

자동 생성 PR body에는 `Closes #204`를 넣지 않고 `Automation source: #204`만 남긴다. 이 자동화가 향후 생성하는 업데이트 PR이 #204 파이프라인 이슈를 닫는 PR처럼 보이면 안 되기 때문이다.

## workflow 상태 분기

workflow는 다음 순서로 상태를 분기한다.

1. `rhwp-studio` manifest의 current tag/commit을 읽는다.
2. 입력 `target_tag`가 있으면 해당 release를, 없으면 upstream latest release를 조회한다.
3. target tag를 실제 commit으로 resolve한다.
4. current tag/commit과 target tag/commit이 같으면 `current` 상태로 종료하고 PR을 만들지 않는다.
5. upstream checkout을 만들고 `scripts/ci/detect-rhwp-studio-impact.sh`로 impact를 판정한다.
6. impact가 없고 `force_pr=false`이면 `no viewer impact` 상태로 종료하고 PR을 만들지 않는다.
7. 같은 automation branch 또는 같은 head/base open PR이 있으면 중복 생성 없이 종료한다.
8. `dry_run=true`이면 build, push, PR 생성 없이 종료한다.
9. upstream WASM과 `rhwp-studio` dist를 build한다.
10. `scripts/update-rhwp-core.sh --check --channel stable --tag <target>`로 core API compatibility를 확인한다.
11. `scripts/sync-rhwp-studio.sh --tag <target> --commit <commit>`으로 bundled asset을 갱신한다.
12. repository changed paths가 없으면 PR 없이 종료한다.
13. PR body를 생성하고 automation branch commit/push 후 `gh pr create --base devel`을 실행한다.

## 검증 결과

### workflow YAML

```bash
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/rhwp-upstream-sync-pr.yml"); puts "Parsed .github/workflows/rhwp-upstream-sync-pr.yml"'
ruby -e 'require "psych"; Dir[".github/workflows/*.yml"].sort.each { |path| Psych.parse_file(path); puts "Parsed #{path}" }'
actionlint .github/workflows/rhwp-upstream-sync-pr.yml
```

결과: 모두 통과.

### helper syntax와 interface

```bash
bash -n scripts/ci/write-rhwp-studio-sync-pr-body.sh
scripts/ci/write-rhwp-studio-sync-pr-body.sh --help
bash -n scripts/*.sh scripts/ci/*.sh
git diff --check
```

결과: 모두 통과.

### PR body sample 생성

`build.noindex/rhwp-sync-pr-body-test/` 아래 sample changed path, impact TSV, repository changed path, verification file을 만들고 helper를 실행했다.

결과 body 주요 내용:

```text
# Update bundled rhwp-studio to rhwp v0.7.12
@postmelee upstream `edwardkim/rhwp` release 감지 결과 bundled `rhwp-studio` 업데이트 후보를 생성했습니다.
...
Automation source: #204
```

본문에는 previous/new tag와 commit, upstream impact paths, repository changed paths, verification, maintainer checklist, release boundary가 포함됐다.

## 로컬에서 확인하지 못한 항목

다음은 GitHub-hosted runner와 repository 권한이 있어야 확인할 수 있다.

- `GITHUB_TOKEN`으로 `automation/rhwp-<tag>-studio-sync` branch push가 가능한지
- `gh pr create --base devel --head automation/rhwp-<tag>-studio-sync`가 성공하는지
- `gh pr edit --add-assignee`, `--add-reviewer`가 repository 설정에서 허용되는지
- schedule workflow가 repository 기본 브랜치 `main` 반영 전후로 언제 활성화되는지
- upstream 실제 build에서 `docker-compose` 또는 `docker compose` WASM build가 GitHub-hosted runner에서 성공하는지
- `npm ci`, `npx tsc`, `npx vite build --base ./`가 upstream `rhwp-studio`에서 시간 제한 안에 성공하는지

## Stage 5 진입 조건

Stage 5에서는 PR CI 분류와 운영 문서를 갱신한다. 특히 신규 workflow와 helper가 PR CI의 helper interface check에 포함되도록 하고, `rhwp Upstream Sync PR`의 trigger, 권한, 상태 분기, 로컬 재현 명령을 `mydocs/manual/ci_workflow_guide.md`에 기록한다.

## 잔여 위험

- 자동 PR workflow는 write 권한을 가진다. 권한은 PR 생성 workflow에만 부여했지만, 실제 repository settings와 GitHub Actions token policy에 따라 세부 동작이 달라질 수 있다.
- upstream build는 Docker, npm, Vite, TypeScript에 의존한다. 로컬 Stage 4에서는 workflow 문법과 helper body 생성만 검증했고 실제 upstream build는 실행하지 않았다.
- 자동 PR은 bundled `rhwp-studio` 후보를 생성한다. public release, Sparkle appcast, DMG, Homebrew 배포는 계속 별도 승인 흐름이다.
