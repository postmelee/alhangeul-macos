# Issue #22 단계 4 완료 보고서

## 작업 내용

- `ThumbnailExtension`의 최소 요청 크기 제한을 제거했다.
- 수정된 Release 설치본을 `~/Applications/RhwpMac.app`에 다시 배치하고 PlugInKit에 재등록했다.
- 작은 요청 크기(`16`, `32`, `64`)에서 실제로 thumbnail provider가 동작하는지 사용자 파일 기준으로 다시 검증했다.

## 코드 변경

### 1. `QLThumbnailMinimumDimension` 제거

- `Sources/ThumbnailExtension/Info.plist`에서 `NSExtensionAttributes.QLThumbnailMinimumDimension` 키를 제거했다.
- 기존 값은 `64`였고, 이 값 때문에 Finder의 작은 아이콘 보기나 표준 리스트 크기 일부에서 thumbnail extension이 호출되지 않고 일반 아이콘으로 내려가고 있었다.
- Apple 문서 권고에 맞춰, 현재 생성기가 충분히 빠른 전제에서 최소 크기 키를 생략하는 방향으로 정리했다.

### 2. 설치본/빌드 산출물 재정리

- `build/DerivedDataReleaseSigned/Build/Products/Release/RhwpMac.app`를 기반으로 `~/Applications/RhwpMac.app`를 다시 설치했다.
- 기존 설치본은 `~/.Trash/RhwpMac.app.stage4-before-small-thumbnail-fix`로 백업 이동했다.
- build 산출물 경로가 LaunchServices/Quick Look discovery에 다시 개입하지 않도록 다음 앱 번들은 `.app.disabled`로 바꿨다.
  - `build/DerivedData/Build/Products/Debug/RhwpMac.app.disabled`
  - `build/DerivedDataReleaseSigned/Build/Products/Release/RhwpMac.app.disabled`

## 원인 정리

small-size thumbnail 미노출의 직접 원인은 FFI나 렌더러가 아니라 thumbnail extension 설정이었다.

- 기존 설정:
  - `QLThumbnailMinimumDimension = 64`
- 결과:
  - `64pt`보다 작은 요청에서는 macOS가 우리 thumbnail provider를 호출하지 않고 일반 아이콘을 사용
- 수정 후:
  - extension 수준의 최소 크기 제한이 사라져 `16pt`, `32pt`, `64pt` 요청 모두 provider가 처리 가능해졌다.

즉, 이번 문제는 "특정 파일이 렌더되지 않는다"가 아니라 "작은 요청 크기에서는 extension이 아예 호출되지 않는다"가 본질이었다.

## 검증

### 정적 검증

- `git diff --check -- Sources/ThumbnailExtension/Info.plist`
- `xcodegen generate`

### 빌드 검증

- `xcodebuild -project RhwpMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build`
- `xcodebuild -project RhwpMac.xcodeproj -scheme HostApp -configuration Release -derivedDataPath build/DerivedDataReleaseSigned CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=YES build`

### 설치/등록 검증

- `pluginkit -a /Users/melee/Applications/RhwpMac.app`
- `pluginkit -mAvvv -D -i com.postmelee.rhwpmac.ThumbnailExtension`
  - 활성 경로:
    - `/Users/melee/Applications/RhwpMac.app/Contents/PlugIns/RhwpMacThumbnail.appex`
- 설치본 `Info.plist` 확인:
  - `QLThumbnailMinimumDimension` 키가 더 이상 존재하지 않음

### small-size thumbnail 검증

- `qlmanage -r`
- `qlmanage -r cache`
- `qlmanage -t -x -s 16 -o /tmp /Users/melee/Downloads/교양및전공이수에관한규정 [별표 1] 교양 및 최소 전공교과목 이수 현황(2025.02.06. 개정) (2).hwp`
  - 결과: `produced one thumbnail`
- `qlmanage -t -x -s 16 -o /tmp /Users/melee/Downloads/(붙임) 2021년 예비창업패키지 일반·특화분야 연계지원 안내문(최종).hwp`
  - 결과: `produced one thumbnail`
- `qlmanage -t -x -s 16 -o /tmp /Users/melee/Downloads/(양식)진행요원 근무일지_소프트 졸업작품 전시회.hwp`
  - 결과: `produced one thumbnail`
- `qlmanage -t -x -s 32 -o /tmp /Users/melee/Downloads/(양식)진행요원 근무일지_소프트 졸업작품 전시회.hwp`
  - 결과: `produced one thumbnail`
- `qlmanage -t -x -s 64 -o /tmp /Users/melee/Downloads/(양식)진행요원 근무일지_소프트 졸업작품 전시회.hwp`
  - 결과: `produced one thumbnail`

## 판단

- 우리 thumbnail extension은 이제 extension 설정 차원에서 모든 작은 요청 크기를 받을 수 있다.
- 사용자 제보 파일 3개 모두 `16pt` 요청에서 썸네일 생성이 확인됐다.
- 따라서 이번 수정으로 "특정 크기 이상에서만 보이던" 현상은 앱 설정 기준으로 해소됐다.

남는 주의점은 있다.

- Finder의 아주 일부 표시 모드나 운영체제 정책상 일반 아이콘이 선택되는 경우는 앱이 완전히 강제할 수 없다.
- 다만 이번 단계에서 제거한 `64pt` 하한은 더 이상 우리 쪽 제한이 아니다.

## 다음 단계

- 5단계에서 아키텍처/배포 문서에 다음 내용을 반영한다.
  - Thumbnail extension 최소 크기 정책 제거 이유
  - 설치본과 build 산출물 중복 discovery 방지 규칙
  - small-size thumbnail 검증 절차

## 승인 요청 사항

- 이 단계 완료 기준으로 5단계(문서와 provenance 정리) 진행 승인 요청
