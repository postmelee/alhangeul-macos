# Task #159 구현 계획서

본 문서는 [`task_m010_159.md`](task_m010_159.md) 수행계획서를 단계별 실행 단위로 분해한 것이다. 각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 환경

- **Worktree**: `/private/tmp/rhwp-mac-task159`
- **Branch**: `local/task159`
- **기준 브랜치**: `devel-webview`
- **기준 이슈**: [#159](https://github.com/postmelee/alhangeul-macos/issues/159)
- **범위**: GitHub Actions release rehearsal, publish, upstream rhwp release check 자동화

## 확정 전제

- M16 작업은 별도 브랜치에서 병렬 진행 중이므로, 이 작업은 기본적으로 `.github/workflows`와 CI helper script만 수정한다.
- 실제 public release publish, notarization submission, GitHub Release 게시, Homebrew tap 반영은 이 task 구현 중 실행하지 않는다.
- release publish workflow는 floating latest를 사용하지 않는다. `rhwp-core.lock`과 `RustBridge/Cargo.lock` 정합성을 검증하고, 수동 입력 `expected_rhwp_tag`와 lock tag가 일치할 때만 진행한다.
- 2026-05-06 기준 현재 lock은 `v0.7.9`이고 upstream 최신 release는 `v0.7.10`이다. 이 작업은 `v0.7.10` 반영을 직접 수행하지 않고, publish 전 check/guard가 이를 드러내도록 만든다.
- Apple Developer ID certificate, notarization credential, keychain password는 GitHub repository/environment secrets로 주입하는 전제만 문서화하고 값은 저장하지 않는다.
- Homebrew 공식 cask 등재는 이 task 완료 기준이 아니다.

## Stage 1 — workflow 요구사항과 secret/environment 설계

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `mydocs/working/task_m010_159_stage1.md` | workflow별 입력, 권한, secret, environment, publish guard 설계 기록 | 단계 보고서 |
| `mydocs/plans/task_m010_159_impl.md` | 필요 시 구현계획서 보정 | blocker 발견 시만 |

### 설계 항목

- `release-rehearsal.yml`
  - trigger: `workflow_dispatch`
  - inputs: `version`, `expected_rhwp_tag`
  - permissions: `contents: read`
  - output: rehearsal DMG와 sha256을 Actions artifact로 업로드
- `release-publish.yml`
  - trigger: `workflow_dispatch`
  - environment: `release`
  - permissions: `contents: write`
  - inputs: `version`, `expected_rhwp_tag`, `prerelease`, `draft`
  - guards: tag ref, plist version, lock tag, clean release script preflight
- `rhwp-upstream-check.yml`
  - trigger: `workflow_dispatch`, 필요 시 `schedule`
  - permissions: `contents: read`
  - output: current lock tag, upstream latest tag, compatibility check 결과 summary
- secrets/variables
  - Developer ID `.p12` base64, password, Apple ID 또는 App Store Connect API key, Team ID, temporary keychain password
  - repository secret과 environment secret 경계

### 단계 검증

```bash
cd /private/tmp/rhwp-mac-task159
gh release view -R edwardkim/rhwp --json tagName,publishedAt,targetCommitish,url,name
git status --short --branch
git diff --check
```

### 커밋

```
Task #159 Stage 1: release workflow 요구사항과 guard 설계
```

## Stage 2 — release rehearsal workflow 구현

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `.github/workflows/release-rehearsal.yml` | 수동 rehearsal DMG 생성 workflow 추가 | public release asset으로 사용 금지 |
| 필요 시 `scripts/ci/read-rhwp-core-lock.sh` | lock 값 읽기 helper | publish workflow와 공유 가능 |
| `mydocs/working/task_m010_159_stage2.md` | 단계 보고서 | 검증 결과 포함 |

### 구현 기준

- `workflow_dispatch`로만 실행한다.
- checkout 후 `./scripts/build-rust-macos.sh --verify-lock`, `./scripts/release.sh --skip-notarize <version>` 경로를 사용한다.
- `expected_rhwp_tag`가 비어 있지 않으면 `rhwp-core.lock`의 `rhwp_release_tag`와 비교한다.
- `*-rehearsal.dmg`와 `.sha256`만 Actions artifact로 업로드한다.
- GitHub Release 생성, notarization, Homebrew Cask 갱신은 수행하지 않는다.

### 단계 검증

```bash
cd /private/tmp/rhwp-mac-task159
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/release-rehearsal.yml"); puts "ok"'
./scripts/release.sh --help
./scripts/build-rust-macos.sh --verify-lock
git diff --check
```

가능하면 별도 승인 또는 환경 가능 시:

```bash
./scripts/release.sh --skip-notarize 0.1.0
```

### 커밋

```
Task #159 Stage 2: release rehearsal workflow 추가
```

## Stage 3 — signed/notarized publish workflow 구현

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `.github/workflows/release-publish.yml` | protected environment 기반 publish workflow 추가 | 실제 실행은 제외 |
| 필요 시 `scripts/ci/import-developer-id-certificate.sh` | temporary keychain import helper | secret 값 없음 |
| 필요 시 `scripts/ci/write-release-notes.sh` | release note skeleton 생성 | M16 결과 주입 가능하게 설계 |
| `mydocs/working/task_m010_159_stage3.md` | 단계 보고서 | secret/guard 설명 포함 |

### 구현 기준

- `workflow_dispatch`와 `environment: release`로 보호한다.
- `permissions.contents: write`를 명시한다.
- `version`은 plist version과 일치해야 한다.
- workflow ref 또는 입력 tag가 `v<version>` 기준인지 확인한다.
- `expected_rhwp_tag`와 `rhwp-core.lock`의 tag가 다르면 중단한다.
- temporary keychain을 만들고 Developer ID certificate를 import한 뒤 `scripts/release.sh <version>`만 호출한다.
- DMG와 sha256 생성 후 `gh release create` 또는 `gh release upload`로 GitHub Release asset을 draft/prerelease로 게시하는 경로를 만든다.
- M16 완료 전 실제 publish는 실행하지 않는다.

### 단계 검증

```bash
cd /private/tmp/rhwp-mac-task159
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/release-publish.yml"); puts "ok"'
./scripts/release.sh --help
env -u ALHANGEUL_DEVELOPER_ID_APPLICATION -u ALHANGEUL_NOTARY_PROFILE ./scripts/release.sh 0.1.0
git diff --check
```

credential 누락 preflight는 `ERROR: ALHANGEUL_DEVELOPER_ID_APPLICATION is required for public release`로 build 전에 실패해야 정상이다.

### 커밋

```
Task #159 Stage 3: signed notarized release publish workflow 추가
```

## Stage 4 — upstream rhwp release check workflow 구현

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `.github/workflows/rhwp-upstream-check.yml` | upstream latest release 감지 workflow 추가 | source 수정 없음 |
| 필요 시 `scripts/ci/check-rhwp-upstream-release.sh` | latest release와 current lock 비교 helper | compatibility check 실행 |
| `mydocs/working/task_m010_159_stage4.md` | 단계 보고서 | `v0.7.10` 감지 결과 포함 |

### 구현 기준

- `workflow_dispatch`를 기본으로 하고, schedule은 보수적으로 추가한다.
- `gh release view -R edwardkim/rhwp`로 latest release tag를 확인한다.
- current lock tag와 latest tag를 summary에 기록한다.
- latest tag가 current lock보다 앞서 있으면 `./scripts/update-rhwp-core.sh --check --channel stable --tag <latest>`를 실행한다.
- check 실패는 publish 실패와 분리해 compatibility failure 또는 lookup failure로 보고한다.
- lock, Cargo.toml, Cargo.lock, Framework artifact를 자동 수정하지 않는다.

### 단계 검증

```bash
cd /private/tmp/rhwp-mac-task159
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/rhwp-upstream-check.yml"); puts "ok"'
gh release view -R edwardkim/rhwp --json tagName,publishedAt,targetCommitish,url,name
./scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.10
git diff --check
```

### 커밋

```
Task #159 Stage 4: upstream rhwp release check workflow 추가
```

## Stage 5 — 최종 검증과 보고서 정리

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `mydocs/report/task_m010_159_report.md` | 최종 결과 보고서 작성 | 실제 publish 제외 명시 |
| `mydocs/orders/20260506.md` | 작업 상태 완료 처리 | 최종 단계 |
| 필요 시 `mydocs/working/task_m010_159_stage5.md` | 최종 검증 단계 보고서 | 검증 명령 결과 |

### 최종 검증

```bash
cd /private/tmp/rhwp-mac-task159
git status --short --branch
git diff --check
ruby -e 'require "yaml"; Dir[".github/workflows/*.yml"].each { |f| YAML.load_file(f); puts f }'
./scripts/build-rust-macos.sh --verify-lock
./scripts/check-no-appkit.sh
./scripts/release.sh --help
env -u ALHANGEUL_DEVELOPER_ID_APPLICATION -u ALHANGEUL_NOTARY_PROFILE ./scripts/release.sh 0.1.0
gh release view -R edwardkim/rhwp --json tagName,publishedAt,targetCommitish,url,name
```

가능하고 별도 승인 또는 환경 가능 시 rehearsal workflow와 같은 경로를 로컬에서 검증한다.

```bash
./scripts/release.sh --skip-notarize 0.1.0
```

### 실제 실행 제외 확인

다음은 이 task 완료만으로 실행하지 않는다.

- public notarization submission
- GitHub Release publish
- Homebrew tap push 또는 PR 생성
- `v0.7.10` core bump
- secret 생성, export, 저장
- M16 문서와 release note 최종 문구 확정

### 커밋

```
Task #159 Stage 5 + 최종 보고서: release automation pipeline 정리
```

## 승인 요청 사항

이 구현 계획 기준으로 Stage 1 진행 승인을 요청한다.
