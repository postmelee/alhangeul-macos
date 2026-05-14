# Task M010 #243 Stage 4 완료보고서

## 단계 목적

앱 전체 종료 요청에서 저장되지 않은 변경사항이 있는 문서 창을 순차적으로 확인하고, 사용자의 선택과 저장 결과에 따라 앱 종료를 계속하거나 중단하도록 구현했다. 창 단위 저장 확인은 Stage 3 구현을 재사용했다.

## 산출물

- `Sources/HostApp/Services/DocumentTerminationCoordinator.swift` (75 lines)
  - `applicationShouldTerminate(_:)`에서 dirty 문서가 없으면 `.terminateNow`, 있으면 `.terminateLater`를 반환한다.
  - dirty 문서 close controller를 순차 확인하고, 모든 문서가 저장 또는 저장하지 않음으로 정리되면 `reply(toApplicationShouldTerminate: true)`를 호출한다.
  - 취소, 저장 panel 취소, 저장 실패가 발생하면 `reply(toApplicationShouldTerminate: false)`로 앱 종료를 중단한다.
  - 종료 confirmation 중 재진입 요청이 들어오면 중복 reply를 막도록 내부 상태를 둔다.
- `Sources/HostApp/Services/DocumentCloseConfirmationController.swift` (268 lines)
  - 창 닫기 sheet 결과를 앱 종료 흐름에서도 재사용할 수 있도록 `DocumentCloseConfirmationResult`를 추가했다.
  - window/store 쌍을 수집하는 `DocumentCloseConfirmationRegistry`를 추가했다.
  - `confirmForTermination(completion:)`를 추가해 앱 종료 중에도 동일한 저장/저장하지 않음/취소 sheet를 표시한다.
  - 창 닫기 경로는 기존처럼 confirmed 결과에서만 실제 close를 실행하도록 유지했다.
- `Sources/HostApp/HostApp.swift` (486 lines)
  - `AppDelegate.applicationShouldTerminate(_:)`를 추가해 termination coordinator로 앱 종료 정책을 위임했다.
- `Alhangeul.xcodeproj/project.pbxproj`
  - `xcodegen generate`로 신규 `DocumentTerminationCoordinator.swift` source 포함 항목을 반영했다.
- `mydocs/orders/20260514.md`
  - #243 상태 메모를 `Stage 4 완료 후 승인 대기`로 갱신했다.

## 본문 변경 정도 / 무손실 여부

- HostApp의 AppKit lifecycle 경계만 변경했다.
- `Sources/RhwpCoreBridge`와 Rust FFI 경계는 변경하지 않았다.
- 저장 export/write 구현은 복제하지 않고 Stage 3에서 만든 `RhwpStudioNativeCommandDispatcher.saveDocument(in:completion:)` 경로를 그대로 사용했다.
- `rhwp-studio` bundled asset은 변경하지 않았다.

## 구현 메모

- 종료 대상 dirty 문서는 `DocumentCloseConfirmationRegistry.dirtyControllers()`가 수집한다.
- registry는 현재 `NSApp.windows` 순서를 우선 사용해 사용자에게 보이는 창 순서에 가깝게 sheet를 표시한다.
- termination coordinator는 dirty controller 목록을 순차 처리한다.
  - 이미 dirty가 해제된 controller는 건너뛴다.
  - `저장` 성공 또는 `저장하지 않음`은 다음 문서로 진행한다.
  - `취소`, save panel 취소, 저장 실패는 전체 종료를 중단한다.
- close sheet가 이미 표시 중인 창에서 앱 종료가 들어오면 해당 종료 요청은 취소로 처리해 중복 sheet와 중복 termination reply를 피한다.

## 검증 결과

```bash
git diff --check -- Alhangeul.xcodeproj/project.pbxproj Sources/HostApp/HostApp.swift Sources/HostApp/Services/DocumentCloseConfirmationController.swift Sources/HostApp/Services/DocumentTerminationCoordinator.swift
```

- 결과: 통과. 출력 없음.

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask243Stage4 \
  CODE_SIGNING_ALLOWED=NO \
  build
```

- sandbox 실행 결과: SwiftPM package graph 해석 중 `github.com` DNS 접근 제한으로 실패했다.
- 승인 경로로 같은 명령을 재실행했다.
- 최종 결과: `** BUILD SUCCEEDED ** [12.156 sec]`
- 참고: Xcode의 CoreSimulator version 경고가 출력되었지만 macOS HostApp build는 완료되었다.

```bash
rg -n "applicationShouldTerminate|terminateLater|reply\\(toApplicationShouldTerminate|termination|DocumentTermination|unsaved|DocumentCloseConfirmationRegistry" Sources/HostApp
```

- 결과: AppDelegate 종료 hook, termination coordinator, close confirmation registry, dirty 확인 경로를 확인했다.

## 수동 smoke

- foreground 앱 조작이 필요한 Command+Q sheet 흐름은 이번 단계에서 자동화하지 않았다.
- Stage 5 통합 검증에서 다음 항목을 실제 앱으로 확인해야 한다.
  - dirty 문서 1개에서 Command+Q 후 `취소` 선택 시 앱 유지
  - dirty 문서 1개에서 `저장하지 않음` 선택 시 앱 종료
  - dirty 문서 1개에서 `저장` 성공 시 앱 종료
  - save panel 취소 또는 저장 실패 시 앱 종료 중단
  - dirty 문서 2개 이상에서 순차 확인과 중간 취소 동작

## 잔여 위험

- multi-window termination sheet 순서는 `NSApp.windows`와 registry fallback을 사용하므로 실제 사용자 체감 순서는 Stage 5 수동 smoke에서 확인해야 한다.
- interactive sheet 동작은 build로 보장되지 않으므로 Stage 5에서 창 닫기와 앱 종료를 함께 검증해야 한다.

## 다음 단계 영향

- Stage 5는 통합 검증과 최종 보고 단계다.
- `./scripts/check-no-appkit.sh`, `xcodegen generate`, HostApp Debug build, `scripts/verify-rhwp-studio-assets.sh`, 수동 smoke를 실행하고 최종 보고서를 작성한다.

## 승인 요청

Stage 5에서 통합 검증과 최종 보고로 넘어갈 수 있도록 검토와 다음 단계 진행 승인을 요청한다.
