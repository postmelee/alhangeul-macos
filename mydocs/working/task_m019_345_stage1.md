# Task M019 #345 Stage 1 완료 보고서

## 단계 목적

`rhwp Upstream Sync PR` workflow의 upstream WASM build 권한 실패 경로를 확인하고, Stage 2에서 적용할 runner UID/GID 기반 `.env.docker` 생성 전략을 확정한다.

이번 단계는 조사와 보고 단계이며 source, workflow, lock, bundled asset은 변경하지 않았다.

## 확인 시각

- 2026-06-05 17:35 KST

## 산출물

| 파일 | 요약 |
|------|------|
| `mydocs/working/task_m019_345_stage1.md` | 실패 run, upstream Docker UID/GID 구성, Stage 2 구현 전략 정리 |

참조한 기존 파일:

| 파일 | 확인 내용 |
|------|----------|
| `.github/workflows/rhwp-upstream-sync-pr.yml` | 현재 build 단계가 #336에서 추가한 `.env.docker.example` 복사 로직을 사용 |
| `mydocs/plans/task_m019_345.md` | #345 수행 범위와 제외 범위 확인 |
| `mydocs/plans/task_m019_345_impl.md` | Stage 1 완료 기준과 Stage 2 구현 방향 확인 |

## 본문 변경 정도 / 본문 무손실 여부

- 제품 source 변경 없음.
- workflow 변경 없음.
- `rhwp-core.lock`, RustBridge dependency 변경 없음.
- bundled `rhwp-studio` asset 변경 없음.
- 신규 단계 보고서만 추가하고 오늘할일 비고를 현재 단계에 맞게 갱신했다.

## 확인한 실패 경로

- 실패 run: `27004087710`
- workflow: `rhwp Upstream Sync PR`
- event: `workflow_dispatch`
- ref: `devel`
- head SHA: `1cf1db9303a9254dc7fb65cd30ee6d9320ec4c68`
- 입력: `target_tag=v0.7.14`, `force_pr=false`, `dry_run=false`
- job: `Create rhwp-studio sync PR candidate`
- 실패 step: `Build upstream rhwp-studio assets`
- job URL: `https://github.com/postmelee/alhangeul-macos/actions/runs/27004087710/job/79691263684`

run의 주요 단계 상태는 다음과 같았다.

| 단계 | 결과 | 의미 |
|------|------|------|
| `Check out base branch` | success | `devel` ref의 merge commit checkout |
| `Verify helper syntax` | success | workflow helper syntax 정상 |
| `Resolve current and target rhwp release` | success | target `v0.7.14` 해석 |
| `Check out upstream rhwp` | success | upstream checkout 통과 |
| `Detect rhwp-studio impact` | success | viewer/WASM/core 영향 있음 |
| `Check existing automation PR` | success | 기존 automation branch/PR 없음 |
| `Build upstream rhwp-studio assets` | failure | Docker container 내부 `/app/Cargo.lock` 권한 실패 |
| `Sync bundled rhwp-studio and create PR` | skipped | build 실패로 미실행 |

## 실패 로그 핵심

#336에서 해결한 `.env.docker` 누락 오류는 재발하지 않았다. build 단계는 Docker image build와 `wasm-pack` 설치까지 진행했다.

```text
Installed package `wasm-pack v0.15.0` (executable `wasm-pack`)
#7 DONE 73.2s
```

이후 Docker image build 중 upstream example의 기본 UID/GID가 반영된 builder user 생성이 로그에 남았다.

```text
groupadd -g 1000 builder ... && useradd -m -u 1000 -g 1000 builder
```

최종 실패는 `cargo metadata`가 bind-mounted `/app/Cargo.lock`을 쓰지 못한 권한 오류였다.

```text
error: failed to write /app/Cargo.lock

Caused by:
  failed to open: /app/Cargo.lock

Caused by:
  Permission denied (os error 13)
```

## upstream Docker UID/GID 구성

upstream `v0.7.14`의 `.env.docker.example` 내용:

```text
# Docker compose environment file
# Copy this file to .env.docker before running WASM build:
#   cp .env.docker.example .env.docker
#
# Usage:
#   docker compose --env-file .env.docker run --rm wasm

# 호스트 사용자 UID/GID (빌드 산출물 소유권 일치)
UID=1000
GID=1000
```

upstream `docker-compose.yml`의 `wasm` service는 `UID`/`GID`를 build args로 넘기고, `.env.docker`를 service env file로 사용한다.

```yaml
wasm:
  build:
    context: .
    args:
      UID: ${UID:-1000}
      GID: ${GID:-1000}
  env_file: .env.docker
  volumes:
    - .:/app
    - cargo-cache:/home/builder/.cargo/registry
    - cargo-bin:/home/builder/.cargo/bin
    - wasm-pack-cache:/home/builder/.cache/.wasm-pack
  working_dir: /app
  command: wasm-pack build --target web
```

따라서 `.env.docker`의 UID/GID는 container 안에서 `/app` bind mount에 쓰는 user와 host checkout owner를 맞추기 위한 값이다. CI에서 upstream example을 그대로 복사하면 `1000:1000`이 고정되어 GitHub-hosted runner workspace의 실제 owner와 어긋날 수 있다.

## Stage 2 구현 전략

Stage 2 수정 범위는 `.github/workflows/rhwp-upstream-sync-pr.yml`의 `Build upstream rhwp-studio assets` 단계에 한정한다.

`cd "$upstream_dir"` 직후 `.env.docker` 준비 block을 다음 전략으로 교체한다.

1. `.env.docker.example`이 없으면 upstream layout 이상을 알리는 오류를 출력하고 실패한다.
2. CI용 `.env.docker`는 workflow가 명시적으로 생성한다.
3. 생성 값은 현재 runner user의 UID/GID를 사용한다.

후보 구현:

```bash
if [ ! -f .env.docker.example ]; then
  echo "ERROR: upstream rhwp is missing .env.docker.example" >&2
  exit 1
fi

{
  echo "UID=$(id -u)"
  echo "GID=$(id -g)"
} > .env.docker
```

이 방식은 upstream example의 고정 `UID=1000`, `GID=1000`을 가져오지 않고, GitHub-hosted runner의 checkout owner와 container builder user를 맞춘다.

Docker Compose 실행 방식은 기존 우선순위를 유지한다.

1. `docker-compose` 명령이 있으면 `docker-compose --env-file .env.docker run --rm wasm`
2. 없으면 `docker compose --env-file .env.docker run --rm wasm`

## 검증 결과

```bash
git status --short --branch
```

결과: `## local/task345`, Stage 1 조사 전 미커밋 변경 없음.

```bash
gh run view 27004087710 --repo postmelee/alhangeul-macos --json status,conclusion,url,headBranch,headSha,jobs
```

결과:

- status: `completed`
- conclusion: `failure`
- headBranch: `devel`
- failed step: `Build upstream rhwp-studio assets`

```bash
gh api 'repos/edwardkim/rhwp/contents/.env.docker.example?ref=v0.7.14' --jq '.content | @base64d'
```

결과: `UID=1000`, `GID=1000` 기본값 확인.

```bash
gh api 'repos/edwardkim/rhwp/contents/docker-compose.yml?ref=v0.7.14' --jq '.content | @base64d'
```

결과: `UID`/`GID`가 build args로 사용되고, `env_file: .env.docker`, `.:/app` bind mount가 설정됨을 확인.

```bash
gh run view 27004087710 --repo postmelee/alhangeul-macos --log --job 79691263684 | rg -C 3 "failed to write /app/Cargo.lock|Permission denied|couldn't find env file|wasm-pack v0.15.0|Installed package|DONE 73.2s"
```

결과:

- `wasm-pack v0.15.0` 설치 완료
- Docker image build 중 `groupadd -g 1000`, `useradd -u 1000` 확인
- `/app/Cargo.lock` permission denied 확인
- `couldn't find env file` 오류 없음

```bash
git diff --check
```

결과: 통과.

## 잔여 위험

- Stage 1은 조사와 구현 전략 확정만 수행했으므로 CI 실패는 아직 수정되지 않았다.
- runner UID/GID 기반 env file로 권한 문제가 해결돼도 upstream Docker build, `wasm-pack`, npm dependency, TypeScript, Vite build에서 다른 실패가 이어질 수 있다.
- `dry_run=true`는 build를 건너뛰므로 이번 권한 문제의 실제 검증 기준이 될 수 없다.
- workflow 성공 시 자동 update 후보 PR이 생성될 수 있다. 해당 PR은 별도로 검토하고 이번 작업에서 merge하지 않는다.

## 다음 단계 영향

Stage 2에서는 실제 workflow 변경을 수행한다.

1. `.env.docker.example` 존재 확인을 유지한다.
2. `.env.docker`는 example 복사 대신 runner `id -u`, `id -g` 값으로 생성한다.
3. Docker Compose 실행 block은 유지한다.
4. workflow YAML parse와 `git diff --check`를 실행한다.
5. `rhwp-core.lock`, RustBridge dependency, bundled `rhwp-studio` asset이 변경되지 않았음을 확인한다.

## 승인 요청

Stage 1 결과를 승인하면 Stage 2 `workflow UID/GID env file 생성 로직 구현`으로 진행한다.
