# Issue #27 구현 계획서

## 구현 목표

앱 이름과 Finder 통합 검증 절차의 불일치를 최소 범위로 바로잡는다.

- 사용자에게 보이는 이름은 `알한글`로 맞춘다.
- 내부 ASCII 식별자는 필요한 경우 유지한다.
- Finder 통합 절차는 표준 검증과 문제 복구 절차를 구분한다.

## 단계 계획

### 1단계. 이름/운영 절차 기준 확정

- 현재 `project.yml`, Info.plist, 패키징 스크립트, README/manual의 이름 사용 위치를 다시 확인한다.
- `알한글`로 보여야 하는 값과 내부용으로 유지할 값을 구분한다.
- Finder 통합 절차에서 표준 검증과 troubleshooting으로 나눌 항목을 확정한다.

### 2단계. 설정과 패키징 정합화

- 사용자 노출 가능성이 있는 extension 표시명을 한글 기준으로 정리한다.
- 패키징 산출물이 `알한글.app` 기준으로 만들어지도록 스크립트를 조정한다.
- Homebrew Cask의 앱 이름 설명을 실제 산출물 기준으로 맞춘다.

### 3단계. 관련 문서 최소 수정

- README와 build/run manual의 앱 경로와 Finder 검증 절차를 보정한다.
- release manual의 앱 이름, 패키징, Cask 확인 항목을 보정한다.
- project architecture 문서에는 사용자 표시명과 내부 식별자 경계만 필요한 만큼 반영한다.

### 4단계. 검증 및 보고 준비

- Xcode project 재생성 및 build setting을 확인한다.
- 앱 빌드와 패키징 산출물을 확인한다.
- 단계별 완료 보고서에 실제 변경과 검증 결과를 정리한다.

## 단계별 검증

- 1단계 후:
  - `git diff --check -- mydocs/plans/task_m050_27_impl.md`

- 2단계 후:
  - `xcodegen generate`
  - `xcodebuild -showBuildSettings -project RhwpMac.xcodeproj -scheme HostApp`
  - `git diff --check -- project.yml scripts/package-release.sh Casks/rhwp-mac.rb Sources/QLExtension/Info.plist Sources/ThumbnailExtension/Info.plist`

- 3단계 후:
  - `git diff --check -- README.md mydocs/tech/project_architecture.md mydocs/manual/build_run_guide.md mydocs/manual/release_distribution_guide.md`

- 4단계 후:
  - `xcodebuild -project RhwpMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build`
  - `./scripts/package-release.sh 0.1.0`
  - 필요 시 `pluginkit` / `qlmanage` smoke test
  - `git diff --check`

## 보류 기준

다음 조건 중 하나가 발생하면 다음 단계로 넘어가지 않고 보고 후 승인 대기한다.

1. `알한글.app` 번들 경로가 Finder/Quick Look 등록 실패를 재현하는 경우
2. 패키징 산출물 이름 변경이 Cask 또는 release guide와 충돌하는 경우
3. 표준 Finder 검증 절차와 troubleshooting 절차를 명확히 분리하기 어려운 경우
4. 이번 범위를 넘어서는 서명/공증/릴리스 자동화 변경이 필요한 경우

## 승인 요청 사항

- 이 구현 계획서 기준으로 1단계 구현 진행 승인 요청
