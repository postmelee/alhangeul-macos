# Task M014 #292 Stage 3 완료 보고서

## 단계 목적

재생성한 AppIcon PNG가 HostApp Debug build 산출물에 반영되는지 확인하고, 빌드된 app bundle의 icon metadata와 asset catalog 결과를 검증한다.

## 수행 내용

- `xcodegen generate --spec project.yml`을 실행해 `Alhangeul.xcodeproj`를 재생성했다.
- 재생성 후 `Alhangeul.xcodeproj`와 `project.yml`에 diff가 없음을 확인했다.
- HostApp Debug build를 `build.noindex/DerivedDataTask292` 아래에서 수행했다.
- 빌드 중 로컬 `Frameworks/Rhwp.xcframework`가 현재 Swift source가 기대하는 FFI 심볼보다 오래된 것을 확인하고 `./scripts/build-rust-macos.sh`로 Rust bridge 산출물을 재생성했다.
- 재생성한 `Frameworks/generated_rhwp.h`와 `Frameworks/Rhwp.xcframework/.../rhwp.h`에 `rhwp_page_overlay_images`가 포함된 것을 확인했다.
- 빌드된 app bundle의 `Info.plist`, `AppIcon.icns`, asset catalog `Assets.car`를 확인했다.
- `iconutil`로 추출 가능한 `AppIcon.icns` 슬롯의 해상도와 strong bbox를 측정했다.

## 생성 산출물

커밋 대상이 아닌 검증 산출물:

- `build.noindex/DerivedDataTask292/`
- `build.noindex/task292/AppIcon.iconset/`
- `build.noindex/task292/stage3-icns-metrics.csv`
- `build.noindex/task292/stage3-assets-car-info.json`
- `build.noindex/task292/stage3-assets-car-appicon-renditions.csv`

커밋 대상:

- `mydocs/working/task_m014_292_stage3.md`
- `mydocs/orders/20260529.md`

## 빌드 결과

최종 빌드 명령:

```text
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedDataTask292 CODE_SIGNING_ALLOWED=NO build
```

결과:

- `** BUILD SUCCEEDED **`
- 산출물: `build.noindex/DerivedDataTask292/Build/Products/Debug/Alhangeul.app`
- `AppIcon.icns`: `build.noindex/DerivedDataTask292/Build/Products/Debug/Alhangeul.app/Contents/Resources/AppIcon.icns`

## 환경 이슈와 조치

첫 번째 `xcodebuild`는 Sparkle package fetch 단계에서 sandbox network 제한으로 실패했다.

```text
Could not resolve host: github.com
```

외부 실행으로 재시도해 Sparkle `2.9.1` package resolution을 완료했다.

두 번째 빌드는 `RhwpDocument.swift`가 기대하는 `rhwp_page_overlay_images` FFI 심볼이 로컬 generated header에 없어 실패했다.

```text
cannot find 'rhwp_page_overlay_images' in scope
```

이는 이번 AppIcon 변경 때문이 아니라 로컬 생성 산출물 준비 문제였다. `./scripts/build-rust-macos.sh` 실행 후 generated header와 XCFramework header에서 해당 심볼을 확인했고, 이후 같은 HostApp Debug build가 성공했다.

일반 sandbox 안의 후속 `xcodebuild`는 SwiftPM/clang 사용자 cache 쓰기 제한으로 실패했다.

```text
error opening '/Users/melee/.cache/clang/ModuleCache/Swift-5SCGS38H536W.swiftmodule' for output
```

동일 명령을 외부 실행으로 재시도해 성공했다.

## Bundle icon metadata

`Info.plist` 확인 결과:

| 항목 | 값 |
|------|----|
| `CFBundleIconFile` | `AppIcon` |
| `CFBundleIconName` | `AppIcon` |
| `CFBundleShortVersionString` | `0.1.3` |
| `CFBundleVersion` | `9` |

`xcodebuild -showBuildSettings`에서 확인한 관련 설정:

| 항목 | 값 |
|------|----|
| `ASSETCATALOG_COMPILER_APPICON_NAME` | `AppIcon` |
| `INFOPLIST_FILE` | `Sources/HostApp/Info.plist` |
| `PRODUCT_BUNDLE_IDENTIFIER` | `com.postmelee.alhangeul` |

## AppIcon.icns 추출 결과

`iconutil` 추출 명령:

```text
iconutil -c iconset -o build.noindex/task292/AppIcon.iconset build.noindex/DerivedDataTask292/Build/Products/Debug/Alhangeul.app/Contents/Resources/AppIcon.icns
```

추출된 슬롯:

| 파일 | size | strong bbox | strong coverage | strong bbox px |
|------|------|-------------|-----------------|----------------|
| `icon_16x16.png` | `16x16` | `0.8125 x 0.8125` | `0.5664` | `13x13` |
| `icon_16x16@2x.png` | `32x32` | `0.8125 x 0.8125` | `0.5859` | `26x26` |
| `icon_128x128.png` | `128x128` | `0.8047 x 0.8047` | `0.6006` | `103x103` |
| `icon_128x128@2x.png` | `256x256` | `0.8047 x 0.8047` | `0.6042` | `206x206` |

`AppIcon.icns` 내부 chunk:

```text
ic13 37165
ic11 1686
ic04 656
ic07 12573
```

이 환경의 Xcode asset catalog build가 만든 legacy `AppIcon.icns`는 추출 가능한 슬롯이 16/32/128/256 계열로 제한된다. 따라서 512/1024 슬롯의 반영 여부는 `AppIcon.icns`만으로 판단하지 않고, 함께 생성된 `Assets.car`의 AppIcon rendition 목록으로 확인했다.

## Assets.car AppIcon 확인

`xcrun assetutil --info` 기준 `Assets.car`에는 AppIcon rendition 10개가 모두 포함되어 있다.

| rendition | pixel size | scale | icon index |
|-----------|------------|-------|------------|
| `icon_16x16.png` | `16x16` | `1` | `1` |
| `icon_16x16@2x.png` | `32x32` | `2` | `1` |
| `icon_32x32.png` | `32x32` | `1` | `2` |
| `icon_32x32@2x.png` | `64x64` | `2` | `2` |
| `icon_128x128.png` | `128x128` | `1` | `3` |
| `icon_128x128@2x.png` | `256x256` | `2` | `3` |
| `icon_256x256.png` | `256x256` | `1` | `4` |
| `icon_256x256@2x.png` | `512x512` | `2` | `4` |
| `icon_512x512.png` | `512x512` | `1` | `5` |
| `icon_512x512@2x.png` | `1024x1024` | `2` | `5` |

즉 asset catalog 입력 PNG 10개는 build 산출물의 `Assets.car`에 모두 반영됐다. Stage 2의 `824 / 1024 = 0.8046875` keyline은 `AppIcon.icns`에서 추출 가능한 128px 이상 슬롯에서도 유지된다.

## 검증 결과

```text
xcodegen generate --spec project.yml
git diff --quiet -- Alhangeul.xcodeproj project.yml
```

결과:

- 통과. `project.yml`과 generated Xcode project의 tracked diff 없음.

```text
./scripts/build-rust-macos.sh
```

결과:

- 통과. `Frameworks/Rhwp.xcframework` 재생성 완료.
- generated FFI symbols에 `rhwp_page_overlay_images` 포함.

```text
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedDataTask292 CODE_SIGNING_ALLOWED=NO build
```

결과:

- 통과. `** BUILD SUCCEEDED **`

```text
plutil -p build.noindex/DerivedDataTask292/Build/Products/Debug/Alhangeul.app/Contents/Info.plist | rg 'CFBundleIcon|CFBundleShortVersionString|CFBundleVersion'
```

결과:

- `CFBundleIconFile`, `CFBundleIconName`, version/build 확인.

```text
sips -g pixelWidth -g pixelHeight build.noindex/task292/AppIcon.iconset/*.png
```

결과:

- `16x16`, `32x32`, `128x128`, `256x256` 추출 슬롯 확인.

```text
git status --short --branch
```

결과:

- Stage 3 보고서 작성 전에는 tracked source diff 없음.

## 변경 범위

Stage 3는 빌드/산출물 검증 단계다. 소스 AppIcon PNG, `Contents.json`, `project.yml`, Swift source, Rust source는 변경하지 않았다.

`Frameworks/Rhwp.xcframework`와 `Frameworks/generated_rhwp.h`는 로컬 빌드 준비용 생성 산출물이며 git tracking 대상이 아니다.

## 잔여 리스크

- Dock/Finder/About의 실제 표시 결과는 아직 확인하지 않았다. macOS IconServices와 Dock cache가 개입하므로 Stage 4에서 별도 검증한다.
- 이 Xcode/macOS 환경의 legacy `AppIcon.icns`는 512/1024 슬롯을 직접 추출할 수 없었다. 다만 `Assets.car`에는 512/1024 포함 AppIcon rendition 10개가 모두 존재한다. 실제 표시 경로가 `CFBundleIconFile`의 legacy `.icns`를 우선하는지, `CFBundleIconName` 기반 asset catalog를 우선하는지는 Stage 4의 화면 검증에서 확인한다.

## 다음 단계

작업지시자가 Stage 3 결과를 승인하면 Stage 4에서 Dock/Finder/About 표시를 확인하고, 캐시 영향 여부를 낮은 영향 순서로 분리한다.
