# Task M013 #244 Stage 4 보고서

## 단계 목적

Stage 3에서 정렬한 브랜치 정책을 GitHub PR 표면과 CI workflow branch filter에 반영했다.

이번 단계는 `.github` 자동화와 CI 운영 문서 정합화만 수행했고, 원격 브랜치 생성, 원격 브랜치 삭제, `devel` 교체, branch protection/default branch 설정 변경은 수행하지 않았다.

## 반영한 기준

| 항목 | Stage 4 기준 |
|------|--------------|
| 제품/배포/문서 PR base | `devel` |
| Swift native viewer/editor PR base | `native-viewer-editor` |
| `devel-webview` | 전환 기간 legacy alias로 PR CI trigger에만 유지 |
| release publish | `main` tag 기준 유지 |
| release rehearsal | 수동 `workflow_dispatch` 유지 |
| upstream check | 수동/스케줄 `workflow_dispatch`/`schedule` 유지 |

## 변경 내용

| 파일 | 변경 |
|------|------|
| `.github/pull_request_template.md` | PR 작성자가 base 선택 기준을 확인할 수 있도록 `PR base` 섹션 추가 |
| `.github/workflows/pr-ci.yml` | `pull_request.branches`에 `native-viewer-editor` 추가, `devel`을 제품 기본 대상으로 앞에 배치, `devel-webview`는 legacy alias로 유지 |
| `mydocs/manual/ci_workflow_guide.md` | PR CI 대상 브랜치 기준과 `devel-webview` legacy trigger 유지 사유 추가 |

## 점검 결과

| workflow | 판단 |
|----------|------|
| `.github/workflows/pr-ci.yml` | branch filter가 있어 수정함 |
| `.github/workflows/release-publish.yml` | `workflow_dispatch` + tag 검증 기준이며 branch filter가 없어 변경하지 않음 |
| `.github/workflows/release-rehearsal.yml` | 수동 rehearsal workflow이며 branch filter가 없어 변경하지 않음 |
| `.github/workflows/rhwp-upstream-check.yml` | 수동/스케줄 upstream release 점검이며 branch filter가 없어 변경하지 않음 |

## 검증 결과

| 검증 | 결과 |
|------|------|
| `git diff --check` | 통과 |
| `ruby -e 'ARGV.each { \|path\| require "psych"; Psych.parse_file(path); puts path }' .github/workflows/*.yml` | 통과. 로컬 Ruby 환경의 `ffi-1.13.1` extension warning이 출력됐지만 YAML parse는 4개 workflow 모두 성공 |
| `for script in scripts/*.sh scripts/ci/*.sh; do bash -n "$script"; done` | 통과 |
| `bash scripts/ci/classify-pr-changes.sh --help` | 통과 |
| `scripts/ci/classify-pr-changes.sh origin/devel-webview HEAD` | `docs_only=false`, `run_release_checks=true`, `run_macos_build=false`, `run_rust_verify=false`, `run_render_smoke=false` |
| `.github` branch 참조 검색 | `devel`, `native-viewer-editor`, `devel-webview` legacy alias 참조 확인 |

## 보류 항목

| 항목 | 보류 사유 |
|------|-----------|
| 원격 `native-viewer-editor` 생성 | Stage 5 원격 전환 승인 전에는 수행하지 않음 |
| 원격 `devel` 교체 | Stage 5에서 기존 ref와 후보 ref를 재확인한 뒤 별도 승인으로만 수행 |
| GitHub branch protection/default branch 설정 | 원격 전환 후 GitHub repository setting에서 수동 확인 필요 |
| `devel-webview` 삭제 | legacy alias 유지 기간과 삭제 여부는 별도 승인으로 판단 |

## 다음 단계 제안

Stage 5에서는 원격 전환 gate를 재확인한 뒤, 작업지시자가 명시 승인할 경우에만 `native-viewer-editor` 보존 브랜치 생성, 제품 후보 commit 생성, `devel-webview` legacy alias fast-forward, `devel` 교체를 순서대로 수행한다.

## 승인 요청

Stage 4 workflow/automation 정렬을 완료했다. 이 보고서 기준으로 Stage 5 원격 전환 gate 확인을 진행해도 되는지 승인 요청한다.
