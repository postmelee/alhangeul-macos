# Task M019 #336 최종 보고서

## 작업 요약

- 이슈: [#336 rhwp Upstream Sync PR가 upstream WASM 빌드 전 .env.docker 누락으로 실패하는 문제 수정](https://github.com/postmelee/alhangeul-macos/issues/336)
- 마일스톤: M019 (`v0.1.2`)
- 브랜치: `local/task336`
- 기준 브랜치: `devel`
- 단계 수: 4단계
- 목적: `rhwp Upstream Sync PR` workflow가 upstream `rhwp`의 WASM build 전에 `.env.docker`를 준비하지 않아 실패하는 문제를 수정한다.

## 결과

scheduled `rhwp Upstream Sync PR` run `26996434439`는 upstream `v0.7.14`에 viewer impact가 있다고 판정한 뒤 `Build upstream rhwp-studio assets` 단계로 진행했지만, upstream checkout root에 `.env.docker`가 없어 Docker Compose 실행 전 실패했다.

이번 작업에서는 upstream build 단계에서 `.env.docker`가 없고 `.env.docker.example`만 있는 경우 example을 복사해 CI용 env file을 준비하도록 workflow를 보강했다. `.env.docker`가 이미 있으면 덮어쓰지 않고, 두 파일이 모두 없으면 명확한 오류 메시지로 실패한다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `.github/workflows/rhwp-upstream-sync-pr.yml` | `Build upstream rhwp-studio assets` 단계에서 `.env.docker.example`을 `.env.docker`로 준비하는 조건 분기 추가 |
| `mydocs/manual/ci_workflow_guide.md` | upstream sync PR의 WASM build env file 준비 기준을 반복 운영 조건으로 문서화 |
| `mydocs/orders/20260605.md` | #336 진행/완료 상태 관리 |
| `mydocs/plans/task_m019_336.md` | 수행계획서 |
| `mydocs/plans/task_m019_336_impl.md` | 구현계획서 |
| `mydocs/working/task_m019_336_stage1.md` | 실패 경로와 upstream env file 사전 조건 조사 보고 |
| `mydocs/working/task_m019_336_stage2.md` | workflow env file 준비 로직 구현 보고 |
| `mydocs/working/task_m019_336_stage3.md` | syntax, upstream 조건, 로컬 env 준비 검증 보고 |
| `mydocs/report/task_m019_336_report.md` | 본 최종 보고서 |

## 변경 전·후 비교

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| upstream root에 `.env.docker` 없음 | Docker Compose가 `couldn't find env file`로 즉시 실패 | `.env.docker.example`이 있으면 `.env.docker`로 복사 후 실행 |
| upstream root에 `.env.docker` 있음 | 기존 파일 사용 | 기존 파일을 덮어쓰지 않고 그대로 사용 |
| `.env.docker`와 `.env.docker.example` 모두 없음 | Compose 오류로 원인 파악 필요 | workflow가 명확한 오류 메시지 출력 후 실패 |
| 운영 문서 | upstream sync PR의 env file 준비 조건 없음 | 반복 운영 조건으로 기록 |

Stage 3까지의 전체 diff 기준:

```text
8 files changed, 833 insertions(+)
```

최종 보고서와 오늘할일 완료 갱신을 포함하면 변경 파일은 9개다.

## 단계별 커밋

| 단계 | 커밋 | 내용 |
|------|------|------|
| 수행계획 | `2fec70a` | 수행 계획서 작성과 오늘할일 갱신 |
| 구현계획 | `ac24360` | 구현계획서 작성 |
| Stage 1 | `46ff0f3` | upstream sync env file 실패 경로 정리 |
| Stage 2 | `1ba7005` | upstream sync env file 준비 로직 추가 |
| Stage 3 | `5eaf36b` | upstream sync env file 검증 정리 |
| Stage 4 | 본 커밋 | 최종 보고서와 오늘할일 완료 처리 |

## 검증 결과

| 수용 기준 | 결과 | 근거 |
|-----------|------|------|
| workflow가 `.env.docker` 준비 조건 분기를 포함 | OK | Stage 2 workflow diff |
| `.env.docker`가 이미 있으면 덮어쓰지 않음 | OK | `[ ! -f .env.docker ]` 조건 사용 |
| `.env.docker.example` 기반 준비 조건 확인 | OK | 로컬 임시 디렉터리에서 `env_created=true` |
| upstream `v0.7.14` 파일 조건 확인 | OK | `.env.docker.example`, `docker-compose.yml` 존재, `.env.docker` 없음 |
| workflow YAML parse 통과 | OK | Ruby `Psych.parse_file` 결과 `parsed` |
| 관련 shell helper syntax 검증 | OK | `bash -n` 5개 helper 통과 |
| diff whitespace 검증 | OK | `git diff --check` 통과 |
| core lock과 bundled asset 미변경 | OK | 변경 파일 목록에 `rhwp-core.lock`, `RustBridge/*`, `Sources/HostApp/Resources/rhwp-studio/*` 없음 |

실행한 주요 검증:

```bash
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/rhwp-upstream-sync-pr.yml"); puts "parsed"'
bash -n scripts/ci/check-rhwp-upstream-release.sh
bash -n scripts/ci/detect-rhwp-studio-impact.sh
bash -n scripts/ci/write-rhwp-studio-sync-pr-body.sh
bash -n scripts/sync-rhwp-studio.sh
bash -n scripts/verify-rhwp-studio-assets.sh
gh api 'repos/edwardkim/rhwp/git/trees/v0.7.14?recursive=1' --jq '.tree[] | select(.path == ".env.docker.example" or .path == ".env.docker" or .path == "docker-compose.yml") | .path'
git diff --check
```

참고:

- Ruby YAML parse 중 `ffi-1.13.1` extension 경고가 출력됐지만 `parsed`로 종료되어 parse 실패는 아니었다.
- 로컬 env file 준비 검증은 `/private/tmp/rhwp-task336-env-test-final-58052` 임시 디렉터리에서 수행했다. 이 경로는 재생성 가능한 검증 부산물이다.

## 미수행 범위

- bundled `rhwp-studio` asset 갱신
- `rhwp-core.lock` 갱신
- RustBridge dependency 갱신
- upstream `edwardkim/rhwp` 수정
- release, signing, notarization, Homebrew 배포
- 자동 sync PR 실제 생성, push, merge

## 잔여 위험과 후속 확인

| 항목 | 내용 |
|------|------|
| GitHub-hosted workflow 재실행 | 로컬 syntax와 사전 조건 검증은 통과했지만, 실제 Docker/WASM build는 PR merge 후 workflow dispatch 또는 다음 schedule에서 확인해야 한다. |
| 후속 build 단계 | `.env.docker` 준비 이후 upstream Docker image build, `wasm-pack`, `npm ci`, TypeScript, Vite build 단계에서 별도 실패가 드러날 수 있다. |
| 자동 PR 생성 | repository write 권한과 upstream build 전체 성공이 필요하므로 로컬에서 완전히 대체할 수 없다. |

## PR close 전략

PR 본문에는 다음을 명시한다.

```text
Closes #336
```

## 작업지시자 승인 요청

최종 보고 결과를 승인하면 PR 게시 절차로 진행한다. 다음 절차는 `publish/task336` 원격 브랜치 push와 `devel` 대상 Open PR 생성이다.
