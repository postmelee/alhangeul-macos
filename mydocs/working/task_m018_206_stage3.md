# Task M018 #206 Stage 3 완료 보고서

## 단계 목적

`Release Publish DMG` workflow의 official stable release 경로를 branch push 기반 `docs/appcast.xml` 갱신에서 Pages artifact upload + `deploy-pages` deployment job 구조로 전환했다.

## 산출물

| 파일 | 라인 수 | 요약 |
|------|---------|------|
| `.github/workflows/release-publish.yml` | 535 | stable appcast 생성 후 Pages artifact를 업로드하고 별도 `deploy-pages` job으로 배포하도록 전환 |

주요 변경:

- top-level workflow permission을 `contents: read`로 낮췄다.
- `publish-dmg` job에 `contents: write`를 명시해 GitHub Release asset publish 권한을 유지했다.
- `ALHANGEUL_PAGES_BRANCH` env와 Pages branch clone/push step을 제거했다.
- stable release path에서 `scripts/ci/prepare-pages-artifact.sh`를 실행해 `docs/`와 generated `appcast.xml`을 Pages artifact directory로 조립한다.
- `actions/upload-pages-artifact@v5`로 Pages artifact를 업로드한다.
- `deploy-pages` job을 추가해 `actions/deploy-pages@v5`로 Pages deployment를 수행한다.
- `deploy-pages` job 권한은 `pages: write`, `id-token: write`로 분리했다.
- `deploy-pages` job은 `github-pages` environment를 사용하고 `steps.deployment.outputs.page_url`을 environment URL과 summary에 남긴다.
- draft/prerelease 실행에서는 stable appcast와 Pages deployment를 모두 skip한다고 summary에 명시한다.

## 본문 변경 정도 / 본문 무손실 여부

사용자-facing Pages HTML, release notes 본문, appcast XML schema는 수정하지 않았다. 변경은 release workflow orchestration에 한정된다.

## 검증 결과

```bash
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/release-publish.yml")'
```

결과: YAML parse 통과. 로컬 Ruby 환경에서 `ffi-1.13.1` extension 관련 warning이 출력됐지만 parse exit code는 0이었다.

```bash
rg -n "upload-pages-artifact@v5|deploy-pages@v5|pages: write|id-token: write|github-pages|prepare-pages-artifact|Publish Sparkle appcast to Pages branch|ALHANGEUL_PAGES_BRANCH" .github/workflows/release-publish.yml
```

결과 요약:

- `scripts/ci/prepare-pages-artifact.sh` 존재
- `actions/upload-pages-artifact@v5` 존재
- `pages: write`, `id-token: write` 존재
- `github-pages` environment 존재
- `actions/deploy-pages@v5` 존재
- 기존 `Publish Sparkle appcast to Pages branch`, `ALHANGEUL_PAGES_BRANCH`는 출력 없음

```bash
bash -n scripts/ci/*.sh
```

결과: 출력 없음, exit code 0.

```bash
scripts/ci/classify-pr-changes.sh devel-webview 27b4746bff2544955a9eadcf86ed5a406d5ccc56
```

`HEAD`는 아직 Stage 3 커밋 전이라 미커밋 workflow 변경을 보지 못한다. 따라서 staged 변경을 포함한 임시 commit object `27b4746bff2544955a9eadcf86ed5a406d5ccc56`를 만들어 PR 변경 분류를 검증했다.

결과 요약:

| Flag | Value |
|------|-------|
| `docs_only` | `false` |
| `run_macos_build` | `false` |
| `run_rust_verify` | `false` |
| `run_render_smoke` | `false` |
| `run_release_checks` | `true` |

`run_release_checks=true` 이유:

- `.github/workflows/pr-ci.yml` affects release scripts, workflows, or Cask automation
- `.github/workflows/release-publish.yml` affects release scripts, workflows, or Cask automation
- `scripts/ci/prepare-pages-artifact.sh` affects release scripts, workflows, or Cask automation

```bash
git diff --check
git diff --check --cached
```

결과: 출력 없음, exit code 0.

## 잔여 위험

- repository Pages source는 아직 `build_type=legacy`다. 실제 `deploy-pages` 성공 전에는 Pages source를 `workflow`로 전환해야 한다.
- `github-pages` environment에는 아직 `v*` tag policy가 없다. release workflow가 tag ref에서 실행되므로, tag policy 추가 전에는 deploy job이 environment policy에 막힐 수 있다.
- `actions/upload-pages-artifact@v5`와 `actions/deploy-pages@v5`의 실제 연동은 GitHub Actions run에서 최종 확인해야 한다.
- official release execution, Sparkle private key, signed/notarized DMG, public appcast URL 반영은 #188에서 확인해야 한다.

## 다음 단계 영향

Stage 4에서는 release/CI 문서와 `mydocs/release/v0.1.1.md`의 #188 handoff를 업데이트한다. 특히 다음 기준을 문서화해야 한다.

- Pages source `workflow` precondition
- `github-pages` environment `v*` tag policy precondition
- `deploy-pages` job `page_url` 확인
- public `appcast.xml` stable item과 Sparkle EdDSA signature 확인

## 승인 요청

Stage 3 산출물 승인을 요청한다.

승인 후 Stage 4 `Release/CI 문서와 #188 handoff 갱신`으로 진행한다.
