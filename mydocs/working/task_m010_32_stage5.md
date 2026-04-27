# Task #32 Stage 5 완료 보고서

## 단계 목적

Apple Developer Program credential 없이 가능한 최종 검증을 수행한다. public signing/notarization은 실행하지 않고, script syntax, shellcheck, Cask syntax, public mode credential fail-fast, rehearsal DMG 생성, checksum 검증, bundle 구조 확인까지만 수행한다.

## 변경 파일

- `scripts/package-release.sh`
- `mydocs/orders/20260426.md`
- `mydocs/working/task_m010_32_stage5.md`

## 검증 중 보정

`shellcheck`가 `scripts/package-release.sh`의 `rm -rf` 경로에 SC2115 경고를 보고했다. 기존 동작을 바꾸지 않고 `${BUILD_DIR:?}` guard만 추가했다.

보정 전:

```bash
rm -rf "$BUILD_DIR/$BUILD_APP_NAME" "$BUILD_DIR/$BUILD_APP_NAME.dSYM"
rm -rf "$BUILD_DIR/$APP_NAME"
```

보정 후:

```bash
rm -rf "${BUILD_DIR:?}/$BUILD_APP_NAME" "${BUILD_DIR:?}/$BUILD_APP_NAME.dSYM"
rm -rf "${BUILD_DIR:?}/$APP_NAME"
```

## 정적 검증 결과

작업트리 기준:

```text
$ git status --short --branch
## local/task32
```

shell syntax:

```text
$ bash -n scripts/release.sh scripts/package-release.sh scripts/build-rust-macos.sh scripts/check-no-appkit.sh
결과: 통과
```

shellcheck:

```text
$ shellcheck scripts/release.sh scripts/package-release.sh scripts/build-rust-macos.sh scripts/check-no-appkit.sh
결과: 통과
```

Cask syntax:

```text
$ ruby -c Casks/alhangeul-macos.rb
Syntax OK
```

diff whitespace:

```text
$ git diff --check
결과: 통과
```

release help:

```text
$ ./scripts/release.sh --help
결과: Usage, options, public release environment 출력 확인
```

## Public Mode Credential Fail-fast

credential을 명시적으로 제거한 상태에서 public mode를 실행해 build 전에 실패하는지 확인했다.

```text
$ env -u ALHANGEUL_DEVELOPER_ID_APPLICATION -u ALHANGEUL_NOTARY_PROFILE ./scripts/release.sh 0.1.0
ERROR: ALHANGEUL_DEVELOPER_ID_APPLICATION is required for public release
```

결과:

- 기대한 오류로 실패했다.
- Rust build, Xcode build, notarization submit은 시작하지 않았다.

## Rehearsal DMG 검증

`hdiutil create`와 `hdiutil verify`는 disk image 접근이 필요하므로 sandbox 밖에서 실행했다.

```text
$ ./scripts/release.sh --skip-notarize 0.1.0
결과: 성공
```

확인된 단계:

- Rust bridge staticlib universal build 성공
- `Rhwp.xcframework` 생성 성공
- `rhwp-core.lock` verify 성공
- `scripts/check-no-appkit.sh` 성공
- `xcodegen generate` 성공
- Xcode Release build 성공
- unsigned rehearsal app 기준 code signing 검증 skip 경고 출력
- rehearsal DMG 생성 성공
- `hdiutil verify` 성공
- sha256 파일 생성 성공
- public release/Homebrew Cask에 사용하지 말라는 경고 출력

산출물:

```text
build.noindex/release/AlhangeulMac.app
build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg
build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg.sha256
```

checksum:

```text
0d292f78ea38a15fa59c07384a830d322b54df100644c874bf56384bae4696d0  alhangeul-macos-0.1.0-rehearsal.dmg
```

checksum 검증:

```text
$ shasum -a 256 -c alhangeul-macos-0.1.0-rehearsal.dmg.sha256
alhangeul-macos-0.1.0-rehearsal.dmg: OK
```

## Bundle 구조 확인

app bundle:

```text
build.noindex/release/AlhangeulMac.app
```

embedded app extensions:

```text
build.noindex/release/AlhangeulMac.app/Contents/PlugIns/AlhangeulMacPreview.appex
build.noindex/release/AlhangeulMac.app/Contents/PlugIns/AlhangeulMacThumbnail.appex
```

version 확인:

```text
HostApp: 0.1.0
QLExtension: 0.1.0
ThumbnailExtension: 0.1.0
```

## 검증하지 않은 항목

다음 항목은 Apple Developer Program credential이 없으므로 이번 단계에서 실행하지 않았다.

- Developer ID Application signing
- app notarization submit/wait
- app staple
- DMG signing
- DMG notarization submit/wait
- DMG staple
- public Gatekeeper assessment
- Homebrew Cask 실제 설치 검증
- GitHub Release asset upload

## 잔여 위험

- public mode signing 설정이 실제 Developer ID certificate 환경에서 embedded app extension까지 안정적으로 동작하는지는 credential 확보 후 검증해야 한다.
- rehearsal DMG는 unsigned 산출물이므로 public release나 Cask digest 기준으로 사용할 수 없다.
- Cask의 `sha256 :no_check`는 public signed/notarized DMG가 생성된 뒤 실제 digest로 교체해야 한다.

## 다음 단계

Stage 6에서는 최종 보고서를 작성하고 오늘할일을 완료 처리한 뒤, PR 준비 절차로 넘어간다.

## 승인 요청

Stage 5 검증을 완료했다. 이 보고서 기준으로 Stage 6 `최종 보고서 작성, 오늘할일 완료 처리, PR 준비`를 진행할지 승인 요청한다.
