# Issue #27 단계 3 완료 보고서

## 작업 내용

- README와 manual의 앱 경로 설명을 현재 build 설정에 맞췄다.
- Finder 통합 검증 절차를 단일 설치본 기준으로 보정했다.
- 아키텍처 문서에 사용자 표시명과 내부 식별자 경계를 짧게 반영했다.

## 변경 내용

### 1. README

- 개발 build 산출물 경로를 `RhwpMac.app` 기준으로 수정했다.
- 실행 예시도 내부 산출물 경로에 맞췄다.

### 2. build/run guide

- 앱 실행 확인은 `build/DerivedData/.../RhwpMac.app` 기준으로 수정했다.
- Finder 통합 확인은 `~/Applications/알한글.app` 단일 설치본을 만든 뒤 `pluginkit -a`로 등록하는 절차로 정리했다.
- build 산출물 제외는 중복 discovery가 확인된 경우에만 쓰는 절차로 분리했다.

### 3. release guide

- `scripts/package-release.sh`가 내부 산출물 `RhwpMac.app`을 빌드한 뒤 `알한글.app`으로 zip을 만든다고 수정했다.
- Finder 통합 smoke test를 `~/Applications/알한글.app` 단일 설치본 기준으로 수정했다.
- Homebrew Cask URL이 이미 현재 저장소 기준으로 바뀌었으므로 과거 URL 주의 문구를 제거했다.

### 4. architecture

- 사용자 표시명/배포 앱 번들명은 `알한글` 기준이고, 내부 Xcode product/executable/module 이름은 `RhwpMac` 계열을 유지한다고 명시했다.

## 검증

- `rg -n "build/DerivedData/Build/Products/(Debug|Release)/알한글\\.app|open build/DerivedData/Build/Products/Debug/알한글\\.app|postmelee/rhwp-mac|알한글 Preview|알한글 Thumbnail" README.md mydocs/manual mydocs/tech Casks Sources scripts`
  - 결과: 매칭 없음
- `git diff --check -- README.md mydocs/tech/project_architecture.md mydocs/manual/build_run_guide.md mydocs/manual/release_distribution_guide.md`

## 다음 단계

- 4단계에서 앱 build, 패키징 산출물, 전체 diff 형식을 검증하고 최종 보고 준비를 진행한다.

## 승인 요청 사항

- 이 단계 완료 기준으로 4단계 진행 승인 요청
