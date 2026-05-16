# Task #153 최종 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| GitHub Issue | [#153 Finder drag/drop 원본 URL 확보로 Finder에서 보기 활성화](https://github.com/postmelee/alhangeul-macos/issues/153) |
| 마일스톤 | M010 — v0.1.0 Viewer 기반 |
| 대상 브랜치 | `devel-webview` |
| 작업 브랜치 | `local/task153` |
| 게시 브랜치 | `publish/task153` 예정 |
| 단계 수 | 구현 계획 5단계 + 최종 보고 |

Finder에서 WKWebView viewer 영역으로 파일을 끌어놓을 때 기존 JavaScript `dropped-document` fallback은 문서 bytes와 filename만 전달했기 때문에 `sourceDocument`가 설정되지 않았다. 이 작업에서는 AppKit drag pasteboard에서 native file URL을 먼저 확보하고 기존 `DocumentViewerStore.loadDocument(from:)` 경로로 연결해, Finder drag/drop에서도 native open과 같은 `Finder에서 보기` 정책을 사용하도록 했다.

PR 준비 중 `devel-webview`가 Task #123 merge로 앞서 나간 것을 확인해 `local/task153`에 최신 `devel-webview`를 병합했다. 이 병합은 PR diff에서 관련 없는 `CGTreeRenderer.swift` 역변경이 보이지 않도록 기준을 맞추기 위한 것이며, Task #153의 기능 변경 범위에는 포함하지 않는다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `Sources/HostApp/Views/RhwpStudioWebView.swift` | `WKWebView` subclass에서 Finder file URL drag pasteboard를 읽고, HWP/HWPX URL을 native callback으로 전달한다. native URL drop 직후 같은 파일명의 JS fallback이 source-less 문서로 덮어쓰지 않도록 중복 억제 상태를 추가했다. |
| `Sources/HostApp/Views/DocumentViewerView.swift` | `RhwpStudioWebView`의 native file URL drop callback을 `DocumentViewerStore.loadDocument(from:)`로 연결했다. |
| `mydocs/plans/task_m010_153.md` | 작업 수행 계획서 작성 |
| `mydocs/plans/task_m010_153_impl.md` | 구현 단계와 검증 기준 작성 |
| `mydocs/working/task_m010_153_stage1.md` | native drag/drop URL 확보 지점 조사 보고 |
| `mydocs/working/task_m010_153_stage2.md` | native file URL drop callback 구현 보고 |
| `mydocs/working/task_m010_153_stage3.md` | store 연결과 duplicate guard 구현 보고 |
| `mydocs/working/task_m010_153_stage4.md` | 빌드 및 toolbar smoke 검증 보고 |
| `mydocs/working/task_m010_153_stage5.md` | 최종 보고와 PR 준비 상태 정리 |
| `mydocs/orders/20260506.md` | Task #153 진행 상태와 완료 처리 |

## 변경 전·후 정량 비교

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| Finder drag/drop 원본 URL | JS fallback payload만 사용, 원본 file URL 없음 | AppKit pasteboard에서 file URL 확보 후 `loadDocument(from:)` 사용 |
| `Finder에서 보기` 활성 조건 | `sourceDocument != nil`, Finder drag/drop에서는 미충족 | Finder drag/drop도 `sourceDocument` 설정으로 충족 |
| HostApp 소스 변경량 | 해당 없음 | `DocumentViewerView.swift` +5줄, `RhwpStudioWebView.swift` +140줄 |
| 단계 문서 | 없음 | Stage 1-5 보고서 5개 작성 |
| 통합 브랜치 정렬 | 작업 시작 시점 `devel-webview` 기준 | Task #123 merge 이후 최신 `devel-webview` 병합 완료 |

## 검증 결과

| 수용 기준 | 결과 | 근거 |
|-----------|------|------|
| `git diff --check` 통과 | OK | 최종 절차에서 출력 없이 성공 |
| `scripts/check-no-appkit.sh` 통과 | OK | `OK: shared Swift code has no AppKit/UIKit dependencies` |
| HostApp Debug build 성공 | OK | `xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build` 결과 `** BUILD SUCCEEDED ** [5.275 sec]` |
| Finder HWP drag/drop 후 문서 표시 | OK | Stage 4 smoke에서 `/private/tmp/rhwp-task153-drag/task153_unique.hwp` drag/drop 성공 |
| Finder drag/drop 후 toolbar 세 항목 enabled | OK | Stage 4 smoke에서 `공유`, `Finder에서 보기`, `PDF로 내보내기` 모두 enabled |
| `Finder에서 보기` 실행 시 원본 선택 | OK | Stage 4 smoke에서 Finder selection이 `/private/tmp/rhwp-task153-drag/task153_unique.hwp`로 확인됨 |
| native open HWP toolbar 유지 | OK | Stage 4 smoke에서 `samples/exam_math.hwp` open 후 세 항목 enabled |
| native open HWPX toolbar 유지 | OK | Stage 4 smoke에서 `samples/table-vpos-01.hwpx` open 후 세 항목 enabled |
| source-less JS/File drop fallback toolbar 정책 | MISS | 별도 UI smoke는 미실행. fallback 코드는 유지했고 native URL drop 뒤 덮어쓰기 방지만 추가했다. |
| HWPX Finder drag/drop smoke | MISS | HWPX는 native open만 확인했다. native pasteboard 필터는 HWP/HWPX를 동일하게 허용한다. |

## 잔여 위험과 후속 작업

| 항목 | 내용 |
|------|------|
| source-less fallback 직접 검증 | Finder drag/drop이 native URL 경로로 선점되므로 source-less fallback UI smoke를 별도로 만들지 못했다. fallback 코드는 유지되어 있으나 후속 회귀 테스트 후보로 남긴다. |
| HWPX Finder drag/drop | native open HWPX는 통과했지만 Finder drag/drop HWPX는 미실행이다. HWPX 베타/저장 제한 정책과 함께 후속 smoke 후보로 둔다. |
| duplicate guard | 현재는 normalized filename과 짧은 시간 창으로 같은 사용자 drop의 JS fallback 덮어쓰기를 억제한다. 동일 파일명을 짧은 시간 안에 반복 drop하는 특수 케이스는 후속 관찰 대상이다. |
| Finder drag target | smoke 검증에서 창이 겹쳐 실제 drop target이 앱이 아니면 로드되지 않았다. 앱 window 위에 정확히 drop되는 조건에서는 성공을 확인했다. |

## 작업지시자 승인 요청

최종 보고서 기준으로 Task #153 구현과 검증을 완료했다. `publish/task153` 브랜치 push 및 `devel-webview` 대상 PR 게시 후 리뷰와 merge 승인을 요청한다.
