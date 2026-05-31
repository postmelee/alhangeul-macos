# Task M040 #79 최종 결과보고서

## 작업 요약

| 항목 | 값 |
|------|----|
| GitHub Issue | [#79](https://github.com/postmelee/alhangeul-macos/issues/79) |
| 마일스톤 | M040 (`v0.4`) |
| 작업 브랜치 | `local/task79` |
| 기준 브랜치 | `devel` |
| 단계 수 | 4단계 |
| 목적 | 릴리즈 작업 때마다 참고할 수 있는 메인테이너용 public release 실행 runbook 작성 |

특정 버전의 release 기록이 아니라, 앞으로 매 public release마다 최신 release context를 다시 수집하고 승인 gate별로 진행할 수 있는 반복 실행 문서를 작성했다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `mydocs/manual/public_release_runbook.md` | 신규 메인테이너용 public release 실행 runbook. context 수집, release identity 확정, source preflight, rehearsal, publish, Pages/Sparkle, Finder smoke, Homebrew, release record, rollback gate 정리 |
| `mydocs/manual/release_distribution_guide.md` | 하위 매뉴얼 표와 전체 release flow 앞에 runbook 진입점 추가 |
| `mydocs/plans/task_m040_79.md` | 수행계획서 |
| `mydocs/plans/task_m040_79_impl.md` | 4단계 구현계획서 |
| `mydocs/working/task_m040_79_stage1.md` | 최신 release 기준과 기존 문서 역할 분류 보고 |
| `mydocs/working/task_m040_79_stage2.md` | runbook 신규 작성 보고 |
| `mydocs/working/task_m040_79_stage3.md` | release guide 연결 보강 보고 |
| `mydocs/orders/20260530.md` | 오늘할일 #79 완료 처리 |
| `mydocs/report/task_m040_79_report.md` | 최종 결과보고서 |

## 변경 전·후 정량 비교

| 항목 | 결과 |
|------|------|
| 신규 runbook | `mydocs/manual/public_release_runbook.md`, 398 lines |
| 기존 release guide 보강 | 3 lines 추가, 정책 본문 삭제 없음 |
| 단계 보고서 | Stage 1 112 lines, Stage 2 88 lines, Stage 3 61 lines |
| 작업 커밋 | 수행계획, 구현계획, Stage 1, Stage 2, Stage 3, Stage 4 최종 보고 |

## 단계별 결과

| 단계 | 결과 |
|------|------|
| Stage 1 | 최신 공개 앱 release, upstream `rhwp`, local lock/manifest/workflow/Cask 상태를 수집하고 runbook 설계 기준을 정리 |
| Stage 2 | 특정 버전 고정값 대신 placeholder와 최신 context 재수집 절차 중심의 `public_release_runbook.md` 신규 작성 |
| Stage 3 | `release_distribution_guide.md`에서 runbook을 실행 진입점으로 연결하고 역할을 구분 |
| Stage 4 | 최종 검증, secret 금지 문구 확인, 최종 보고서와 오늘할일 완료 처리 |

## 검증 결과

| 검증 항목 | 결과 | 비고 |
|-----------|------|------|
| `git status --short --branch` | OK | Stage 4 시작 시 `local/task79` 확인 |
| `git diff --check` | OK | whitespace 오류 없음 |
| `test -f mydocs/manual/public_release_runbook.md` | OK | 신규 runbook 존재 |
| `rg -n "public_release_runbook\|Release Publish DMG\|Release Rehearsal DMG\|previous_release_ref\|expected_rhwp_tag\|require_latest_rhwp\|include_rhwp_in_title\|SPARKLE_ED_PRIVATE_KEY\|Homebrew\|rollback\|Rollback" mydocs/manual` | OK | runbook 연결, workflow input, Sparkle, Homebrew, rollback 항목 확인 |
| `rg -n "password\|app-specific password\|\\.p8\|\\.p12\|private key\|token" mydocs/manual/public_release_runbook.md` | OK | 실제 secret 값 없음. 기록 금지 항목을 설명하는 1개 문장만 확인 |
| `git log --oneline devel..local/task79` | OK | task 커밋 목록 확인 |

## 실행하지 않은 항목

이번 task는 문서화 작업이므로 다음은 실행하지 않았다.

- `./scripts/release.sh <version>` public mode
- `Release Publish DMG` workflow dispatch
- notarization submit/wait
- GitHub Release 생성 또는 수정
- Pages deployment
- Sparkle appcast 갱신
- Homebrew tap PR 또는 push
- Cask version/SHA256 변경

## 잔여 위험과 후속 작업

- release workflow input, Pages/Sparkle 정책, Homebrew tap 정책이 바뀌면 `public_release_runbook.md`와 `release_distribution_guide.md`를 함께 갱신해야 한다.
- runbook은 실행 절차 문서이며 실제 release 성공을 대체하지 않는다. 매 release 때 workflow summary, artifact, SHA256, 수동 smoke 결과를 `mydocs/release/v<version>.md`에 별도 기록해야 한다.
- secret 이름과 금지 항목은 문서에 등장하지만 실제 secret 값은 기록하지 않았다. 향후 수정 시에도 같은 원칙을 유지해야 한다.

## 작업지시자 승인 요청

최종 결과보고서 기준으로 PR 게시 단계 진행 승인을 요청한다. 승인 후 `publish/task79` 원격 브랜치로 push하고 `devel` 대상 PR을 생성한다.
