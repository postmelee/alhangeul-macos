# Task M010 #177 Stage 1 보고서

## 목표

Sparkle 2 기반 업데이트 확인과 GitHub Pages appcast 준비를 구현하기 전에 필요한 외부 요구사항과 현재 저장소 상태를 확정한다.

이번 단계에서는 소스 구현을 하지 않고, Stage 2-4에서 수정할 항목과 운영 결정을 정리했다.

## 공식 문서 확인

### Sparkle 기본 통합

확인 문서:

- https://sparkle-project.org/documentation/
- https://sparkle-project.org/documentation/programmatic-setup/

확인 결과:

- Swift Package Manager로 Sparkle을 추가할 수 있다.
- Sparkle 2의 새 통합은 `SPUStandardUpdaterController`를 기준으로 한다.
- SwiftUI 앱에서는 updater controller를 앱 수명에 맞춰 보관하고, commands 영역에 `Check for Updates...` 버튼을 연결하는 방식이 문서화되어 있다.
- update archive는 EdDSA 서명으로 보호한다.
- `generate_keys`로 private key를 만들고, 앱에는 `SUPublicEDKey`만 넣는다.
- appcast URL은 앱 `Info.plist`의 `SUFeedURL`에 넣는다.
- Sparkle은 `CFBundleVersion`을 기준으로 업데이트 여부를 비교하므로 release마다 build number 증가가 필요하다.
- Sparkle은 DMG 업데이트를 지원하므로 현재 public release 기준인 signed/notarized DMG를 그대로 update archive로 재사용할 수 있다.

### sandboxed app 요구사항

확인 문서:

- https://sparkle-project.org/documentation/sandboxing/

확인 결과:

- Sparkle 2는 sandboxed app을 지원한다.
- sandboxed app은 Installer XPC Service가 필요하고, 앱 `Info.plist`에 `SUEnableInstallerLauncherService = YES`를 넣어 활성화한다.
- installer tool과 통신하려면 entitlement에 다음 mach lookup temporary exception이 필요하다.

```xml
<key>com.apple.security.temporary-exception.mach-lookup.global-name</key>
<array>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)-spks</string>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)-spki</string>
</array>
```

- Downloader XPC Service는 앱에 `com.apple.security.network.client`가 없을 때만 필요하다.
- 현재 HostApp은 이미 `com.apple.security.network.client`를 가지고 있으므로 Stage 2에서는 Downloader Service를 켜지 않는다.

### appcast와 release item

확인 문서:

- https://sparkle-project.org/documentation/publishing/

확인 결과:

- appcast는 Sparkle 전용 RSS feed다.
- 각 release item은 `sparkle:version`, `sparkle:releaseNotesLink`, `pubDate`, `enclosure`를 포함한다.
- `enclosure`에는 DMG URL, `sparkle:edSignature`, byte length, `type="application/octet-stream"`을 넣는다.
- 이번 작업에서는 feed signing(`SURequireSignedFeed`)은 초기 범위에서 제외한다. update archive EdDSA signature를 우선 적용하고, signed feed는 첫 배포 이후 강화 후보로 남긴다.

### GitHub Release 직접 다운로드 URL

확인 문서:

- https://docs.github.com/en/repositories/releasing-projects-on-github/linking-to-releases
- https://docs.github.com/en/rest/releases/releases#get-the-latest-release

확인 결과:

- 최신 release asset 직접 다운로드 URL은 `/releases/latest/download/{asset-name}` 형식이 지원된다.
- GitHub의 latest release는 non-prerelease, non-draft release 기준이다.
- 현재 `.github/workflows/release-publish.yml` 기본값은 `draft=true`, `prerelease=true`이므로, v0.1을 기본값 그대로 게시하면 `releases/latest/download/...`가 첫 배포 DMG를 가리키지 않을 수 있다.
- 따라서 첫 v0.1 다운로드 버튼과 Sparkle appcast enclosure는 tag 고정 URL을 사용한다.

```text
https://github.com/postmelee/alhangeul-macos/releases/download/v0.1.0/alhangeul-macos-0.1.0.dmg
```

## 현재 저장소 상태

### GitHub Pages

현재 `docs/index.html`의 header 다운로드 버튼은 GitHub Release 목록으로 이동한다.

```text
docs/index.html:45
href="https://github.com/postmelee/alhangeul-macos/releases/latest"
```

FAQ도 “상단 다운로드 버튼은 GitHub Releases로 연결”된다고 설명한다. Stage 3에서 이 버튼과 FAQ를 직접 DMG 다운로드 기준으로 바꾼다.

### release workflow

현재 publish workflow는 다음 public artifact 이름을 사용한다.

```text
alhangeul-macos-$VERSION.dmg
alhangeul-macos-$VERSION.dmg.sha256
```

`VERSION=0.1.0`일 때 직접 다운로드 대상은 다음 파일이다.

```text
alhangeul-macos-0.1.0.dmg
```

workflow 기본값:

```text
draft=true
prerelease=true
```

이 기본값 때문에 `latest/download` 대신 tag 고정 URL을 v0.1 기준으로 선택한다.

### HostApp 설정

현재 HostApp:

- bundle identifier: `com.postmelee.alhangeul`
- `CFBundleShortVersionString`: `0.1.0`
- `CFBundleVersion`: `1`
- sandbox enabled
- `com.apple.security.network.client = true`

현재 `Info.plist`에는 Sparkle key가 없다.

- `SUFeedURL` 없음
- `SUPublicEDKey` 없음
- `SUEnableInstallerLauncherService` 없음

현재 `project.yml`에는 Swift Package dependency가 없다. Stage 2에서 XcodeGen `packages`와 target `dependencies`에 Sparkle을 추가한다.

### Sparkle release

GitHub release 조회 결과, 2026-05-08 기준 Sparkle 최신 안정 release는 다음이다.

```json
{"tagName":"2.9.1","name":"2.9.1 Appcast Improvements","publishedAt":"2026-03-29T23:30:46Z","isPrerelease":false,"isDraft":false}
```

Stage 2에서는 XcodeGen `packages`에 Sparkle `exactVersion: 2.9.1`을 우선 적용한다. release-critical dependency라서 floating update보다 재현 가능한 exact pin을 선택한다.

## 확정 결정

### 1. 앱이 바라볼 feed URL

첫 배포 앱의 `SUFeedURL`은 stable feed로 고정한다.

```text
https://postmelee.github.io/alhangeul-macos/appcast.xml
```

`appcast-prerelease.xml`은 Stage 3에서 skeleton을 만들 수 있지만, v0.1 앱 기본 feed로 사용하지 않는다. 별도 beta channel UI가 없으므로 첫 배포 앱이 prerelease feed를 직접 바라보게 만들지 않는다.

### 2. appcast item URL

Sparkle appcast enclosure는 GitHub Release tag 고정 URL을 사용한다.

```text
https://github.com/postmelee/alhangeul-macos/releases/download/v0.1.0/alhangeul-macos-0.1.0.dmg
```

이 URL은 #166에서 실제 release asset이 올라가기 전까지 404일 수 있다. 다만 #177은 #166 선행 작업이므로, Stage 3에서 skeleton과 경로를 먼저 넣고 #166에서 asset 게시로 완성하는 흐름을 유지한다.

### 3. Pages 다운로드 버튼

Stage 3에서 header 다운로드 버튼을 GitHub Release 목록이 아니라 DMG 직접 다운로드 URL로 변경한다.

```text
https://github.com/postmelee/alhangeul-macos/releases/download/v0.1.0/alhangeul-macos-0.1.0.dmg
```

FAQ에는 다음 기준을 반영한다.

- 다운로드 버튼은 DMG 직접 다운로드로 연결된다.
- 릴리스 전에는 파일이 아직 없을 수 있다.
- 문제가 있으면 GitHub Releases 목록에서 수동으로 확인할 수 있다.

`/releases/latest/download/...`는 v0.1을 full release로 게시하기로 결정될 때만 재검토한다.

### 4. Sparkle dependency

Stage 2에서 XcodeGen 설정은 다음 형태를 후보로 둔다.

```yaml
packages:
  Sparkle:
    url: https://github.com/sparkle-project/Sparkle
    exactVersion: 2.9.1
```

HostApp dependency는 다음 형태를 후보로 둔다.

```yaml
dependencies:
  - package: Sparkle
    product: Sparkle
    embed: true
```

XcodeGen 문서상 Swift Package는 top-level `packages`에 정의하고 target dependency에서 `package`/`product`로 참조한다.

### 5. HostApp updater 구조

Stage 2에서는 새 service를 추가한다.

```text
Sources/HostApp/Services/UpdateController.swift
```

역할:

- `SPUStandardUpdaterController`를 앱 lifetime 동안 보관
- SwiftUI command에서 `checkForUpdates` 호출
- 가능하면 `canCheckForUpdates`를 관찰해 메뉴 disabled state 반영

기존 `HostAppCommands`에 “업데이트 확인...” 항목을 추가한다.

### 6. Sparkle key 운영

`SUPublicEDKey`는 앱에 들어가야 하므로 Stage 2 전에 실제 public key가 필요하다.

결정:

- private key는 저장소에 기록하지 않는다.
- private key는 작업지시자가 로컬 Keychain 또는 GitHub Actions secret으로 관리한다.
- Stage 2 구현 전에 작업지시자가 Sparkle public EdDSA key를 제공하거나, 별도 승인으로 `generate_keys` 실행 절차를 진행한다.
- public key가 없으면 placeholder로 컴파일만 통과시키지 않는다. 첫 출시 앱에 잘못된 public key가 들어가면 이후 자동 업데이트 신뢰 체계가 깨지므로, Stage 2 진입 전에 key 확보를 blocker로 둔다.

## Stage 2 변경 범위 확정

Stage 2에서 수정할 파일:

- `project.yml`
- `Sources/HostApp/Info.plist`
- `Sources/HostApp/HostApp.entitlements`
- `Sources/HostApp/HostApp.swift`
- `Sources/HostApp/Services/UpdateController.swift`
- `Alhangeul.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` (package resolution 후 생성/갱신되는 경우)

Stage 2에서 아직 수정하지 않을 파일:

- `docs/index.html`
- `docs/appcast.xml`
- `.github/workflows/release-publish.yml`
- `scripts/ci/write-sparkle-appcast.sh`
- `mydocs/manual/release_distribution_guide.md`

위 파일은 Stage 3-4 범위로 남긴다.

## 검증

```bash
git status --short --branch
```

결과:

```text
## local/task177
```

```bash
rg -n "SUFeedURL|SUPublicEDKey|SUEnableInstaller|Sparkle|appcast|releases/latest|download" \
  project.yml Sources/HostApp docs .github/workflows scripts mydocs/manual/release_distribution_guide.md \
  -g '!Sources/HostApp/Resources/rhwp-studio/**'
```

결과:

- `docs/index.html` 다운로드 버튼이 `releases/latest` 페이지를 가리키는 현재 상태 확인
- `docs/styles.css`의 다운로드 버튼 styling 확인
- HostApp/project/release manual에는 아직 Sparkle/appcast 설정이 없는 상태 확인

```bash
gh release view --repo sparkle-project/Sparkle --json tagName,name,publishedAt,url,isPrerelease,isDraft
```

결과:

```json
{"isDraft":false,"isPrerelease":false,"name":"2.9.1 Appcast Improvements","publishedAt":"2026-03-29T23:30:46Z","tagName":"2.9.1","url":"https://github.com/sparkle-project/Sparkle/releases/tag/2.9.1"}
```

## 리스크와 후속 처리

- Stage 2는 Sparkle package fetch가 필요하므로 네트워크 또는 Xcode package resolution 실패 가능성이 있다.
- Sparkle public key가 없으면 Stage 2에서 올바른 `SUPublicEDKey`를 넣을 수 없다.
- `CODE_SIGNING_ALLOWED=NO` Debug build는 Sparkle install flow를 실제로 검증하지 못한다. Stage 2에서는 compile/config 검증까지 수행하고, public signed/notarized install update 검증은 #166 또는 후속 release smoke에서 분리한다.
- v0.1 release가 full release로 바뀌면 Pages 다운로드 버튼을 `releases/latest/download/...`로 바꿀 수 있지만, 현재 workflow 기본값은 prerelease라 tag 고정 URL이 더 안전하다.

## 다음 단계 승인 요청

Stage 2 `HostApp Sparkle 통합` 진행 승인을 요청한다.

Stage 2 진입 전 필요한 입력:

- Sparkle `SUPublicEDKey` 값

작업지시자가 public key 생성을 원하면, 다음 절차를 별도 승인 후 진행한다.

```bash
# Sparkle distribution의 generate_keys 실행
# 출력된 public key만 Info.plist에 기록
# private key는 저장소에 기록하지 않음
```
