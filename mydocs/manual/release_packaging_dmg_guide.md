# 릴리즈 패키징과 DMG 가이드

## 목적

이 문서는 Release configuration build, 개발용 zip, public/rehearsal DMG, DMG layout smoke, Finder 통합 smoke 절차를 정리한다. 배포 정책은 [`release_policy_guide.md`](release_policy_guide.md), signing/notarization 세부 검증은 [`release_signing_notarization_guide.md`](release_signing_notarization_guide.md)를 따른다.

## 권한 원칙

- public DMG 생성은 작업지시자가 release version과 release candidate commit을 확정하고 명시 지시한 뒤 수행한다.
- `--skip-notarize` rehearsal DMG와 개발용 zip은 public GitHub Release asset 또는 Homebrew Cask URL에 사용하지 않는다.
- public release mode는 clean worktree와 Developer ID/notary credential 준비가 필요하다.

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

## 기본 검증

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

## Release pipeline preflight check

```bash
./scripts/release.sh --help
env -u ALHANGEUL_DEVELOPER_ID_APPLICATION -u ALHANGEUL_NOTARY_PROFILE ./scripts/release.sh <version>
```

두 번째 명령은 credential 누락 시 build 전에 중단되는 fail-fast guard 검증용이다. 다음처럼 실패해야 정상이다.

```text
ERROR: ALHANGEUL_DEVELOPER_ID_APPLICATION is required for public release
```

## 개발용 패키징

zip 생성:

```bash
./scripts/package-release.sh <version>
```

산출물:

```text
build.noindex/release/alhangeul-macos-<version>.zip
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
ALHANGEUL_DEVELOPER_ID_APPLICATION="<Developer ID Application signing identity>" \
ALHANGEUL_NOTARY_PROFILE="<notarytool keychain profile>" \
./scripts/release.sh <version>
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
build.noindex/release/alhangeul-macos-<version>.dmg
build.noindex/release/alhangeul-macos-<version>.dmg.sha256
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
- DMG layout metadata 적용
- DMG signing
- DMG notarization submit/wait
- DMG staple
- `spctl` Gatekeeper 검증
- DMG sha256 파일 생성

주의:

- public mode는 Developer ID signing identity와 `notarytool` keychain profile이 확인된 환경에서만 실행한다.
- password, app-specific password, API key, keychain profile 내부 credential payload는 저장소에 기록하지 않는다.
- notarytool keychain profile 생성과 credential 관리는 작업지시자가 직접 수행한다.
- `scripts/release.sh` public mode는 clean worktree를 요구한다.
- GitHub Release 생성과 asset upload는 이 script가 수행하지 않는다.
- Homebrew Cask PR 생성도 이 script가 수행하지 않는다.

## Rehearsal DMG

public release 전 layout, DMG 생성, checksum 생성만 확인할 때 rehearsal mode를 사용한다.

```bash
./scripts/release.sh --skip-notarize <version>
```

rehearsal mode 산출물:

```text
build.noindex/release/Alhangeul.app
build.noindex/release/alhangeul-macos-<version>-rehearsal.dmg
build.noindex/release/alhangeul-macos-<version>-rehearsal.dmg.sha256
```

rehearsal mode가 수행하는 일:

- Rust bridge lock verify
- shared Swift boundary check
- Release build
- DMG layout 생성
- DMG layout smoke 입력 산출물 생성
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
- rehearsal DMG에서 background와 icon 위치가 정상이어도 public DMG signing/notarization/staple 후 최종 layout smoke를 반복한다.

GitHub Actions `Release Rehearsal DMG` workflow를 사용할 때도 같은 산출물 계층을 따른다.

workflow 입력:

- `version`
- `previous_release_ref`
- `expected_rhwp_tag`

workflow 결과:

- rehearsal DMG/checksum artifact
- release delta checklist artifact
- workflow summary의 `rhwp core`, `Release delta checklist`, `Rehearsal artifact` 섹션

`previous_release_ref`는 직전 public release tag 또는 commit을 넣는다. 이 입력이 잘못되면 delta checklist가 잘못 생성되므로, workflow summary와 artifact의 previous/candidate ref를 release owner가 확인한다.

## DMG layout smoke

- mounted volume root에는 `Alhangeul.app`과 `Applications` symlink만 사용자에게 노출되어야 한다.
- 별도 `설치 안내.txt` 파일은 두지 않는다. 설치 안내는 DMG background와 release note/README/Homebrew caveats에 유지한다.
- background 파일은 `.background/alhangeul-dmg-background.png`이며, 기준 크기는 720x460 PNG다.
- Retina/multi-representation TIFF background는 Finder 환경에 따라 2x representation이 실제 background 크기로 선택되어 확대 표시될 수 있으므로, 별도 호환성 검증 없이는 public 기준으로 쓰지 않는다.
- Finder window는 toolbar/statusbar hidden icon view로 열리고, app icon과 Applications symlink가 background arrow 흐름과 맞는 위치에 있어야 한다.
- rehearsal DMG에서 확인한 layout은 public mode에서도 같은 `create_dmg` path를 쓰므로 기본 회귀 신호로 삼되, signed/notarized public DMG 생성 후 같은 smoke를 다시 반복한다.

## Finder 통합 smoke test

전체 명령 시퀀스(`lsregister` 갱신, `ditto` 설치, `pluginkit` 등록 확인, `qlmanage` 캐시/렌더 검증)와 반복 시행착오 방지 규칙은 [`build_run_guide.md`](build_run_guide.md)의 "Finder 통합 확인" 섹션을 따른다. 기본 명령은 다음과 같다.

```bash
scripts/smoke-finder-integration.sh --version <version>
```

이미 생성된 Release package staging app을 재사용할 때:

```bash
scripts/smoke-finder-integration.sh --skip-package --app build.noindex/release/Alhangeul.app
```

이전 이름 설치본이 남아 false positive가 의심되면 파일을 삭제하지 않고 등록만 격리하는 옵션을 명시한다.

```bash
scripts/smoke-finder-integration.sh --skip-package --app build.noindex/release/Alhangeul.app --unregister-legacy-candidates
```

release pipeline 검증 시 추가로 다음을 적용한다.

- 입력 산출물은 반드시 `./scripts/package-release.sh <version>`이 만든 signed/sealed Release package를 사용한다 (Debug 산출물 금지).
- 자동화 환경에서는 `qlmanage -p`(GUI preview)를 사용하지 않고 `qlmanage -t -x`(headless thumbnail) 기준으로 판정한다. Preview 확인은 수동 확인 결과로 별도 기록한다.
- 기본 샘플은 앱 저장소 루트의 `samples/basic/KTX.hwp`와 `samples/hwpx/hwpx-01.hwpx`를 사용하고, 사용자 파일 검증이 필요하면 대상 경로를 명시한다.
- helper script가 출력하는 diagnostics directory를 단계 보고서 또는 release smoke report에 기록한다.

주의:

- `CODE_SIGNING_ALLOWED=NO` Debug 산출물은 Finder 통합 smoke test에 쓰지 않는다. compile/link 확인과 bundle resource 확인까지만 사용한다.
- Debug/Release 중간 산출물과 package staging 산출물은 Spotlight 앱 검색 결과에 섞이지 않도록 `build.noindex/` 아래에 둔다.
- Release package 산출물은 `Sign to Run Locally` 경로로 signing과 sealed resources가 적용되므로 LaunchServices/PlugInKit 등록 검증에 더 적합하다.
- Dock/Finder/Spotlight 표시명 검증 시 기본 `Info.plist`의 `CFBundleDisplayName`/`CFBundleName`이 실제 bundle filesystem name과 맞고, `ko.lproj/InfoPlist.strings`와 `LSHasLocalizedDisplayName`이 release bundle 안에 포함됐는지 먼저 확인한다.
- 이전 이름의 설치본(`RhwpMac.app`, `AlhangeulMac.app`, `알한글.app`)이 발견되면 helper는 false positive 방지를 위해 기본 실패한다. 작업지시자 승인 후 `--unregister-legacy-candidates`로 LaunchServices/PlugInKit 등록만 격리할 수 있으며, 실제 파일 삭제는 별도 승인 후에만 수행한다.
- `qlmanage -m plugins` 미노출은 app extension 실행 실패의 직접 증거가 아니므로, 등록은 `pluginkit -mAvvv`, 실제 렌더링은 `qlmanage -t -x`로 판정한다.
