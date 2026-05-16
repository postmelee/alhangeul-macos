# Task M019 #214 구현계획서

수행계획서: `mydocs/plans/task_m019_214.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #214 Pages workflow 전환 후 docs-only 즉시 배포와 appcast 보존 workflow 추가
- 마일스톤: M019 (`v0.1.2`)
- 브랜치: `local/task214`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac`
- 기준 브랜치: `devel`
- 선행 상태: #206에서 `Release Publish DMG` workflow가 `actions/upload-pages-artifact@v5`와 `actions/deploy-pages@v5` 기반 release-driven Pages deployment로 전환되어 있다.
- 목표: `main`의 `docs/**` 변경을 docs-only Pages workflow로 즉시 배포하되, public stable Sparkle `appcast.xml`을 stale repository copy로 덮어쓰지 않는다.

## 확인된 현재 상태

2026-05-17 기준 로컬 확인 결과:

- 현재 브랜치 `local/task214`는 `devel`에서 분기했다.
- `.github/workflows/release-publish.yml`은 stable release path에서 `scripts/ci/prepare-pages-artifact.sh`, `actions/upload-pages-artifact@v5`, `actions/deploy-pages@v5`를 사용한다.
- `scripts/ci/prepare-pages-artifact.sh`는 `docs/` 정적 파일과 입력 appcast 파일을 artifact root의 `appcast.xml`로 조립한다.
- `docs/appcast.xml`은 repository에 남아 있는 feed copy이며, 현재 내용은 `Alhangeul v0.1.0` item을 포함한다. public 최신 release feed와 어긋날 수 있으므로 docs-only 배포에서 그대로 사용하면 stale overwrite 위험이 있다.
- `PR CI`는 workflow와 `scripts/ci/**` 변경을 `run_release_checks=true`로 분류하고, release helper dry-run에서 `prepare-pages-artifact.sh`를 검증한다.
- `release_github_pages_sparkle_guide.md`, `ci_workflow_guide.md`, `release_distribution_guide.md`에는 release-driven Pages deployment 기준은 있으나 docs-only Pages deployment와 appcast 보존 정책은 아직 없다.

## 구현 원칙

- docs-only Pages deployment는 release publish workflow와 분리한다.
- docs-only workflow는 `main` branch의 `docs/**` 변경에서 실행한다. PR 대상 브랜치나 `devel` push에서 public Pages를 배포하지 않는다.
- docs-only workflow는 Sparkle appcast를 새로 생성하지 않는다.
- docs-only workflow는 public `https://postmelee.github.io/alhangeul-macos/appcast.xml`을 다운로드해 검증한 뒤 Pages artifact에 주입한다.
- public appcast 다운로드, 빈 파일 검증, XML 검증 중 하나라도 실패하면 docs-only 배포를 실패시킨다. stale `docs/appcast.xml` fallback은 허용하지 않는다.
- Pages artifact 조립은 기존 `scripts/ci/prepare-pages-artifact.sh`를 재사용한다. docs-only workflow는 public appcast를 local file로 준비한 뒤 기존 helper에 넘긴다.
- release workflow와 docs-only workflow는 같은 Pages site를 배포하므로 concurrency group을 공유한다. official release deployment를 중간에 취소하지 않기 위해 `cancel-in-progress: false`를 사용한다.
- `github-pages` environment는 release tag `v*`와 `main` branch deployment를 모두 허용해야 한다. 실제 environment policy 변경은 작업지시자 승인 없이 수행하지 않고, 매뉴얼과 보고서에 전제 조건으로 기록한다.

## Stage 1. docs-only 배포 현황과 appcast 보존 정책 고정

### 목표

#206 이후 release-driven Pages deployment 구조와 stale appcast 위험을 확인하고, docs-only workflow가 사용할 appcast 보존 정책을 단계 보고서에 고정한다.

### 작업

- `release-publish.yml`의 Pages artifact upload와 `deploy-pages` job 구조를 확인한다.
- `scripts/ci/prepare-pages-artifact.sh`의 입력/출력 계약을 확인한다.
- `docs/appcast.xml`의 repository copy가 stale feed가 될 수 있음을 기록한다.
- 가능하면 public appcast URL을 다운로드해 XML 검증 가능 여부를 확인한다.
- `github-pages` environment policy에서 `main` branch deployment가 허용되어야 한다는 전제를 기록한다.
- 결론을 다음으로 확정한다.
  - docs-only workflow는 public appcast를 다운로드해 보존한다.
  - stale repository appcast fallback은 금지한다.
  - 기존 Pages artifact helper를 재사용한다.

### 예상 변경 파일

- `mydocs/working/task_m019_214_stage1.md`

### 검증

```bash
git status --short --branch
rg -n "upload-pages-artifact|deploy-pages|prepare-pages-artifact|github-pages|appcast.xml|concurrency" .github/workflows scripts/ci mydocs/manual
sed -n '1,120p' docs/appcast.xml
curl -fsSL https://postmelee.github.io/alhangeul-macos/appcast.xml \
  -o build.noindex/release/public-appcast.xml
xmllint --noout build.noindex/release/public-appcast.xml
git diff --check
```

네트워크 접근 또는 public Pages 응답 확인이 로컬에서 불가능하면 Stage 1 보고서에 미실행 사유와 GitHub Actions에서 확인할 명령을 남긴다.

### 완료 기준

- Stage 1 보고서에 현재 release-driven Pages 구조와 stale appcast 위험이 기록된다.
- docs-only appcast 보존 정책과 fallback 금지 정책이 확정된다.
- Stage 2에서 구현할 workflow 구조의 전제가 명확하다.

### 커밋 메시지

```text
Task #214 Stage 1: docs-only Pages appcast 보존 정책 확정
```

## Stage 2. docs-only Pages deploy workflow 추가

### 목표

`main` branch의 `docs/**` 변경을 감지해 public appcast를 보존한 Pages artifact를 배포하는 workflow를 추가한다.

### 작업

- `.github/workflows/pages-docs-deploy.yml`을 추가한다.
- trigger를 설정한다.
  - `push.branches`: `main`
  - `push.paths`: `docs/**`
  - `workflow_dispatch`
- workflow 권한을 최소화한다.
  - top-level `contents: read`
  - deploy job `pages: write`, `id-token: write`
- concurrency group을 release workflow와 공유할 수 있는 이름으로 둔다.
  - 후보: `pages-deploy`
  - `cancel-in-progress: false`
- artifact 준비 job을 구성한다.
  - checkout
  - `build.noindex/release` 생성
  - public appcast URL 다운로드
  - `test -s`와 `xmllint --noout` 검증
  - `scripts/ci/prepare-pages-artifact.sh --docs-dir docs --appcast build.noindex/release/public-appcast.xml --output-dir build.noindex/release/pages-artifact`
  - `index.html`, `updates/index.html`, `appcast.xml` 존재 검증
  - `GITHUB_STEP_SUMMARY`에 appcast source URL과 artifact 검증 결과 기록
  - `actions/upload-pages-artifact@v5`
- deploy job을 구성한다.
  - `needs`로 artifact 준비 job을 요구한다.
  - `environment.name: github-pages`
  - `environment.url: ${{ steps.deployment.outputs.page_url }}`
  - `actions/deploy-pages@v5`
  - summary에 deployment URL과 appcast URL 기록

### 예상 변경 파일

- `.github/workflows/pages-docs-deploy.yml`
- `mydocs/working/task_m019_214_stage2.md`

### 검증

```bash
git status --short --branch
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/pages-docs-deploy.yml")'
rg -n "on:|branches:|paths:|workflow_dispatch|pages-deploy|cancel-in-progress|pages: write|id-token: write|upload-pages-artifact@v5|deploy-pages@v5|prepare-pages-artifact|appcast.xml" .github/workflows/pages-docs-deploy.yml
bash -n scripts/ci/*.sh
scripts/ci/prepare-pages-artifact.sh --help
git diff --check
```

가능하면 public appcast를 실제로 내려받아 helper를 실행한다.

```bash
mkdir -p build.noindex/release
curl -fsSL https://postmelee.github.io/alhangeul-macos/appcast.xml \
  -o build.noindex/release/public-appcast.xml
xmllint --noout build.noindex/release/public-appcast.xml
scripts/ci/prepare-pages-artifact.sh \
  --docs-dir docs \
  --appcast build.noindex/release/public-appcast.xml \
  --output-dir build.noindex/release/pages-artifact
test -f build.noindex/release/pages-artifact/index.html
test -f build.noindex/release/pages-artifact/updates/index.html
xmllint --noout build.noindex/release/pages-artifact/appcast.xml
```

### 완료 기준

- docs-only workflow가 추가된다.
- workflow가 repository `docs/appcast.xml`을 직접 배포하지 않고 public appcast를 내려받아 artifact에 주입한다.
- public appcast 검증 실패 시 deployment가 진행되지 않는 구조다.
- Stage 2 보고서에 workflow trigger, permission, concurrency, artifact 검증 결과가 기록된다.

### 커밋 메시지

```text
Task #214 Stage 2: docs-only Pages deploy workflow 추가
```

## Stage 3. Release workflow concurrency와 PR CI 검증 보강

### 목표

release-driven Pages deployment와 docs-only Pages deployment가 같은 Pages site를 동시에 덮어쓰지 않도록 concurrency 정책을 맞추고, 새 workflow가 PR CI에서 검증되게 한다.

### 작업

- `.github/workflows/release-publish.yml`의 Pages deployment 관련 concurrency를 검토한다.
- release workflow와 docs-only workflow가 같은 Pages deployment group을 공유하도록 필요한 보강을 적용한다.
  - workflow 전체 concurrency를 바꾸는 방식이 release publish version별 실행 제약을 흐리면, Pages deploy job 수준에서 안전하게 적용 가능한 구조를 우선 검토한다.
  - GitHub Actions job-level concurrency가 적용 가능하면 deploy job에 `group: pages-deploy`, `cancel-in-progress: false`를 둔다.
  - job-level concurrency 적용이 부적절하면 workflow-level concurrency 한계와 운영상 serialized deployment 전제를 문서에 명확히 남긴다.
- `.github/workflows/pr-ci.yml` release checks에 workflow YAML parse 검증을 추가한다.
  - `.github/workflows/*.yml` 또는 주요 workflow file을 `Psych.parse_file`로 확인한다.
  - 새 `pages-docs-deploy.yml`이 검증 대상에 포함된다.
- 변경 범위 helper가 새 workflow 변경을 `run_release_checks=true`로 분류하는지 확인한다.

### 예상 변경 파일

- `.github/workflows/release-publish.yml`
- `.github/workflows/pr-ci.yml`
- 필요 시 `scripts/ci/classify-pr-changes.sh`
- `mydocs/working/task_m019_214_stage3.md`

### 검증

```bash
git status --short --branch
ruby -e 'require "psych"; Dir[".github/workflows/*.yml"].sort.each { |path| Psych.parse_file(path) }'
scripts/ci/classify-pr-changes.sh devel HEAD
bash -n scripts/ci/*.sh
rg -n "concurrency:|pages-deploy|cancel-in-progress|Psych.parse_file|pages-docs-deploy|run_release_checks" .github/workflows scripts/ci
git diff --check
```

### 완료 기준

- release-driven deployment와 docs-only deployment의 concurrency 정책이 같은 기준으로 정리된다.
- PR CI가 새 workflow YAML parse를 포함한다.
- Stage 3 보고서에 concurrency 선택 이유와 한계가 기록된다.

### 커밋 메시지

```text
Task #214 Stage 3: Pages deployment concurrency와 PR CI 검증 보강
```

## Stage 4. CI/Release/Pages 운영 매뉴얼 갱신

### 목표

release-driven Pages deployment와 docs-only Pages deployment의 역할 차이, appcast 보존 정책, GitHub environment 전제 조건을 장기 운영 문서에 기록한다.

### 작업

- `ci_workflow_guide.md`에 `Docs-only Pages Deploy` workflow 항목을 추가한다.
  - trigger, 권한, runner, artifact source, appcast source, deployment output
  - public appcast 다운로드 실패 시 stale fallback 없이 실패한다는 기준
  - 수동 재현 명령
- `release_github_pages_sparkle_guide.md`에 docs-only Pages 배포 모델을 추가한다.
  - release workflow는 generated appcast를 배포한다.
  - docs-only workflow는 public latest appcast를 보존한다.
  - `docs/appcast.xml` repository copy는 docs-only 배포 source로 사용하지 않는다.
  - `github-pages` environment는 `main` branch와 release tag `v*` deployment를 허용해야 한다.
- `release_distribution_guide.md`의 현재 release 자산과 체크리스트에 docs-only workflow와 appcast 보존 확인을 반영한다.

### 예상 변경 파일

- `mydocs/manual/ci_workflow_guide.md`
- `mydocs/manual/release_github_pages_sparkle_guide.md`
- `mydocs/manual/release_distribution_guide.md`
- `mydocs/working/task_m019_214_stage4.md`

### 검증

```bash
git status --short --branch
rg -n "Docs-only|docs-only|pages-docs-deploy|public appcast|stale|fallback|github-pages|main|v\\*|Pages deployment" mydocs/manual
git diff --check
```

### 완료 기준

- 운영 매뉴얼에서 두 Pages deployment 경로의 역할 차이를 확인할 수 있다.
- stale `docs/appcast.xml` fallback 금지 정책이 문서화된다.
- environment branch/tag policy 전제 조건이 명확하다.

### 커밋 메시지

```text
Task #214 Stage 4: docs-only Pages 운영 기준 문서화
```

## Stage 5. 통합 검증과 최종 정리

### 목표

전체 변경의 로컬 검증을 수행하고, 실제 GitHub Pages deployment는 merge 후 확인해야 하는 항목으로 분리해 최종 보고한다.

### 작업

- workflow YAML parse, shell syntax, helper dry-run, release helper dry-run을 수행한다.
- 가능하면 public appcast 다운로드와 Pages artifact 조립을 로컬에서 수행한다.
- PR CI 변경 범위 분류가 예상대로 `run_release_checks=true`를 켜는지 확인한다.
- Stage 5 보고서에 로컬 검증 결과와 GitHub-hosted runner에서 확인할 항목을 남긴다.
- 최종 결과보고서에 구현 요약, 검증 결과, 미실행/잔여 위험, PR 후 확인 항목을 정리한다.

### 예상 변경 파일

- `mydocs/working/task_m019_214_stage5.md`
- `mydocs/report/task_m019_214_report.md`
- `mydocs/orders/20260517.md`

### 검증

```bash
git status --short --branch
ruby -e 'require "psych"; Dir[".github/workflows/*.yml"].sort.each { |path| Psych.parse_file(path) }'
bash -n scripts/ci/*.sh
scripts/ci/prepare-pages-artifact.sh --help
scripts/ci/write-sparkle-appcast.sh \
  --version 0.1.2 \
  --build 8 \
  --dmg-url https://github.com/postmelee/alhangeul-macos/releases/download/v0.1.2/alhangeul-macos-0.1.2.dmg \
  --length 1 \
  --ed-signature dummy-ed-signature \
  --release-notes-url https://postmelee.github.io/alhangeul-macos/updates/v0.1.2.html \
  --pub-date "Fri, 08 May 2026 09:00:00 +0000" \
  --minimum-system-version 12.0 \
  --output build.noindex/release/appcast.xml
xmllint --noout build.noindex/release/appcast.xml
scripts/ci/prepare-pages-artifact.sh \
  --docs-dir docs \
  --appcast build.noindex/release/appcast.xml \
  --output-dir build.noindex/release/pages-artifact
xmllint --noout build.noindex/release/pages-artifact/appcast.xml
test -f build.noindex/release/pages-artifact/index.html
test -f build.noindex/release/pages-artifact/updates/index.html
scripts/ci/classify-pr-changes.sh devel HEAD
git diff --check
```

가능하면 public appcast 보존 경로도 확인한다.

```bash
curl -fsSL https://postmelee.github.io/alhangeul-macos/appcast.xml \
  -o build.noindex/release/public-appcast.xml
xmllint --noout build.noindex/release/public-appcast.xml
scripts/ci/prepare-pages-artifact.sh \
  --docs-dir docs \
  --appcast build.noindex/release/public-appcast.xml \
  --output-dir build.noindex/release/docs-only-pages-artifact
xmllint --noout build.noindex/release/docs-only-pages-artifact/appcast.xml
```

### 완료 기준

- 로컬에서 workflow parse와 shell/helper 검증이 통과한다.
- docs-only workflow의 appcast 보존 경로가 로컬 dry-run 또는 GitHub Actions 확인 항목으로 정리된다.
- 최종 보고서에 merge 후 `main` docs 변경 또는 수동 dispatch로 확인할 GitHub Pages deployment 항목이 남는다.

### 커밋 메시지

```text
Task #214 Stage 5 + 최종 보고서: docs-only Pages 배포 검증 정리
```

## 승인 요청 사항

1. 위 5단계 구현계획 승인
2. Stage 1에서 public appcast 다운로드 검증과 stale fallback 금지 정책을 단계 보고서로 확정하는 방향 승인
3. Stage 2에서 신규 `.github/workflows/pages-docs-deploy.yml`을 추가하고 기존 `prepare-pages-artifact.sh`를 재사용하는 방향 승인
4. Stage 3에서 Pages deployment concurrency와 PR CI workflow parse 검증을 보강하는 방향 승인
5. 승인 후 Stage 1 진행
