# Task M014 #292 Stage 2 완료 보고서

## 단계 목적

Stage 1에서 확정한 84% 축소율을 적용해 `AppIcon.appiconset` PNG 10개를 재생성한다. 파일명과 pixel size, asset catalog 구조는 유지하고 PNG 내용만 교체한다.

## 수행 내용

- `build.noindex/task292/icon-candidates/scale-84/`의 후보 PNG 10개를 기존 AppIcon 파일명에 맞춰 복사했다.
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

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| size | `1024x1024` | `1024x1024` |
| strong bbox width | `1.0000` | `0.8398` |
| strong bbox height | `1.0000` | `0.8398` |
| strong coverage | `0.9392` | `0.6624` |
| non-white bbox width | `0.7900` | `0.6641` |
| non-white bbox height | `0.7471` | `0.6270` |

전체 AppIcon PNG 10개 변경 후:

| 파일 | size | strong bbox | strong coverage | non-white bbox |
|------|------|-------------|-----------------|----------------|
| `icon_16x16.png` | `16x16` | `0.8125 x 0.8125` | `0.6133` | `0.6875 x 0.6875` |
| `icon_16x16@2x.png` | `32x32` | `0.8438 x 0.8438` | `0.6729` | `0.6875 x 0.6562` |
| `icon_32x32.png` | `32x32` | `0.8438 x 0.8438` | `0.6729` | `0.6875 x 0.6562` |
| `icon_32x32@2x.png` | `64x64` | `0.8438 x 0.8438` | `0.6689` | `0.6875 x 0.6406` |
| `icon_128x128.png` | `128x128` | `0.8438 x 0.8438` | `0.6689` | `0.6719 x 0.6406` |
| `icon_128x128@2x.png` | `256x256` | `0.8398 x 0.8398` | `0.6627` | `0.6680 x 0.6289` |
| `icon_256x256.png` | `256x256` | `0.8398 x 0.8398` | `0.6627` | `0.6680 x 0.6289` |
| `icon_256x256@2x.png` | `512x512` | `0.8398 x 0.8398` | `0.6625` | `0.6641 x 0.6289` |
| `icon_512x512.png` | `512x512` | `0.8398 x 0.8398` | `0.6625` | `0.6641 x 0.6289` |
| `icon_512x512@2x.png` | `1024x1024` | `0.8398 x 0.8398` | `0.6624` | `0.6641 x 0.6270` |

Stage 1 기준 앱 중앙값은 strong bbox `0.8047 x 0.8047`, strong coverage `0.6189`였다. 변경 후 알한글 master는 기준 앱보다 약간 크지만, 기존의 전체 캔버스 점유 상태에서 벗어나 macOS 앱 아이콘 관행에 가까워졌다.

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
 .../AppIcon.appiconset/icon_128x128.png            | Bin 50643 -> 10855 bytes
 .../AppIcon.appiconset/icon_128x128@2x.png         | Bin 180398 -> 30934 bytes
 .../AppIcon.appiconset/icon_16x16.png              | Bin 1637 -> 510 bytes
 .../AppIcon.appiconset/icon_16x16@2x.png           | Bin 4532 -> 1521 bytes
 .../AppIcon.appiconset/icon_256x256.png            | Bin 180398 -> 30934 bytes
 .../AppIcon.appiconset/icon_256x256@2x.png         | Bin 651854 -> 98315 bytes
 .../AppIcon.appiconset/icon_32x32.png              | Bin 4575 -> 1521 bytes
 .../AppIcon.appiconset/icon_32x32@2x.png           | Bin 14643 -> 3757 bytes
 .../AppIcon.appiconset/icon_512x512.png            | Bin 651854 -> 98315 bytes
 .../AppIcon.appiconset/icon_512x512@2x.png         | Bin 2344809 -> 436317 bytes
 10 files changed, 0 insertions(+), 0 deletions(-)
```

## 시각 확인

다음 조사 산출물로 변경 후 아이콘을 기준 앱과 비교했다.

- `build.noindex/task292/icon-candidates/stage2-source-sheet.png`

확인 결과 84% 적용 후 흰색 배경판이 Safari/Chrome 기준 앱과 유사한 외곽 여백을 갖는다. 작은 슬롯은 Stage 1 확대 sheet 기준으로 16px/32px에서도 글리프와 흰 배경판의 식별성이 유지됐다.

## 잔여 리스크

- 실제 Dock/Finder 표시에서는 macOS 아이콘 캐시가 개입하므로 Stage 3 빌드 산출물 검증과 Stage 4 표시 검증이 필요하다.
- 빌드 산출물의 `AppIcon.icns`가 asset catalog 입력 PNG를 어떤 슬롯으로 포함하는지는 Stage 3에서 `iconutil` 추출로 다시 확인한다.
- 84%는 기준 앱 중앙값보다 약간 크므로, 최종 표시에서 여전히 크다고 판단되면 후속 보정이 필요할 수 있다.

## 다음 단계

작업지시자가 Stage 2 결과를 승인하면 Stage 3에서 HostApp Debug build를 수행하고 빌드 산출물의 `AppIcon.icns` 반영 여부를 검증한다.
