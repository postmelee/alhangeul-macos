# GitHub Actions Node.js 20 deprecation warning 대응 기록

## 배경

- 날짜: 2026-05-10
- 관련 이슈: [#186](https://github.com/postmelee/alhangeul-macos/issues/186)
- 관련 후속 이슈: [#206](https://github.com/postmelee/alhangeul-macos/issues/206)

GitHub Actions runner에서 JavaScript action의 Node.js 20 runtime deprecation warning이 release 판단을 흐릴 수 있어 official action major를 Node.js 24 runtime 대응 버전으로 갱신했다.

확인한 공식 자료:

- GitHub Changelog: `https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/`
- `actions/checkout`: `https://github.com/actions/checkout`
- `actions/upload-artifact`: `https://github.com/actions/upload-artifact`

## 증상

GitHub Actions run annotation에 Node.js 20 기반 JavaScript action deprecation warning이 표시된다.

위험:

- PR CI와 release rehearsal/publish run의 상태 해석이 불명확해진다.
- GitHub-hosted runner에서 Node.js 20 runtime 제거 시점 이후 workflow가 실패할 수 있다.
- release 판단 시 실제 build/release 문제와 runner runtime warning이 섞일 수 있다.

## 원인

작업 당시 workflow는 다음 official action major를 사용했다.

| action | 기존 major | 사용 위치 |
|--------|------------|-----------|
| `actions/checkout` | `v4` | PR CI, release rehearsal, release publish, upstream check |
| `actions/upload-artifact` | `v4` | release rehearsal, release publish |

GitHub-hosted runner의 JavaScript action runtime 기준이 Node.js 24로 이동하면서 Node.js 20 기반 action major를 유지하면 deprecation warning이 발생한다.

## 대응

official action repository의 `action.yml` runtime을 확인한 뒤 다음처럼 갱신했다.

| action | 변경 전 | 변경 후 | 확인한 runtime |
|--------|---------|---------|----------------|
| `actions/checkout` | `actions/checkout@v4` | `actions/checkout@v6` | `runs.using: node24` |
| `actions/upload-artifact` | `actions/upload-artifact@v4` | `actions/upload-artifact@v7` | `runs.using: node24` |

변경 파일:

- `.github/workflows/pr-ci.yml`
- `.github/workflows/rhwp-upstream-check.yml`
- `.github/workflows/release-rehearsal.yml`
- `.github/workflows/release-publish.yml`

유지한 범위:

- workflow trigger, permissions, environment 유지
- release publish tag 검증 유지
- GitHub Release asset upload 유지
- stable Sparkle appcast 조건 유지
- branch Pages/appcast push 구조 유지

적용하지 않은 우회:

- `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24`
- `ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION`

## 확인 명령

workflow action reference 점검:

```bash
rg -n "uses:|actions/checkout@|actions/upload-artifact@|actions/deploy-pages|actions/upload-pages-artifact" .github/workflows
```

official action runtime 확인:

```bash
gh api repos/actions/checkout/contents/action.yml --method GET -f ref=v6 --jq '.content' | base64 --decode | rg -n "runs:|using:|node"
gh api repos/actions/upload-artifact/contents/action.yml --method GET -f ref=v7 --jq '.content' | base64 --decode | rg -n "runs:|using:|node"
```

local validation:

```bash
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/pr-ci.yml")'
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/release-rehearsal.yml")'
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/release-publish.yml")'
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/rhwp-upstream-check.yml")'
bash -n scripts/ci/*.sh
scripts/ci/classify-pr-changes.sh devel-webview HEAD
git diff --check
```

기대 결과:

- `actions/checkout@v4`: 없음
- `actions/upload-artifact@v4`: 없음
- `actions/checkout@v6`: 7곳
- `actions/upload-artifact@v7`: 5곳
- PR 변경 범위 분류: `run_release_checks=true`

## 재발 방지

- JavaScript action runtime deprecation warning이 발생하면 manual에 특정 사건 내용을 누적하지 않는다.
- `mydocs/manual/ci_workflow_guide.md`에는 action runtime 확인 절차와 판단 기준만 둔다.
- 특정 runtime, action major, warning 문구, 검증 결과는 troubleshooting 문서에 기록한다.
- Pages deployment model 전환은 Node.js runtime warning 대응과 분리한다. 이 작업은 #206에서 추적한다.
