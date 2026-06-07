# Task #323 구현 계획서

본 문서는 [`task_m040_323.md`](task_m040_323.md) 수행계획서를 단계별 실행 단위로 분해한 것이다. 각 단계 완료 후 [`task-stage-report`](../skills/task-stage-report/SKILL.md) skill로 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 환경

- Worktree: `/Users/melee/Documents/projects/rhwp-mac`
- Branch: `local/task323`
- 기준 브랜치: `devel`
- 기준 이슈: [#323](https://github.com/postmelee/alhangeul-macos/issues/323)
- 마일스톤: M040 (`v0.4`)
- 범위: HostApp 실행 시 Sparkle 백그라운드 업데이트 확인 1회 요청

## 구현 원칙

- 업데이트 경로는 기존 Sparkle 단일 경로를 유지한다.
- 앱 실행 시 호출은 사용자 주도 확인 UI용 `checkForUpdates(nil)`이 아니라, 최신 상태에서 조용히 끝나는 `checkForUpdatesInBackground()`를 사용한다.
- 사용자가 Sparkle 자동 확인을 꺼 둔 경우에는 실행 시 백그라운드 확인을 강제하지 않는다.
- `SUAutomaticallyUpdate` 기본값은 유지한다. 자동 설치 또는 자동 다운로드 정책은 변경하지 않는다.
- `알한글 > 업데이트 확인...` 수동 메뉴는 기존처럼 즉시 사용자 주도 확인을 수행해야 한다.
- public appcast 생성, Pages 배포, release workflow 실행은 이번 task 범위가 아니다.

## Stage 1 — 실행 시 백그라운드 확인 호출 구현

### 목표

- `UpdateController` 초기화 중 Sparkle updater 시작 직후 백그라운드 업데이트 확인을 1회 요청한다.
- 자동 확인이 비활성화된 사용자 설정을 존중한다.
- 기존 수동 업데이트 확인 메뉴 동작을 유지한다.

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `Sources/HostApp/Services/UpdateController.swift` | `SPUStandardUpdaterController` 생성 후 `automaticallyChecksForUpdates` guard와 `checkForUpdatesInBackground()` 호출 추가 | 핵심 코드 변경 |
| `mydocs/working/task_m040_323_stage1.md` | Stage 1 완료보고서 작성 | 코드 변경, 검증 결과, 잔여 수동 확인 기록 |

### 구현 기준

1. `SPUStandardUpdaterController(startingUpdater: true, ...)` 생성은 유지한다.
2. `updaterController.updater.automaticallyChecksForUpdates`가 `true`일 때만 `updaterController.updater.checkForUpdatesInBackground()`를 호출한다.
3. 호출은 `UpdateController.init()`에서 updater controller 생성 이후 한 번만 수행한다.
4. `checkForUpdates()` 메서드는 기존처럼 `updaterController.checkForUpdates(nil)`을 호출한다.
5. Sparkle delegate 추가나 사용자 정의 UI는 도입하지 않는다.

### 단계 검증

```bash
git diff --check
plutil -lint Sources/HostApp/Info.plist
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
```

### 단계 완료 기준

- `UpdateController`가 실행 시 백그라운드 확인을 요청한다.
- 자동 확인 비활성화 시 강제 확인을 요청하지 않는 guard가 코드에 있다.
- 수동 메뉴의 `checkForUpdates(nil)` 경로가 변경되지 않았다.
- HostApp Debug build가 통과한다.

### 커밋 메시지

```text
Task #323 Stage 1: Sparkle 실행 시 백그라운드 확인 호출
```

## Stage 2 — Sparkle 실행 시 확인 정책 문서화

### 목표

- 실행 시 백그라운드 확인 정책과 수동 확인 경로의 차이를 운영 문서에 남긴다.
- 향후 release smoke에서 무엇을 자동으로 확인할 수 있고 무엇을 수동 확인으로 남겨야 하는지 구분한다.

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `mydocs/manual/release_github_pages_sparkle_guide.md` | 필요 시 Sparkle appcast 또는 업데이트 확인 섹션에 실행 시 background check 정책 추가 | 문서 보강 |
| `mydocs/working/task_m040_323_stage2.md` | Stage 2 완료보고서 작성 | 문서 변경과 검증 기준 기록 |

### 반영 기준

1. 앱의 stable feed가 `https://postmelee.github.io/alhangeul-macos/appcast.xml`인 점은 유지한다.
2. 앱 실행 시에는 자동 확인 설정이 켜진 경우에만 background check를 요청한다고 적는다.
3. 수동 메뉴는 사용자가 직접 요청한 확인으로, 최신 상태 안내 UI가 나올 수 있다고 구분한다.
4. 자동 설치는 켜지지 않으며 설치 여부는 사용자가 Sparkle 표준 UI에서 선택한다고 유지한다.
5. public release, Pages deployment, appcast 생성 승인 gate는 변경하지 않는다.

### 단계 검증

```bash
git diff --check
rg -n "checkForUpdatesInBackground|백그라운드|업데이트 확인|appcast.xml|SUAutomaticallyUpdate" mydocs/manual/release_github_pages_sparkle_guide.md
```

### 단계 완료 기준

- 실행 시 background check와 수동 메뉴 확인의 차이가 문서에 남아 있다.
- 자동 설치 정책과 release/appcast 승인 gate가 기존 정책과 충돌하지 않는다.

### 커밋 메시지

```text
Task #323 Stage 2: Sparkle 실행 시 확인 정책 문서화
```

## Stage 3 — 통합 검증과 최종 보고

### 목표

- 코드와 문서 변경을 한 번 더 통합 검증한다.
- 자동화로 검증 가능한 항목과 실제 설치본/foreground 세션에서만 확인 가능한 항목을 분리해 최종 보고한다.

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `Sources/HostApp/Services/UpdateController.swift` | 필요 시 Stage 1 피드백 반영 | 최종 보정 |
| `mydocs/manual/release_github_pages_sparkle_guide.md` | 필요 시 Stage 2 피드백 반영 | 최종 보정 |
| `mydocs/report/task_m040_323_report.md` | 최종 결과보고서 작성 | 모든 단계 완료 후 |
| `mydocs/orders/20260601.md` | 작업 상태 완료 처리 | 최종 보고 단계 |

### 최종 검증

```bash
git status --short --branch
git diff --check
plutil -lint Sources/HostApp/Info.plist
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
rg -n "checkForUpdatesInBackground|automaticallyChecksForUpdates|checkForUpdates\\(" Sources/HostApp/Services/UpdateController.swift
rg -n "백그라운드|업데이트 확인|appcast.xml|SUAutomaticallyUpdate" mydocs/manual/release_github_pages_sparkle_guide.md
```

### 수동 확인 후보

- public appcast가 최신 release item을 제공하는 이전 설치본에서 앱 실행 시 새 버전 안내가 표시되는지 확인
- 최신 버전 설치본에서 실행 시 불필요한 "최신 버전입니다" 모달이 표시되지 않는지 확인
- `알한글 > 업데이트 확인...` 메뉴를 눌렀을 때 기존 수동 확인 UI가 표시되는지 확인
- Sparkle 자동 확인 설정을 끈 상태에서 앱 실행 시 background check를 강제하지 않는지 확인

### 커밋 메시지

```text
Task #323 Stage 3 + 최종 보고서: Sparkle 실행 시 확인 보강 완료
```

## 승인 요청 사항

이 구현 계획 기준으로 Stage 1 진행 승인을 요청한다. 승인 전에는 `UpdateController` 코드 변경을 시작하지 않는다.
