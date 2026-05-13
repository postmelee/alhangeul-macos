# Task M019 #219 Stage 2 완료 보고서

## 단계 목적

Sparkle framework 내부 component signing 경로를 `Versions/B` 고정에서 `Versions/Current` 우선 + discovery fallback 방식으로 바꾸고, required nested component 누락을 public/signed path에서 조용히 skip하지 않도록 보강한다.

확인 시각: `2026-05-11 13:41 KST`

## 산출물

| 파일 | 내용 |
|------|------|
| `scripts/release.sh` | Sparkle required component 목록, version directory resolver, 누락 component report helper 추가. `sign_sparkle_components_for_notarization`이 resolver 기반 경로를 사용하도록 변경 |
| `mydocs/working/task_m019_219_stage2.md` | Stage 2 구현 결과와 검증 기록 |

## 본문 변경 정도 / 본문 무손실 여부

- Stage 2 범위에 맞춰 `scripts/release.sh`의 Sparkle signing path만 수정했다.
- signer, Team ID, timestamp, hardened runtime, entitlement parser는 아직 추가하지 않았다. 이 범위는 Stage 3으로 유지한다.
- workflow와 manual 본문은 수정하지 않았다.
- public release, Developer ID signing, notarization submit/wait, GitHub Release 게시, Pages/appcast 갱신은 실행하지 않았다.

## 변경 내용

### Required component 목록 중앙화

`sparkle_required_component_paths` helper를 추가해 Sparkle notarization signing 대상 nested component를 한 곳에서 관리한다.

현재 required component:

- `XPCServices/Downloader.xpc`
- `XPCServices/Installer.xpc`
- `Updater.app`
- `Autoupdate`

이 목록은 Stage 2부터 signing path에서 사용하고, Stage 3 validator에서도 같은 기준으로 재사용할 예정이다.

### Sparkle version directory resolution

새 resolver는 다음 순서로 version directory를 결정한다.

1. `Sparkle.framework`와 `Sparkle.framework/Versions` 존재 확인
2. `Versions/Current`가 directory 또는 symlink로 유효하면 물리 경로(`pwd -P`)로 해석
3. `Versions/Current`가 required component를 모두 포함하면 그 경로 사용
4. `Versions/Current`가 없거나 incomplete이면 `Versions/*`에서 `Current`를 제외하고 required component를 모두 포함한 directory 탐색
5. 끝까지 찾지 못하면 확인한 `Versions` 위치와 누락 component path를 stderr에 출력한 뒤 실패

`basename` 같은 추가 외부 tool 의존을 만들지 않기 위해 `Current` 제외는 shell parameter expansion(`${candidate##*/}`)으로 처리했다.

### Signing path 보강

기존 `sign_sparkle_components_for_notarization`은 `Sparkle.framework/Versions/B`를 직접 보고, version directory가 없으면 return하고, component가 없으면 해당 component만 skip했다.

변경 후에는 Developer ID signing path에서 다음처럼 동작한다.

- `resolve_sparkle_version_dir`로 version directory를 먼저 확정한다.
- Sparkle framework 또는 `Versions` directory가 없으면 실패한다.
- required nested component를 모두 갖춘 version directory가 없으면 실패한다.
- 확정된 version directory의 required component를 모두 `codesign_developer_id`로 서명한다.
- 마지막에 `Sparkle.framework`를 재서명한다.

이제 public/signed path에서 Sparkle required component가 누락된 상태로 notary submit까지 진행하지 않는다.

## Stage 1 기준 대비 결과

| Stage 1 기준 | 결과 |
|--------------|------|
| `Sparkle.framework` 존재 확인 helper 추가 | OK. resolver에서 framework와 `Versions` directory를 확인 |
| `Versions/Current` symlink/dir 해석 helper 추가 | OK. `resolve_sparkle_current_version_dir` 추가 |
| `Versions/Current`가 없거나 유효하지 않으면 `Versions/*` discovery | OK. `Current` 제외 후 required component 보유 directory 탐색 |
| required component 목록 중앙화 | OK. `sparkle_required_component_paths` 추가 |
| `sign_sparkle_components_for_notarization`이 새 resolver 사용 | OK. `Versions/B` 고정 제거 |
| public/signed path에서 required component 누락 시 `fail` | OK. resolver가 누락 component report 후 실패 |
| unsigned path에서는 signing helper가 실행되지 않음 | OK. 기존 `DEVELOPER_ID_APPLICATION` empty guard 유지 |

## 검증 결과

| 명령 | 결과 | 비고 |
|------|------|------|
| `git status -sb` | OK | `local/task219`, `origin/devel-webview` 대비 ahead 3에서 시작 |
| `bash -n scripts/release.sh` | OK | shell syntax 통과 |
| `./scripts/release.sh --help` | OK | release script interface 출력 정상 |
| `rg -n "resolve_sparkle\|Sparkle.framework/Versions\|XPCServices\|Updater.app\|Autoupdate\|Versions/Current" scripts/release.sh` | OK | resolver와 required component 목록 확인 |
| `git diff -- scripts/release.sh` | OK | 변경 범위가 Sparkle resolver/signing path에 한정됨 |

## 실행하지 않은 항목

- `./scripts/release.sh --skip-notarize` 실행
- Developer ID signing
- notarization submit/wait
- signer, Team ID, timestamp, hardened runtime, entitlement validation 구현
- workflow summary 수정
- manual 수정

## 잔여 위험

- Stage 2는 path discovery와 required component fail-fast만 다룬다. 실제 signer, timestamp, hardened runtime, `get-task-allow` 검증은 아직 `codesign --verify` 수준을 넘어서지 않는다.
- Sparkle future version에서 required component 이름이 바뀌면 current policy가 실패한다. 이는 의도된 fail-fast이며, public release 전 Sparkle 구조 변경을 명시 검토해야 한다.
- 실제 signed app bundle에서 resolver가 어떤 directory를 선택하는지는 Stage 3/5에서 release rehearsal 또는 signed path 실행 결과로 확인해야 한다.

## 다음 단계

Stage 3 승인 후 다음을 수행한다.

1. app notarization 제출 전 실행되는 `verify_release_signing_preflight` 계열 함수를 추가한다.
2. Host app, Quick Look extension, Thumbnail extension, Sparkle framework/nested component에 대해 개별 `codesign --verify --strict`를 수행한다.
3. Developer ID signer, Team ID, timestamp, hardened runtime, `get-task-allow` 부재 검증을 추가한다.
4. 실패 로그가 component label/path/기대 조건을 보여주도록 정리한다.

## 승인 요청

1. Stage 2 결과 승인
2. Stage 3 `artifact signing preflight validator 구현` 진입 승인
