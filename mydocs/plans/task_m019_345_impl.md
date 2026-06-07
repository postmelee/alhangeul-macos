# Task M019 #345 구현계획서

수행계획서: `mydocs/plans/task_m019_345.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #345 `rhwp Upstream Sync PR`가 upstream WASM build 중 `Cargo.lock` 권한 오류로 실패하는 문제 수정
- 마일스톤: M019 (`v0.1.2`)
- 브랜치: `local/task345`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac`
- 기준 브랜치: `devel`
- 목표: GitHub-hosted runner에서 upstream WASM build container가 bind-mounted `/app/Cargo.lock`을 쓸 수 있게 `.env.docker`의 UID/GID 값을 runner user와 맞춘다.

## 확인된 현재 상태

2026-06-05 기준 확인 결과:

- `rhwp Upstream Sync PR` run `27004087710`은 `workflow_dispatch`로 실행됐다.
- 실행 ref는 `devel`, head SHA는 `1cf1db9303a9254dc7fb65cd30ee6d9320ec4c68`였다.
- 입력은 `target_tag=v0.7.14`, `force_pr=false`, `dry_run=false`였다.
- `Check out upstream rhwp`, `Detect rhwp-studio impact`, `Check existing automation PR` 단계는 통과했다.
- #336에서 추가한 `.env.docker` 준비 로직은 동작했다. 기존 `.env.docker` 누락 오류는 재발하지 않았고 Docker image build와 `wasm-pack` 설치까지 진행했다.
- 실패 단계는 `Build upstream rhwp-studio assets`였고 직접 오류는 다음이었다.

```text
error: failed to write /app/Cargo.lock
Caused by:
  failed to open: /app/Cargo.lock
Caused by:
  Permission denied (os error 13)
```

- upstream `.env.docker.example`은 `UID=1000`, `GID=1000`을 기본값으로 제공한다.
- upstream `docker-compose.yml`은 build args와 service env file에서 `UID`/`GID`를 사용해 container의 `builder` user/group을 구성한다.
- GitHub-hosted runner checkout directory의 owner UID/GID와 upstream example의 고정 `1000:1000`이 맞지 않아 `/app` bind mount write 권한이 깨진 것으로 판단한다.

## 구현 원칙

- 수정은 `.github/workflows/rhwp-upstream-sync-pr.yml`의 `Build upstream rhwp-studio assets` 단계에 한정한다.
- upstream checkout, impact detection, PR body 생성, bundled asset sync 로직은 변경하지 않는다.
- CI용 `.env.docker`는 runner의 실제 `id -u`와 `id -g`를 사용해 생성한다.
- upstream `.env.docker.example`은 파일 존재/사용법 근거로 참고하되, CI에서는 `UID`/`GID` 값을 명시적으로 override한다.
- `.env.docker`에 필요한 값은 현재 upstream compose 기준 `UID`, `GID` 두 개다. Stage 1에서 upstream file을 확인해 이 전제를 보고서에 고정한다.
- `dry_run=true`는 build를 건너뛰므로 권한 수정 검증 기준으로 삼지 않는다. 실제 수정 검증은 `dry_run=false` workflow 실행으로 한다.
- `rhwp-core.lock`, RustBridge dependency, bundled `rhwp-studio` asset은 이번 작업 브랜치에서 수동 갱신하지 않는다.
- 실제 workflow 성공으로 생성되는 `automation/rhwp-v0.7.14-studio-sync` PR은 별도 업데이트 후보 PR로 확인만 하고 merge하지 않는다.

## Stage 1. 실패 원인과 UID/GID 전략 확정

### 목표

run `27004087710` 실패 경로와 upstream Docker UID/GID 사용 방식을 보고서에 고정하고, Stage 2에서 구현할 `.env.docker` 생성 전략을 확정한다.

### 작업

- run `27004087710`의 실패 단계와 직접 오류를 기록한다.
- `.env.docker` 누락 오류가 해결됐고 새 실패가 `/app/Cargo.lock` 권한 문제임을 정리한다.
- upstream `v0.7.14`의 `.env.docker.example` 내용을 확인한다.
- upstream `v0.7.14`의 `docker-compose.yml`에서 `UID`, `GID` 사용 위치를 확인한다.
- Stage 2 구현 전략을 다음 방향으로 고정한다.
  - `cd "$upstream_dir"` 직후 CI용 `.env.docker`를 workflow가 생성한다.
  - 값은 `UID=$(id -u)`, `GID=$(id -g)`로 한다.
  - 기존 `.env.docker.example` 복사 방식은 고정 UID/GID를 가져오므로 대체한다.

### 예상 변경 파일

- `mydocs/working/task_m019_345_stage1.md`

### 검증

```bash
git status --short --branch
gh run view 27004087710 --repo postmelee/alhangeul-macos --json status,conclusion,url,headBranch,headSha,jobs
gh api 'repos/edwardkim/rhwp/contents/.env.docker.example?ref=v0.7.14' --jq '.content | @base64d'
gh api 'repos/edwardkim/rhwp/contents/docker-compose.yml?ref=v0.7.14' --jq '.content | @base64d'
git diff --check
```

### 완료 기준

- Stage 1 보고서에 실패 메시지, upstream UID/GID 구성, Stage 2 구현 전략이 기록된다.
- source/workflow 구현 변경은 아직 없다.

### 커밋 메시지

```text
Task #345 Stage 1: upstream sync Cargo.lock 권한 실패 경로 정리
```

## Stage 2. workflow UID/GID env file 생성 로직 구현

### 목표

`Build upstream rhwp-studio assets` 단계가 runner user의 UID/GID를 담은 CI용 `.env.docker`를 생성한 뒤 Docker Compose를 실행하게 한다.

### 작업

- `.github/workflows/rhwp-upstream-sync-pr.yml`을 수정한다.
  - `cd "$upstream_dir"` 직후 `.env.docker` 생성 block을 교체한다.
  - `.env.docker.example`이 없으면 upstream layout 이상을 알리는 오류를 출력하고 실패한다.
  - `.env.docker`에는 `UID=$(id -u)`와 `GID=$(id -g)`를 기록한다.
  - 생성된 값은 secret이 아니므로 workflow log에 짧게 출력할지 여부를 검토하되, 과한 로그는 피한다.
- Docker Compose 실행 block은 기존 command selection을 유지한다.
- workflow YAML parse와 diff check를 실행한다.
- Stage 2 보고서에 변경 지점과 검증 결과를 기록한다.

### 예상 변경 파일

- `.github/workflows/rhwp-upstream-sync-pr.yml`
- `mydocs/working/task_m019_345_stage2.md`

### 검증

```bash
git status --short --branch
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/rhwp-upstream-sync-pr.yml"); puts "parsed"'
git diff --check
```

### 완료 기준

- workflow가 runner UID/GID 기반 `.env.docker` 생성 block을 포함한다.
- workflow YAML parse와 diff check가 통과한다.
- `rhwp-core.lock`, RustBridge dependency, bundled `rhwp-studio` asset 변경이 없다.

### 커밋 메시지

```text
Task #345 Stage 2: upstream sync Docker UID GID 설정 보강
```

## Stage 3. syntax와 env file 생성 조건 검증

### 목표

수정된 workflow의 syntax와 CI용 `.env.docker` 생성 조건을 로컬에서 검증하고, 운영 문서 보강 필요 여부를 판단한다.

### 작업

- workflow YAML parse를 다시 수행한다.
- 관련 shell helper syntax 검증을 수행한다.
- 로컬 임시 디렉터리에서 workflow block과 같은 방식으로 `.env.docker`가 생성되는지 확인한다.
- 생성된 `.env.docker`가 현재 실행 user의 `id -u`, `id -g` 값을 담는지 확인한다.
- `mydocs/manual/ci_workflow_guide.md`를 읽고, 반복 운영 기준으로 UID/GID 기준을 남길 필요가 있으면 짧게 보강한다.
- Stage 3 보고서에 검증 결과와 GitHub-hosted workflow 재실행 계획을 기록한다.

### 예상 변경 파일

- 필요 시 `mydocs/manual/ci_workflow_guide.md`
- `mydocs/working/task_m019_345_stage3.md`

### 검증

```bash
git status --short --branch
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/rhwp-upstream-sync-pr.yml"); puts "parsed"'
bash -n scripts/ci/check-rhwp-upstream-release.sh
bash -n scripts/ci/detect-rhwp-studio-impact.sh
bash -n scripts/ci/write-rhwp-studio-sync-pr-body.sh
bash -n scripts/sync-rhwp-studio.sh
bash -n scripts/verify-rhwp-studio-assets.sh
git diff --check
```

로컬 env file 검증 후보:

```bash
tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/rhwp-task345-env.XXXXXX")"
cd "$tmpdir"
touch .env.docker.example
{
  echo "UID=$(id -u)"
  echo "GID=$(id -g)"
} > .env.docker
cat .env.docker
```

### 완료 기준

- syntax 검증이 통과한다.
- `.env.docker` 생성 결과가 현재 user UID/GID와 일치한다.
- 문서 보강 여부와 이유가 Stage 3 보고서에 기록된다.
- 실제 GitHub-hosted 검증은 Stage 4에서 수행한다.

### 커밋 메시지

```text
Task #345 Stage 3: Docker UID GID env file 검증 정리
```

## Stage 4. 실제 workflow 검증과 자동 PR 확인

### 목표

수정된 workflow를 `devel` ref에서 실제로 실행해 `/app/Cargo.lock` permission denied가 해결됐는지 확인하고, 성공 시 자동 업데이트 후보 PR 생성을 확인한다.

### 작업

- 변경 브랜치를 PR로 올리기 전에는 GitHub Actions가 원격 ref에서 수정 workflow를 실행할 수 없으므로, Stage 4 진입 시점에 검증 방식이 가능한지 재확인한다.
- 원칙적으로 `devel` ref에 수정이 반영된 뒤 다음 명령으로 실제 workflow를 실행한다.

```bash
gh workflow run "rhwp Upstream Sync PR" \
  --repo postmelee/alhangeul-macos \
  --ref devel \
  -f target_tag=v0.7.14 \
  -f force_pr=false \
  -f dry_run=false
```

- 실행 run URL, status, conclusion을 확인한다.
- 성공하면 `automation/rhwp-v0.7.14-studio-sync` branch/PR 생성 여부를 확인한다.
- 실패하면 로그에서 새 실패 원인을 분리해 Stage 4 보고서에 기록하고, 같은 #345 범위에서 해결 가능한지 판단한다.

### 예상 변경 파일

- `mydocs/working/task_m019_345_stage4.md`

### 검증

```bash
gh run view <run_id> --repo postmelee/alhangeul-macos --json status,conclusion,url,headBranch,headSha,jobs
gh pr list --repo postmelee/alhangeul-macos --base devel --head automation/rhwp-v0.7.14-studio-sync --state all --json number,title,state,url,headRefName,baseRefName
git ls-remote --heads origin automation/rhwp-v0.7.14-studio-sync
git diff --check
```

### 완료 기준

- workflow run이 success이거나, 실패 시 `/app/Cargo.lock` permission denied가 재발하지 않았음이 명확하다.
- 성공한 경우 자동 update 후보 PR URL이 Stage 4 보고서에 기록된다.
- 실패한 경우 새 실패 원인과 다음 처리 방향이 Stage 4 보고서에 기록된다.
- 자동 update 후보 PR은 확인만 하고 merge하지 않는다.

### 커밋 메시지

```text
Task #345 Stage 4: upstream sync workflow 실제 검증
```

## Stage 5. 최종 보고와 PR 준비

### 목표

작업 결과와 실제 workflow 검증 결과를 최종 보고서에 정리하고 PR 게시 전 상태를 정리한다.

### 작업

- `mydocs/report/task_m019_345_report.md`를 작성한다.
- `mydocs/orders/20260605.md`의 #345 상태를 `완료`로 갱신한다.
- 실패 run, 수정 지점, 검증 명령 결과, 자동 update 후보 PR 상태, 잔여 확인 항목을 보고서에 기록한다.
- 변경 범위가 workflow와 문서에 한정됐는지 확인한다.
- PR 게시 전 `git status --short --branch`, `git diff --check`, `git diff --name-only devel...HEAD`를 실행한다.

### 예상 변경 파일

- `mydocs/report/task_m019_345_report.md`
- `mydocs/orders/20260605.md`

### 검증

```bash
git status --short --branch
git diff --check
git diff --name-only devel...HEAD
```

### 완료 기준

- 최종 보고서가 작성되고 오늘할일이 완료 처리된다.
- 작업 브랜치에 미커밋 변경이 없다.
- PR 게시 절차로 넘길 준비가 끝난다.

### 커밋 메시지

```text
Task #345 Stage 5 + 최종 보고서: upstream sync Docker 권한 수정 완료
```

## 승인 요청 사항

1. 위 5단계 구현 계획 승인
2. Stage 1에서 실패 경로와 upstream UID/GID 구성을 단계 보고서로 고정하는 작업 승인
3. Stage 2에서 `.github/workflows/rhwp-upstream-sync-pr.yml`의 `.env.docker` 생성 로직만 수정하는 방향 승인
4. Stage 4에서 `dry_run=false` workflow 실행을 실제 검증 기준으로 사용하는 방향 승인
5. workflow 성공으로 생성되는 `automation/rhwp-v0.7.14-studio-sync` PR은 확인만 하고 이번 작업에서 merge하지 않는 방향 승인
