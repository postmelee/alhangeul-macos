# Task M019 #336 Stage 2 완료 보고서

## 단계 목적

`rhwp Upstream Sync PR` workflow의 `Build upstream rhwp-studio assets` 단계에 upstream `.env.docker` 준비 로직을 추가한다.

이번 단계는 workflow source 변경 단계이며, 수정 범위는 `.github/workflows/rhwp-upstream-sync-pr.yml`의 upstream build 단계로 제한했다.

## 확인 시각

- 2026-06-05 16:50 KST

## 산출물

| 파일 | 요약 |
|------|------|
| `.github/workflows/rhwp-upstream-sync-pr.yml` | upstream root에서 `.env.docker`가 없으면 `.env.docker.example`을 복사하고, 둘 다 없으면 명확한 오류로 실패하도록 보강 |
| `mydocs/working/task_m019_336_stage2.md` | Stage 2 변경 지점과 검증 결과 정리 |

## 본문 변경 정도 / 본문 무손실 여부

- 제품 source 변경 없음.
- `rhwp-core.lock`, RustBridge dependency 변경 없음.
- bundled `rhwp-studio` asset 변경 없음.
- workflow 변경은 `Build upstream rhwp-studio assets` 단계의 env file 준비 block 추가에 한정했다.

## 변경 내용

`cd "$upstream_dir"` 직후 다음 조건 분기를 추가했다.

```bash
if [ ! -f .env.docker ]; then
  if [ -f .env.docker.example ]; then
    cp .env.docker.example .env.docker
  else
    echo "ERROR: upstream rhwp is missing .env.docker and .env.docker.example" >&2
    exit 1
  fi
fi
```

동작은 다음과 같다.

| 조건 | 동작 |
|------|------|
| `.env.docker` 존재 | 기존 파일을 그대로 사용 |
| `.env.docker` 없음, `.env.docker.example` 존재 | `.env.docker.example`을 `.env.docker`로 복사 |
| 둘 다 없음 | 원인을 알 수 있는 오류를 stderr로 출력하고 실패 |

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
## local/task336
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

결과: `cd "$upstream_dir"` 직후 `.env.docker` 준비 block만 추가됨을 확인했다.

## 완료 기준 확인

| 기준 | 결과 |
|------|------|
| workflow가 `.env.docker` 준비 조건 분기를 포함 | OK |
| workflow YAML parse 통과 | OK |
| `git diff --check` 통과 | OK |
| `rhwp-core.lock` 변경 없음 | OK |
| RustBridge dependency 변경 없음 | OK |
| bundled `rhwp-studio` asset 변경 없음 | OK |

## 잔여 위험

- Stage 2는 workflow syntax와 변경 범위 검증까지 수행했다. 실제 GitHub-hosted Docker/WASM build는 Stage 3의 추가 검증과 PR 이후 workflow 재실행 또는 다음 schedule에서 확인해야 한다.
- `.env.docker` 준비 이후에도 upstream Docker image build, `wasm-pack`, `npm ci`, TypeScript, Vite build 단계에서 별도 실패가 드러날 수 있다.
- Ruby `ffi` 경고는 parse 실패가 아니지만, 로컬 Ruby 환경 경고가 검증 로그에 섞일 수 있다.

## 다음 단계 영향

Stage 3에서는 다음을 수행한다.

1. workflow YAML parse를 다시 확인한다.
2. 관련 shell helper syntax를 확인한다.
3. upstream `v0.7.14`의 `.env.docker.example`, `docker-compose.yml`, `.env.docker` 조건을 재확인한다.
4. 로컬 임시 디렉터리에서 `.env.docker.example`만 있을 때 준비 block과 같은 조건이 `.env.docker`를 생성하는지 확인한다.
5. `ci_workflow_guide.md` 문서 보강 필요 여부를 판단한다.

## 승인 요청

Stage 2 결과를 승인하면 Stage 3 `검증과 CI 운영 문서 보강`으로 진행한다.
