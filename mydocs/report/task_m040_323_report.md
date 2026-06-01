# Task M040 #323 최종 결과보고서

## 작업 요약

| 항목 | 값 |
|------|----|
| GitHub Issue | [#323](https://github.com/postmelee/alhangeul-macos/issues/323) |
| 마일스톤 | M040 (`v0.4`) |
| 작업 브랜치 | `local/task323` |
| 기준 브랜치 | `devel` |
| 단계 수 | 3단계 |
| 목적 | HostApp 실행 시 Sparkle 백그라운드 업데이트 확인을 1회 요청하고, 수동 확인 경로와 정책 차이를 문서화 |

HostApp이 실행될 때 Sparkle updater 시작 직후 `checkForUpdatesInBackground()`를 요청하도록 보강했다. 사용자가 Sparkle 자동 확인을 끈 경우에는 실행 시 확인을 강제하지 않으며, 앱 메뉴의 수동 `업데이트 확인...`은 기존 `checkForUpdates(nil)` 경로로 유지했다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `Sources/HostApp/Services/UpdateController.swift` | `SPUStandardUpdaterController` 생성 직후 `requestLaunchUpdateCheckIfAllowed()`를 호출한다. `automaticallyChecksForUpdates`가 켜진 경우에만 `checkForUpdatesInBackground()`를 1회 요청한다. |
| `mydocs/manual/release_github_pages_sparkle_guide.md` | Sparkle stable feed 아래에 `앱 업데이트 확인 동작` 섹션을 추가해 실행 시 백그라운드 확인, 수동 메뉴 확인, 자동 설치 비활성 정책을 문서화했다. |
| `mydocs/plans/task_m040_323.md` | 수행계획서. 범위, 제외 항목, 설계 방향, 검증 계획을 기록했다. |
| `mydocs/plans/task_m040_323_impl.md` | 구현계획서. Stage 1~3의 변경 파일, 검증 명령, 완료 기준을 기록했다. |
| `mydocs/working/task_m040_323_stage1.md` | Stage 1 코드 변경과 HostApp build 검증 결과를 기록했다. |
| `mydocs/working/task_m040_323_stage2.md` | Stage 2 문서 변경과 Sparkle 가이드 검색 검증 결과를 기록했다. |
| `mydocs/orders/20260601.md` | #323 작업을 등록하고 완료 처리했다. |
| `mydocs/report/task_m040_323_report.md` | 최종 결과보고서. |

## 변경 전·후 정량 비교

| 항목 | 결과 |
|------|------|
| 코드 변경 | `UpdateController.swift` 9 lines 추가, 기존 수동 `checkForUpdates(nil)` 유지 |
| 운영 문서 변경 | Sparkle guide 8 lines 추가, 기존 release/appcast 승인 gate 삭제 없음 |
| 계획/보고 문서 | 수행계획 95 lines, 구현계획 149 lines, Stage 1 보고 91 lines, Stage 2 보고 71 lines |
| 전체 task diff | 7 files changed, 430 insertions before final report commit |
| 최종 검증 | whitespace, plist lint, HostApp Debug build, 코드/문서 검색 검증 통과 |

## 단계별 결과

| 단계 | 결과 |
|------|------|
| Stage 1 | `UpdateController` 초기화 중 자동 확인 설정을 존중하며 Sparkle 백그라운드 업데이트 확인을 1회 요청하도록 구현 |
| Stage 2 | 실행 시 background check와 앱 메뉴 수동 확인 경로의 차이, 자동 설치 비활성 정책을 Sparkle 운영 문서에 기록 |
| Stage 3 | 통합 검증을 수행하고 최종 결과보고서와 오늘할일 완료 처리를 반영 |

## 검증 결과

| 검증 항목 | 결과 | 비고 |
|-----------|------|------|
| `git status --short --branch` | OK | Stage 3 시작 시 `local/task323` clean 확인 |
| `git diff --check` | OK | whitespace 오류 없음 |
| `plutil -lint Sources/HostApp/Info.plist` | OK | `Sources/HostApp/Info.plist: OK` |
| `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build` | OK | sandbox 내부 첫 실행은 Swift/Xcode 캐시 접근 제한으로 실패. 같은 명령을 캐시 접근 허용 상태로 재실행해 `** BUILD SUCCEEDED ** [0.477 sec]` 확인 |
| `rg -n "checkForUpdatesInBackground\|automaticallyChecksForUpdates\|checkForUpdates\\(" Sources/HostApp/Services/UpdateController.swift` | OK | 수동 `checkForUpdates(nil)`, 자동 확인 guard, background check 호출 확인 |
| `rg -n "백그라운드\|업데이트 확인\|appcast.xml\|SUAutomaticallyUpdate" mydocs/manual/release_github_pages_sparkle_guide.md` | OK | stable appcast URL, 실행 시 확인 정책, 수동 메뉴, 자동 설치 비활성 정책 확인 |

## 실행하지 않은 항목

이번 task는 코드 경로와 운영 문서 정합성 보강이 범위이므로 다음은 실행하지 않았다.

- public appcast 생성 또는 Pages deployment
- GitHub Release 게시 또는 release workflow dispatch
- Sparkle update archive signing
- 이전 public 설치본에서 새 버전 안내 UI 확인
- 최신 설치본 foreground 세션에서 모달 미표시 확인
- Sparkle 자동 확인 사용자 설정을 끈 상태의 설치본 smoke

## 잔여 위험과 후속 작업

- Sparkle 실제 안내 UI는 public appcast, 설치본 버전, 사용자 defaults, 앱 foreground 상태에 영향을 받는다. 새 public release 준비 시 설치본 smoke에서 새 버전 안내와 최신 상태 무알림을 다시 확인해야 한다.
- 실행 시 background check는 `automaticallyChecksForUpdates`가 켜진 경우에만 요청한다. 사용자가 자동 확인을 꺼 둔 상태의 동작은 향후 release smoke 후보로 남긴다.
- 이번 변경은 자동 설치나 자동 다운로드 정책을 바꾸지 않는다. `SUAutomaticallyUpdate=false` 정책은 유지된다.

## 커밋 목록

```text
71d6be8 Task #323: 수행 계획서 작성과 오늘할일 갱신
0bf29ed Task #323: 구현 계획서 작성
6918b26 Task #323 Stage 1: Sparkle 실행 시 백그라운드 확인 호출
fca9c38 Task #323 Stage 2: Sparkle 실행 시 확인 정책 문서화
```

Stage 3 최종 보고 커밋은 본 보고서와 오늘할일 완료 처리와 함께 생성한다.

## 작업지시자 승인 요청

최종 결과보고서 기준으로 PR 게시 단계 진행 승인을 요청한다. 승인 후 `publish/task323` 원격 브랜치로 push하고 `devel` 대상 PR을 생성한다.
