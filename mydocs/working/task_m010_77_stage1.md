# Task #77 Stage 1 완료 보고서

## 단계 목적

외부 입력 PNG 세트가 macOS AppIcon 슬롯에 필요한 해상도를 모두 제공하는지 확인하고, 현재 HostApp이 AppIcon과 앱 내 로고 표시를 어떤 경로로 사용하는지 재확인했다.

## 산출물

- `mydocs/plans/task_m010_77_impl.md`
  - `Contents.json` 검증 명령을 `plutil -lint`에서 `jq empty`로 보정했다.
  - 이유: `Contents.json`은 Xcode asset catalog의 JSON 파일이며, 현재 환경에서 `plutil -lint`는 JSON을 plist로 해석하려다 실패했다. `file`과 `python3 -m json.tool`, `jq empty`로 JSON 구조가 정상임을 확인했다.
- `mydocs/working/task_m010_77_stage1.md`
  - Stage 1 확인 결과와 Stage 2 입력 대응표를 기록했다.

Stage 1에서는 AppIcon PNG 파일 자체를 아직 교체하지 않았다.

## 본문 변경 정도 / 본문 무손실 여부

코드와 앱 자산 본문 변경은 없다. 구현계획서의 검증 명령만 JSON 파일 형식에 맞게 보정했으며, 단계 구조와 변경 범위는 유지했다.

## 입력 자산 확인

Stage 2에서 사용할 입력 PNG 10개가 모두 존재하고 기대 pixel size와 일치한다.

| 입력 파일 | 확인 pixel size | Stage 2 대상 |
|-----------|-----------------|--------------|
| `Icon-iOS-Default-16x16@1x.png` | 16x16 | `icon_16x16.png` |
| `Icon-iOS-Default-16x16@2x.png` | 32x32 | `icon_16x16@2x.png` |
| `Icon-iOS-Default-32x32@1x.png` | 32x32 | `icon_32x32.png` |
| `Icon-iOS-Default-32x32@2x.png` | 64x64 | `icon_32x32@2x.png` |
| `Icon-iOS-Default-128x128@1x.png` | 128x128 | `icon_128x128.png` |
| `Icon-iOS-Default-128x128@2x.png` | 256x256 | `icon_128x128@2x.png` |
| `Icon-iOS-Default-256x256@1x.png` | 256x256 | `icon_256x256.png` |
| `Icon-iOS-Default-256x256@2x.png` | 512x512 | `icon_256x256@2x.png` |
| `Icon-iOS-Default-512x512@1x.png` | 512x512 | `icon_512x512.png` |
| `Icon-iOS-Default-1024x1024@1x.png` | 1024x1024 | `icon_512x512@2x.png` |

## AppIcon 연결 경로 확인

- `Sources/HostApp/Assets.xcassets/AppIcon.appiconset/Contents.json`에는 macOS AppIcon 슬롯 10개가 존재한다.
- `project.yml`은 HostApp의 `ASSETCATALOG_COMPILER_APPICON_NAME`을 `AppIcon`으로 지정한다.
- `Sources/HostApp/Views/AboutView.swift`의 About 헤더는 `NSApp.applicationIconImage`를 표시한다.
- 따라서 Stage 2에서 AppIcon PNG 10개를 교체하면 앱 아이콘과 About 화면의 로고 표시가 같은 자산을 따른다.

## 검증 결과

### 입력 PNG 해상도

```text
Icon-iOS-Default-16x16@1x.png: 16x16
Icon-iOS-Default-16x16@2x.png: 32x32
Icon-iOS-Default-32x32@1x.png: 32x32
Icon-iOS-Default-32x32@2x.png: 64x64
Icon-iOS-Default-128x128@1x.png: 128x128
Icon-iOS-Default-128x128@2x.png: 256x256
Icon-iOS-Default-256x256@1x.png: 256x256
Icon-iOS-Default-256x256@2x.png: 512x512
Icon-iOS-Default-512x512@1x.png: 512x512
Icon-iOS-Default-1024x1024@1x.png: 1024x1024
```

### AppIcon 슬롯

```text
icon_16x16.png       mac  16x16   1x
icon_16x16@2x.png    mac  16x16   2x
icon_32x32.png       mac  32x32   1x
icon_32x32@2x.png    mac  32x32   2x
icon_128x128.png     mac  128x128 1x
icon_128x128@2x.png  mac  128x128 2x
icon_256x256.png     mac  256x256 1x
icon_256x256@2x.png  mac  256x256 2x
icon_512x512.png     mac  512x512 1x
icon_512x512@2x.png  mac  512x512 2x
```

### 사용 경로

```text
project.yml:33: ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
Sources/HostApp/Views/AboutView.swift:56: Image(nsImage: NSApp.applicationIconImage)
```

### 명령 결과

- `jq empty Sources/HostApp/Assets.xcassets/AppIcon.appiconset/Contents.json`: 통과
- `git diff --check`: 통과
- `git status --short --branch`: `local/task77`에서 #77 범위 밖 변경 3개가 남아 있음

## 잔여 위험

- 현재 작업트리에 `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`, `rhwp-core.lock` 변경이 남아 있다. #77 범위 밖 변경이므로 되돌리거나 커밋하지 않았다. Stage 1 커밋에는 `mydocs/plans/task_m010_77_impl.md`와 본 보고서만 포함한다.
- Stage 2에서 실제 PNG를 교체한 뒤에는 AppIcon 입력 파일 10개의 해상도를 다시 확인해야 한다.

## 다음 단계 영향

Stage 2는 구현계획서의 대응표 그대로 진행할 수 있다. `Contents.json`과 `project.yml`은 변경하지 않고, 기존 AppIcon 파일명에 신규 PNG 내용만 덮어쓰면 된다.

## 승인 요청

Stage 1 결과를 승인하면 Stage 2(AppIcon PNG 교체)로 진행한다.
