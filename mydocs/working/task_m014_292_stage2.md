# Task M014 #292 Stage 2 완료 보고서

## 단계 목적

Stage 1에서 확정한 84% 축소율을 먼저 적용한 뒤, 작업지시자가 확인한 Apple macOS Sequoia App Icon production template 기준값을 반영해 `824 / 1024` keyline으로 보정한다. 파일명과 pixel size, asset catalog 구조는 유지하고 PNG 내용만 교체한다.

## 수행 내용

- `build.noindex/task292/icon-candidates/scale-84/`의 후보 PNG 10개를 기존 AppIcon 파일명에 맞춰 1차 적용했다.
- 작업지시자가 Figma로 import한 Apple macOS Sequoia production template에서 `512x512@2x` export group은 `1024 x 1024`, 내부 icon mask는 `824 x 824`임을 확인했다.
- template 기준 margin은 1024 frame 안에서 상하좌우 `100px`, 비율은 `824 / 1024 = 0.8046875`로 확정했다.
- Stage 2 최종 AppIcon은 기존 원본 master를 기준으로 `824 / 1024` keyline에 맞춰 다시 재생성했다.
- `Sources/HostApp/Assets.xcassets/AppIcon.appiconset`의 PNG 10개만 변경했다.
- `Contents.json`, `project.yml`, Swift source, Rust source는 변경하지 않았다.
- 변경 후 AppIcon PNG 10개의 해상도와 alpha 포함 여부를 확인했다.
- 변경 후 AppIcon PNG 10개의 시각 점유율을 다시 측정했다.
- 기준 앱과 비교하는 contact sheet를 확인했다.

## 변경 파일

- `Sources/HostApp/Assets.xcassets/AppIcon.appiconset/icon_16x16.png`
- `Sources/HostApp/Assets.xcassets/AppIcon.appiconset/icon_16x16@2x.png`
- `Sources/HostApp/Assets.xcassets/AppIcon.appiconset/icon_32x32.png`
- `Sources/HostApp/Assets.xcassets/AppIcon.appiconset/icon_32x32@2x.png`
- `Sources/HostApp/Assets.xcassets/AppIcon.appiconset/icon_128x128.png`
- `Sources/HostApp/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png`
- `Sources/HostApp/Assets.xcassets/AppIcon.appiconset/icon_256x256.png`
- `Sources/HostApp/Assets.xcassets/AppIcon.appiconset/icon_256x256@2x.png`
- `Sources/HostApp/Assets.xcassets/AppIcon.appiconset/icon_512x512.png`
- `Sources/HostApp/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png`
- `mydocs/working/task_m014_292_stage2.md`

## 적용 결과

`icon_512x512@2x.png` 기준:

| 항목 | 변경 전 | 84% 1차 적용 | 824 keyline 최종 |
|------|---------|--------------|------------------|
| size | `1024x1024` | `1024x1024` | `1024x1024` |
| strong bbox width | `1.0000` | `0.8398` | `0.8047` |
| strong bbox height | `1.0000` | `0.8398` | `0.8047` |
| strong coverage | `0.9392` | `0.6624` | `0.6081` |
| non-white bbox width | `0.7900` | `0.6641` | `0.6367` |
| non-white bbox height | `0.7471` | `0.6270` | `0.6016` |

전체 AppIcon PNG 10개 변경 후:

| 파일 | size | strong bbox | strong coverage | non-white bbox |
|------|------|-------------|-----------------|----------------|
| `icon_16x16.png` | `16x16` | `0.8125 x 0.8125` | `0.6133` | `0.6875 x 0.6875` |
| `icon_16x16@2x.png` | `32x32` | `0.8125 x 0.8125` | `0.6211` | `0.6875 x 0.6250` |
| `icon_32x32.png` | `32x32` | `0.8125 x 0.8125` | `0.6211` | `0.6875 x 0.6250` |
| `icon_32x32@2x.png` | `64x64` | `0.8125 x 0.8125` | `0.6230` | `0.6562 x 0.6250` |
| `icon_128x128.png` | `128x128` | `0.8047 x 0.8047` | `0.6085` | `0.6484 x 0.6016` |
| `icon_128x128@2x.png` | `256x256` | `0.8047 x 0.8047` | `0.6084` | `0.6406 x 0.6016` |
| `icon_256x256.png` | `256x256` | `0.8047 x 0.8047` | `0.6084` | `0.6406 x 0.6016` |
| `icon_256x256@2x.png` | `512x512` | `0.8047 x 0.8047` | `0.6083` | `0.6367 x 0.6016` |
| `icon_512x512.png` | `512x512` | `0.8047 x 0.8047` | `0.6083` | `0.6367 x 0.6016` |
| `icon_512x512@2x.png` | `1024x1024` | `0.8047 x 0.8047` | `0.6081` | `0.6367 x 0.6016` |

Stage 1 기준 앱 중앙값은 strong bbox `0.8047 x 0.8047`, strong coverage `0.6189`였다. Apple template 확인 후 최종 보정한 알한글 master의 strong bbox도 `0.8047 x 0.8047`로 맞췄다. 이는 `1024 x 1024` export frame 안에 `824 x 824` mask를 중앙 배치하는 공식 production template 기준과 일치한다.

## 검증 결과

### PNG 해상도와 alpha

```text
sips -g pixelWidth -g pixelHeight -g hasAlpha Sources/HostApp/Assets.xcassets/AppIcon.appiconset/*.png
```

결과:

- PNG 10개 모두 기존 slot과 같은 pixel size 유지
- PNG 10개 모두 `hasAlpha: yes`

### `Contents.json` 구조

```text
jq empty Sources/HostApp/Assets.xcassets/AppIcon.appiconset/Contents.json
python3 -m json.tool Sources/HostApp/Assets.xcassets/AppIcon.appiconset/Contents.json
```

결과:

- 통과

참고: 이 환경의 `plutil -lint Sources/HostApp/Assets.xcassets/AppIcon.appiconset/Contents.json`은 JSON 파일을 plist로 해석하지 못해 `Unexpected character { at line 1`로 실패했다. `Contents.json` 자체는 변경하지 않았고, JSON parser 검증은 통과했다.

### 변경되지 않아야 할 파일

```text
git diff -- Sources/HostApp/Assets.xcassets/AppIcon.appiconset/Contents.json project.yml
```

결과:

- 출력 없음. 두 파일 변경 없음.

### diff 검증

```text
git diff --check
```

결과:

- 통과

### 변경 범위

```text
git diff --stat -- Sources/HostApp/Assets.xcassets/AppIcon.appiconset
```

결과:

```text
 .../AppIcon.appiconset/icon_128x128.png            | Bin 50643 -> 8800 bytes
 .../AppIcon.appiconset/icon_128x128@2x.png         | Bin 180398 -> 24902 bytes
 .../AppIcon.appiconset/icon_16x16.png              | Bin 1637 -> 510 bytes
 .../AppIcon.appiconset/icon_16x16@2x.png           | Bin 4532 -> 1318 bytes
 .../AppIcon.appiconset/icon_256x256.png            | Bin 180398 -> 24902 bytes
 .../AppIcon.appiconset/icon_256x256@2x.png         | Bin 651854 -> 78362 bytes
 .../AppIcon.appiconset/icon_32x32.png              | Bin 4575 -> 1318 bytes
 .../AppIcon.appiconset/icon_32x32@2x.png           | Bin 14643 -> 3219 bytes
 .../AppIcon.appiconset/icon_512x512.png            | Bin 651854 -> 78362 bytes
 .../AppIcon.appiconset/icon_512x512@2x.png         | Bin 2344809 -> 362625 bytes
 10 files changed, 0 insertions(+), 0 deletions(-)
```

## 시각 확인

다음 조사 산출물로 변경 후 아이콘을 기준 앱과 비교했다.

- `build.noindex/task292/icon-candidates/stage2-824-keyline-sheet.png`

확인 결과 824 keyline 적용 후 흰색 배경판이 Safari/Chrome 기준 앱과 같은 keyline 폭에 들어온다. 작은 슬롯은 반올림 때문에 16px/32px에서 `0.8125` 단위로 표현되지만, 128px 이상 슬롯에서는 `0.8047`로 template 비율과 일치한다.

## 잔여 리스크

- 실제 Dock/Finder 표시에서는 macOS 아이콘 캐시가 개입하므로 Stage 3 빌드 산출물 검증과 Stage 4 표시 검증이 필요하다.
- 빌드 산출물의 `AppIcon.icns`가 asset catalog 입력 PNG를 어떤 슬롯으로 포함하는지는 Stage 3에서 `iconutil` 추출로 다시 확인한다.
- 작은 슬롯에서는 `824 / 1024` 비율을 정수 pixel로 표현해야 하므로 16px/32px에서 1px 단위 반올림 차이가 생긴다. Stage 3/4에서 빌드 산출물과 표시 결과를 다시 확인한다.

## 다음 단계

작업지시자가 Stage 2 결과를 승인하면 Stage 3에서 HostApp Debug build를 수행하고 빌드 산출물의 `AppIcon.icns` 반영 여부를 검증한다.
