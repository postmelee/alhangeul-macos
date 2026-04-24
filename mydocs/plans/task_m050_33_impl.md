# Issue #33 구현 계획서

## 타스크

- GitHub Issue: #33
- 마일스톤: M050
- 제목: Quick Look thumbnail smoke test 실패 원인 분석
- 선행 작업: Issue #26, #27, #37 merge 반영

## 구현 원칙

- #33은 #27 smoke test 실패의 후속 원인 분석이다.
- 실제 조사는 `devel` 최신 기준(`22aa57f`, PR #38까지 반영)에서 진행한다.
- 원인 확인 전에는 code path를 넓게 수정하지 않는다.
- `Vendor/rhwp` core 수정은 이번 단계의 기본 범위에서 제외한다.
- 사용자 표시명은 `알한글`로 유지한다.
- repository/build/distribution-facing ASCII 이름은 추가 Stage에서 `AlhangeulMac`/`alhangeul-macos` 계열로 정리한다.
- 테스트용 파일은 `/Users/melee/Documents/projects/rhwp-mac/samples` 아래 파일만 사용한다.

## Stage 1. 기준 상태 동기화와 재현 조건 고정

### 목표

- #27 변경 기준에서 #33 조사를 시작할 수 있게 branch/worktree 기준을 맞춘다.
- smoke test 재현 조건을 고정한다.

### 작업

- `local/task33`에 #27 변경 반영 방식을 결정한다.
  - #26/#27/#37 merge가 반영된 `devel` 기준으로 재동기화한다.
- `/Users/melee/Applications/알한글.app` 단일 설치 상태를 확인한다.
- `/Users/melee/Applications/AlhangeulMac.app.stage27-smoke-disabled` 처리 상태를 확인한다.
- `project.yml`, HostApp/QLExtension/ThumbnailExtension Info.plist, package 산출물 Info.plist를 대조한다.
- `/Users/melee/Documents/projects/rhwp-mac/samples/basic/KTX.hwp`와 대표 샘플 2개 이상으로 `qlmanage -t` 실패를 재현한다.

### 완료 기준

- 조사 기준 commit과 설치본 경로가 문서에 기록된다.
- `qlmanage -t` 실패가 같은 조건에서 재현된다.

## Stage 2. LaunchServices, PlugInKit, Quick Look discovery 분리

### 목표

- 등록 계층과 Quick Look discovery 계층 중 어느 지점에서 끊기는지 확인한다.

### 작업

- LaunchServices 등록 경로를 확인한다.
- PlugInKit 등록 항목, enable 상태, 중복 UUID 상태를 확인한다.
- `qlmanage -m plugins`에 extension이 노출되지 않는 조건을 확인한다.
- unified log에서 extension discovery 관련 메시지를 수집한다.
- 필요한 경우 수동 등록/해제 절차를 최소 범위로 반복해 차이를 비교한다.

### 완료 기준

- LaunchServices/PlugInKit/Quick Look discovery 중 실패 지점 후보가 좁혀진다.
- 중복 등록이 원인인지, discovery 미반영이 원인인지 판단 근거가 남는다.

## Stage 3. Thumbnail provider 실행 여부 확인과 최소 수정

### 목표

- `HwpThumbnailProvider`가 실제로 로드/실행되는지 확인한다.
- 설정 또는 코드 문제가 확인되면 최소 수정한다.

### 작업

- Thumbnail extension principal class/module 이름을 생성 산출물 기준으로 확인한다.
- provider 진입 여부 확인을 위한 최소 logging 또는 signpost를 검토한다.
- sandbox, signing, extension crash, module load 실패 로그를 확인한다.
- 원인이 설정이면 Info.plist 또는 `project.yml`을 최소 수정한다.
- 원인이 provider 실행 이후라면 해당 code path만 좁게 수정한다.

### 완료 기준

- provider 미실행/실행 후 실패 여부가 구분된다.
- 수정이 필요한 경우 변경 범위와 근거가 명확히 남는다.

## Stage 4. `AlhangeulMac` 이름 정합화

### 목표

- 사용자 표시명 `알한글`은 유지한다.
- `RhwpMac`/`rhwpmac`으로 남아 있던 Xcode project, product, executable, bundle identifier, UTI, package, Cask 이름을 `alhangeul-macos` 저장소명과 맞는 ASCII 계열로 정리한다.

### 작업

- `project.yml`의 project/product/executable 이름을 `AlhangeulMac` 계열로 변경한다.
- HostApp/QLExtension/ThumbnailExtension bundle identifier와 app-owned UTI를 `com.postmelee.alhangeulmac` 계열로 변경한다.
- package zip, Homebrew Cask token/file, 문서의 배포 산출물 이름을 `alhangeul-macos`/`AlhangeulMac.app` 기준으로 변경한다.
- `xcodegen generate`로 Xcode project 생성물을 갱신한다.
- 새 식별자 기준으로 build/package/Finder thumbnail smoke test를 재수행한다.

### 완료 기준

- build 산출물과 package zip 내부 app bundle이 `AlhangeulMac.app`로 생성된다.
- package 파일명이 `alhangeul-macos-<version>.zip`으로 생성된다.
- 사용자 표시명은 `알한글` 계열로 유지된다.
- `/Users/melee/Documents/projects/rhwp-mac/samples` 샘플 기준 thumbnail smoke test가 성공한다.

## Stage 5. 검증과 보고서

### 목표

- 수정 또는 원인 분석 결과를 검증하고 보고서를 작성한다.

### 작업

- `xcodegen generate`
- `plutil -lint Sources/QLExtension/Info.plist Sources/ThumbnailExtension/Info.plist`
- 필요한 경우 Debug build 수행
- 필요한 경우 release package 수행
- 설치본 smoke test 재수행
  - `pluginkit -mAvvv`
  - `mdls -name kMDItemContentType /Users/melee/Documents/projects/rhwp-mac/samples/basic/KTX.hwp`
  - `qlmanage -r`
  - `qlmanage -r cache`
  - `qlmanage -m plugins`
  - `qlmanage -t -x -s 512 -o /tmp /Users/melee/Documents/projects/rhwp-mac/samples/basic/KTX.hwp`
- 단계 완료 보고서와 최종 보고서 작성

### 완료 기준

- Finder thumbnail 생성 성공 또는 실패 원인의 다음 조치가 명확히 정리된다.
- 검증 결과와 남은 리스크가 최종 보고서에 기록된다.

## 승인 요청 사항

- 이 구현 계획 기준으로 Stage 1 진행 승인 요청
