# Task #154 Stage 4 완료 보고서: 문서와 smoke 기준 갱신

## 단계 목적

운영 문서와 공개 안내 문서에 남아 있던 `AlhangeulMac` 계열 build/run/release/smoke 기준을 `Alhangeul` 기준으로 갱신했다. GitHub 저장소명, Homebrew Cask token, public DMG/zip 파일명인 `alhangeul-macos`는 유지했다.

## 변경 파일

### 공개 안내와 기여 문서

- `README.md`
  - build command를 `Alhangeul.xcodeproj` 기준으로 변경
  - Debug app 실행 경로를 `Alhangeul.app`으로 변경
  - Finder/Quick Look 등록 확인 grep을 `com.postmelee.alhangeul` 기준으로 변경
- `CONTRIBUTING.md`
  - 초기 build/run 명령과 공통 체크 명령을 새 project/app 경로로 변경
  - Quick Look/Thumbnail 등록 문제 첨부 명령을 `com.postmelee.alhangeul` 기준으로 변경
- `AGENTS.md`
  - `project.yml` 원본 규칙의 generated project 이름을 `Alhangeul.xcodeproj`로 변경
- `.github/copilot-instructions.md`
  - reviewer 기준의 generated project 이름을 `Alhangeul.xcodeproj`로 변경

`CONTRIBUTING.md`와 `AGENTS.md`는 Stage 4 구현 중 추가 전역 검색에서 현재 작업자/기여자 안내로 쓰이는 old 기준이 확인되어 함께 갱신했다.

### build/run/manual 문서

- `mydocs/manual/build_run_guide.md`
  - Xcode project 생성/빌드 명령을 `Alhangeul.xcodeproj` 기준으로 변경
  - Debug/Release app 경로를 `Alhangeul.app`으로 변경
  - HostApp smoke process name을 `Alhangeul`로 변경
  - 표준 설치 경로를 `$HOME/Applications/Alhangeul.app`으로 변경
  - PlugInKit grep을 `com.postmelee.alhangeul` 기준으로 변경
  - 표시명 기준을 한국어 `알한글`, 영어 `Alhangeul`, 기본 bundle name `Alhangeul`로 변경
- `mydocs/manual/core_dependency_operation_guide.md`
  - core 업데이트 검증용 `xcodebuild` 명령을 `Alhangeul.xcodeproj` 기준으로 변경

### release/architecture/compatibility 문서

- `mydocs/manual/release_distribution_guide.md`
  - package/release 산출물 경로를 `Alhangeul.app`으로 변경
  - 확정 identity 기준을 `Alhangeul`, `com.postmelee.alhangeul` 계열로 변경
  - signing/stapler/spctl 검증 명령을 `Alhangeul.app`으로 변경
  - Cask 확인 항목을 `app "Alhangeul.app"`으로 변경
- `mydocs/tech/project_architecture.md`
  - generated project와 product/bundle naming 정책을 `Alhangeul` 기준으로 변경
  - 사용자 표시명 정책을 한국어 `알한글`, 영어 `Alhangeul` 기준으로 변경
- `mydocs/tech/core_release_compatibility.md`
  - release package 설치/등록 기록의 app 경로를 `Alhangeul.app`으로 변경

## 유지한 값

다음 값은 제품 identity가 아니라 저장소/배포 채널명이라 유지했다.

- GitHub 저장소: `postmelee/alhangeul-macos`
- Homebrew Cask token: `alhangeul-macos`
- public DMG/zip 파일명: `alhangeul-macos-<version>.dmg`, `alhangeul-macos-<version>.zip`
- 임시 Quick Look output directory 예시: `/tmp/alhangeul-ql`

## 검증 결과

실행한 명령:

```bash
rg --line-number 'AlhangeulMac|alhangeulmac|AlhangeulMacHost|AlhangeulMacPreview|AlhangeulMacThumbnail|com\.postmelee\.alhangeulmac' \
  AGENTS.md CONTRIBUTING.md README.md .github mydocs/manual mydocs/tech
rg --line-number 'Alhangeul\.xcodeproj|Alhangeul\.app|com\.postmelee\.alhangeul|pgrep -x Alhangeul|pluginkit.*com\.postmelee\.alhangeul' \
  AGENTS.md CONTRIBUTING.md README.md .github mydocs/manual mydocs/tech
bash -n scripts/package-release.sh scripts/release.sh
git diff --check
```

결과:

- 현재 운영/안내 문서 범위에서 old identity 문자열 없음
- 새 project/app/bundle id/smoke 명령 기준 확인
- release/package script 문법 검사 통과
- `git diff --check` 통과

## 범위 메모

과거 task 계획서와 단계 보고서에는 당시 검증 명령과 산출물명이 기록되어 있어 `AlhangeulMac` 계열 문자열이 남아 있다. 이 문서들은 실행 당시의 근거 기록이므로 Stage 4의 운영 기준 갱신 대상에서 제외했다. 현재 기준으로 참조되는 root 안내, contributor 안내, README, `.github`, `mydocs/manual`, `mydocs/tech` 문서에서는 old identity를 제거했다.

## 다음 단계 영향

Stage 5에서는 최종 검증과 최종 보고서를 정리한다. 가능하면 release rehearsal (`./scripts/release.sh --skip-notarize 0.1.0`)까지 수행해 `Alhangeul.app` DMG layout과 checksum 생성을 확인한다.

## 승인 요청

Stage 4를 완료했다. 이 보고서 기준으로 Stage 5 `최종 검증과 보고서 정리`를 진행할지 승인 요청한다.
