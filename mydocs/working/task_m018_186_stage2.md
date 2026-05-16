# Task M018 #186 Stage 2 완료 보고서

## 단계 목적

GitHub Actions Node.js 20 deprecation warning 대응을 위해 workflow 구조는 유지하고 official action major reference만 Node.js 24 runtime 대응 버전으로 갱신했다.

## 변경 요약

| workflow | 변경 전 | 변경 후 | 개수 |
|----------|---------|---------|------|
| `.github/workflows/pr-ci.yml` | `actions/checkout@v4` | `actions/checkout@v6` | 4 |
| `.github/workflows/rhwp-upstream-check.yml` | `actions/checkout@v4` | `actions/checkout@v6` | 1 |
| `.github/workflows/release-rehearsal.yml` | `actions/checkout@v4` | `actions/checkout@v6` | 1 |
| `.github/workflows/release-rehearsal.yml` | `actions/upload-artifact@v4` | `actions/upload-artifact@v7` | 2 |
| `.github/workflows/release-publish.yml` | `actions/checkout@v4` | `actions/checkout@v6` | 1 |
| `.github/workflows/release-publish.yml` | `actions/upload-artifact@v4` | `actions/upload-artifact@v7` | 3 |

합계:

- `actions/checkout@v6`: 7곳
- `actions/upload-artifact@v7`: 5곳
- `actions/checkout@v4`: 0곳
- `actions/upload-artifact@v4`: 0곳

## 유지한 범위

이번 단계에서는 action major reference 외의 workflow 동작을 바꾸지 않았다.

- PR CI trigger와 job 조건 유지
- release rehearsal/publish `workflow_dispatch` 입력 유지
- release publish `environment: release` 유지
- tag 검증, GitHub Release asset upload, Sparkle appcast 생성 조건 유지
- branch Pages/appcast push 구조 유지
- `actions/deploy-pages`, `actions/upload-pages-artifact` 도입 없음
- 임시 우회 환경변수 추가 없음

Pages deployment model 전환은 별도 이슈 #206 범위로 유지한다.

## 검증 결과

```bash
git status --short --branch
```

결과: `local/task186`에서 네 개 workflow 변경을 확인했다.

```bash
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/pr-ci.yml")'
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/release-rehearsal.yml")'
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/release-publish.yml")'
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/rhwp-upstream-check.yml")'
```

결과: 네 workflow 모두 exit code 0. 로컬 Ruby 환경에서 `ffi-1.13.1` gem extension warning이 출력됐지만 YAML parse 자체는 성공했다.

```bash
bash -n scripts/ci/*.sh
```

결과: exit code 0.

```bash
rg -n "actions/checkout@v4|actions/upload-artifact@v4|actions/checkout@v6|actions/upload-artifact@v7" .github/workflows
```

결과:

- `actions/checkout@v6`: 7곳
- `actions/upload-artifact@v7`: 5곳
- `actions/checkout@v4`: 없음
- `actions/upload-artifact@v4`: 없음

```bash
rg -n "FORCE_JAVASCRIPT_ACTIONS_TO_NODE24|ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION" .github/workflows mydocs/manual
```

결과: 출력 없음, exit code 1. 우회 환경변수는 추가하지 않았다.

```bash
git diff --check
```

결과: 출력 없음, exit code 0.

## PR 변경 범위 분류

커밋 후 `HEAD` 기준으로 다시 확인했다.

```bash
scripts/ci/classify-pr-changes.sh devel-webview HEAD
```

결과 요약:

| Flag | Value |
|------|-------|
| `docs_only` | `false` |
| `run_macos_build` | `false` |
| `run_rust_verify` | `false` |
| `run_render_smoke` | `false` |
| `run_release_checks` | `true` |

Release check reason:

- `.github/workflows/pr-ci.yml` affects release scripts, workflows, or Cask automation
- `.github/workflows/release-publish.yml` affects release scripts, workflows, or Cask automation
- `.github/workflows/release-rehearsal.yml` affects release scripts, workflows, or Cask automation
- `.github/workflows/rhwp-upstream-check.yml` affects release scripts, workflows, or Cask automation

## 다음 단계 영향

Stage 3에서는 Node.js action runtime warning 대응 기준과 official action major 갱신 판단 절차를 `ci_workflow_guide.md`에 문서화한다.

## 승인 요청

Stage 2 산출물 승인을 요청한다.

승인 후 Stage 3 `CI/runtime 대응 기준 문서화`로 진행한다.
