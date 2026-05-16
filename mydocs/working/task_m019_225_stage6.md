# Task M019 #225 Stage 6 완료보고서

## 단계 목적

Stage 5 이후 GUI smoke와 System Settings 확인 중 발견된 Quick Look/Thumbnail extension 중복 등록, legacy `rhwpmac` UTI routing, 특정 thumbnail 크기 생성 불안정 의심을 build `6` 후보로 보정하고 검증했다.

public Developer ID 서명, notarization, GitHub Release, stable appcast, actual Sparkle update는 실행하지 않았다.

## 원인 분석

현재 active provider는 Stage 5 설치본 기준으로 `/Users/melee/Applications/Alhangeul.app` 내부 Preview/Thumbnail appex가 맞았다. 다만 fresh sample의 `mdls`가 다음처럼 과거 개발 설치본의 UTI로 분류되는 상태가 남아 있었다.

```text
kMDItemContentType = "com.postmelee.rhwpmac.hwp"
kMDItemContentType = "com.postmelee.rhwpmac.hwpx"
```

`pluginkit`에는 현재 `com.postmelee.alhangeul.*` extension만 active였지만, LaunchServices에는 이전 `RhwpMac` 계열 UTI가 남아 Finder content type routing을 흐릴 수 있었다. 기존 build `5` extension은 이 legacy UTI를 `QLSupportedContentTypes`에 포함하지 않았으므로 Finder가 파일을 legacy UTI로 분류하는 사용자 환경에서 thumbnail 요청이 current provider로 안정적으로 전달되지 않을 수 있었다.

또한 Xcode build는 `RegisterWithLaunchServices` 단계에서 `build.noindex/` 또는 Xcode DerivedData 산출물을 자동 등록할 수 있다. 이 등록은 파일을 삭제하지 않아도 System Settings의 extension 목록을 늘리고 검증 대상을 혼동시킬 수 있으므로 smoke 절차에서 개발 산출물 등록을 해제해야 한다.

## 변경 사항

| 파일 | 변경 | 요약 |
|------|------|------|
| `Sources/HostApp/Info.plist` | 수정 | `CFBundleVersion=6`, legacy `com.postmelee.alhangeulmac.*`, `com.postmelee.rhwpmac.*` UTI를 document type/imported type에 추가 |
| `Sources/QLExtension/Info.plist` | 수정 | `CFBundleVersion=6`, legacy HWP/HWPX UTI를 `QLSupportedContentTypes`에 추가 |
| `Sources/ThumbnailExtension/Info.plist` | 수정 | `CFBundleVersion=6`, legacy HWP/HWPX UTI를 `QLSupportedContentTypes`에 추가 |
| `scripts/smoke-clean-quicklook-install.sh` | 수정 | smoke 설치 전 `build.noindex/`와 Xcode DerivedData의 개발/테스트용 `Alhangeul.app` 등록을 파일 삭제 없이 해제 |
| `AGENTS.md` | 수정 | Debug/테스트용 Quick Look/Thumbnail 등록은 표준 smoke 절차 안에서만 수행하고 종료 시 개발 산출물 등록을 해제하도록 강제 규칙 추가 |
| `mydocs/manual/build_run_guide.md` | 수정 | 반복 smoke 중 등록/해제 규칙과 표준 helper 동작 보강 |
| `mydocs/troubleshootings/finder_integration_validation_pitfalls.md` | 수정 | 현재 이름 개발 산출물 등록 처리와 legacy UTI 진단 기준 추가 |
| `README.md`, `docs/updates/v0.1.2.html`, `.github/workflows/pr-ci.yml`, `mydocs/release/v0.1.2.md` | 수정 | v0.1.2 build `6`, legacy UTI compatibility, 검증 결과 반영 |

## 검증 결과

### plist와 build

```text
$ plutil -lint Sources/HostApp/Info.plist Sources/QLExtension/Info.plist Sources/ThumbnailExtension/Info.plist
Sources/HostApp/Info.plist: OK
Sources/QLExtension/Info.plist: OK
Sources/ThumbnailExtension/Info.plist: OK

$ xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
** BUILD SUCCEEDED ** [7.388 sec]
```

기본 sandbox 실행은 SwiftPM/Clang cache 권한으로 실패했고 승인 경로 재실행으로 통과했다.

### Release rehearsal

```text
$ ./scripts/release.sh --skip-notarize 0.1.2
** BUILD SUCCEEDED ** [25.833 sec]
hdiutil: verify: checksum of ".../alhangeul-macos-0.1.2-rehearsal.dmg" is VALID
```

Rehearsal DMG:

```text
9991285e9cb26875ae5a0dde5f42ff8be69802f9af4b9d97821f613ed23d9fca  build.noindex/release/alhangeul-macos-0.1.2-rehearsal.dmg
```

`build.noindex/release/Alhangeul.app`의 app, Preview appex, Thumbnail appex 모두 `0.1.2 (6)`이고 실행 파일은 `x86_64 arm64` universal이다.

### active provider

```text
$ pluginkit -mAvvv -i com.postmelee.alhangeul.QLExtension
Path = /Users/melee/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulPreview.appex

$ pluginkit -mAvvv -i com.postmelee.alhangeul.ThumbnailExtension
Path = /Users/melee/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulThumbnail.appex
```

방금 설치한 build `6`가 현재 active provider임을 확인했다.

### clean Quick Look smoke

```text
$ ./scripts/smoke-clean-quicklook-install.sh --skip-package --app build.noindex/release/Alhangeul.app --install-app /Users/melee/Applications/Alhangeul.app --sample samples/basic/KTX.hwp --sample samples/hwpx/hwpx-01.hwpx
OK: clean Quick Look visual smoke setup complete
Installed app: /Users/melee/Applications/Alhangeul.app
Fresh samples: /private/tmp/alhangeul-visual-smoke/20260512-162418/samples
Generated thumbnails: /private/tmp/alhangeul-visual-smoke/20260512-162418/thumbnails
```

Crash check:

```text
$ /private/tmp/alhangeul-visual-smoke/20260512-162418/check-crashes.command
OK: no new AlhangeulPreview/AlhangeulThumbnail crash reports since smoke setup.
```

### Sparkle refresh helper

```text
$ ./scripts/smoke-sparkle-extension-refresh.sh --expected-version 0.1.2 --expected-build 6 --app /Users/melee/Applications/Alhangeul.app
OK: post-Sparkle extension refresh smoke passed
Expected: 0.1.2 (6)
Registration repair used: 0
```

### legacy UTI thumbnail 크기별 smoke

Fresh sample의 실제 `mdls` 결과가 legacy UTI인 상태에서 forced content type으로 HWP/HWPX 각각 `16`, `32`, `64`, `128`, `256`, `512`, `1024` 크기 thumbnail 생성을 확인했다.

```text
hwp  16    com.postmelee.rhwpmac.hwp   16x12
hwp  32    com.postmelee.rhwpmac.hwp   32x23
hwp  64    com.postmelee.rhwpmac.hwp   64x46
hwp  128   com.postmelee.rhwpmac.hwp   128x91
hwp  256   com.postmelee.rhwpmac.hwp   256x182
hwp  512   com.postmelee.rhwpmac.hwp   512x363
hwp  1024  com.postmelee.rhwpmac.hwp   1024x725
hwpx 16    com.postmelee.rhwpmac.hwpx  12x16
hwpx 32    com.postmelee.rhwpmac.hwpx  23x32
hwpx 64    com.postmelee.rhwpmac.hwpx  46x64
hwpx 128   com.postmelee.rhwpmac.hwpx  91x128
hwpx 256   com.postmelee.rhwpmac.hwpx  182x256
hwpx 512   com.postmelee.rhwpmac.hwpx  363x512
hwpx 1024  com.postmelee.rhwpmac.hwpx  725x1024
```

`-c` 없이 Finder/Quick Look default routing에 맡긴 경우도 `16`, `512`, `1024`에서 HWP/HWPX 모두 PNG가 생성됐다.

## 결론

Stage 5에서 확인된 thumbnail 크기 문제는 provider 렌더러의 특정 크기 실패로 재현되지 않았다. build `6`에서는 현재 설치본 provider가 active이고, Finder가 파일을 legacy `rhwpmac` UTI로 분류하는 경우에도 Preview/Thumbnail extension이 해당 UTI를 수용한다.

중복 extension 목록 문제는 Xcode/테스트 산출물 등록이 남는 운영 문제로 분리했다. 표준 smoke helper와 문서 규칙을 보강했으므로 앞으로 Debug/테스트 등록은 smoke 절차 안에서만 수행하고 개발 산출물 등록은 종료 시 해제한다.

## 미실행 항목

| 항목 | 사유 |
|------|------|
| build 6 GUI About 재확인 | Stage 6 변경은 version/build metadata와 UTI registration surface 중심이며, About provenance 시각 확인은 Stage 5 build 5에서 수행 |
| Developer ID signing / notarization | public release 승인 전 단계 |
| actual Sparkle update from public v0.1.1 | public v0.1.2 signed/notarized asset과 appcast가 아직 없음 |
| Intel Mac 실기기 smoke | 현재 접근 가능한 환경에서 실행하지 않음 |

## 다음 단계 영향

다음 단계에서는 Stage 6 변경을 커밋한 뒤 최종 보고서와 PR 게시 절차로 넘어간다. public 배포 명령은 여전히 main merge와 별도 승인 후에만 실행한다.
