# 릴리스/배포 가이드

## 목적

이 문서는 `alhangeul-macos`의 릴리스, 배포, Homebrew Cask, 서명, 공증, GitHub Release 작업을 위한 저장소 소유자용 절차를 정리한다.

공개 `README.md`는 프로젝트 소개와 소스 빌드 중심으로 유지한다. 릴리스/배포 절차는 권한, 인증서, 배포 정책, 버전 확정이 필요한 작업이므로 이 매뉴얼에서만 다룬다.

## 권한 원칙

- 릴리스/배포 작업은 저장소 소유자의 명시 지시가 있을 때만 수행한다.
- Claude와 Codex가 임의로 버전 태그, GitHub Release, Homebrew Cask PR, 서명/공증 작업을 시작하지 않는다.
- 인증서 private key, Apple Developer 계정, notarization credential, GitHub token, Homebrew tap 권한은 작업지시자가 직접 관리한다.
- 민감 정보는 문서, commit, PR, shell history에 남기지 않는다.
- 문서에 기록할 수 있는 값은 Team ID, signing identity 표시명, keychain profile name처럼 비밀이 아닌 운영 식별자에 한정한다.
- password, app-specific password, App Store Connect API private key(`.p8`), exported signing identity(`.p12`)와 그 password는 저장소에 기록하지 않는다.

## 현재 상태

현재 저장소에는 다음 릴리스 관련 자산이 있다.

- `scripts/package-release.sh`: Release configuration으로 내부 산출물 `Alhangeul.app`을 빌드한 뒤 ASCII filesystem bundle name인 `Alhangeul.app`으로 zip 파일을 생성한다.
- `scripts/release.sh`: 공개 배포용 DMG release pipeline이다. Developer ID 서명, app/DMG notarization, staple, Gatekeeper 검증, sha256 산출 경로를 포함한다.
- `Casks/alhangeul-macos.rb`: Homebrew Cask 초안이다.
- `Sources/HostApp/Info.plist`, `Sources/QLExtension/Info.plist`, `Sources/ThumbnailExtension/Info.plist`: 앱과 extension 버전 정보가 들어 있다.
- `rhwp-core.lock`: 릴리스에 포함되는 `edwardkim/rhwp` core commit과 Rust bridge 산출물 provenance를 기록한다.
- `Sources/HostApp/Resources/rhwp-studio/manifest.json`: 릴리스에 포함되는 bundled `rhwp-studio` static asset provenance와 entrypoint hash를 기록한다.

### 확정된 기준

다음 항목은 v0.1.0 시점에 이미 결정되어 release script, Cask, plist에 반영되어 있다.

- GitHub 저장소: `postmelee/alhangeul-macos`
- 산출물 파일명/Homebrew Cask token: `alhangeul-macos`
- 앱 filesystem bundle name: `Alhangeul.app` (Quick Look/Thumbnail ExtensionKit lookup 안정성을 위해 ASCII 유지)
- 내부 Xcode product name: `Alhangeul`
- bundle identifier: `com.postmelee.alhangeul` 계열
- 사용자 표시명: 한국어 `알한글` (`ko.lproj/InfoPlist.strings`), 영어 `Alhangeul` (`en.lproj/InfoPlist.strings`). 기본 `Info.plist`의 `CFBundleDisplayName`/`CFBundleName`은 ASCII filesystem name과 동일
- 공개 배포 산출물명: `alhangeul-macos-<version>.dmg`

### 배포 브랜치 기준

v0.1.x public release는 `devel-webview`를 배포 준비 기준 브랜치로 사용한다. 릴리스 후보가 확정되면 `devel-webview`의 검증된 commit을 `main`에 반영하고, Git tag와 GitHub Release는 `main` 기준으로 생성한다.

`devel`은 native viewer renderer와 장기 개발 통합 브랜치이므로 배포 직전 기준 브랜치로 사용하지 않는다. `devel-webview`에 merge된 release-critical 변경은 별도 PR 또는 cherry-pick으로 `devel`에 후속 동기화한다.

브랜치 역할과 출시 후 rename 후보는 [`branch_strategy_webview_native.md`](../tech/branch_strategy_webview_native.md)를 기준으로 판단한다.

### Apple Developer Program 준비 상태

2026-04-29 기준 Apple Developer Program 가입과 public release에 필요한 로컬 credential 준비가 완료된 상태다.

비밀이 아닌 운영 값:

- Team ID: `XH6JHKYXV8`
- Developer ID Application signing identity: `Developer ID Application: Taegyu Lee (XH6JHKYXV8)`
- notarytool keychain profile: `alhangeul-notary`

로컬 확인 완료 항목:

- Developer ID Application 인증서를 `로그인` Keychain에 설치했고, `security find-identity -v -p codesigning`에서 signing identity를 확인했다.
- `xcrun notarytool store-credentials "alhangeul-notary" --apple-id <Apple ID> --team-id "XH6JHKYXV8"`로 credential을 Keychain에 저장했다.
- `xcrun notarytool history --keychain-profile "alhangeul-notary"`가 credential validation을 통과했고, 아직 notarization submission history가 없는 상태를 확인했다.

저장소에 기록하지 않는 값:

- Apple ID password
- app-specific password
- App Store Connect API private key(`.p8`)
- exported signing identity(`.p12`)와 password
- Keychain에 저장된 notarytool credential payload

### 공개 release 전 확정 항목

다음 항목은 첫 public release 시점에 작업지시자 결정이 필요하다.

- DMG `sha256` 교체: Cask 초안의 `sha256 :no_check`를 public DMG 생성 후 실제 digest로 교체할 시점
- Developer ID 서명/notarization 실행 시점: credential은 준비됐지만 실제 public release 실행은 작업지시자가 버전과 release commit을 확정하고 명시 지시한 시점에만 수행

## 릴리스 전 확인

릴리스 후보를 만들기 전에 다음을 확인한다.

```bash
git status --short --branch
cat rhwp-core.lock
./scripts/build-rust-macos.sh --verify-lock
scripts/verify-rhwp-studio-assets.sh
```

확인 기준:

- 작업 브랜치와 릴리스 기준 브랜치가 명확해야 한다.
- `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`, `rhwp-core.lock`의 repo/ref/commit 기준이 일치해야 한다.
- `Frameworks/universal/librhwp.a`, `Frameworks/generated_rhwp.h`의 hash/size가 `rhwp-core.lock`과 일치해야 한다.
- `Sources/HostApp/Resources/rhwp-studio/manifest.json`의 release tag/commit과 bundled entrypoint hash가 현재 resource tree와 일치해야 한다.
- 의도하지 않은 미커밋 변경이 없어야 한다.
- 릴리스에 포함할 PR이 모두 merge되어 있어야 한다.
- public release 산출물을 만들 때는 Apple Developer Program, Developer ID Application 인증서, notarytool keychain profile이 준비되어 있어야 한다.

## v0.1 artifact 구성 기준

v0.1 release artifact는 사용 목적을 기준으로 세 계층으로 분리한다.

| 계층 | 기준 산출물 | 목적 | public 사용 |
|------|-------------|------|-------------|
| 개발/설치본 smoke | `build.noindex/release/Alhangeul.app`, `alhangeul-macos-<version>.zip` | Release configuration bundle 구성과 Finder/Quick Look/Thumbnail 설치본 smoke 입력 | 아니오 |
| public release rehearsal | `alhangeul-macos-<version>-rehearsal.dmg`, `.sha256` | DMG layout, checksum 생성, release script path 확인 | 아니오 |
| public release | `alhangeul-macos-<version>.dmg`, `.sha256` | GitHub Release asset, 사용자 배포, Homebrew Cask digest 기준 | 예 |

checksum 공개 기준:

| checksum | 공개 범위 | 기준 |
|----------|-----------|------|
| zip stdout checksum | 단계 보고서, 설치본 smoke report | 개발/검증용 식별자. GitHub Release asset이나 Cask digest로 쓰지 않는다. |
| rehearsal DMG `.sha256` | rehearsal workflow artifact와 단계 보고서 | public release checksum으로 쓰지 않는다. |
| public DMG `.sha256` | GitHub Release asset, release note, Homebrew Cask 교체 입력 | 사용자 배포 기준 checksum이다. |

provenance 진실 원천:

| 대상 | 진실 원천 | 공개/검증 방식 |
|------|-----------|---------------|
| `rhwp` core release tag/commit | `rhwp-core.lock` | release note에 tag/commit을 직접 표시하고 lock 파일을 검증 기준으로 둔다. |
| Rust bridge artifact hash/size | `rhwp-core.lock` | release 전 `./scripts/build-rust-macos.sh --verify-lock`으로 검증한다. |
| FFI ABI surface | `rhwp-ffi-symbols.txt` | 최종 보고서와 PR에서 변경 여부를 기록한다. |
| bundled `rhwp-studio` asset | `Sources/HostApp/Resources/rhwp-studio/manifest.json` | release note에 manifest 위치와 tag/commit을 표시하고 `scripts/verify-rhwp-studio-assets.sh`로 검증한다. |
| Third Party notices | `THIRD_PARTY_LICENSES.md`, `Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md` | release note에서 문서 위치를 안내한다. |

## 필수 검증

기본 검증:

```bash
./scripts/build-rust-macos.sh --verify-lock
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
./scripts/validate-stage3-render.sh
```

Release configuration 검증:

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Release \
  -derivedDataPath build.noindex/DerivedDataRelease \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Public release credential 확인:

```bash
security find-identity -v -p codesigning
xcrun notarytool history --keychain-profile "alhangeul-notary"
```

확인 기준:

- `security find-identity` 출력에 `Developer ID Application: Taegyu Lee (XH6JHKYXV8)`가 있어야 한다.
- `notarytool history`가 인증 오류 없이 실행되어야 한다. 제출 이력이 없으면 `No submission history.`가 나올 수 있으며 credential 검증 실패가 아니다.

Release pipeline preflight check:

```bash
./scripts/release.sh --help
env -u ALHANGEUL_DEVELOPER_ID_APPLICATION -u ALHANGEUL_NOTARY_PROFILE ./scripts/release.sh 0.1.0
```

두 번째 명령은 credential 누락 시 build 전에 중단되는 fail-fast guard 검증용이다. 다음처럼 실패해야 정상이다.

```text
ERROR: ALHANGEUL_DEVELOPER_ID_APPLICATION is required for public release
```

public release 전 DMG layout과 checksum 생성만 확인할 때:

```bash
./scripts/release.sh --skip-notarize 0.1.0
```

`--skip-notarize` 산출물은 `alhangeul-macos-<version>-rehearsal.dmg`이며 public release, GitHub Release asset, Homebrew Cask URL/sha256에 사용하지 않는다.

Finder 통합 smoke test:

전체 명령 시퀀스(`lsregister` 갱신, `ditto` 설치, `pluginkit` 등록 확인, `qlmanage` 캐시/렌더 검증)와 반복 시행착오 방지 규칙은 [`build_run_guide.md`](build_run_guide.md)의 "Finder 통합 확인" 섹션을 따른다. release pipeline 검증 시 추가로 다음을 적용한다.

- 입력 산출물은 반드시 `./scripts/package-release.sh <version>`이 만든 signed/sealed Release package를 사용한다 (Debug 산출물 금지).
- 자동화 환경에서는 `qlmanage -p`(GUI preview)를 사용하지 않고 `qlmanage -t -x`(headless thumbnail) 기준으로 판정한다.
- 기본 샘플은 앱 저장소 루트의 `samples/basic/KTX.hwp`를 사용하고, 사용자 파일 검증이 필요하면 대상 경로를 명시한다.

주의:

- `CODE_SIGNING_ALLOWED=NO` Debug 산출물은 Finder 통합 smoke test에 쓰지 않는다. compile/link 확인과 bundle resource 확인까지만 사용한다.
- Debug/Release 중간 산출물과 package staging 산출물은 Spotlight 앱 검색 결과에 섞이지 않도록 `build.noindex/` 아래에 둔다.
- Release package 산출물은 `Sign to Run Locally` 경로로 signing과 sealed resources가 적용되므로 LaunchServices/PlugInKit 등록 검증에 더 적합하다.
- Dock/Finder/Spotlight 표시명 검증 시 기본 `Info.plist`의 `CFBundleDisplayName`/`CFBundleName`이 실제 bundle filesystem name과 맞고, `ko.lproj/InfoPlist.strings`와 `LSHasLocalizedDisplayName`이 release bundle 안에 포함됐는지 먼저 확인한다.
- 이전 이름의 설치본(`RhwpMac.app`, `알한글.app`)은 discovery 충돌이 확인되거나 의심될 때만 작업지시자 승인 후 제거한다.
- `qlmanage -m plugins` 미노출은 app extension 실행 실패의 직접 증거가 아니므로, 등록은 `pluginkit -mAvvv`, 실제 렌더링은 `qlmanage -t -x`로 판정한다.

## 버전 갱신

릴리스 버전은 태그와 앱 plist 버전을 함께 맞춘다.

확인 대상:

- `Sources/HostApp/Info.plist`
- `Sources/QLExtension/Info.plist`
- `Sources/ThumbnailExtension/Info.plist`
- `Casks/alhangeul-macos.rb`
- Git tag: `v<version>`
- GitHub Release 제목과 파일명

현재 버전 필드:

- `CFBundleShortVersionString`
- `CFBundleVersion`

버전 갱신 방식은 별도 자동화가 생기기 전까지 수동으로 검토한다.

## 개발용 패키징

zip 생성:

```bash
./scripts/package-release.sh 0.1.0
```

현재 산출물:

```text
build.noindex/release/alhangeul-macos-0.1.0.zip
```

스크립트가 수행하는 일:

- Rust bridge와 `Rhwp.xcframework` 재생성 후 `rhwp-core.lock` 검증
- `xcodegen generate`
- Release configuration으로 HostApp 빌드
- 내부 산출물 `Alhangeul.app`을 release staging으로 복사한 뒤 `Alhangeul.app` 이름으로 zip 압축
- Release staging app은 local signing과 sealed resources가 적용되어 Finder 통합 smoke test의 기준 산출물로 사용할 수 있음
- SHA256 출력

주의:

- `scripts/package-release.sh`는 서명/공증을 자동 수행하지 않는다.
- lock 검증이 실패하면 app build와 zip 생성을 시작하지 않는다.
- zip 파일명은 `alhangeul-macos-<version>.zip`이며 저장소명과 맞춘다.
- 이 zip은 개발/검증용 산출물이다. public release와 Homebrew Cask 기준 산출물은 `scripts/release.sh`가 만드는 signed/notarized DMG다.

## 공개 배포용 DMG

public release DMG 생성:

```bash
ALHANGEUL_DEVELOPER_ID_APPLICATION="Developer ID Application: Taegyu Lee (XH6JHKYXV8)" \
ALHANGEUL_NOTARY_PROFILE="alhangeul-notary" \
./scripts/release.sh 0.1.0
```

선택 환경변수:

```text
ALHANGEUL_DEVELOPER_ID_DMG
ALHANGEUL_BUILD_ROOT
```

`ALHANGEUL_DEVELOPER_ID_DMG`를 지정하지 않으면 `ALHANGEUL_DEVELOPER_ID_APPLICATION`과 같은 identity로 DMG를 서명한다.

public mode 산출물:

```text
build.noindex/release/Alhangeul.app
build.noindex/release/alhangeul-macos-0.1.0.dmg
build.noindex/release/alhangeul-macos-0.1.0.dmg.sha256
```

`scripts/release.sh`가 수행하는 일:

- Rust bridge와 `Rhwp.xcframework` 재생성 후 `rhwp-core.lock` 검증
- `scripts/check-no-appkit.sh`
- `xcodegen generate`
- Release configuration으로 HostApp 빌드
- Developer ID Application signing identity 확인
- app code signature 검증
- app notarization submit/wait
- app staple
- DMG 생성
- DMG signing
- DMG notarization submit/wait
- DMG staple
- `spctl` Gatekeeper 검증
- DMG sha256 파일 생성

주의:

- public mode는 위 Developer ID signing identity와 `notarytool` keychain profile이 확인된 환경에서만 실행한다.
- password, app-specific password, API key, keychain profile 내부 credential payload는 저장소에 기록하지 않는다.
- notarytool keychain profile 생성과 credential 관리는 작업지시자가 직접 수행한다.
- `scripts/release.sh` public mode는 clean worktree를 요구한다. 버전, release 기준 commit, 포함 PR을 확정한 뒤 실행한다.
- GitHub Release 생성과 asset upload는 이 script가 수행하지 않는다.
- Homebrew Cask PR 생성도 이 script가 수행하지 않는다.

## Rehearsal DMG

public release 전 layout, DMG 생성, checksum 생성만 확인할 때 rehearsal mode를 사용한다.

```bash
./scripts/release.sh --skip-notarize 0.1.0
```

rehearsal mode 산출물:

```text
build.noindex/release/Alhangeul.app
build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg
build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg.sha256
```

rehearsal mode가 수행하는 일:

- Rust bridge lock verify
- shared Swift boundary check
- Release build
- DMG layout 생성
- `hdiutil verify`
- sha256 파일 생성

rehearsal mode가 수행하지 않는 일:

- Developer ID signing 필수 요구
- notarization submit/wait
- staple
- public Gatekeeper 검증

주의:

- `*-rehearsal.dmg`는 public release asset으로 업로드하지 않는다.
- `*-rehearsal.dmg.sha256`은 Homebrew Cask `sha256`에 사용하지 않는다.
- unsigned rehearsal build는 Finder Quick Look/Thumbnail 등록 보증에 쓰지 않는다.
- signed/notarized public DMG 검증은 rehearsal 결과로 대체하지 않는다.

## 서명과 공증 검증 항목

public mode에서 확인할 항목:

- HostApp, QLExtension, ThumbnailExtension이 모두 올바르게 서명되는가
- extension bundle이 app bundle 안에 올바르게 embed되는가
- sandbox entitlement가 preview/thumbnail 동작과 충돌하지 않는가
- notarization 후 Gatekeeper에서 실행 가능한가
- stapled app과 stapled DMG가 모두 검증되는가

대표 확인 명령:

```bash
codesign --verify --deep --strict --verbose=2 build.noindex/release/Alhangeul.app
xcrun stapler validate build.noindex/release/Alhangeul.app
xcrun stapler validate build.noindex/release/alhangeul-macos-0.1.0.dmg
spctl --assess --type execute --verbose build.noindex/release/Alhangeul.app
spctl --assess --type open --context context:primary-signature --verbose build.noindex/release/alhangeul-macos-0.1.0.dmg
```

위 검증은 `scripts/release.sh` public mode가 이미 수행하는 항목을 수동으로 재확인할 때 사용한다.

## GitHub Release

GitHub Release 생성 전 확인:

- release branch 또는 tag 기준 commit이 정확한가
- `rhwp-core.lock`의 core repository와 commit이 release note에 기록되었는가
- `rhwp-studio` manifest의 release tag와 commit이 release note에 기록되었는가
- third-party notices 위치가 release note에 기록되었는가
- `validate-stage3-render.sh` 결과가 release report에 기록되었는가
- DMG 파일 SHA256이 기록되었는가
- 알려진 한계와 수동 확인 항목이 기록되었는가

Release note에 포함할 내용:

- 주요 변경 사항
- 지원 macOS 버전
- 포함된 `edwardkim/rhwp` core commit
- 포함된 `rhwp-studio` asset manifest와 commit
- Third Party notices와 bundled font notice 위치
- 설치/실행 주의사항
- Quick Look/Thumbnail extension 등록 확인 방법
- 알려진 문제

## Homebrew Cask

현재 `Casks/alhangeul-macos.rb`는 초안이다.

릴리스 전 확인:

- `url`이 `https://github.com/postmelee/alhangeul-macos/releases/...`를 가리키는가
- `version`이 Git tag와 일치하는가
- `url`이 public DMG 산출물 `alhangeul-macos-<version>.dmg`와 일치하는가
- `sha256`이 public DMG의 실제 digest와 일치하는가
- cask token이 `alhangeul-macos`인가
- `homepage`이 현재 저장소를 가리키는가
- `app "Alhangeul.app"`이 산출물과 일치하는가
- caveats 문구가 현재 extension 등록 흐름과 일치하는가

운영 기준:

- Cask는 public DMG release가 GitHub Release asset으로 업로드된 뒤에만 배포 경로로 사용한다.
- 실제 public DMG 없이 rehearsal DMG를 가리키도록 수정하지 않는다.
- public DMG sha256이 확정되기 전에는 Cask 초안의 `sha256 :no_check`를 실제 배포 승인으로 간주하지 않는다.

## Rollback

릴리스에 문제가 있으면 다음 순서로 대응한다.

1. GitHub Release asset을 숨기거나 삭제한다.
2. Homebrew Cask가 공개된 경우 해당 버전 설치 경로를 중단하거나 새 patch release를 만든다.
3. 문제를 GitHub Issue로 등록한다.
4. 원인, 영향 범위, 재발 방지책을 `mydocs/troubleshootings/`에 기록한다.
5. 수정 PR을 출시 대상 통합 브랜치로 merge한 뒤 새 릴리스 후보를 만든다. v0.1.x 기준은 `devel-webview`이며, native renderer 장기 브랜치에도 필요한 수정은 별도 PR 또는 cherry-pick으로 `devel`에 후속 반영한다.

## 릴리스 체크리스트

- [ ] 릴리스 버전 확정
- [ ] 릴리스 기준 branch/commit 확정
- [ ] `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`, `rhwp-core.lock` 정합성 확인
- [ ] `./scripts/build-rust-macos.sh --verify-lock` 통과
- [ ] `scripts/verify-rhwp-studio-assets.sh` 통과
- [ ] Debug build 통과
- [ ] Release build 통과
- [ ] `validate-stage3-render.sh` 통과
- [ ] Finder Quick Look smoke test 완료
- [ ] Finder thumbnail smoke test 완료
- [ ] 개발용 zip 산출물 생성
- [ ] public DMG 산출물 생성
- [ ] public DMG SHA256 기록
- [ ] release note에 `rhwp-core.lock`, `rhwp-studio` manifest, third-party notices 기준 기록
- [ ] 서명/공증 검증 완료
- [ ] GitHub Release note 작성
- [ ] Homebrew Cask 갱신 여부 결정
- [ ] 릴리스 최종 보고서 작성
