# Task #159 최종 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | [#159 GitHub Actions 기반 release 자동화 파이프라인 구축](https://github.com/postmelee/alhangeul-macos/issues/159) |
| 마일스톤 | M010 / v0.1.0 Viewer 기반 |
| 기준 브랜치 | `devel-webview` |
| 작업 브랜치 | `local/task159` |
| 단계 수 | 5단계 |
| 결론 | GitHub Actions 기반 release rehearsal, signed/notarized publish, upstream `rhwp` release 감지 workflow를 추가했다. |

이번 작업은 M16 병렬 작업과 충돌하지 않도록 `.github/workflows`, `scripts/ci`, task 문서만 수정했다. 실제 public release publish, Apple notarization submission, GitHub Release 생성, Homebrew tap push, `rhwp` `v0.7.10` core bump는 실행하지 않았다.

## 단계별 결과

| 단계 | 커밋 | 결과 |
|------|------|------|
| 계획 | `df0301b`, `5ec71ae` | 수행계획서, 구현계획서, 오늘할일 항목을 작성했다. |
| Stage 1 | `4651333` | release rehearsal, publish, upstream check workflow 요구사항과 secret/environment guard를 설계했다. |
| Stage 2 | `c81d473` | secret 없는 rehearsal DMG workflow와 `rhwp-core.lock` reader helper를 추가했다. |
| Stage 3 | `a9c7ef0` | protected environment 기반 signed/notarized publish workflow, Developer ID import helper, release note helper를 추가했다. |
| Stage 4 | `5eab85b` | upstream `rhwp` latest release 감지와 compatibility check workflow/helper를 추가했다. |
| Stage 5 | 이번 최종 보고 커밋 | 최종 검증, 오늘할일 완료 처리, 최종 보고서를 정리했다. |

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `.github/workflows/release-rehearsal.yml` | 수동 실행으로 unsigned rehearsal DMG와 checksum을 생성하고 Actions artifact로 보관한다. |
| `.github/workflows/release-publish.yml` | `release` environment 승인 후 tag 기준 signed/notarized DMG를 만들고 GitHub Release asset으로 업로드한다. |
| `.github/workflows/rhwp-upstream-check.yml` | 수동/일일 schedule로 upstream `edwardkim/rhwp` release를 확인하고 current lock과 비교한다. |
| `scripts/ci/read-rhwp-core-lock.sh` | `rhwp-core.lock`의 top-level scalar 값을 workflow에서 읽는다. |
| `scripts/ci/import-developer-id-certificate.sh` | Developer ID Application `.p12`를 임시 keychain에 import한다. |
| `scripts/ci/write-release-notes.sh` | DMG checksum과 `rhwp` core provenance를 포함한 release note skeleton을 생성한다. |
| `scripts/ci/check-rhwp-upstream-release.sh` | current lock, latest release, target release, compatibility check 결과를 summary/output으로 남긴다. |
| `mydocs/plans/task_m010_159.md` | 수행계획서를 추가했다. |
| `mydocs/plans/task_m010_159_impl.md` | 단계별 구현계획서를 추가했다. |
| `mydocs/working/task_m010_159_stage{1,2,3,4}.md` | 단계별 설계, 구현, 검증 결과를 기록했다. |
| `mydocs/report/task_m010_159_report.md` | 최종 보고서를 추가했다. |
| `mydocs/orders/20260506.md` | #159 상태를 완료로 갱신했다. |

## Workflow별 운영 기준

### Release Rehearsal

- trigger: `workflow_dispatch`
- permissions: `contents: read`
- inputs: `version`, optional `expected_rhwp_tag`
- 실행 내용:
  - version 형식 검증
  - `rhwp-core.lock` tag/commit summary 기록
  - `./scripts/build-rust-macos.sh --verify-lock`
  - `./scripts/release.sh --skip-notarize <version>`
  - `*-rehearsal.dmg`와 `.sha256` artifact 업로드
- 주의:
  - unsigned, unnotarized 산출물이므로 public release asset이나 Homebrew Cask checksum으로 사용하지 않는다.

### Release Publish

- trigger: `workflow_dispatch`
- environment: `release`
- permissions: `contents: write`
- inputs:
  - `version`
  - `expected_rhwp_tag` 기본값 `v0.7.10`
  - `require_latest_rhwp` 기본값 `true`
  - `draft` 기본값 `true`
  - `prerelease` 기본값 `true`
- guard:
  - 실행 ref가 `v<version>` tag인지 확인
  - checkout HEAD와 tag commit 일치 확인
  - `expected_rhwp_tag`와 `rhwp-core.lock`의 `rhwp_release_tag` 일치 확인
  - `require_latest_rhwp=true`이면 upstream latest와 current lock 일치 확인
  - `./scripts/build-rust-macos.sh --verify-lock`
  - 기존 `./scripts/release.sh <version>` public mode preflight
- 실행 내용:
  - Developer ID `.p12` 임시 keychain import
  - notarytool credential 저장
  - signed/notarized DMG 생성
  - DMG checksum 검증
  - GitHub Release asset upload 또는 release 생성

### rhwp Upstream Check

- trigger: `workflow_dispatch`, `schedule`
- schedule: `17 0 * * *`
- permissions: `contents: read`
- inputs:
  - optional `target_tag`
  - `run_compatibility_check`
- 실행 내용:
  - current `rhwp-core.lock` tag/commit 조회
  - upstream latest release 조회
  - target release metadata 기록
  - current와 target이 다르면 `outdated=true`
  - compatibility check가 켜져 있으면 `./scripts/update-rhwp-core.sh --check --channel stable --tag <target>` 실행
- 주의:
  - source, lock, Cargo 파일, framework artifact를 자동 수정하지 않는다.

## GitHub 설정 필요 항목

`release-publish.yml` 실행 전 GitHub `release` environment에 reviewer protection과 다음 값이 필요하다.

| 이름 | 권장 위치 | 구분 |
|------|----------|------|
| `ALHANGEUL_DEVELOPER_ID_APPLICATION` | environment variable | Developer ID Application identity 표시명 |
| `ALHANGEUL_DEVELOPER_ID_DMG` | environment variable, optional | DMG signing identity. 비우면 app identity 사용 |
| `ALHANGEUL_NOTARY_PROFILE` | environment variable | notarytool keychain profile name |
| `APPLE_TEAM_ID` | environment variable 또는 secret | Apple Team ID |
| `DEVELOPER_ID_APPLICATION_P12_BASE64` | environment secret | Developer ID Application `.p12` base64 |
| `DEVELOPER_ID_APPLICATION_P12_PASSWORD` | environment secret | `.p12` password |
| `NOTARY_APPLE_ID` | environment secret | notarization Apple ID |
| `NOTARY_APP_SPECIFIC_PASSWORD` | environment secret | notarization app-specific password |
| `RELEASE_KEYCHAIN_PASSWORD` | environment secret | temporary keychain password |

secret 값, `.p12` payload, app-specific password는 저장소 파일에 기록하지 않았다.

## 현재 core 상태와 publish 영향

2026-05-06 확인 기준:

| 항목 | 값 |
|------|----|
| current lock tag | `v0.7.9` |
| current lock commit | `0fb3e6758b8ad11d2f3c3849c83b914684e83863` |
| upstream latest release | `v0.7.10` |
| latest published at | `2026-05-05T17:56:40Z` |
| latest URL | `https://github.com/edwardkim/rhwp/releases/tag/v0.7.10` |
| latest compatibility check | passed |
| latest resolved commit | `62a458aa317e962cd3d0eec6096728c172d57110` |

현재 상태에서 `release-publish.yml` 기본값으로 public publish를 실행하면 `expected_rhwp_tag=v0.7.10` guard 또는 `require_latest_rhwp=true` guard에서 중단된다. 이는 M16이 `v0.7.9` 기준으로 진행 중인 상태에서 stale core로 첫 public release가 나가지 않도록 한 의도된 동작이다.

첫 public release 전에는 별도 core update task로 `rhwp` `v0.7.10` 반영과 smoke 검증을 수행하거나, 이전 core로 배포해야 하는 명시적 사유를 release report에 남기고 `require_latest_rhwp=false` 예외를 사용해야 한다.

## 최종 검증 결과

| 검증 | 결과 | 비고 |
|------|------|------|
| `git diff --check` | OK | whitespace error 없음 |
| workflow YAML parse | OK | 3개 workflow 로드 성공 |
| `bash -n scripts/ci/*.sh` | OK | CI helper syntax 검증 |
| `./scripts/build-rust-macos.sh --verify-lock` | OK | `rhwp-core.lock` 검증 통과 |
| `./scripts/check-no-appkit.sh` | OK | shared Swift code 경계 유지 |
| `./scripts/release.sh --help` | OK | release script interface 확인 |
| public release missing credential preflight | OK | `ALHANGEUL_DEVELOPER_ID_APPLICATION` 누락으로 build 전 중단 |
| Developer ID import missing secret preflight | OK | `.p12` secret 누락으로 build 전 중단 |
| release note helper | OK | current core tag/commit 포함 note 생성 |
| upstream latest lookup | OK | latest `v0.7.10` 확인 |
| upstream compatibility helper | OK | `v0.7.10` check passed |
| rehearsal DMG 생성 | OK | unsigned rehearsal DMG 생성과 `hdiutil verify` 통과 |
| rehearsal checksum 검증 | OK | `shasum -a 256 -c` 통과 |

YAML parse 중 로컬 Ruby 환경의 `ffi` extension 경고가 출력됐지만 parse는 성공했다.

`./scripts/build-rust-macos.sh --verify-lock` 중 Xcode/CoreSimulator 관련 로컬 경고가 출력됐지만, 최종적으로 `Verified: /private/tmp/rhwp-mac-task159/rhwp-core.lock`가 출력됐다.

최종 rehearsal artifact:

```text
build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg
build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg.sha256
```

최종 rehearsal checksum:

```text
1b7229c162a543574d7f1fd072dd1fded31df44d6f37906434acf3e944e8cde4  alhangeul-macos-0.1.0-rehearsal.dmg
```

`actionlint`는 로컬에 설치되어 있지 않아 실행하지 못했다. 원격 PR CI 또는 개발자 환경에 `actionlint`가 있으면 추가 검증하는 것이 좋다.

## 수용 기준 충족 여부

| 수용 기준 | 결과 |
|----------|------|
| M16 병렬 작업과 충돌하지 않는 별도 release automation 변경 | OK |
| secret 없는 rehearsal DMG workflow | OK |
| signed/notarized publish workflow 정의 | OK |
| protected `release` environment 전제 | OK |
| tag ref guard | OK |
| `expected_rhwp_tag`와 current lock 비교 guard | OK |
| upstream latest와 current lock 비교 guard | OK |
| current core provenance release note 기록 | OK |
| upstream `rhwp` latest 감지 workflow | OK |
| `v0.7.10` 감지와 compatibility check 기록 | OK |
| 실제 public publish 미실행 | OK |
| secret 값 미기록 | OK |

## 첫 public release 가능 조건

이 작업이 merge되면 GitHub Actions 기반 release 자동화 경로는 준비된다. 다만 사용자가 설치 가능한 첫 public release를 내기 전에는 다음 조건이 남는다.

- M16 release-critical 이슈 merge 완료
- `rhwp` `v0.7.10` core update와 앱 smoke 검증 완료, 또는 stale core 배포 예외 승인
- GitHub `release` environment reviewer protection 설정
- Apple Developer ID/notarization 관련 variables/secrets 설정
- release 기준 commit을 `main`에 반영
- `v0.1.0` tag 생성
- `release-publish.yml` 수동 실행과 environment 승인
- 생성된 GitHub Release asset과 sha256 확인
- Homebrew Cask/tap 반영 여부 결정

따라서 이 task 완료만으로 Homebrew까지 자동 배포되지는 않는다. 이번 작업은 GitHub Release public DMG와 checksum을 안정적으로 만들고 업로드하는 경로를 제공하며, Homebrew Cask 갱신과 tap publish는 public DMG 생성 후 별도 승인/후속 작업으로 처리해야 한다.

## 잔여 위험과 후속 작업

| 구분 | 내용 |
|------|------|
| GitHub Actions 실환경 | `macos-15` runner의 keychain/notarytool 동작은 실제 protected workflow 첫 실행에서 검증해야 한다. |
| Apple credential | `.p12`, app-specific password, keychain password는 작업지시자가 GitHub environment secret으로 설정해야 한다. |
| `rhwp` 최신 반영 | `v0.7.10` compatibility check는 passed지만 actual core bump/build/smoke는 별도 task가 필요하다. |
| Homebrew | public DMG와 sha256 확정 후 Cask/tap 갱신 workflow 또는 수동 PR 절차를 별도 확정해야 한다. |
| actionlint | 로컬에 없어 미실행했다. PR CI 또는 별도 개발자 환경에서 추가 실행 권장. |
| release notes | M16 최종 smoke result, known limitations, license/provenance 문구는 첫 public release 직전에 최종 보고서 기준으로 보정해야 한다. |

## 작업지시자 승인 요청

Task #159는 GitHub Actions release 자동화 파이프라인 구현과 최종 검증을 완료했다. 다음 단계는 `publish/task159` 원격 push와 `devel-webview` 대상 PR 생성 승인이다.
