# Task #104 Stage 4 완료 보고서 - 앱 version 정합성과 render smoke 검증

## 목적

`v0.7.9` Rust bridge 산출물이 준비된 상태에서 app/extension version 정합성을 확인하고, XcodeGen project 재생성, Swift/macOS Debug build, 기본 render smoke를 수행한다.

## version 방침 결과

Stage 1에서 정한 기본 방침대로 app/extension version은 변경하지 않았다.

source plist raw value:

```text
HostApp:             CFBundleShortVersionString = 0.1.0, CFBundleVersion = 1
QLExtension:         CFBundleShortVersionString = 0.1.0, CFBundleVersion = 1
ThumbnailExtension:  CFBundleShortVersionString = 0.1.0, CFBundleVersion = 1
```

Debug build output도 같은 version을 포함한다.

```text
AlhangeulMac.app:                  0.1.0 (1)
AlhangeulMacPreview.appex:         0.1.0 (1)
AlhangeulMacThumbnail.appex:       0.1.0 (1)
```

이번 작업은 public release가 아니라 Release package를 표준 Applications 경로에 등록해 검증하는 작업이다. 따라서 `CFBundleShortVersionString`과 `CFBundleVersion`을 별도로 올리지 않고, Stage 5에서 `./scripts/package-release.sh 0.1.0` 산출물을 등록한다.

## Xcode project

프로젝트 형태:

```text
./AlhangeulMac.xcodeproj
./AlhangeulMac.xcodeproj/project.xcworkspace
```

`xcodebuild -list -project AlhangeulMac.xcodeproj` 확인 결과:

```text
Targets:
    HostApp
    QLExtension
    ThumbnailExtension

Schemes:
    HostApp
    QLExtension
    ThumbnailExtension
```

`xcodegen generate`는 성공했고, tracked project diff는 발생하지 않았다.

## no-AppKit 규칙

실행 명령:

```bash
./scripts/check-no-appkit.sh
```

결과:

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

## Debug build

실행 명령:

```bash
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과:

```text
** BUILD SUCCEEDED ** [12.845 sec]
```

build는 `HostApp`, `QLExtension`, `ThumbnailExtension` dependency graph를 모두 처리했고, `AlhangeulMac.app` 안에 `AlhangeulMacPreview.appex`, `AlhangeulMacThumbnail.appex`를 embed했다.

Xcode는 이번 단계에서도 CoreSimulatorService, DVT file event stream, provisioning profile 관련 경고를 출력했다. macOS Debug build 자체는 성공했으므로 Stage 4에서는 환경 경고로 기록한다.

## render smoke

실행 명령:

```bash
./scripts/validate-stage3-render.sh
```

결과:

```text
LAYOUT_OVERFLOW_DRAW: section=0 pi=28 line=0 y=768.5 col_bottom=755.9 overflow=12.5px
LAYOUT_OVERFLOW: page=0, col=0, para=28, type=PartialParagraph, y=776.5, bottom=755.9, overflow=20.5px
OK KTX.hwp: page=1 size=1123x794 textRuns=436 hangulRuns=76 hangulScalars=209 nonWhitePixels=452034 png=/Users/melee/Documents/projects/rhwp-mac/output/stage3-render/KTX-page1.png
OK request.hwp: page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=53257 png=/Users/melee/Documents/projects/rhwp-mac/output/stage3-render/request-page1.png
OK exam_kor.hwp: page=1 size=1123x1588 textRuns=133 hangulRuns=86 hangulScalars=1368 nonWhitePixels=174108 png=/Users/melee/Documents/projects/rhwp-mac/output/stage3-render/exam_kor-page1.png
```

`KTX.hwp`에서 layout overflow 진단 로그가 출력됐지만, 기본 smoke 기준의 문서 open, page size, render tree decode, 한글 text run, non-white bitmap 생성은 세 샘플 모두 통과했다.

생성 PNG 확인:

```text
output/stage3-render/KTX-page1.png:      PNG image data, 1123 x 794, 8-bit/color RGBA, non-interlaced
output/stage3-render/request-page1.png:  PNG image data, 567 x 794, 8-bit/color RGBA, non-interlaced
output/stage3-render/exam_kor-page1.png: PNG image data, 1123 x 1588, 8-bit/color RGBA, non-interlaced
```

## 검증

실행한 명령:

```bash
./scripts/build-rust-macos.sh --verify-lock
plutil -extract CFBundleShortVersionString raw -o - Sources/HostApp/Info.plist
plutil -extract CFBundleVersion raw -o - Sources/HostApp/Info.plist
plutil -extract CFBundleShortVersionString raw -o - Sources/QLExtension/Info.plist
plutil -extract CFBundleVersion raw -o - Sources/QLExtension/Info.plist
plutil -extract CFBundleShortVersionString raw -o - Sources/ThumbnailExtension/Info.plist
plutil -extract CFBundleVersion raw -o - Sources/ThumbnailExtension/Info.plist
./scripts/check-no-appkit.sh
xcodebuild -list -project AlhangeulMac.xcodeproj
xcodegen generate
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
./scripts/validate-stage3-render.sh
plutil -extract CFBundleShortVersionString raw -o - build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app/Contents/Info.plist
plutil -extract CFBundleVersion raw -o - build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app/Contents/Info.plist
plutil -extract CFBundleShortVersionString raw -o - build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app/Contents/PlugIns/AlhangeulMacPreview.appex/Contents/Info.plist
plutil -extract CFBundleVersion raw -o - build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app/Contents/PlugIns/AlhangeulMacPreview.appex/Contents/Info.plist
plutil -extract CFBundleShortVersionString raw -o - build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app/Contents/PlugIns/AlhangeulMacThumbnail.appex/Contents/Info.plist
plutil -extract CFBundleVersion raw -o - build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app/Contents/PlugIns/AlhangeulMacThumbnail.appex/Contents/Info.plist
file output/stage3-render/KTX-page1.png output/stage3-render/request-page1.png output/stage3-render/exam_kor-page1.png
git diff --check
git status --short
```

검증 결과:

- `./scripts/build-rust-macos.sh --verify-lock` 통과
- app/extension source plist version 일치
- Debug build output app/extension version 일치
- `./scripts/check-no-appkit.sh` 통과
- `xcodegen generate` 성공, tracked project 변경 없음
- HostApp Debug build 성공
- `./scripts/validate-stage3-render.sh` 통과
- `git diff --check` 통과
- Stage 4 source 변경 없음

## 다음 단계

Stage 5에서는 `./scripts/package-release.sh 0.1.0`으로 Release package를 생성하고, 산출물을 `$HOME/Applications/AlhangeulMac.app`에 설치한 뒤 LaunchServices/PlugInKit 등록, Quick Look/Thumbnail/Viewer smoke를 수행한다.
