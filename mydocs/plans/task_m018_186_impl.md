# Task M018 #186 구현계획서

수행계획서: `mydocs/plans/task_m018_186.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #186 GitHub Actions Node.js 20 deprecation warning 대응
- 마일스톤: M018 (`v0.1.1`)
- 브랜치: `local/task186`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac`
- 기준 브랜치: `devel-webview`
- 선행 상태: #198 merge 완료. `PR CI`, release rehearsal/publish delta checklist, `ci_workflow_guide.md`가 존재한다.
- 분리된 후속 이슈: #206 Pages/appcast 배포 방식을 `deploy-pages` workflow로 전환 검토
- 목표: official action major를 Node.js 24 runtime 대응 버전으로 갱신하고, workflow/manual 기준을 정리해 Node.js 20 deprecation annotation이 다음 release 판단을 흐리지 않게 한다.

## 구현 원칙

- 이번 작업은 Node.js 20 warning 대응에 한정한다.
- GitHub Pages 배포 모델 전환은 #206으로 분리하고, #186에서는 branch Pages/appcast push 구조를 바꾸지 않는다.
- release publish의 `workflow_dispatch`, `environment: release`, tag 검증, signing/notarization, GitHub Release asset, Sparkle appcast 조건은 유지한다.
- 임시 우회 환경변수(`FORCE_JAVASCRIPT_ACTIONS_TO_NODE24`, `ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION`)는 사용하지 않는다.
- official action repository의 `action.yml` runtime과 release tag를 근거로 major version을 갱신한다.
- workflow 변경 후 PR CI 실제 run에서 Node.js 20 deprecation annotation 해소 여부를 확인한다.

## Stage 1. 공식 action/runtime 기준과 현 workflow 영향 분석

### 목표

현재 workflow에서 사용하는 GitHub Action과 official Node.js 24 대응 major를 확정하고, 갱신 위험을 workflow별로 정리한다.

### 작업

- `.github/workflows/`의 `uses:` action을 전수 확인한다.
  - `actions/checkout@v4`
  - `actions/upload-artifact@v4`
  - Pages 전용 `actions/deploy-pages`, `actions/upload-pages-artifact` 미사용 여부
- official source 기준을 기록한다.
  - GitHub Actions Node.js 20 deprecation changelog
  - `actions/checkout@v6` `runs.using: node24`
  - `actions/upload-artifact@v7` `runs.using: node24`
- checkout `v6` 영향 분석:
  - 일반 checkout
  - release tag checkout
  - PR CI checkout
  - `gh` CLI 사용 경로
  - release publish의 별도 `git clone` 기반 Pages branch push
- upload-artifact `v7` 영향 분석:
  - release delta checklist artifact
  - rehearsal DMG/checksum artifact
  - appcast artifact
  - signed public DMG/checksum/release notes artifact
- #206으로 분리한 Pages deployment model 전환 범위를 Stage 1 보고서에 명시한다.

### 예상 변경 파일

- `mydocs/working/task_m018_186_stage1.md`

### 검증

```bash
git status --short --branch
rg -n "uses:|actions/checkout@|actions/upload-artifact@|actions/deploy-pages|actions/upload-pages-artifact" .github/workflows
gh api repos/actions/checkout/contents/action.yml --method GET -f ref=v6 --jq '.content' | base64 --decode | rg -n "runs:|using:|node"
gh api repos/actions/upload-artifact/contents/action.yml --method GET -f ref=v7 --jq '.content' | base64 --decode | rg -n "runs:|using:|node"
gh issue view 206 --json number,title,state,url
git diff --check
```

### 완료 기준

- 갱신 대상 action과 목표 major version이 Stage 1 보고서에 확정된다.
- Pages `deploy-pages` 전환이 #206 범위임이 기록된다.
- checkout/upload-artifact 갱신 위험과 유지해야 할 workflow 경계가 정리된다.

### 커밋 메시지

```text
Task #186 Stage 1: Node.js 24 action 기준과 workflow 영향 분석
```

## Stage 2. workflow action version 갱신

### 목표

workflow 구조를 바꾸지 않고 `actions/checkout`과 `actions/upload-artifact` major version만 Node.js 24 대응 버전으로 갱신한다.

### 작업

- `.github/workflows/pr-ci.yml`
  - `actions/checkout@v4` -> `actions/checkout@v6`
- `.github/workflows/rhwp-upstream-check.yml`
  - `actions/checkout@v4` -> `actions/checkout@v6`
- `.github/workflows/release-rehearsal.yml`
  - `actions/checkout@v4` -> `actions/checkout@v6`
  - `actions/upload-artifact@v4` -> `actions/upload-artifact@v7`
- `.github/workflows/release-publish.yml`
  - `actions/checkout@v4` -> `actions/checkout@v6`
  - `actions/upload-artifact@v4` -> `actions/upload-artifact@v7`
- 다른 workflow 조건, permissions, environment, artifact path, Pages branch push logic은 변경하지 않는다.
- Stage 2 보고서에 변경 전/후 action reference 표를 남긴다.

### 예상 변경 파일

- `.github/workflows/pr-ci.yml`
- `.github/workflows/rhwp-upstream-check.yml`
- `.github/workflows/release-rehearsal.yml`
- `.github/workflows/release-publish.yml`
- `mydocs/working/task_m018_186_stage2.md`

### 검증

```bash
git status --short --branch
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/pr-ci.yml")'
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/release-rehearsal.yml")'
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/release-publish.yml")'
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/rhwp-upstream-check.yml")'
bash -n scripts/ci/*.sh
scripts/ci/classify-pr-changes.sh devel-webview HEAD
rg -n "actions/checkout@v4|actions/upload-artifact@v4|actions/checkout@v6|actions/upload-artifact@v7" .github/workflows
rg -n "FORCE_JAVASCRIPT_ACTIONS_TO_NODE24|ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION" .github/workflows mydocs/manual || true
git diff --check
```

### 완료 기준

- `actions/checkout@v4`와 `actions/upload-artifact@v4` reference가 workflow에서 제거된다.
- `actions/checkout@v6`와 `actions/upload-artifact@v7` reference가 기대 개수로 존재한다.
- workflow YAML parse가 모두 통과한다.
- PR CI 변경 범위 분류가 release checks를 켠다.

### 커밋 메시지

```text
Task #186 Stage 2: GitHub Actions official action major 갱신
```

## Stage 3. CI/runtime 대응 기준 문서화

### 목표

Node.js action runtime warning 대응 기준과 이후 action major 갱신 판단 절차를 문서화한다.

### 작업

- `mydocs/manual/ci_workflow_guide.md`에 다음을 추가한다.
  - JavaScript action runtime 점검 기준
  - official action `action.yml`의 `runs.using` 확인 방법
  - `checkout@v6`, `upload-artifact@v7` 기준
  - 임시 우회 환경변수를 기본 대응책으로 쓰지 않는 원칙
  - PR run에서 Node.js 20 deprecation annotation 확인 항목
- release 관련 guide 또는 entrypoint에 필요한 경우 짧은 링크를 추가한다.
- #206을 Pages deployment model 전환 검토 이슈로 링크한다.
- Stage 3 보고서에 문서 entrypoint와 후속 handoff를 정리한다.

### 예상 변경 파일

- `mydocs/manual/ci_workflow_guide.md`
- `mydocs/manual/release_distribution_guide.md` 또는 `mydocs/manual/release_github_pages_sparkle_guide.md` (필요 시)
- `mydocs/working/task_m018_186_stage3.md`

### 검증

```bash
git status --short --branch
rg -n "Node.js 20|Node.js 24|node24|checkout@v6|upload-artifact@v7|FORCE_JAVASCRIPT_ACTIONS_TO_NODE24|ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION|#206|deploy-pages" mydocs/manual .github/workflows
git diff --check
```

### 완료 기준

- Node.js action runtime warning 대응 기준이 `ci_workflow_guide.md`에서 확인된다.
- #206과 #186의 범위가 문서에서 분리된다.
- release workflow warning 대응 기준이 #188 handoff에 사용할 수 있게 남는다.

### 커밋 메시지

```text
Task #186 Stage 3: CI action runtime 대응 기준 문서화
```

## Stage 4. 최종 dry-run, 보고, PR 준비

### 목표

전체 변경을 검증하고, 로컬 검증과 PR run에서 확인해야 할 항목을 분리해 최종 보고서와 PR 본문에 남긴다.

### 작업

- workflow YAML parse를 반복한다.
- shell syntax와 release helper dry-run을 반복한다.
- action reference 검색을 반복한다.
- 오늘할일 상태를 완료로 갱신한다.
- 최종 보고서에 다음을 포함한다.
  - 변경 파일 목록과 영향 범위
  - action version 변경 전/후 표
  - 실행한 로컬 검증
  - PR run에서 Node.js 20 warning annotation 확인 결과
  - #206과 #188 handoff
- `task-final-report` 절차로 PR을 게시한다.

### 예상 변경 파일

- `mydocs/orders/20260510.md`
- `mydocs/report/task_m018_186_report.md`

### 검증

```bash
git status --short --branch
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/pr-ci.yml")'
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/release-rehearsal.yml")'
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/release-publish.yml")'
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/rhwp-upstream-check.yml")'
bash -n scripts/ci/*.sh
scripts/ci/classify-pr-changes.sh devel-webview HEAD
scripts/ci/write-release-delta-checklist.sh v0.1.0 HEAD build.noindex/release/delta-checklist-0.1.1.md
rg -n "actions/checkout@v4|actions/upload-artifact@v4|actions/checkout@v6|actions/upload-artifact@v7|Node.js 20|Node.js 24|#206" .github/workflows mydocs/manual mydocs/report
git diff --check
```

### 완료 기준

- 모든 workflow YAML parse가 통과한다.
- action reference가 Node.js 24 대응 major로 갱신된다.
- 최종 보고서와 오늘할일 갱신이 완료된다.
- PR 생성 후 GitHub Actions `PR CI`가 통과하고 Node.js 20 deprecation annotation이 남지 않는다.

### 커밋 메시지

```text
Task #186 Stage 4 + 최종 보고서: Node.js 20 Actions warning 대응 완료
```
