# Task M014 #292 Stage 1 완료 보고서

## 단계 목적

현행 AppIcon의 시각적 점유율과 macOS 기본 앱/대표 서드파티 앱의 점유율을 같은 기준으로 측정하고, Stage 2에서 사용할 축소율을 확정한다.

## 수행 내용

- `Sources/HostApp/Assets.xcassets/AppIcon.appiconset`의 PNG 10개 해상도와 alpha 포함 여부를 확인했다.
- 현재 AppIcon PNG 10개의 `alpha bbox`, `strong alpha bbox`, `strong alpha coverage`, `non-white bbox`를 측정했다.
- 로컬 Mac에서 찾을 수 있는 macOS 앱 17개의 `.icns`를 `iconutil`로 추출해 같은 지표로 비교했다.
- 현재 `icon_512x512@2x.png`를 기준으로 `84%`, `86%`, `88%` 후보 PNG 세트를 `build.noindex/task292/icon-candidates/` 아래에 생성했다.
- 큰 슬롯 contact sheet와 작은 슬롯 확대 sheet를 확인했다.

## 생성 산출물

커밋 대상이 아닌 조사 산출물:

- `build.noindex/task292/icon-metrics/current-appicon-metrics.csv`
- `build.noindex/task292/icon-metrics/reference-app-metrics.csv`
- `build.noindex/task292/icon-metrics/candidate-metrics.csv`
- `build.noindex/task292/icon-metrics/summary.md`
- `build.noindex/task292/icon-candidates/scale-84/`
- `build.noindex/task292/icon-candidates/scale-86/`
- `build.noindex/task292/icon-candidates/scale-88/`
- `build.noindex/task292/icon-candidates/contact-sheet.png`
- `build.noindex/task292/icon-candidates/small-slot-sheet.png`

커밋 대상:

- `mydocs/working/task_m014_292_stage1.md`

## 측정 결과

### 현재 AppIcon

`icon_512x512@2x.png` 기준:

| 항목 | 값 |
|------|----|
| size | `1024x1024` |
| strong bbox width | `1.0000` |
| strong bbox height | `1.0000` |
| strong coverage | `0.9392` |
| non-white bbox width | `0.7900` |
| non-white bbox height | `0.7471` |

현재 AppIcon PNG 10개의 strong bbox width/height 중앙값은 모두 `1.0000`이다. 즉 흰색 rounded-square 배경판이 캔버스 끝까지 닿는 상태다.

### 기준 앱 비교

로컬에서 추출한 기준 앱 17개:

- Safari
- Mail
- Notes
- Photos
- App Store
- System Settings
- Terminal
- TextEdit
- Preview
- Music
- Messages
- Firefox
- Spotify
- Notion
- Discord
- Google Chrome
- KakaoTalk

기준 앱 통계:

| 항목 | 중앙값 | 최소 | 최대 |
|------|--------|------|------|
| strong bbox width | `0.8047` | `0.8047` | `0.9639` |
| strong bbox height | `0.8047` | `0.8047` | `1.0000` |
| strong coverage | `0.6189` | `0.6166` | `0.8789` |

대부분의 Apple 기본 앱과 대표 앱은 strong bbox가 약 `0.8047 x 0.8047`에 모여 있었다. Notion처럼 예외적으로 세로 또는 가로를 크게 쓰는 앱도 있지만, 현재 알한글처럼 전체 슬롯을 `1.0000 x 1.0000`으로 채우는 값은 기준 앱 중앙값과 거리가 크다.

### 후보 비교

`icon_512x512@2x.png` 후보 기준:

| 후보 | strong bbox w | strong bbox h | strong coverage | non-white bbox w | non-white bbox h |
|------|---------------|---------------|-----------------|------------------|------------------|
| 84% | `0.8398` | `0.8398` | `0.6624` | `0.6641` | `0.6270` |
| 86% | `0.8604` | `0.8604` | `0.6951` | `0.6807` | `0.6436` |
| 88% | `0.8799` | `0.8799` | `0.7271` | `0.6953` | `0.6572` |

작은 슬롯 확인:

| 후보 | 16px strong bbox | 32px strong bbox | 64px strong bbox |
|------|------------------|------------------|------------------|
| 84% | `0.8125 x 0.8125` | `0.8438 x 0.8438` | `0.8438 x 0.8438` |
| 86% | `0.8750 x 0.8750` | `0.8750 x 0.8750` | `0.8594 x 0.8594` |
| 88% | `0.8750 x 0.8750` | `0.8750 x 0.8750` | `0.8750 x 0.8750` |

## 결정

Stage 2에서 사용할 축소율은 **84%**로 확정한다.

이유:

- 기준 앱 strong bbox 중앙값 `0.8047`에 세 후보 중 가장 가깝다.
- 84% 후보의 master strong bbox는 `0.8398`로, 현재 `1.0000`에서 충분히 줄면서도 기준 앱보다 약간 큰 정도에 머문다.
- 86%와 88%는 현재보다는 개선되지만 기준 앱 중앙값 대비 여전히 크게 보일 가능성이 높다.
- 16px/32px 확대 sheet에서 84% 후보도 글리프 형태와 흰 배경판의 식별성이 유지됐다.
- 알한글 글리프는 흰 배경 안쪽에 별도 여백을 가진 구조이므로 80%까지 줄이면 글리프가 과하게 작아질 수 있다. 84%는 macOS 관행에 가까워지면서 브랜드 식별성을 유지하는 절충점이다.

## 검증 결과

```text
sips -g pixelWidth -g pixelHeight -g hasAlpha Sources/HostApp/Assets.xcassets/AppIcon.appiconset/*.png
```

결과:

- AppIcon PNG 10개 모두 기존 슬롯과 일치하는 pixel size 확인
- 모든 AppIcon PNG에서 `hasAlpha: yes` 확인

```text
python3 - <<'PY'
from PIL import Image
print("Pillow available")
PY
```

결과:

- `Pillow available`

```text
git diff --check -- mydocs/working/task_m014_292_stage1.md
```

결과:

- 통과

## 변경 범위

Stage 1에서 소스 AppIcon PNG, `Contents.json`, `project.yml`, Swift/Rust source는 변경하지 않았다.

이번 단계의 커밋 대상은 Stage 1 완료 보고서뿐이다. `build.noindex/task292/` 아래 측정/후보 산출물은 재생성 가능한 조사 산출물로 커밋하지 않는다.

## 잔여 리스크

- 84% 후보는 기준 앱 중앙값보다 약간 크다. 하지만 현재 알한글 글리프 구조상 80% 수준으로 바로 줄이면 글리프가 약해질 수 있으므로 Stage 2에서 84%를 적용한 뒤 빌드 산출물과 Dock/Finder 표시로 재확인한다.
- 후보 PNG는 기존 master PNG를 리샘플링한 결과다. Stage 2에서 최종 PNG 10개를 생성한 뒤 작은 슬롯의 흐림을 다시 확인해야 한다.
- Dock/Finder 표시 판단은 캐시 영향을 받을 수 있으므로 Stage 4에서 별도로 분리해 검증한다.

## 다음 단계

작업지시자가 Stage 1 결과를 승인하면 Stage 2에서 84% 기준으로 AppIcon PNG 10개를 재생성한다.
