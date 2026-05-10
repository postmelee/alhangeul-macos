# Task M018 #206 구현계획서

수행계획서: `mydocs/plans/task_m018_206.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #206 Pages/appcast 배포 방식을 deploy-pages workflow로 전환 검토
- 마일스톤: M018 (`v0.1.1`)
- 브랜치: `local/task206`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac`
- 기준 브랜치: `devel-webview`
- 선행 상태: #185, #198, #186, #187, #208 완료. release note, PR CI, Node.js 24 action runtime, Homebrew 정책, universal DMG 안내 기준은 이미 정리되어 있다.
- 목표: `Release Publish DMG` workflow에서 stable appcast 생성 이후 GitHub Pages deployment까지 같은 workflow run에서 검증 가능한 구조로 전환한다.

## 확인된 현재 상태

2026-05-10 기준 확인 결과:

- GitHub Pages API: `build_type=legacy`, `source.branch=main`, `source.path=/docs`, `status=built`, `html_url=https://postmelee.github.io/alhangeul-macos/`
- 최신 legacy Pages build: pusher `postmelee`, commit `9174d161bc5b689fa202bc8c0da55fd2a1d038c3`, `created_at=2026-05-09T10:43:15Z`
- repository Actions default workflow permission: `read`
- `github-pages` environment는 존재하며 custom deployment branch policy를 사용한다.
- 현재 `github-pages` environment 허용 branch policy: `devel-webview`, `gh-pages`, `main`, `publish/task135`
- `v*` tag deployment policy는 아직 없다.
- `actions/deploy-pages` latest release: `v5.0.0`, published `2026-03-25T16:59:14Z`
- `actions/upload-pages-artifact` latest release: `v5.0.0`, published `2026-04-10T18:22:59Z`

공식 문서 기준:

- GitHub Pages branch publishing에서는 `GITHUB_TOKEN`을 사용하는 workflow가 push한 commit이 Pages build를 trigger하지 않는다.
- custom GitHub Actions workflow 방식은 static files artifact upload 후 `deploy-pages`로 배포하는 흐름을 권장한다.
- `deploy-pages` 배포 job은 최소 `pages: write`, `id-token: write` 권한이 필요하다.
- `deploy-pages`는 `github-pages` environment 사용을 권장하고, output `page_url`을 제공한다.
- environment deployment branch/tag rule은 workflow run의 `GITHUB_REF`와 매칭된다. release workflow가 tag ref `v<version>`에서 실행되므로 `github-pages` environment에 `v*` tag rule이 필요하다.
- Pages API는 `build_type`을 `legacy` 또는 `workflow`로 설정할 수 있다. `workflow` 전환에는 Pages write와 Administration write 권한이 필요하다.

참고 URL:

- https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site
- https://docs.github.com/en/rest/pages/pages
- https://docs.github.com/en/actions/reference/deployments-and-environments
- https://github.com/actions/deploy-pages/releases/tag/v5.0.0
- https://github.com/actions/upload-pages-artifact/releases/tag/v5.0.0

## 구현 원칙

- `Release Publish DMG`의 수동 실행, `environment: release`, tag 검증, signed/notarized DMG 생성, GitHub Release asset upload, Sparkle EdDSA signing 조건은 유지한다.
- `draft=false`이고 `prerelease=false`인 official stable release에서만 stable appcast와 Pages deployment를 수행한다.
- branch push 기반 `docs/appcast.xml` 갱신 경로는 기본 release path에서 제거한다.
- generated appcast는 repository branch에 커밋하지 않고 Pages artifact에 overlay한다.
- Pages artifact는 release tag에 포함된 `docs/` 정적 파일을 기준으로 만들고, generated `appcast.xml`만 덮어쓴다.
- Pages source를 `workflow`로 전환하고 `github-pages` environment에 `v*` tag deployment policy를 추가하는 저장소 설정 변경은 작업지시자 별도 승인 후에만 실행한다.
- workflow 변경은 repository 설정이 아직 legacy이면 실패 원인을 명확히 알 수 있도록 문서와 stage report에 precondition으로 남긴다.
- GitHub Actions action은 official `actions/*` major tag를 사용한다: `actions/upload-pages-artifact@v5`, `actions/deploy-pages@v5`.

## Stage 1. Pages 배포 모델 확정과 설정 변경 승인 항목 정리

### 목표

현재 repository Pages/environment 설정과 공식 문서 기준을 단계 보고서로 고정하고, `deploy-pages` 전환에 필요한 저장소 설정 변경을 작업지시자 승인 항목으로 분리한다.

### 작업

- `gh api repos/postmelee/alhangeul-macos/pages` 결과를 stage report에 기록한다.
- `gh api repos/postmelee/alhangeul-macos/environments/github-pages`와 deployment branch policy 결과를 stage report에 기록한다.
- official docs 근거를 정리한다.
  - branch publishing의 `GITHUB_TOKEN` push trigger 한계
  - custom Actions Pages workflow 흐름
  - `deploy-pages` required permissions/environment/output
  - environment branch/tag policy와 `GITHUB_REF` 매칭
  - Pages API `build_type=workflow` 전환 조건
- 결론을 `deploy-pages` 전환으로 확정한다.
- 별도 승인 필요 항목을 명시한다.
  - Pages source: `legacy` -> `workflow`
  - `github-pages` environment에 tag policy `v*` 추가

### 예상 변경 파일

- `mydocs/working/task_m018_206_stage1.md`

### 검증

```bash
git status --short --branch
gh api repos/postmelee/alhangeul-macos/pages
gh api repos/postmelee/alhangeul-macos/environments/github-pages
gh api repos/postmelee/alhangeul-macos/environments/github-pages/deployment-branch-policies
gh release view -R actions/deploy-pages --json tagName,publishedAt,url
gh release view -R actions/upload-pages-artifact --json tagName,publishedAt,url
git diff --check
```

### 완료 기준

- Stage 1 보고서에 전환 결론과 근거가 기록된다.
- Pages source 전환과 `v*` tag policy 추가가 별도 승인 항목으로 분리된다.
- code/workflow 변경 전 필요한 precondition이 명확하다.

### 커밋 메시지

```text
Task #206 Stage 1: Pages deploy-pages 전환 기준 확정
```

## Stage 2. Pages artifact helper와 PR CI 검증 연결

### 목표

release workflow에서 사용할 Pages artifact assembly를 로컬과 PR CI에서 검증 가능한 helper로 분리한다.

### 작업

- `scripts/ci/prepare-pages-artifact.sh`를 추가한다.
  - 입력: `--docs-dir <dir> --appcast <file> --output-dir <dir>`
  - `docs/` 정적 파일을 output dir에 복사한다.
  - generated appcast를 output dir의 `appcast.xml`로 덮어쓴다.
  - `index.html`, `updates/index.html`, `updates/v<version>.html` 같은 기존 파일은 그대로 유지한다.
  - source/output 경로가 같거나 appcast가 없으면 실패한다.
  - `--help`를 제공한다.
- PR CI release helper checks에 helper syntax/interface/dry-run을 추가한다.
- release 변경 범위 분류가 helper 추가로 `run_release_checks=true`를 유지하는지 확인한다.
- Stage 2 보고서에 artifact directory 구조와 검증 fixture를 기록한다.

### 예상 변경 파일

- `scripts/ci/prepare-pages-artifact.sh`
- `.github/workflows/pr-ci.yml`
- `mydocs/working/task_m018_206_stage2.md`

### 검증

```bash
git status --short --branch
bash -n scripts/ci/prepare-pages-artifact.sh
scripts/ci/prepare-pages-artifact.sh --help
scripts/ci/write-sparkle-appcast.sh \
  --version 0.1.1 \
  --build 2 \
  --dmg-url https://github.com/postmelee/alhangeul-macos/releases/download/v0.1.1/alhangeul-macos-0.1.1.dmg \
  --length 1 \
  --ed-signature dummy-ed-signature \
  --release-notes-url https://postmelee.github.io/alhangeul-macos/updates/v0.1.1.html \
  --pub-date "Fri, 08 May 2026 09:00:00 +0000" \
  --minimum-system-version 12.0 \
  --output build.noindex/release/appcast.xml
scripts/ci/prepare-pages-artifact.sh \
  --docs-dir docs \
  --appcast build.noindex/release/appcast.xml \
  --output-dir build.noindex/release/pages-artifact
xmllint --noout build.noindex/release/pages-artifact/appcast.xml
test -f build.noindex/release/pages-artifact/index.html
test -f build.noindex/release/pages-artifact/updates/index.html
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/pr-ci.yml")'
scripts/ci/classify-pr-changes.sh devel-webview HEAD
git diff --check
```

### 완료 기준

- helper가 generated appcast를 포함한 Pages artifact directory를 만든다.
- PR CI release helper checks에서 helper interface/dry-run을 검증한다.
- Stage 2 보고서에 로컬 dry-run 결과와 artifact 구조가 기록된다.

### 커밋 메시지

```text
Task #206 Stage 2: Pages artifact helper 추가
```

## Stage 3. Release Publish DMG workflow를 deploy-pages 경로로 전환

### 목표

official stable release에서 appcast 생성 후 Pages artifact를 업로드하고, 별도 `github-pages` deployment job이 `deploy-pages`로 배포하도록 workflow를 전환한다.

### 작업

- `.github/workflows/release-publish.yml` permissions를 필요한 최소 권한으로 명시한다.
  - release publish job: `contents: write`
  - Pages deploy job: `pages: write`, `id-token: write`
- stable release path에서 `scripts/ci/prepare-pages-artifact.sh`를 실행한다.
- `actions/upload-pages-artifact@v5`로 Pages artifact를 업로드한다.
- 기존 `Publish Sparkle appcast to Pages branch` branch push step을 제거한다.
- `deploy-pages` 별도 job을 추가한다.
  - `needs: publish-dmg`
  - `if: ${{ !inputs.draft && !inputs.prerelease }}`
  - `environment.name: github-pages`
  - `environment.url: ${{ steps.deployment.outputs.page_url }}`
  - `actions/deploy-pages@v5`
- deployment `page_url`과 appcast URL 확인 항목을 `GITHUB_STEP_SUMMARY`에 남긴다.
- draft/prerelease skip path는 stable appcast와 Pages deployment를 모두 건너뛰는 것으로 명확히 한다.

### 예상 변경 파일

- `.github/workflows/release-publish.yml`
- `mydocs/working/task_m018_206_stage3.md`

### 검증

```bash
git status --short --branch
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/release-publish.yml")'
rg -n "upload-pages-artifact@v5|deploy-pages@v5|pages: write|id-token: write|github-pages|prepare-pages-artifact|Publish Sparkle appcast to Pages branch|ALHANGEUL_PAGES_BRANCH" .github/workflows/release-publish.yml
bash -n scripts/ci/*.sh
scripts/ci/classify-pr-changes.sh devel-webview HEAD
git diff --check
```

### 완료 기준

- branch push 기반 appcast publish step이 제거된다.
- stable release path가 Pages artifact upload와 `deploy-pages` deployment job을 가진다.
- draft/prerelease path가 stable appcast와 Pages deployment를 모두 건너뛰는 기준을 유지한다.
- workflow parse와 helper syntax 검증이 통과한다.

### 커밋 메시지

```text
Task #206 Stage 3: release workflow를 deploy-pages 배포로 전환
```

## Stage 4. Release/CI 문서와 #188 handoff 갱신

### 목표

선택한 Pages deployment model, 필요한 repository setting, #188 public release에서 확인할 Pages/appcast 기준을 문서화한다.

### 작업

- `release_github_pages_sparkle_guide.md`의 Pages 배포 모델을 업데이트한다.
  - `build_type=workflow`
  - `github-pages` environment
  - `v*` tag deployment policy
  - `upload-pages-artifact@v5`/`deploy-pages@v5`
  - generated appcast는 branch commit이 아니라 Pages artifact에 포함된다는 기준
- `ci_workflow_guide.md`의 `Release Publish DMG` 산출물/권한/summary 기준을 업데이트한다.
- `release_distribution_guide.md`의 release checklist에서 `docs/appcast.xml` branch 갱신 확인을 Pages deployment URL/public appcast 확인으로 바꾼다.
- `mydocs/release/v0.1.1.md`에 #188 handoff 항목을 추가한다.
  - Pages source가 `workflow`인지 확인
  - `github-pages` environment가 `v*` tag를 허용하는지 확인
  - deploy-pages job의 `page_url` 확인
  - public appcast URL의 stable item/EdDSA signature 확인
- Stage 4 보고서에 문서 entrypoint와 #188 검증 흐름을 기록한다.

### 예상 변경 파일

- `mydocs/manual/release_github_pages_sparkle_guide.md`
- `mydocs/manual/ci_workflow_guide.md`
- `mydocs/manual/release_distribution_guide.md`
- `mydocs/release/v0.1.1.md`
- `mydocs/working/task_m018_206_stage4.md`

### 검증

```bash
git status --short --branch
rg -n "deploy-pages|upload-pages-artifact|github-pages|build_type|workflow|Pages deployment|appcast|#188|#206|v\\*" mydocs/manual mydocs/release/v0.1.1.md
git diff --check
```

### 완료 기준

- release 관련 문서에서 새 Pages deployment model과 precondition을 찾을 수 있다.
- #188 handoff에 Pages/appcast 성공 판단 기준이 연결된다.
- branch push 기반 `docs/appcast.xml` 확인 문구가 남지 않는다.

### 커밋 메시지

```text
Task #206 Stage 4: Pages deploy-pages 운영 기준 문서화
```

## Stage 5. 통합 검증, 최종 보고, PR 준비

### 목표

전체 변경을 검증하고, 실제 repository setting 변경/official release 실행 여부를 분리해 최종 보고서와 PR 본문에 남긴다.

### 작업

- workflow YAML parse를 반복한다.
- shell syntax와 helper dry-run을 반복한다.
- action reference와 legacy branch push reference 검색을 반복한다.
- repository Pages/environment 설정을 다시 확인한다.
- 오늘할일 상태를 완료로 갱신한다.
- 최종 보고서에 다음을 포함한다.
  - 변경 파일 목록과 영향 범위
  - branch publishing 유지 대비 `deploy-pages` 전환 결정 이유
  - 필요한 repository setting 변경 여부와 실행/미실행 상태
  - 실행한 로컬 검증
  - 실제 `Release Publish DMG` official run과 public Pages/appcast 확인은 #188 범위라는 handoff
- `task-final-report` 절차로 PR을 게시한다.

### 예상 변경 파일

- `mydocs/orders/20260510.md`
- `mydocs/report/task_m018_206_report.md`

### 검증

```bash
git status --short --branch
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/pr-ci.yml")'
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/release-publish.yml")'
bash -n scripts/ci/*.sh
scripts/ci/write-sparkle-appcast.sh \
  --version 0.1.1 \
  --build 2 \
  --dmg-url https://github.com/postmelee/alhangeul-macos/releases/download/v0.1.1/alhangeul-macos-0.1.1.dmg \
  --length 1 \
  --ed-signature dummy-ed-signature \
  --release-notes-url https://postmelee.github.io/alhangeul-macos/updates/v0.1.1.html \
  --pub-date "Fri, 08 May 2026 09:00:00 +0000" \
  --minimum-system-version 12.0 \
  --output build.noindex/release/appcast.xml
scripts/ci/prepare-pages-artifact.sh \
  --docs-dir docs \
  --appcast build.noindex/release/appcast.xml \
  --output-dir build.noindex/release/pages-artifact
xmllint --noout build.noindex/release/pages-artifact/appcast.xml
scripts/ci/classify-pr-changes.sh devel-webview HEAD
rg -n "ALHANGEUL_PAGES_BRANCH|Publish Sparkle appcast to Pages branch|deploy-pages@v5|upload-pages-artifact@v5|github-pages|pages: write|id-token: write" .github/workflows mydocs/manual mydocs/release mydocs/report
gh api repos/postmelee/alhangeul-macos/pages
gh api repos/postmelee/alhangeul-macos/environments/github-pages/deployment-branch-policies
git diff --check
```

### 완료 기준

- workflow/helper/documentation 검증이 통과한다.
- legacy branch push 기반 appcast publish reference가 release workflow에서 제거된다.
- repository setting 변경이 실행됐다면 final report에 API 결과를 남기고, 미실행이면 #188 전 승인/실행 항목으로 남긴다.
- PR 생성 전 working tree가 clean이다.

### 커밋 메시지

```text
Task #206 Stage 5 + 최종 보고서: Pages appcast 배포 전환 정리
```
