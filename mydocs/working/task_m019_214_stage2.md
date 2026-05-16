# Task M019 #214 Stage 2 완료 보고서

## 단계 목적

`main` branch의 `docs/**` 변경을 감지해 public appcast를 보존한 Pages artifact를 배포하는 docs-only Pages workflow를 추가한다.

## 산출물

- `.github/workflows/pages-docs-deploy.yml` (133 lines): docs-only Pages deployment workflow
- `mydocs/working/task_m019_214_stage2.md`: Stage 2 완료 보고서

## 변경 내용

신규 `Docs-only Pages Deploy` workflow를 추가했다.

주요 동작:

- trigger
  - `push` to `main`
  - `paths: docs/**`
  - `workflow_dispatch`
- permissions
  - workflow 기본 권한: `contents: read`
  - deploy job 권한: `pages: write`, `id-token: write`
- concurrency
  - group: `pages-deploy`
  - `cancel-in-progress: false`
- safety guard
  - `GITHUB_REF`가 `refs/heads/main`이 아니면 실패한다.
  - 따라서 수동 dispatch를 다른 ref에서 실행해도 public Pages 배포로 진행하지 않는다.
- appcast 보존
  - public `https://postmelee.github.io/alhangeul-macos/appcast.xml`을 다운로드한다.
  - `test -s`와 `xmllint --noout` 검증을 통과한 appcast만 사용한다.
  - stale repository `docs/appcast.xml` fallback은 사용하지 않는다.
- artifact 조립
  - 기존 `scripts/ci/prepare-pages-artifact.sh`를 재사용한다.
  - `docs/` 정적 파일과 preserved public appcast를 Pages artifact로 조립한다.
  - `index.html`, `updates/index.html`, `appcast.xml` 존재를 검증한다.
- deployment
  - `actions/upload-pages-artifact@v5`로 artifact를 업로드한다.
  - `actions/deploy-pages@v5`로 `github-pages` environment에 배포한다.
  - workflow summary에 appcast source, artifact 검증 결과, deployment URL을 남긴다.

## 본문 변경 정도 / 본문 무손실 여부

기존 workflow, script, docs 본문은 변경하지 않았다. 신규 workflow 파일만 추가했다. 기존 `scripts/ci/prepare-pages-artifact.sh` 계약은 그대로 유지했다.

## 검증 결과

실행한 검증:

```bash
git status --short --branch
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/pages-docs-deploy.yml")'
rg -n "Validate deployment ref|refs/heads/main|on:|branches:|paths:|workflow_dispatch|pages-deploy|cancel-in-progress|pages: write|id-token: write|upload-pages-artifact@v5|deploy-pages@v5|prepare-pages-artifact|appcast.xml" .github/workflows/pages-docs-deploy.yml
bash -n scripts/ci/*.sh
scripts/ci/prepare-pages-artifact.sh --help
mkdir -p build.noindex/release
curl -fsSL https://postmelee.github.io/alhangeul-macos/appcast.xml -o build.noindex/release/public-appcast.xml
xmllint --noout build.noindex/release/public-appcast.xml
scripts/ci/prepare-pages-artifact.sh --docs-dir docs --appcast build.noindex/release/public-appcast.xml --output-dir build.noindex/release/pages-artifact
test -f build.noindex/release/pages-artifact/index.html
test -f build.noindex/release/pages-artifact/updates/index.html
xmllint --noout build.noindex/release/pages-artifact/appcast.xml
rg -n "Alhangeul v|sparkle:shortVersionString|releases/download" build.noindex/release/pages-artifact/appcast.xml
git diff --check
```

결과:

- YAML parse 통과. Ruby 실행 시 기존 로컬 gem 경고(`ffi-1.13.1`)가 출력됐지만 exit code는 0이었다.
- shell syntax 검증 통과.
- `prepare-pages-artifact.sh --help` 통과.
- sandbox network 제한으로 최초 `curl`은 DNS 실패했으나, 승인된 escalated 실행에서는 public appcast 다운로드가 성공했다.
- public appcast XML 검증 통과.
- Pages artifact dry-run 성공: `Prepared Pages artifact at /Users/melee/Documents/projects/rhwp-mac/build.noindex/release/pages-artifact`
- artifact root의 `appcast.xml`은 v0.1.2 feed를 유지했다.
- `git diff --check` 통과.

## 잔여 위험

- 실제 `actions/upload-pages-artifact`와 `actions/deploy-pages` 실행은 로컬에서 재현하지 못했다. PR merge 후 GitHub-hosted runner에서 확인해야 한다.
- Stage 2 workflow는 `pages-deploy` concurrency group을 사용하지만, release workflow의 Pages deploy job은 아직 같은 group을 공유하지 않는다. 이 정리는 Stage 3 범위다.
- `workflow_dispatch`는 main 외 ref에서 실행할 수 있으나, workflow 내부 `refs/heads/main` 검증으로 배포 전 실패하도록 했다.

## 다음 단계 영향

Stage 3에서는 다음을 진행한다.

- release-driven Pages deployment와 docs-only Pages deployment의 concurrency 정책을 맞춘다.
- PR CI에서 새 workflow YAML parse를 포함하도록 보강한다.
- `scripts/ci/classify-pr-changes.sh devel HEAD` 기준으로 workflow 변경이 `run_release_checks=true`를 켜는지 확인한다.

## 승인 요청

Stage 2 결과를 승인하면 Stage 3로 진행해 Pages deployment concurrency와 PR CI workflow 검증을 보강한다.
