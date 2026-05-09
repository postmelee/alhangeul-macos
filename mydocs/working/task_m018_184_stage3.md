# Task M018 #184 Stage 3 완료 보고서

## 단계 목적

`--skip-notarize` rehearsal DMG를 실제 생성하고 mount해 Stage 2에서 구현한 DMG 설치 안내 layout이 산출물에 포함되는지 확인한다.

## 산출물

- `scripts/release.sh`
  - 총 514라인
  - Stage 3 첫 rehearsal에서 발견한 Finder background alias 지정 오류를 보정했다.
- `build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg`
  - rehearsal DMG 산출물
  - 크기: 약 59 MB
  - SHA256: `2c822d5c5da9237ebfc86bc17bf2d25fc533e16d29c61801a896dc96e92adc25`
- `build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg.sha256`
  - rehearsal checksum 파일
- `mydocs/working/task_m018_184_stage3.md`
  - Stage 3 검증 결과와 잔여 위험 기록

## 본문 변경 정도 / 본문 무손실 여부

제품 본문, 앱 source, Quick Look/Thumbnail extension 구현은 변경하지 않았다.

Stage 3 중 `scripts/release.sh`의 AppleScript 한 곳만 수정했다. 기존 표현식은 Finder object path로 background image를 지정했지만, rehearsal DMG 생성 중 Finder가 `.background/alhangeul-dmg-background.png`를 `background picture`로 설정하지 못했다. 이를 mounted volume의 POSIX path alias로 바꿔 같은 layout 의미를 유지하면서 Finder AppleScript가 안정적으로 처리하게 했다.

## 검증 결과

현재 버전 확인:

```text
$ plutil -extract CFBundleShortVersionString raw -o - Sources/HostApp/Info.plist
0.1.0

$ plutil -extract CFBundleShortVersionString raw -o - Sources/QLExtension/Info.plist
0.1.0

$ plutil -extract CFBundleShortVersionString raw -o - Sources/ThumbnailExtension/Info.plist
0.1.0
```

`0.1.1` version bump는 아직 반영되지 않았으므로 rehearsal DMG는 현재 source version인 `0.1.0`으로 생성했다.

첫 rehearsal 시도:

```text
$ ./scripts/release.sh --skip-notarize 0.1.0
...
INFO: Creating DMG
created: .../build.noindex/release/staging/alhangeul-macos-0.1.0-layout.dmg
execution error: Finder에 오류 발생: folder ".background" ... 을(를) file "alhangeul-dmg-background.png" ... (으)로 설정할 수 없습니다. (-10006)
```

회복 조치:

- `scripts/release.sh`의 AppleScript에서 `backgroundPath`를 만든 뒤 `POSIX file backgroundPath as alias`로 `background picture`를 설정하도록 수정했다.
- 수정 후 `bash -n scripts/release.sh`, `shellcheck scripts/release.sh`, `git diff --check`가 통과했다.

최종 rehearsal DMG 생성:

```text
$ ./scripts/release.sh --skip-notarize 0.1.0
...
** BUILD SUCCEEDED ** [23.054 sec]
WARN: Skipping codesign verification because this rehearsal build is unsigned.
INFO: Creating DMG
created: .../build.noindex/release/staging/alhangeul-macos-0.1.0-layout.dmg
created: .../build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg
WARN: Skipping DMG signing because this rehearsal build is unsigned.
INFO: Verifying rehearsal DMG
hdiutil: verify: checksum of ".../alhangeul-macos-0.1.0-rehearsal.dmg" is VALID
INFO: Writing sha256 checksum
INFO: Release artifact: .../build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg
INFO: Checksum: .../build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg.sha256
WARN: Rehearsal artifact complete. Do not use it for public release or Homebrew Cask.
```

별도 DMG verify:

```text
$ hdiutil verify build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg
hdiutil: verify: checksum of "build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg" is VALID
확인됨 CRC32 $308FC55F
```

checksum 검증:

```text
$ shasum -a 256 -c alhangeul-macos-0.1.0-rehearsal.dmg.sha256
alhangeul-macos-0.1.0-rehearsal.dmg: OK
```

산출물:

```text
$ ls -lh build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg.sha256 build.noindex/release/Alhangeul.app
-rw-r--r--@ 1 melee  staff    59M May  9 19:58 build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg
-rw-r--r--@ 1 melee  staff   102B May  9 19:58 build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg.sha256

build.noindex/release/Alhangeul.app:
total 0
drwxr-xr-x@ 8 melee  staff   256B May  9 19:58 Contents
```

mounted DMG 구조:

```text
$ hdiutil attach build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg -mountpoint /private/tmp/alhangeul-stage3-dmg -readonly -noverify -noautoopen -nobrowse
/dev/disk14         	GUID_partition_scheme
/dev/disk14s1       	Apple_HFS                      	/private/tmp/alhangeul-stage3-dmg

$ ls -la /private/tmp/alhangeul-stage3-dmg
.DS_Store
.background
Alhangeul.app
Applications -> /Applications
설치 안내.txt
```

안내 텍스트:

```text
$ cat /private/tmp/alhangeul-stage3-dmg/설치\ 안내.txt
Alhangeul.app을 Applications로 드래그해 설치하세요.

설치 후 Alhangeul.app을 한 번 실행하면 macOS가 Quick Look 및 Thumbnail 확장을 등록합니다.
등록 후 Finder에서 .hwp 또는 .hwpx 파일을 선택하고 Space를 눌러 미리보기를 확인할 수 있습니다.

Drag Alhangeul.app to Applications.
Launch once after installing to enable Quick Look and thumbnails.
```

background asset:

```text
$ file /private/tmp/alhangeul-stage3-dmg/.background/alhangeul-dmg-background.png
PNG image data, 720 x 460, 8-bit/color RGBA, non-interlaced

$ sips -g pixelWidth -g pixelHeight /private/tmp/alhangeul-stage3-dmg/.background/alhangeul-dmg-background.png
pixelWidth: 720
pixelHeight: 460
```

Finder layout metadata:

```text
$ strings /private/tmp/alhangeul-stage3-dmg/.DS_Store
...
backgroundImageAlias
alhangeul-dmg-background.png
.background
WindowBounds
{{120, 402}, {720, 460}}
...
```

Finder 창 속성:

```text
$ osascript ... /private/tmp/alhangeul-stage3-dmg
bounds=120120840580
toolbar=false
statusbar=false
iconSize=96
appPosition=178268
applicationsPosition=542268
```

Finder item 위치:

```text
$ osascript ... /private/tmp/alhangeul-stage3-dmg
items=Alhangeul.app@178268;Applications@542268;설치 안내.txt@360392;
```

mount 해제:

```text
$ hdiutil detach /dev/disk14
"disk14" ejected.
```

최종 source 검증:

```text
$ bash -n scripts/release.sh
# 출력 없음, 성공

$ shellcheck scripts/release.sh
# 출력 없음, 성공

$ git diff --check
# 출력 없음, 성공
```

## 잔여 위험

- 이번 단계의 DMG는 unsigned rehearsal 산출물이므로 public release, Cask digest, Gatekeeper 최종 판단에는 사용하지 않는다.
- Finder background picture 속성을 AppleScript로 직접 문자열화하는 검사는 Finder AppleEvent 오류로 실패했다. 대신 `.DS_Store`의 `backgroundImageAlias`, background PNG 파일 존재, Finder 창 bounds/icon position을 확인했다.
- signed/notarized public DMG에서 Finder metadata가 동일하게 유지되는지는 #188 public release 실행 시 다시 확인해야 한다.
- 한글 파일명은 mounted HFS+에서 decomposed form으로 보인다. Finder 표시상 문제는 확인하지 못했으므로 Stage 4 문서에 public smoke 항목으로 남긴다.

## 다음 단계 영향

Stage 4에서는 `release_distribution_guide.md`에 다음 기준을 추가한다.

- DMG layout smoke에서 app, Applications symlink, 설치 안내 텍스트, background image, Finder icon 위치를 확인한다.
- rehearsal DMG는 layout/checksum 검증용이며 public release 기준으로 사용하지 않는다.
- #188 public release 실행 시 signed/notarized DMG에서도 같은 layout smoke를 반복한다.

## 승인 요청

Stage 3 결과를 승인해주면 Stage 4 `Public release 호환성과 배포 가이드 보강`으로 진행한다.
