# Task M019 #214 최종 결과보고서

## 작업 요약

- 이슈: [#214 Pages workflow 전환 후 docs-only 즉시 배포와 appcast 보존 workflow 추가](https://github.com/postmelee/alhangeul-macos/issues/214)
- 마일스톤: M019 (`v0.1.2`)
- 브랜치: `local/task214`
- 기준 브랜치: `devel`
- 단계 수: 5단계

`main`의 `docs/**` 변경을 public GitHub Pages에 즉시 배포하는 docs-only workflow를 추가했다. docs-only 배포는 public `appcast.xml`을 다운로드해 XML 검증 후 Pages artifact에 주입하며, stale repository `docs/appcast.xml` fallback은 사용하지 않는다. release workflow와 docs-only workflow는 `pages-deploy` concurrency group을 공유한다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `.github/workflows/pages-docs-deploy.yml` | `main`의 `docs/**` 변경과 수동 실행을 처리하는 docs-only Pages deploy workflow 추가 |
| `.github/workflows/pr-ci.yml` | PR CI에서 `.github/workflows/*.yml` YAML parse 검증 추가 |
| `.github/workflows/release-publish.yml` | release `deploy-pages` job에 `pages-deploy` concurrency 추가 |
| `mydocs/manual/ci_workflow_guide.md` | docs-only workflow 역할, 권한, 재현 명령, 실패 해석 기준 문서화 |
| `mydocs/manual/release_github_pages_sparkle_guide.md` | release/docs-only Pages 배포 역할 분리와 appcast 보존 기준 문서화 |
| `mydocs/manual/release_distribution_guide.md` | release 자산과 체크리스트에 docs-only workflow와 Pages concurrency 기준 추가 |
| `mydocs/orders/20260517.md` | #214 오늘할일 완료 처리 |
| `mydocs/plans/task_m019_214.md` | 수행계획서 작성 |
| `mydocs/plans/task_m019_214_impl.md` | 구현계획서 작성 |
| `mydocs/working/task_m019_214_stage1.md` | appcast 보존 정책과 현황 확인 보고 |
| `mydocs/working/task_m019_214_stage2.md` | docs-only workflow 추가 보고 |
| `mydocs/working/task_m019_214_stage3.md` | Pages concurrency와 PR CI 보강 보고 |
| `mydocs/working/task_m019_214_stage4.md` | 운영 매뉴얼 갱신 보고 |
| `mydocs/working/task_m019_214_stage5.md` | 통합 검증 보고 |
| `mydocs/report/task_m019_214_report.md` | 최종 결과보고서 |

## 변경 전·후 정량 비교

| 항목 | 결과 |
|------|------|
| Stage 5 진입 전 변경량 | 13 files, 1082 insertions, 3 deletions |
| 신규 workflow | 1개 (`pages-docs-deploy.yml`) |
| workflow parse 대상 | `.github/workflows/*.yml` 전체 |
| 단계 보고서 | 5개 |
| 계획/최종 보고 문서 | 수행계획서 1개, 구현계획서 1개, 최종 결과보고서 1개 |
| 변경 범위 분류 | `run_release_checks=true`, macOS/Rust/render 검증 false |

## 단계별 결과

- Stage 1: release-driven Pages 구조와 public/repository appcast 차이를 확인하고, public appcast 보존과 stale fallback 금지 정책을 확정했다.
- Stage 2: `Docs-only Pages Deploy` workflow를 추가하고 public appcast 보존 dry-run을 검증했다.
- Stage 3: release/docs-only Pages deployment가 `pages-deploy` concurrency group을 공유하게 하고 PR CI workflow YAML parse를 추가했다.
- Stage 4: CI/Release/Pages 매뉴얼에 docs-only workflow 운영 기준을 문서화했다.
- Stage 5: 전체 workflow parse, shell syntax, generated/public appcast artifact dry-run, 변경 범위 분류를 재검증했다.

## 검증 결과

| 수용 기준 | 결과 |
|-----------|------|
| `main`의 `docs/**` 변경으로 docs-only Pages workflow 실행 경로 존재 | OK: `pages-docs-deploy.yml` trigger 추가 |
| docs-only 배포가 stale `docs/appcast.xml`을 사용하지 않음 | OK: public appcast 다운로드/검증 후 helper에 전달, fallback disabled |
| Pages artifact 필수 파일 검증 | OK: `index.html`, `updates/index.html`, `appcast.xml` dry-run 검증 |
| `appcast.xml` XML 검증 | OK: generated/public/docs-only artifact 모두 `xmllint --noout` 통과 |
| release/docs-only Pages concurrency 문서화와 workflow 반영 | OK: `pages-deploy`, `cancel-in-progress=false` |
| PR CI release checks 연결 | OK: workflow 변경으로 `run_release_checks=true`, YAML parse 추가 |
| 운영 매뉴얼 갱신 | OK: CI, Pages/Sparkle, Release entrypoint 갱신 |

주요 실행 명령:

```bash
ruby -e 'require "psych"; Dir[".github/workflows/*.yml"].sort.each { |path| Psych.parse_file(path); puts "Parsed #{path}" }'
bash -n scripts/ci/*.sh
scripts/ci/prepare-pages-artifact.sh --help
scripts/ci/write-sparkle-appcast.sh --version 0.1.2 --build 8 --dmg-url https://github.com/postmelee/alhangeul-macos/releases/download/v0.1.2/alhangeul-macos-0.1.2.dmg --length 1 --ed-signature dummy-ed-signature --release-notes-url https://postmelee.github.io/alhangeul-macos/updates/v0.1.2.html --pub-date "Fri, 08 May 2026 09:00:00 +0000" --minimum-system-version 12.0 --output build.noindex/release/appcast.xml
xmllint --noout build.noindex/release/appcast.xml
scripts/ci/prepare-pages-artifact.sh --docs-dir docs --appcast build.noindex/release/public-appcast.xml --output-dir build.noindex/release/docs-only-pages-artifact
xmllint --noout build.noindex/release/docs-only-pages-artifact/appcast.xml
scripts/ci/classify-pr-changes.sh devel HEAD
git diff --check
```

## 잔여 위험과 후속 작업

- 실제 `actions/upload-pages-artifact@v5`와 `actions/deploy-pages@v5` deployment는 로컬에서 재현하지 못했다. PR merge 후 GitHub-hosted runner에서 확인해야 한다.
- GitHub Actions job-level concurrency의 실제 queueing 동작은 workflow 실행으로 확인해야 한다.
- `github-pages` environment에 남아 있는 legacy branch policy(`devel-webview`, `gh-pages`, `publish/task135`) 정리는 이번 범위에서 제외했다.

## PR 후 확인 항목

- PR CI에서 workflow YAML parse와 release checks가 성공하는지 확인한다.
- merge 후 `main`의 `docs/**` 변경 또는 수동 dispatch에서 `Docs-only Pages Deploy`가 실행되는지 확인한다.
- workflow summary에 public appcast source, artifact 검증, deployment URL이 남는지 확인한다.
- public `https://postmelee.github.io/alhangeul-macos/appcast.xml`이 기존 stable v0.1.2 feed를 유지하는지 확인한다.

## 작업지시자 승인 요청

최종 결과보고서를 승인하면 `publish/task214` 원격 브랜치 push와 `devel` 대상 Open PR 생성 절차로 진행한다.
