# Task M018 #206 최종 결과보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | [#206 Pages/appcast 배포 방식을 deploy-pages workflow로 전환 검토](https://github.com/postmelee/alhangeul-macos/issues/206) |
| 마일스톤 | M018 (`v0.1.1`) |
| 브랜치 | `local/task206` |
| 기준 브랜치 | `devel-webview` |
| 단계 수 | 5단계 |

`Release Publish DMG` workflow의 stable appcast 배포 경로를 legacy Pages branch push에서 `docs/` + generated `appcast.xml` Pages artifact와 `actions/deploy-pages@v5` deployment job 구조로 전환했다. 실제 repository Pages setting 변경과 official release run은 #188 전 승인/실행 항목으로 분리했다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `.github/workflows/pr-ci.yml` | release helper checks에 Pages artifact helper interface/dry-run 검증 추가 |
| `.github/workflows/release-publish.yml` | branch push 기반 appcast publish 제거, Pages artifact upload와 `deploy-pages` job 추가, release job/Pages job 권한 분리 |
| `scripts/ci/prepare-pages-artifact.sh` | `docs/` 정적 파일과 generated `appcast.xml`을 `build.noindex` 아래 Pages artifact directory로 조립하는 helper 추가 |
| `mydocs/manual/release_github_pages_sparkle_guide.md` | Pages 배포 모델을 `build_type=workflow`, `github-pages`, `v*` tag policy, `upload-pages-artifact@v5`, `deploy-pages@v5` 기준으로 갱신 |
| `mydocs/manual/ci_workflow_guide.md` | `Release Publish DMG` 권한/job 경계와 Pages artifact helper 재현 명령, Pages deployment summary 기준 반영 |
| `mydocs/manual/release_distribution_guide.md` | release 자산 목록과 최종 체크리스트를 Pages deployment/public appcast 검증 기준으로 갱신 |
| `mydocs/release/v0.1.1.md` | #206 변경점과 #188 Pages/appcast handoff 항목 추가 |
| `mydocs/plans/task_m018_206.md` | 수행계획서 |
| `mydocs/plans/task_m018_206_impl.md` | 구현계획서 |
| `mydocs/working/task_m018_206_stage1.md` | Pages 설정 조사와 전환 결론 보고 |
| `mydocs/working/task_m018_206_stage2.md` | Pages artifact helper와 PR CI 연결 보고 |
| `mydocs/working/task_m018_206_stage3.md` | `release-publish.yml` deploy-pages 전환 보고 |
| `mydocs/working/task_m018_206_stage4.md` | 운영 문서와 #188 handoff 갱신 보고 |
| `mydocs/orders/20260510.md` | #206 상태 완료 처리 |

## 변경 전·후 정량 비교

| 항목 | 결과 |
|------|------|
| 변경 파일 수 | 14개 |
| 총 diff | 1240 insertions, 47 deletions |
| workflow 변경 | `pr-ci.yml` 14 insertions, `release-publish.yml` 59 insertions / 27 deletions |
| 신규 helper | `scripts/ci/prepare-pages-artifact.sh` 134 lines |
| 계획/보고 문서 | 수행계획서, 구현계획서, Stage 1-4 보고서, 최종 보고서 작성 |
| PR 변경 분류 | `run_release_checks=true`, macOS build/render/rust checks는 false |

## 전환 결정 요약

branch publishing 유지보다 `deploy-pages` 전환을 선택한 이유:

- `GITHUB_TOKEN` workflow push가 Pages build를 trigger하지 않을 수 있는 legacy branch publishing 위험을 제거한다.
- appcast 생성, Pages artifact upload, Pages deployment success를 같은 workflow run과 summary에서 확인할 수 있다.
- `deploy-pages` output `page_url`을 #188 public release 검증 기준에 직접 연결할 수 있다.
- generated `appcast.xml`을 source branch commit으로 남기지 않고 release artifact/deployment 기록과 `mydocs/release/v0.1.1.md`로 추적한다.

## Repository setting 상태

현재 GitHub API 확인 결과:

| 항목 | 현재 상태 |
|------|-----------|
| Pages `build_type` | `legacy` |
| Pages source | `main` / `/docs` |
| `github-pages` environment | 존재 |
| deployment policy | custom branch policies 사용 |
| 현재 허용 policy | `devel-webview`, `gh-pages`, `main`, `publish/task135` branch |
| `v*` tag policy | 없음 |

이번 작업에서는 repository setting을 변경하지 않았다. #188 전 또는 PR merge 후 별도 승인으로 다음을 실행해야 한다.

```bash
gh api repos/postmelee/alhangeul-macos/pages --method PUT -f build_type=workflow
gh api repos/postmelee/alhangeul-macos/environments/github-pages/deployment-branch-policies --method POST -f name='v*' -f type=tag
```

## 검증 결과

| 수용 기준 | 결과 | 비고 |
|-----------|------|------|
| `git status --short --branch` | OK | Stage 5 시작 시 clean |
| `ruby -e 'require "psych"; Psych.parse_file(".github/workflows/pr-ci.yml")'` | OK | Ruby `ffi-1.13.1` extension warning은 있었으나 exit code 0 |
| `ruby -e 'require "psych"; Psych.parse_file(".github/workflows/release-publish.yml")'` | OK | Ruby `ffi-1.13.1` extension warning은 있었으나 exit code 0 |
| `bash -n scripts/ci/*.sh` | OK | 출력 없음 |
| `scripts/ci/write-sparkle-appcast.sh ...` | OK | dummy EdDSA signature로 appcast XML 생성 |
| `scripts/ci/prepare-pages-artifact.sh ...` | OK | `build.noindex/release/pages-artifact` 생성 |
| `xmllint --noout build.noindex/release/pages-artifact/appcast.xml` | OK | 출력 없음 |
| `.DS_Store` 제외 확인 | OK | artifact 아래 `.DS_Store` 없음 |
| `scripts/ci/classify-pr-changes.sh devel-webview HEAD` | OK | `run_release_checks=true` |
| legacy workflow ref 검색 | OK | `.github/workflows`, `mydocs/manual`, `mydocs/release`에 `ALHANGEUL_PAGES_BRANCH` / `Publish Sparkle appcast to Pages branch` 없음 |
| Stage 5 전체 reference 검색 | OK | 새 `deploy-pages@v5`, `upload-pages-artifact@v5`, `github-pages`, `pages: write`, `id-token: write` 기준 확인. 과거 `mydocs/report`의 이전 작업 기록에는 옛 기준이 남아 있으나 역사 기록이라 수정하지 않음 |
| GitHub Pages API 확인 | OK | 현재는 아직 `legacy` / `main` `/docs` |
| `github-pages` environment policy 확인 | OK | `v*` tag policy 없음. #188 전 승인/실행 항목 |
| `git diff --check` | OK | 출력 없음 |

## 잔여 위험과 후속 작업

- Pages source가 아직 `legacy`이므로 실제 `deploy-pages` success 전에는 repository Pages setting을 `workflow`로 전환해야 한다.
- `github-pages` environment에 `v*` tag policy가 없으므로 release tag ref에서 실행되는 deploy job은 policy에 막힐 수 있다.
- `actions/upload-pages-artifact@v5`와 `actions/deploy-pages@v5`의 실제 연동은 GitHub Actions official release run에서 최종 확인해야 한다.
- Sparkle private key, signed/notarized public DMG, public appcast URL 반영은 #188 범위다.
- #188 final release smoke에서 `deploy-pages` `page_url`, public `appcast.xml` stable item, EdDSA signature, release notes URL을 확인해야 한다.

## 작업지시자 승인 요청

PR 리뷰와 merge 승인을 요청한다. PR merge 후 #188 전에 repository Pages source `workflow` 전환과 `github-pages` environment `v*` tag policy 추가 승인/실행이 필요하다.
