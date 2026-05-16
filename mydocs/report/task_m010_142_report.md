# Task M010 #142 최종 보고서

## 작업 요약

- 이슈: [#142 WKWebView 저장 단축키와 macOS shortcut 표기 보정](https://github.com/postmelee/alhangeul-macos/issues/142)
- 마일스톤: M010 / v0.1.0 Viewer 기반
- 대상 브랜치: `devel-webview`
- 작업 브랜치: `local/task142`
- 단계 수: 수행 계획 + Stage 1-4 + 최종 보고

HostApp WKWebView viewer에서 `Command+S`가 macOS 관례대로 현재 파일에 바로 저장되도록 수정했다. 기존 save panel 기반 저장은 `Command+Shift+S`의 `다른 이름으로 저장...`로 분리했다. WKWebView 내부 메뉴와 toolbar tooltip의 shortcut 표기도 `Ctrl`/`Alt`에서 `Command`/`Option` 기준으로 보정했다. Stage 4에서는 작업지시자 추가 요청에 따라 저장 성공 후 하단 status bar에 `저장 완료 HH:mm`을 3초 표시하는 최소 UX 피드백을 추가했다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `Sources/HostApp/HostApp.swift` | native 저장 메뉴에 `다른 이름으로 저장...` / `Command+Shift+S` 추가 |
| `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift` | `file:save-as` bridge, shortcut routing, macOS shortcut label 보정, 저장 완료 status 표시 추가 |
| `Sources/HostApp/Stores/DocumentViewerStore.swift` | save-as 이후 현재 source document와 recent document 갱신 method 추가 |
| `Sources/HostApp/Views/DocumentViewerView.swift` | `sourceDocument`와 저장 완료 callback을 WKWebView wrapper로 전달 |
| `Sources/HostApp/Views/RhwpStudioWebView.swift` | 즉시 저장/save-as 분리, security-scoped source URL write, fallback, 저장 완료 status 호출 추가 |
| `mydocs/orders/20260504.md` | #142 진행 상태와 완료 시각 갱신 |
| `mydocs/plans/task_m010_142.md` | 수행 계획서 |
| `mydocs/plans/task_m010_142_impl.md` | 구현 계획서 |
| `mydocs/working/task_m010_142_stage1.md` | 저장 command 흐름 조사 보고 |
| `mydocs/working/task_m010_142_stage2.md` | 저장 단축키 분리 구현 보고 |
| `mydocs/working/task_m010_142_stage3.md` | WebView 메뉴/shortcut smoke 보정 보고 |
| `mydocs/working/task_m010_142_stage4.md` | 저장 완료 status UX 보고 |
| `mydocs/report/task_m010_142_report.md` | 최종 보고서 |

## 변경 전·후 정량 비교

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| 저장 단축키 | `Command+S`가 항상 save panel 흐름 | `Command+S`는 즉시 저장, `Command+Shift+S`는 save panel |
| source document 갱신 | save panel 저장 후 이후 즉시 저장 대상 없음 | save-as 성공 URL을 source document/recent document로 기록 |
| WebView shortcut 표기 | `Ctrl+`, `Alt+` 중심 | `Command+`, `Option+` 표시 보정 |
| 저장 성공 피드백 | 성공 여부를 UI로 알 수 없음 | 하단 status에 `저장 완료 HH:mm` 3초 표시 |
| 구현 커밋 | 없음 | 5개 커밋 |
| 구현 diff stat | 없음 | 최종 보고서 작성 전 기준 12 files, 1056 insertions, 29 deletions |

## 단계별 결과

| 단계 | 커밋 | 결과 |
|------|------|------|
| 수행 계획 | `3cac17a` | 이슈 #142 수행 계획서, 구현 계획서, 오늘할일 등록 |
| Stage 1 | `9e66ebe` | 기존 저장 command, source document ownership, shortcut label 위치 조사 |
| Stage 2 | `4718b8e` | `file:save` / `file:save-as` 분리와 즉시 저장 구현 |
| Stage 3 | `7b52d68` | WebView 메뉴 save-as 표시/클릭 보정과 shortcut smoke 검증 |
| Stage 4 | `9a06fa5` | 저장 성공 status 표시 UX 추가와 수동 smoke 검증 |

## 검증 결과

| 수용 기준 | 결과 | 근거 |
|-----------|------|------|
| Debug HostApp build 성공 | OK | `xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/task142-final/DerivedData CODE_SIGNING_ALLOWED=NO build` → `** BUILD SUCCEEDED ** [14.462 sec]` |
| `Command+S`와 `Command+Shift+S` command routing 분리 | OK | Stage 2 코드 검색 및 Stage 3/4 앱 smoke |
| source document가 있는 HWP에서 save panel 없이 즉시 저장 | OK | `/private/tmp/task142-save-smoke-stage4.hwp`가 `643072` → `561664` bytes로 갱신 |
| 원본 샘플 파일 미변경 | OK | `samples/20250130-hongbo.hwp`는 `1777080928 643072` 유지 |
| `Command+Shift+S`가 save panel 실행 | OK | Stage 3 앱 smoke에서 `HWP 문서 저장` panel 확인 |
| WKWebView 내부 shortcut label이 macOS 표기로 표시 | OK | Stage 3 accessibility tree와 화면에서 `Command+X`, `Option+F10`, `Command+F`, `Command+B` 확인 |
| 저장 완료 feedback 표시 | OK | Stage 4 앱 smoke에서 `저장 완료 14:54` 표시 후 3초 뒤 파일명 status 복귀 확인 |
| Shared Swift AppKit/UIKit 경계 유지 | OK | `./scripts/check-no-appkit.sh` → `OK: shared Swift code has no AppKit/UIKit dependencies` |
| whitespace 검사 | OK | `git diff --check` 오류 없음 |

## 잔여 위험과 후속 작업

- HWP 저장은 rhwp-studio export payload를 다시 쓰는 방식이다. 현재 smoke에서는 정상 저장됐지만, 문서별 round-trip compatibility 검증 체계는 별도 작업이 필요하다.
- dirty-state 추적이 없으므로 `Command+S`는 변경 여부와 무관하게 export/write를 수행한다. 릴리즈 후 문서 편집 기능 범위가 넓어지면 dirty-state와 저장 필요 여부 표시가 필요하다.
- HWPX 저장은 이번 작업 범위가 아니다. 기존 rhwp-studio의 HWPX 저장 제한 정책을 유지한다.
- native viewer footer를 복구해 전체 파일 경로, 마지막 저장 시각, Finder reveal을 제공하는 UX는 별도 이슈로 분리하는 것이 좋다. 이 후속 작업에서 상단 Finder 버튼 제거 여부도 함께 판단할 수 있다.
- source document가 없는 빈 WebView에서 `Command+S` save panel fallback은 코드 경로로 유지했지만, Stage 4 수동 smoke는 HWP source document 중심으로 수행했다.

## 결론

#142의 핵심 목표인 macOS 저장 단축키 분리, 즉시 저장, save-as fallback, WebView shortcut 표기 보정, 저장 완료 피드백을 완료했다. 최종 검증 기준으로 Debug build와 주요 수동 smoke가 통과했다.

작업지시자에게 본 최종 보고서 기준 PR 게시와 리뷰를 요청한다.
