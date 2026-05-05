# Task #148 Stage 1 완료 보고서: 배포 자산과 credential 준비 상태 점검

## 단계 목적

현재 저장소의 DMG release pipeline, 개발용 package script, Homebrew Cask 초안, release guide, bundle/version/signing 설정을 점검하고 v0.1 public 배포를 `Developer ID signed + notarized DMG` 기준으로 진행할 수 있는 준비 상태인지 확인했다.

## 산출물

Stage 1은 조사 단계라 코드와 운영 문서 본문은 변경하지 않았다. 본 단계 산출물은 이 완료 보고서다.

점검한 주요 파일:

| 파일 | 라인 수 | 확인 요약 |
|------|--------:|-----------|
| `scripts/release.sh` | 422 | public/rehearsal DMG, Developer ID signing, app/DMG notarization, staple, Gatekeeper, sha256 흐름 확인 |
| `scripts/package-release.sh` | 58 | 개발·검증용 zip package와 public DMG 책임 분리 확인 |
| `Casks/alhangeul-macos.rb` | 15 | Cask token, version, GitHub Release DMG URL, app stanza, caveats 확인 |
| `mydocs/manual/release_distribution_guide.md` | 399 | release 권한 원칙, credential 상태, DMG/Homebrew/GitHub Release 기준 확인 |
| `project.yml` | 76 | bundle id, entitlements, Automatic signing 설정 확인 |
| `Sources/HostApp/Info.plist` | 176 | HostApp version/build/document type 확인 |
| `Sources/QLExtension/Info.plist` | 51 | Quick Look extension version/content type 확인 |
| `Sources/ThumbnailExtension/Info.plist` | 47 | Thumbnail extension version/content type 확인 |

## 본문 변경 정도 / 본문 무손실 여부

- 기존 소스와 운영 문서 본문은 변경하지 않았다.
- 조사 결과는 신규 단계 보고서에만 추가했다.
- 수행계획서와 구현계획서의 Stage 1 범위를 유지했다.

## 점검 결과

### Release pipeline

`scripts/release.sh --help` 확인 결과 public release 입력값과 rehearsal option이 문서와 일치했다.

```text
Usage: ./scripts/release.sh [options] <version>
--skip-notarize    Build a local rehearsal DMG without notarization or staple.
ALHANGEUL_DEVELOPER_ID_APPLICATION   Developer ID Application signing identity.
ALHANGEUL_NOTARY_PROFILE             notarytool keychain profile name.
ALHANGEUL_DEVELOPER_ID_DMG           Optional DMG signing identity. Defaults to app identity.
```

script 구조상 public mode는 다음 항목을 수행한다.

- Rust bridge lock verify
- `scripts/check-no-appkit.sh`
- `xcodegen generate`
- Release app build
- Developer ID Application signing identity 확인
- app notarization submit/wait와 staple
- DMG 생성, signing, notarization submit/wait와 staple
- `spctl` Gatekeeper 검증
- DMG sha256 파일 생성

rehearsal mode는 `alhangeul-macos-<version>-rehearsal.dmg`를 만들며, script와 문서 모두 public release/Homebrew Cask에 사용하지 말라고 경고한다.

### Credential 준비 상태

sandbox 안에서 실행한 keychain 확인은 다음처럼 제한을 받았다.

```text
security find-identity -v -p codesigning
0 valid identities found

xcrun notarytool history --keychain-profile "alhangeul-notary"
Error: An error occurred while accessing the keychain. One or more parameters passed to a function were not valid.
```

동일 명령을 keychain 접근 권한을 허용해 다시 실행하면 문서의 운영 값과 일치했다.

```text
security find-identity -v -p codesigning
Apple Development: meleehadmac@gmail.com (X2U3KJKF32)
Developer ID Application: Taegyu Lee (XH6JHKYXV8)
2 valid identities found

xcrun notarytool history --keychain-profile "alhangeul-notary"
No submission history.
```

따라서 Stage 1 기준으로 Developer ID Application identity와 `alhangeul-notary` keychain profile은 준비된 상태로 판단한다. `No submission history.`는 credential 실패가 아니라 아직 제출 이력이 없다는 상태다.

### Bundle, version, entitlement

`project.yml` 확인 결과 세 target은 모두 `com.postmelee.alhangeulmac` 계열 bundle id와 각 target별 entitlements를 사용한다.

- HostApp: `com.postmelee.alhangeulmac`, `Sources/HostApp/HostApp.entitlements`
- QLExtension: `com.postmelee.alhangeulmac.QLExtension`, `Sources/QLExtension/QLExtension.entitlements`
- ThumbnailExtension: `com.postmelee.alhangeulmac.ThumbnailExtension`, `Sources/ThumbnailExtension/ThumbnailExtension.entitlements`

세 `Info.plist`의 `CFBundleShortVersionString`은 모두 `0.1.0`이고, HostApp `CFBundleVersion`은 `1`이다.

entitlement 상태:

- HostApp: app sandbox, user-selected read-write, network client, print
- QLExtension: app sandbox, user-selected read-only
- ThumbnailExtension: app sandbox, user-selected read-only

Stage 1 조사만으로 notarization 차단 요인은 확인되지 않았다. 실제 판정은 public DMG build와 notarization submission 또는 signed rehearsal build에서 확정해야 한다.

### Homebrew Cask

현재 Cask는 public DMG URL 형식과 app stanza가 저장소 기준과 맞다.

```ruby
version "0.1.0"
sha256 :no_check
url "https://github.com/postmelee/alhangeul-macos/releases/download/v#{version}/alhangeul-macos-#{version}.dmg"
app "AlhangeulMac.app"
```

남은 gap:

- `sha256 :no_check`는 public DMG 생성 전 placeholder다.
- GitHub Release asset이 업로드되기 전에는 Cask가 실제 설치 경로로 동작한다고 볼 수 없다.
- Homebrew 배포 대상을 이 저장소의 `Casks/` 초안으로 유지할지, 별도 tap을 만들지, 장기적으로 `Homebrew/homebrew-cask` 제출을 목표로 둘지 Stage 3에서 작업지시자 확인이 필요하다.

### App Store 후속 경로

현재 Stage 1 범위에서는 App Store 제출용 archive/export 설정, App Store Connect metadata, review 대응 자료가 별도 lane으로 분리되어 있지 않다. Developer ID DMG/Homebrew 배포와 App Store 배포는 인증서, export method, sandbox/review 요구가 다르므로 Stage 4에서 후속 체크리스트로 분리하는 편이 맞다.

## 검증 결과

구현계획서 Stage 1 검증 명령을 실행했다.

```bash
rg --line-number 'Developer ID|notarytool|notarization|공증|Homebrew Cask|GitHub Release|sha256|App Store|rehearsal' \
  README.md mydocs/manual/release_distribution_guide.md scripts/release.sh Casks/alhangeul-macos.rb
```

결과: 관련 문구가 `scripts/release.sh`, `README.md`, `Casks/alhangeul-macos.rb`, `mydocs/manual/release_distribution_guide.md`에서 확인됐다.

```bash
./scripts/release.sh --help
```

결과: usage와 public release 환경변수, rehearsal option 확인.

```bash
security find-identity -v -p codesigning
xcrun notarytool history --keychain-profile "alhangeul-notary"
```

결과: sandbox 안에서는 keychain 접근 제한이 있었고, 권한 허용 후 Developer ID Application identity와 notarytool profile 확인 통과.

추가 점검:

```bash
plutil -extract CFBundleShortVersionString raw -o - Sources/HostApp/Info.plist
plutil -extract CFBundleShortVersionString raw -o - Sources/QLExtension/Info.plist
plutil -extract CFBundleShortVersionString raw -o - Sources/ThumbnailExtension/Info.plist
bash -n scripts/release.sh scripts/package-release.sh
git diff --check
```

결과: 세 target version은 모두 `0.1.0`, shell syntax 오류 없음, whitespace 오류 없음.

## 잔여 위험

- 실제 public notarization submission은 아직 실행하지 않았으므로 Apple notarization server의 최종 판정은 미확정이다.
- public DMG가 아직 생성되지 않아 Cask sha256을 확정할 수 없다.
- `scripts/release.sh` public mode는 clean worktree를 요구하므로 실제 release 실행 전 release 기준 commit과 포함 PR 확정이 필요하다.
- Homebrew tap 운영 방식은 아직 결정되지 않았다.
- App Store 배포는 별도 archive/export/review 준비가 필요하며 이번 Stage 1에서는 구조적 gap만 확인했다.

## 다음 단계 영향

Stage 2에서는 v0.1 배포 수준을 `Developer ID signed + notarized DMG`로 문서화하고, unsigned/ad-hoc/rehearsal artifact를 일반 사용자 배포 기준에서 제외하는 안내를 보강한다. Gatekeeper, quarantine, Quick Look/Thumbnail extension 등록 안내도 사용자 관점으로 정리한다.

Stage 3 진입 전 또는 진행 중에는 Homebrew tap 운영 방식을 작업지시자에게 확인해야 한다.

## 승인 요청

Stage 1을 완료했다. 이 보고서 기준으로 Stage 2 `v0.1 배포 수준과 사용자 안내 기준 확정`을 진행할지 승인 요청한다.
