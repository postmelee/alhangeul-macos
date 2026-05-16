# Task M018 #186 Stage 1 완료 보고서

## 단계 목적

GitHub Actions Node.js 20 deprecation warning 대응을 위해 현재 workflow에서 사용하는 official action을 전수 확인하고, Node.js 24 runtime 대응 major와 갱신 위험을 확정했다. 이 단계는 분석 보고이며 workflow 파일은 아직 수정하지 않았다.

## 현재 workflow action 사용 현황

| workflow | action | 개수 | 용도 |
|----------|--------|------|------|
| `pr-ci.yml` | `actions/checkout@v4` | 4 | 변경 범위 분류, script checks, macOS validation, release checks checkout |
| `release-rehearsal.yml` | `actions/checkout@v4` | 1 | rehearsal candidate checkout |
| `release-rehearsal.yml` | `actions/upload-artifact@v4` | 2 | release delta checklist artifact, rehearsal DMG/checksum artifact |
| `release-publish.yml` | `actions/checkout@v4` | 1 | release tag checkout |
| `release-publish.yml` | `actions/upload-artifact@v4` | 3 | release delta checklist artifact, appcast artifact, public DMG/checksum/release notes artifact |
| `rhwp-upstream-check.yml` | `actions/checkout@v4` | 1 | upstream check helper checkout |

합계:

- `actions/checkout@v4`: 7곳
- `actions/upload-artifact@v4`: 5곳
- `actions/deploy-pages`, `actions/upload-pages-artifact`: 0곳

현재 Pages는 GitHub Actions deployment workflow가 아니라 `main` 브랜치 `/docs`를 source로 쓰는 legacy branch publishing이다.

```text
build_type: legacy
source: main / docs
```

Pages deployment model 전환은 별도 이슈 [#206](https://github.com/postmelee/alhangeul-macos/issues/206)으로 분리했다. #186에서는 branch Pages/appcast push 구조를 바꾸지 않는다.

## 공식 runtime 기준

| action | 현재 | 목표 | 공식 확인 결과 |
|--------|------|------|----------------|
| `actions/checkout` | `v4` | `v6` | 최신 release `v6.0.2`, `action.yml`의 `runs.using: node24` |
| `actions/upload-artifact` | `v4` | `v7` | 최신 release `v7.0.1`, `action.yml`의 `runs.using: 'node24'` |

확인한 공식 자료:

- GitHub Changelog: `https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/`
- `actions/checkout` release/repository: `https://github.com/actions/checkout`
- `actions/upload-artifact` release/repository: `https://github.com/actions/upload-artifact`

Node.js 20은 2026년 4월 EOL이며, GitHub-hosted runner는 2026년 6월 2일부터 JavaScript action 기본 runtime을 Node.js 24로 전환하고, 2026년 가을 Node.js 20을 runner에서 제거할 예정이다. 대응은 임시 환경변수보다 Node.js 24에서 실행되는 official action major로 갱신하는 것이 기본이다.

## `actions/checkout@v6` 영향 분석

공식 README 기준 `checkout@v6`는 credential 보안을 개선해 `persist-credentials`가 credential을 `.git/config`에 직접 쓰지 않고 `$RUNNER_TEMP` 아래 별도 파일에 저장한다.

| 경로 | 현재 사용 | 영향 판단 |
|------|-----------|-----------|
| PR CI `classify-changes` | checkout 후 `git diff` 실행 | 인증 git push가 없으므로 영향 낮음 |
| PR CI `script-checks` | checkout 후 shell syntax/helper help | 인증 git 작업 없음 |
| PR CI `macos-validation` | checkout 후 build/test | 인증 git 작업 없음 |
| PR CI `release-checks` | checkout 후 `git fetch --tags --force`, release helper dry-run | public repo token checkout + fetch tag. 인증 push 없음 |
| release rehearsal | checkout 후 build/rehearsal artifact 생성 | 인증 git push 없음 |
| release publish tag checkout | `ref: ${{ github.ref }}`로 tag checkout | checkout 방식은 유지. 이후 GitHub Release publish는 `gh` CLI와 `GH_TOKEN` 사용 |
| release publish Pages appcast push | 별도 `git clone https://x-access-token:${GH_TOKEN}@github.com/...` 사용 | checkout credential storage와 독립. #206에서 Pages deployment model은 별도 검토 |
| rhwp upstream check | checkout 후 helper 실행 | 인증 git push 없음 |

결론: `checkout@v6` 갱신은 현재 workflow 구조와 충돌 가능성이 낮다. release publish의 Pages branch push는 checkout credential에 의존하지 않고 별도 token URL clone을 사용하므로 `v6` credential storage 변경의 직접 영향이 없다.

## `actions/upload-artifact@v7` 영향 분석

공식 README 기준 `upload-artifact@v7`에서도 현재 workflow가 쓰는 입력은 유지된다.

- `name`
- `path`
- `if-no-files-found`
- `retention-days`

주의점:

- 기본적으로 hidden file은 업로드하지 않는다.
- artifact는 mutation이 아니라 immutable/overwrite 모델이다.
- 같은 artifact 이름을 여러 job에서 누적 업로드하는 방식은 지원하지 않는다.

현재 workflow artifact는 모두 명시 파일 path를 사용하며 숨김 파일을 업로드하지 않는다. 같은 이름의 artifact를 여러 job에서 누적 업로드하지도 않는다.

| artifact | workflow | path | 영향 판단 |
|----------|----------|------|-----------|
| release delta checklist | rehearsal/publish | 단일 `.md` 파일 | hidden file 아님, 단일 upload |
| rehearsal DMG/checksum | rehearsal | DMG와 `.sha256` | hidden file 아님, 단일 upload |
| appcast artifact | publish | `appcast.xml` | hidden file 아님, 단일 upload |
| public DMG/checksum/release notes | publish | DMG, `.sha256`, notes `.md` | hidden file 아님, 단일 upload |

결론: `upload-artifact@v7` 갱신은 현재 artifact 입력과 충돌 가능성이 낮다.

## Stage 2 변경 기준

Stage 2에서는 workflow 구조를 바꾸지 않고 다음 reference만 갱신한다.

| 변경 전 | 변경 후 |
|---------|---------|
| `actions/checkout@v4` | `actions/checkout@v6` |
| `actions/upload-artifact@v4` | `actions/upload-artifact@v7` |

유지해야 할 항목:

- `pull_request` 기반 PR CI
- release publish의 `workflow_dispatch`
- release publish의 `environment: release`
- tag `v<version>` 검증
- GitHub Release asset publish 경로
- Sparkle appcast 생성 조건
- branch Pages/appcast push 구조

사용하지 않을 우회:

- `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24`
- `ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION`

## 검증 결과

```bash
git status --short --branch
```

결과: `local/task186`, Stage 1 보고서 작성 전 clean 상태를 확인했다.

```bash
rg -n "uses:|actions/checkout@|actions/upload-artifact@|actions/deploy-pages|actions/upload-pages-artifact" .github/workflows
```

결과 요약:

- `actions/checkout@v4`: 7곳
- `actions/upload-artifact@v4`: 5곳
- `actions/deploy-pages`, `actions/upload-pages-artifact`: 없음

```bash
gh api repos/actions/checkout/contents/action.yml --method GET -f ref=v6 --jq '.content' | base64 --decode | rg -n "runs:|using:|node"
```

결과: `runs.using: node24`.

```bash
gh api repos/actions/upload-artifact/contents/action.yml --method GET -f ref=v7 --jq '.content' | base64 --decode | rg -n "runs:|using:|node"
```

결과: `runs.using: 'node24'`.

```bash
gh issue view 206 --json number,title,state,url
```

결과: #206이 `OPEN` 상태임을 확인했다.

```bash
gh api repos/postmelee/alhangeul-macos/pages --jq '{source: .source, build_type: .build_type, html_url: .html_url, status: .status}'
```

결과: Pages는 `legacy`, source는 `main`/`docs`.

```bash
git diff --check
```

결과: 출력 없음, exit code 0.

## 다음 단계 영향

Stage 2에서는 이 보고서의 기준대로 official action major reference만 갱신한다. Pages deployment model 전환, `deploy-pages` workflow 추가, `pages: write`/`id-token: write` 권한 추가는 #206 범위로 남긴다.

## 승인 요청

Stage 1 산출물 승인을 요청한다.

승인 후 Stage 2 `workflow action version 갱신`으로 진행한다.
