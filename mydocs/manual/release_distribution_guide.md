# 릴리스/배포 가이드

## 목적

이 문서는 `alhangeul-macos`의 릴리스, 배포, Homebrew Cask, 서명, 공증, GitHub Release 작업을 위한 저장소 소유자용 절차를 정리한다.

공개 `README.md`는 프로젝트 소개와 소스 빌드 중심으로 유지한다. 릴리스/배포 절차는 권한, 인증서, 배포 정책, 버전 확정이 필요한 작업이므로 이 매뉴얼에서만 다룬다.

## 권한 원칙

- 릴리스/배포 작업은 저장소 소유자의 명시 지시가 있을 때만 수행한다.
- Claude와 Codex가 임의로 버전 태그, GitHub Release, Homebrew Cask PR, 서명/공증 작업을 시작하지 않는다.
- 인증서, Apple Developer 계정, notarization credential, GitHub token, Homebrew tap 권한은 작업지시자가 직접 관리한다.
- 민감 정보는 문서, commit, PR, shell history에 남기지 않는다.

## 현재 상태

현재 저장소에는 다음 릴리스 관련 자산이 있다.

- `scripts/package-release.sh`: Release configuration으로 내부 산출물 `RhwpMac.app`을 빌드한 뒤 ASCII filesystem bundle name인 `RhwpMac.app`으로 zip 파일을 생성한다.
- `Casks/rhwp-mac.rb`: Homebrew Cask 초안이다.
- `Sources/HostApp/Info.plist`, `Sources/QLExtension/Info.plist`, `Sources/ThumbnailExtension/Info.plist`: 앱과 extension 버전 정보가 들어 있다.
- `rhwp-core.lock`: 릴리스에 포함되는 `rhwp` core commit을 기록한다.

첫 공개 릴리스 전 확정해야 할 사항:

- GitHub 저장소명 기준 release URL: 현재 저장소는 `postmelee/alhangeul-macos`다.
- zip 파일명과 Homebrew Cask token: 현재 스크립트와 cask는 `rhwp-mac` 이름을 사용한다.
- 앱 표시명: 현재 `알한글`이다.
- 배포 앱 filesystem bundle name: 현재 `RhwpMac.app`이다. Quick Look/Thumbnail extension의 LaunchServices/ExtensionKit lookup 안정성을 위해 `.app` 경로는 ASCII로 유지한다.
- 내부 Xcode product name: 현재 `RhwpMac.app`이다.
- bundle identifier: 현재 `com.postmelee.rhwpmac` 계열이다.
- SHA256 고정 여부: 공개 배포 시 `sha256 :no_check`를 유지할지 결정해야 한다.
- Developer ID 서명과 notarization 적용 시점.

## 릴리스 전 확인

릴리스 후보를 만들기 전에 다음을 확인한다.

```bash
git status --short --branch
git submodule status Vendor/rhwp
cat rhwp-core.lock
```

확인 기준:

- 작업 브랜치와 릴리스 기준 브랜치가 명확해야 한다.
- `Vendor/rhwp` submodule commit과 `rhwp-core.lock`의 `rhwp_commit`이 일치해야 한다.
- 의도하지 않은 미커밋 변경이 없어야 한다.
- 릴리스에 포함할 PR이 모두 merge되어 있어야 한다.

## 필수 검증

기본 검증:

```bash
./scripts/build-rust-macos.sh
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project RhwpMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
./scripts/validate-stage3-render.sh
```

Release configuration 검증:

```bash
xcodebuild -project RhwpMac.xcodeproj \
  -scheme HostApp \
  -configuration Release \
  -derivedDataPath build/DerivedDataRelease \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Finder 통합 smoke test:

```bash
mkdir -p ~/Applications
rm -rf ~/Applications/RhwpMac.app
ditto build/DerivedData/Build/Products/Debug/RhwpMac.app ~/Applications/RhwpMac.app
pluginkit -a ~/Applications/RhwpMac.app
pluginkit -m | grep com.postmelee.rhwpmac
qlmanage -r
qlmanage -r cache
qlmanage -p Vendor/rhwp/samples/basic/KTX.hwp
```

`qlmanage -p`는 GUI preview를 띄우므로 자동화 환경에서는 작업지시자 확인이 필요하다.

## 버전 갱신

릴리스 버전은 태그와 앱 plist 버전을 함께 맞춘다.

확인 대상:

- `Sources/HostApp/Info.plist`
- `Sources/QLExtension/Info.plist`
- `Sources/ThumbnailExtension/Info.plist`
- `Casks/rhwp-mac.rb`
- Git tag: `v<version>`
- GitHub Release 제목과 파일명

현재 버전 필드:

- `CFBundleShortVersionString`
- `CFBundleVersion`

버전 갱신 방식은 별도 자동화가 생기기 전까지 수동으로 검토한다.

## 패키징

zip 생성:

```bash
./scripts/package-release.sh 0.1.0
```

현재 산출물:

```text
build/release/rhwp-mac-0.1.0.zip
```

스크립트가 수행하는 일:

- Rust bridge와 `Rhwp.xcframework` 재생성
- `xcodegen generate`
- Release configuration으로 HostApp 빌드
- 내부 산출물 `RhwpMac.app`을 release staging으로 복사한 뒤 `RhwpMac.app` 이름으로 zip 압축
- SHA256 출력

주의:

- 현재 스크립트는 서명/공증을 자동 수행하지 않는다.
- zip 파일명은 `rhwp-mac-<version>.zip`이다. 저장소명 `alhangeul-macos`와 맞출지 릴리스 전 결정해야 한다.

## 서명과 공증

현재 저장소에는 Developer ID 서명과 notarization 자동화가 없다.

공개 배포 전 선택지:

- 미서명 개발용 zip만 배포
- Developer ID Application 인증서로 서명
- hardened runtime과 entitlement 검토
- notarization 제출 및 staple

서명/공증을 도입할 때 확인할 항목:

- HostApp, QLExtension, ThumbnailExtension이 모두 올바르게 서명되는가
- extension bundle이 app bundle 안에 올바르게 embed되는가
- sandbox entitlement가 preview/thumbnail 동작과 충돌하지 않는가
- notarization 후 Gatekeeper에서 실행 가능한가

서명/공증 자동화가 추가되면 이 문서를 함께 갱신한다.

## GitHub Release

GitHub Release 생성 전 확인:

- release branch 또는 tag 기준 commit이 정확한가
- `rhwp-core.lock` commit이 release note에 기록되었는가
- `validate-stage3-render.sh` 결과가 release report에 기록되었는가
- zip 파일 SHA256이 기록되었는가
- 알려진 한계와 수동 확인 항목이 기록되었는가

Release note에 포함할 내용:

- 주요 변경 사항
- 지원 macOS 버전
- 포함된 `rhwp` core commit
- 설치/실행 주의사항
- Quick Look/Thumbnail extension 등록 확인 방법
- 알려진 문제

## Homebrew Cask

현재 `Casks/rhwp-mac.rb`는 초안이다.

릴리스 전 확인:

- `url`이 `https://github.com/postmelee/alhangeul-macos/releases/...`를 가리키는가
- `version`이 Git tag와 일치하는가
- `sha256`을 실제 값으로 고정할 것인가
- cask token을 `rhwp-mac`으로 유지할 것인가, `alhangeul-macos`로 바꿀 것인가
- `homepage`이 현재 저장소를 가리키는가
- `app "RhwpMac.app"`이 산출물과 일치하는가
- caveats 문구가 현재 extension 등록 흐름과 일치하는가

## Rollback

릴리스에 문제가 있으면 다음 순서로 대응한다.

1. GitHub Release asset을 숨기거나 삭제한다.
2. Homebrew Cask가 공개된 경우 해당 버전 설치 경로를 중단하거나 새 patch release를 만든다.
3. 문제를 GitHub Issue로 등록한다.
4. 원인, 영향 범위, 재발 방지책을 `mydocs/troubleshootings/`에 기록한다.
5. 수정 PR을 `devel`로 merge한 뒤 새 릴리스 후보를 만든다.

## 릴리스 체크리스트

- [ ] 릴리스 버전 확정
- [ ] 릴리스 기준 branch/commit 확정
- [ ] `Vendor/rhwp`와 `rhwp-core.lock` 일치 확인
- [ ] Debug build 통과
- [ ] Release build 통과
- [ ] `validate-stage3-render.sh` 통과
- [ ] Finder Quick Look smoke test 완료
- [ ] Finder thumbnail smoke test 완료
- [ ] zip 산출물 생성
- [ ] SHA256 기록
- [ ] 서명/공증 정책 확인
- [ ] GitHub Release note 작성
- [ ] Homebrew Cask 갱신 여부 결정
- [ ] 릴리스 최종 보고서 작성
