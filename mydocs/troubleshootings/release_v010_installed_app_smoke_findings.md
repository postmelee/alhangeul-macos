# v0.1.0 설치본 smoke 확인 결과와 판정 기준

## 작성 목적

2026년 5월 9일 `v0.1.0` GitHub Release DMG 설치본을 실제 사용자 설치 경로로 확인하면서 두 가지 혼동 지점이 확인됐다.

1. Sparkle 업데이트 창이 첫 실행 직후 자동으로 뜨지 않는 것을 실패로 볼지 여부
2. 창 상단 헤더를 더블 클릭해 창을 크게 만들 때 WebView runtime error가 발생한 문제의 처리 범위

이 문서는 다음 release smoke에서 같은 판단 혼선을 줄이기 위해 설치본 smoke 판정 기준과 후속 분리 기준을 기록한다.

## 테스트 대상

관련 작업:

- GitHub Issue: [#166](https://github.com/postmelee/alhangeul-macos/issues/166)
- 후속 이슈: [#183](https://github.com/postmelee/alhangeul-macos/issues/183)
- Release: [v0.1.0](https://github.com/postmelee/alhangeul-macos/releases/tag/v0.1.0)
- 설치본: `alhangeul-macos-0.1.0.dmg`
- 설치 위치: `/Applications/Alhangeul.app`

검증 대상은 Xcode/DerivedData 산출물이 아니라 GitHub Release에서 내려받아 `/Applications`에 설치한 public DMG 설치본이다.

## 사전 정리

public DMG smoke 전에는 오래된 로컬 앱과 실행 중인 이전 빌드를 정리한다.

```bash
pkill -f '/Users/melee/Applications/AlhangeulMac.app/Contents/MacOS/AlhangeulMacHost'
rm -rf ~/Applications/AlhangeulMac.app
```

일반 설치 위치에 남은 이전 앱도 정리한다.

```bash
rm -rf /Applications/Alhangeul.app
rm -rf ~/Applications/Alhangeul.app
rm -rf /Applications/알한글.app
rm -rf ~/Applications/알한글.app
```

최신 macOS에서는 `lsregister -kill`이 제거되어 있다. Launch Services 갱신이 필요하면 `-kill` 없이 실행한다.

```bash
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -r -domain local -domain system -domain user

qlmanage -r
qlmanage -r cache
```

## 확인된 결과

### 통과 항목

- GitHub Release DMG 다운로드 가능
- `/Applications/Alhangeul.app` 설치 가능
- 앱 실행 시 크래시 없음
- HWP/HWPX 문서 열기 가능
- Sparkle 수동 업데이트 확인 UI 표시

Sparkle 수동 확인 결과:

```text
최신 버전입니다.
알한글 0.1.0 이(가) 현재 최신 버전입니다.
```

따라서 `알한글 > 업데이트 확인...` 수동 smoke는 통과로 판정한다.

### 실패 또는 후속 분리 항목

창 상단 헤더/title bar 영역을 더블 클릭해 창을 크게 만들 때 WebView runtime error 화면이 표시됐다.

표시 문구:

```text
웹 viewer 실행 중 오류가 발생했습니다
JavaScript 또는 WASM runtime 오류로 viewer가 정상 상태가 아닙니다.
```

이 문제는 `v0.1.0` public release smoke에서 발견된 후속 버그로 분리했다.

- 후속 이슈: [#183 v0.1.0 설치본에서 창 확대 시 WebView runtime error 발생](https://github.com/postmelee/alhangeul-macos/issues/183)
- 권장 처리: `v0.1.1` patch release 후보에서 수정 및 재검증

## Sparkle 판정 기준

첫 실행 직후 "최신 버전입니다" 창이 자동으로 뜨지 않는 것은 실패가 아니다.

이유:

- `SUEnableAutomaticChecks=true`는 자동 확인 스케줄을 허용하는 설정이다.
- 매 실행마다 사용자-facing 최신 버전 창을 띄운다는 의미가 아니다.
- 사용자가 메뉴에서 `업데이트 확인...`을 직접 눌렀을 때 최신 버전 또는 업데이트 가능 UI가 표시되면 수동 smoke는 통과다.

따라서 release smoke의 기대 결과는 다음으로 둔다.

1. 메뉴 막대에서 `알한글 > 업데이트 확인...` 항목이 보인다.
2. 메뉴 항목이 클릭 가능하다.
3. 클릭 후 Sparkle UI가 표시된다.
4. 현재 설치본이 최신이면 "최신 버전입니다"류 메시지가 표시된다.
5. 이전 버전 설치본이면 새 버전 안내 UI가 표시된다.

## 설치본 smoke 체크리스트

다음 release에서는 public DMG 설치 후 아래 항목을 확인한다.

- [ ] `/Applications/Alhangeul.app` 실행
- [ ] HWP 샘플 열기
- [ ] HWPX 샘플 열기
- [ ] 창 상단 헤더 더블 클릭 또는 녹색 버튼으로 창 확대
- [ ] 창 크기 조절 후 WebView runtime error가 없는지 확인
- [ ] `알한글 > 업데이트 확인...` 수동 실행
- [ ] Finder Quick Look preview 확인
- [ ] Finder thumbnail 확인
- [ ] 필요하면 오류 화면의 `진단 정보` 펼쳐서 기록

## 진단 정보 수집 기준

WebView runtime error 화면이 뜨면 `진단 정보` disclosure를 펼쳐서 내용을 저장한다.

추가로 확인할 수 있는 항목:

```bash
plutil -p /Applications/Alhangeul.app/Contents/Info.plist

codesign --display --entitlements - /Applications/Alhangeul.app

find /Applications/Alhangeul.app/Contents/Frameworks/Sparkle.framework \
  -maxdepth 6 \( -name '*.xpc' -o -name 'Updater.app' -o -name 'Autoupdate' \) -print
```

Sparkle 동작 확인이 필요하면 메뉴 항목이 enabled인지 접근성으로 볼 수 있다.

```bash
osascript -e 'tell application "System Events" to tell process "Alhangeul" to get {name, enabled} of menu items of menu 1 of menu bar item "알한글" of menu bar 1'
```

## release 처리 기준

`v0.1.0`은 이미 public GitHub Release, appcast, Cask SHA가 공개된 상태이므로 같은 tag/version을 덮어쓰지 않는다.

운영 기준:

- `v0.1.0`은 유지한다.
- 창 확대 WebView runtime error는 #183으로 추적한다.
- 수정 후 `CFBundleShortVersionString=0.1.1`, `CFBundleVersion=2`처럼 버전을 올린다.
- `v0.1.1` tag와 GitHub Release를 새로 만든다.
- appcast에 `v0.1.1` item이 추가되어 `v0.1.0` 설치 사용자가 Sparkle로 업데이트할 수 있게 한다.

## 관련 문서

- [`release_distribution_guide.md`](../manual/release_distribution_guide.md)
- [`task_m010_166_report.md`](../report/task_m010_166_report.md)
- [`task_m010_166_stage5.md`](../working/task_m010_166_stage5.md)
