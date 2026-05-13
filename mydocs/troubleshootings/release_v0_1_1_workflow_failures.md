# v0.1.1 release workflow 실패 사례 troubleshooting

## 목적

`v0.1.1` public release 실행 중 발생한 GitHub Actions, Developer ID signing, notarization, Sparkle nested signing, Rust bridge 검증 실패를 장기 운영자가 재사용할 수 있는 진단 문서로 정리한다.

이 문서는 `#188` Stage 4 보고서의 사건 기록을 운영 절차로 재구성한 것이다. release script나 workflow의 현재 구현이 바뀌어도, 같은 계열의 실패가 다시 발생하면 증상, 재현 조건, 원인, 수정, 예방책 순서로 먼저 대조한다.

## 대상 release와 참조 자료

| 항목 | 값 |
|------|----|
| 관련 이슈 | [#188](https://github.com/postmelee/alhangeul-macos/issues/188), [#218](https://github.com/postmelee/alhangeul-macos/issues/218) |
| 원본 stage report | `mydocs/working/task_m018_188_stage4.md` |
| 최종 report | `mydocs/report/task_m018_188_report.md` |
| 초기 public success run | `25633522344` |
| 최종 public release run | `25645869039` |
| 최종 public release | `v0.1.1` build `4` |

기록하지 않는 값:

- Apple ID password
- app-specific password
- App Store Connect API private key
- exported signing identity `.p12` payload와 password
- Keychain credential payload
- Sparkle EdDSA private key
- GitHub token 값
- notarization credential 원문

문서에는 workflow variable/secret 이름, run 번호, 실패 step 이름, public run URL, script/function 이름만 기록한다.

## 전체 실패 흐름

| run | 실패 지점 | 대표 증상 | 적용된 보정 |
|-----|-----------|-----------|-------------|
| [`25632437884`](https://github.com/postmelee/alhangeul-macos/actions/runs/25632437884) | upstream latest rhwp release 확인 | `gh` 인증 실패 | release workflow에 `GH_TOKEN: ${{ github.token }}` 복구 |
| [`25632495693`](https://github.com/postmelee/alhangeul-macos/actions/runs/25632495693) | Developer ID certificate import | `$GITHUB_OUTPUT` format 오류 | helper stdout에는 keychain path만 남기고 `security` 출력은 stderr로 이동 |
| [`25632545387`](https://github.com/postmelee/alhangeul-macos/actions/runs/25632545387) | rhwp lock verify | runner에 `cbindgen` 없음 | release/rehearsal workflow에서 필요 시 `brew install cbindgen` |
| [`25632598126`](https://github.com/postmelee/alhangeul-macos/actions/runs/25632598126) | rhwp staticlib hash verify | `librhwp.a` hash/size mismatch | CI에서는 staticlib byte hash만 제한적으로 skip |
| [`25632780594`](https://github.com/postmelee/alhangeul-macos/actions/runs/25632780594) | app notarization | notary status `Invalid`, 상세 log 부족 | notary JSON status 파싱과 submission log 출력 |
| [`25633064531`](https://github.com/postmelee/alhangeul-macos/actions/runs/25633064531) | app notarization | Sparkle nested component signature/timestamp 문제 | Sparkle nested component Developer ID/timestamp signing |
| [`25633267598`](https://github.com/postmelee/alhangeul-macos/actions/runs/25633267598) | app notarization | Quick Look/Thumbnail extension entitlement/timestamp 문제 | app extension 배포용 entitlements 재서명 |
| [`25633522344`](https://github.com/postmelee/alhangeul-macos/actions/runs/25633522344) | 없음 | initial public workflow 성공 | `v0.1.1` build `2` 게시 |

## 1. `GH_TOKEN` 누락으로 `gh` 인증 실패

### 증상

`Release Publish DMG` workflow의 upstream latest `rhwp` release 확인 단계에서 `gh` 명령이 인증 실패로 중단된다.

대표 판단:

- 실패 run: `25632437884`
- 실패 지점: upstream latest `rhwp` release 확인
- 관련 workflow: `.github/workflows/release-publish.yml`

### 재현 조건

GitHub Actions workflow에서 `gh` CLI를 사용하지만 job 또는 step 환경에 `GH_TOKEN`이 설정되어 있지 않다. `github.token`은 자동으로 모든 subprocess에 전달되는 값이 아니므로, `gh`가 읽을 환경 변수로 명시해야 한다.

### 원인

release workflow에서 `GH_TOKEN`을 제거하면서 `gh` 인증 기반 조회가 실패했다. upstream release guard는 public API처럼 보이더라도 `gh` CLI 실행 경로에서는 인증 환경을 요구한다.

### 수정

release publish workflow env에 다음 값을 복구했다.

```yaml
GH_TOKEN: ${{ github.token }}
```

### 예방책

- workflow에서 `gh` CLI를 쓰는 step은 `GH_TOKEN` 전달 여부를 확인한다.
- token 값을 로그나 문서에 기록하지 않는다.
- workflow 변경 후에는 `rg -n "GH_TOKEN|gh " .github/workflows`로 인증 사용 지점을 함께 점검한다.

## 2. certificate import helper stdout 오염

### 증상

Developer ID certificate import step에서 `$GITHUB_OUTPUT` format 오류가 발생한다.

대표 판단:

- 실패 run: `25632495693`
- 실패 지점: Developer ID certificate import
- 관련 helper: `scripts/ci/import-developer-id-certificate.sh`

### 재현 조건

workflow step이 helper stdout을 command substitution으로 받아 `GITHUB_OUTPUT`에 쓰는데, helper stdout에 keychain path 외의 `security` command 출력이 섞인다.

### 원인

GitHub Actions output file은 `key=value` 형식 또는 heredoc 형식을 기대한다. keychain path 하나만 받아야 하는 흐름에 `security create-keychain`, `security import`, `security list-keychains` 같은 command output이 stdout으로 섞이면 output parser가 실패한다.

### 수정

helper는 `security` 출력과 진단 메시지를 stderr로 보내고, stdout에는 keychain path만 남기도록 보정했다.

현재 기준:

- required env: `DEVELOPER_ID_APPLICATION_P12_BASE64`, `DEVELOPER_ID_APPLICATION_P12_PASSWORD`, `RELEASE_KEYCHAIN_PASSWORD`
- stdout: temporary keychain path
- stderr: `security` command output

### 예방책

- GitHub Actions output으로 사용할 값은 stdout에 단일 값만 남긴다.
- 진단 출력은 stderr로 보낸다.
- helper 변경 후에는 workflow step의 command substitution 사용 여부를 확인한다.
- `.p12` payload, password, keychain credential 값은 문서와 로그에 남기지 않는다.

## 3. runner에 `cbindgen` 없음

### 증상

`./scripts/build-rust-macos.sh --verify-lock` 실행 중 `cbindgen` command가 없어 rhwp lock verify가 실패한다.

대표 판단:

- 실패 run: `25632545387`
- 실패 지점: rhwp lock verify
- 관련 script: `scripts/build-rust-macos.sh`

### 재현 조건

GitHub-hosted macOS runner에 Rust toolchain은 있지만 `cbindgen`이 사전 설치되어 있지 않다. `build-rust-macos.sh`는 generated header와 FFI symbol snapshot을 검증하기 위해 `cbindgen`을 필수 도구로 요구한다.

### 원인

release workflow가 local 개발 환경의 `cbindgen` 설치 상태를 runner에도 있다고 가정했다. 하지만 GitHub-hosted runner image에는 해당 도구가 없을 수 있다.

### 수정

release/rehearsal workflow에서 `cbindgen`이 없으면 설치하도록 보정했다.

대표 흐름:

```bash
if ! command -v cbindgen >/dev/null 2>&1; then
  brew install cbindgen
fi
```

### 예방책

- `scripts/build-rust-macos.sh`의 `require_tool` 목록을 workflow 준비 step과 함께 점검한다.
- runner image 업데이트 이후에도 `cbindgen` presence를 가정하지 않는다.
- dependency 설치 step은 release publish와 rehearsal 양쪽에 함께 반영한다.

## 4. `librhwp.a` staticlib byte hash mismatch

### 증상

`Frameworks/universal/librhwp.a`의 sha256 또는 size가 `rhwp-core.lock`에 기록된 값과 달라져 `--verify-lock`이 실패한다.

대표 판단:

- 실패 run: `25632598126`
- 실패 지점: rhwp staticlib hash verify
- 관련 artifact: `Frameworks/universal/librhwp.a`
- 관련 env: `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY`

### 재현 조건

같은 `rhwp` source commit과 같은 RustBridge source를 사용해도 GitHub macOS runner, Rust compiler, Xcode/linker/ar, build path, dependency build 환경 차이로 static archive byte layout이 달라진다.

### 원인

`rhwp-core.lock`은 staticlib artifact의 byte hash/size까지 기록하고 있었다. 그러나 CI runner/toolchain 차이에서 `librhwp.a`의 byte-for-byte reproducibility가 안정적으로 보장되지 않았다.

### 수정

`#188`에서는 release를 진행하기 위한 제한적 예외로 staticlib byte hash/size 검증만 건너뛰었다.

유지한 검증:

- `rhwp` source lock
- `Cargo.lock`의 resolved commit
- generated header
- FFI symbol snapshot

적용된 환경 변수:

```bash
ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1
```

`scripts/build-rust-macos.sh`는 해당 env가 `1`일 때 `Frameworks/universal/librhwp.a` byte hash만 skip하고, 경고와 함께 다른 검증은 유지한다.

### 예방책

- 이 env는 전체 rhwp 검증 skip이 아니다. staticlib byte hash에만 적용한다.
- release 판단에서 이 예외를 쓰면 report에 이유와 유지된 검증 범위를 기록한다.
- 장기 정책은 [#220](https://github.com/postmelee/alhangeul-macos/issues/220)과 [#227](https://github.com/postmelee/alhangeul-macos/issues/227)의 결론을 따른다.
- core/FFI/ABI 변경이 있는 PR에서는 generated header와 `rhwp-ffi-symbols.txt` 검증 결과를 반드시 확인한다.

## 5. notarization invalid 후 log 부족

### 증상

notary submit 결과가 `Invalid`인데 상세 notarization log 없이 이후 단계로 진행하거나 stapling 단계에서 실패한다.

대표 판단:

- 실패 run: `25632780594`
- 실패 지점: app notarization
- 관련 script: `scripts/release.sh`
- 관련 function: `submit_for_notarization`, `print_notary_log`

### 재현 조건

`xcrun notarytool submit --wait --output-format json` 실행 결과를 제출 성공 여부만으로 판단하고, JSON의 `status`가 `Accepted`인지 별도로 확인하지 않는다. submission id가 있는데도 `notarytool log`를 출력하지 않으면 원인 진단이 늦어진다.

### 원인

notary command exit code와 notarization status를 분리해 처리하지 않았고, rejection/invalid 상태에서 notary log를 가져오는 진단 경로가 부족했다.

### 수정

`scripts/release.sh`에서 다음을 보강했다.

- notary result JSON에서 `id`와 `status` 추출
- status가 `Accepted`가 아니면 JSON 출력
- submission id가 있으면 `xcrun notarytool log` 출력
- app bundle과 DMG notarization에 같은 helper 사용

### 예방책

- notary submit은 command success와 `status=Accepted`를 모두 확인한다.
- `Invalid` 또는 `Rejected`면 stapling 전에 실패시킨다.
- release report에는 command, 대상 artifact, status, log 요약을 기록하되 credential 원문은 기록하지 않는다.

## 6. Sparkle nested component signing/timestamp 누락

### 증상

app notarization이 Sparkle nested XPC/Updater/Autoupdate 서명 문제로 실패한다.

대표 판단:

- 실패 run: `25633064531`
- 실패 지점: app notarization
- 관련 framework: `Sparkle.framework`
- 관련 function: `sign_sparkle_components_for_notarization`

### 재현 조건

App bundle 안에 포함된 Sparkle framework의 nested component가 ad-hoc signature 상태이거나 Developer ID timestamp가 없는 상태로 notarization에 제출된다.

주요 대상:

- `Sparkle.framework/Versions/B/XPCServices/Downloader.xpc`
- `Sparkle.framework/Versions/B/XPCServices/Installer.xpc`
- `Sparkle.framework/Versions/B/Updater.app`
- `Sparkle.framework/Versions/B/Autoupdate`

### 원인

Host app 자체만 Developer ID로 서명해도 nested component가 notarization 요구조건을 만족한다는 보장은 없다. Sparkle framework 내부 실행 구성요소는 별도로 서명 상태를 확인해야 한다.

### 수정

`scripts/release.sh`가 Sparkle nested component를 Developer ID/timestamp로 재서명한 뒤 Sparkle framework와 app bundle을 다시 seal하도록 보정했다.

### 예방책

- Sparkle 버전 업데이트 후 framework 내부 version directory와 nested component 경로를 재확인한다.
- notary preflight가 도입되면 nested component 서명, timestamp, hardened runtime 상태를 제출 전에 fail-fast로 확인한다.
- Sparkle framework 내부 경로가 `Versions/B`에 고정되어 있는 점은 [#219](https://github.com/postmelee/alhangeul-macos/issues/219)에서 discovery 기반 처리로 개선할 후보다.

## 7. Quick Look/Thumbnail extension entitlement/timestamp 문제

### 증상

app notarization이 Quick Look 또는 Thumbnail extension의 entitlement/timestamp 문제로 실패한다.

대표 판단:

- 실패 run: `25633267598`
- 실패 지점: app notarization
- 관련 bundles: `AlhangeulPreview.appex`, `AlhangeulThumbnail.appex`
- 대표 문제: `get-task-allow`, timestamp 없음
- 관련 function: `sign_app_extension_for_notarization`

### 재현 조건

Release app bundle에 포함된 app extension이 debug entitlement를 유지하거나, Developer ID timestamp가 없는 signature 상태로 notarization에 제출된다.

### 원인

App extension은 host app과 별도 bundle이므로 release용 entitlements로 별도 서명해야 한다. Debug build 또는 개발용 signing metadata가 보존되면 notarization 요구조건과 충돌할 수 있다.

### 수정

`scripts/release.sh`에서 Quick Look/Thumbnail extension을 배포용 entitlements로 재서명하도록 보정했다.

현재 기준:

- `Sources/QLExtension/QLExtension.entitlements`
- `Sources/ThumbnailExtension/ThumbnailExtension.entitlements`
- bundle id placeholder는 release signing 시 실제 bundle id로 확장
- extension 재서명 후 host app bundle 재서명

### 예방책

- release artifact에는 `get-task-allow`가 남아 있으면 안 된다.
- `codesign --verify --strict`로 extension bundle 단독 검증을 수행한다.
- notarization submit 전 preflight validator가 도입되면 host app, extension, Sparkle nested executable을 모두 확인한다. 이 개선은 [#219](https://github.com/postmelee/alhangeul-macos/issues/219) 범위다.

## 다음 release 전 checklist

- [ ] `gh` CLI를 사용하는 workflow step에 `GH_TOKEN`이 전달되는지 확인
- [ ] certificate import helper stdout에 GitHub Actions output으로 사용할 값만 남는지 확인
- [ ] release/rehearsal/PR CI runner에서 `cbindgen` 설치 또는 presence 확인
- [ ] `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1` 사용 여부와 사용 이유를 release report에 기록
- [ ] staticlib hash skip을 써도 source lock, Cargo lock, generated header, FFI symbol 검증은 유지되는지 확인
- [ ] notary submit result JSON의 `status`가 `Accepted`인지 확인
- [ ] notarization 실패 시 submission id로 `notarytool log`를 출력하는지 확인
- [ ] Sparkle nested XPC/Updater/Autoupdate가 Developer ID/timestamp로 서명되는지 확인
- [ ] Quick Look/Thumbnail extension에 `get-task-allow`가 남지 않는지 확인
- [ ] app extension 단독 `codesign --verify --strict` 검증을 수행

## 후속 이슈

| 이슈 | 연결 이유 |
|------|-----------|
| [#219](https://github.com/postmelee/alhangeul-macos/issues/219) | signing/notarization preflight validator로 Sparkle nested component, app extension entitlement, timestamp 문제를 제출 전에 fail-fast 처리 |
| [#220](https://github.com/postmelee/alhangeul-macos/issues/220) | Rust staticlib hash 재현성 검증 정책과 skip 허용 조건 정리 |
| [#227](https://github.com/postmelee/alhangeul-macos/issues/227) | Rust bridge staticlib artifact 검증 정책과 PR CI/release workflow 보장 범위 재정의 |

## 적용하지 않은 범위

- release script 기능 변경
- release workflow YAML 변경
- notarization submit 또는 signing 실행
- GitHub Release 게시
- Pages deployment
- Homebrew tap 배포
- staticlib hash 장기 정책 확정

이 문서는 `#188`에서 실제 발생한 release workflow 실패를 진단하기 위한 기록이다. 장기 정책 또는 자동 preflight 구현은 후속 이슈에서 다룬다.
