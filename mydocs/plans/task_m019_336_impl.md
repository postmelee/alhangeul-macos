# Task M019 #336 구현계획서

수행계획서: `mydocs/plans/task_m019_336.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #336 `rhwp Upstream Sync PR`가 upstream WASM 빌드 전 `.env.docker` 누락으로 실패하는 문제 수정
- 마일스톤: M019 (`v0.1.2`)
- 브랜치: `local/task336`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac`
- 기준 브랜치: `devel`
- 목표: upstream `edwardkim/rhwp` checkout root에 `.env.docker.example`만 있는 경우에도 sync PR workflow가 CI용 `.env.docker`를 준비하고 WASM/rhwp-studio build 단계로 진행하게 한다.

## 확인된 현재 상태

2026-06-05 기준 확인 결과:

- `rhwp Upstream Sync PR` run `26996434439`는 scheduled event로 실행됐고, `Create rhwp-studio sync PR candidate` job에서 실패했다.
- workflow는 base branch `devel`을 checkout한 뒤 upstream target release를 `v0.7.14`로 해석했다.
- bundled manifest의 current release는 `v0.7.13`, current commit은 `b3e16ef212af81ef37d973ddb86d6816d3804642`였다.
- target release `v0.7.14`의 resolved commit은 `fb885547538dc6572a12722dd2991b553e082e0e`였다.
- `Detect rhwp-studio impact` 단계는 `has_viewer_impact=true`, `impact_reason_count=171`을 출력했다.
- `Build upstream rhwp-studio assets` 단계는 `scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.14` 통과 후 upstream root에서 Docker Compose를 실행하려다 실패했다.
- 직접 실패 메시지는 `couldn't find env file: .../build.noindex/rhwp-upstream/.env.docker`였다.
- upstream `edwardkim/rhwp`의 `v0.7.13`, `v0.7.14` tree에는 `.env.docker`가 없고 `.env.docker.example`과 `docker-compose.yml`이 있다.
- `.env.docker.example`은 `.env.docker`로 복사한 뒤 `docker compose --env-file .env.docker run --rm wasm`를 실행하는 사용법을 안내한다.
- 현재 `.github/workflows/rhwp-upstream-sync-pr.yml`은 `cd "$upstream_dir"` 직후 `.env.docker` 준비 없이 `docker-compose --env-file .env.docker run --rm wasm` 또는 `docker compose --env-file .env.docker run --rm wasm`를 실행한다.

## 구현 원칙

- 수정은 `.github/workflows/rhwp-upstream-sync-pr.yml`의 `Build upstream rhwp-studio assets` 단계에 한정한다.
- upstream checkout, impact detection, PR 생성, bundled asset sync 로직은 이번 단계에서 변경하지 않는다.
- `.env.docker`가 이미 있으면 그대로 사용한다.
- `.env.docker`가 없고 `.env.docker.example`이 있으면 `cp .env.docker.example .env.docker`로 준비한다.
- `.env.docker`와 `.env.docker.example`이 모두 없으면 원인을 알 수 있는 오류 메시지를 출력하고 실패한다.
- Docker Compose 명령 선택(`docker-compose` 우선, 없으면 `docker compose`)과 후속 `npm ci`, `npx tsc`, `npx vite build --base ./` 흐름은 유지한다.
- `rhwp-core.lock`, RustBridge dependency, bundled `rhwp-studio` asset은 갱신하지 않는다.
- 실제 자동 PR 생성, release publish, signing/notarization, Homebrew 배포는 수행하지 않는다.

## Stage 1. 실패 경로와 env file 사전 조건 확정

### 목표

실패 run, workflow 명령, upstream Docker 관련 파일을 단계 보고서에 고정하고 구현 지점이 `Build upstream rhwp-studio assets` 단계임을 확정한다.

### 작업

- run `26996434439`의 실패 단계와 직접 오류를 기록한다.
- `.github/workflows/rhwp-upstream-sync-pr.yml`의 build 단계 명령을 확인한다.
- upstream `v0.7.14`의 `.env.docker.example`, `docker-compose.yml`, `.env.docker` 존재 여부를 확인한다.
- `.env.docker.example`을 `.env.docker`로 복사하는 방식이 upstream 안내와 맞는지 기록한다.
- Stage 2에서 수정할 조건 분기와 오류 메시지 방향을 확정한다.

### 예상 변경 파일

- `mydocs/working/task_m019_336_stage1.md`

### 검증

```bash
git status --short --branch
rg -n "Build upstream rhwp-studio assets|\\.env\\.docker|docker compose|docker-compose" .github/workflows/rhwp-upstream-sync-pr.yml
gh api 'repos/edwardkim/rhwp/git/trees/v0.7.14?recursive=1' --jq '.tree[] | select(.path == ".env.docker.example" or .path == ".env.docker" or .path == "docker-compose.yml") | .path'
git diff --check
```

### 완료 기준

- Stage 1 보고서에 실패 명령, 실패 메시지, upstream file 존재 여부, Stage 2 구현 조건이 기록된다.
- source/workflow 구현 변경은 아직 없다.

### 커밋 메시지

```text
Task #336 Stage 1: upstream sync env file 실패 경로 정리
```

## Stage 2. workflow env file 준비 로직 구현

### 목표

`Build upstream rhwp-studio assets` 단계가 upstream `.env.docker.example`을 CI용 `.env.docker`로 준비한 뒤 Docker Compose를 실행하게 한다.

### 작업

- `.github/workflows/rhwp-upstream-sync-pr.yml`을 수정한다.
  - `cd "$upstream_dir"` 직후 `.env.docker` 준비 block을 추가한다.
  - `.env.docker`가 있으면 그대로 둔다.
  - `.env.docker`가 없고 `.env.docker.example`이 있으면 복사한다.
  - 둘 다 없으면 `ERROR: upstream rhwp is missing .env.docker and .env.docker.example` 같은 명확한 오류를 출력하고 `exit 1`한다.
- Docker Compose 실행 block은 기존 command selection을 유지한다.
- 변경 후 workflow YAML parse와 diff check를 실행한다.
- Stage 2 보고서에 변경 지점과 검증 결과를 기록한다.

### 예상 변경 파일

- `.github/workflows/rhwp-upstream-sync-pr.yml`
- `mydocs/working/task_m019_336_stage2.md`

### 검증

```bash
git status --short --branch
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/rhwp-upstream-sync-pr.yml"); puts "parsed"'
git diff --check
```

### 완료 기준

- workflow가 `.env.docker` 준비 조건 분기를 포함한다.
- workflow YAML parse와 diff check가 통과한다.
- `rhwp-core.lock`, RustBridge dependency, bundled `rhwp-studio` asset 변경이 없다.

### 커밋 메시지

```text
Task #336 Stage 2: upstream sync env file 준비 로직 추가
```

## Stage 3. 검증과 CI 운영 문서 보강

### 목표

수정된 workflow의 syntax와 build 사전 조건을 검증하고, 장기 운영 문서에 남길 필요가 있는 내용을 정리한다.

### 작업

- workflow YAML parse를 다시 수행한다.
- helper shell syntax 검증을 수행한다.
- upstream `v0.7.14` tree에 `.env.docker.example`과 `docker-compose.yml`이 있고 `.env.docker`가 없음을 재확인한다.
- 로컬 임시 디렉터리에서 `.env.docker.example`만 있는 경우 준비 block과 같은 조건이 `.env.docker`를 생성하는지 확인한다.
- `mydocs/manual/ci_workflow_guide.md`를 읽고, 반복 운영 기준으로 남길 만한 내용이 있으면 짧게 보강한다. 특정 run 로그의 상세 사건 기록은 manual에 누적하지 않는다.
- Stage 3 보고서에 검증 결과와 GitHub-hosted workflow 재실행 잔여 확인 항목을 기록한다.

### 예상 변경 파일

- 필요 시 `mydocs/manual/ci_workflow_guide.md`
- `mydocs/working/task_m019_336_stage3.md`

### 검증

```bash
git status --short --branch
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/rhwp-upstream-sync-pr.yml"); puts "parsed"'
bash -n scripts/ci/check-rhwp-upstream-release.sh
bash -n scripts/ci/detect-rhwp-studio-impact.sh
bash -n scripts/ci/write-rhwp-studio-sync-pr-body.sh
bash -n scripts/sync-rhwp-studio.sh
bash -n scripts/verify-rhwp-studio-assets.sh
gh api 'repos/edwardkim/rhwp/git/trees/v0.7.14?recursive=1' --jq '.tree[] | select(.path == ".env.docker.example" or .path == ".env.docker" or .path == "docker-compose.yml") | .path'
git diff --check
```

### 완료 기준

- syntax 검증이 통과한다.
- `.env.docker.example` 기반 준비 조건이 로컬에서 확인된다.
- 문서 보강 여부와 이유가 Stage 3 보고서에 기록된다.
- 실제 GitHub-hosted Docker/WASM build는 workflow_dispatch 또는 다음 schedule에서 확인할 잔여 항목으로 남긴다.

### 커밋 메시지

```text
Task #336 Stage 3: upstream sync env file 검증 정리
```

## Stage 4. 최종 보고와 PR 준비

### 목표

작업 결과와 검증 한계를 최종 보고서에 정리하고 PR 게시 전 상태를 정리한다.

### 작업

- `mydocs/report/task_m019_336_report.md`를 작성한다.
- `mydocs/orders/20260605.md`의 #336 상태를 `완료`로 갱신한다.
- 실패 run, 수정 지점, 검증 명령 결과, 잔여 확인 항목을 보고서에 기록한다.
- 변경 범위가 workflow와 문서에 한정됐는지 확인한다.
- PR 게시 전 `git status --short --branch`, `git diff --check`, `git diff --name-only devel...HEAD`를 실행한다.

### 예상 변경 파일

- `mydocs/report/task_m019_336_report.md`
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
Task #336 Stage 4 + 최종 보고서: upstream sync env file 수정 완료
```

## 승인 요청 사항

1. 위 4단계 구현 계획 승인
2. Stage 1에서 실패 경로와 env file 사전 조건을 단계 보고서로 고정하는 작업 승인
3. Stage 2에서 `.github/workflows/rhwp-upstream-sync-pr.yml`의 `Build upstream rhwp-studio assets` 단계만 수정하는 방향 승인
4. Stage 3에서 `ci_workflow_guide.md`는 반복 운영 기준으로 필요한 경우에만 짧게 보강하는 방향 승인
