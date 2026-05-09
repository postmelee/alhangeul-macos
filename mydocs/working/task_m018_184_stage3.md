# Task M018 #184 Stage 3 완료 보고서

## 단계 목적

`--skip-notarize` rehearsal DMG를 실제 생성하고 mount해 Stage 2에서 구현한 DMG 설치 안내 layout이 산출물에 포함되는지 확인한다.

## 산출물

- `scripts/release.sh`
  - 총 497라인
  - Stage 3 첫 rehearsal에서 발견한 Finder background alias 지정 오류를 보정했다.
  - 사용자 screenshot 피드백에 따라 `설치 안내.txt` root 배치를 제거하고 Finder 창 높이를 보정했다.
- `scripts/create-dmg-background.swift`
  - 총 196라인
  - 상단 안내에서 영어 문구를 제거하고, 하단 안내 문구를 `설치 후 앱을 한 번 실행해야 Quick Look/Thumbnail이 활성화됩니다.`로 변경했다.
  - Finder item label과 겹치던 background 내 app/Applications label을 제거했다.
  - 사용자 시각 검증 결과를 반영해 상단 앱명을 `알한글.app`으로 고치고, 안내 텍스트 세로 중앙 정렬과 화살표 머리 방향을 보정했다.
- `build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg`
  - rehearsal DMG 산출물
  - 크기: 약 59 MB
  - SHA256: `0bbc54790aff25c0236ec0630812aa78d33f8989f528f23ae61d6777779482ee`
- `build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg.sha256`
  - rehearsal checksum 파일
- `mydocs/working/task_m018_184_stage3.md`
  - Stage 3 검증 결과와 잔여 위험 기록

## 본문 변경 정도 / 본문 무손실 여부

제품 본문, 앱 source, Quick Look/Thumbnail extension 구현은 변경하지 않았다.

Stage 3 중 `scripts/release.sh`의 AppleScript 한 곳을 수정했다. 기존 표현식은 Finder object path로 background image를 지정했지만, rehearsal DMG 생성 중 Finder가 `.background/alhangeul-dmg-background.png`를 `background picture`로 설정하지 못했다. 이를 mounted volume의 POSIX path alias로 바꿔 같은 layout 의미를 유지하면서 Finder AppleScript가 안정적으로 처리하게 했다.

사용자 screenshot 검토 결과, Finder 창이 한 화면에 전체 배경을 담지 못하고 `설치 안내.txt` 아이콘이 하단 안내 박스와 겹쳤다. `설치 안내.txt`는 background 안내, README, release guide와 정보가 중복되고 설치 첫 화면의 시각적 품질을 낮추므로 DMG root에서 제거했다. 접근성/대체 텍스트가 필요해지는 경우에는 root 아이콘 대신 release note 또는 배포 문서에 유지하는 편이 적합하다.

추가 사용자 시각 검증에서 다음 문제가 확인되어 `scripts/create-dmg-background.swift`를 한 번 더 보정했다.

- 상단 안내의 `Alhangeul.app` 표기가 실제 Finder 표시명인 `알한글.app`과 맞지 않았다.
- 상단/하단 안내 텍스트가 박스 안에서 세로 중앙 정렬로 보이지 않았다.
- 기존 화살표 머리가 곡선 접선 방향과 어긋나 어색하게 보였다.
- Retina 선명도 개선을 위해 multi-representation TIFF를 실험했으나, Finder가 2x representation을 실제 background 크기로 선택해 배경이 2배 확대되어 잘렸다. TIFF directory 순서를 1x 우선으로 바꿔도 같은 증상이 재현되어 최종적으로 안정적인 720x460 PNG background를 유지하기로 했다.

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
확인됨 CRC32 $EF0A001A
```

checksum 검증:

```text
$ shasum -a 256 -c alhangeul-macos-0.1.0-rehearsal.dmg.sha256
alhangeul-macos-0.1.0-rehearsal.dmg: OK

$ cat alhangeul-macos-0.1.0-rehearsal.dmg.sha256
0bbc54790aff25c0236ec0630812aa78d33f8989f528f23ae61d6777779482ee  alhangeul-macos-0.1.0-rehearsal.dmg
```

산출물:

```text
$ ls -lh build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg.sha256 build.noindex/release/Alhangeul.app
-rw-r--r--@ 1 melee  staff    59M May  9 20:54 build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg
-rw-r--r--@ 1 melee  staff   102B May  9 20:54 build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg.sha256

build.noindex/release/Alhangeul.app:
total 0
drwxr-xr-x@ 8 melee  staff   256B May  9 20:53 Contents
```

mounted DMG 구조:

```text
$ hdiutil attach build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg -mountpoint /private/tmp/alhangeul-stage3-dmg -readonly -noverify -noautoopen -nobrowse
/dev/disk14         	GUID_partition_scheme
/dev/disk14s1       	Apple_HFS                      	/private/tmp/alhangeul-stage3-dmg

$ find /private/tmp/alhangeul-stage3-dmg -maxdepth 2 -print
/private/tmp/alhangeul-stage3-dmg
/private/tmp/alhangeul-stage3-dmg/.background
/private/tmp/alhangeul-stage3-dmg/.background/alhangeul-dmg-background.png
/private/tmp/alhangeul-stage3-dmg/.DS_Store
/private/tmp/alhangeul-stage3-dmg/.fseventsd
/private/tmp/alhangeul-stage3-dmg/.fseventsd/0000000025faf1a2
/private/tmp/alhangeul-stage3-dmg/.fseventsd/0000000025faf1a3
/private/tmp/alhangeul-stage3-dmg/.fseventsd/fseventsd-uuid
/private/tmp/alhangeul-stage3-dmg/Alhangeul.app
/private/tmp/alhangeul-stage3-dmg/Alhangeul.app/Contents
/private/tmp/alhangeul-stage3-dmg/Applications
```

background asset:

```text
$ file /private/tmp/alhangeul-stage3-dmg/.background/alhangeul-dmg-background.png
PNG image data, 720 x 460, 8-bit/color RGBA, non-interlaced

$ sips -g pixelWidth -g pixelHeight /private/tmp/alhangeul-stage3-dmg/.background/alhangeul-dmg-background.png
pixelWidth: 720
pixelHeight: 460

$ sips -g dpiWidth -g dpiHeight /private/tmp/alhangeul-stage3-dmg/.background/alhangeul-dmg-background.png
dpiWidth: 72.000
dpiHeight: 72.000
```

Finder layout metadata:

```text
$ strings /private/tmp/alhangeul-stage3-dmg/.DS_Store
...
backgroundImageAlias
alhangeul-dmg-background.png
.background
WindowBounds
...
```

Finder 창 속성:

```text
$ osascript ... /private/tmp/alhangeul-stage3-dmg
bounds=120120840680
toolbar=false
statusbar=false
iconSize=96
appPosition=178268
applicationsPosition=542268
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
- `설치 안내.txt`는 제거했다. 설치 보조 설명은 DMG background와 배포 문서에 유지하며, public release smoke에서 root에 불필요한 안내 파일이 다시 추가되지 않았는지 확인한다.
- Retina/multi-representation TIFF background는 이 Finder 환경에서 확대 표시 문제가 재현되어 사용하지 않는다. public release 기준은 720x460 PNG background로 고정한다.

## 다음 단계 영향

Stage 4에서는 `release_distribution_guide.md`에 다음 기준을 추가한다.

- DMG layout smoke에서 app, Applications symlink, background image, Finder icon 위치를 확인한다.
- DMG root에는 `Alhangeul.app`과 `Applications` symlink만 노출하고, 별도 `설치 안내.txt`를 두지 않는다.
- DMG background는 720x460 PNG를 기준으로 검증하고, Retina TIFF 전환은 별도 호환성 검증 없이는 도입하지 않는다.
- rehearsal DMG는 layout/checksum 검증용이며 public release 기준으로 사용하지 않는다.
- #188 public release 실행 시 signed/notarized DMG에서도 같은 layout smoke를 반복한다.

## 승인 요청

Stage 3 결과를 승인해주면 Stage 4 `Public release 호환성과 배포 가이드 보강`으로 진행한다.
