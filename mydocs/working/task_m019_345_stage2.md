# Task M019 #345 Stage 2 완료 보고서

## 단계 목적

`rhwp Upstream Sync PR` workflow의 upstream WASM build 단계에서 CI용 `.env.docker`를 runner UID/GID 기반으로 생성하도록 수정한다.

이번 단계는 workflow source 변경 단계이며, 수정 범위는 `.github/workflows/rhwp-upstream-sync-pr.yml`의 `Build upstream rhwp-studio assets` 단계로 제한했다.

## 확인 시각

- 2026-06-05 17:41 KST

## 산출물

| 파일 | 요약 |
|------|------|
| `.github/workflows/rhwp-upstream-sync-pr.yml` | `.env.docker.example` 복사 대신 runner `id -u`, `id -g` 기반 `.env.docker` 생성 |
| `mydocs/working/task_m019_345_stage2.md` | Stage 2 변경 지점과 검증 결과 정리 |

## 본문 변경 정도 / 본문 무손실 여부

- 제품 source 변경 없음.
- `rhwp-core.lock`, RustBridge dependency 변경 없음.
- bundled `rhwp-studio` asset 변경 없음.
- workflow 변경은 `Build upstream rhwp-studio assets` 단계의 env file 준비 block 교체에 한정했다.

## 변경 내용

기존 block은 `.env.docker`가 없으면 upstream `.env.docker.example`을 그대로 복사했다. upstream example의 기본값은 `UID=1000`, `GID=1000`이라 GitHub-hosted runner workspace owner와 맞지 않을 수 있었다.

이번 단계에서는 다음 block으로 교체했다.

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

동작은 다음과 같다.

| 조건 | 동작 |
|------|------|
| `.env.docker.example` 없음 | upstream layout 이상으로 보고 명확한 오류 출력 후 실패 |
| `.env.docker.example` 있음 | 현재 runner user의 UID/GID로 CI용 `.env.docker` 생성 |
| `.env.docker` 기존 존재 | CI용 값으로 재생성 |

upstream checkout은 workflow가 매번 재생성하는 임시 directory이므로 `.env.docker`를 CI용 값으로 재생성해도 사용자 파일 손실은 없다.

Docker Compose 실행 방식은 기존과 동일하게 유지했다.

```bash
if command -v docker-compose >/dev/null 2>&1; then
  docker-compose --env-file .env.docker run --rm wasm
else
  docker compose --env-file .env.docker run --rm wasm
fi
```

## 검증 결과

```bash
git status --short --branch
```

결과:

```text
## local/task345
 M .github/workflows/rhwp-upstream-sync-pr.yml
```

```bash
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/rhwp-upstream-sync-pr.yml"); puts "parsed"'
```

결과:

```text
Ignoring ffi-1.13.1 because its extensions are not built. Try: gem pristine ffi --version 1.13.1
parsed
```

`ffi` gem 경고는 로컬 Ruby 환경 경고이며, `Psych.parse_file`은 `parsed`를 출력하고 종료 코드 0으로 완료했다.

```bash
git diff --check
```

결과: 통과.

```bash
git diff -- .github/workflows/rhwp-upstream-sync-pr.yml
```

결과: `cd "$upstream_dir"` 직후 env file 준비 block만 runner UID/GID 기반 생성 방식으로 교체됨을 확인했다.

## 완료 기준 확인

| 기준 | 결과 |
|------|------|
| workflow가 runner UID/GID 기반 `.env.docker` 생성 block 포함 | OK |
| workflow YAML parse 통과 | OK |
| `git diff --check` 통과 | OK |
| `rhwp-core.lock` 변경 없음 | OK |
| RustBridge dependency 변경 없음 | OK |
| bundled `rhwp-studio` asset 변경 없음 | OK |

## 잔여 위험

- Stage 2는 workflow syntax와 변경 범위 검증까지 수행했다. 실제 GitHub-hosted runner의 `/app/Cargo.lock` permission denied 해결 여부는 Stage 4의 `dry_run=false` workflow 실행에서 확인해야 한다.
- UID/GID 권한 문제가 해결돼도 upstream Docker build, `wasm-pack`, npm dependency, TypeScript, Vite build에서 다른 실패가 이어질 수 있다.
- Ruby `ffi` 경고는 parse 실패가 아니지만, 로컬 Ruby 환경 경고가 검증 로그에 섞일 수 있다.

## 다음 단계 영향

Stage 3에서는 다음을 수행한다.

1. workflow YAML parse를 다시 확인한다.
2. 관련 shell helper syntax를 확인한다.
3. 로컬 임시 디렉터리에서 workflow block과 같은 방식으로 `.env.docker`가 현재 user UID/GID를 담는지 확인한다.
4. CI 운영 문서 보강 필요 여부를 판단한다.

## 승인 요청

Stage 2 결과를 승인하면 Stage 3 `syntax와 env file 생성 조건 검증`으로 진행한다.
