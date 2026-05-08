# Task #104 Stage 5 완료 보고서 - Release 앱 등록과 extension smoke 검증

## 목적

`rhwp v0.7.9` bridge 산출물을 포함한 Release package를 생성하고, 표준 사용자 설치 위치인 `$HOME/Applications/AlhangeulMac.app`에 등록해 Quick Look preview, Thumbnail, viewer 검증이 가능한 상태로 만든다.

## Release package

실행 명령:

```bash
./scripts/package-release.sh 0.1.0
```

결과:

```text
** BUILD SUCCEEDED ** [17.006 sec]
c96ce24dfef7f0af996d84a096130a321ee973169b03b70a512cd7b9fe77af19  alhangeul-macos-0.1.0.zip
```

생성 산출물:

```text
build.noindex/release/AlhangeulMac.app
build.noindex/release/alhangeul-macos-0.1.0.zip
```

zip hash:

```text
c96ce24dfef7f0af996d84a096130a321ee973169b03b70a512cd7b9fe77af19  build.noindex/release/alhangeul-macos-0.1.0.zip
```

Release package app/extension version:

```text
AlhangeulMac.app:             0.1.0 (1)
AlhangeulMacPreview.appex:    0.1.0 (1)
AlhangeulMacThumbnail.appex:  0.1.0 (1)
```

## 설치와 등록

Release 산출물을 표준 설치 위치로 교체했다.

```text
/Users/melee/Applications/AlhangeulMac.app
```

실행한 등록 절차:

```bash
lsregister -u "$HOME/Applications/AlhangeulMac.app"
ditto build.noindex/release/AlhangeulMac.app "$HOME/Applications/AlhangeulMac.app"
lsregister -f -R -trusted "$HOME/Applications/AlhangeulMac.app"
pluginkit -a "$HOME/Applications/AlhangeulMac.app"
qlmanage -r
qlmanage -r cache
```

`xcodebuild`가 Release build product인 `build.noindex/release/AlhangeulMac.app`도 LaunchServices에 임시 등록해 같은 bundle id의 extension 후보가 중복된 것을 확인했다. 표준 설치본만 검증 대상으로 남기기 위해 build 산출물 등록을 해제하고 `$HOME/Applications` 설치본을 다시 등록했다.

정리 후 PlugInKit 확인 결과:

```text
com.postmelee.alhangeulmac.QLExtension(0.1.0)
Path = /Users/melee/Applications/AlhangeulMac.app/Contents/PlugIns/AlhangeulMacPreview.appex
Timestamp = 2026-05-01 04:01:15 +0000
SDK = com.apple.quicklook.preview
Parent Bundle = /Users/melee/Applications/AlhangeulMac.app

com.postmelee.alhangeulmac.ThumbnailExtension(0.1.0)
Path = /Users/melee/Applications/AlhangeulMac.app/Contents/PlugIns/AlhangeulMacThumbnail.appex
Timestamp = 2026-05-01 04:01:15 +0000
SDK = com.apple.quicklook.thumbnail
Parent Bundle = /Users/melee/Applications/AlhangeulMac.app
```

## Thumbnail smoke

실행 명령:

```bash
qlmanage -t -x -s 512 -o /private/tmp/rhwp-task104-ql-stage5 samples/basic/KTX.hwp
```

결과:

```text
Testing Quick Look thumbnails with files using server:
    samples/basic/KTX.hwp
* /Users/melee/Documents/projects/rhwp-mac/samples/basic/KTX.hwp produced one thumbnail
Done producing thumbnails
/private/tmp/rhwp-task104-ql-stage5/KTX.hwp.png: PNG image data, 512 x 363, 8-bit/color RGBA, non-interlaced
```

Thumbnail extension smoke는 통과했다.

## Quick Look preview smoke

실행 명령:

```bash
qlmanage -p -x -o /private/tmp/rhwp-task104-preview-stage5 samples/basic/KTX.hwp
qlmanage -p -x -o /private/tmp/rhwp-task104-preview-control README.md
```

`KTX.hwp`와 대조군인 `README.md` 모두 동일한 `qlmanage` 예외로 종료됐다.

```text
*** Terminating app due to uncaught exception 'NSInvalidArgumentException',
reason: '*** -[__NSDictionaryM setObject:forKey:]: key cannot be nil'
```

관련 system log:

```text
Unable to load host extension context class
Unable to initialize extension context class: (null)
An uncaught exception was raised outside of any generator: *** -[__NSDictionaryM setObject:forKey:]: key cannot be nil
```

대조군 `README.md`에서도 같은 예외가 발생하므로, 이번 Stage 5에서는 `qlmanage -p` 기반 Preview 자동 smoke를 macOS 실행 환경의 공통 `qlmanage` preview harness 문제로 분리한다. AlhangeulMac Preview extension 자체는 PlugInKit에 `com.apple.quicklook.preview` SDK로 등록되어 있고, 설치 경로도 `$HOME/Applications/AlhangeulMac.app`로 정리됐다. Finder Quick Look 수동 검증은 등록 상태에서 가능하다.

## Viewer smoke

실행 명령:

```bash
open -n -a "$HOME/Applications/AlhangeulMac.app" samples/basic/KTX.hwp
pgrep -fl 'AlhangeulMac|AlhangeulMacHost'
osascript -e 'tell application "System Events" to get name of windows of process "AlhangeulMacHost"'
```

결과:

```text
/Users/melee/Applications/AlhangeulMac.app/Contents/MacOS/AlhangeulMacHost
알한글
```

설치된 Release 앱이 샘플 문서와 함께 실행되고 viewer window가 생성되는 것을 확인했다.

## 검증

실행한 명령:

```bash
./scripts/package-release.sh 0.1.0
ls -lh build.noindex/release/AlhangeulMac.app build.noindex/release/alhangeul-macos-0.1.0.zip
shasum -a 256 build.noindex/release/alhangeul-macos-0.1.0.zip
plutil -extract CFBundleShortVersionString raw -o - build.noindex/release/AlhangeulMac.app/Contents/Info.plist
plutil -extract CFBundleVersion raw -o - build.noindex/release/AlhangeulMac.app/Contents/Info.plist
plutil -extract CFBundleShortVersionString raw -o - build.noindex/release/AlhangeulMac.app/Contents/PlugIns/AlhangeulMacPreview.appex/Contents/Info.plist
plutil -extract CFBundleVersion raw -o - build.noindex/release/AlhangeulMac.app/Contents/PlugIns/AlhangeulMacPreview.appex/Contents/Info.plist
plutil -extract CFBundleShortVersionString raw -o - build.noindex/release/AlhangeulMac.app/Contents/PlugIns/AlhangeulMacThumbnail.appex/Contents/Info.plist
plutil -extract CFBundleVersion raw -o - build.noindex/release/AlhangeulMac.app/Contents/PlugIns/AlhangeulMacThumbnail.appex/Contents/Info.plist
lsregister -u "$HOME/Applications/AlhangeulMac.app"
ditto build.noindex/release/AlhangeulMac.app "$HOME/Applications/AlhangeulMac.app"
lsregister -f -R -trusted "$HOME/Applications/AlhangeulMac.app"
pluginkit -a "$HOME/Applications/AlhangeulMac.app"
pluginkit -mAvvv
qlmanage -r
qlmanage -r cache
qlmanage -t -x -s 512 -o /private/tmp/rhwp-task104-ql-stage5 samples/basic/KTX.hwp
qlmanage -p -x -o /private/tmp/rhwp-task104-preview-stage5 samples/basic/KTX.hwp
qlmanage -p -x -o /private/tmp/rhwp-task104-preview-control README.md
log show --last 3m --style compact --predicate 'process == "AlhangeulMacPreview" OR process == "qlmanage" OR eventMessage CONTAINS "QLExtension"'
open -n -a "$HOME/Applications/AlhangeulMac.app" samples/basic/KTX.hwp
pgrep -fl 'AlhangeulMac|AlhangeulMacHost'
osascript -e 'tell application "System Events" to get name of windows of process "AlhangeulMacHost"'
git status --short
```

검증 결과:

- Release package build 성공
- zip hash 확인 완료
- Release app/extension version `0.1.0 (1)` 확인
- `$HOME/Applications/AlhangeulMac.app` 설치 완료
- LaunchServices/PlugInKit 등록 완료
- build 산출물 중복 등록 정리 완료
- Quick Look cache reset 완료
- Thumbnail smoke 통과
- Viewer smoke 통과
- Preview extension 등록 확인 완료
- `qlmanage -p` preview 자동 smoke는 대조군에서도 같은 예외가 발생해 환경 이슈로 기록
- Stage 5 source 변경 없음

## 다음 단계

Stage 6에서는 지금까지의 변경과 검증 결과를 최종 문서에 정리하고, 작업 완료 보고와 PR 준비 단계로 넘어간다.
