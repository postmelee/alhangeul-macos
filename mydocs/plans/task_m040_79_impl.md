# Task #79 구현 계획서

본 문서는 [`task_m040_79.md`](task_m040_79.md) 수행계획서를 단계별 실행 단위로 분해한 것이다. 각 단계 완료 후 [`task-stage-report`](../skills/task-stage-report/SKILL.md) skill로 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 환경

- Worktree: `/Users/melee/Documents/projects/rhwp-mac`
- Branch: `local/task79`
- 기준 브랜치: `devel`
- 기준 이슈: [#79](https://github.com/postmelee/alhangeul-macos/issues/79)
- 마일스톤: M040 (`v0.4`)
- 범위: 메인테이너용 public release 실행 runbook 작성

## 구현 원칙

- `public_release_runbook.md`는 실제 배포일 실행 순서를 담당하고, 기존 하위 매뉴얼은 세부 정책의 진실 원천으로 유지한다.
- runbook에는 secret 값을 적지 않는다. 기록 가능한 값은 비밀이 아닌 운영 식별자, workflow input 이름, command 판정 기준으로 제한한다.
- workflow 기본값은 릴리즈마다 stale할 수 있으므로, 문서에서 기본값 신뢰를 금지하고 매번 현재 release context를 재확인하도록 쓴다.
- 실제 public release, notarization, GitHub Release publish, Pages deployment, Homebrew tap 반영은 이번 task에서 실행하지 않는다.
- 문서 예시는 특정 릴리즈에 고정되지 않게 `<version>`, `v<version>`, `<previous-release-ref>`, `<expected-rhwp-tag>` placeholder를 기본으로 사용한다.
- 다만 runbook 작성 근거로 최신 공개 앱 릴리즈 `v0.1.3`, upstream `rhwp v0.7.13`, 현재 lock/manifest/workflow/Cask 상태는 분석 결과에 기록할 수 있다.

## Stage 1 — 기존 릴리스 문서와 최신 기준 수집

### 목표

- 새 runbook이 참조할 기존 매뉴얼, workflow, release record, 최신 공개 릴리즈 기준을 정리한다.
- runbook에 직접 써야 할 실행 순서와 기존 문서로 링크할 세부 정책을 구분한다.

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `mydocs/plans/task_m040_79_impl.md` | 구현계획서 작성 | 현재 단계 산출물 |
| `mydocs/working/task_m040_79_stage1.md` | Stage 1 완료보고서 작성 | 수집 결과와 runbook 설계 기준 기록 |

### 확인할 자료

- Issue #79 본문
- `mydocs/manual/release_distribution_guide.md`
- `mydocs/manual/ci_workflow_guide.md`
- `mydocs/manual/release_policy_guide.md`
- `mydocs/manual/release_packaging_dmg_guide.md`
- `mydocs/manual/release_signing_notarization_guide.md`
- `mydocs/manual/release_github_pages_sparkle_guide.md`
- `mydocs/manual/release_homebrew_cask_guide.md`
- `mydocs/release/v0.1.3.md`
- `.github/workflows/release-rehearsal.yml`
- `.github/workflows/release-publish.yml`
- `rhwp-core.lock`
- `Sources/HostApp/Resources/rhwp-studio/manifest.json`
- `Casks/alhangeul.rb`

### 확인 기준

- 최신 공개 앱 릴리즈, 직전 public release ref, 현재 lock/manifest의 `rhwp` tag, workflow default, Cask version을 구분한다.
- `Release Publish DMG` workflow의 필수 input과 secret/variable 요구사항을 정리한다.
- Homebrew Cask 반영이 public DMG SHA256 확정 이후 gate임을 확인한다.
- runbook에 중복 복제하지 않을 세부 정책을 하위 문서 링크로 분류한다.

### 단계 검증

```bash
git diff --check
rg -n "Release Publish DMG|Release Rehearsal DMG|previous_release_ref|expected_rhwp_tag|SPARKLE_ED_PRIVATE_KEY|Homebrew|Rollback" mydocs/manual .github/workflows
```

### 커밋 메시지

```text
Task #79 Stage 1: public release runbook 기준 수집
```

## Stage 2 — public release runbook 신규 작성

### 목표

- `mydocs/manual/public_release_runbook.md`를 신규 작성한다.
- 릴리즈 요청을 받은 에이전트가 이 문서를 먼저 읽고, 최신 context 수집부터 public 배포 후 기록까지 순서대로 수행할 수 있게 한다.

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `mydocs/manual/public_release_runbook.md` | 신규 runbook 작성 | 핵심 산출물 |
| `mydocs/working/task_m040_79_stage2.md` | Stage 2 완료보고서 작성 | 신규 문서 구조와 포함 항목 기록 |

### runbook 구성

1. 목적과 사용 시점
2. 권한/승인/중단 원칙
3. 시작 전 context 수집
4. release identity 확정
5. source preflight
6. rehearsal DMG와 delta checklist
7. public publish workflow
8. GitHub Release, Pages, Sparkle 확인
9. 설치본과 Finder 통합 smoke
10. Homebrew Cask 반영 gate
11. release record와 최종 보고
12. rollback과 실패 시 후속 처리

### 필수 반영 기준

- 작업지시자 명시 승인 없이는 public release 실행, GitHub Release 게시, Sparkle appcast 갱신, Homebrew Cask 반영을 시작하지 않는다고 적는다.
- 매 릴리즈 시작 시 `version`, `build`, `candidate commit`, `previous_release_ref`, `expected_rhwp_tag`, `require_latest_rhwp`, `include_rhwp_in_title`, `draft`, `prerelease`를 확정하도록 한다.
- workflow default가 현재 release candidate와 다를 수 있으므로 `workflow_dispatch` 화면의 기본값을 그대로 쓰지 말고 입력값을 재확인하도록 한다.
- `draft=false`, `prerelease=false`인 official release에서만 stable Sparkle appcast와 Pages deployment가 실행된다고 적는다.
- Homebrew는 public DMG asset과 SHA256 확정 후 별도 승인 gate로 분리한다.
- 실행하지 않은 수동 smoke는 성공으로 기록하지 않도록 한다.

### 단계 검증

```bash
test -f mydocs/manual/public_release_runbook.md
rg -n "previous_release_ref|expected_rhwp_tag|require_latest_rhwp|include_rhwp_in_title|draft|prerelease|SPARKLE_ED_PRIVATE_KEY|Homebrew|rollback|Rollback" mydocs/manual/public_release_runbook.md
git diff --check
```

### 커밋 메시지

```text
Task #79 Stage 2: public release 실행 runbook 작성
```

## Stage 3 — release distribution guide 연결 보강

### 목표

- 기존 릴리스/배포 진입점에서 새 runbook을 찾을 수 있게 한다.
- `release_distribution_guide.md`와 `public_release_runbook.md`의 역할이 겹치지 않도록 문구를 정리한다.

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `mydocs/manual/release_distribution_guide.md` | runbook 링크와 읽는 시점 추가 | 기존 진실 원천 유지 |
| `mydocs/manual/public_release_runbook.md` | 필요 시 링크/표현 보정 | Stage 2 피드백 반영 |
| `mydocs/working/task_m040_79_stage3.md` | Stage 3 완료보고서 작성 | 연결 보강 내용 기록 |

### 반영 기준

- 하위 매뉴얼 표에 `public_release_runbook.md`를 추가한다.
- 전체 release flow에서 실제 배포일에는 runbook을 먼저 읽는다고 안내한다.
- 기존 최종 체크리스트는 유지하되, runbook이 실행 순서와 승인 gate를 담당한다고 구분한다.
- `release_distribution_guide.md`가 지나치게 장황해지지 않게 링크 중심으로 보정한다.

### 단계 검증

```bash
rg -n "public_release_runbook|public release 실행 runbook|메인테이너용" mydocs/manual/release_distribution_guide.md mydocs/manual/public_release_runbook.md
git diff --check
```

### 커밋 메시지

```text
Task #79 Stage 3: release guide에 runbook 진입점 추가
```

## Stage 4 — 최종 문서 검증과 보고

### 목표

- runbook과 연결 문서의 링크, 명령, placeholder, secret 미기록 원칙을 최종 검증한다.
- 최종 결과보고서와 오늘할일 완료 처리를 준비한다.

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `mydocs/manual/public_release_runbook.md` | 최종 표현, 링크, 체크리스트 보정 | 필요한 경우 |
| `mydocs/manual/release_distribution_guide.md` | 최종 연결 문구 보정 | 필요한 경우 |
| `mydocs/report/task_m040_79_report.md` | 최종 결과보고서 작성 | 모든 단계 완료 후 |
| `mydocs/orders/20260530.md` | 작업 상태 완료 처리 | 최종 보고 단계 |

### 최종 검증

```bash
git status --short --branch
git diff --check
test -f mydocs/manual/public_release_runbook.md
rg -n "public_release_runbook|Release Publish DMG|Release Rehearsal DMG|previous_release_ref|expected_rhwp_tag|require_latest_rhwp|include_rhwp_in_title|SPARKLE_ED_PRIVATE_KEY|Homebrew|rollback|Rollback" mydocs/manual
rg -n "password|app-specific password|\\.p8|\\.p12|private key|token" mydocs/manual/public_release_runbook.md
```

두 번째 `rg`는 secret 금지 원칙 확인용이다. 금지 대상 문자열이 등장하더라도 실제 secret 값이 아니라 기록 금지 항목 또는 secret 이름 설명인지 확인한다.

### 실제 실행 제외 확인

이번 task에서는 다음을 실행하지 않는다.

- `./scripts/release.sh <version>` public mode
- `Release Publish DMG` workflow dispatch
- notarization submit/wait
- GitHub Release 생성 또는 수정
- Pages deployment
- Sparkle appcast 갱신
- Homebrew tap PR 또는 push
- Cask version/SHA256 변경

### 커밋 메시지

```text
Task #79 Stage 4 + 최종 보고서: public release runbook 문서화 완료
```

## 승인 요청 사항

이 구현 계획 기준으로 Stage 1 진행 승인을 요청한다.
