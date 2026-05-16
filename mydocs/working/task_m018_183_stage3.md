# Task M018 #183 Stage 3 완료 보고서

## 단계 목적

Stage 2에서 확정한 수정안에 따라 창 확대/resize 중 발생하는 browser-level ResizeObserver loop notification이 fatal runtime fallback으로 승격되지 않도록 최소 수정했다.

제품 코드 변경은 `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift` 한 파일로 제한했다. bundled `rhwp-studio` minified asset, `RhwpStudioWebView` state transition, `DocumentViewerStore`는 수정하지 않았다.

## 산출물

| 파일 | 내용 |
|------|------|
| `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift` | runtime benign filter에 ResizeObserver loop notification narrow guard 추가 |
| `mydocs/working/task_m018_183_stage3.md` | Stage 3 변경 내용과 검증 결과 |
| `mydocs/orders/20260509.md` | #183 상태를 Stage 3 완료 및 Stage 4 승인 대기로 갱신 |

## 변경 내용

`RhwpStudioHostBridgeScript.runtimeErrorSource`에 `isResizeObserverLoopNotification` helper를 추가했다.

benign 처리 대상은 다음 두 browser notification message로 제한했다.

```text
ResizeObserver loop completed with undelivered notifications.
ResizeObserver loop limit exceeded
```

추가 조건:

- `reason`이 비어 있어야 한다.
- `line`이 `0`이어야 한다.
- `column`이 `0`이어야 한다.

`window.error` handler는 `event.lineno`, `event.colno`를 먼저 `line`, `column`으로 고정한 뒤 benign filter에 전달하도록 변경했다. native로 전달하는 payload도 같은 값을 사용한다.

기존 `registerSW.js` benign rule은 유지했다. `unhandledrejection` 경로도 같은 helper를 호출하지만, promise rejection의 `reason`이 있으면 ResizeObserver benign 조건을 통과하지 않는다. 따라서 실제 JavaScript/WASM exception, stack이 있는 error, source line이 있는 error는 계속 `runtime-error`로 전달된다.

## 제외한 대안

| 대안 | 제외 이유 |
|------|----------|
| bundled `assets/index-BN69C-Lp.js` 직접 수정 | minified asset provenance가 흐려지고, upstream `rhwp-studio` 재반입 흐름과 충돌할 수 있음 |
| `handleRuntimeError`를 nonfatal 처리 | #150에서 도입한 실제 runtime failure 감지를 약화함 |
| 모든 ResizeObserver 관련 message 무시 | 실제 exception을 숨길 수 있어 observed browser notification의 exact message와 0:0 위치 조건으로 제한 |

## 사용자 영향

창 확대 과정에서 WebKit이 보고하는 ResizeObserver loop notification만 무시한다. 문서 viewer 자체가 실제 JavaScript/WASM exception을 발생시키는 경우에는 기존처럼 fallback이 표시된다.

Stage 4에서 `KTX.hwp`, `hwpx-01.hwpx`로 창 확대/원복/수동 resize smoke를 수행해 사용자 동작 기준 결과를 확인한다.

## 본문 변경 정도 / 본문 무손실 여부

- 제품 코드 변경은 `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift`의 runtime bridge filter 보강으로 제한했다.
- `Sources/RhwpCoreBridge` 변경 없음.
- `project.yml` 및 `Alhangeul.xcodeproj` 변경 없음.
- bundled `rhwp-studio` resource 변경 없음.
- 기존 문서 본문 삭제 없음.
- `mydocs/orders/20260509.md`는 #183 비고만 Stage 3 완료 상태로 갱신한다.

## 검증 결과

```bash
git status --short --branch
```

변경 직후 결과:

```text
## local/task183
 M Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift
```

```bash
scripts/verify-rhwp-studio-assets.sh
```

결과:

```text
OK: rhwp-studio assets verified at /Users/melee/Documents/projects/rhwp-mac/Sources/HostApp/Resources/rhwp-studio
```

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  build
```

결과:

```text
** BUILD SUCCEEDED ** [2.386 sec]
```

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과:

```text
** BUILD SUCCEEDED ** [1.386 sec]
```

```bash
git diff --check
```

결과: 출력 없음. 공백 오류 없음.

## 특이 사항

Xcode/SwiftPM cache 쓰기 권한 때문에 build 검증은 sandbox 밖에서 실행했다. 같은 문제는 Stage 1에서도 발생했던 환경 제약이며, 제품 코드 변경과는 무관하다.

작업 중 외부 checkout으로 현재 브랜치가 `main`으로 바뀐 것을 감지했다. 제품 코드 변경은 커밋 전 `local/task183`로 다시 전환한 뒤 재적용했고, 최종 검증도 `local/task183`에서 수행했다.

## 다음 단계

Stage 4에서는 Debug build 산출물로 HWP/HWPX 문서 창 확대/원복/수동 resize smoke를 수행한다. 핵심 확인 대상은 `KTX.hwp`에서 fatal fallback이 더 이상 표시되지 않는지와, HWPX 정상 경로가 회귀하지 않았는지다.
