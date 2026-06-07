# Task M900 #302 구현계획서

## 개요

이 구현계획서는 릴리즈 운영 문서에 signed/notarized draft DMG smoke를 public publish 전 필수 gate로 반영하는 작업을 4단계로 나눈다.

작업의 핵심은 `Release Publish DMG` workflow의 draft 실행과 official stable publish 실행을 문서상 분리하는 것이다. `draft=true` 실행은 signed/notarized DMG를 만들고 maintainer 설치 smoke를 수행하는 pre-public 검증 단계로 정의한다. `draft=false`, `prerelease=false` 실행은 draft smoke 통과 후 별도 승인으로 진행하는 official stable publish 단계로 정의한다.

이 작업은 릴리즈 실행 문서 정렬만 수행한다. tag 생성, workflow 실행, GitHub Release publish, stable appcast/Pages 배포, Homebrew Cask 갱신은 이 구현계획 승인만으로 실행하지 않는다.

## Stage 1: 현재 릴리즈 Gate 문맥 감사

### 목표

현재 릴리즈 manual과 #301 릴리즈 실행 문서에서 draft signed/notarized DMG smoke, official stable publish, post-publish public surface 확인이 섞인 지점을 식별한다.

### 변경 파일

- `mydocs/working/task_m900_302_stage1.md`

### 작업

1. `release_distribution_guide.md`, `public_release_runbook.md`, `release_github_pages_sparkle_guide.md`의 release flow와 gate 문구를 검색한다.
2. #301 수행계획서, 구현계획서, `v0.1.4` release record의 Stage 4/5 문구를 확인한다.
3. 다음 세 범주가 문서에서 어떻게 쓰이는지 표로 정리한다.
   - pre-public draft signed/notarized DMG smoke
   - official stable publish (`draft=false`, `prerelease=false`)
   - post-publish public surface 확인
4. 문서 보정 대상을 확정하고, #301 문서는 정책 충돌 제거에 필요한 문구만 고친다는 제한을 기록한다.

### 검증

```bash
rg -n "draft=true|draft=false|signed/notarized|pre-public|post-publish|Public artifact|Pages|Sparkle|Stage 4|Stage 5" \
  mydocs/manual/release_distribution_guide.md \
  mydocs/manual/public_release_runbook.md \
  mydocs/manual/release_github_pages_sparkle_guide.md \
  mydocs/plans/task_m900_301.md \
  mydocs/plans/task_m900_301_impl.md \
  mydocs/release/v0.1.4.md
git diff --check
```

### 단계 산출물

- `mydocs/working/task_m900_302_stage1.md`
- 단계 커밋: `Task #302 Stage 1: release gate 문맥 감사`

### 승인 요청

Stage 1 완료보고서 기준으로 Stage 2 진행 승인을 요청한다.

## Stage 2: Pre-public DMG Smoke Gate 문서화

### 목표

릴리즈 entrypoint와 runbook에 signed/notarized DMG 설치 smoke가 public publish 전 필수 gate임을 명시한다.

### 변경 파일

- `mydocs/manual/release_distribution_guide.md`
- `mydocs/manual/public_release_runbook.md`
- `mydocs/working/task_m900_302_stage2.md`

### 작업

1. `release_distribution_guide.md`의 전체 release flow와 최종 체크리스트에서 signed/notarized draft DMG smoke를 public publish 전 gate로 분리한다.
2. `public_release_runbook.md`에서 tag 생성 이후 `Release Publish DMG`를 `draft=true`, `prerelease=false`로 실행해 signed/notarized DMG를 만드는 pre-public gate를 추가한다.
3. maintainer가 draft release asset 또는 Actions artifact DMG를 내려받아 설치 smoke를 수행해야 함을 명시한다.
4. official stable publish는 draft smoke 통과 후 별도 승인으로 `draft=false`, `prerelease=false`를 실행하는 단계임을 명시한다.
5. Gate 번호와 이름을 바꿀 경우 뒤쪽 Gate와 release record 필수 항목의 용어가 자연스럽게 이어지는지 함께 보정한다.

### 검증

```bash
rg -n "draft signed/notarized DMG|draft=true|pre-public|public publish 전|official stable|post-publish" \
  mydocs/manual/release_distribution_guide.md \
  mydocs/manual/public_release_runbook.md
rg -n "Git tag 생성|Release Publish DMG|draft=false|prerelease=false|Homebrew" \
  mydocs/manual/public_release_runbook.md
git diff --check
```

### 단계 산출물

- `mydocs/working/task_m900_302_stage2.md`
- 단계 커밋: `Task #302 Stage 2: pre-public DMG smoke gate 문서화`

### 승인 요청

Stage 2 완료보고서 기준으로 Stage 3 진행 승인을 요청한다.

## Stage 3: Pages/Sparkle와 현재 Release 문서 정렬

### 목표

draft/prerelease 실행이 stable Sparkle appcast와 Pages를 갱신하지 않는 pre-public 검증 단계임을 분명히 하고, #301 관련 문서의 Stage 4/5 용어를 같은 정책에 맞춘다.

### 변경 파일

- `mydocs/manual/release_github_pages_sparkle_guide.md`
- `mydocs/plans/task_m900_301.md` (필요 시)
- `mydocs/plans/task_m900_301_impl.md` (필요 시)
- `mydocs/release/v0.1.4.md` (필요 시)
- `mydocs/working/task_m900_302_stage3.md`

### 작업

1. `release_github_pages_sparkle_guide.md`에 draft/prerelease 실행에서 stable appcast와 Pages deployment를 skip하는 이유가 pre-public 검증 경계임을 명시한다.
2. GitHub Release body와 Pages 문서는 draft smoke 이후 candidate 변경이 있으면 official stable publish 전에 다시 검토해야 한다는 기존 기준을 유지한다.
3. #301 수행계획서와 구현계획서에서 Stage 4는 draft signed/notarized DMG smoke와 official stable publish approval gate를 다루고, Stage 5는 post-publish public surface 확인과 Homebrew gate를 다루도록 문구를 보정한다.
4. `mydocs/release/v0.1.4.md`의 release execution gate가 public publish 전 signed/notarized DMG smoke를 필수 조건으로 읽히는지 확인하고 필요 시 보정한다.
5. #301 고유 SHA256, workflow run 결과, release 실행 결과를 새로 단정하지 않는다.

### 검증

```bash
rg -n "draft|prerelease|stable appcast|Pages deployment|pre-public|official stable" \
  mydocs/manual/release_github_pages_sparkle_guide.md
rg -n "Stage 4|Stage 5|draft signed/notarized|pre-public|post-publish|Homebrew gate" \
  mydocs/plans/task_m900_301.md \
  mydocs/plans/task_m900_301_impl.md \
  mydocs/release/v0.1.4.md
git diff --check
```

### 단계 산출물

- `mydocs/working/task_m900_302_stage3.md`
- 단계 커밋: `Task #302 Stage 3: Pages Sparkle와 release 문서 정렬`

### 승인 요청

Stage 3 완료보고서 기준으로 Stage 4 진행 승인을 요청한다.

## Stage 4: 통합 검증과 최종 보고

### 목표

릴리즈 문서 묶음의 gate 용어와 승인 경계를 재검증하고, 최종 결과보고서와 PR 게시 준비를 완료한다.

### 변경 파일

- `mydocs/working/task_m900_302_stage4.md`
- `mydocs/report/task_m900_302_report.md`
- `mydocs/orders/20260602.md`

### 작업

1. 릴리즈 manual 3개와 #301 관련 문서의 gate 용어를 최종 검색한다.
2. public publish, GitHub Release 게시, Pages/Sparkle 갱신, Homebrew Cask 반영이 모두 별도 승인 gate로 남아 있는지 확인한다.
3. secret 값, credential payload, 일회성 SHA256 또는 workflow 실행 결과가 manual에 추가되지 않았는지 확인한다.
4. `git diff --check`와 `git status --short`를 실행한다.
5. Stage 4 완료보고서와 최종 결과보고서를 작성한다.
6. 오늘할일의 #302 상태를 완료로 갱신한다.

### 검증

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

### 단계 산출물

- `mydocs/working/task_m900_302_stage4.md`
- `mydocs/report/task_m900_302_report.md`
- 완료 처리된 `mydocs/orders/20260602.md`
- 단계/최종 커밋: `Task #302 Stage 4 + 최종 보고서: 릴리즈 smoke gate 문서화 완료`

### 승인 요청

최종 결과보고서 기준으로 PR 게시 단계 진행 승인을 요청한다.

## 전체 승인 Gate

| Gate | 승인 없이 진행 금지 항목 |
|------|--------------------------|
| 수행계획 승인 | 구현계획서 작성 이후의 실제 릴리즈 문서 수정 |
| 구현계획 승인 | Stage 1 감사 보고서 작성 |
| Stage 1 승인 | 릴리즈 manual 본문 수정 |
| Stage 2 승인 | Pages/Sparkle manual과 #301 관련 문서 보정 |
| Stage 3 승인 | 최종 보고서 작성과 오늘할일 완료 처리 |
| 최종 결과보고 승인 | `publish/task302` push와 PR 생성 |

## 검증/기록 원칙

- 실행하지 않은 workflow, smoke, signing/notarization 결과를 성공으로 기록하지 않는다.
- manual에는 반복 적용 가능한 정책과 gate만 남기고, 특정 release의 SHA256 또는 일회성 workflow 결과는 `mydocs/release/`에만 둔다.
- draft signed/notarized DMG, official stable public DMG, rehearsal DMG의 산출물 계층을 섞지 않는다.
- secret 값과 credential payload는 어떤 문서, commit, PR, shell history에도 기록하지 않는다.
- #301 문서는 정책 충돌 제거 범위에서만 보정하고, release execution 자체는 #301 승인 흐름을 따른다.

## 승인 요청 사항

이 구현계획서 기준으로 Stage 1 진행 승인을 요청한다.
