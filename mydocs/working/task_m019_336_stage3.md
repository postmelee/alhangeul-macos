# Task M019 #336 Stage 3 완료 보고서

## 단계 목적

Stage 2에서 추가한 `.env.docker` 준비 로직의 syntax와 사전 조건을 검증하고, 장기 운영 문서에 필요한 반복 기준을 보강한다.

이번 단계는 검증과 문서 정리 단계이며, workflow source 추가 변경은 수행하지 않았다.

## 확인 시각

- 2026-06-05 16:54 KST

## 산출물

| 파일 | 요약 |
|------|------|
| `mydocs/manual/ci_workflow_guide.md` | upstream sync PR의 WASM build env file 준비 기준을 반복 운영 조건으로 한 줄 보강 |
| `mydocs/working/task_m019_336_stage3.md` | Stage 3 검증 결과와 잔여 확인 항목 정리 |

참조한 기존 파일:

| 파일 | 확인 내용 |
|------|----------|
| `.github/workflows/rhwp-upstream-sync-pr.yml` | Stage 2에서 추가한 `.env.docker` 준비 block 유지 |
| `scripts/ci/check-rhwp-upstream-release.sh` | shell syntax 검증 |
| `scripts/ci/detect-rhwp-studio-impact.sh` | shell syntax 검증 |
| `scripts/ci/write-rhwp-studio-sync-pr-body.sh` | shell syntax 검증 |
| `scripts/sync-rhwp-studio.sh` | shell syntax 검증 |
| `scripts/verify-rhwp-studio-assets.sh` | shell syntax 검증 |

## 본문 변경 정도 / 본문 무손실 여부

- 제품 source 변경 없음.
- workflow source 추가 변경 없음.
- `rhwp-core.lock`, RustBridge dependency 변경 없음.
- bundled `rhwp-studio` asset 변경 없음.
- manual에는 특정 run 사건을 누적하지 않고, 반복 운영 기준 한 줄만 추가했다.

## CI 운영 문서 보강

`mydocs/manual/ci_workflow_guide.md`의 `rhwp Upstream Sync PR` 유지 조건에 다음 기준을 추가했다.

```text
upstream WASM build는 upstream root의 `.env.docker`를 사용한다. checkout에 `.env.docker`가 없고 `.env.docker.example`만 있으면 workflow가 example을 복사해 CI용 env file을 준비한다.
```

이 문구는 특정 실패 run의 상세 기록이 아니라, 앞으로 workflow가 유지해야 하는 반복 운영 조건이다. 실제 실패 증상과 원인 분석은 Stage 보고서와 #336 이슈 기록에 남긴다.

## 검증 결과

```bash
git status --short --branch
```

결과:

```text
## local/task336
 M mydocs/manual/ci_workflow_guide.md
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
bash -n scripts/ci/check-rhwp-upstream-release.sh
bash -n scripts/ci/detect-rhwp-studio-impact.sh
bash -n scripts/ci/write-rhwp-studio-sync-pr-body.sh
bash -n scripts/sync-rhwp-studio.sh
bash -n scripts/verify-rhwp-studio-assets.sh
```

결과: 모두 통과.

```bash
gh api 'repos/edwardkim/rhwp/git/trees/v0.7.14?recursive=1' --jq '.tree[] | select(.path == ".env.docker.example" or .path == ".env.docker" or .path == "docker-compose.yml") | .path'
```

결과:

```text
.env.docker.example
docker-compose.yml
```

upstream `v0.7.14`에는 `.env.docker.example`과 `docker-compose.yml`이 있고 `.env.docker`는 tracked file로 없다.

```bash
tmpdir="/private/tmp/rhwp-task336-env-test-final-$$"
mkdir -p "$tmpdir"
cd "$tmpdir"
touch .env.docker.example
if [ ! -f .env.docker ]; then
  if [ -f .env.docker.example ]; then
    cp .env.docker.example .env.docker
  else
    echo "ERROR: upstream rhwp is missing .env.docker and .env.docker.example" >&2
    exit 1
  fi
fi
test -f .env.docker
printf 'env_created=%s\n' "$(test -f .env.docker && echo true || echo false)"
printf 'tmpdir=%s\n' "$tmpdir"
```

결과:

```text
env_created=true
tmpdir=/private/tmp/rhwp-task336-env-test-final-58052
```

`.env.docker.example`만 있는 경우 Stage 2 workflow block과 같은 조건이 `.env.docker`를 생성함을 확인했다.

```bash
git diff --check
```

결과: 통과.

## 완료 기준 확인

| 기준 | 결과 |
|------|------|
| workflow YAML parse 재확인 | OK |
| 관련 shell helper syntax 검증 | OK |
| upstream `v0.7.14` 파일 조건 재확인 | OK |
| `.env.docker.example` 기반 로컬 준비 조건 확인 | OK |
| CI 운영 문서 보강 여부 판단 | OK, 반복 기준 한 줄 보강 |
| `git diff --check` 통과 | OK |

## 잔여 위험

- GitHub-hosted runner에서 실제 Docker/WASM build가 끝까지 통과하는지는 아직 확인하지 않았다.
- `.env.docker` 준비 이후 upstream Docker image build, `wasm-pack`, `npm ci`, TypeScript, Vite build 단계에서 별도 실패가 드러날 수 있다.
- 자동 sync PR 생성은 repository write 권한과 upstream build 전체 성공이 필요하므로 PR 이후 workflow 재실행 또는 다음 schedule에서 확인해야 한다.
- 로컬 임시 검증 디렉터리 `/private/tmp/rhwp-task336-env-test-final-58052`는 재생성 가능한 테스트 부산물이다.

## 다음 단계 영향

Stage 4에서는 최종 보고서를 작성하고 오늘할일을 완료 처리한 뒤 PR 게시 전 상태를 확인한다.

1. `mydocs/report/task_m019_336_report.md`를 작성한다.
2. `mydocs/orders/20260605.md`의 #336 상태를 완료로 갱신한다.
3. `git status --short --branch`, `git diff --check`, `git diff --name-only devel...HEAD`를 실행한다.
4. PR 게시 절차로 넘길 준비를 마친다.

## 승인 요청

Stage 3 결과를 승인하면 Stage 4 `최종 보고와 PR 준비`로 진행한다.
