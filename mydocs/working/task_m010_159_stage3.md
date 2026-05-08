# Task #159 Stage 3 보고서

## 단계 목적

protected GitHub environment에서 signed/notarized public DMG를 생성하고 GitHub Release asset으로 게시하는 workflow를 추가한다. 이 단계는 자동화 정의와 helper만 추가하며, 실제 Apple notarization submission, GitHub Release 생성, Homebrew Cask 갱신은 실행하지 않는다.

## 산출물

| 파일 | 변경 | 요약 |
|------|------|------|
| `.github/workflows/release-publish.yml` | 신규 | tag 기준 public DMG 생성, 공증, GitHub Release asset 게시 workflow |
| `scripts/ci/import-developer-id-certificate.sh` | 신규 | Developer ID `.p12`를 임시 keychain에 import하는 CI helper |
| `scripts/ci/write-release-notes.sh` | 신규 | core provenance와 DMG checksum을 포함한 GitHub Release note 생성 helper |
| `mydocs/working/task_m010_159_stage3.md` | 신규 | Stage 3 구현 및 검증 결과 보고서 |

## 본문 변경 정도 / 본문 무손실 여부

- 앱 소스, Rust bridge, `scripts/release.sh`, Cask, README, manual은 변경하지 않았다.
- 기존 release script의 public mode를 수정하지 않고 workflow에서 호출한다.
- `rhwp-core.lock`은 변경하지 않았다. 현재 lock은 계속 `v0.7.9`이며, workflow 기본값은 `expected_rhwp_tag=v0.7.10`이므로 현재 상태에서 public publish는 중단되어야 정상이다.
- M16 병렬 작업이 다루는 앱 기능·렌더링·bridge 파일과 충돌하지 않는 `.github/workflows`, `scripts/ci`, stage 보고서만 추가했다.

## 구현 내용

### `release-publish.yml`

- `workflow_dispatch` 전용 workflow로 추가했다.
- `environment: release`를 지정해 GitHub protected environment 승인을 전제로 한다.
- `permissions.contents: write`를 명시해 GitHub Release asset upload에 필요한 권한만 열었다.
- 입력값:
  - `version`: 앱 버전. workflow는 반드시 `v<version>` tag ref에서 실행되어야 함
  - `expected_rhwp_tag`: `rhwp-core.lock`의 `rhwp_release_tag`와 일치해야 함. 기본값 `v0.7.10`
  - `require_latest_rhwp`: true이면 upstream `edwardkim/rhwp` latest release와 lock tag가 다르면 중단
  - `draft`: GitHub Release가 없을 때 draft로 생성할지 여부
  - `prerelease`: GitHub Release가 없을 때 prerelease로 표시할지 여부
- guard:
  - semantic version 형식 확인
  - 실행 ref가 `refs/tags/v<version>`인지 확인
  - checkout HEAD가 해당 tag commit과 일치하는지 확인
  - `rhwp-core.lock` tag가 `expected_rhwp_tag`와 일치하는지 확인
  - `require_latest_rhwp=true`이면 upstream latest release tag와 lock tag가 일치하는지 확인
  - `./scripts/build-rust-macos.sh --verify-lock` 실행
  - 기존 `./scripts/release.sh "$VERSION"` public preflight 사용
- publish:
  - `alhangeul-macos-<version>.dmg`와 `.sha256`을 검증한다.
  - release note를 생성한다.
  - GitHub Release가 있으면 asset을 `--clobber`로 업로드한다.
  - GitHub Release가 없으면 `--verify-tag`로 release를 생성하고 asset을 업로드한다.
  - Actions artifact copy도 14일 보관한다.

### `import-developer-id-certificate.sh`

- 필요한 secret:
  - `DEVELOPER_ID_APPLICATION_P12_BASE64`
  - `DEVELOPER_ID_APPLICATION_P12_PASSWORD`
  - `RELEASE_KEYCHAIN_PASSWORD`
- `RUNNER_TEMP/alhangeul-release.keychain-db` 임시 keychain을 만든다.
- `.p12`를 decode/import하고 `codesign`이 private key를 사용할 수 있도록 partition list를 설정한다.
- 임시 keychain을 user keychain search list와 default keychain으로 지정한다.
- workflow 마지막 단계에서 임시 keychain을 삭제한다.

### `write-release-notes.sh`

- 입력값: `version`, `dmg sha256`, `output file`
- `rhwp-core.lock`에서 `rhwp_release_tag`와 `rhwp_commit`을 읽는다.
- GitHub Release note에 설치 안내, DMG checksum, core provenance, 검증 기준을 기록한다.

## GitHub 설정 필요 항목

`release-publish.yml` 실행 전 GitHub repository 또는 `release` environment에 다음 값을 설정해야 한다. secret 값은 저장소 파일에 남기지 않는다.

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

## 검증 결과

```text
$ ruby -e 'require "yaml"; YAML.load_file(".github/workflows/release-publish.yml"); puts "ok"'
Ignoring ffi-1.13.1 because its extensions are not built. Try: gem pristine ffi --version 1.13.1
ok
```

Ruby local gem 경고는 현재 로컬 Ruby 환경의 `ffi` extension 경고이며 YAML parse는 성공했다.

```text
$ ruby -e 'require "yaml"; Dir[".github/workflows/*.yml"].sort.each { |f| YAML.load_file(f); puts f }'
.github/workflows/release-publish.yml
.github/workflows/release-rehearsal.yml
```

```text
$ bash -n scripts/ci/import-developer-id-certificate.sh
통과
```

```text
$ bash -n scripts/ci/write-release-notes.sh
통과
```

```text
$ bash scripts/ci/import-developer-id-certificate.sh
ERROR: DEVELOPER_ID_APPLICATION_P12_BASE64 is required to import Developer ID certificate
```

secret 없는 환경에서 certificate import helper가 build 전에 중단되는 것을 확인했다.

```text
$ env -u ALHANGEUL_DEVELOPER_ID_APPLICATION -u ALHANGEUL_NOTARY_PROFILE ./scripts/release.sh 0.1.0
ERROR: ALHANGEUL_DEVELOPER_ID_APPLICATION is required for public release
```

기존 release script public mode가 credential 없이 build 전에 중단되는 것을 확인했다.

```text
$ bash scripts/ci/write-release-notes.sh 0.1.0 d3c236f08b50ef5fb7552bd1b6678d98ab296765ffed65b91153d218262883e0 /private/tmp/task159-stage3-release-notes.md
통과
```

생성된 release note에는 현재 lock 기준 `rhwp` tag `v0.7.9`, commit `0fb3e6758b8ad11d2f3c3849c83b914684e83863`이 기록됐다.

```text
$ bash scripts/ci/write-release-notes.sh 0.1.0 invalid /private/tmp/task159-stage3-release-notes-invalid.md
ERROR: dmg sha256 must be a 64-character hex digest
```

checksum 형식 guard가 동작하는 것을 확인했다.

```text
$ ./scripts/build-rust-macos.sh --verify-lock
Verified: /private/tmp/rhwp-mac-task159/rhwp-core.lock
```

검증 중 Xcode/CoreSimulator 경고가 출력됐지만, Rust universal framework 생성과 lock 검증은 완료됐다.

```text
$ ./scripts/release.sh --help
통과
```

```text
$ git diff --check
통과
```

`actionlint`는 로컬에 설치되어 있지 않아 실행하지 못했다.

## 잔여 위험

- 실제 signed/notarized workflow 실행은 Apple credential과 GitHub `release` environment 설정이 필요하므로 이번 단계에서 수행하지 않았다.
- GitHub-hosted `macos-15` runner에서 keychain/notarytool 동작은 실제 workflow 첫 실행으로 확인해야 한다.
- 현재 lock이 `v0.7.9`라서 `release-publish.yml` 기본 입력값 그대로 실행하면 `expected_rhwp_tag=v0.7.10` guard에서 중단된다. 이는 M16 완료 후 public release 전에 core update 또는 명시적 예외 판단이 필요하다는 의도된 동작이다.
- `require_latest_rhwp=false`는 긴급 예외용 입력이다. 예외 사용 시 release note 또는 최종 release report에 stale core 배포 사유를 남겨야 한다.

## 다음 단계 영향

Stage 4에서는 upstream `rhwp` latest release 감지 workflow를 추가한다. Stage 3 publish guard가 public release 시점의 stale core를 막는 역할이라면, Stage 4는 평소에 upstream release 변화를 감지하고 compatibility check를 별도로 실행하는 역할을 맡는다.

## 승인 요청

Stage 3을 완료했다. Stage 4 `upstream rhwp release check workflow 구현`으로 진행할지 승인 요청한다.
