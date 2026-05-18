# Task M010 #243 최종 보고서

## 작업 요약

- 이슈: #243 종료/창 닫기 시 저장 여부 확인 모달 추가
- 마일스톤: M010 (`v0.1`)
- 브랜치: `local/task243`
- 단계 수: 5
- 핵심 변경: WKWebView 기반 HostApp에서 dirty 문서 창 닫기와 앱 종료 시 저장 확인 sheet를 표시하고, 저장/저장하지 않음/취소 선택에 따라 창 닫기와 앱 종료를 제어하도록 구현

## 단계별 진행

| Stage | Commit | 핵심 내용 |
|-------|--------|-----------|
| 시작 | `e367320` | 수행계획서 작성과 오늘할일 등록 |
| 구현 계획 | `a986953` | 5단계 구현계획서 작성 |
| 1 | `e4e3193` | 종료/창 닫기 lifecycle, 저장 bridge, dirty signal 후보 조사 |
| 2 | `8d4184b` | `DocumentViewerStore.hasUnsavedChanges`와 WebView `document-edited` bridge 추가 |
| 3 | `4af671f` | 저장 completion API와 문서 창 닫기 저장 확인 controller 추가 |
| 4 | `af101e8` | 앱 종료 dirty 문서 순차 확인 coordinator 추가 |
| 5 | 본 커밋 | 통합 검증, 수동 smoke, 최종 보고서 작성 |

## 완료 내용

- `DocumentViewerStore`가 현재 문서의 저장되지 않은 변경 여부를 소유한다.
- `RhwpStudioHostBridgeScript`가 WebView 내부 입력/편집 후보 이벤트를 `document-edited` native message로 전달한다.
- `DocumentViewerView`와 `RhwpStudioWebView`가 dirty callback을 store에 연결한다.
- 저장 완료 시 `recordSavedDocument(at:)`가 dirty state를 해제한다.
- 창 닫기 요청은 `DocumentCloseConfirmationController`가 `NSWindowDelegate`로 가로챈다.
- dirty 문서 창 닫기 시 `저장`, `저장하지 않음`, `취소` sheet를 표시한다.
- `저장`은 기존 `RhwpStudioNativeCommandDispatcher.saveDocument(in:completion:)` 경로를 재사용한다.
- 저장 성공은 창 닫기/종료를 계속 진행하고, 저장 panel 취소 또는 저장 실패는 중단한다.
- `저장하지 않음`은 dirty state를 해제한 뒤 창 닫기/종료를 계속 진행한다.
- `취소`는 창 닫기/종료를 중단한다.
- `AppDelegate.applicationShouldTerminate(_:)`가 `DocumentTerminationCoordinator`에 종료 정책을 위임한다.
- dirty 문서가 없으면 `.terminateNow`, dirty 문서가 있으면 `.terminateLater`와 `reply(toApplicationShouldTerminate:)`로 비동기 종료 확인을 수행한다.
- 여러 dirty window는 registry에서 수집해 순차 처리하도록 구성했다.
- `Sources/RhwpCoreBridge`와 Rust FFI 경계는 변경하지 않았다.
- `rhwp-studio` bundled asset은 변경하지 않았다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `Sources/HostApp/Stores/DocumentViewerStore.swift` | dirty state, mark/clear, 저장 완료 시 dirty 해제 |
| `Sources/HostApp/Views/DocumentViewerView.swift` | WebView document edited callback을 store에 연결 |
| `Sources/HostApp/Views/RhwpStudioWebView.swift` | `document-edited` message 처리, save completion result, window scoped save dispatcher |
| `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift` | 입력/편집 후보 event와 mutating command 후보 감지 |
| `Sources/HostApp/Services/DocumentCloseConfirmationController.swift` | 창 닫기/종료 공용 저장 확인 sheet, registry, save completion 처리 |
| `Sources/HostApp/Services/DocumentTerminationCoordinator.swift` | 앱 종료 시 dirty 문서 순차 확인과 termination reply 관리 |
| `Sources/HostApp/HostApp.swift` | window lifecycle close guard 연결, app termination hook 추가 |
| `Alhangeul.xcodeproj/project.pbxproj` | XcodeGen 재생성 결과 |
| `mydocs/plans/task_m010_243.md` | 수행계획서 |
| `mydocs/plans/task_m010_243_impl.md` | 구현계획서 |
| `mydocs/working/task_m010_243_stage1.md` | Stage 1 조사 보고서 |
| `mydocs/working/task_m010_243_stage2.md` | Stage 2 dirty bridge 보고서 |
| `mydocs/working/task_m010_243_stage3.md` | Stage 3 창 닫기 저장 확인 보고서 |
| `mydocs/working/task_m010_243_stage4.md` | Stage 4 앱 종료 저장 확인 보고서 |
| `mydocs/working/task_m010_243_stage5.md` | Stage 5 통합 검증 보고서 |
| `mydocs/orders/20260514.md` | #243 완료 상태 기록 |
| `mydocs/report/task_m010_243_report.md` | 본 최종 보고서 |

## 검증 결과

```bash
./scripts/check-no-appkit.sh
```

결과: 성공. `Sources/RhwpCoreBridge`에 AppKit/UIKit 직접 의존 없음.

```bash
xcodegen generate
```

결과: 성공.

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask243 \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과: 최종 승인 경로에서 `** BUILD SUCCEEDED ** [12.179 sec]`.

최초 sandbox 실행은 Sparkle SwiftPM fetch 중 `github.com` DNS 제한으로 실패했다. 같은 명령을 승인 경로로 재실행해 통과했다. CoreSimulator version 경고가 출력되었지만 macOS HostApp build는 완료됐다.

```bash
scripts/verify-rhwp-studio-assets.sh
scripts/verify-rhwp-studio-assets.sh build.noindex/DerivedDataTask243/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
```

결과: 둘 다 성공.

```bash
rg -n "Task M010 #243|#243|저장되지 않은|저장하지 않음|applicationShouldTerminate|windowShouldClose|hasUnsavedChanges|document-edited" \
  Sources/HostApp mydocs/orders/20260514.md mydocs/plans/task_m010_243.md mydocs/plans/task_m010_243_impl.md mydocs/working mydocs/report
```

결과: 관련 코드와 문서 연결 지점 확인.

```bash
git diff --check
git status --short --branch
```

문서 작성 전 기준 결과: whitespace error 없음, worktree clean.

## UI smoke 결과

Debug app에서 `KTX.hwp`를 열고 본문 입력으로 dirty 상태를 만든 뒤 확인했다.

- 앱 종료(`Command+Q`) 시 저장 확인 sheet 표시.
- 앱 종료 sheet에서 `취소` 선택 시 앱과 문서 창 유지.
- 앱 종료 sheet에서 `저장하지 않음` 선택 시 앱 종료.
- 창 닫기 버튼 클릭 시 저장 확인 sheet 표시.
- 창 닫기 sheet에서 `취소` 선택 시 문서 창 유지.
- 창 닫기 sheet에서 `저장하지 않음` 선택 시 문서 창 닫힘.
- smoke 후 `build.noindex/DerivedDataTask243` Debug app 프로세스를 정리.
- smoke 중 source sample 저장은 수행하지 않아 worktree 변경 없음.

## 직접 확인하지 않은 항목

- `저장` 선택 후 실제 원본 파일 write까지 이어지는 UI smoke는 수행하지 않았다. 최근 문서로 연 `KTX.hwp`가 실제 sample 파일이므로 저장 버튼을 누르면 source sample을 덮어쓸 수 있기 때문이다.
- dirty 문서 2개 이상의 순차 종료 sheet는 UI에서 직접 수행하지 않았다. coordinator의 순차 처리 경로는 build와 코드 경로 검증으로 확인했다.

## 완료 판단

Issue #243의 핵심 결함인 dirty 문서 창 닫기/앱 종료 시 저장 여부 확인 부재는 해결됐다. `취소`와 `저장하지 않음`의 데이터 유실 방지 경로는 실제 Debug app UI에서 확인했고, 저장 경로는 기존 save/export bridge를 재사용하도록 completion API로 연결했다.

## 잔여 위험

- 실제 `저장` 성공 후 창 닫기/앱 종료 완료까지의 end-to-end UI smoke는 별도 temp 문서로 보강하는 것이 좋다.
- multi-window dirty 종료 순서와 중간 취소는 coordinator 설계상 지원하지만, 실제 foreground multi-window smoke는 후속 검증으로 남는다.
- dirty signal은 false negative를 줄이기 위해 보수적으로 감지한다. `rhwp-studio` 내부 command 구조가 바뀌면 dirty 후보 목록을 재점검해야 한다.

## 다음 단계

작업지시자 승인 후 `publish/task243` 브랜치 게시와 `devel-webview` 대상 PR 생성 절차로 넘길 수 있다.
