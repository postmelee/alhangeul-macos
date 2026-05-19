# Task M013 #274 Stage 2 보고서

## 단계 목적

Issue Template 변경이 PR CI classifier에서 앱 빌드 입력으로 오분류되지 않도록 `scripts/ci/classify-pr-changes.sh`를 보정하고, PR CI script checks에 Issue Template YAML parse 검증을 추가했다.

이번 단계에서는 `macOS validation` job 자체, release workflow, 제품 Swift/Rust 코드, #273 Issue Template 내용은 변경하지 않았다.

## 변경 파일

| 파일 | 변경 내용 |
|------|-----------|
| `scripts/ci/classify-pr-changes.sh` | `is_docs_path()`에 `.github/ISSUE_TEMPLATE/*`를 추가 |
| `.github/workflows/pr-ci.yml` | `script-checks`에 Issue Template YAML parse step 추가 |

## classifier 변경

기존 docs-only 경로는 다음과 같았다.

```bash
README.md|*.md|docs/*|mydocs/*
```

이번 단계에서 다음 경로를 추가했다.

```bash
.github/ISSUE_TEMPLATE/*
```

의도는 다음과 같다.

- Issue Template YAML과 `config.yml`은 앱, RustBridge, renderer, Xcode build 입력이 아니므로 macOS build fallback을 타지 않는다.
- `.github/*` 전체를 docs-only로 열지 않는다.
- `.github/workflows/*`는 기존처럼 CI/release automation 변경으로 분류된다.

## PR CI YAML 검증 추가

`script-checks` job에 다음 step을 추가했다.

```yaml
- name: Check issue template YAML syntax
  shell: bash
  run: |
    set -euo pipefail
    ruby -e 'require "psych"; Dir[".github/ISSUE_TEMPLATE/*.yml"].sort.each { |path| Psych.parse_file(path); puts "Parsed #{path}" }'
```

Ruby glob을 사용하므로 `.github/ISSUE_TEMPLATE/*.yml`가 없는 브랜치에서도 빈 배열을 순회하고 성공한다. 기존 workflow YAML parse step과 분리해 Issue Template YAML 오류를 별도 step에서 확인할 수 있게 했다.

## #273 범위 재검증

Stage 1에서 재현한 PR #273 범위를 같은 base/head로 다시 분류했다.

```bash
bash scripts/ci/classify-pr-changes.sh \
  1ce876faedb4792fad862fd74d6663b9bcdabf55 \
  2d718fbcbc2a69416ffb95a4ae0f054ec123503a
```

변경 후 출력:

| Flag | 변경 전 | 변경 후 |
|------|---------|---------|
| `docs_only` | `false` | `true` |
| `run_macos_build` | `true` | `false` |
| `run_rust_verify` | `false` | `false` |
| `run_render_smoke` | `false` | `false` |
| `run_release_checks` | `false` | `false` |

Issue Template 파일에 대해 더 이상 `not a docs-only path` 또는 `unclassified non-docs change` 이유가 출력되지 않았다.

## 현재 #274 변경 범위 분류

현재 추적 파일 변경을 포함한 임시 commit object를 만들어 classifier를 실행했다.

```bash
tmp_ref=$(git stash create task274-stage2-validation || true)
bash scripts/ci/classify-pr-changes.sh devel "$tmp_ref"
```

출력 요약:

| Flag | Value |
|------|-------|
| `docs_only` | `false` |
| `run_macos_build` | `false` |
| `run_rust_verify` | `false` |
| `run_render_smoke` | `false` |
| `run_release_checks` | `true` |

이는 현재 #274가 `.github/workflows/pr-ci.yml`과 `scripts/ci/classify-pr-changes.sh`를 바꾸는 CI 변경이므로 release/script checks를 켜되, macOS build는 켜지 않는다는 기대와 일치한다.

## 검증 결과

| 검증 | 결과 |
|------|------|
| `bash -n scripts/ci/classify-pr-changes.sh` | 통과 |
| `bash scripts/ci/classify-pr-changes.sh --help` | 통과 |
| `ruby -e 'require "psych"; Psych.parse_file(".github/workflows/pr-ci.yml"); puts "workflow-ok"'` | 통과 |
| `ruby -e 'require "psych"; Dir[".github/ISSUE_TEMPLATE/*.yml"].sort.each { \|path\| Psych.parse_file(path); puts "Parsed #{path}" }'` | 통과 |
| #273 범위 classifier 재검증 | `docs_only=true`, `run_macos_build=false`, `run_release_checks=false` |
| 현재 #274 추적 변경 분류 | `docs_only=false`, `run_macos_build=false`, `run_release_checks=true` |
| `git diff --check` | Stage 2 보고서 작성 후 수행 예정 |

로컬 Ruby 실행 시 `Ignoring ffi-1.13.1 because its extensions are not built` 경고가 출력되었지만, Psych parse는 정상 완료했다.

## Stage 2 판단

- Issue Template-only 변경은 이제 macOS validation을 켜지 않는다.
- CI/workflow 변경은 기존처럼 docs-only가 아니며 release/script checks를 켠다.
- `.github/workflows/*`의 보수 분류는 유지되었다.
- Stage 3에서는 Issue Template-only, workflow 변경, 제품 코드 변경 case를 표로 검증해 회귀 방지 확인을 남긴다.

## 승인 요청

Stage 2 classifier와 YAML 검증 보정을 완료했다. 이 보고서 기준으로 Stage 3 classifier case 검증과 회귀 방지 확인을 진행하려면 작업지시자 승인이 필요하다.
