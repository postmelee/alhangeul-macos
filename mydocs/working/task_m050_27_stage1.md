# Issue #27 단계 1 완료 보고서

## 작업 내용

- 앱 이름이 노출되는 설정, 스크립트, 문서 위치를 확인했다.
- `알한글`로 보여야 하는 값과 내부용 ASCII 값을 구분했다.
- Finder 통합 검증 절차의 표준 절차와 troubleshooting 절차를 나눴다.

## 확인 결과

### 1. 이름 사용 위치

- `project.yml`의 `PRODUCT_NAME`은 현재 `RhwpMac`, `RhwpMacPreview`, `RhwpMacThumbnail`이다.
- HostApp `Info.plist`의 `CFBundleDisplayName`과 `CFBundleName`은 이미 `알한글`이다.
- QLExtension / ThumbnailExtension 표시명은 `알한글 Preview`, `알한글 Thumbnail`로 영어 표현이 섞여 있다.
- `scripts/package-release.sh`, `Casks/rhwp-mac.rb`, README/manual 일부는 `알한글.app`을 기준으로 설명한다.
- README/manual 일부는 실제 개발 build 산출물과 맞지 않는 `build/DerivedData/.../알한글.app` 경로를 안내한다.

### 2. 이름 정책

- 사용자에게 보이는 앱 이름과 배포 앱 번들명은 `알한글`로 맞춘다.
- extension 표시명도 한글 기준으로 정리한다.
- bundle identifier, executable name, Swift module name, extension product path는 시스템 식별과 Swift principal class 안정성을 위해 ASCII 계열을 유지한다.
- Xcode 개발 build 산출물명은 내부 산출물로 보고, 사용자 배포/설치 단계에서 `알한글.app`로 맞춘다.

### 3. Finder 통합 절차 판단

- DerivedData 산출물을 바로 여는 절차는 앱 빌드/실행 확인에는 사용할 수 있지만 Finder Quick Look/Thumbnail 등록 검증 기준으로는 부적합하다.
- 표준 Finder 통합 검증은 단일 설치본을 기준으로 한다.
  - 예: build 산출물을 검증용 설치 위치에 `알한글.app`로 배치
  - `pluginkit -a`로 해당 설치본을 명시 등록
  - `pluginkit`, `qlmanage`로 확인
- `.app.disabled`로 build 산출물을 감추는 방식은 표준 절차가 아니라, 중복 discovery가 실제로 확인된 경우의 troubleshooting 절차로 분리한다.

## 다음 단계

- 2단계에서 extension 표시명, 패키징 스크립트, Cask를 이 기준에 맞춰 최소 수정한다.

## 승인 요청 사항

- 이 단계 완료 기준으로 2단계 진행 승인 요청
