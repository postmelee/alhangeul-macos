# Task #144 최종 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | [#144 HostApp WKWebView 드래그앤드롭 문서 로드 후 titlebar toolbar 동작 비활성화 수정](https://github.com/postmelee/alhangeul-macos/issues/144) |
| 마일스톤 | M010 / v0.1.0 Viewer 기반 |
| 기준 브랜치 | `devel-webview` |
| 작업 브랜치 | `local/task144` |
| 단계 수 | 5단계 |
| 결론 | WKWebView 내부 drag/drop으로 문서를 열었을 때 문서 상태가 native store로 반영되지 않아 toolbar 검증 상태가 갱신되지 않던 문제를 수정했다. |

WKWebView 주입 스크립트가 지원 문서 drop을 감지해 문서 바이트와 파일명을 native로 전달하고, `DocumentViewerStore`가 이 source-less 문서를 현재 문서로 로드하도록 연결했다. Toolbar 검증은 store 변경 시점에 명시적으로 다시 수행되도록 보강했다.

단, Finder 원본 URL이 없는 JS/File 기반 drop에서는 `Finder에서 보기`를 활성화하지 않는다. 이 동작은 이번 수정의 안전 정책이며, Finder drag/drop 원본 URL 확보는 후속 이슈로 분리한다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift` | WKWebView 내부 `drop` 이벤트에서 `.hwp`/`.hwpx` 파일을 감지하고 base64 payload를 native bridge로 전송하는 `dropped-document` 메시지를 추가했다. |
| `Sources/HostApp/Views/RhwpStudioWebView.swift` | `dropped-document` script message를 Swift 타입으로 디코딩하고 `onDroppedDocument` callback으로 전달했다. 기존 PDF export payload 디코딩도 공통 헬퍼를 사용하도록 정리했다. |
| `Sources/HostApp/Stores/DocumentViewerStore.swift` | source URL이 없는 drop 문서를 `rhwpStudioDocument`로 로드하는 `loadDroppedDocument(data:filename:)` 경로를 추가했다. |
| `Sources/HostApp/Views/DocumentViewerView.swift` | WebView drop callback을 store 로드 경로에 연결했다. |
| `Sources/HostApp/HostApp.swift` | `DocumentWindowToolbarController`가 store 변경을 구독해 visible toolbar item validation을 다시 수행하도록 보강했다. |
| `mydocs/plans/task_m010_144.md` | 수행 계획서 작성. |
| `mydocs/plans/task_m010_144_impl.md` | 구현 계획서 작성. |
| `mydocs/working/task_m010_144_stage1.md` | Stage 1 조사 보고서 작성. |
| `mydocs/working/task_m010_144_stage2.md` | Stage 2 bridge message 보고서 작성. |
| `mydocs/working/task_m010_144_stage3.md` | Stage 3 store 연결 보고서 작성. |
| `mydocs/working/task_m010_144_stage4.md` | Stage 4 toolbar smoke 검증 보고서 작성. |
| `mydocs/working/task_m010_144_stage5.md` | Stage 5 최종 정리 보고서 작성. |
| `mydocs/orders/20260505.md` | 오늘할일 상태를 완료로 갱신. |

## 변경 전·후 정량 비교

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| WKWebView drag/drop 문서 로드 | rhwp-studio 내부에서만 문서가 열리고 native toolbar 상태는 빈 문서처럼 남음 | native store가 dropped document를 현재 문서로 보유하고 toolbar 상태가 문서 있음 기준으로 갱신됨 |
| JS/File drag/drop의 공유하기 | 비활성 | 활성 |
| JS/File drag/drop의 PDF 내보내기 | 비활성 | 활성 |
| JS/File drag/drop의 Finder에서 보기 | 비활성 | 비활성 유지. source URL 없음 정책 |
| native open의 Finder에서 보기 | 활성 | 활성 유지 |
| 소스 변경량 | 없음 | 5개 파일, +142/-4 |
| 문서 변경량 | 없음 | 계획서 2개, 단계 보고서 5개, 오늘할일 갱신, 최종 보고서 |

## 단계별 결과

| 단계 | 커밋 | 결과 |
|------|------|------|
| 계획 | `b39e697` | 수행 계획서와 오늘할일 항목을 작성했다. |
| 구현 계획 | `2ad96c6` | drag/drop bridge, store 연결, smoke 검증으로 구현 단계를 분리했다. |
| Stage 1 | `3c73e61` | 기존 open 경로와 toolbar enable 조건을 조사하고, bug 재현 근거를 정리했다. |
| Stage 2 | `255bdef` | WKWebView 주입 스크립트와 Swift message handler에 dropped document bridge를 추가했다. |
| Stage 3 | `4d6b651` | dropped document를 `DocumentViewerStore`의 현재 문서 상태에 연결했다. |
| Stage 4 | `5dd3d43` | drag/drop과 native open toolbar 상태를 smoke 검증했다. |
| Stage 5 | `a22763d` | 최종 정리와 후속 이슈 분리 내용을 문서화했다. |

## 검증 결과

| 검증 | 결과 | 비고 |
|------|------|------|
| `git diff --check` | OK | whitespace error 없음 |
| `scripts/check-no-appkit.sh` | OK | `Sources/RhwpCoreBridge` AppKit/UIKit 의존 없음 |
| `xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build` | OK | `** BUILD SUCCEEDED **` |
| HWP drag/drop smoke | OK | `samples/exam_social.hwp` drop 후 `공유하기`와 `PDF로 내보내기` 활성, `Finder에서 보기` 비활성 확인 |
| native open smoke | OK | `samples/exam_science.hwp` open 후 `공유하기`, `Finder에서 보기`, `PDF로 내보내기` 활성 확인 |
| HWPX drag/drop smoke | PARTIAL | `.hwpx` 확장자는 bridge filter에 포함했지만 별도 수동 smoke는 미실행 |

## 잔여 위험과 후속 작업

| 구분 | 내용 |
|------|------|
| 후속 이슈 | Finder drag/drop 원본 URL 확보. JS/File drop payload만으로는 Finder 원본 경로를 신뢰할 수 없어 AppKit `NSDraggingDestination` 또는 pasteboard 기반 native drop 경로가 필요하다. |
| 잔여 위험 | 큰 문서는 JS base64 payload 생성으로 일시 메모리 사용량이 늘 수 있다. |
| 미검증 | HWPX 실제 drag/drop smoke와 공유/PDF 명령의 최종 산출물 저장까지의 end-to-end 검증은 별도 실행하지 않았다. |

## 작업지시자 승인 요청

Task #144는 drag/drop 문서 로드 후 toolbar 상태 갱신 문제를 수정했고, source URL이 없는 Finder drag/drop의 `Finder에서 보기`는 후속 이슈로 분리했다. 본 보고서와 PR 게시 결과를 기준으로 리뷰와 merge 여부 확인을 요청한다.
