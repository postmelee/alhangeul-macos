# Task M013 #274 Stage 3 보고서

## 단계 목적

Issue Template 경로 보정 이후 주요 변경 유형에서 `scripts/ci/classify-pr-changes.sh`가 의도한 flag를 유지하는지 case별로 확인했다.

이번 단계에서는 classifier와 workflow를 추가 수정하지 않았다. 검증 산출물은 이 보고서만 추가한다.

## 검증 방식

처음에는 `devel` 트리에서 경로별 임시 commit object를 만들어 순수 fixture를 구성하려 했으나, sandbox가 `.git/objects` 임시 파일 생성을 막아 중단했다. 저장소 작업트리와 refs는 변경되지 않았다.

대신 실제 저장소 히스토리의 commit 범위를 사용해 다음 case를 검증했다.

| Case | 범위 | 변경 유형 |
|------|------|-----------|
| Issue Template/doc-only | `6a3cd6c^..6a3cd6c` | `.github/ISSUE_TEMPLATE/*` 8개와 단계 보고서 |
| CI workflow/script | `7b77a71^..7b77a71` | `.github/workflows/pr-ci.yml`, `scripts/ci/classify-pr-changes.sh`, 단계 보고서 |
| 제품 HostApp source | `8d4184b^..8d4184b` | `Sources/HostApp/*` 4개와 단계 문서 |

`mydocs/*` 문서는 docs-only 경로이므로 각 case의 앱 빌드 trigger 판단을 바꾸지 않는다.

## Case별 결과

| Case | 기대 flag | 실제 flag | 판단 |
|------|-----------|-----------|------|
| Issue Template/doc-only | `docs_only=true`, `run_macos_build=false`, `run_release_checks=false` | `docs_only=true`, `run_macos_build=false`, `run_release_checks=false` | OK |
| CI workflow/script | `docs_only=false`, `run_macos_build=false`, `run_release_checks=true` | `docs_only=false`, `run_macos_build=false`, `run_release_checks=true` | OK |
| 제품 HostApp source | `docs_only=false`, `run_macos_build=true`, `run_release_checks=false` | `docs_only=false`, `run_macos_build=true`, `run_release_checks=false` | OK |

## Issue Template/doc-only case

명령:

```bash
bash scripts/ci/classify-pr-changes.sh 6a3cd6c^ 6a3cd6c
```

변경 파일 요약:

- `.github/ISSUE_TEMPLATE/01-user-bug.yml`
- `.github/ISSUE_TEMPLATE/02-document-compatibility.yml`
- `.github/ISSUE_TEMPLATE/03-quick-look-thumbnail.yml`
- `.github/ISSUE_TEMPLATE/04-feature-request.yml`
- `.github/ISSUE_TEMPLATE/05-install-update-release.yml`
- `.github/ISSUE_TEMPLATE/07-developer-task.yml`
- `.github/ISSUE_TEMPLATE/08-regression.yml`
- `.github/ISSUE_TEMPLATE/config.yml`
- `mydocs/working/task_m013_272_stage2.md`

출력 요약:

| Flag | Value |
|------|-------|
| `docs_only` | `true` |
| `run_macos_build` | `false` |
| `run_rust_verify` | `false` |
| `run_render_smoke` | `false` |
| `run_release_checks` | `false` |

`Non-docs reasons`, `macOS build reasons`, `Release check reasons`가 모두 `없음`으로 출력되었다. Issue Template 변경이 macOS validation을 켜지 않는다는 목표를 만족한다.

## CI workflow/script case

명령:

```bash
bash scripts/ci/classify-pr-changes.sh 7b77a71^ 7b77a71
```

변경 파일 요약:

- `.github/workflows/pr-ci.yml`
- `scripts/ci/classify-pr-changes.sh`
- `mydocs/working/task_m013_274_stage2.md`

출력 요약:

| Flag | Value |
|------|-------|
| `docs_only` | `false` |
| `run_macos_build` | `false` |
| `run_rust_verify` | `false` |
| `run_render_smoke` | `false` |
| `run_release_checks` | `true` |

`.github/workflows/pr-ci.yml`과 `scripts/ci/classify-pr-changes.sh`는 계속 CI/release automation 변경으로 분류된다. `.github/*` 전체를 docs-only로 열지 않는다는 Stage 2 원칙을 유지한다.

## 제품 HostApp source case

명령:

```bash
bash scripts/ci/classify-pr-changes.sh 8d4184b^ 8d4184b
```

변경 파일 요약:

- `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift`
- `Sources/HostApp/Stores/DocumentViewerStore.swift`
- `Sources/HostApp/Views/DocumentViewerView.swift`
- `Sources/HostApp/Views/RhwpStudioWebView.swift`
- `mydocs/orders/20260514.md`
- `mydocs/working/task_m010_243_stage2.md`

출력 요약:

| Flag | Value |
|------|-------|
| `docs_only` | `false` |
| `run_macos_build` | `true` |
| `run_rust_verify` | `false` |
| `run_render_smoke` | `false` |
| `run_release_checks` | `false` |

`Sources/HostApp/*` 변경은 기존처럼 app/Xcode build 입력으로 분류되어 `run_macos_build=true`를 유지한다.

## 현재 #274 브랜치 분류

명령:

```bash
bash scripts/ci/classify-pr-changes.sh devel HEAD
```

출력 요약:

| Flag | Value |
|------|-------|
| `docs_only` | `false` |
| `run_macos_build` | `false` |
| `run_rust_verify` | `false` |
| `run_render_smoke` | `false` |
| `run_release_checks` | `true` |

현재 #274 브랜치는 classifier와 PR CI workflow를 변경하므로 docs-only는 아니며 release/script checks를 켠다. 제품 build 입력은 바꾸지 않았으므로 `run_macos_build=false`가 기대와 일치한다.

## 문법 검증

| 검증 | 결과 |
|------|------|
| `bash -n scripts/ci/classify-pr-changes.sh` | 통과 |
| `ruby -e 'require "psych"; Psych.parse_file(".github/workflows/pr-ci.yml"); puts "workflow-ok"'` | 통과 |
| `ruby -e 'require "psych"; Dir[".github/ISSUE_TEMPLATE/*.yml"].sort.each { \|path\| Psych.parse_file(path); puts "Parsed #{path}" }'` | 통과 |

로컬 Ruby 실행 시 `Ignoring ffi-1.13.1 because its extensions are not built` 경고가 출력되었지만, Psych parse는 정상 완료했다.

## 판단

- Issue Template 변경은 docs/metadata 변경으로 분류되어 macOS validation을 켜지 않는다.
- workflow와 classifier script 변경은 계속 release/script automation 변경으로 분류된다.
- `Sources/HostApp/*` 제품 코드 변경은 기존처럼 macOS validation을 켠다.
- Stage 2 구현을 보완할 추가 코드 변경은 없다.

## 승인 요청

Stage 3 classifier case 검증을 완료했다. 이 보고서 기준으로 Stage 4 최종 검증, 최종 보고서 작성, 오늘할일 완료 처리, PR 게시 준비를 진행하려면 작업지시자 승인이 필요하다.
