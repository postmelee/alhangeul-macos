# Task M019 #225 Stage 7 완료보고서

## 단계 목적

첫 public marketing release 전에는 기존 사용자가 없으므로 Stage 6의 legacy `RhwpMac`/`AlhangeulMac` UTI compatibility를 제품 후보에서 제외했다. build `7`에서는 앱 소유 UTI를 `com.postmelee.alhangeul.*`로 고정하고, Hancom 계열 UTI만 함께 지원하도록 release candidate를 respin했다.

public Developer ID 서명, notarization, GitHub Release, stable appcast, actual Sparkle update는 실행하지 않았다.

## 변경 사항

| 파일 | 변경 | 요약 |
|------|------|------|
| `Sources/HostApp/Info.plist` | 수정 | `CFBundleVersion=7`, document type/imported type에서 legacy `com.postmelee.alhangeulmac.*`, `com.postmelee.rhwpmac.*` 제거 |
| `Sources/QLExtension/Info.plist` | 수정 | `CFBundleVersion=7`, `QLSupportedContentTypes`를 current `com.postmelee.alhangeul.*`와 Hancom 계열 UTI로 제한 |
| `Sources/ThumbnailExtension/Info.plist` | 수정 | `CFBundleVersion=7`, `QLSupportedContentTypes`를 current `com.postmelee.alhangeul.*`와 Hancom 계열 UTI로 제한 |
| `.github/workflows/pr-ci.yml` | 수정 | Sparkle appcast helper dry-run build 기준을 `7`로 변경 |
| `README.md`, `docs/updates/v0.1.2.html`, `mydocs/release/v0.1.2.md` | 수정 | release candidate 설명을 build `7`과 current/Hancom UTI 정책 기준으로 갱신 |

## 검증 결과

### plist와 source UTI policy

```text
$ plutil -lint Sources/HostApp/Info.plist Sources/QLExtension/Info.plist Sources/ThumbnailExtension/Info.plist
Sources/HostApp/Info.plist: OK
Sources/QLExtension/Info.plist: OK
Sources/ThumbnailExtension/Info.plist: OK

$ rg -n 'alhangeulmac|rhwpmac' Sources project.yml .github/workflows/pr-ci.yml README.md docs/updates/v0.1.2.html
<no matches>
```

Stage 7 이후 제품 source와 public-facing 문서에는 legacy UTI 문자열이 없다. `mydocs/release/v0.1.2.md`에는 Stage 6의 폐기된 후보 기록으로만 legacy UTI가 남아 있다.

### Debug build

```text
$ xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
** BUILD SUCCEEDED ** [9.369 sec]
```

기본 sandbox 실행은 SwiftPM/Clang cache 권한으로 실패했고 승인 경로 재실행으로 통과했다.

Debug 산출물 확인:

```text
Alhangeul.app CFBundleVersion: 7
AlhangeulPreview.appex CFBundleVersion: 7
QLSupportedContentTypes:
  com.postmelee.alhangeul.hwp
  com.postmelee.alhangeul.hwpx
  com.hancom.hwp
  com.hancom.hwpx
  com.haansoft.hancomofficeviewer.mac.hwp
  com.haansoft.hancomofficeviewer.mac.hwpx
```

### Release rehearsal

```text
$ ./scripts/release.sh --skip-notarize 0.1.2
** BUILD SUCCEEDED ** [27.406 sec]
hdiutil: verify: checksum of ".../alhangeul-macos-0.1.2-rehearsal.dmg" is VALID
```

Rehearsal DMG:

```text
9ceb081d05d277a03f8a8ae9d0b8396180611f667658c2fb42d10f6d4b4510f7  alhangeul-macos-0.1.2-rehearsal.dmg
```

`build.noindex/release/Alhangeul.app`의 app, Preview appex, Thumbnail appex 모두 `0.1.2 (7)`이고 실행 파일은 `x86_64 arm64` universal이다.

### clean Quick Look smoke

```text
$ ./scripts/smoke-clean-quicklook-install.sh --skip-package --app build.noindex/release/Alhangeul.app --install-app /Users/melee/Applications/Alhangeul.app --sample samples/basic/KTX.hwp --sample samples/hwpx/hwpx-01.hwpx
OK: clean Quick Look visual smoke setup complete
Installed app: /Users/melee/Applications/Alhangeul.app
Fresh samples: /private/tmp/alhangeul-visual-smoke/20260512-172947/samples
Generated thumbnails: /private/tmp/alhangeul-visual-smoke/20260512-172947/thumbnails
```

이 smoke는 `.hwp`/`.hwpx`를 각각 current `com.postmelee.alhangeul.hwp`, `com.postmelee.alhangeul.hwpx`로 강제 지정해 thumbnail을 생성한다.

Crash check:

```text
$ /private/tmp/alhangeul-visual-smoke/20260512-172947/check-crashes.command
OK: no new AlhangeulPreview/AlhangeulThumbnail crash reports since smoke setup.
```

### Hancom 계열 UTI forced routing

같은 build `7` 설치본에서 Hancom 계열 UTI 4종을 forced content type으로 지정해 thumbnail 생성을 확인했다.

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
$ ./scripts/smoke-sparkle-extension-refresh.sh --expected-version 0.1.2 --expected-build 7 --app /Users/melee/Applications/Alhangeul.app
OK: post-Sparkle extension refresh smoke passed
Expected: 0.1.2 (7)
Registration repair used: 0
```

### Appcast helper

```text
$ scripts/ci/write-sparkle-appcast.sh --version 0.1.2 --build 7 ...
$ xmllint --noout build.noindex/release/appcast.xml
```

생성된 helper appcast에는 `sparkle:version=7`, `sparkle:shortVersionString=0.1.2`가 들어 있다.

### local cleanup

Smoke 후 임시 설치본을 유지하지 않기 위해 다음 정리를 수행했다.

```text
pluginkit -r /Users/melee/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulPreview.appex
pluginkit -r /Users/melee/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulThumbnail.appex
lsregister -u /Users/melee/Applications/Alhangeul.app
mv /Users/melee/Applications/Alhangeul.app /private/tmp/alhangeul-build7-smoke-installed-20260512-1732/Alhangeul.app
qlmanage -r cache
qlmanage -r
```

정리 후 `/Users/melee/Applications/Alhangeul.app`는 없고, PlugInKit 조회에서 `com.postmelee.alhangeul.QLExtension`과 `com.postmelee.alhangeul.ThumbnailExtension`은 `no matches`다.

## 결론

build `7` release candidate는 legacy `rhwpmac`/`alhangeulmac` UTI 지원을 제거했고, 앱 소유 UTI를 `com.postmelee.alhangeul.*`로 고정했다. Hancom 계열 UTI는 Preview/Thumbnail provider 지원 목록과 forced thumbnail smoke에서 확인됐다.

현재 로컬은 smoke 설치본을 해제한 상태이므로, public signed/notarized DMG가 준비되면 첫 사용자 설치 시나리오로 다시 테스트할 수 있다.

## 미실행 항목

| 항목 | 사유 |
|------|------|
| Developer ID signing / notarization | public release 승인 전 단계 |
| public DMG Gatekeeper 설치 테스트 | signed/notarized public DMG가 아직 없음 |
| actual Sparkle update from public v0.1.1 | public v0.1.2 signed/notarized asset과 appcast가 아직 없음 |
| Intel Mac 실기기 smoke | 현재 접근 가능한 환경에서 실행하지 않음 |

## 다음 단계 영향

다음 단계에서는 Stage 7 변경을 커밋한 뒤 최종 보고서와 PR 게시 절차로 넘어간다. public 배포 명령은 여전히 main merge와 별도 승인 후에만 실행한다.
