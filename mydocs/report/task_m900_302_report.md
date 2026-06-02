# Task M900 #302 최종 결과보고서

## 작업 요약

| 항목 | 값 |
|------|----|
| Issue | [#302](https://github.com/postmelee/alhangeul-macos/issues/302) |
| Milestone | `Release Operations` |
| 문서 코드 | `M900` |
| 브랜치 | `local/task302` |
| 단계 수 | 4단계 |
| 범위 | 릴리즈 운영 문서의 pre-public signed/notarized DMG smoke gate 정렬 |

이번 작업은 public release 문서에서 signed/notarized DMG 설치 smoke가 post-publish 사후 검증으로 밀려 읽히지 않도록, `draft=true`, `prerelease=false` 실행을 pre-public 검증 단계로 정의하고 `draft=false`, `prerelease=false` 실행을 official stable publish로 분리했다.

실제 `v0.1.4` 배포 실행, tag 생성, workflow 실행, GitHub Release 게시, Pages/Sparkle 배포, Homebrew Cask 갱신은 수행하지 않았다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `mydocs/manual/release_distribution_guide.md` | 권한 원칙, 전체 release flow, public release 전 확정 항목, 최종 체크리스트에 pre-public draft signed/notarized DMG smoke gate 반영 |
| `mydocs/manual/public_release_runbook.md` | Gate 4를 pre-public signed/notarized DMG smoke로 분리하고 Gate 5 official stable publish를 신설 |
| `mydocs/manual/release_github_pages_sparkle_guide.md` | draft/prerelease 실행의 stable appcast/Pages skip 의미와 official stable publish 전 release body/Pages 재검토 기준 보강 |
| `mydocs/plans/task_m900_301.md` | #301 수행계획서 Stage 4/5 용어와 workflow 입력 예시를 #302 정책에 맞게 보정 |
| `mydocs/plans/task_m900_301_impl.md` | #301 구현계획서 Stage 4를 pre-public smoke와 official publish gate로 정렬 |
| `mydocs/release/v0.1.4.md` | release execution gate에 pre-public draft DMG smoke와 official stable publish 조건 반영 |
| `mydocs/plans/task_m900_302.md` | #302 수행계획서 |
| `mydocs/plans/task_m900_302_impl.md` | #302 구현계획서 |
| `mydocs/working/task_m900_302_stage1.md` | Stage 1 release gate 문맥 감사 보고 |
| `mydocs/working/task_m900_302_stage2.md` | Stage 2 pre-public DMG smoke gate 문서화 보고 |
| `mydocs/working/task_m900_302_stage3.md` | Stage 3 Pages/Sparkle와 #301 문서 정렬 보고 |
| `mydocs/working/task_m900_302_stage4.md` | Stage 4 통합 검증 보고 |
| `mydocs/orders/20260602.md` | #302 오늘할일 완료 처리 |

## 변경 전·후 정량 비교

| 항목 | 변경 전 | 변경 후 |
|------|--------|--------|
| Stage 보고서 | 없음 | Stage 1~4 보고서 작성 |
| 최종 결과보고서 | 없음 | `task_m900_302_report.md` 작성 |
| runbook Gate 구조 | Gate 4 `Public publish`, Gate 5 `Public artifact 확인` | Gate 4 `Pre-public signed/notarized DMG smoke`, Gate 5 `Official stable publish`, Gate 6 이후 public 확인 |
| Sparkle/Pages draft 기준 | draft/prerelease appcast skip 기준은 있었으나 pre-public smoke 의미가 약함 | draft smoke 단계에서 stable appcast/Pages skip이 정상 동작임을 명시 |
| #301 Stage 4/5 경계 | Stage 4 public publish, Stage 5 post-publish 확인 | Stage 4 pre-public smoke와 official publish gate, Stage 5 post-publish public surface와 Homebrew gate |
| 통합 검증 | 미실행 | Stage 4 `rg` 2건, `git diff --check`, `git status --short` 통과 |

## 검증 결과

| 수용 기준 | 결과 | 비고 |
|-----------|------|------|
| public signed/notarized DMG 설치 smoke가 public publish 이전 gate로 문서화 | OK | `release_distribution_guide.md`, `public_release_runbook.md`에 반영 |
| Stage 5가 GitHub Release asset, Pages 다운로드 링크, Sparkle stable feed 등 public surface 사후 검증으로 정의 | OK | #301 구현계획서와 runbook Gate 6~8에 반영 |
| draft release smoke와 official stable publish의 승인 경계가 드러남 | OK | `draft=true`/`draft=false` workflow 입력 예시와 Gate 분리 반영 |
| 실제 release 실행, signing/notarization 실행, Homebrew 갱신 제외 | OK | 실행하지 않았고 문서에도 별도 승인 gate로 유지 |
| `git diff --check` | OK | 출력 없음 |
| secret/credential 값 유입 없음 | OK | 검색 결과는 기존 정책 문구와 체크리스트 항목으로 한정 |

실행한 통합 검증:

```bash
rg -n "draft signed/notarized DMG|pre-public|official stable|post-publish|public surface|Homebrew gate" \
  mydocs/manual/release_distribution_guide.md \
  mydocs/manual/public_release_runbook.md \
  mydocs/manual/release_github_pages_sparkle_guide.md \
  mydocs/plans/task_m900_301.md \
  mydocs/plans/task_m900_301_impl.md \
  mydocs/release/v0.1.4.md
rg -n "password|private key|token|credential payload|SHA256" \
  mydocs/manual/release_distribution_guide.md \
  mydocs/manual/public_release_runbook.md \
  mydocs/manual/release_github_pages_sparkle_guide.md
git diff --check
git status --short
```

## 잔여 위험과 후속 작업

- #302는 문서 정렬 작업이므로 실제 `v0.1.4` signed/notarized draft DMG smoke 결과는 #301 실행 단계에서 확인해야 한다.
- GitHub Actions가 생성하는 draft release asset 또는 Actions artifact의 실제 위치는 workflow run 결과에 따라 `mydocs/release/v0.1.4.md`에 기록해야 한다.
- Homebrew Cask 반영은 public DMG URL과 SHA256 확정 후 별도 승인으로 진행해야 한다.
- Stage 4 이후 PR 게시와 리뷰/merge는 아직 수행하지 않았다.

## 작업지시자 승인 요청

이 최종 결과보고서 기준으로 `publish/task302` 원격 push와 `devel` 대상 Open PR 생성 단계 진행 승인을 요청한다.
