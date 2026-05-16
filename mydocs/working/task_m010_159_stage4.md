# Task #159 Stage 4 보고서

## 단계 목적

upstream `edwardkim/rhwp` 최신 release를 감지하고 현재 `rhwp-core.lock`과 비교하는 workflow를 추가한다. 이 단계는 source, lock, Cargo 파일을 자동 수정하지 않고, update 필요 여부와 compatibility check 결과만 GitHub Actions summary에 남긴다.

## 산출물

| 파일 | 변경 | 요약 |
|------|------|------|
| `.github/workflows/rhwp-upstream-check.yml` | 신규 | 수동/일일 schedule 기반 upstream release 감지 workflow |
| `scripts/ci/check-rhwp-upstream-release.sh` | 신규 | current lock과 upstream release 비교 및 optional compatibility check helper |
| `mydocs/working/task_m010_159_stage4.md` | 신규 | Stage 4 구현 및 검증 결과 보고서 |

## 본문 변경 정도 / 본문 무손실 여부

- 앱 소스, Rust bridge, `scripts/update-rhwp-core.sh`, `scripts/release.sh`, Cask, README, manual은 변경하지 않았다.
- `rhwp-core.lock`, `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`, framework artifact는 변경하지 않았다.
- M16 병렬 작업과 직접 충돌하지 않는 `.github/workflows`, `scripts/ci`, stage 보고서만 추가했다.

## 구현 내용

### `rhwp-upstream-check.yml`

- `workflow_dispatch`와 `schedule` trigger를 추가했다.
- schedule은 `17 0 * * *`로 매일 00:17 UTC에 실행한다. source 수정이 없는 read-only check라 upstream release가 잦은 상황에서도 부담이 낮고, stale core를 하루 안에 드러낼 수 있다.
- 입력값:
  - `target_tag`: 비어 있으면 upstream latest release를 사용한다.
  - `run_compatibility_check`: true이면 target tag가 current lock과 다를 때 `update-rhwp-core.sh --check`를 실행한다.
- `permissions.contents: read`로 제한했다.
- `ubuntu-latest`에서 실행한다. Xcode build나 notarization이 아니라 GitHub release lookup과 git/API compatibility check만 수행하기 때문이다.

### `check-rhwp-upstream-release.sh`

- 현재 `rhwp-core.lock`에서 `rhwp_release_tag`, `rhwp_commit`을 읽는다.
- `gh release view -R edwardkim/rhwp`로 latest release tag를 조회한다.
- `target_tag`가 주어지면 해당 release를 확인하고, 없으면 latest release를 target으로 사용한다.
- current lock tag와 target tag가 다르면 `outdated=true`로 표시한다.
- compatibility check가 켜져 있고 target이 current와 다르면 다음 명령을 실행한다.

```bash
./scripts/update-rhwp-core.sh --check --channel stable --tag <target-tag>
```

- helper는 다음 값을 `GITHUB_OUTPUT`에 남긴다.
  - `current_tag`
  - `current_commit`
  - `latest_tag`
  - `target_tag`
  - `target_url`
  - `outdated`
  - `compatibility_status`
- GitHub step summary에는 current lock, latest release, target release, outdated 여부, compatibility status, release metadata, compatibility check output을 기록한다.
- compatibility check 실패는 workflow failure로 보고한다. 단순히 upstream이 최신인 상태는 failure가 아니라 `outdated=true`, `compatibility_status=passed`로 보고한다.

## 검증 결과

```text
$ ruby -e 'require "yaml"; YAML.load_file(".github/workflows/rhwp-upstream-check.yml"); puts "ok"'
Ignoring ffi-1.13.1 because its extensions are not built. Try: gem pristine ffi --version 1.13.1
ok
```

Ruby local gem 경고는 현재 로컬 Ruby 환경의 `ffi` extension 경고이며 YAML parse는 성공했다.

```text
$ ruby -e 'require "yaml"; Dir[".github/workflows/*.yml"].sort.each { |f| YAML.load_file(f); puts f }'
.github/workflows/release-publish.yml
.github/workflows/release-rehearsal.yml
.github/workflows/rhwp-upstream-check.yml
```

```text
$ bash -n scripts/ci/check-rhwp-upstream-release.sh
통과
```

```text
$ bash scripts/ci/check-rhwp-upstream-release.sh --help
통과
```

```text
$ bash scripts/ci/check-rhwp-upstream-release.sh --target-tag bad --run-compatibility-check false
ERROR: rhwp release tag must look like vMAJOR.MINOR.PATCH, got: bad
```

target tag 형식 guard가 동작하는 것을 확인했다.

```text
$ bash scripts/ci/check-rhwp-upstream-release.sh --run-compatibility-check false
current_tag=v0.7.9
latest_tag=v0.7.10
target_tag=v0.7.10
outdated=true
compatibility_status=skipped_by_input
```

network 제한이 있는 sandbox 안에서는 GitHub API 연결이 차단되어, 위 upstream 조회 검증은 승인된 네트워크 실행으로 확인했다.

```text
$ bash scripts/ci/check-rhwp-upstream-release.sh --run-compatibility-check true
current_tag=v0.7.9
latest_tag=v0.7.10
target_tag=v0.7.10
outdated=true
compatibility_status=passed
```

compatibility check output:

```text
From https://github.com/edwardkim/rhwp
 * [new tag]         v0.7.10    -> v0.7.10
Checked rhwp core target:
  channel: stable
  tag:     v0.7.10
  commit:  62a458aa317e962cd3d0eec6096728c172d57110
```

2026-05-06 확인 기준 upstream latest release:

```text
tag: v0.7.10
name: v0.7.10 — 외부 기여자 7명 + AI/VLM 연동 + CLI 바이너리 릴리즈
published_at: 2026-05-05T17:56:40Z
url: https://github.com/edwardkim/rhwp/releases/tag/v0.7.10
target_commitish: main
```

```text
$ git status --short --branch
## local/task159...origin/devel-webview [ahead 5]
?? .github/workflows/rhwp-upstream-check.yml
?? scripts/ci/check-rhwp-upstream-release.sh
```

검증 후 `rhwp-core.lock`, `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`은 수정되지 않았다.

```text
$ git diff --check
통과
```

`actionlint`는 로컬에 설치되어 있지 않아 실행하지 못했다.

## 잔여 위험

- scheduled workflow는 upstream release를 감지하고 compatibility check만 수행한다. 실제 `v0.7.10` 반영은 별도 core update task에서 `update-rhwp-core.sh`, build, smoke test를 거쳐야 한다.
- GitHub API rate limit이나 일시적 upstream 장애는 workflow failure로 나타날 수 있다. 이 경우 release publish guard와는 별개의 lookup failure로 판단해야 한다.
- current lock이 stale이더라도 compatibility check가 passed이면 workflow는 성공한다. public publish 중단은 Stage 3 `release-publish.yml`의 `expected_rhwp_tag`와 `require_latest_rhwp` guard가 담당한다.

## 다음 단계 영향

Stage 5에서는 전체 workflow YAML, CI helper, lock 검증, release preflight를 다시 묶어서 확인하고 최종 보고서를 작성한다. 이 task 완료 후에도 첫 public release 전에는 M16 산출물 merge, `rhwp` `v0.7.10` 반영 여부 결정, GitHub `release` environment/secret 설정, signed/notarized workflow dry-run이 남는다.

## 승인 요청

Stage 4를 완료했다. Stage 5 `최종 검증과 보고서 정리`로 진행할지 승인 요청한다.
