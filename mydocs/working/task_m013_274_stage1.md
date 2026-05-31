# Task M013 #274 Stage 1 보고서

## 단계 목적

PR #273에서 Issue Template 추가만으로 `macOS validation`이 실행된 원인을 로컬 classifier 실행으로 재현하고, Stage 2의 보정 방식을 확정했다.

이번 단계에서는 `scripts/ci/classify-pr-changes.sh`와 `.github/workflows/pr-ci.yml`을 수정하지 않았다.

## 현재 구조 확인

PR CI는 `devel` 대상 PR에서 항상 시작한다.

| 항목 | 현재 동작 |
|------|-----------|
| workflow trigger | `.github/workflows/pr-ci.yml`의 `pull_request.branches`가 `main`, `devel`, `native-viewer-editor`를 포함 |
| classifier job | `Classify changed files`가 `scripts/ci/classify-pr-changes.sh $base_sha HEAD` 실행 |
| macOS validation 조건 | `needs.classify-changes.outputs.run_macos_build == 'true'` |
| docs-only 판정 | `README.md`, `*.md`, `docs/*`, `mydocs/*`만 docs path로 인정 |
| fallback | 분류되지 않은 non-docs 변경은 `run_macos_build=true` |

핵심 원인은 `is_docs_path()`가 `.github/ISSUE_TEMPLATE/*`를 docs/metadata 경로로 인식하지 않는다는 점이다.

## #273 변경 범위 재현

PR #273 merge commit은 다음 부모를 가진다.

| 항목 | commit |
|------|--------|
| merge commit | `587943179cbc2ed5944e6b61977d5726caaa59de` |
| base parent | `1ce876faedb4792fad862fd74d6663b9bcdabf55` |
| head parent | `2d718fbcbc2a69416ffb95a4ae0f054ec123503a` |

따라서 PR #273의 변경 범위는 다음 명령으로 재현했다.

```bash
git diff --name-only 1ce876faedb4792fad862fd74d6663b9bcdabf55..2d718fbcbc2a69416ffb95a4ae0f054ec123503a
```

변경 파일은 Issue Template 8개와 `mydocs/` 문서 7개였다.

```text
.github/ISSUE_TEMPLATE/01-user-bug.yml
.github/ISSUE_TEMPLATE/02-document-compatibility.yml
.github/ISSUE_TEMPLATE/03-quick-look-thumbnail.yml
.github/ISSUE_TEMPLATE/04-feature-request.yml
.github/ISSUE_TEMPLATE/05-install-update-release.yml
.github/ISSUE_TEMPLATE/07-developer-task.yml
.github/ISSUE_TEMPLATE/08-regression.yml
.github/ISSUE_TEMPLATE/config.yml
mydocs/orders/20260519.md
mydocs/plans/task_m013_272.md
mydocs/plans/task_m013_272_impl.md
mydocs/report/task_m013_272_report.md
mydocs/working/task_m013_272_stage1.md
mydocs/working/task_m013_272_stage2.md
mydocs/working/task_m013_272_stage3.md
```

## classifier 현재 출력

재현 명령:

```bash
bash scripts/ci/classify-pr-changes.sh \
  1ce876faedb4792fad862fd74d6663b9bcdabf55 \
  2d718fbcbc2a69416ffb95a4ae0f054ec123503a
```

현재 출력 요약:

| Flag | Value |
|------|-------|
| `docs_only` | `false` |
| `run_macos_build` | `true` |
| `run_rust_verify` | `false` |
| `run_render_smoke` | `false` |
| `run_release_checks` | `false` |

classifier는 `.github/ISSUE_TEMPLATE/*.yml` 8개 각각에 대해 다음 이유를 기록했다.

- `... is not a docs-only path`
- `... is unclassified non-docs change`

따라서 #273에서 `macOS validation`이 실행된 것은 의도된 앱 빌드 필요성 때문이 아니라, Issue Template 경로가 docs/metadata로 분류되지 않아 fallback에 걸린 결과다.

## 현재 #274 브랜치 출력

`local/task274`의 현재 변경은 `mydocs/` 계획 문서뿐이므로 classifier는 docs-only로 분류한다.

```bash
bash scripts/ci/classify-pr-changes.sh devel HEAD
```

출력 요약:

| Flag | Value |
|------|-------|
| `docs_only` | `true` |
| `run_macos_build` | `false` |
| `run_rust_verify` | `false` |
| `run_render_smoke` | `false` |
| `run_release_checks` | `false` |

이 결과는 현재 classifier의 기본 docs-only 동작은 정상이며, 문제 범위가 `.github/ISSUE_TEMPLATE/*`로 좁혀진다는 점을 보여준다.

## Stage 2 설계 판단

Stage 2에서는 다음 두 가지를 수행한다.

1. `scripts/ci/classify-pr-changes.sh`
   - `is_docs_path()`에 `.github/ISSUE_TEMPLATE/*`를 추가한다.
   - `.github/*` 전체를 docs-only로 열지 않는다.
   - `.github/workflows/*`는 기존 release/script automation 분류를 유지한다.

2. `.github/workflows/pr-ci.yml`
   - `script-checks`에 Issue Template YAML parse step을 추가한다.
   - Ruby glob `Dir[".github/ISSUE_TEMPLATE/*.yml"]`를 사용해 디렉터리가 없거나 매칭 파일이 없어도 실패하지 않게 한다.
   - 기존 workflow YAML parse step과 별도 step으로 두어 실패 원인을 명확히 한다.

## 제외 유지 판단

다음은 Stage 2에서도 수행하지 않는다.

- `.github/workflows/*` docs-only 분류
- `macOS validation` job 삭제 또는 조건 약화
- release workflow 변경
- branch protection 또는 required check 설정 변경
- #273 Issue Template 내용 변경
- 제품 Swift/Rust 코드, RustBridge, Xcode project 변경

## 검증 결과

| 검증 | 결과 |
|------|------|
| `git status --short --branch` | `local/task274`, Stage 1 시작 시 clean |
| `bash scripts/ci/classify-pr-changes.sh --help` | 통과 |
| `bash scripts/ci/classify-pr-changes.sh 1ce876f... 2d718fb...` | #273 범위에서 `run_macos_build=true` 재현 |
| `bash scripts/ci/classify-pr-changes.sh devel HEAD` | 현재 #274 문서 변경은 `docs_only=true` |
| `rg -n "is_docs_path|unclassified non-docs|ISSUE_TEMPLATE|macOS validation|run_macos_build" ...` | 관련 위치 확인 |
| `git diff --check` | 보고서 작성 후 수행 예정 |

## 승인 요청

Stage 1 재현과 설계 확정을 완료했다. 이 보고서 기준으로 Stage 2 classifier와 YAML 검증 보정을 진행하려면 작업지시자 승인이 필요하다.
