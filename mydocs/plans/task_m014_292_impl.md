# Task M014 #292 구현계획서

## 작업 기준

- 이슈: #292 앱 아이콘이 너무 커요
- 마일스톤: M014 (`v0.1.4 Native Preview/Viewer Parity`)
- 작업 브랜치: `local/task292`
- 기준 브랜치: `devel`
- 수행계획서: `mydocs/plans/task_m014_292.md`

## 구현 목표

알한글 HostApp의 `AppIcon.appiconset` PNG 10개를 macOS 앱 아이콘 관행에 맞는 시각적 여백을 가진 이미지로 재생성한다. 기존 아이콘 디자인, 색상, 글리프, asset catalog 파일명과 슬롯 구조는 유지하고, 흰색 rounded-square 배경판과 전체 아이콘 본체가 캔버스 끝까지 닿지 않도록 조정한다.

최종 산출물은 다음 조건을 만족해야 한다.

- AppIcon PNG 10개의 파일명과 pixel size가 기존 `Contents.json` 슬롯과 일치한다.
- `Contents.json`, `project.yml`, Swift source, Rust source는 변경하지 않는다.
- 큰 슬롯 기준 강한 불투명 영역 bbox가 기존 `100% x 100%`에서 macOS 기본 앱과 더 가까운 값으로 줄어든다.
- 16px/32px 슬롯에서도 글리프 식별성이 유지된다.
- 빌드된 HostApp bundle의 `AppIcon.icns`에 새 아이콘이 반영된다.
- Dock/Finder/About 표시 검증에서 캐시 영향을 분리해 기록한다.

## Stage 1. 현행 아이콘과 후보 축소율 inventory

### 목적

현재 AppIcon의 시각적 점유율과 macOS 기본 앱/대표 서드파티 앱의 점유율을 같은 스크립트로 다시 측정하고, Stage 2에서 사용할 축소율을 고정한다.

### 작업

- 현재 AppIcon PNG 10개의 `pixelWidth`, `pixelHeight`, `hasAlpha`를 기록한다.
- `alpha bbox`, `strong alpha bbox`, `strong alpha coverage`, `non-white bbox`를 측정한다.
- Safari, Mail, Notes, Photos, App Store, Terminal, Firefox, Spotify 등 로컬에서 찾을 수 있는 앱의 `.icns`를 추출해 같은 지표로 비교한다.
- `84%`, `86%`, `88%` 후보를 임시 PNG로 생성해 큰 슬롯과 작은 슬롯의 예상 점유율을 비교한다.
- 최종 축소율 후보를 하나로 고정하고 Stage 1 보고서에 근거를 남긴다.

### 산출물

- `build.noindex/task292/icon-metrics/` 아래 측정 산출물
- `build.noindex/task292/icon-candidates/` 아래 후보 PNG
- `mydocs/working/task_m014_292_stage1.md`

### 검증

```bash
sips -g pixelWidth -g pixelHeight -g hasAlpha Sources/HostApp/Assets.xcassets/AppIcon.appiconset/*.png
python3 - <<'PY'
from PIL import Image
print("Pillow available")
PY
git diff --check -- mydocs/working/task_m014_292_stage1.md
```

### 커밋

```text
Task #292 Stage 1: AppIcon 점유율과 축소 후보 확정
```

## Stage 2. AppIcon PNG 10개 재생성

### 목적

Stage 1에서 확정한 축소율과 중심 정렬 기준으로 AppIcon PNG 10개를 재생성한다.

### 작업

- 원본 `icon_512x512@2x.png` 또는 가장 큰 품질의 기존 자산을 기준으로 master 후보를 만든다.
- 기존 아이콘 전체를 확정 비율로 축소하고, 투명 캔버스 중앙에 배치한다.
- `16`, `32`, `64`, `128`, `256`, `512`, `1024` pixel 출력으로 내려보낸다.
- 각 출력 파일을 기존 AppIcon 파일명에 대응시킨다.
- 작은 슬롯에서 흐림이 과하면 16px/32px 슬롯만 별도 보정 후보를 검토한다. 단, 새 디자인이나 새 색상은 도입하지 않는다.

### 산출물

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

### 검증

```bash
sips -g pixelWidth -g pixelHeight -g hasAlpha Sources/HostApp/Assets.xcassets/AppIcon.appiconset/*.png
plutil -lint Sources/HostApp/Assets.xcassets/AppIcon.appiconset/Contents.json
git diff --check
git diff --stat -- Sources/HostApp/Assets.xcassets/AppIcon.appiconset mydocs/working/task_m014_292_stage2.md
```

### 커밋

```text
Task #292 Stage 2: AppIcon PNG 여백 보강
```

## Stage 3. 빌드 산출물 검증

### 목적

재생성한 AppIcon이 HostApp 빌드 산출물에 반영되고, 빌드된 `AppIcon.icns`에서 기대한 슬롯과 점유율을 확인한다.

### 작업

- `Alhangeul.xcodeproj`가 최신 `project.yml` 기준인지 확인한다.
- HostApp Debug build를 수행한다.
- 빌드 산출물 앱 bundle의 `Info.plist`에서 `CFBundleIconFile`, `CFBundleIconName`, version/build 정보를 확인한다.
- `AppIcon.icns`를 `iconutil`로 추출하고, 추출 가능한 슬롯의 해상도와 점유율을 측정한다.
- `Contents.json`과 `project.yml`에 변경이 없음을 재확인한다.

### 산출물

- `build.noindex/DerivedDataTask292/`
- `build.noindex/task292/AppIcon.iconset/`
- `mydocs/working/task_m014_292_stage3.md`

### 검증

```bash
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask292 CODE_SIGNING_ALLOWED=NO build
plutil -p build.noindex/DerivedDataTask292/Build/Products/Debug/Alhangeul.app/Contents/Info.plist | \
  rg 'CFBundleIcon|CFBundleShortVersionString|CFBundleVersion'
iconutil -c iconset -o build.noindex/task292/AppIcon.iconset \
  build.noindex/DerivedDataTask292/Build/Products/Debug/Alhangeul.app/Contents/Resources/AppIcon.icns
sips -g pixelWidth -g pixelHeight build.noindex/task292/AppIcon.iconset/*.png
git diff --check
```

### 커밋

```text
Task #292 Stage 3: AppIcon 빌드 산출물 검증
```

## Stage 4. Dock/Finder/About 표시 검증

### 목적

실제 macOS 표시 환경에서 새 아이콘이 주변 앱과 유사한 크기로 보이는지 확인하고, 캐시 때문에 화면 반영이 지연되는지 분리한다.

### 작업

- 작업자 로컬 Dock 설정(`tilesize`, `magnification`, `largesize`)을 기록한다.
- 가능하면 build 산출물 앱을 직접 실행하거나 임시 위치에서 표시해 `/Applications` 설치본과 분리해 확인한다.
- About 화면의 `NSApp.applicationIconImage` 표시가 새 아이콘을 사용하는지 확인한다.
- Finder `/Applications` 보기와 Dock 표시를 확인한다.
- 캐시 갱신은 낮은 영향 순서로만 시도한다.
  1. 앱 종료 후 재실행
  2. Dock에서 앱 제거 후 재추가
  3. `touch /Applications/Alhangeul.app`
  4. `killall Dock`
- 위 절차로도 반영되지 않으면 전역 IconServices 캐시 삭제 필요성을 보고서에 남기고, 실제 삭제는 작업지시자 별도 승인 후 수행한다.

### 산출물

- 표시 검증 스크린샷 또는 관찰 기록
- `mydocs/working/task_m014_292_stage4.md`

### 검증

```bash
defaults read com.apple.dock tilesize
defaults read com.apple.dock magnification
defaults read com.apple.dock largesize
git diff --check -- mydocs/working/task_m014_292_stage4.md
```

필요 시 낮은 영향 캐시 갱신:

```bash
touch /Applications/Alhangeul.app
killall Dock
```

### 커밋

```text
Task #292 Stage 4: AppIcon 표시 검증과 캐시 영향 정리
```

## Stage 5. 최종 보고와 PR 준비

### 목적

전후 점유율, 변경 파일, 빌드 검증, 표시 검증, 잔여 리스크를 정리하고 PR 게시 준비 상태로 만든다.

### 작업

- 최종 결과 보고서 작성
- 오늘할일 상태 완료 처리
- `git status`, `git diff --check`, 최근 커밋 목록 확인
- 제보자에게 PR에서 공유할 전후 비교 요약 작성

### 산출물

- `mydocs/report/task_m014_292_report.md`
- `mydocs/orders/20260529.md`

### 검증

```bash
git diff --check
git status --short --branch
git log --oneline -5
```

### 커밋

```text
Task #292 Stage 5 + 최종 보고서: AppIcon 여백 보강 결과 정리
```

## 구현 중단 기준

- 후보 축소율이 모두 작은 슬롯에서 식별성을 심하게 떨어뜨리는 경우
- 현재 자산에서 재생성했을 때 색상/알파가 비정상적으로 변형되는 경우
- HostApp build가 AppIcon과 무관한 기존 문제로 실패하고, 해당 실패가 이번 작업 범위를 넘어서는 경우
- 표시 검증을 위해 전역 IconServices 캐시 삭제가 필요해졌지만 작업지시자 승인이 없는 경우

## 승인 요청 사항

1. 위 5단계 구현계획 승인
2. Stage 1에서 후보 PNG와 측정 산출물을 `build.noindex/task292/` 아래에 만들고, 커밋 대상에서는 제외하는 방향 승인
3. Stage 2에서 기존 PNG 파일명과 `Contents.json` 구조를 유지하고 PNG 내용만 교체하는 방향 재승인
4. Stage 4에서 전역 IconServices 캐시 삭제는 별도 승인 없이는 수행하지 않는 방향 재승인

승인 전에는 AppIcon PNG와 소스 파일을 변경하지 않는다.
