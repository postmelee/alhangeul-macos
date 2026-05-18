# Task M010 #264 구현계획서

## 개요

수행계획서 승인에 따라 릴리즈 안내의 사용자-facing 변경사항 구분 기준을 도입한다. 작업은 4단계로 진행하며, 각 단계 완료 후 단계 보고서와 커밋을 만들고 승인 없이 다음 단계로 넘어가지 않는다.

이번 작업은 release communication 기준과 생성 helper를 보강하는 범위다. 실제 upstream `rhwp` 갱신, public DMG 생성, GitHub Release 게시, Pages deployment, Sparkle appcast 갱신은 수행하지 않는다.

## Stage 1: 현황 inventory와 정보 구조 확정

### 목표

현재 release communication 표면이 변경사항을 어떻게 표현하는지 조사하고, `전체 요약`, `포함된 rhwp 변화`, `알한글 앱 변화`의 적용 위치와 상세도를 확정한다.

### 작업 범위

- `mydocs/manual/release_github_pages_sparkle_guide.md`의 GitHub Release body, Pages 업데이트 문서 기준 확인
- `mydocs/manual/release_policy_guide.md`, `mydocs/manual/release_distribution_guide.md`, `mydocs/release/index.md`의 관련 checklist와 정보 소유 기준 확인
- `scripts/ci/write-release-notes.sh`, `scripts/ci/check-release-notes-template.sh`의 현재 heading 구조 확인
- `mydocs/release/v0.1.2.md`, `docs/updates/v0.1.2.html`의 실제 변경사항 구분 사례 확인
- Stage 1 보고서에 구분 적용 원칙, 소유 표면, 후속 stage 변경 범위 기록

### 예상 변경 파일

- `mydocs/working/task_m010_264_stage1.md`

Stage 1에서는 조사 보고서만 작성하고 manual/script는 수정하지 않는다.

### 검증

```bash
rg -n "사용자용 요약|이번 버전의 주요 변경 사항|주요 변경|포함된 rhwp|Release metadata|release delta" \
  mydocs/manual/release_github_pages_sparkle_guide.md \
  mydocs/manual/release_policy_guide.md \
  mydocs/manual/release_distribution_guide.md \
  mydocs/release/index.md \
  mydocs/release/v0.1.2.md \
  docs/updates/v0.1.2.html \
  scripts/ci/write-release-notes.sh \
  scripts/ci/check-release-notes-template.sh
git diff --check -- mydocs/working/task_m010_264_stage1.md
```

### 커밋

```text
Task #264 Stage 1: 릴리즈 안내 변경사항 구조 조사
```

### 승인 요청

Stage 1 보고서에서 실제 적용 구조와 Stage 2~3 변경 범위를 확인받은 뒤 Stage 2로 진행한다.

## Stage 2: release manual과 내부 기록 기준 보강

### 목표

반복 적용되는 작성 기준을 manual과 release 기록 인덱스에 반영한다. GitHub Release body와 Pages가 같은 세 구분을 따르되, 상세도는 각 표면의 역할에 맞게 다르게 둔다.

### 작업 범위

- `release_github_pages_sparkle_guide.md`에 GitHub Release body의 변경사항 구분 기준 추가
- `release_github_pages_sparkle_guide.md`에 Pages 릴리즈 노트의 짧은 구분 적용 기준 추가
- 필요 시 `release_policy_guide.md`의 bundled `rhwp` 표기 정책에 `포함된 rhwp 변화` 작성 원칙 연결
- 필요 시 `release_distribution_guide.md` 최종 체크리스트에 변경사항 구분 확인 항목 보강
- `mydocs/release/index.md`의 릴리즈 문서 갱신 순서 또는 정보 소유 기준에 새 구분 반영
- Stage 2 보고서 작성

### 예상 변경 파일

- `mydocs/manual/release_github_pages_sparkle_guide.md`
- `mydocs/manual/release_policy_guide.md` (필요 시)
- `mydocs/manual/release_distribution_guide.md` (필요 시)
- `mydocs/release/index.md`
- `mydocs/working/task_m010_264_stage2.md`

### 검증

```bash
rg -n "전체 요약|포함된 rhwp 변화|알한글 앱 변화|GitHub Release body|Pages" \
  mydocs/manual/release_github_pages_sparkle_guide.md \
  mydocs/manual/release_policy_guide.md \
  mydocs/manual/release_distribution_guide.md \
  mydocs/release/index.md
git diff --check -- \
  mydocs/manual/release_github_pages_sparkle_guide.md \
  mydocs/manual/release_policy_guide.md \
  mydocs/manual/release_distribution_guide.md \
  mydocs/release/index.md \
  mydocs/working/task_m010_264_stage2.md
```

### 커밋

```text
Task #264 Stage 2: 릴리즈 변경사항 구분 기준 문서화
```

### 승인 요청

Stage 2 보고서에서 manual 기준과 정보 소유 경계를 확인받은 뒤 Stage 3으로 진행한다.

## Stage 3: release note 생성/검증 스크립트 보강

### 목표

GitHub Release body 후보 생성 스크립트와 template checker가 새 변경사항 구분을 기본 구조로 만들고 검증하게 한다.

### 작업 범위

- `scripts/ci/write-release-notes.sh`의 `## 이번 버전의 주요 변경 사항` 하위 구조를 보강
- 생성 결과에 `### 전체 요약`, `### 포함된 rhwp 변화`, `### 알한글 앱 변화`를 포함
- `포함된 rhwp 변화`에는 current lock/manifest 기준 `rhwp` tag와 upstream release URL을 자동으로 포함하되, 실제 사용자 영향은 release owner가 보정해야 함을 명시
- `rhwp` 미변경 릴리즈에서 사용할 수 있는 짧은 문구 기준을 template에 남길지 검토
- `scripts/ci/check-release-notes-template.sh`가 새 필수 heading을 검사하도록 보강
- Stage 3 보고서 작성

### 예상 변경 파일

- `scripts/ci/write-release-notes.sh`
- `scripts/ci/check-release-notes-template.sh`
- `mydocs/working/task_m010_264_stage3.md`

### 검증

```bash
bash -n scripts/ci/write-release-notes.sh
bash -n scripts/ci/check-release-notes-template.sh
bash scripts/ci/write-release-notes.sh 0.1.3 0000000000000000000000000000000000000000000000000000000000000000 build.noindex/release/release-notes-0.1.3.md
bash scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.3.md
rg -n "### 전체 요약|### 포함된 rhwp 변화|### 알한글 앱 변화|Release metadata|rhwp core release tag" \
  build.noindex/release/release-notes-0.1.3.md \
  scripts/ci/write-release-notes.sh \
  scripts/ci/check-release-notes-template.sh
git diff --check -- \
  scripts/ci/write-release-notes.sh \
  scripts/ci/check-release-notes-template.sh \
  mydocs/working/task_m010_264_stage3.md
```

### 커밋

```text
Task #264 Stage 3: release note 변경사항 템플릿 보강
```

### 승인 요청

Stage 3 보고서에서 generated release note 후보와 checker 결과를 확인받은 뒤 Stage 4로 진행한다.

## Stage 4: 통합 검증과 최종 보고

### 목표

문서와 스크립트가 같은 기준을 따르는지 통합 검증하고, 최종 결과보고서와 오늘할일 상태를 정리한다.

### 작업 범위

- Stage 1~3 산출물의 기준 일관성 확인
- release note dry-run 결과의 heading, provenance, 작성 지침 문구 확인
- public release 실행 제외 범위 재확인
- `mydocs/report/task_m010_264_report.md` 작성
- `mydocs/orders/20260518.md` 상태 완료로 갱신

### 예상 변경 파일

- `mydocs/report/task_m010_264_report.md`
- `mydocs/orders/20260518.md`
- `mydocs/working/task_m010_264_stage4.md`

### 검증

```bash
bash -n scripts/ci/write-release-notes.sh scripts/ci/check-release-notes-template.sh
bash scripts/ci/write-release-notes.sh 0.1.3 0000000000000000000000000000000000000000000000000000000000000000 build.noindex/release/release-notes-0.1.3.md
bash scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.3.md
rg -n "전체 요약|포함된 rhwp 변화|알한글 앱 변화|GitHub Release body|Pages|Release metadata" \
  build.noindex/release/release-notes-0.1.3.md \
  mydocs/manual/release_github_pages_sparkle_guide.md \
  mydocs/release/index.md \
  mydocs/report/task_m010_264_report.md
git status --short
git diff --check
```

### 커밋

```text
Task #264 Stage 4 + 최종 보고서: 릴리즈 안내 구분 기준 도입 완료
```

### 승인 요청

최종 보고서 승인 후 `task-final-report` 절차로 PR 게시를 진행한다.

## 공통 주의사항

- 기존 public GitHub Release body를 수정하지 않는다.
- public Pages deployment와 Sparkle appcast 갱신을 실행하지 않는다.
- generated release note는 실제 변경사항 자동 요약이 아니라 release owner가 보정해야 하는 후보임을 유지한다.
- Pages는 사용자용 짧은 안내 표면이므로 GitHub Release body의 긴 검증/provenance를 복제하지 않는다.
- unrelated worktree 또는 #263 변경 파일은 건드리지 않는다.

## 승인 요청 사항

1. 위 4단계 구현계획 승인
2. Stage 3 generated GitHub Release body의 하위 heading을 `### 전체 요약`, `### 포함된 rhwp 변화`, `### 알한글 앱 변화`로 고정하는 방향 승인
3. 승인 후 Stage 1 `현황 inventory와 정보 구조 확정` 진행
