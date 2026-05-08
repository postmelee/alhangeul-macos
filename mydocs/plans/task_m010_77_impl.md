# Task #77 구현 계획서

본 문서는 [`task_m010_77.md`](task_m010_77.md) 수행계획서를 단계별 실행 단위로 분해한 것이다. 각 단계 완료 후 [`task-stage-report`](../skills/task-stage-report/SKILL.md) skill로 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 환경

- **Worktree**: `/Users/melee/Documents/projects/rhwp-mac`
- **Branch**: `local/task77`
- **Issue**: #77
- **Milestone**: M010 (`v0.1`)
- **입력 자산**: `/Users/melee/Documents/projects/Icon Exports`
- **대상 AppIcon**: `Sources/HostApp/Assets.xcassets/AppIcon.appiconset`

## 구현 원칙

- v0.1.0 배포물에 포함될 앱 대표 이미지만 교체한다.
- `project.yml`은 이미 `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`을 지정하므로 변경하지 않는다.
- `Contents.json`의 슬롯과 파일명은 유지하고 PNG 내용만 교체한다.
- About 화면은 `NSApp.applicationIconImage`를 사용하므로 별도 Swift 코드 변경 없이 AppIcon 교체 결과를 따르는지 확인한다.
- README 문서용 `assets/logo-256@2x.png`, `assets/home_banner.png`는 이번 작업 범위에서 제외한다.
- `Sources/RhwpCoreBridge`에는 변경을 만들지 않는다.

## Stage 1. 입력 자산과 현재 AppIcon 정합성 확인

### 목표

- 외부 입력 PNG 세트가 macOS AppIcon 슬롯에 필요한 해상도를 모두 제공하는지 확인한다.
- 현재 프로젝트가 HostApp AppIcon과 About 화면 아이콘 표시를 어떤 경로로 사용하는지 재확인한다.

### 작업

- `/Users/melee/Documents/projects/Icon Exports`의 PNG 목록을 확인한다.
- `sips`로 Stage 2에서 사용할 10개 입력 PNG의 pixel size를 확인한다.
- `Sources/HostApp/Assets.xcassets/AppIcon.appiconset/Contents.json`의 macOS 슬롯 10개를 확인한다.
- `project.yml`에서 `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` 유지 여부를 확인한다.
- `Sources/HostApp/Views/AboutView.swift`가 `NSApp.applicationIconImage`를 표시하는지 확인한다.
- Stage 2 파일 대응표를 단계 보고서에 기록한다.

### 파일 대응표

| AppIcon 파일 | 입력 파일 | 기대 pixel size |
|--------------|-----------|----------------|
| `icon_16x16.png` | `Icon-iOS-Default-16x16@1x.png` | 16x16 |
| `icon_16x16@2x.png` | `Icon-iOS-Default-16x16@2x.png` | 32x32 |
| `icon_32x32.png` | `Icon-iOS-Default-32x32@1x.png` | 32x32 |
| `icon_32x32@2x.png` | `Icon-iOS-Default-32x32@2x.png` | 64x64 |
| `icon_128x128.png` | `Icon-iOS-Default-128x128@1x.png` | 128x128 |
| `icon_128x128@2x.png` | `Icon-iOS-Default-128x128@2x.png` | 256x256 |
| `icon_256x256.png` | `Icon-iOS-Default-256x256@1x.png` | 256x256 |
| `icon_256x256@2x.png` | `Icon-iOS-Default-256x256@2x.png` | 512x512 |
| `icon_512x512.png` | `Icon-iOS-Default-512x512@1x.png` | 512x512 |
| `icon_512x512@2x.png` | `Icon-iOS-Default-1024x1024@1x.png` | 1024x1024 |

### 완료 기준

- 입력 PNG 10개가 모두 존재한다.
- 입력 PNG 10개의 pixel size가 AppIcon 슬롯과 일치한다.
- 프로젝트 설정과 About 화면 경로상 AppIcon 교체만으로 앱 아이콘과 앱 내 로고 표시가 함께 반영됨을 확인한다.

### 검증

```bash
git status --short --branch
sips -g pixelWidth -g pixelHeight \
  "/Users/melee/Documents/projects/Icon Exports/Icon-iOS-Default-16x16@1x.png" \
  "/Users/melee/Documents/projects/Icon Exports/Icon-iOS-Default-16x16@2x.png" \
  "/Users/melee/Documents/projects/Icon Exports/Icon-iOS-Default-32x32@1x.png" \
  "/Users/melee/Documents/projects/Icon Exports/Icon-iOS-Default-32x32@2x.png" \
  "/Users/melee/Documents/projects/Icon Exports/Icon-iOS-Default-128x128@1x.png" \
  "/Users/melee/Documents/projects/Icon Exports/Icon-iOS-Default-128x128@2x.png" \
  "/Users/melee/Documents/projects/Icon Exports/Icon-iOS-Default-256x256@1x.png" \
  "/Users/melee/Documents/projects/Icon Exports/Icon-iOS-Default-256x256@2x.png" \
  "/Users/melee/Documents/projects/Icon Exports/Icon-iOS-Default-512x512@1x.png" \
  "/Users/melee/Documents/projects/Icon Exports/Icon-iOS-Default-1024x1024@1x.png"
jq empty Sources/HostApp/Assets.xcassets/AppIcon.appiconset/Contents.json
rg -n "ASSETCATALOG_COMPILER_APPICON_NAME|NSApp.applicationIconImage|AppIcon" project.yml Sources/HostApp
git diff --check
```

### 커밋 메시지

```text
Task #77 Stage 1: AppIcon 입력 자산 정합성 확인
```

## Stage 2. AppIcon PNG 교체

### 목표

- 기존 macOS AppIcon 파일명과 `Contents.json` 구조를 유지한 채 PNG 내용을 신규 아이콘으로 교체한다.
- 교체 후 asset catalog 슬롯과 실제 PNG 해상도가 일치함을 확인한다.

### 작업

- Stage 1 대응표에 따라 외부 입력 PNG 10개를 `Sources/HostApp/Assets.xcassets/AppIcon.appiconset`의 기존 파일명으로 복사한다.
- `Contents.json`을 수정하지 않았음을 확인한다.
- 교체 후 AppIcon PNG 10개의 pixel size를 확인한다.
- `git diff --stat`으로 변경 범위가 AppIcon PNG 10개와 단계 보고서에 한정되는지 확인한다.

### 완료 기준

- AppIcon PNG 10개가 신규 이미지 내용으로 교체된다.
- `Contents.json`에는 불필요한 변경이 없다.
- 각 PNG의 pixel size가 `Contents.json`의 size/scale 슬롯과 일치한다.
- 앱 코드, bridge, extension 로직에는 변경이 없다.

### 검증

```bash
git status --short --branch
sips -g pixelWidth -g pixelHeight Sources/HostApp/Assets.xcassets/AppIcon.appiconset/*.png
jq empty Sources/HostApp/Assets.xcassets/AppIcon.appiconset/Contents.json
git diff --check
git diff --stat
```

### 커밋 메시지

```text
Task #77 Stage 2: HostApp AppIcon 이미지 교체
```

## Stage 3. 빌드 산출물 검증과 최종 보고

### 목표

- 교체된 AppIcon이 HostApp 빌드에 포함되는지 확인한다.
- 단계별 검증 결과를 최종 보고서와 오늘할일에 반영한다.

### 작업

- `project.yml` 변경이 없으므로 `xcodegen generate`는 생략한다. 단, 빌드 실패가 project 상태 문제로 보이면 즉시 보고 후 재판단한다.
- HostApp Debug build를 실행한다.
- 빌드된 앱 번들에 asset catalog 산출물(`Assets.car`)이 포함되는지 확인한다.
- 가능한 경우 앱 번들의 아이콘 리소스 또는 About 화면 표시 경로를 추가 확인한다.
- `./scripts/check-no-appkit.sh`로 bridge 경계 위반이 없음을 확인한다.
- 최종 결과 보고서(`mydocs/report/task_m010_77_report.md`)를 작성한다.
- 오늘할일 `#77` 행을 완료 상태로 갱신한다.

### 완료 기준

- HostApp Debug build가 성공한다.
- `Sources/RhwpCoreBridge` 변경이 없고 AppKit/UIKit 경계 위반이 없다.
- 신규 AppIcon PNG가 asset catalog 입력으로 유지되고 빌드 산출물에 포함된다.
- 최종 보고서에 적용 파일, 검증 명령, 남은 리스크가 기록된다.

### 검증

```bash
git status --short --branch
git diff --check
./scripts/check-no-appkit.sh
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
find build.noindex/DerivedData -path "*AlhangeulMac.app/Contents/Resources/Assets.car" -print
```

### 커밋 메시지

```text
Task #77 Stage 3 + 최종 보고서: AppIcon 빌드 검증과 보고
```

## 승인 요청 사항

1. 본 구현계획서의 3단계 분해와 단계별 변경 범위
2. README 문서용 `assets/logo-256@2x.png`, `assets/home_banner.png`를 이번 작업에서 제외하는 최종 결정
3. Stage 2에서 `Contents.json` 파일명 유지 + PNG 내용만 교체하는 방식
4. 본 구현계획서 승인 후 Stage 1 정합성 확인부터 순차 진행
