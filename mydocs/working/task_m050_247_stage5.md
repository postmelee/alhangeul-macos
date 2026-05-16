# Task M050 #247 Stage 5 보고서

## 목적

`origin/devel..origin/devel-webview`에 남은 #243 저장 확인 변경을 `native-viewer-editor` 라인에 선별 포팅한다.

이번 단계의 목표는 `devel-webview`를 다시 기준 브랜치로 되돌리는 것이 아니라, native 라인 후속 개발에도 필요한 dirty-state, 창 닫기, 앱 종료 확인 흐름만 최신 제품 라인에 맞춰 가져오는 것이다.

## 반영한 항목

| 파일 | 변경 |
|------|------|
| `Sources/HostApp/Services/DocumentCloseConfirmationController.swift` | 저장되지 않은 변경사항이 있는 문서 창을 닫을 때 저장/저장하지 않음/취소 sheet를 표시하는 AppKit controller 추가 |
| `Sources/HostApp/Services/DocumentTerminationCoordinator.swift` | 앱 종료 시 dirty window를 순서대로 확인하고 `terminateLater` 응답을 완료하는 coordinator 추가 |
| `Sources/HostApp/HostApp.swift` | window lifecycle에 close confirmation controller 연결, 자동으로 닫는 빈 창은 prompt 없이 닫도록 우회, 앱 종료 delegate 연결 |
| `Sources/HostApp/Stores/DocumentViewerStore.swift` | `hasUnsavedChanges` 상태와 mark/clear API 추가, 문서 load/save/clear 시 dirty state 초기화 |
| `Sources/HostApp/Views/DocumentViewerView.swift` | WebView fallback에서 document edited callback을 store dirty state로 연결 |
| `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift` | WebView fallback 내부 command/input/keyboard/drop 이벤트를 dirty-state 신호로 전달 |
| `Sources/HostApp/Views/RhwpStudioWebView.swift` | save completion result, document-edited message handling, close confirmation에서 호출 가능한 save dispatcher 추가 |
| `Alhangeul.xcodeproj/project.pbxproj` | `xcodegen generate`로 새 service 파일을 HostApp source phase에 반영 |

`project.yml`은 이미 `Sources/HostApp` glob를 사용하므로 별도 수정하지 않았다.

## 제외한 항목

| 항목 | 제외 사유 |
|------|-----------|
| README/CONTRIBUTING/AGENTS/.github 문서 변경 | `devel-webview` 전환기 문서 변경이 포함되어 있어 현재 `devel` 기본 브랜치 정책과 충돌할 수 있음 |
| `.github/workflows/pr-ci.yml`, PR template, Copilot instructions 변경 | #244 이후 devel 기준 문서/운영 정리와 충돌할 가능성이 있어 Stage 5 범위에서 제외 |
| `origin/devel-webview` 전체 merge | legacy alias 방향으로 branch 안내가 후퇴할 수 있으므로 source 변경만 선별 포팅 |

## 판단 기록

### close/termination controller

`DocumentCloseConfirmationController`와 `DocumentTerminationCoordinator`는 WebView 자체가 아니라 macOS window/app lifecycle에 붙는 구현이다. `native-viewer-editor`가 장기적으로 native editor를 붙이더라도 dirty 문서 close/terminate 정책은 같은 계층에서 필요하다.

현재 구현은 기존 `DocumentWindowPresenter`가 설정한 `NSWindowDelegate`를 보존하고 forwarding한다. 따라서 detached window controller 정리 로직은 `windowWillClose`를 통해 계속 호출된다.

### dirty-state 신호

dirty-state의 입력은 현재 남아 있는 `RhwpStudioWebView` fallback에 연결했다. 이는 native editor 저장 모델을 확정하는 변경이 아니라, 현 브랜치가 아직 사용하는 WebView fallback에서 #243의 저장 확인 동작을 유지하기 위한 포팅이다.

후속 native editor 구현에서는 `DocumentViewerStore.markDocumentEdited()`와 `clearUnsavedChanges()`를 native editing surface에서도 호출하도록 확장하면 된다.

### 저장 completion

닫기 확인 sheet의 "저장" 버튼은 `RhwpStudioNativeCommandDispatcher.saveDocument(in:completion:)`을 통해 현재 window의 WebView save bridge를 호출한다. 저장 성공 시 `recordSavedDocument(at:)`가 실행되어 source document와 recent document를 갱신하고 dirty state를 clear한다.

저장 대상 선택 취소나 저장 실패는 close/termination을 취소한다.

## 검증

| 명령 | 결과 |
|------|------|
| `xcodegen generate` | 통과. 새 service 파일이 `Alhangeul.xcodeproj` HostApp source phase에 반영됨 |
| `./scripts/check-no-appkit.sh` | 통과. shared Swift code AppKit/UIKit 의존 없음 |
| `for script in scripts/*.sh scripts/ci/*.sh; do bash -n "$script"; done` | 통과 |
| `scripts/ci/classify-pr-changes.sh HEAD~1 HEAD` | `docs_only=false`, `run_macos_build=true`, `run_rust_verify=false`, `run_render_smoke=false`, `run_release_checks=false` |
| `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData -clonedSourcePackagesDirPath build.noindex/SourcePackages CODE_SIGNING_ALLOWED=NO build` | 통과. `** BUILD SUCCEEDED **` |
| `git diff --check` | 통과 |

`xcodebuild` 중 CoreSimulator out-of-date warning과 macOS destination 중복 warning이 출력됐지만 HostApp macOS Debug build는 성공했다.

## 다음 단계

Stage 6에서는 최종 검증을 반복하고 `mydocs/report/task_m050_247_report.md`를 작성한다. 이후 오늘할일 완료 처리, 최종 커밋, `publish/task247` push와 `native-viewer-editor` 대상 PR 게시를 준비한다.
