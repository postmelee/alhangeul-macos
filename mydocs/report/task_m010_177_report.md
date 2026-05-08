# Task M010 #177 최종 보고서

## 작업 개요

이 작업은 첫 공식 DMG 배포 전에 알한글 앱이 Sparkle 기반 업데이트 확인 경로를 갖도록 준비하는 작업이다.

완료 범위:

- HostApp에 Sparkle 2 통합
- 앱 메뉴 `업데이트 확인...` 추가
- Sparkle public key와 stable feed URL을 앱 `Info.plist`에 반영
- sandboxed app용 Sparkle installer service entitlement 반영
- GitHub Pages에 `appcast.xml` skeleton과 업데이트 안내 페이지 추가
- Pages 다운로드 버튼을 GitHub Release DMG 직접 다운로드 URL로 변경
- release publish workflow에 Sparkle appcast 생성과 Pages branch 갱신 경로 추가
- #166 공식 릴리즈가 이어받을 secret, workflow, 검증 gate 문서화

## 단계별 결과

### Stage 1

Sparkle 2, sandboxed app, appcast, GitHub Release direct download URL 요구사항을 확정했다.

결정:

- 앱 feed URL: `https://postmelee.github.io/alhangeul-macos/appcast.xml`
- feed channel: stable 하나만 사용
- 첫 v0.1.0은 prerelease가 아닌 공식 release 기준
- Pages 다운로드 버튼: `releases/latest/download/alhangeul-macos-0.1.0.dmg`
- appcast enclosure: tag 고정 URL `releases/download/v0.1.0/alhangeul-macos-0.1.0.dmg`

### Stage 2

HostApp에 Sparkle을 통합했다.

변경:

- `project.yml`에 Sparkle 2.9.1 exact pin 추가
- `Package.resolved`에 Sparkle revision 고정
- `Sources/HostApp/Info.plist`에 Sparkle 설정 추가
- `Sources/HostApp/HostApp.entitlements`에 Sparkle installer service mach lookup exception 추가
- `Sources/HostApp/Services/UpdateController.swift` 추가
- `Sources/HostApp/HostApp.swift`에 updater controller와 app menu command 연결

빌드 검증 결과 `HostApp` Debug build가 통과했다.

### Stage 3

GitHub Pages 업데이트 안내 경로를 추가했다.

변경:

- `docs/appcast.xml` skeleton 추가
- `docs/updates/index.html` 추가
- `docs/updates/v0.1.0.html` 추가
- `docs/index.html` 다운로드 버튼을 latest DMG direct URL로 변경
- FAQ와 footer에 업데이트 안내 링크 추가

정적 서버에서 `/`, `/appcast.xml`, `/updates/`, `/updates/v0.1.0.html` 모두 `200 OK`를 확인했다.

### Stage 4

release workflow가 appcast를 생성하고 Pages branch에 갱신할 수 있게 했다.

변경:

- `scripts/ci/write-sparkle-appcast.sh` 추가
- `.github/workflows/release-publish.yml`에 official stable release에서만 appcast signing/generation/push 수행
- `SPARKLE_ED_PRIVATE_KEY` secret과 `ALHANGEUL_PAGES_BRANCH` variable 운영 기준 추가
- `mydocs/manual/release_distribution_guide.md`에 Sparkle appcast 운영 문서 추가

fixture appcast 생성과 XML lint를 통과했다.

### Stage 5

통합 검증을 수행했다.

검증 결과:

- `xcodegen dump --type parsed-yaml`: 통과
- `xcodegen generate`: 통과
- `plutil -lint Sources/HostApp/Info.plist Sources/HostApp/HostApp.entitlements`: 통과
- `xmllint --noout docs/appcast.xml`: 통과
- `scripts/ci/write-sparkle-appcast.sh` shell 문법: 통과
- fixture appcast 생성과 XML lint: 통과
- GitHub Actions workflow YAML parse: 통과
- HostApp Debug build: 통과
- built app bundle의 Sparkle framework, `Downloader.xpc`, `Installer.xpc` 포함 확인
- built app bundle의 `SUFeedURL`, `SUPublicEDKey`, `SUEnableInstallerLauncherService` 확인
- Pages 로컬 서버 경로 확인: 통과

## 현재 상태

앱 바이너리에 들어갈 업데이트 확인 기반은 준비되었다.

- `SUFeedURL`: `https://postmelee.github.io/alhangeul-macos/appcast.xml`
- `SUPublicEDKey`: `5bIatnE362KFmrf9NneeE7gVvkKfTnWK7c26MwfFLSs=`
- `SUEnableInstallerLauncherService`: `true`
- `SUAutomaticallyUpdate`: `false`
- `SUEnableAutomaticChecks`: `true`

GitHub Pages에는 사용자 안내와 stable feed 위치가 준비되었다.

- 업데이트 안내: `https://postmelee.github.io/alhangeul-macos/updates/`
- appcast: `https://postmelee.github.io/alhangeul-macos/appcast.xml`

현재 `docs/appcast.xml`은 release item이 없는 skeleton이다. 이는 정상 상태다. 첫 공식 release DMG가 아직 없기 때문에 signed release item은 #166에서 생성된다.

## #166 인계 사항

#166 공식 릴리즈 실행 전에 반드시 해야 할 일:

1. Sparkle private key를 GitHub Actions secret `SPARKLE_ED_PRIVATE_KEY`로 등록한다.
2. `generate_keys -p` 출력 public key가 앱의 `SUPublicEDKey`와 일치하는지 확인한다.
3. `Release Publish DMG` workflow를 공식 release 기준 `draft=false`, `prerelease=false`로 실행한다.
4. workflow가 public DMG를 생성, 서명, 공증, staple, 업로드한 뒤 `docs/appcast.xml`을 Pages branch에 갱신하는지 확인한다.
5. release publish 후 `releases/latest`가 `v0.1.0` official release를 가리키는지 확인한다.
6. Pages 다운로드 버튼이 실제 DMG를 바로 내려주는지 확인한다.
7. `appcast.xml`에 signed release item이 포함되는지 확인한다.
8. 설치된 이전 build에서 `알한글 > 업데이트 확인...`을 눌러 업데이트 안내 UI를 확인한다.

## 실행하지 않은 범위

이번 task에서는 다음을 실행하지 않았다.

- public notarization submission
- GitHub Release publish
- Homebrew Cask 배포
- release tag 생성
- `SPARKLE_ED_PRIVATE_KEY` secret 등록
- 실제 “새 업데이트 있음” Sparkle UI 확인

실제 업데이트 안내 UI 확인은 signed appcast item과 public DMG가 있어야 의미가 있으므로 #166 공식 release 또는 별도 signed test feed가 필요하다.

## 결론

#177의 목표인 첫 출시 전 Sparkle 업데이트 확인 기반과 GitHub Pages appcast 준비는 완료되었다.

#166은 이제 release credential 확인, official release workflow 실행, appcast 갱신 결과 확인, 설치 앱의 업데이트 안내 UI smoke를 이어받으면 된다.
