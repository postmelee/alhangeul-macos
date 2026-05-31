# Task M013 #274 구현계획서

수행계획서: `mydocs/plans/task_m013_274.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #274 Issue Template 변경을 docs-only로 분류하도록 PR CI classifier 보정
- 마일스톤: M013 (`하이퍼-워터폴 작업환경 조성`)
- 브랜치: `local/task274`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac`
- 기준 브랜치: `devel`
- 선행 상태: #272/#273에서 GitHub Issue Forms가 `devel`에 병합되었고, 해당 PR에서 `.github/ISSUE_TEMPLATE/*`가 unclassified non-docs change로 분류되어 `macOS validation`이 실행되는 현상을 확인했다.
- 목표: Issue Template-only 변경은 macOS build 없이 docs/metadata 수준으로 분류하고, 필요 시 PR CI의 script checks에서 Issue Template YAML parse를 수행하게 한다.

## 구현 원칙

- `.github/*` 전체를 docs-only로 분류하지 않는다.
- `.github/workflows/*`는 계속 CI/release automation 변경으로 분류한다.
- `.github/ISSUE_TEMPLATE/*`만 앱 빌드 입력이 아닌 repository metadata로 분류한다.
- macOS validation job 자체와 release workflow는 변경하지 않는다.
- #273의 Issue Template 내용은 변경하지 않는다.
- 제품 Swift/Rust 코드, RustBridge, renderer, Xcode project는 변경하지 않는다.
- 검증은 classifier flag 변화와 YAML/script parse에 집중한다.

## Stage 1. 현재 classifier 동작 재현과 보정 설계 확정

### 목표

PR #273과 같은 Issue Template-only 변경이 현재 classifier에서 `run_macos_build=true`가 되는 현상을 재현하고, 보정 방식을 확정한다.

### 작업

- `scripts/ci/classify-pr-changes.sh`의 현재 docs-only 판정과 fallback 조건을 정리한다.
- #273 변경 경로와 동일한 실제 diff 또는 로컬 fixture로 classifier 현재 출력을 기록한다.
- `.github/ISSUE_TEMPLATE/*`를 docs/metadata 경로로 분류하는 보정 방식을 확정한다.
- PR CI script checks에 Issue Template YAML parse 검증을 추가할지 판단한다.
- Stage 1 보고서에 변경 전 flag와 설계 판단을 기록한다.

### 산출물

- `mydocs/working/task_m013_274_stage1.md`

### 검증

```bash
git status --short --branch
bash scripts/ci/classify-pr-changes.sh --help
bash scripts/ci/classify-pr-changes.sh devel HEAD
rg -n "is_docs_path|unclassified non-docs|ISSUE_TEMPLATE|macOS validation|run_macos_build" scripts/ci/classify-pr-changes.sh .github/workflows/pr-ci.yml mydocs/plans/task_m013_274.md
git diff --check
```

### 완료 기준

- Issue Template-only 변경이 현재 왜 macOS validation을 켜는지 단계 보고서에 재현 결과로 남긴다.
- Stage 2에서 수정할 경로와 검증 추가 여부가 확정된다.

### 커밋 메시지

```text
Task #274 Stage 1: CI 분류 오동작 재현과 설계 확정
```

## Stage 2. classifier와 YAML 검증 보정

### 목표

`.github/ISSUE_TEMPLATE/*` 변경을 docs/metadata 경로로 분류하고, Issue Template YAML을 PR CI script checks에서 검증하도록 보정한다.

### 작업

- `scripts/ci/classify-pr-changes.sh`의 `is_docs_path()`에 `.github/ISSUE_TEMPLATE/*`를 추가한다.
- `.github/workflows/*`가 release/script automation 경로로 계속 분류되는지 유지한다.
- `.github/workflows/pr-ci.yml`의 `script-checks`에 Issue Template YAML parse step을 추가한다.
  - `.github/ISSUE_TEMPLATE/*.yml`가 없을 때도 실패하지 않도록 Ruby glob을 사용한다.
  - workflow YAML parse와 별도 step으로 두어 실패 위치를 명확히 한다.
- Stage 2 보고서에 변경 파일과 의도한 CI flag 변화를 기록한다.

### 산출물

- `scripts/ci/classify-pr-changes.sh`
- `.github/workflows/pr-ci.yml`
- `mydocs/working/task_m013_274_stage2.md`

### 검증

```bash
bash -n scripts/ci/classify-pr-changes.sh
bash scripts/ci/classify-pr-changes.sh --help
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/pr-ci.yml")'
ruby -e 'require "psych"; Dir[".github/ISSUE_TEMPLATE/*.yml"].sort.each { |path| Psych.parse_file(path); puts "Parsed #{path}" }'
bash scripts/ci/classify-pr-changes.sh devel HEAD
git diff --check
```

### 완료 기준

- classifier script syntax가 통과한다.
- workflow YAML parse가 통과한다.
- Issue Template YAML parse 명령이 통과한다.
- 현재 브랜치 변경 범위에서 classifier가 기대한 flag를 출력한다.

### 커밋 메시지

```text
Task #274 Stage 2: Issue Template CI 분류 보정
```

## Stage 3. classifier case 검증과 회귀 방지 확인

### 목표

Issue Template-only 변경, workflow 변경, 제품 코드 변경 등 주요 case에서 classifier flag가 의도대로 나오는지 검증한다.

### 작업

- Issue Template-only 변경 case에서 `docs_only=true`, `run_macos_build=false`, `run_release_checks=false`를 확인한다.
- `.github/workflows/*` 변경 case가 여전히 release/script automation 변경으로 분류되는지 확인한다.
- `Sources/*` 또는 `project.yml` 변경 case가 여전히 `run_macos_build=true`를 내는지 확인한다.
- 필요 시 임시 branch 또는 git worktree 밖 fixture repo를 사용하되, 생성 산출물은 커밋하지 않는다.
- Stage 3 보고서에 case별 입력 경로, expected flag, actual flag를 표로 남긴다.

### 산출물

- 필요 시 `scripts/ci/classify-pr-changes.sh` 또는 `.github/workflows/pr-ci.yml` 보정
- `mydocs/working/task_m013_274_stage3.md`

### 검증

```bash
bash -n scripts/ci/classify-pr-changes.sh
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/pr-ci.yml")'
ruby -e 'require "psych"; Dir[".github/ISSUE_TEMPLATE/*.yml"].sort.each { |path| Psych.parse_file(path); puts "Parsed #{path}" }'
bash scripts/ci/classify-pr-changes.sh devel HEAD
git diff --check
git status --short --branch
```

### 완료 기준

- 최소 3개 classifier case가 보고서에 기록된다.
- Issue Template-only case에서 macOS validation trigger가 꺼진다.
- workflow/product code case의 기존 보수 분류가 유지된다.

### 커밋 메시지

```text
Task #274 Stage 3: CI 분류 case 검증
```

## Stage 4. 최종 검증과 보고

### 목표

전체 수용 기준을 다시 확인하고, 최종 결과보고서와 오늘할일 완료 처리를 수행한 뒤 PR 게시 준비 상태로 만든다.

### 작업

- 수행계획서와 구현계획서의 포함/제외 범위가 지켜졌는지 확인한다.
- 최종 결과보고서를 작성한다.
- `mydocs/orders/20260519.md`의 #274 상태를 완료로 갱신한다.
- PR 본문에 classifier 변경 이유, 검증 case, 남은 리스크를 정리한다.

### 산출물

- `mydocs/report/task_m013_274_report.md`
- `mydocs/orders/20260519.md`

### 검증

```bash
bash -n scripts/ci/classify-pr-changes.sh
bash scripts/ci/classify-pr-changes.sh --help
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/pr-ci.yml")'
ruby -e 'require "psych"; Dir[".github/ISSUE_TEMPLATE/*.yml"].sort.each { |path| Psych.parse_file(path); puts "Parsed #{path}" }'
bash scripts/ci/classify-pr-changes.sh devel HEAD
rg -n "ISSUE_TEMPLATE|run_macos_build|docs_only|Issue Template|macOS validation" scripts/ci/classify-pr-changes.sh .github/workflows/pr-ci.yml mydocs/report/task_m013_274_report.md
git diff --check
git status --short --branch
```

### 완료 기준

- 전체 검증 명령이 통과한다.
- 최종 보고서에 변경 파일, classifier flag 변화, 잔여 위험이 기록된다.
- 오늘할일이 완료 처리된다.
- 작업 트리가 clean 상태에서 PR 게시 승인 요청을 할 수 있다.

### 커밋 메시지

```text
Task #274 Stage 4 + 최종 보고서: CI 분류 보정 정리
```

## PR 계획

- 작업 브랜치: `local/task274`
- 게시 브랜치: `publish/task274`
- 대상 브랜치: `devel`
- PR 제목 후보: `Task #274: Issue Template 변경의 PR CI 분류 보정`
- PR 본문에는 #273에서 관측된 원인, classifier 변경, YAML 검증 추가, case별 flag 검증 결과를 포함한다.

## 변경 금지 사항

- `.github/workflows/*`를 docs-only로 분류하지 않는다.
- `macOS validation` job 자체를 삭제하거나 약화하지 않는다.
- release workflow, branch protection, required check 설정을 변경하지 않는다.
- #273의 Issue Template 내용은 수정하지 않는다.
- 제품 Swift/Rust 코드와 Xcode project를 수정하지 않는다.
