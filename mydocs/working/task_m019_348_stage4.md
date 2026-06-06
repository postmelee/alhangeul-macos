# Task M019 #348 Stage 4 완료 보고서

## 단계 목적

`publish/task348` 원격 ref에서 `rhwp Upstream Sync PR` workflow를 `dry_run=true`로 실행해 target/current 판정, upstream impact 분석, 기존 automation branch/PR 확인, dry-run decision이 원격 GitHub Actions에서 동작하는지 검증한다.

## 확인 시각

- 2026-06-07 03:33 KST

## 원격 ref

```bash
git push origin local/task348:publish/task348
```

초기 push 결과:

- `publish/task348` 생성
- pushed commit: `44879241826d6856dc1984ac4d1e4c7fc16ea46f`

dry-run 실패 수정 후 재push:

- pushed commit: `9fedf20cd9f6468298096539adea4babedf27739`

## 1차 dry-run 실패와 수정

실행:

```bash
gh workflow run "rhwp Upstream Sync PR" \
  --repo postmelee/alhangeul-macos \
  --ref publish/task348 \
  -f target_tag=v0.7.15 \
  -f force_pr=false \
  -f dry_run=true
```

1차 run:

- URL: `https://github.com/postmelee/alhangeul-macos/actions/runs/27070391813`
- conclusion: `failure`
- failed job: `Resolve rhwp full sync target`
- failed step: `Verify helper syntax`

원인:

```text
bash: scripts/ci/write-rhwp-full-sync-pr-body.sh: No such file or directory
```

workflow file은 `publish/task348`에서 실행됐지만 checkout step이 `ref: devel`을 사용해, 아직 `devel`에 없는 신규 helper를 찾지 못했다. 이는 #348 PR merge 전 원격 ref 검증에서만 드러나는 문제이며, workflow가 default branch에 merge된 뒤에는 자연히 해소될 수 있지만 Stage 4 검증과 Stage 5 실제 PR 생성 검증을 위해 수정했다.

수정:

- checkout step을 `ref: ${{ github.ref }}`로 변경해 workflow 실행 ref의 helper를 사용하도록 보정
- PR 생성 job은 `origin/devel` 기반 automation branch로 switch하기 전에 `write-rhwp-full-sync-pr-body.sh`를 `build.noindex` 아래 임시 파일로 복사해 사용하도록 보정
- step 이름을 `Check out workflow ref`로 정리

수정 커밋:

```text
9fedf20 Task #348 Stage 4: dry-run workflow ref checkout 보정
```

수정 후 로컬 검증:

```bash
git diff --check
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/rhwp-upstream-sync-pr.yml"); puts "parsed"'
actionlint .github/workflows/rhwp-upstream-sync-pr.yml
bash -n scripts/ci/write-rhwp-full-sync-pr-body.sh
bash -n scripts/ci/read-rhwp-core-lock.sh
```

결과: 통과.

## 2차 dry-run 성공

실행:

```bash
gh workflow run "rhwp Upstream Sync PR" \
  --repo postmelee/alhangeul-macos \
  --ref publish/task348 \
  -f target_tag=v0.7.15 \
  -f force_pr=false \
  -f dry_run=true
```

2차 run:

- URL: `https://github.com/postmelee/alhangeul-macos/actions/runs/27070451323`
- event: `workflow_dispatch`
- head branch: `publish/task348`
- head SHA: `9fedf20cd9f6468298096539adea4babedf27739`
- status: `completed`
- conclusion: `success`
- createdAt: `2026-06-06T18:31:44Z`
- updatedAt: `2026-06-06T18:32:18Z`

job 결과:

| job | conclusion |
|-----|------------|
| `Resolve rhwp full sync target` | success |
| `Build upstream rhwp-studio assets` | skipped |
| `Create rhwp full sync PR candidate` | skipped |

`dry_run=true`이므로 build와 PR 생성 job이 skip되는 것이 의도한 동작이다.

## dry-run 판정 값

현재 local/publish 기준:

| 항목 | 값 |
|------|----|
| current core tag | `v0.7.13` |
| current core commit | `b3e16ef212af81ef37d973ddb86d6816d3804642` |
| current studio tag | `v0.7.13` |
| current studio commit | `b3e16ef212af81ef37d973ddb86d6816d3804642` |
| target tag | `v0.7.15` |
| target commit | `aa925a5954f0fd26dfcef2166cbce7877c481f44` |
| automation branch | `automation/rhwp-v0.7.15-full-sync` |

impact 결과:

```text
current_tag=v0.7.13
current_commit=b3e16ef212af81ef37d973ddb86d6816d3804642
target_tag=v0.7.15
target_commit=aa925a5954f0fd26dfcef2166cbce7877c481f44
has_viewer_impact=true
impact_reason_count=176
```

기존 automation branch/PR 확인:

- `automation/rhwp-v0.7.15-full-sync` remote branch 없음
- `devel` 대상 `automation/rhwp-v0.7.15-full-sync` PR 없음

decision:

- `dry_run=true` 입력 때문에 `should_build=false`
- build/PR 생성 job skip 확인

## GitHub App token 설정 확인

사용자가 등록한 repository variable/secret 이름을 확인했다. secret 값은 조회하지 않았다.

```text
ALHANGEUL_AUTOMATION_CLIENT_ID      registered at 2026-06-06T18:26:42Z
ALHANGEUL_AUTOMATION_APP_PRIVATE_KEY registered at 2026-06-06T18:27:36Z
```

`dry_run=true`에서는 `create-full-sync-pr` job이 skip되므로 GitHub App token 발급과 push/PR 생성은 아직 실행되지 않았다. Stage 5에서 `dry_run=false`로 확인해야 한다.

## 완료 기준 확인

| 기준 | 결과 |
|------|------|
| `publish/task348` 원격 ref 생성 | OK |
| `dry_run=true` workflow 실행 | OK, 2차 run success |
| helper syntax 원격 검증 | OK |
| target release resolve | OK, `v0.7.15` |
| current core/studio provenance 판정 | OK, 둘 다 `v0.7.13` |
| upstream impact detection | OK, `has_viewer_impact=true`, `176` |
| 기존 automation branch/PR 확인 | OK, 없음 |
| build/PR 생성 skip | OK, `dry_run=true` |
| GitHub App variable/secret 등록 확인 | OK, 이름 확인 |

## 다음 단계

Stage 5에서는 같은 `publish/task348` ref에서 `dry_run=false`로 실행해 실제 full sync build, automation branch 생성, PR 생성, PR CI 자동 trigger를 검증한다. 이 단계는 upstream WASM/studio build와 macOS RustBridge/core lock update를 실제로 수행하고 `automation/rhwp-v0.7.15-full-sync` PR을 만들 수 있다.

## 승인 요청 사항

Stage 4 보고서를 승인하면 Stage 5 `실제 full sync 자동 PR 생성 검증`으로 진행한다.
