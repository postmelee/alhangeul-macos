# Task M019 #223 Stage 5 완료 보고서

## 단계 목적

Stage 4에서 확인된 nonfatal banner가 사용자가 닫기 전까지 계속 남는 UX 문제를 보완했다. 상단 banner는 문서 사용을 막지 않는 transient 알림이므로 5초 뒤 자동으로 사라지게 하고, 사용자가 즉시 닫을 수 있는 우측 닫기 버튼을 추가했다.

## 변경 내용

### banner 상태 소유권 정리

`DocumentViewerStore`가 `webViewErrorMessage`를 외부에서 직접 변경하지 않도록 `private(set)`으로 바꾸고, 다음 API로만 표시와 해제를 처리하게 했다.

| API | 역할 |
|-----|------|
| `setWebViewError(_:)` | WebView error callback에서 banner 표시 또는 해제 |
| `setWebViewFailure(_:)` | fatal이면 fallback 표시와 banner 해제, nonfatal이면 banner 표시 |
| `dismissWebViewError()` | 사용자가 닫거나 load/retry 시 banner와 예약 task 해제 |

### 자동 dismiss

banner를 표시할 때마다 5초 dismiss task를 예약한다. 새 banner가 들어오면 기존 task를 취소하고 token을 증가시켜 오래된 task가 새 message를 지우지 못하게 했다.

자동 dismiss가 적용되는 대상은 `webViewErrorMessage` 기반 상단 banner 전체다. `webViewFailure` 기반 fatal fallback 화면은 기존처럼 유지되며 자동으로 닫히지 않는다.

### 수동 닫기 버튼

`WebViewerErrorBanner` 우측에 `xmark` 버튼을 추가했다.

- 버튼은 `dismissWebViewError()`를 호출해 즉시 banner를 닫는다.
- tooltip/help와 accessibility label은 `알림 닫기`로 지정했다.
- 작업지시자 직접 smoke 후 닫기 버튼 색상이 잘 보이지 않는다는 피드백을 받아 `xmark` 색상을 흰색으로 조정했다.

## 변경 파일

| 파일 | 변경 |
|------|------|
| `Sources/HostApp/Stores/DocumentViewerStore.swift` | banner 표시/dismiss API와 5초 자동 dismiss task 추가 |
| `Sources/HostApp/Views/DocumentViewerView.swift` | banner 닫기 버튼과 흰색 `xmark` 적용 |
| `mydocs/plans/task_m019_223_impl.md` | Stage 5 UX 보완 단계를 추가하고 최종 정리를 Stage 6으로 조정 |
| `mydocs/orders/20260511.md` | 오늘할일 상태를 Stage 5 완료보고서 승인 대기로 갱신 |
| `mydocs/working/task_m019_223_stage5.md` | Stage 5 완료 보고서 추가 |

## 검증 결과

```bash
git diff --check -- Sources/HostApp/Stores/DocumentViewerStore.swift Sources/HostApp/Views/DocumentViewerView.swift mydocs/plans/task_m019_223_impl.md
```

결과: 출력 없음, exit code 0.

```bash
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedDataStage5 CODE_SIGNING_ALLOWED=NO build
```

결과: `** BUILD SUCCEEDED **`.

```bash
scripts/verify-rhwp-studio-assets.sh
scripts/verify-rhwp-studio-assets.sh build.noindex/DerivedDataStage5/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
```

결과: 둘 다 성공.

```bash
xcodebuild -list -project Alhangeul.xcodeproj
```

결과: 테스트 타깃은 없고 `HostApp`, `QLExtension`, `ThumbnailExtension` scheme만 존재함을 확인했다.

## 수동 smoke 결과

- Stage 5 Debug 앱을 실행해 `samples/exam_science.hwp` 표시 상태를 확인했다.
- Stage 1 재현 위치에서 object 선택 후 Space 입력을 재시도했지만, 이번 세션에서는 banner가 다시 발생하지 않았다.
- 작업지시자가 같은 변경본을 직접 테스트해 닫기 버튼 노출을 확인했고, 닫기 버튼 색상 피드백을 제공했다.
- 피드백 반영 후 `xmark` 색상을 흰색으로 변경하고 빌드 검증을 다시 통과시켰다.

## 유지한 동작

- fatal fallback 화면은 `webViewFailure` 경로로 남아 자동 dismiss나 `xmark` 버튼이 적용되지 않는다.
- nonfatal runtime failure는 문서 화면을 유지한 채 banner만 표시한다.
- 문서 reload, retry, 새 문서 load, fatal failure 전환 시 기존 banner dismiss task는 취소된다.

## 잔여 위험

- 자동 dismiss의 시간 경과 동작은 코드 경로와 빌드로 검증했고, 이번 세션의 Computer Use smoke에서는 재현 banner를 안정적으로 다시 띄우지 못했다.
- 같은 bundle identifier의 여러 Debug 앱이 동시에 실행되면 Computer Use가 오래된 인스턴스를 바라볼 수 있어, 화면 검증 시 Debug 인스턴스 정리가 필요하다.

## 다음 단계

Stage 5 결과를 승인하면 Stage 6에서 최종 보고서와 PR 게시 준비를 진행한다.

## 승인 요청

Stage 5 산출물 승인을 요청한다.

승인 후 Stage 6 `최종 정리와 PR 준비`로 진행한다.
