# Task M010 #177 Stage 2 보고서

## 목표

HostApp에 Sparkle 2 기반 업데이트 확인 기능을 통합하고, sandboxed macOS 앱에서 Sparkle update install을 시작할 수 있는 기본 설정을 반영한다.

이번 단계에서는 GitHub Pages appcast 파일과 release workflow 갱신은 다루지 않고, 앱 바이너리에 들어가야 하는 Sparkle dependency, `Info.plist`, entitlement, 메뉴 명령을 구현했다.

## 변경 사항

### Sparkle dependency

`project.yml`에 Sparkle Swift Package를 추가했다.

```yaml
packages:
  Sparkle:
    url: https://github.com/sparkle-project/Sparkle
    exactVersion: 2.9.1
```

HostApp target에는 Sparkle package product를 dependency로 추가했다.

```yaml
- package: Sparkle
  product: Sparkle
```

`embed: true`는 package product에서 제거했다. XcodeGen이 `embed: true`를 package dependency에 적용하면 Sparkle framework copy 후 `Sparkle` 파일을 추가로 복사하려는 잘못된 build phase가 생겨 Debug build가 실패했다. `embed`를 지정하지 않아도 Xcode는 Sparkle binary framework를 앱 bundle `Contents/Frameworks/Sparkle.framework`로 복사했다.

`xcodebuild -resolvePackageDependencies` 실행 결과 `Alhangeul.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`가 생성되었고, Sparkle 2.9.1은 다음 revision으로 고정되었다.

```text
066e75a8b3e99962685d6a90cdd5293ebffd9261
```

### Sparkle key

Sparkle distribution의 `generate_keys`를 실행해 EdDSA key pair를 생성했다.

- private key: macOS login Keychain에 저장됨
- public key: `Sources/HostApp/Info.plist`의 `SUPublicEDKey`에 반영됨

반영된 public key:

```text
5bIatnE362KFmrf9NneeE7gVvkKfTnWK7c26MwfFLSs=
```

private key 값은 저장소에 커밋하지 않았다. Stage 4에서 CI signing에 필요한 key export/import 또는 GitHub Actions secret 운영 절차를 문서화해야 한다.

### Info.plist

`Sources/HostApp/Info.plist`에 Sparkle 기본 설정을 추가했다.

- `SUFeedURL`: `https://postmelee.github.io/alhangeul-macos/appcast.xml`
- `SUPublicEDKey`: 생성된 Sparkle public EdDSA key
- `SUEnableInstallerLauncherService`: `true`
- `SUEnableAutomaticChecks`: `true`
- `SUAutomaticallyUpdate`: `false`

자동 확인은 켜고, silent automatic install은 기본값으로 켜지지 않게 했다. 사용자는 앱 메뉴에서 수동으로 업데이트 확인을 실행할 수 있다.

### sandbox entitlement

`Sources/HostApp/HostApp.entitlements`에 Sparkle installer service 통신용 mach lookup temporary exception을 추가했다.

```xml
<key>com.apple.security.temporary-exception.mach-lookup.global-name</key>
<array>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)-spks</string>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)-spki</string>
</array>
```

HostApp은 이미 `com.apple.security.network.client`를 가지고 있으므로 `SUEnableDownloaderService`는 추가하지 않았다.

### 업데이트 확인 명령

`Sources/HostApp/Services/UpdateController.swift`를 추가했다.

역할:

- `SPUStandardUpdaterController`를 앱 lifetime 동안 보관
- `SPUUpdater.canCheckForUpdates`를 관찰해 메뉴 disabled state에 반영
- “업데이트 확인...” 메뉴에서 `checkForUpdates` 실행

`Sources/HostApp/HostApp.swift`에서는 `@StateObject`로 `UpdateController`를 보관하고, 기존 app menu command group에 “업데이트 확인...” 명령을 추가했다.

## 검증

```bash
xcodegen dump --type parsed-yaml
```

결과:

- Sparkle package `exactVersion: 2.9.1` 파싱 확인
- HostApp dependency로 Sparkle package product 확인

```bash
xcodegen generate
```

결과:

```text
Created project at /tmp/rhwp-mac-task177/Alhangeul.xcodeproj
```

```bash
xcodebuild -resolvePackageDependencies \
  -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -derivedDataPath build.noindex/DerivedData
```

결과:

```text
Resolved source packages:
  Sparkle: https://github.com/sparkle-project/Sparkle @ 2.9.1
```

```bash
plutil -lint Sources/HostApp/Info.plist Sources/HostApp/HostApp.entitlements
```

결과:

```text
Sources/HostApp/Info.plist: OK
Sources/HostApp/HostApp.entitlements: OK
```

```bash
plutil -extract SUFeedURL raw -o - Sources/HostApp/Info.plist
plutil -extract SUPublicEDKey raw -o - Sources/HostApp/Info.plist
```

결과:

```text
https://postmelee.github.io/alhangeul-macos/appcast.xml
5bIatnE362KFmrf9NneeE7gVvkKfTnWK7c26MwfFLSs=
```

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과:

```text
** BUILD SUCCEEDED **
```

빌드 검증은 별도 worktree에 `Frameworks/Rhwp.xcframework`가 없어 기존 로컬 산출물을 복사한 뒤 실행했다. `Frameworks/`는 ignore된 build artifact이며 이번 커밋에는 포함하지 않는다.

Sparkle framework와 XPC service 포함 여부도 확인했다.

```bash
find build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Frameworks/Sparkle.framework \
  -maxdepth 5 -type d -name '*.xpc' -print
```

결과:

```text
.../Sparkle.framework/Versions/B/XPCServices/Downloader.xpc
.../Sparkle.framework/Versions/B/XPCServices/Installer.xpc
```

`Downloader.xpc`는 Sparkle framework bundle에 포함되지만, HostApp에 `com.apple.security.network.client`가 있으므로 `SUEnableDownloaderService`는 켜지 않았다.

```bash
git diff --check
```

결과: 문제 없음.

## 리스크와 후속 처리

- `CODE_SIGNING_ALLOWED=NO` Debug build는 Sparkle install flow의 실제 교체 동작을 검증하지 못한다. signed/notarized install update smoke는 #166 release 실행 또는 후속 release smoke에서 확인한다.
- Sparkle private key는 현재 login Keychain에 생성되어 있다. Stage 4에서 CI appcast signing을 위해 private key export/import 또는 GitHub Actions secret 등록 절차를 명확히 해야 한다.
- Stage 3에서 GitHub Pages `docs/appcast.xml`, 업데이트 안내 페이지, direct DMG download 버튼을 추가해야 한다.
- Stage 4에서 release workflow가 DMG signature와 appcast item을 생성/갱신하도록 연결해야 한다.

## 다음 단계 승인 요청

Stage 3 `GitHub Pages 업데이트 안내와 직접 다운로드 버튼` 진행 승인을 요청한다.
