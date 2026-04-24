# Issue #40 구현 계획서

## 타스크

- GitHub Issue: #40
- 마일스톤: M050
- 제목: Dock/Spotlight 표시명 한영 현지화
- 작업 브랜치: `local/task40`

## 구현 원칙

- 실제 app bundle filesystem path는 `AlhangeulMac.app`으로 유지한다.
- 사용자 표시명은 localized `InfoPlist.strings`로 제공한다.
- target별 표시명은 각 target bundle 안에 포함한다.
- `project.yml`을 원본으로 수정하고 `AlhangeulMac.xcodeproj`는 XcodeGen으로 재생성한다.
- `Sources/RhwpCoreBridge`에는 변경을 넣지 않는다.

## Stage 1. 현지화 리소스 구조 추가

### 작업

- HostApp에 `ko.lproj`와 `en.lproj`의 `InfoPlist.strings`를 추가한다.
- QLExtension에 `ko.lproj`와 `en.lproj`의 `InfoPlist.strings`를 추가한다.
- ThumbnailExtension에 `ko.lproj`와 `en.lproj`의 `InfoPlist.strings`를 추가한다.
- 각 파일에는 `CFBundleDisplayName`, `CFBundleName`만 최소로 둔다.

### 예상 표시명

| Target | ko | en |
|--------|----|----|
| HostApp | 알한글 | AlhangeulMac |
| QLExtension | 알한글 미리보기 | AlhangeulMac Preview |
| ThumbnailExtension | 알한글 썸네일 | AlhangeulMac Thumbnail |

### 완료 조건

- 추가한 `InfoPlist.strings`가 `plutil -lint`를 통과한다.
- target별 표시명이 수행 계획의 목표와 일치한다.

## Stage 2. XcodeGen 리소스 포함 및 프로젝트 재생성

### 작업

- 필요하면 `project.yml`의 target source/resource 포함 경로를 보정한다.
- `xcodegen generate`로 `AlhangeulMac.xcodeproj`를 재생성한다.
- 생성된 project가 각 target의 localized resources를 포함하는지 확인한다.

### 완료 조건

- `xcodegen generate` 성공
- `git diff`에서 의도한 리소스와 XcodeGen 산출물 변경만 확인

## Stage 3. 빌드 산출물과 등록 상태 검증

### 작업

- Debug build를 수행한다.
- build 산출물의 HostApp과 extension bundle 안에 `ko.lproj`, `en.lproj` 리소스가 포함됐는지 확인한다.
- `/Users/melee/Applications/AlhangeulMac.app`에 설치해 LaunchServices/PlugInKit 등록을 확인한다.
- 가능한 CLI 범위에서 localized display name을 확인하고, Dock/Finder/Spotlight 즉시 반영 여부는 캐시 조건을 분리해 기록한다.

### 완료 조건

- Debug build 성공
- HostApp/QLExtension/ThumbnailExtension bundle에 localized `InfoPlist.strings` 포함
- PlugInKit 등록이 `com.postmelee.alhangeulmac.*` 계열로 유지됨
- 이전 `RhwpMac.app`, `알한글.app` filesystem path를 다시 만들지 않음

## Stage 4. 문서와 최종 보고

### 작업

- README 또는 운영 문서에서 표시명과 filesystem bundle name의 차이를 필요한 만큼 보완한다.
- 단계 보고서와 최종 보고서를 작성한다.
- 오늘할일 상태를 갱신한다.

### 완료 조건

- 관련 문서가 현재 정책을 설명한다.
- 최종 보고서에 검증 결과와 캐시 관련 한계를 기록한다.
- PR 생성 전 미커밋 변경이 없다.

## 승인 요청

위 4개 Stage 기준으로 Stage 1 구현 진행 승인을 요청한다.
