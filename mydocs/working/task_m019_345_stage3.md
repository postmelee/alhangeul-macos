# Task M019 #345 Stage 3 완료 보고서

## 단계 목적

`rhwp Upstream Sync PR` workflow의 syntax와 CI용 `.env.docker` 생성 조건을 로컬에서 검증하고, 반복 운영 시 참고할 CI 문서 설명을 현재 동작에 맞게 보강한다.

이번 단계는 로컬 검증과 운영 문서 보강 단계이며, workflow source는 Stage 2 커밋 이후 추가로 변경하지 않았다.

## 확인 시각

- 2026-06-06 17:13 KST

## 산출물

| 파일 | 요약 |
|------|------|
| `mydocs/manual/ci_workflow_guide.md` | upstream WASM build의 `.env.docker` 준비 설명을 runner UID/GID 생성 방식으로 갱신 |
| `mydocs/orders/20260606.md` | 날짜 변경에 맞춰 #345 Stage 3 진행 상태 기록 |
| `mydocs/working/task_m019_345_stage3.md` | Stage 3 검증 결과와 Stage 4 검증 계획 정리 |

## 본문 변경 정도 / 본문 무손실 여부

- 제품 source 변경 없음.
- workflow 추가 변경 없음.
- `rhwp-core.lock`, RustBridge dependency 변경 없음.
- bundled `rhwp-studio` asset 변경 없음.
- CI 운영 문서는 #336에서 남긴 `.env.docker.example` 복사 설명을 Stage 2의 runner UID/GID 생성 방식에 맞게 한 줄 보정했다.

## 문서 보강 판단

`mydocs/manual/ci_workflow_guide.md`에는 기존에 다음 취지의 설명이 남아 있었다.

```text
checkout에 .env.docker가 없고 .env.docker.example만 있으면 workflow가 example을 복사해 CI용 env file을 준비한다.
```

Stage 2 이후 실제 동작은 example 복사가 아니라 `.env.docker.example` 존재 확인 후 runner의 `id -u`, `id -g` 값으로 `.env.docker`를 생성하는 방식이다. 반복 운영 시 같은 실패를 다시 분석하지 않도록 운영 문서의 설명을 현재 동작에 맞게 수정했다.

## 검증 결과

```bash
git status --short --branch
```

결과:

```text
## local/task345
```

```bash
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/rhwp-upstream-sync-pr.yml"); puts "parsed"'
```

결과:

```text
Ignoring ffi-1.13.1 because its extensions are not built. Try: gem pristine ffi --version 1.13.1
parsed
```

`ffi` gem 경고는 로컬 Ruby 환경 경고이며, YAML parse는 종료 코드 0으로 완료했다.

관련 shell helper syntax 검증:

```bash
bash -n scripts/ci/check-rhwp-upstream-release.sh
bash -n scripts/ci/detect-rhwp-studio-impact.sh
bash -n scripts/ci/write-rhwp-studio-sync-pr-body.sh
bash -n scripts/sync-rhwp-studio.sh
bash -n scripts/verify-rhwp-studio-assets.sh
```

결과: 모두 종료 코드 0으로 통과했다.

로컬 env file 생성 스모크:

```bash
tmpdir="$(mktemp -d "${TMPDIR:-/private/tmp}/rhwp-task345-env.XXXXXX")"
cd "$tmpdir"
touch .env.docker.example
{
  echo "UID=$(id -u)"
  echo "GID=$(id -g)"
} > .env.docker
cat .env.docker
printf 'current_uid=%s\n' "$(id -u)"
printf 'current_gid=%s\n' "$(id -g)"
printf 'tmpdir=%s\n' "$tmpdir"
```

결과:

```text
UID=501
GID=20
current_uid=501
current_gid=20
tmpdir=/var/folders/c2/y83wcw894j1d5bv4_lhqmvg80000gn/T//rhwp-task345-env.hQF5ST
```

`.env.docker`에 기록된 `UID`/`GID`가 현재 실행 user의 `id -u`, `id -g` 결과와 일치함을 확인했다.

```bash
git diff --check
```

결과: 통과.

## 완료 기준 확인

| 기준 | 결과 |
|------|------|
| workflow YAML parse 통과 | OK |
| 관련 shell helper syntax 검증 통과 | OK |
| `.env.docker` 생성 결과가 현재 user UID/GID와 일치 | OK |
| 운영 문서 보강 필요 여부 판단 | OK, 보강함 |
| `git diff --check` 통과 | OK |
| `rhwp-core.lock` 변경 없음 | OK |
| bundled `rhwp-studio` asset 변경 없음 | OK |

## 잔여 위험

- `dry_run=true`는 target 조회와 impact 분류까지만 수행하고 upstream WASM build, push, PR 생성을 생략한다. 따라서 이번 `/app/Cargo.lock` permission denied 수정의 실검증 기준으로는 충분하지 않다.
- 실제 GitHub-hosted runner에서 권한 오류가 해결됐는지는 Stage 4의 `dry_run=false` workflow 실행으로 확인해야 한다.
- 권한 오류가 해결된 뒤에도 upstream Docker build, `wasm-pack`, npm dependency, TypeScript, Vite build에서 별도 실패가 이어질 수 있다.

## 다음 단계 영향

Stage 4에서는 원격 ref에서 수정 workflow를 실행할 수 있는 검증 경로를 재확인한 뒤, 실제 `rhwp Upstream Sync PR` 실행 결과와 자동 업데이트 후보 PR 생성 여부를 확인한다.

## 승인 요청

Stage 3 결과를 승인하면 Stage 4 `실제 workflow 검증과 자동 PR 확인`으로 진행한다.
