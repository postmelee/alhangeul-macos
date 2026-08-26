# Task M040 #459 Stage 4 완료 보고서

## 단계 목적

Stage 1~3에서 구현·검증한 일반 인쇄 controller ownership, PDF renderer generation과 종료 cleanup을 장기 architecture 계약으로 기록한다. Issue #459의 완료 조건을 전체 HostAppTests, HostApp Debug build, XcodeGen 생성 정합성과 변경 범위에서 최종 확인한다.

## 산출물

| 파일 | 변경 내용 |
|------|-----------|
| `mydocs/tech/project_architecture.md` | 인쇄 lifecycle 단일 ownership, renderer current token 판정, `finish` cleanup 순서, 재사용과 자동 검증 한계 기록 |
| `mydocs/working/task_m040_459_stage4.md` | Issue 완료 조건별 근거와 Stage 4 최종 수용 검증 결과 기록 |
| `mydocs/orders/20260826.md` | Stage 4 완료와 최종 보고 승인 대기 상태 반영 |

Stage 4에서는 production source, test, `project.yml`과 generated Xcode project를 보정하지 않았다. Xcode project는 기존 `project.yml`로 두 번 재생성해 같은 결과임을 확인했다.

## Architecture 계약 반영

### 인쇄 controller 단일 ownership

- `RhwpStudioWebView.Coordinator`는 payload 검증 뒤 지속적으로 보유한 `RhwpStudioPrintLifecycle`에 인쇄 요청을 위임한다.
- Lifecycle은 active `RhwpStudioPrintControlling`의 단일 소유자다. Active controller가 있으면 factory 호출 전에 요청을 거부하고 기존 controller를 유지한다.
- Controller completion이 캡처한 controller와 현재 active controller의 객체 identity가 같을 때만 active slot을 해제한다. 이전 controller의 늦거나 중복된 completion은 후속 controller ownership을 바꾸지 않는다.
- Completion 내부에서 다음 요청을 즉시 시작할 수 있고 lifecycle/controller의 weak capture는 retain cycle을 만들지 않는다.

### Renderer generation과 current 판정

Renderer는 다음 세 식별 상태를 함께 소유한다.

1. Render 전체에서 단조 증가하는 `generation`
2. 현재 page의 `(generation, pageIndex)` token
3. `loadHTMLString`이 실제 반환한 `WKNavigation` 객체 identity

Navigation 완료·실패는 renderer 소유 WebView와 current navigation identity를, JavaScript preparation·metrics·`createPDF`·page append·watchdog은 current page token을 검사한다. WebContent process 종료는 renderer 소유 WebView에 active page token이 있을 때만 현재 generation을 실패시킨다. Stale callback은 현재 watchdog, page index, 누적 PDF, retained payload와 completion을 변경하지 않는다.

### 종료 cleanup과 재사용

`finish`는 current token을 먼저 무효화하고 exactly-once 상태를 설정한 뒤 navigation delegate, watchdog과 WebView load를 정리한다. 이어 stored completion, payload, 누적 PDF와 page index를 초기화한 뒤 사용자 completion을 호출한다.

사용자 completion보다 먼저 idle 상태로 복귀하므로 같은 call stack에서도 다음 render가 새 generation으로 시작될 수 있다. 정상 완료, navigation·font preparation·PDF encoding 실패, timeout과 WebContent process 종료 뒤 같은 renderer를 재사용하는 회귀를 architecture의 필수 계약으로 기록했다.

### 자동 검증 경계

- Navigation identity는 임의로 생성한 `WKNavigation`이 아니라 tracking WebView의 실제 `loadHTMLString` 반환값으로 검증한다.
- `WKNavigationAction`에는 render generation identity가 없어 current page의 최초 main-frame `about:blank` 1회 allowlist로 범위를 제한한다.
- WebContent process 종료 callback에도 process generation identity가 없어 renderer 소유 WebView와 current page token을 요구한다.
- Internal WebKit operation seam은 production의 `callAsyncJavaScript`와 `createPDF` 전후에 같은 token gate를 통과한다.
- 실제 printer, modal `NSPrintOperation` panel과 사용자 취소 UI는 deterministic 자동 테스트 대상이 아니다. Protocol/factory fake로 controller ownership과 outcome별 재진입을 검증하고 production controller의 모든 종료는 단일 `finish` 경로로 수렴한다.

이 한계는 현재 완료 조건을 막는 별도 제품 결함이 아니다. 실제 print panel 통합 테스트는 OS UI·printer 환경 의존성과 유지 비용에 비해 lifecycle identity 검증을 추가로 강화하는 폭이 작아 별도 후속 이슈로 분리하지 않는다. 실제 취소·실패 회귀가 관측되거나 print operation을 주입 가능한 구조로 바꾸는 작업이 생길 때 재평가한다.

## Issue #459 완료 조건 대조

| 완료 조건 | 구현·검증 근거 | 판정 |
|-----------|----------------|------|
| 인쇄 중 두 번째 요청이 기존 controller를 교체하지 않고 명시적으로 거부됨 | `RhwpStudioPrintLifecycle.start`가 active 검사 뒤에만 factory를 호출하고 `.printingInProgress`를 반환한다. `testDuplicateRequestKeepsActiveControllerAndReportsErrorWithoutCreatingAnother`가 factory 추가 호출 0회와 오류 1회를 검증한다. | 충족 |
| 이전 render/navigation 세대 callback이 현재 page나 completion을 변경하지 않음 | Generation/page/navigation token gate와 `testRenderLifecycleRejectsStaleTokenAcrossRenderGenerations`, `testRendererReentersAfterCurrentNavigationFailureAndIgnoresRepeatedFailure`, `testRendererIgnoresStaleCreatePDFResultWhileProcessTerminationRetryIsActive`가 state·completion 불변을 검증한다. | 충족 |
| 실패·취소·정상 완료 뒤 다음 인쇄와 PDF render가 정상 진입함 | `testCompletionAllowsNextRequestForEveryControllerOutcome`, `testCompletionCallStackAllowsImmediateNextRequestAndKeepsItsIdentity`와 renderer의 정상·navigation·font·encoding·timeout·process 종료 재사용 회귀가 다음 요청 수락과 exactly-once completion을 검증한다. | 충족 |
| 관련 HostAppTests와 HostApp Debug build 통과 | 전체 HostAppTests 178/178, 실패·skip 0. HostApp Debug unsigned build 성공. | 충족 |
| `project.yml`로 Xcode project 재생성 후 추가 diff 없음 | XcodeGen 2회 결과 SHA-1이 모두 `192e1cd7c42b3a80213fbdf7f3b8ab396a738ef0`이고 두 번째 생성 뒤 project diff가 없다. | 충족 |

Issue 범위의 native PDF menu `aria-label` observer 보완은 Stage 1에서 적용했다. `testNativePDFMenuOverrideIsReappliedAfterAttributeChanges`와 관련 Host bridge source 계약 테스트가 `class`, `aria-disabled`, `title`, `aria-label` filter와 canonical 복원을 검증한다.

## 최종 검증 결과

| 검증 | 결과 |
|------|------|
| 전체 `HostAppTests` | 178/178 통과, 실패·skip 0 |
| HostApp Debug unsigned build | 성공 |
| `xcodegen generate` 2회 | 성공, 같은 project SHA-1, 두 번째 추가 diff 없음 |
| Xcode project SHA-1 | `192e1cd7c42b3a80213fbdf7f3b8ab396a738ef0` |
| 신규 source membership | `project.yml`과 generated project의 `RhwpStudioPrintLifecycle.swift` production/test source 포함 일치 |
| `./scripts/check-no-appkit.sh` | 통과 |
| `./scripts/verify-rhwp-studio-assets.sh` | 통과 |
| `./scripts/check-extension-registration-hygiene.sh` | issue 0, development registration 0 |
| `git diff --check` | 통과 |

전체 test 결과 bundle:

- `build.noindex/task459-stage4-tests/Logs/Test/Test-HostAppTests-2026.08.26_18-02-23-+0900.xcresult`

최초 sandbox 실행은 `github.com` DNS와 CoreSimulator/Xcode service 접근 제한으로 Sparkle package graph 해석 전에 중단됐다. 같은 test/build 명령을 정상 macOS 권한에서 다시 실행했고 각각 `TEST SUCCEEDED`, `BUILD SUCCEEDED`로 완료했다. 이는 source, test 또는 dependency version 실패가 아니다.

## 변경 범위 정합성

Task #459 전체 변경은 다음 범위에 한정됐다.

- `Sources/HostApp/Services`, `Sources/HostApp/Views`
- `Tests/HostAppTests`
- `project.yml`과 XcodeGen generated project
- `mydocs/orders`, `mydocs/plans`, `mydocs/working`, `mydocs/tech`

`Sources/RhwpCoreBridge`, `Sources/Shared`, `Sources/QLExtension`, `Sources/ThumbnailExtension`, `Frameworks/Rhwp.xcframework`, `rhwp-core.lock`과 bundled `rhwp-studio` asset에는 diff가 없다. Build/test 산출물은 ignored `build.noindex/task459-stage4-*` 아래에 생성됐고 development extension registration은 남지 않았다.

## 본문 변경 정도 / 본문 무손실 여부

- Stage 4는 문서만 변경했으며 PDF·인쇄 production 동작과 test fixture를 변경하지 않았다.
- Task 전체에서도 HWP/HWPX bytes, page SVG payload, font binary, CSP, PDF page geometry와 원본 저장 경로를 변경하지 않았다.
- 실제 printer spool, 사용자 문서, release·서명·공증과 Quick Look/Thumbnail 등록을 수행하지 않았다.

## 잔여 위험

- `WKNavigationAction`과 WebContent process 종료 callback에 generation identity가 없는 WebKit API 한계는 유지된다. Current pending state와 owned WebView/token gate보다 넓은 fallback은 두지 않았다.
- 실제 `NSPrintOperation` panel의 OS별 사용자 취소·printer failure UI는 자동화하지 않았다. 현재는 lifecycle fake와 production controller 단일 `finish` 수렴 계약으로 경계를 검증한다.
- Renderer generation은 `UInt64` 단조 증가이며 현실적인 app session에서 overflow하지 않는다. 별도 persistence나 외부 노출은 없다.

## 다음 단계 영향

Stage 4까지 구현·문서·검증은 완료됐다. 다음 단계는 작업지시자가 `task-final-report`를 명시 호출한 뒤에만 최종 보고서 작성, 오늘할일 완료 처리, 최종 커밋, `publish/task459` push와 `devel` 대상 PR 생성을 진행한다. Issue #459는 PR merge 전까지 열린 상태로 유지한다.

## 승인 요청

Architecture 계약, Issue 완료 조건별 근거, 전체 178개 test·HostApp Debug build와 변경 범위 정합성을 검토하고 Task #459 최종 보고·PR 게시 단계 진입 승인을 요청한다.
