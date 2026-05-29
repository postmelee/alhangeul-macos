# Task M014 #292 Stage 4 완료 보고서

## 단계 목적

실제 macOS 표시 환경에서 새 AppIcon이 About/Finder/Dock 계열 경로에 어떻게 반영되는지 확인하고, IconServices/LaunchServices cache 때문에 화면 결과가 실제 bundle resource와 달라질 수 있는지 분리한다.

## 수행 내용

- Dock 표시 설정을 기록했다.
- HostApp Debug build 산출물과 `/Applications/Alhangeul.app` 설치본을 분리해 확인했다.
- `NSWorkspace.icon(forFile:)`와 `NSRunningApplication.icon`으로 IconServices가 반환하는 아이콘을 PNG로 저장하고 bbox를 측정했다.
- Debug build 산출물 앱을 직접 실행해 실제 running app icon이 새 `824 / 1024` keyline을 사용하는지 확인했다.
- About window를 열어 표시 아이콘을 확인하고 스크린샷을 저장했다.
- Finder에서 `/Applications/Alhangeul.app`을 선택해 표시 상태를 확인하고 스크린샷을 저장했다.
- `/Applications/Alhangeul.app`의 실제 `AppIcon.icns`를 별도로 추출해 화면 표시와 bundle resource가 일치하는지 확인했다.
- 표시 확인 후 테스트로 띄운 HostApp 본체 인스턴스를 종료했다.

## 생성 산출물

커밋 대상이 아닌 검증 산출물:

- `build.noindex/task292/export-icons.swift`
- `build.noindex/task292/stage4-iconservices-build.png`
- `build.noindex/task292/stage4-iconservices-applications.png`
- `build.noindex/task292/stage4-running-build-icon.png`
- `build.noindex/task292/stage4-running-applications-icon.png`
- `build.noindex/task292/stage4-running-build-bundle-url.txt`
- `build.noindex/task292/stage4-running-applications-bundle-url.txt`
- `build.noindex/task292/stage4-iconservices-metrics.csv`
- `build.noindex/task292/stage4-about-screen.png`
- `build.noindex/task292/stage4-finder-applications-screen.png`
- `build.noindex/task292/AppIcon-applications.iconset/`

커밋 대상:

- `mydocs/working/task_m014_292_stage4.md`
- `mydocs/orders/20260529.md`

## Dock 설정

```text
defaults read com.apple.dock tilesize
```

결과:

- `47`

```text
defaults read com.apple.dock magnification
```

결과:

- `0`

```text
defaults read com.apple.dock largesize
```

결과:

- `16`

추가 확인:

```text
defaults read com.apple.dock autohide
```

결과:

- `1`

현재 Dock은 자동 숨김 상태다. 따라서 화면 캡처에서 Dock 아이콘을 안정적으로 비교하기보다는 `NSRunningApplication.icon`을 Dock 표시 경로의 근거로 사용했다.

## Bundle 상태

확인 대상:

| 경로 | 상태 |
|------|------|
| `build.noindex/DerivedDataTask292/Build/Products/Debug/Alhangeul.app` | Stage 3에서 빌드한 Debug 산출물 |
| `/Applications/Alhangeul.app` | 기존 설치본 존재 |

두 bundle의 `Info.plist` 주요 값은 같다.

| 항목 | 값 |
|------|----|
| `CFBundleIdentifier` | `com.postmelee.alhangeul` |
| `CFBundleIconFile` | `AppIcon` |
| `CFBundleIconName` | `AppIcon` |
| `CFBundleShortVersionString` | `0.1.3` |
| `CFBundleVersion` | `9` |

단, 두 bundle의 `AppIcon.icns` 파일은 다르다.

| 경로 | `AppIcon.icns` 크기 |
|------|--------------------|
| Debug build | `51K` |
| `/Applications` 설치본 | `91K` |

## 실행 앱 아이콘 확인

Debug build 산출물을 직접 실행했다.

```text
open -n /Users/melee/Documents/projects/rhwp-mac/build.noindex/DerivedDataTask292/Build/Products/Debug/Alhangeul.app
```

실행 후 프로세스 경로:

```text
/Users/melee/Documents/projects/rhwp-mac/build.noindex/DerivedDataTask292/Build/Products/Debug/Alhangeul.app/Contents/MacOS/Alhangeul
```

`NSRunningApplication.icon`으로 실행 중인 Debug build 앱 아이콘을 추출한 결과:

| 항목 | 값 |
|------|----|
| output | `build.noindex/task292/stage4-running-build-icon.png` |
| bundle URL | `build.noindex/task292/stage4-running-build-bundle-url.txt` |
| strong bbox | `0.8047 x 0.8047` |
| strong coverage | `0.6070` |
| strong bbox px | `824x824` |

즉 Dock이 사용하는 running app icon 경로에서는 새 AppIcon의 `824 / 1024` keyline이 정상 반영된다.

## About 표시 확인

Computer Use로 `/Applications` 설치본의 About window를 열었다.

경로:

- 메뉴 `알한글` -> `알한글에 관하여`

확인 결과:

- About window 좌상단 앱 아이콘이 새 여백을 가진 아이콘으로 표시된다.
- 화면 텍스트는 `v0.1.3 (9)`, `버전 0.1.3`, `빌드 9`로 표시된다.
- 스크린샷: `build.noindex/task292/stage4-about-screen.png`

주의:

- Computer Use는 app name 기준으로 `/Applications/Alhangeul.app`을 선택했다.
- 이 시점에는 Debug build와 `/Applications` 설치본이 같은 bundle id로 동시에 떠 있었기 때문에, 화면 표시에는 LaunchServices/IconServices cache가 개입할 수 있다.

## Finder 표시 확인

```text
open -R /Applications/Alhangeul.app
```

확인 결과:

- Finder `/Applications` 목록 보기에서 `알한글.app`이 선택됐다.
- 목록 아이콘은 새 여백을 가진 아이콘으로 보였다.
- 스크린샷: `build.noindex/task292/stage4-finder-applications-screen.png`

다만 이 결과만으로 `/Applications` 설치본 resource가 갱신됐다고 판단하면 안 된다. 아래 cache 분리 결과처럼 실제 `/Applications/Alhangeul.app/Contents/Resources/AppIcon.icns`는 아직 기존 full-size 아이콘이다.

## Cache 영향 분리

IconServices를 통해 file icon과 running app icon을 비교했다.

| 대상 | output | strong bbox | strong bbox px | 해석 |
|------|--------|-------------|----------------|------|
| Debug build file icon | `stage4-iconservices-build.png` | `0.6719 x 0.8867` | `688x908` | generic document icon 반환 |
| `/Applications` file icon | `stage4-iconservices-applications.png` | `0.8047 x 0.8047` | `824x824` | 새 아이콘처럼 반환 |
| Debug build running icon | `stage4-running-build-icon.png` | `0.8047 x 0.8047` | `824x824` | 새 아이콘 정상 |
| `/Applications` running icon | `stage4-running-applications-icon.png` | `0.8047 x 0.8047` | `824x824` | 새 아이콘처럼 반환 |

동시에 `/Applications` 설치본의 실제 `AppIcon.icns`를 `iconutil`로 추출해 측정했다.

| 설치본 `AppIcon.icns` 슬롯 | strong bbox | strong coverage | strong bbox px |
|----------------------------|-------------|-----------------|----------------|
| `icon_16x16.png` | `1.0000 x 1.0000` | `0.8750` | `16x16` |
| `icon_16x16@2x.png` | `1.0000 x 1.0000` | `0.9023` | `32x32` |
| `icon_128x128.png` | `1.0000 x 1.0000` | `0.9302` | `128x128` |
| `icon_128x128@2x.png` | `1.0000 x 1.0000` | `0.9349` | `256x256` |

결론:

- `/Applications` 설치본 resource 자체는 아직 기존 full-size AppIcon이다.
- 그런데 Finder/IconServices는 같은 bundle id로 등록된 Debug build의 새 아이콘을 반환하고 있었다.
- 따라서 사용자 환경에서 “어떤 Mac에서는 크게 보이고, 어떤 Mac에서는 작게 보이는” 현상은 실제 resource 차이뿐 아니라 IconServices/LaunchServices cache 상태 차이로도 발생할 수 있다.

## Cache reset 수행 여부

이번 단계에서는 다음 조치를 수행하지 않았다.

- `touch /Applications/Alhangeul.app`
- `killall Dock`
- 전역 IconServices cache 삭제

이유:

- Debug build running app icon과 About 표시에서는 새 아이콘이 이미 정상 반영됐다.
- `/Applications` 설치본 resource가 아직 기존 아이콘인 상태에서 cache를 갱신하면 Finder/Dock이 오히려 기존 설치본 아이콘으로 돌아갈 수 있다.
- 전역 IconServices cache 삭제는 사용자 세션 영향이 크므로 계획대로 별도 승인 전에는 수행하지 않는다.

## 정리 상태

검증 후 HostApp 본체 테스트 인스턴스는 종료했다.

남아 있던 프로세스:

```text
/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulPreview.appex/Contents/MacOS/AlhangeulPreview
/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulThumbnail.appex/Contents/MacOS/AlhangeulThumbnail
```

이들은 Stage 4 시작 전에도 떠 있던 `/Applications` 설치본 extension 프로세스다. 이번 단계에서는 Quick Look/Thumbnail 등록 초기화나 extension 종료를 수행하지 않았다.

## 검증 결과

```text
git status --short --branch
```

Stage 4 보고서 작성 전 결과:

- tracked source diff 없음.

```text
python3 - <<'PY'
from PIL import Image
print("Pillow available")
PY
```

Stage 4에서 생성한 PNG 측정에 Pillow를 사용했다. 기존 Stage 1/2와 같은 측정 방식이다.

```text
screencapture -x /Users/melee/Documents/projects/rhwp-mac/build.noindex/task292/stage4-about-screen.png
screencapture -x /Users/melee/Documents/projects/rhwp-mac/build.noindex/task292/stage4-finder-applications-screen.png
```

결과:

- About window와 Finder `/Applications` 표시 스크린샷 저장.

## 변경 범위

Stage 4는 표시 검증 단계다. 소스 AppIcon PNG, `Contents.json`, `project.yml`, Swift source, Rust source는 변경하지 않았다.

커밋 대상 변경은 Stage 4 보고서와 오늘할일 문서뿐이다. `build.noindex/task292/` 아래 스크립트와 스크린샷은 검증 산출물로 커밋하지 않는다.

## 잔여 리스크

- `/Applications` 설치본은 아직 이번 브랜치의 새 bundle로 교체하지 않았다. 따라서 설치본 자체의 resource 검증은 public/release packaging 또는 별도 clean install smoke에서 수행해야 한다.
- Debug build file icon은 `NSWorkspace.icon(forFile:)`에서 generic document icon으로 반환됐다. `.noindex` 개발 산출물과 동일 bundle id 등록 상태가 영향을 준 것으로 보이며, Finder file icon 검증에는 설치/패키징된 app copy가 더 적합하다.
- 전역 IconServices cache 삭제는 수행하지 않았다. 사용자 제보 환경에서 계속 큰 아이콘이 보이면, 새 build 설치 후 `touch`/Dock 재시작/IconServices cache reset을 낮은 영향 순서로 안내해야 한다.

## 다음 단계

작업지시자가 Stage 4 결과를 승인하면 Stage 5에서 최종 보고서, 오늘할일 완료 처리, PR 준비용 요약을 작성한다.
