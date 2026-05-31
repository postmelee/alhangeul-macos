# Task M013 #274 최종 보고서

## 작업 요약

- 이슈: [#274 Issue Template 변경을 docs-only로 분류하도록 PR CI classifier 보정](https://github.com/postmelee/alhangeul-macos/issues/274)
- 마일스톤: M013 (`하이퍼-워터폴 작업환경 조성`)
- 기준 브랜치: `devel`
- 작업 브랜치: `local/task274`
- 단계 수: 4단계

PR #273에서 `.github/ISSUE_TEMPLATE/*`와 `mydocs/*`만 변경했는데도 `macOS validation`이 실행된 원인을 classifier 기준에서 재현하고, Issue Template 경로만 repository metadata로 분류하도록 보정했다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `.github/workflows/pr-ci.yml` | `script-checks`에 Issue Template YAML parse step 추가 |
| `scripts/ci/classify-pr-changes.sh` | `is_docs_path()`에 `.github/ISSUE_TEMPLATE/*` 추가 |
| `mydocs/plans/task_m013_274.md` | 수행계획서 작성 |
| `mydocs/plans/task_m013_274_impl.md` | 구현계획서 작성 |
| `mydocs/working/task_m013_274_stage1.md` | #273 classifier 오동작 재현과 보정 설계 기록 |
| `mydocs/working/task_m013_274_stage2.md` | classifier와 PR CI YAML 검증 보정 기록 |
| `mydocs/working/task_m013_274_stage3.md` | classifier case 검증 결과 기록 |
| `mydocs/report/task_m013_274_report.md` | 최종 결과보고서 작성 |
| `mydocs/orders/20260519.md` | #274 작업 상태 갱신 |

제품 Swift/Rust 코드, RustBridge, renderer, Xcode project, release workflow, branch protection, #273 Issue Template 본문은 변경하지 않았다.

## 변경 전·후 정량 비교

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| #273 Issue Template-only 범위 `docs_only` | `false` | `true` |
| #273 Issue Template-only 범위 `run_macos_build` | `true` | `false` |
| #273 Issue Template-only 범위 `run_release_checks` | `false` | `false` |
| 현재 #274 범위 `run_macos_build` | 해당 없음 | `false` |
| 현재 #274 범위 `run_release_checks` | 해당 없음 | `true` |
| 변경 규모 | 해당 없음 | 9 files, 795 insertions, 1 deletion |

`run_release_checks=true`는 #274가 `.github/workflows/pr-ci.yml`과 `scripts/ci/classify-pr-changes.sh`를 변경하기 때문에 의도된 결과다. 이 변경은 macOS build 입력을 바꾸지 않으므로 `run_macos_build=false`가 기대값이다.

## 단계별 결과

| 단계 | 결과 |
|------|------|
| Stage 1 | PR #273 범위에서 `.github/ISSUE_TEMPLATE/*`가 unclassified non-docs change로 처리되어 `run_macos_build=true`가 되는 원인을 재현 |
| Stage 2 | `.github/ISSUE_TEMPLATE/*`를 docs path로 추가하고, Issue Template YAML parse step을 PR CI script checks에 추가 |
| Stage 3 | Issue Template/doc-only, CI workflow/script, HostApp source case에서 classifier flag가 기대대로 유지되는지 검증 |
| Stage 4 | 전체 수용 기준을 다시 실행하고 최종 보고서와 오늘할일 완료 처리를 수행 |

## 검증 결과

| 수용 기준 | 결과 | 비고 |
|-----------|------|------|
| `bash -n scripts/ci/classify-pr-changes.sh` | OK | shell syntax 통과 |
| `bash scripts/ci/classify-pr-changes.sh --help` | OK | usage 출력 확인 |
| `ruby -e 'require "psych"; Psych.parse_file(".github/workflows/pr-ci.yml"); puts "workflow-ok"'` | OK | workflow YAML parse 통과 |
| `ruby -e 'require "psych"; Dir[".github/ISSUE_TEMPLATE/*.yml"].sort.each { \|path\| Psych.parse_file(path); puts "Parsed #{path}" }'` | OK | Issue Template YAML 8개 parse 통과 |
| `bash scripts/ci/classify-pr-changes.sh 6a3cd6c^ 6a3cd6c` | OK | Issue Template/doc-only: `docs_only=true`, `run_macos_build=false`, `run_release_checks=false` |
| `bash scripts/ci/classify-pr-changes.sh 7b77a71^ 7b77a71` | OK | workflow/script: `run_release_checks=true`, `run_macos_build=false` |
| `bash scripts/ci/classify-pr-changes.sh 8d4184b^ 8d4184b` | OK | HostApp source: `run_macos_build=true` |
| `bash scripts/ci/classify-pr-changes.sh devel HEAD` | OK | 현재 #274 범위: `run_release_checks=true`, `run_macos_build=false` |
| `git diff --check` | OK | whitespace error 없음 |
| `git status --short --branch` | OK | Stage 4 수정 전 clean 확인 |

로컬 Ruby 실행 시 `Ignoring ffi-1.13.1 because its extensions are not built` 경고가 출력되었지만, Psych parse 명령은 정상 완료했다.

## 잔여 위험과 후속 작업

| 항목 | 내용 |
|------|------|
| GitHub settings | branch protection 또는 required check 설정은 이번 작업 범위가 아니므로 변경하지 않았다. |
| GitHub Issue Template semantics | 이번 검증은 YAML syntax parse까지이며, GitHub Issue Forms schema 수준의 원격 검증은 PR CI 실행 결과에서 추가 확인한다. |
| `.github/*` 분류 범위 | `.github/ISSUE_TEMPLATE/*`만 docs path로 열었고, `.github/workflows/*`는 계속 release/script automation으로 분류된다. |

현재 기준으로 분리할 후속 이슈는 없다.

## 작업지시자 승인 요청

최종 보고서 작성과 오늘할일 완료 처리를 마쳤다. PR 게시 후 CI 결과와 리뷰를 확인하고 merge 여부를 승인받는다.
