# Task M018 #206 Stage 1 완료 보고서

## 단계 목적

GitHub Pages/appcast 배포 모델 전환 여부를 확정하기 위해 현재 repository Pages 설정, `github-pages` environment 정책, official Pages Actions 기준을 확인했다. 이 단계는 분석과 승인 항목 분리 단계이며, workflow 파일과 repository 설정은 아직 변경하지 않았다.

## 현재 Pages 설정

GitHub Pages API 확인 결과, 현재 사이트는 legacy branch publishing 방식이다.

| 항목 | 값 |
|------|----|
| `html_url` | `https://postmelee.github.io/alhangeul-macos/` |
| `status` | `built` |
| `build_type` | `legacy` |
| `source.branch` | `main` |
| `source.path` | `/docs` |
| `https_enforced` | `true` |

현재 `Release Publish DMG` workflow는 stable release에서 generated appcast를 만든 뒤 별도 worktree로 Pages source branch를 clone하고 `docs/appcast.xml`만 commit/push한다. 이 구조는 `GITHUB_TOKEN` workflow push가 Pages build를 trigger하지 않을 수 있다는 GitHub Pages branch publishing 제약과 충돌한다.

## 현재 `github-pages` environment 설정

`github-pages` environment는 이미 존재한다.

| 항목 | 값 |
|------|----|
| environment name | `github-pages` |
| created_at | `2026-05-08T08:17:07Z` |
| protection rule | `branch_policy` |
| `deployment_branch_policy.protected_branches` | `false` |
| `deployment_branch_policy.custom_branch_policies` | `true` |
| `can_admins_bypass` | `true` |

현재 허용된 deployment branch policy:

| name | type |
|------|------|
| `devel-webview` | `branch` |
| `gh-pages` | `branch` |
| `main` | `branch` |
| `publish/task135` | `branch` |

`Release Publish DMG` workflow는 tag `v<version>`에서 실행되므로 `deploy-pages` job이 `github-pages` environment를 사용하려면 tag policy `v*` 추가가 필요하다. GitHub environment policy는 workflow run의 `GITHUB_REF`와 매칭되며, branch와 tag rule은 별도로 설정해야 한다.

## official action 기준

| action | 확인된 latest | publishedAt | URL |
|--------|---------------|-------------|-----|
| `actions/deploy-pages` | `v5.0.0` | `2026-03-25T16:59:14Z` | `https://github.com/actions/deploy-pages/releases/tag/v5.0.0` |
| `actions/upload-pages-artifact` | `v5.0.0` | `2026-04-10T18:22:59Z` | `https://github.com/actions/upload-pages-artifact/releases/tag/v5.0.0` |

GitHub Pages 공식 문서 기준:

- branch publishing은 특정 branch/folder를 source로 삼지만, `GITHUB_TOKEN`을 쓰는 workflow push가 Pages build를 trigger하지 않을 수 있다.
- custom GitHub Actions publishing은 정적 파일 artifact를 업로드한 뒤 Pages deployment action으로 배포하는 방식이다.
- `deploy-pages` deployment job에는 최소 `pages: write`, `id-token: write` 권한이 필요하다.
- `github-pages` environment 사용이 권장되며, deployment output으로 `page_url`을 받을 수 있다.
- Pages API는 `build_type`을 `legacy` 또는 `workflow`로 설정할 수 있고, `workflow` 전환에는 Pages write와 Administration write 권한이 필요하다.

참고한 공식 URL:

- https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site
- https://docs.github.com/en/rest/pages/pages
- https://docs.github.com/en/actions/reference/deployments-and-environments
- https://github.com/actions/deploy-pages/releases/tag/v5.0.0
- https://github.com/actions/upload-pages-artifact/releases/tag/v5.0.0

## 전환 결론

Pages/appcast 배포 모델은 `deploy-pages` 기반 GitHub Actions deployment로 전환하는 것이 타당하다.

이유:

- appcast 생성 성공, Pages artifact upload, Pages deployment 성공을 같은 workflow run과 summary에서 확인할 수 있다.
- `GITHUB_TOKEN` branch push가 Pages build를 trigger하지 않을 수 있는 legacy branch publishing 위험을 제거한다.
- `deploy-pages` output `page_url`과 public appcast URL 확인을 #188 public release 검증 기준으로 직접 연결할 수 있다.
- generated `appcast.xml`을 source branch에 commit하지 않고 release workflow 산출물과 Pages deployment 기록으로 관리할 수 있다.

## 별도 승인 필요 항목

다음 repository 설정 변경은 코드 변경과 별개로 작업지시자 승인 후 실행해야 한다.

1. GitHub Pages source 전환
   - 현재: `build_type=legacy`, `source=main /docs`
   - 필요: `build_type=workflow`
   - API 예시: `gh api repos/postmelee/alhangeul-macos/pages --method PUT -f build_type=workflow`
2. `github-pages` environment tag policy 추가
   - 현재: branch policy만 존재
   - 필요: tag policy `v*`
   - API 예시: `gh api repos/postmelee/alhangeul-macos/environments/github-pages/deployment-branch-policies --method POST -f name='v*' -f type=tag`

이번 단계에서는 위 설정 변경을 실행하지 않았다.

## 검증 결과

```bash
git status --short --branch
```

결과: `## local/task206`

```bash
gh api repos/postmelee/alhangeul-macos/pages
```

결과 요약: `build_type=legacy`, `source.branch=main`, `source.path=/docs`, `status=built`.

```bash
gh api repos/postmelee/alhangeul-macos/environments/github-pages
```

결과 요약: `github-pages` environment 존재, custom branch policies 활성화.

```bash
gh api repos/postmelee/alhangeul-macos/environments/github-pages/deployment-branch-policies
```

결과 요약: `devel-webview`, `gh-pages`, `main`, `publish/task135` branch policy 4개 존재. `v*` tag policy 없음.

```bash
gh release view -R actions/deploy-pages --json tagName,publishedAt,url
```

결과: `v5.0.0`, published `2026-03-25T16:59:14Z`.

```bash
gh release view -R actions/upload-pages-artifact --json tagName,publishedAt,url
```

결과: `v5.0.0`, published `2026-04-10T18:22:59Z`.

```bash
git diff --check
```

결과: 출력 없음, exit code 0.

## 산출물

- `mydocs/working/task_m018_206_stage1.md`: Stage 1 분석과 전환 결론 기록

본문 변경 정도 / 본문 무손실 여부: 해당 없음. 이번 단계는 신규 보고서 작성만 수행했다.

## 잔여 위험

- Pages source가 아직 `legacy`이므로 Stage 3 workflow가 병합되더라도 repository setting 전환 전에는 실제 Pages deployment가 성공하지 않을 수 있다.
- `github-pages` environment에 `v*` tag policy가 없으므로 release tag ref에서 실행되는 deploy job은 environment policy에 막힐 수 있다.
- `docs/appcast.xml`을 branch commit으로 남기지 않는 구조로 바뀌므로, appcast 장기 추적 기준은 release artifact/deployment 기록과 `mydocs/release/v0.1.1.md`로 옮겨야 한다.
- 실제 official release, Sparkle private key, Pages deployment, public appcast URL 반영은 #188에서 최종 확인해야 한다.

## 다음 단계 영향

Stage 2에서는 `scripts/ci/prepare-pages-artifact.sh`를 추가하고 PR CI release helper checks에 dry-run을 연결한다. 이 작업은 repository Pages source 전환 없이 로컬/PR CI에서 검증 가능하다.

Stage 3 전에 repository 설정 변경을 실행할지, PR 병합 후 #188 직전에 실행할지 결정해야 한다. 설정 변경은 별도 승인이 필요하다.

## 승인 요청

Stage 1 산출물 승인을 요청한다.

승인 후 Stage 2 `Pages artifact helper와 PR CI 검증 연결`로 진행한다.
