# Task M019 #345 최종 보고서

## 작업 요약

- 이슈: `#345` `rhwp Upstream Sync PR`가 upstream WASM build 중 `Cargo.lock` 권한 오류로 실패하는 문제 수정
- 마일스톤: M019 (`v0.1.2`)
- 기준 브랜치: `devel`
- 작업 브랜치: `local/task345`
- 게시 브랜치: `publish/task345`
- 단계 수: 5단계
- 최종 확인 시각: 2026-06-06 17:42 KST

이번 작업은 `rhwp Upstream Sync PR` workflow가 upstream `rhwp` checkout에서 WASM build를 수행할 때 container user와 GitHub-hosted runner checkout owner가 달라 `/app/Cargo.lock`에 쓰지 못하던 문제를 수정했다.

핵심 변경은 upstream `.env.docker.example`의 고정 `UID=1000`, `GID=1000` 값을 복사하지 않고, CI 실행 시점의 runner `id -u`, `id -g` 값으로 `.env.docker`를 생성하는 것이다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `.github/workflows/rhwp-upstream-sync-pr.yml` | `Build upstream rhwp-studio assets` 단계에서 `.env.docker.example` 존재를 확인하고 runner UID/GID 기반 `.env.docker`를 생성하도록 변경 |
| `mydocs/manual/ci_workflow_guide.md` | upstream WASM build의 `.env.docker` 운영 기준과 자동 PR 생성에 필요한 repository Actions permission 조건 기록 |
| `mydocs/orders/20260605.md` | #345 작업 시작과 단계 진행 상태 기록 |
| `mydocs/orders/20260606.md` | Stage 3 이후 진행과 완료 상태 기록 |
| `mydocs/plans/task_m019_345.md` | #345 수행계획서 작성 |
| `mydocs/plans/task_m019_345_impl.md` | #345 구현계획서 작성 |
| `mydocs/working/task_m019_345_stage1.md` | 실패 run, upstream Docker UID/GID 구성, 구현 전략 정리 |
| `mydocs/working/task_m019_345_stage2.md` | workflow UID/GID env file 생성 로직 구현 결과 정리 |
| `mydocs/working/task_m019_345_stage3.md` | syntax와 env file 생성 조건 로컬 검증 결과 정리 |
| `mydocs/working/task_m019_345_stage4.md` | 실제 workflow build 검증과 repository Actions permission 차단점 정리 |
| `mydocs/working/task_m019_345_stage5.md` | repository permission 변경 후 자동 PR 생성까지 end-to-end 검증 결과 정리 |

## 변경 전·후 정량 비교

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| CI용 `.env.docker` 준비 방식 | upstream `.env.docker.example` 복사, 기본 `UID=1000`, `GID=1000` 사용 | runner `id -u`, `id -g`로 `.env.docker` 생성 |
| 실패 run | `27004087710`, `Build upstream rhwp-studio assets` 실패 | `27057524066`, workflow 전체 success |
| upstream WASM build | `/app/Cargo.lock` permission denied | `Build upstream rhwp-studio assets` success |
| 자동 업데이트 PR 생성 | repository Actions permission 때문에 실패 | `#346` 자동 생성 성공 |
| PR branch 변경 규모 | 해당 없음 | 11 files, 1439 insertions, 8 deletions |
| workflow source 변경 규모 | `.github/workflows/rhwp-upstream-sync-pr.yml` 8 insertions, 7 deletions | runner UID/GID block 반영 |

## 단계별 결과

| 단계 | 커밋 | 결과 |
|------|------|------|
| Stage 1 | `ffe29c6` | 실패 run과 upstream Docker UID/GID 사용 방식을 확인하고 구현 전략 확정 |
| Stage 2 | `c5d5fa8` | workflow가 runner UID/GID 기반 `.env.docker`를 생성하도록 수정 |
| Stage 3 | `73e1bd0` | YAML, shell syntax, 로컬 env file 생성 스모크 검증과 운영 문서 보강 |
| Stage 4 | `2066c09` | `dry_run=false` 실제 run에서 upstream build 성공 확인, PR 생성 권한 차단점 분리 |
| Stage 5 | `4f0a22b` | repository Actions permission 변경 후 workflow 전체 성공과 자동 PR `#346` 생성 확인 |

## 검증 결과

| 수용 기준 | 결과 | 근거 |
|-----------|------|------|
| workflow YAML parse 통과 | OK | `ruby -e 'require "psych"; Psych.parse_file(".github/workflows/rhwp-upstream-sync-pr.yml"); puts "parsed"'` 종료 코드 0 |
| 관련 shell helper syntax 통과 | OK | `bash -n` 5개 helper 모두 종료 코드 0 |
| diff whitespace check 통과 | OK | `git diff --check` 통과 |
| runner UID/GID 기반 `.env.docker` 생성 확인 | OK | 로컬 스모크에서 `UID=501`, `GID=20`이 현재 user 값과 일치 |
| 실제 `dry_run=false` upstream build 성공 | OK | run `27057524066`, `Build upstream rhwp-studio assets` success |
| `/app/Cargo.lock` permission denied 재발 없음 | OK | run `27057524066` 전체 success, 기존 오류 미발생 |
| 자동 업데이트 branch 생성 | OK | `automation/rhwp-v0.7.14-studio-sync` at `28cb70d301e1bb5044dd5d72eb8a23550937c422` |
| 자동 업데이트 PR 생성 | OK | `#346` `Update bundled rhwp-studio to rhwp v0.7.14`, OPEN |
| assignee/reviewer 지정 | OK | `#346` assignee `postmelee`, review request `postmelee` |

`ruby` 검증에서 다음 로컬 환경 경고가 반복 출력됐으나 parse 결과는 `parsed`였고 종료 코드 0이었다.

```text
Ignoring ffi-1.13.1 because its extensions are not built. Try: gem pristine ffi --version 1.13.1
parsed
```

## GitHub Actions 검증

최종 성공 run:

- URL: `https://github.com/postmelee/alhangeul-macos/actions/runs/27057524066`
- event: `workflow_dispatch`
- ref: `publish/task345`
- input: `target_tag=v0.7.14`, `force_pr=false`, `dry_run=false`
- conclusion: `success`
- build step: `Build upstream rhwp-studio assets` success
- PR step: `Sync bundled rhwp-studio and create PR` success

자동 생성 PR:

- URL: `https://github.com/postmelee/alhangeul-macos/pull/346`
- 작성자: `app/github-actions`
- base: `devel`
- head: `automation/rhwp-v0.7.14-studio-sync`
- commit: `28cb70d301e1bb5044dd5d72eb8a23550937c422`
- 업데이트 대상: bundled `rhwp-studio` `v0.7.14`, upstream commit `fb885547538dc6572a12722dd2991b553e082e0e`

## 잔여 위험과 후속 작업

- repository-level Actions permission은 현재 `default_workflow_permissions=read`, `can_approve_pull_request_reviews=true`로 유지된다. workflow별 권한은 workflow `permissions` block에서 제한하므로, 자동 PR 생성 운영을 유지하려면 이 설정을 되돌리지 않아야 한다.
- 자동 생성 PR `#346`은 실제 bundled `rhwp-studio` 업데이트 후보이며, 이번 #345 수정 PR과 별도로 검토해야 한다.
- `publish/task345`는 #345 수정 PR 게시용 branch이고, `automation/rhwp-v0.7.14-studio-sync`는 업데이트 후보 branch다. merge와 cleanup 시 두 branch를 구분해야 한다.
- 이번 작업은 workflow와 운영 문서 수정이다. macOS 앱 빌드, Quick Look smoke, bundled viewer smoke는 제품 코드 변경이 아니므로 수행하지 않았다.

## 작업지시자 승인 요청

#345 최종 결과를 승인하면 `publish/task345`를 `devel` 대상으로 PR 게시하고 리뷰/merge 승인을 요청한다.
