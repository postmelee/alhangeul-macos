# Task M019 #336 Stage 1 완료 보고서

## 단계 목적

`rhwp Upstream Sync PR` workflow의 `.env.docker` 누락 실패 경로를 확인하고, Stage 2에서 적용할 env file 준비 로직의 조건을 확정한다.

이번 단계는 조사와 보고 단계이며 source, workflow, lock, bundled asset은 변경하지 않았다.

## 확인 시각

- 2026-06-05 16:48 KST

## 산출물

| 파일 | 요약 |
|------|------|
| `mydocs/working/task_m019_336_stage1.md` | 실패 run, workflow build 명령, upstream Docker env file 사전 조건, Stage 2 구현 조건 정리 |

참조한 기존 파일:

| 파일 | 확인 내용 |
|------|----------|
| `.github/workflows/rhwp-upstream-sync-pr.yml` | `Build upstream rhwp-studio assets` 단계가 upstream root에서 `.env.docker`를 바로 요구함 |
| `mydocs/plans/task_m019_336.md` | #336 수행 범위와 제외 범위 확인 |
| `mydocs/plans/task_m019_336_impl.md` | Stage 1 완료 기준과 Stage 2 구현 방향 확인 |

## 본문 변경 정도 / 본문 무손실 여부

- 제품 source 변경 없음.
- workflow 변경 없음.
- `rhwp-core.lock`, RustBridge dependency 변경 없음.
- bundled `rhwp-studio` asset 변경 없음.
- 신규 단계 보고서만 추가하고 오늘할일 비고를 현재 단계에 맞게 갱신했다.

## 확인한 실패 경로

- 실패 run: `26996434439`
- workflow: `rhwp Upstream Sync PR`
- event: `schedule`
- head branch: `main`
- head SHA: `d4e3b21e2ea0736353aa999e29eb1ff8ac2091a8`
- job: `Create rhwp-studio sync PR candidate`
- 실패 step: `Build upstream rhwp-studio assets`
- job URL: `https://github.com/postmelee/alhangeul-macos/actions/runs/26996434439/job/79667048375`

해당 run의 앞 단계 상태는 다음과 같았다.

| 단계 | 결과 | 의미 |
|------|------|------|
| `Resolve current and target rhwp release` | success | target release가 `v0.7.14`로 해석됨 |
| `Check out upstream rhwp` | success | #287의 LFS smudge skip 보강 이후 upstream checkout은 통과 |
| `Detect rhwp-studio impact` | success | viewer 영향 있음으로 판정 |
| `Check existing automation PR` | success | 기존 automation branch/PR 없음 |
| `Build upstream rhwp-studio assets` | failure | upstream root의 `.env.docker` 누락으로 Docker Compose 실행 전 실패 |

이전 분석에서 확인한 실패 로그의 직접 오류는 다음과 같다.

```text
couldn't find env file: /home/runner/work/alhangeul-macos/alhangeul-macos/build.noindex/rhwp-upstream/.env.docker
```

## 현재 workflow build 명령

`Build upstream rhwp-studio assets` 단계는 `cd "$upstream_dir"` 이후 다음 명령을 실행한다.

```bash
if command -v docker-compose >/dev/null 2>&1; then
  docker-compose --env-file .env.docker run --rm wasm
else
  docker compose --env-file .env.docker run --rm wasm
fi
```

즉 Docker Compose 실행 전 `.env.docker`를 준비하는 단계가 없다. `--env-file .env.docker` 옵션 때문에 해당 파일이 없으면 Compose가 즉시 실패한다.

## upstream env file 사전 조건

GitHub API로 upstream `edwardkim/rhwp`의 `v0.7.14` tree를 확인한 결과는 다음과 같다.

```text
.env.docker.example
docker-compose.yml
```

`.env.docker`는 tracked file로 존재하지 않는다.

upstream `v0.7.14`의 `.env.docker.example`은 다음 사용법을 안내한다.

```text
Copy this file to .env.docker before running WASM build:
  cp .env.docker.example .env.docker

Usage:
  docker compose --env-file .env.docker run --rm wasm
```

따라서 CI에서 `.env.docker.example`을 `.env.docker`로 복사한 뒤 기존 Docker Compose 명령을 실행하는 방식은 upstream이 안내한 사용법과 일치한다.

## Stage 2 구현 조건

Stage 2 수정 범위는 `.github/workflows/rhwp-upstream-sync-pr.yml`의 `Build upstream rhwp-studio assets` 단계에 한정한다.

`cd "$upstream_dir"` 직후 다음 조건 분기를 추가한다.

1. `.env.docker`가 이미 있으면 그대로 사용한다.
2. `.env.docker`가 없고 `.env.docker.example`이 있으면 `cp .env.docker.example .env.docker`를 실행한다.
3. 둘 다 없으면 `ERROR: upstream rhwp is missing .env.docker and .env.docker.example`처럼 원인을 알 수 있는 메시지를 stderr로 출력하고 `exit 1`한다.

Docker Compose 실행 방식은 기존 우선순위를 유지한다.

1. `docker-compose` 명령이 있으면 `docker-compose --env-file .env.docker run --rm wasm`
2. 없으면 `docker compose --env-file .env.docker run --rm wasm`

## 검증 결과

```bash
git status --short --branch
```

결과: `## local/task336`, Stage 1 조사 전 미커밋 변경 없음.

```bash
rg -n "Build upstream rhwp-studio assets|\\.env\\.docker|docker compose|docker-compose" .github/workflows/rhwp-upstream-sync-pr.yml
```

결과:

```text
282:      - name: Build upstream rhwp-studio assets
296:          if command -v docker-compose >/dev/null 2>&1; then
297:            docker-compose --env-file .env.docker run --rm wasm
299:            docker compose --env-file .env.docker run --rm wasm
```

```bash
gh api 'repos/edwardkim/rhwp/git/trees/v0.7.14?recursive=1' --jq '.tree[] | select(.path == ".env.docker.example" or .path == ".env.docker" or .path == "docker-compose.yml") | .path'
```

결과:

```text
.env.docker.example
docker-compose.yml
```

```bash
gh api 'repos/edwardkim/rhwp/contents/.env.docker.example?ref=v0.7.14' --jq '.content | @base64d'
```

결과: `.env.docker.example`이 `.env.docker`로 복사한 뒤 `docker compose --env-file .env.docker run --rm wasm`를 실행하라고 안내함.

```bash
gh run view 26996434439 -R postmelee/alhangeul-macos --json workflowName,event,conclusion,status,url,headBranch,headSha,jobs
```

결과:

- workflow conclusion: `failure`
- failed job: `Create rhwp-studio sync PR candidate`
- failed step: `Build upstream rhwp-studio assets`
- upstream checkout과 impact detection은 성공

## 잔여 위험

- Stage 1은 조사와 적용 조건 확정만 수행했으므로 CI 실패는 아직 수정되지 않았다.
- `.env.docker` 준비 이후에도 upstream Docker image build, `wasm-pack`, `npm ci`, TypeScript, Vite build 단계에서 별도 실패가 드러날 수 있다.
- GitHub-hosted runner의 Docker Compose 버전 차이는 로컬에서 완전히 대체할 수 없다.
- 실제 자동 sync PR 생성은 repository write 권한과 upstream build 전체 성공이 필요하므로 PR 이후 workflow 재실행 또는 다음 schedule에서 확인해야 한다.

## 다음 단계 영향

Stage 2에서는 실제 workflow 변경을 수행한다.

1. `cd "$upstream_dir"` 직후 `.env.docker` 준비 block을 추가한다.
2. `.env.docker.example`이 없을 때 명확한 오류를 출력하게 한다.
3. workflow YAML parse와 `git diff --check`를 실행한다.
4. `rhwp-core.lock`, RustBridge dependency, bundled `rhwp-studio` asset이 변경되지 않았음을 확인한다.

## 승인 요청

Stage 1 결과를 승인하면 Stage 2 `workflow env file 준비 로직 구현`으로 진행한다.
