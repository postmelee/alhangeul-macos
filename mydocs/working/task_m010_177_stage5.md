# Task M010 #177 Stage 5 보고서

## 목표

HostApp Sparkle 통합, GitHub Pages appcast/업데이트 안내, release workflow appcast 생성 경로를 통합 검증하고 #166 공식 릴리즈가 이어받을 gate를 정리한다.

이번 단계에서는 public notarization, GitHub Release publish, Homebrew Cask 배포, release tag 생성은 실행하지 않았다.

## 검증 결과

### 작업 상태

```bash
git status --short --branch
```

결과:

```text
## local/task177
```

### XcodeGen

```bash
xcodegen dump --type parsed-yaml
xcodegen generate
```

결과:

- `project.yml` 파싱 정상
- Sparkle package `exactVersion: 2.9.1` 확인
- HostApp target dependency에 Sparkle package product 확인
- `Alhangeul.xcodeproj` 재생성 완료

### plist와 entitlement

```bash
plutil -lint Sources/HostApp/Info.plist Sources/HostApp/HostApp.entitlements
plutil -extract SUFeedURL raw -o - Sources/HostApp/Info.plist
plutil -extract SUPublicEDKey raw -o - Sources/HostApp/Info.plist
plutil -extract SUEnableInstallerLauncherService raw -o - Sources/HostApp/Info.plist
plutil -p Sources/HostApp/HostApp.entitlements
```

결과:

- `Sources/HostApp/Info.plist`: OK
- `Sources/HostApp/HostApp.entitlements`: OK
- `SUFeedURL`: `https://postmelee.github.io/alhangeul-macos/appcast.xml`
- `SUPublicEDKey`: `5bIatnE362KFmrf9NneeE7gVvkKfTnWK7c26MwfFLSs=`
- `SUEnableInstallerLauncherService`: `true`
- entitlement에 Sparkle installer service용 mach lookup exception 포함:
  - `$(PRODUCT_BUNDLE_IDENTIFIER)-spks`
  - `$(PRODUCT_BUNDLE_IDENTIFIER)-spki`

### appcast와 Pages 정적 파일

```bash
test -f docs/appcast.xml
xmllint --noout docs/appcast.xml
xmllint --xpath 'count(/rss/channel/item)' docs/appcast.xml
xmllint --xpath 'string(/rss/channel/link)' docs/appcast.xml
```

결과:

- `docs/appcast.xml` 존재
- XML 문법 오류 없음
- 현재 release item 수: `0`
- channel link: `https://postmelee.github.io/alhangeul-macos/updates/`

현재 `docs/appcast.xml`은 skeleton이다. #166 공식 release 실행 후 workflow가 signed release item을 추가하는 구조다.

로컬 정적 서버 확인:

```bash
python3 -m http.server 8000 --directory docs
curl -I http://localhost:8000/
curl -I http://localhost:8000/appcast.xml
curl -I http://localhost:8000/updates/
curl -I http://localhost:8000/updates/v0.1.0.html
```

결과:

- `/`: `HTTP/1.0 200 OK`
- `/appcast.xml`: `HTTP/1.0 200 OK`, `Content-type: application/xml`
- `/updates/`: `HTTP/1.0 200 OK`
- `/updates/v0.1.0.html`: `HTTP/1.0 200 OK`

### appcast 생성 script와 workflow

```bash
bash -n scripts/ci/write-sparkle-appcast.sh scripts/ci/write-release-notes.sh scripts/ci/import-developer-id-certificate.sh
bash scripts/ci/write-sparkle-appcast.sh --version 0.1.0 --build 1 \
  --dmg-url https://github.com/postmelee/alhangeul-macos/releases/download/v0.1.0/alhangeul-macos-0.1.0.dmg \
  --length 123456 \
  --ed-signature TEST_SIGNATURE \
  --release-notes-url https://postmelee.github.io/alhangeul-macos/updates/v0.1.0.html \
  --pub-date 'Sat, 09 May 2026 00:00:00 +0000' \
  --output /tmp/alhangeul-stage5-appcast.xml
xmllint --noout /tmp/alhangeul-stage5-appcast.xml
```

결과:

- shell script 문법 오류 없음
- fixture appcast 생성 성공
- 생성된 fixture XML 문법 오류 없음

생성 fixture 확인:

- `sparkle:version`: `1`
- `sparkle:shortVersionString`: `0.1.0`
- release notes URL: `https://postmelee.github.io/alhangeul-macos/updates/v0.1.0.html`
- enclosure URL: `https://github.com/postmelee/alhangeul-macos/releases/download/v0.1.0/alhangeul-macos-0.1.0.dmg`
- `sparkle:minimumSystemVersion`: `12.0`

```bash
ruby -e 'require "yaml"; Dir[".github/workflows/*.yml"].sort.each { |f| YAML.load_file(f); puts f }'
```

결과:

```text
.github/workflows/release-publish.yml
.github/workflows/release-rehearsal.yml
.github/workflows/rhwp-upstream-check.yml
```

Ruby 환경에서 `ffi` gem extension warning이 출력되었지만 YAML parse는 성공했다.

### HostApp Debug build

일반 sandbox 내부 실행은 SwiftPM/Xcode cache 경로 권한 때문에 package dependency resolve 단계에서 실패했다.

실패 원인:

```text
error opening '/Users/melee/.cache/clang/ModuleCache/Swift-BF86GRDXI25I.swiftmodule' for output: Operation not permitted
cannot open file '/Users/melee/Library/Caches/org.swift.swiftpm/manifests/ManifestLoading/sparkle.dia' for diagnostics emission
```

이후 Stage 5 검증용으로 권한 상승 실행을 승인받아 동일 빌드를 다시 실행했다.

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
Resolved source packages:
  Sparkle: https://github.com/sparkle-project/Sparkle @ 2.9.1
** BUILD SUCCEEDED **
```

빌드 산출물 확인:

```bash
find build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Frameworks/Sparkle.framework \
  -maxdepth 5 -type d -name '*.xpc' -print
plutil -extract SUFeedURL raw -o - build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Info.plist
plutil -extract SUPublicEDKey raw -o - build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Info.plist
plutil -extract SUEnableInstallerLauncherService raw -o - build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Info.plist
```

결과:

- Sparkle framework 포함
- `Downloader.xpc`, `Installer.xpc` 포함
- bundle `Info.plist`의 `SUFeedURL`, `SUPublicEDKey`, `SUEnableInstallerLauncherService` 값 확인

### 앱 내 업데이트 안내 smoke

이번 Stage 5에서 실제 “새 업데이트 있음” UI는 실행하지 않았다.

이유:

- 현재 `docs/appcast.xml`은 release item이 없는 skeleton이다.
- Sparkle이 업데이트 안내 화면을 띄우려면 현재 앱보다 높은 `sparkle:version`을 가진 signed appcast item과 해당 DMG가 필요하다.
- 실제 public GitHub Release와 signed appcast item은 #166에서 생성된다.

이번 단계에서 확인한 범위:

- 앱 메뉴에 `업데이트 확인...` command가 연결됨
- `UpdateController`가 `SPUStandardUpdaterController`와 `canCheckForUpdates`를 사용함
- 앱 bundle에 Sparkle feed URL과 public key가 포함됨
- appcast 생성 workflow가 official stable release에서 signed item을 만들 수 있게 연결됨

## #166 인계 gate

#166 공식 release preflight에서 다음을 확인해야 한다.

1. GitHub Actions secret `SPARKLE_ED_PRIVATE_KEY` 등록
2. `generate_keys -p` 출력 public key가 앱의 `SUPublicEDKey`와 같은지 확인
3. `Release Publish DMG` workflow를 `draft=false`, `prerelease=false`로 실행
4. workflow가 `docs/appcast.xml`을 Pages branch에 갱신했는지 확인
5. `https://github.com/postmelee/alhangeul-macos/releases/latest`가 `v0.1.0` 공식 release를 가리키는지 확인
6. `https://github.com/postmelee/alhangeul-macos/releases/latest/download/alhangeul-macos-0.1.0.dmg`가 실제 DMG를 내려주는지 확인
7. `https://postmelee.github.io/alhangeul-macos/appcast.xml`에 signed release item이 포함되는지 확인
8. 설치된 앱에서 `알한글 > 업데이트 확인...`을 눌러 업데이트 안내 UI를 확인

## 결론

Stage 5 기준 구현과 정적/빌드 검증을 완료했다.

첫 출시 앱은 Sparkle feed URL과 public key를 포함하고, GitHub Pages에는 stable appcast skeleton과 업데이트 안내 페이지가 있다. release publish workflow는 공식 release에서 signed appcast item을 생성하고 Pages branch의 `docs/appcast.xml`을 갱신하는 경로를 가진다.
