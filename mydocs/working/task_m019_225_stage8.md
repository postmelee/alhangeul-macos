# Task M019 #225 Stage 8 완료보고서

## 단계 목적

#235의 Web viewer runtime 오류 banner UX가 `devel-webview`에 merge된 뒤, 해당 변경을 #225 release candidate에 포함했다. build `7`은 #235 이전 후보였으므로, 최종 public release 후보를 build `8`로 respin하고 local/rehearsal 검증을 반복했다.

public Developer ID 서명, notarization, GitHub Release, stable appcast, actual Sparkle update는 실행하지 않았다.

## 변경 사항

| 파일 | 변경 | 요약 |
|------|------|------|
| `Sources/HostApp/Info.plist` | 수정 | `CFBundleVersion=8`로 증가 |
| `Sources/QLExtension/Info.plist` | 수정 | Preview extension `CFBundleVersion=8`로 증가 |
| `Sources/ThumbnailExtension/Info.plist` | 수정 | Thumbnail extension `CFBundleVersion=8`로 증가 |
| `.github/workflows/pr-ci.yml` | 수정 | Sparkle appcast helper dry-run build 기준을 `8`로 변경 |
| `README.md`, `docs/updates/v0.1.2.html`, `mydocs/release/v0.1.2.md` | 수정 | #235 runtime error banner 포함 사실과 build `8` release candidate 검증 결과 반영 |

## 검증 결과

### plist와 Debug build

```text
$ plutil -lint Sources/HostApp/Info.plist Sources/QLExtension/Info.plist Sources/ThumbnailExtension/Info.plist
Sources/HostApp/Info.plist: OK
Sources/QLExtension/Info.plist: OK
Sources/ThumbnailExtension/Info.plist: OK

$ xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
** BUILD SUCCEEDED ** [5.974 sec]
```

Debug 산출물의 HostApp `CFBundleShortVersionString`은 `0.1.2`, `CFBundleVersion`은 `8`이다. Preview/Thumbnail supported content type은 current `com.postmelee.alhangeul.*`와 Hancom 계열 UTI만 포함한다.

### Release rehearsal

```text
$ ./scripts/release.sh --skip-notarize 0.1.2
** BUILD SUCCEEDED ** [25.758 sec]
hdiutil: verify: checksum of ".../alhangeul-macos-0.1.2-rehearsal.dmg" is VALID
```

Rehearsal DMG:

```text
e0c25bd72f64bc4fabbde97c62e92e4f391aad133b0ee9f41dd9a542fa45771b  alhangeul-macos-0.1.2-rehearsal.dmg
```

`build.noindex/release/Alhangeul.app`의 app, Preview appex, Thumbnail appex 모두 `0.1.2 (8)`이고 실행 파일은 `x86_64 arm64` universal이다.

### Core, studio, renderer, release helper

```text
$ scripts/verify-rhwp-studio-assets.sh
OK: rhwp-studio assets verified at .../Sources/HostApp/Resources/rhwp-studio

$ ./scripts/validate-stage3-render.sh
OK KTX.hwp: page=1 ...
OK request.hwp: page=1 ...
OK exam_kor.hwp: page=1 ...

$ scripts/ci/write-sparkle-appcast.sh --version 0.1.2 --build 8 ...
$ xmllint --noout build.noindex/release/appcast.xml

$ scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.2.md
Release note template check passed: build.noindex/release/release-notes-0.1.2.md
```

`validate-stage3-render.sh`는 기존 layout overflow 진단 로그를 남겼지만 실패 없이 세 샘플 PNG를 생성했다. appcast helper 결과에는 `sparkle:version=8`, `sparkle:shortVersionString=0.1.2`가 들어 있다.

### clean Quick Look smoke

```text
$ ./scripts/smoke-clean-quicklook-install.sh --skip-package --app build.noindex/release/Alhangeul.app --install-app /Users/melee/Applications/Alhangeul.app --sample samples/basic/KTX.hwp --sample samples/hwpx/hwpx-01.hwpx
OK: clean Quick Look visual smoke setup complete
Installed app: /Users/melee/Applications/Alhangeul.app
Fresh samples: /private/tmp/alhangeul-visual-smoke/20260513-102822/samples
Generated thumbnails: /private/tmp/alhangeul-visual-smoke/20260513-102822/thumbnails
```

Smoke 중 PlugInKit는 Preview/Thumbnail 모두 `/Users/melee/Applications/Alhangeul.app/Contents/PlugIns/...` 경로의 build `8` provider를 가리켰다.

Crash check:

```text
$ /private/tmp/alhangeul-visual-smoke/20260513-102822/check-crashes.command
OK: no new AlhangeulPreview/AlhangeulThumbnail crash reports since smoke setup.
```

### Hancom 계열 UTI forced routing

같은 build `8` 설치본에서 Hancom 계열 UTI 4종을 forced content type으로 지정해 thumbnail 생성을 확인했다.

```text
$ qlmanage -t -x -s 768 -c com.hancom.hwp -o ... samples/basic/KTX.hwp
produced one thumbnail

$ qlmanage -t -x -s 768 -c com.haansoft.hancomofficeviewer.mac.hwp -o ... samples/basic/KTX.hwp
produced one thumbnail

$ qlmanage -t -x -s 768 -c com.hancom.hwpx -o ... samples/hwpx/hwpx-01.hwpx
produced one thumbnail

$ qlmanage -t -x -s 768 -c com.haansoft.hancomofficeviewer.mac.hwpx -o ... samples/hwpx/hwpx-01.hwpx
produced one thumbnail
```

### Sparkle refresh helper

```text
$ ./scripts/smoke-sparkle-extension-refresh.sh --expected-version 0.1.2 --expected-build 8 --app /Users/melee/Applications/Alhangeul.app
OK: post-Sparkle extension refresh smoke passed
Expected: 0.1.2 (8)
Registration repair used: 0
```

### local cleanup

Smoke 후 임시 설치본을 유지하지 않기 위해 등록을 해제하고 app bundle을 `/private/tmp`로 이동했다.

```text
Archived installed app: /private/tmp/alhangeul-build8-smoke-installed-20260513-103012/Alhangeul.app
```

정리 후 `pluginkit -mAvvv -i com.postmelee.alhangeul.QLExtension`과 `com.postmelee.alhangeul.ThumbnailExtension`은 모두 `no matches`다. LaunchServices dump에서도 `/Users/melee/Applications/Alhangeul.app`, `build.noindex` Debug app, release staging app, Sparkle Updater helper 경로가 검출되지 않는다.

## 결론

build `8` release candidate는 #235를 포함하고, 앱/Preview/Thumbnail metadata, current/Hancom UTI policy, release rehearsal DMG, Quick Look/Thumbnail smoke, Sparkle refresh helper를 통과했다. 현재 로컬에는 smoke 설치본이 남아 있지 않다.

## 미실행 항목

| 항목 | 사유 |
|------|------|
| Developer ID signing / notarization | public release workflow 실행 전 단계 |
| public DMG Gatekeeper 설치 테스트 | signed/notarized public DMG가 아직 없음 |
| actual Sparkle update from public v0.1.1 | public v0.1.2 signed/notarized asset과 stable appcast가 아직 없음 |
| Intel Mac 실기기 smoke | 현재 접근 가능한 환경에서 실행하지 않음 |

## 다음 단계 영향

다음 단계에서는 Stage 8 변경을 커밋한 뒤 최종 보고서와 PR 게시 절차로 넘어간다. public 배포 명령은 `devel-webview` 및 `main` 반영과 release tag 생성 후 실행한다.
