# Task M019 #214 Stage 1 완료 보고서

## 단계 목적

docs-only Pages 배포를 구현하기 전에 #206 이후의 release-driven Pages 배포 구조, repository/public appcast 상태, GitHub Pages environment 전제 조건을 확인하고 Stage 2 구현 정책을 고정한다.

## 산출물

- `mydocs/working/task_m019_214_stage1.md`: Stage 1 확인 결과와 구현 정책 기록

이번 단계는 조사와 보고 단계이므로 workflow, script, manual 본문은 변경하지 않았다.

## 확인 결과

현재 release-driven Pages 배포 구조:

- `.github/workflows/release-publish.yml`은 stable release path에서 `scripts/ci/prepare-pages-artifact.sh`를 실행한다.
- release workflow는 generated `appcast.xml`을 `docs/` 정적 파일 위에 overlay한 뒤 `actions/upload-pages-artifact@v5`와 `actions/deploy-pages@v5`로 배포한다.
- `deploy-pages` job은 `environment: github-pages`, `pages: write`, `id-token: write` 권한을 사용한다.
- `scripts/ci/prepare-pages-artifact.sh`는 입력받은 appcast 파일을 artifact root의 `appcast.xml`로 복사한다. 따라서 docs-only 경로에서도 이 helper를 재사용할 수 있다.

GitHub Pages와 environment 상태:

- `gh api repos/postmelee/alhangeul-macos/pages`
  - `build_type=workflow`
  - `source.branch=main`
  - `source.path=/docs`
  - `html_url=https://postmelee.github.io/alhangeul-macos/`
- `github-pages` environment는 custom branch/tag policy를 사용한다.
- deployment policy 목록에는 `main` branch와 `v*` tag가 모두 포함되어 있다.
- 따라서 docs-only workflow의 `main` branch deployment와 release workflow의 `v*` tag deployment 전제 조건은 현재 충족되어 있다.

appcast 상태:

- repository의 `docs/appcast.xml`은 `Alhangeul v0.1.0`, `sparkle:shortVersionString=0.1.0`, `v0.1.0` DMG URL을 포함한다.
- public `https://postmelee.github.io/alhangeul-macos/appcast.xml`은 `Alhangeul v0.1.2`, `sparkle:shortVersionString=0.1.2`, `v0.1.2` DMG URL을 포함한다.
- 두 파일 크기는 우연히 모두 1159 bytes였지만 feed item 내용은 다르다.
- 따라서 docs-only workflow가 repository의 `docs/appcast.xml`을 그대로 artifact에 넣으면 public stable Sparkle feed를 v0.1.0으로 되돌릴 수 있다.

## 확정 정책

- docs-only workflow는 release workflow와 분리한다.
- trigger는 Stage 2에서 `push` to `main` + `paths: docs/**`와 `workflow_dispatch`로 구성한다.
- docs-only workflow는 Sparkle appcast를 생성하지 않는다.
- docs-only workflow는 public appcast URL을 다운로드해 `test -s`와 `xmllint --noout` 검증을 통과한 파일만 `prepare-pages-artifact.sh`에 넘긴다.
- public appcast 다운로드 또는 XML 검증이 실패하면 Pages deployment를 중단한다.
- stale repository `docs/appcast.xml` fallback은 허용하지 않는다.
- Pages artifact 조립은 기존 `scripts/ci/prepare-pages-artifact.sh`를 재사용한다.
- Stage 2 workflow는 public appcast source URL, artifact directory, deployment URL을 `GITHUB_STEP_SUMMARY`에 남긴다.

## 본문 변경 정도 / 본문 무손실 여부

기존 문서와 소스 본문은 변경하지 않았다. Stage 1 보고서만 신규 추가했다.

## 검증 결과

실행한 확인 명령:

```bash
git status --short --branch
rg -n "upload-pages-artifact|deploy-pages|prepare-pages-artifact|github-pages|appcast.xml|concurrency" .github/workflows scripts/ci mydocs/manual
sed -n '1,160p' docs/appcast.xml
gh api repos/postmelee/alhangeul-macos/pages
gh api repos/postmelee/alhangeul-macos/environments/github-pages
gh api repos/postmelee/alhangeul-macos/environments/github-pages/deployment-branch-policies
curl -fsSL https://postmelee.github.io/alhangeul-macos/appcast.xml -o build.noindex/release/public-appcast.xml
xmllint --noout build.noindex/release/public-appcast.xml
rg -n "Alhangeul v|sparkle:shortVersionString|releases/download" build.noindex/release/public-appcast.xml docs/appcast.xml
```

결과:

- `git status --short --branch`: `## local/task214`
- GitHub API 조회는 sandbox network 제한으로 처음 실패했으나, 승인된 escalated 실행에서는 성공했다.
- public appcast 다운로드 성공.
- `xmllint --noout build.noindex/release/public-appcast.xml` 통과.
- repository appcast와 public appcast의 version 차이를 확인했다.

## 잔여 위험

- public appcast 다운로드가 일시적으로 실패하면 docs-only Pages 배포도 실패한다. 문서 반영 지연보다 Sparkle stable feed 손상 방지가 우선이므로 의도된 실패 정책으로 둔다.
- `github-pages` environment에 legacy policy인 `devel-webview`, `gh-pages`, `publish/task135`가 남아 있지만, 이번 작업의 필수 전제인 `main`과 `v*`는 이미 존재한다. legacy policy 정리는 별도 운영 작업으로 분리하는 편이 안전하다.
- 실제 `actions/deploy-pages` 실행은 로컬에서 재현하지 못하므로 Stage 2 이후 PR/merge 후 GitHub-hosted runner에서 확인해야 한다.

## 다음 단계 영향

Stage 2에서는 신규 `.github/workflows/pages-docs-deploy.yml`을 추가한다. 구현 방향은 다음으로 고정한다.

- public appcast 다운로드 파일 경로: `build.noindex/release/public-appcast.xml`
- Pages artifact output: `build.noindex/release/pages-artifact`
- appcast 검증: `test -s` + `xmllint --noout`
- artifact 조립: 기존 `scripts/ci/prepare-pages-artifact.sh`
- stale `docs/appcast.xml` fallback 금지

## 승인 요청

Stage 1 결과와 정책 고정을 승인하면 Stage 2로 진행해 docs-only Pages deploy workflow를 추가한다.
