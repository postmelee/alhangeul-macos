# Task #159 Stage 1 보고서

## 단계 목적

GitHub Actions release 자동화의 입력값, 권한, secret/environment, publish guard를 먼저 고정한다. Stage 1은 구현 없이 설계 경계만 확정해 M16 병렬 작업과 충돌하지 않는 Stage 2~4 구현 기준을 만든다.

## 산출물

| 파일 | 변경 | 요약 |
|------|------|------|
| `mydocs/working/task_m010_159_stage1.md` | 신규 | release rehearsal, publish, upstream check workflow 요구사항과 guard 설계 |

## 본문 변경 정도 / 본문 무손실 여부

- 소스, workflow, release script, Cask, README, manual은 변경하지 않았다.
- 이번 단계는 신규 stage 보고서만 추가한다.
- M16 작업 산출물과 충돌할 가능성이 높은 문서 본문은 건드리지 않았다.

## 조사 결과

현재 release script 기준:

- `scripts/release.sh --skip-notarize <version>`은 rehearsal DMG를 생성한다.
- `scripts/release.sh <version>` public mode는 `ALHANGEUL_DEVELOPER_ID_APPLICATION`, `ALHANGEUL_NOTARY_PROFILE`을 요구한다.
- public mode는 clean worktree를 요구하고, app/DMG signing, app/DMG notarization, staple, Gatekeeper assessment, sha256 생성을 수행한다.
- GitHub Release 생성과 asset upload는 `scripts/release.sh`가 수행하지 않는다.

현재 core 기준:

- `rhwp-core.lock`의 `rhwp_release_tag`는 `v0.7.9`다.
- 2026-05-06 확인 기준 upstream `edwardkim/rhwp` 최신 release는 `v0.7.10`이다.
- 따라서 첫 public publish 전 `v0.7.10` compatibility check와 core bump 여부를 별도 판단해야 한다.

## Workflow 설계

### `release-rehearsal.yml`

목적:

- secret 없이 release layout, DMG 생성, checksum 생성을 확인한다.
- output은 Actions artifact로만 보관하고 public release asset으로 쓰지 않는다.

Trigger:

- `workflow_dispatch`

Inputs:

| 이름 | 필수 | 기본값 | 의미 |
|------|------|--------|------|
| `version` | yes | `0.1.0` | `scripts/release.sh --skip-notarize`에 넘길 앱 버전 |
| `expected_rhwp_tag` | no | empty | 비어 있지 않으면 `rhwp-core.lock`의 `rhwp_release_tag`와 일치해야 함 |

Permissions:

```yaml
permissions:
  contents: read
```

Guard:

- `expected_rhwp_tag` 입력값이 있으면 lock tag와 비교한다.
- `./scripts/build-rust-macos.sh --verify-lock`를 먼저 실행한다.
- `./scripts/release.sh --skip-notarize "$version"`만 실행한다.

Artifact:

- `build.noindex/release/alhangeul-macos-<version>-rehearsal.dmg`
- `build.noindex/release/alhangeul-macos-<version>-rehearsal.dmg.sha256`

### `release-publish.yml`

목적:

- protected environment 승인 후 signed/notarized public DMG를 만들고 GitHub Release asset으로 업로드한다.
- M16 완료 전에는 workflow 정의만 두고 실제 실행하지 않는다.

Trigger:

- `workflow_dispatch`

Environment:

- `release`
- GitHub environment protection rule로 reviewer approval을 요구한다.

Inputs:

| 이름 | 필수 | 기본값 | 의미 |
|------|------|--------|------|
| `version` | yes | `0.1.0` | release version. tag는 `v<version>` 기준 |
| `expected_rhwp_tag` | yes | `v0.7.10` | publish하려는 core release tag. lock tag와 일치해야 함 |
| `require_latest_rhwp` | yes | `true` | true이면 upstream latest tag와 lock tag가 다를 때 중단 |
| `draft` | yes | `true` | GitHub Release draft 여부 |
| `prerelease` | yes | `true` | v0.1 preview release 성격 표시 |

Permissions:

```yaml
permissions:
  contents: write
```

Repository/environment values:

| 이름 | 구분 | 용도 |
|------|------|------|
| `ALHANGEUL_DEVELOPER_ID_APPLICATION` | environment variable | signing identity 표시명 |
| `ALHANGEUL_DEVELOPER_ID_DMG` | environment variable, optional | DMG signing identity. 비우면 app identity 사용 |
| `ALHANGEUL_NOTARY_PROFILE` | environment variable | CI keychain profile name |
| `APPLE_TEAM_ID` | environment variable 또는 secret | notarytool credential 생성용 Team ID |
| `DEVELOPER_ID_APPLICATION_P12_BASE64` | environment secret | Developer ID Application certificate export |
| `DEVELOPER_ID_APPLICATION_P12_PASSWORD` | environment secret | `.p12` password |
| `NOTARY_APPLE_ID` | environment secret | notarytool Apple ID 방식 사용 시 |
| `NOTARY_APP_SPECIFIC_PASSWORD` | environment secret | notarytool Apple ID 방식 사용 시 |
| `RELEASE_KEYCHAIN_PASSWORD` | environment secret | temporary keychain password |

Publish guard:

- Git tag `v<version>`가 존재해야 한다.
- checkout은 release tag `refs/tags/v<version>` 기준으로 수행한다.
- `rhwp-core.lock`의 `rhwp_release_tag`가 `expected_rhwp_tag`와 일치해야 한다.
- `require_latest_rhwp=true`이면 upstream latest release tag도 lock tag와 일치해야 한다. 현재 상태에서는 lock이 `v0.7.9`, latest가 `v0.7.10`이므로 publish는 중단되어야 정상이다.
- `./scripts/build-rust-macos.sh --verify-lock`로 Cargo.lock, core lock, artifact 정합성을 확인한다.
- `scripts/release.sh`의 plist version check와 clean worktree preflight를 그대로 사용한다.

Release asset:

- `build.noindex/release/alhangeul-macos-<version>.dmg`
- `build.noindex/release/alhangeul-macos-<version>.dmg.sha256`

Release note skeleton:

- release version과 tag
- `rhwp-core.lock`의 `rhwp_release_tag`
- `rhwp-core.lock`의 `rhwp_commit`
- DMG sha256
- M16에서 확정될 license/provenance, smoke result, known limitations 섹션 자리

### `rhwp-upstream-check.yml`

목적:

- upstream `edwardkim/rhwp` 최신 release를 감지하고 current lock과 비교한다.
- release publish와 분리해 source 수정 없이 compatibility check 결과만 남긴다.

Trigger:

- `workflow_dispatch`
- `schedule`은 보수적으로 주 1회 또는 수동 운영이 안정화된 뒤 추가한다.

Inputs:

| 이름 | 필수 | 기본값 | 의미 |
|------|------|--------|------|
| `target_tag` | no | empty | 비어 있으면 latest release tag 사용 |
| `run_compatibility_check` | yes | `true` | `scripts/update-rhwp-core.sh --check` 실행 여부 |

Permissions:

```yaml
permissions:
  contents: read
```

동작:

- `gh release view -R edwardkim/rhwp`로 latest tag를 조회한다.
- current lock tag와 latest tag를 job summary에 기록한다.
- latest 또는 target tag가 current lock과 다르면 `./scripts/update-rhwp-core.sh --check --channel stable --tag <tag>`를 실행한다.
- check 실패는 publish failure가 아니라 compatibility 또는 lookup failure로 분리해 표시한다.
- lock, Cargo.toml, Cargo.lock, Framework artifact는 수정하지 않는다.

## Stage 2~4 구현 경계

- Stage 2는 `release-rehearsal.yml`과 lock tag helper까지만 구현한다.
- Stage 3는 protected publish workflow와 signing/notary setup을 구현하되 실제 public publish는 하지 않는다.
- Stage 4는 upstream check workflow를 구현하고 `v0.7.10` 감지와 compatibility check 결과를 기록한다.
- `scripts/release.sh`는 기존 인터페이스가 충분하므로 Stage 2~4에서 수정하지 않는 것을 기본값으로 둔다.

## 검증 결과

```text
$ gh release view -R edwardkim/rhwp --json tagName,publishedAt,targetCommitish,url,name
{"name":"v0.7.10 — 외부 기여자 7명 + AI/VLM 연동 + CLI 바이너리 릴리즈","publishedAt":"2026-05-05T17:56:40Z","tagName":"v0.7.10","targetCommitish":"main","url":"https://github.com/edwardkim/rhwp/releases/tag/v0.7.10"}
```

```text
$ git status --short --branch
## local/task159...origin/devel-webview [ahead 2]
```

```text
$ git diff --check
통과
```

## 잔여 위험

- GitHub-hosted runner의 Xcode/macOS image 차이로 `xcodegen`, Rust targets, notarization tooling 가용성 문제가 생길 수 있다. Stage 2 이후 실제 workflow 실행 결과로 조정해야 한다.
- `require_latest_rhwp=true`는 stale core publish를 막지만, 긴급 patch release에서는 의도적으로 이전 core를 배포해야 할 수 있다. 이 경우 입력값으로 우회하되 release note에 사유를 남겨야 한다.
- Apple credential은 GitHub environment secret으로만 관리해야 한다. 이 repo에는 secret 값이나 `.p12` payload를 남기지 않는다.

## 다음 단계 영향

Stage 2는 이 설계를 기준으로 `release-rehearsal.yml`을 추가한다. public publish 관련 secret은 Stage 2에서 필요하지 않다. Stage 3 전에는 `release` environment와 secret naming이 실제 GitHub repository 설정과 맞는지 한 번 더 확인해야 한다.

## 승인 요청

Stage 1을 완료했다. Stage 2 `release rehearsal workflow 구현`으로 진행할지 승인 요청한다.
