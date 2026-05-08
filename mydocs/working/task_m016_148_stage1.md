# Task #148 Stage 1 완료 보고서: 배포 자산과 credential 준비 상태 점검

## 단계 목적

현재 저장소의 DMG release pipeline, 개발용 package script, Homebrew Cask 초안, release guide, bundle/version/signing 설정을 점검하고 v0.1 public 배포를 `Developer ID signed + notarized DMG` 기준으로 진행할 수 있는 준비 상태인지 확인했다.

이 보고서는 기존 `task_m010_148_stage1.md`를 2026-05-08 현재 M016 기준으로 이관한 것이다.

## 산출물

Stage 1은 조사 단계라 코드와 운영 문서 본문은 변경하지 않았다. 본 단계 산출물은 이 완료 보고서다.

점검한 주요 파일:

| 파일 | 확인 요약 |
|------|-----------|
| `scripts/release.sh` | public/rehearsal DMG, Developer ID signing, app/DMG notarization, staple, Gatekeeper, sha256 흐름 확인 |
| `scripts/package-release.sh` | 개발·검증용 zip package와 public DMG 책임 분리 확인 |
| `Casks/alhangeul-macos.rb` | Cask token, version, GitHub Release DMG URL, `Alhangeul.app` app stanza, caveats 확인 |
| `mydocs/manual/release_distribution_guide.md` | release 권한 원칙, credential 상태, DMG/Homebrew/GitHub Release 기준 확인 |
| `project.yml` | bundle id, entitlements, signing 설정 확인 |
| `Sources/HostApp/Info.plist` | HostApp version/build/document type 확인 |
| `Sources/QLExtension/Info.plist` | Quick Look extension version/content type 확인 |
| `Sources/ThumbnailExtension/Info.plist` | Thumbnail extension version/content type 확인 |

## 점검 결과

### Release pipeline

`scripts/release.sh --help` 확인 결과 public release 입력값과 rehearsal option이 문서와 일치했다.

```text
--skip-notarize    Build a local rehearsal DMG without notarization or staple.
ALHANGEUL_DEVELOPER_ID_APPLICATION   Developer ID Application signing identity.
ALHANGEUL_NOTARY_PROFILE             notarytool keychain profile name.
ALHANGEUL_DEVELOPER_ID_DMG           Optional DMG signing identity. Defaults to app identity.
```

public mode는 Rust bridge lock verify, shared Swift boundary check, Release build, Developer ID signing, app/DMG notarization, staple, Gatekeeper 검증, DMG sha256 파일 생성을 수행한다.

rehearsal mode는 `alhangeul-macos-<version>-rehearsal.dmg`를 만들며, public release/Homebrew Cask 기준으로 사용하지 않는다.

### Credential 준비 상태

sandbox 안에서 keychain 확인 명령은 접근 제한을 받았지만, 권한 허용 후 문서의 운영 값과 일치했다.

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

세 target은 모두 `com.postmelee.alhangeul` 계열 bundle id와 각 target별 entitlements를 사용한다.

- HostApp: app sandbox, user-selected read-write, network client, print
- QLExtension: app sandbox, user-selected read-only
- ThumbnailExtension: app sandbox, user-selected read-only

Stage 1 조사만으로 notarization 차단 요인은 확인되지 않았다. 실제 판정은 public DMG build와 notarization submission에서 확정해야 한다.

### Homebrew Cask

현재 Cask는 public DMG URL 형식과 app stanza가 저장소 기준과 맞다.

```ruby
version "0.1.0"
sha256 :no_check
url "https://github.com/postmelee/alhangeul-macos/releases/download/v#{version}/alhangeul-macos-#{version}.dmg"
app "Alhangeul.app"
```

남은 gap:

- `sha256 :no_check`는 public DMG 생성 전 placeholder다.
- GitHub Release asset이 업로드되기 전에는 Cask가 실제 설치 경로로 동작한다고 볼 수 없다.
- Homebrew tap 운영 방식은 #148에서 확정하지 않고 release 실행 시점의 별도 승인 사항으로 남긴다.

## 검증 결과

실행 또는 확인한 명령:

```bash
rg --line-number 'Developer ID|notarytool|notarization|공증|Homebrew Cask|GitHub Release|sha256|App Store|rehearsal' \
  README.md mydocs/manual/release_distribution_guide.md scripts/release.sh Casks/alhangeul-macos.rb
./scripts/release.sh --help
security find-identity -v -p codesigning
xcrun notarytool history --keychain-profile "alhangeul-notary"
plutil -extract CFBundleShortVersionString raw -o - Sources/HostApp/Info.plist
plutil -extract CFBundleShortVersionString raw -o - Sources/QLExtension/Info.plist
plutil -extract CFBundleShortVersionString raw -o - Sources/ThumbnailExtension/Info.plist
bash -n scripts/release.sh scripts/package-release.sh
git diff --check
```

결과: release script help, signing/notary credential 확인, shell syntax, whitespace 점검을 통과했다. keychain 확인은 sandbox 접근 제한 때문에 권한 허용 후 재실행했다.

## 잔여 위험

- 실제 public notarization submission은 아직 실행하지 않았으므로 Apple notarization server의 최종 판정은 미확정이다.
- public DMG가 아직 생성되지 않아 Cask sha256을 확정할 수 없다.
- `scripts/release.sh` public mode는 clean worktree를 요구하므로 실제 release 실행 전 release 기준 commit과 포함 PR 확정이 필요하다.

## 다음 단계 영향

Stage 2에서는 v0.1 배포 수준을 `Developer ID signed + notarized DMG`로 문서화하고, unsigned/ad-hoc/rehearsal artifact를 일반 사용자 배포 기준에서 제외하는 안내를 보강한다.
