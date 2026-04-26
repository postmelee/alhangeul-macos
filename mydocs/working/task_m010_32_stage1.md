# Task #32 Stage 1 완료 보고서

## 단계 목적

현재 packaging/release 문서, script, Cask, signing 설정을 조사해 signed release pipeline 설계 범위를 확정한다. 이번 단계에서는 release script, package script, release guide, Cask, README 본문을 구현 목적으로 수정하지 않는다.

## 조사 대상

- `scripts/package-release.sh`
- `scripts/release.sh` 존재 여부
- `Casks/alhangeul-macos.rb`
- `mydocs/manual/release_distribution_guide.md`
- `mydocs/manual/build_run_guide.md`
- `README.md`
- `project.yml`
- `Sources/*/*.entitlements`
- `Sources/*/Info.plist`
- `Sources/*/Resources/*/InfoPlist.strings`
- `.github/`

## 현재 script 상태

### `scripts/package-release.sh`

현재 개발/검증용 package script로 동작한다.

수행 흐름:

1. version 인자 1개를 요구한다.
2. `ALHANGEUL_BUILD_ROOT`가 없으면 `build.noindex`를 build root로 사용한다.
3. `build.noindex/release` 아래 staging을 준비한다.
4. `./scripts/build-rust-macos.sh --verify-lock`을 실행한다.
5. `xcodegen generate`를 실행한다.
6. `xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Release`를 실행한다.
7. build 산출물 `AlhangeulMac.app`을 release staging으로 복사한다.
8. `alhangeul-macos-<version>.zip`을 생성한다.
9. `shasum -a 256`으로 zip checksum을 출력한다.

현재 하지 않는 일:

- Developer ID signing identity 요구
- notarization credential preflight
- `codesign` 수동 검증
- app notarization submit/wait
- app staple
- DMG 생성
- DMG 서명
- DMG notarization submit/wait
- DMG staple
- `spctl` Gatekeeper 검증

현재 script는 `CODE_SIGNING_ALLOWED=NO`를 명시하지 않는다. `project.yml`은 `CODE_SIGN_STYLE: Automatic`을 사용하므로, Release build의 실제 signing 동작은 로컬 Xcode 설정과 계정/인증서 상태에 영향을 받을 수 있다.

### `scripts/release.sh`

현재 존재하지 않는다. Stage 3에서 공개 배포용 signed release pipeline을 새 script로 추가하는 방향이 적합하다.

## 현재 Cask 상태

실제 파일은 `Casks/alhangeul-macos.rb`다. 수행계획서의 예전 후보명은 Stage 1에서 실제 파일명으로 보정했다.

현재 Cask 내용:

- token: `alhangeul-macos`
- version: `0.1.0`
- sha256: `:no_check`
- url: `https://github.com/postmelee/alhangeul-macos/releases/download/v#{version}/alhangeul-macos-#{version}.zip`
- name: `알한글`
- desc: Quick Look, thumbnail, viewer app 설명
- homepage: 현재 GitHub 저장소
- dependency: macOS Monterey 이상
- app artifact: `AlhangeulMac.app`
- caveats: 앱을 한 번 실행하면 Quick Look 및 Thumbnail 확장이 등록된다는 안내

Stage 4에서 확인해야 할 Cask 쟁점:

- 공개 배포 산출물을 zip으로 유지할지 DMG로 전환할지
- signed/notarized DMG가 없는 상태에서 Cask를 공개 배포 대상으로 볼 수 있는지
- `sha256 :no_check`를 유지할지, 실제 sha256 고정으로 전환할지
- Apple Silicon/Intel 분리 산출물이 필요해질 경우 Cask 구조를 어떻게 잡을지
- caveats가 실제 ExtensionKit 등록 흐름과 맞는지

## release 문서 상태

`mydocs/manual/release_distribution_guide.md`는 현재 상태를 비교적 정확히 기록한다.

확인된 내용:

- 릴리스/배포/서명/공증/Homebrew Cask 작업은 작업지시자 명시 지시가 있을 때만 수행한다.
- 인증서, Apple Developer 계정, notarization credential, GitHub token, Homebrew tap 권한은 작업지시자가 직접 관리한다고 되어 있다.
- 현재 `scripts/package-release.sh`는 zip 생성 script로 설명된다.
- 현재 `Casks/alhangeul-macos.rb`는 Homebrew Cask 초안으로 설명된다.
- 공개 릴리스 전 Developer ID 서명과 notarization 적용 시점을 확정해야 한다고 되어 있다.
- 현재 저장소에는 Developer ID 서명과 notarization 자동화가 없다고 명시되어 있다.
- GitHub Release와 Homebrew Cask는 절차와 확인 항목만 있고 자동화는 없다.

보강 필요:

- Apple Developer Program credential이 없는 현 상태에서는 signed/notarized public release가 아니라 rehearsal/missing credential 검증까지만 가능하다는 운영 기준
- 개발용 zip package와 공개 배포용 signed/notarized DMG의 역할 분리
- `scripts/release.sh`가 담당할 preflight, signing, notarization, DMG, checksum, Gatekeeper 검증 단계
- GitHub Release 생성 자동화는 이번 issue 범위가 아니라 후속 issue라는 점

## build/run 문서와 README 상태

`mydocs/manual/build_run_guide.md`와 `README.md`는 Finder 통합 smoke test를 `scripts/package-release.sh` 산출물 기준으로 안내한다.

확인된 기준:

- Debug build는 compile/link 확인용이다.
- `CODE_SIGNING_ALLOWED=NO` 산출물은 Quick Look/Thumbnail 등록 검증에 사용하지 않는다.
- Finder 통합은 `build.noindex/release/AlhangeulMac.app`을 `$HOME/Applications/AlhangeulMac.app`로 복사해 확인한다.
- app filesystem bundle name은 `AlhangeulMac.app` ASCII 이름으로 유지한다.
- 사용자 표시명은 localized `InfoPlist.strings`로 제공한다.

Issue #32 이후 보강 후보:

- README에는 공개 배포 절차를 과하게 넣지 않고, release guide로 연결하는 정도가 적합하다.
- build/run guide의 Finder smoke test는 개발/검증용 package 기준으로 유지하되, signed/notarized public release와는 구분해야 한다.

## Xcode project와 signing 설정

`project.yml` 기준 target:

| target | product | bundle id | entitlements | signing |
|------|------|------|------|------|
| `HostApp` | `AlhangeulMac` | `com.postmelee.alhangeulmac` | `Sources/HostApp/HostApp.entitlements` | `CODE_SIGN_STYLE: Automatic` |
| `QLExtension` | `AlhangeulMacPreview` | `com.postmelee.alhangeulmac.QLExtension` | `Sources/QLExtension/QLExtension.entitlements` | `CODE_SIGN_STYLE: Automatic` |
| `ThumbnailExtension` | `AlhangeulMacThumbnail` | `com.postmelee.alhangeulmac.ThumbnailExtension` | `Sources/ThumbnailExtension/ThumbnailExtension.entitlements` | `CODE_SIGN_STYLE: Automatic` |

entitlements:

- 세 target 모두 app sandbox를 사용한다.
- 세 target 모두 user-selected read-only file access entitlement가 있다.

Info.plist:

- 세 target 모두 `CFBundleShortVersionString = 0.1.0`
- 세 target 모두 `CFBundleVersion = 1`
- HostApp 기본 표시명과 bundle name은 `AlhangeulMac`
- Quick Look extension 기본 표시명과 bundle name은 `AlhangeulMacPreview`
- Thumbnail extension 기본 표시명과 bundle name은 `AlhangeulMacThumbnail`
- `LSHasLocalizedDisplayName = true`

localized display:

- HostApp ko: `알한글`
- HostApp en: `AlhangeulMac`
- Quick Look ko: `알한글 미리보기`
- Quick Look en: `AlhangeulMac Preview`
- Thumbnail ko: `알한글 썸네일`
- Thumbnail en: `AlhangeulMac Thumbnail`

Stage 2 설계 쟁점:

- CLI `codesign --sign` 경로를 쓸지, `xcodebuild`에 signing setting을 넘길지 결정해야 한다.
- `DEVELOPMENT_TEAM`을 환경변수로 요구할지 여부를 정해야 한다.
- app과 embedded appex를 어느 순서로 검증할지 정해야 한다.
- hardened runtime을 `project.yml` setting으로 추가해야 하는지 확인해야 한다.

## GitHub Actions 상태

현재 `.github/`에는 `pull_request_template.md`만 있다. release workflow는 없다.

따라서 이번 issue에서 GitHub Actions 기반 Release 생성/업로드까지 포함하면 범위가 커진다. 수행계획서대로 GitHub Release 생성 자동화와 Actions 연계는 후속 작업으로 두고, 이번 issue는 로컬 release script와 문서화에 집중하는 편이 적합하다.

## 산출물 이름과 경로

현재 package script 기준:

| 항목 | 값 |
|------|------|
| build root | `build.noindex` |
| release dir | `build.noindex/release` |
| Xcode build dir | `build.noindex/release/xcodebuild` |
| DerivedData | `build.noindex/release/DerivedData` |
| app bundle | `AlhangeulMac.app` |
| zip | `alhangeul-macos-<version>.zip` |

공개 배포용 release script의 후보 산출물:

- `AlhangeulMac.app`
- `alhangeul-macos-<version>.dmg`
- `alhangeul-macos-<version>.dmg.sha256` 또는 `SHA256SUMS.txt`
- 필요 시 `alhangeul-macos-<version>.zip`

DMG 안의 app path는 ExtensionKit lookup 안정성을 위해 `AlhangeulMac.app`을 유지하는 것이 맞다.

## Stage 2 제안 범위

Stage 2에서는 구현 전 설계를 문서로 확정한다.

결정할 항목:

- `scripts/release.sh` CLI 인터페이스
- `--skip-notarize` 또는 rehearsal 모드의 범위
- credential preflight 순서와 error message 정책
- app signing과 DMG signing identity 환경변수 이름
- notarytool profile 사용 방식
- `hdiutil` DMG 생성 방식
- `codesign`, `spctl`, `stapler` 검증 순서
- `package-release.sh`를 수정할지, 그대로 개발용으로 둘지
- Cask가 zip을 계속 가리킬지 DMG로 전환할지

## 검증 결과

```text
$ git status --short --branch
결과: local/task32, 작업트리 clean 상태에서 조사 시작
```

```text
$ test -f scripts/release.sh && sed -n '1,240p' scripts/release.sh || true
결과: 출력 없음. scripts/release.sh 없음
```

```text
$ find . -maxdepth 3 -type f \( -path './Casks/*' -o -name '*cask*' -o -name '*.rb' \) | sort
결과: ./Casks/alhangeul-macos.rb
```

```text
$ rg --line-number 'codesign|notary|notar|stapler|hdiutil|spctl|sha256|shasum|ditto|package-release|release.sh|xcodebuild|CODE_SIGN|DEVELOPER_ID|NOTARY|DMG|dmg|zip' README.md mydocs/manual/release_distribution_guide.md mydocs/manual/build_run_guide.md scripts Casks project.yml .github --glob '!RustBridge/target/**'
결과: package-release zip/sha256, release guide의 수동 절차, Cask 초안, project signing setting 확인. release.sh, notarytool 자동화, DMG 자동화 없음.
```

## 잔여 위험

- 실제 signing/notarization은 Apple Developer Program, Developer ID certificate, keychain profile 상태에 의존한다.
- credential 없는 상태의 검증은 preflight/missing credential/dry-run 성격으로 제한된다.
- `package-release.sh`의 Release build가 로컬 Xcode signing 상태에 영향을 받을 수 있으므로, 공개 배포용 script에서는 signing 입력을 더 명확히 요구해야 한다.
- Cask는 현재 zip과 `sha256 :no_check` 기준이다. signed/notarized DMG로 전환하면 Cask URL/sha256 정책을 함께 바꿔야 한다.

## 다음 단계

Stage 2에서는 release pipeline 인터페이스와 실패 정책을 확정한다. 구현은 아직 하지 않는다.

## 승인 요청

Stage 1 조사를 완료했다. 이 보고서 기준으로 Stage 2 `release pipeline 인터페이스와 실패 정책 설계`를 진행할지 승인 요청한다.
