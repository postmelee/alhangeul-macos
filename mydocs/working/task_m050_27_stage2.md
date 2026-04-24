# Issue #27 단계 2 완료 보고서

## 작업 내용

- extension 표시명을 한글 기준으로 정리했다.
- release 패키징이 `알한글.app`을 zip에 담도록 조정했다.
- Homebrew Cask의 저장소 URL과 표시 이름을 현재 저장소/앱 이름 기준으로 맞췄다.

## 변경 내용

### 1. extension 표시명

- `Sources/QLExtension/Info.plist`
  - `알한글 Preview` -> `알한글 미리보기`
- `Sources/ThumbnailExtension/Info.plist`
  - `알한글 Thumbnail` -> `알한글 썸네일`

### 2. release 패키징

- `scripts/package-release.sh`는 Xcode build 산출물 `RhwpMac.app`을 확인한다.
- zip 생성 전 `build/release/알한글.app`로 복사한 뒤, `알한글.app`을 포함해 압축한다.
- 내부 Xcode product name은 변경하지 않았다.

### 3. Homebrew Cask

- release URL과 homepage를 `postmelee/alhangeul-macos` 기준으로 변경했다.
- Cask 표시 이름을 `알한글`로 변경했다.
- 설치 앱 항목 `app "알한글.app"`은 유지했다.

## 검증

- `xcodegen generate`
- `xcodebuild -showBuildSettings -project RhwpMac.xcodeproj -scheme HostApp`
  - 확인: `PRODUCT_NAME = RhwpMac`
  - 확인: `WRAPPER_NAME = RhwpMac.app`
  - 확인: `FULL_PRODUCT_NAME = RhwpMac.app`
- `plutil -lint Sources/QLExtension/Info.plist Sources/ThumbnailExtension/Info.plist`
- `bash -n scripts/package-release.sh`
- `git diff --check -- project.yml scripts/package-release.sh Casks/rhwp-mac.rb Sources/QLExtension/Info.plist Sources/ThumbnailExtension/Info.plist`

## 다음 단계

- 3단계에서 README와 manual 문서의 앱 경로, 패키징, Finder 검증 절차 설명을 최소 수정한다.

## 승인 요청 사항

- 이 단계 완료 기준으로 3단계 진행 승인 요청
