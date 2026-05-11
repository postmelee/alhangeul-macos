# Task M019 #219 Stage 3 완료 보고서

## 단계 목적

app notarization 제출 전에 실행되는 artifact signing preflight validator를 `scripts/release.sh`에 추가한다. Host app, Quick Look extension, Thumbnail extension, Sparkle framework, Sparkle nested component의 code signature metadata를 명시 확인해 notary submit 이후에야 발견되던 signing/notarization prerequisite 문제를 fail-fast로 잡는다.

확인 시각: `2026-05-11 13:45 KST`

## 산출물

| 파일 | 내용 |
|------|------|
| `scripts/release.sh` | release signing preflight helper와 main hook 추가 |
| `mydocs/working/task_m019_219_stage3.md` | Stage 3 구현 결과와 검증 기록 |

## 본문 변경 정도 / 본문 무손실 여부

- `scripts/release.sh`에 artifact signing preflight 함수와 main flow hook을 추가했다.
- Stage 2에서 추가한 Sparkle component resolver를 validator에서도 재사용했다.
- workflow와 manual 본문은 수정하지 않았다. 해당 정리는 Stage 4 범위다.
- public release, Developer ID signing, notarization submit/wait, GitHub Release 게시, Pages/appcast 갱신은 실행하지 않았다.

## 변경 내용

### Team ID 입력

`APPLE_TEAM_ID`를 release signing preflight의 expected Team ID로 사용한다.

- 기본값: `XH6JHKYXV8`
- override: workflow/local 환경에서 `APPLE_TEAM_ID`를 지정하면 해당 값을 사용
- `./scripts/release.sh --help`의 public release environment 섹션에 `APPLE_TEAM_ID`를 추가했다.

### Bundle identifier 검증

`verify_bundle_identifier` helper를 추가했다.

검증 대상:

- Host app: `com.postmelee.alhangeul`
- Quick Look extension: `com.postmelee.alhangeul.QLExtension`
- Thumbnail extension: `com.postmelee.alhangeul.ThumbnailExtension`

Sparkle framework와 nested executable은 bundle id policy를 강제하지 않는다.

### `get-task-allow` 검증

`verify_no_get_task_allow` helper를 추가했다.

`codesign --display --entitlements :-` 결과에서 `com.apple.security.get-task-allow`가 true이면 release signing preflight가 실패한다. entitlement가 없거나 key가 없으면 이 조건은 통과한다.

### Component signature 검증

`verify_release_component_signature` helper를 추가했다. 각 component에 대해 다음을 확인한다.

- component path 존재
- `codesign --verify --strict --verbose=2` 통과
- expected bundle id가 있는 경우 `CFBundleIdentifier` 일치
- Developer ID Application authority
- `TeamIdentifier=$APPLE_TEAM_ID`
- secure timestamp 존재, `Timestamp=none` 아님
- hardened runtime 존재 (`Runtime Version=` 또는 codesign flags의 `runtime`)
- `get-task-allow` true 아님

실패 메시지는 component label, path, 기대 조건을 포함한다.

### Release signing preflight hook

`verify_release_signing_preflight` helper를 추가하고 main flow에서 `verify_app_signature` 이후, `notarize_and_staple_app` 이전에 호출했다.

검증 대상:

- `Alhangeul.app`
- `AlhangeulPreview.appex`
- `AlhangeulThumbnail.appex`
- `Sparkle.framework`
- `Sparkle.framework` resolved version directory의 required nested components
  - `XPCServices/Downloader.xpc`
  - `XPCServices/Installer.xpc`
  - `Updater.app`
  - `Autoupdate`

`ALHANGEUL_DEVELOPER_ID_APPLICATION`이 없는 unsigned rehearsal에서는 preflight를 실행하지 않고 명시 warning을 출력한다. public mode는 `run_preflight`에서 Developer ID identity가 필수이므로, app notarization submit 전 이 validator가 반드시 실행된다.

## Stage 3 기준 대비 결과

| 구현계획 기준 | 결과 |
|---------------|------|
| app notarization 제출 전 `verify_release_signing_preflight` 추가 | OK. main flow에서 `verify_app_signature`와 `notarize_and_staple_app` 사이에 호출 |
| Host/Quick Look/Thumbnail/Sparkle component 개별 `codesign --verify --strict` | OK. `verify_release_component_signature`에서 실행 |
| Developer ID Application signer 확인 | OK. authority 검사 추가 |
| Team ID 확인 | OK. `TeamIdentifier=$APPLE_TEAM_ID` 검사 추가 |
| secure timestamp 확인 | OK. `Timestamp=` 존재와 `Timestamp=none` 부재 확인 |
| hardened runtime 확인 | OK. `Runtime Version=` 또는 `flags=.*runtime` 확인 |
| `get-task-allow` true 실패 | OK. entitlement output 검사 추가 |
| 실패 로그에 label/path/기대 조건 포함 | OK. `signing preflight failed for {label}: ... at {path}` 형식 |

## 검증 결과

| 명령 | 결과 | 비고 |
|------|------|------|
| `git status -sb` | OK | `local/task219`, `origin/devel-webview` 대비 ahead 4에서 시작 |
| `bash -n scripts/release.sh` | OK | shell syntax 통과 |
| `./scripts/release.sh --help` | OK | `APPLE_TEAM_ID` help와 기존 interface 확인 |
| `rg -n "verify_release_signing_preflight\|codesign --display\|entitlements\|get-task-allow\|hardened runtime\|TeamIdentifier\|Timestamp\|APPLE_TEAM_ID" scripts/release.sh` | OK | Stage 3 validator hook과 검사 조건 확인 |
| `git diff -- scripts/release.sh` | OK | 변경 범위 확인 |

## 실행하지 않은 항목

- `./scripts/release.sh --skip-notarize` 실행
- Developer ID signing
- signed rehearsal
- notarization submit/wait
- workflow summary 수정
- manual 수정
- public release 관련 외부 작업

`--skip-notarize` release build는 Stage 5 통합 검증에서 수행 후보로 유지한다. 이번 Stage 3에서는 shell syntax와 script interface, hook/condition 검색으로 implementation-level 검증을 완료했다.

## 잔여 위험

- 실제 signed app bundle에서 `codesign --display --verbose=4` 출력이 예상과 다를 가능성은 남아 있다. Stage 5 또는 release 환경에서 signed path 실행 결과를 확인해야 한다.
- `codesign --display --entitlements :-` output format이 바뀌면 `get-task-allow` grep이 false negative를 낼 수 있다. 현재 macOS plist XML output 기준으로 검사한다.
- Sparkle future version에서 required nested component 구성이 바뀌면 Stage 2 resolver와 Stage 3 validator 모두 실패한다. 이는 public release 전 구조 변경을 드러내기 위한 fail-fast 동작이다.

## 다음 단계

Stage 4 승인 후 다음을 수행한다.

1. `release-publish.yml`과 `release-rehearsal.yml` summary에 signing preflight 실행/skip 기준을 반영한다.
2. release signing/notarization, packaging, distribution 문서에 preflight gate 위치와 실패 기준을 기록한다.
3. #225 release 실행 전 확인해야 하는 preflight 기준을 문서에 남긴다.

## 승인 요청

1. Stage 3 결과 승인
2. Stage 4 `workflow와 release 문서 연결` 진입 승인
