# rhwp-mac

macOS용 HWP/HWPX Quick Look, Finder thumbnail, 문서 viewer 앱입니다.

이 프로젝트는 `rhwp` 코어 엔진을 직접 vendoring하지 않고 `Vendor/rhwp` git submodule로 고정해 사용합니다. 앱, Quick Look 확장, Swift bridge, 배포 정책은 이 레포가 소유합니다.

## 기능

- Finder Quick Look preview: `.hwp`, `.hwpx` 첫 페이지 미리보기
- Finder thumbnail: 첫 페이지 기반 아이콘 썸네일
- macOS viewer app: 파일 열기, 다중 페이지 스크롤, 확대/축소
- Rust `rhwp` 코어 정적 링크: `Rhwp.xcframework` 생성 후 앱/확장에서 사용

## 초기 설정

```bash
git submodule update --init --recursive
rustup target add aarch64-apple-darwin x86_64-apple-darwin
cargo install cbindgen
brew install xcodegen
```

## 빌드

`RustBridge` crate가 `Vendor/rhwp`를 path dependency로 사용해 macOS 앱용 C ABI를 export합니다.

```bash
./scripts/build-rust-macos.sh
xcodegen generate
xcodebuild -project RhwpMac.xcodeproj -scheme HostApp -configuration Debug build
```

## rhwp 코어 최신화

`rhwp` 코어는 upstream `devel` 브랜치를 기준으로 최신화합니다.

```bash
./scripts/update-rhwp-core.sh
./scripts/build-rust-macos.sh
./scripts/check-no-appkit.sh
```

릴리스에는 `rhwp-core.lock`의 submodule commit을 함께 기록합니다.

## 릴리스 패키징

```bash
./scripts/package-release.sh 0.1.0
```

산출물은 `build/release/rhwp-mac-<version>.zip`에 생성되며 SHA256을 출력합니다.
