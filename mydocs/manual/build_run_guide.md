# 빌드 및 실행 가이드

## 목적

이 문서는 개발 중 필요한 빌드/실행/검증 절차를 정리한다. `AGENTS.md`에는 최소 강제 규칙만 유지하고, 상세 명령은 이 문서를 참조한다.

## 초기 설정

```bash
git submodule update --init --recursive
rustup target add aarch64-apple-darwin x86_64-apple-darwin
cargo install cbindgen
brew install xcodegen
```

## Rust bridge 및 XCFramework

```bash
./scripts/build-rust-macos.sh
```

이 스크립트가 수행하는 일:

- `RustBridge` staticlib arm64/x86_64 빌드
- `lipo`로 universal staticlib 생성
- `cbindgen`으로 C header 생성
- `rhwp-ffi-symbols.txt`와 생성 심볼 비교
- `Frameworks/Rhwp.xcframework` 생성

## Xcode 프로젝트 생성

```bash
xcodegen generate
```

`project.yml`이 원본이며 `RhwpMac.xcodeproj`를 직접 수정하지 않는다.

## HostApp 빌드

Debug:

```bash
xcodebuild -project RhwpMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Release:

```bash
xcodebuild -project RhwpMac.xcodeproj \
  -scheme HostApp \
  -configuration Release \
  -derivedDataPath build/DerivedDataRelease \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## 렌더링 smoke test

```bash
./scripts/validate-stage3-render.sh
```

기본 샘플:

- `Vendor/rhwp/samples/basic/KTX.hwp`
- `Vendor/rhwp/samples/basic/request.hwp`
- `Vendor/rhwp/samples/exam_kor.hwp`

## Shared Swift bridge 검사

```bash
./scripts/check-no-appkit.sh
```

`Sources/RhwpCoreBridge`에는 AppKit/UIKit 직접 의존을 넣지 않는다.

## Finder 통합 확인

앱 실행만 확인할 때:

```bash
open build/DerivedData/Build/Products/Debug/RhwpMac.app
```

Finder 통합은 단일 설치본 기준으로 확인한다.

```bash
mkdir -p ~/Applications
rm -rf ~/Applications/RhwpMac.app
ditto build/DerivedData/Build/Products/Debug/RhwpMac.app ~/Applications/RhwpMac.app
pluginkit -a ~/Applications/RhwpMac.app
```

앱과 extension의 사용자 표시명은 `Info.plist`에서 `알한글` 계열로 노출한다. Finder/Quick Look smoke test용 filesystem bundle path는 ExtensionKit lookup 안정성을 위해 `RhwpMac.app`처럼 ASCII 이름을 유지한다.

extension 등록 확인:

```bash
pluginkit -m | grep com.postmelee.rhwpmac
```

Quick Look 캐시 갱신:

```bash
qlmanage -r
qlmanage -r cache
```

preview 확인:

```bash
qlmanage -p Vendor/rhwp/samples/basic/KTX.hwp
```

build 산출물이 중복 discovery되어 잘못된 extension 경로가 잡힐 때만 기존 build 산출물을 임시로 제외한다.
