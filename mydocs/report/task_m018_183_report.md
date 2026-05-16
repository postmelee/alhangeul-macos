# Task M018 #183 최종 결과 보고서

## 작업 요약

- 이슈: [#183](https://github.com/postmelee/alhangeul-macos/issues/183) `v0.1.0 설치본에서 창 확대 시 WebView runtime error 발생`
- 마일스톤: M018 / `v0.1.1`
- 통합 대상: `devel-webview`
- 작업 브랜치: `local/task183`
- 단계 수: Stage 1 재현/진단, Stage 2 원인 분리, Stage 3 최소 수정, Stage 4 smoke 검증, Stage 5 최종 보고

`v0.1.0` 설치본과 Debug build에서 `KTX.hwp` 창 확대 시 WebView runtime fallback이 표시되는 문제를 재현했고, 원인을 browser-level ResizeObserver loop notification이 host bridge에서 fatal `runtime-error`로 승격되는 경로로 분리했다. 수정은 `RhwpStudioHostBridgeScript.runtimeErrorSource`의 benign filter만 좁게 보강하는 방식으로 완료했다.

## 재현 결과

`/Applications/Alhangeul.app` `v0.1.0` 설치본에서 `samples/basic/KTX.hwp`를 연 뒤 window zoom secondary action을 실행하면 fatal fallback이 표시됐다.

fallback 진단 값:

```text
message=ResizeObserver loop completed with undelivered notifications.
sourceURL=alhangeul-studio://app/index.html?url=alhangeul-document://current?revision%3D1&filename=KTX.hwp
line=0
column=0
```

설치본 상태:

| 항목 | 값 |
|------|----|
| `CFBundleShortVersionString` | `0.1.0` |
| `CFBundleVersion` | `1` |
| TeamIdentifier | `XH6JHKYXV8` |
| `rhwp-studio` tag | `v0.7.10` |
| `rhwp-studio` resolved commit | `62a458aa317e962cd3d0eec6096728c172d57110` |

`samples/hwpx/hwpx-01.hwpx`는 같은 설치본에서 창 확대 fallback이 재현되지 않았다.

## 원인 범주

문제는 document route, bundled asset 누락, signing/notarization, WASM 초기화 실패가 아니었다.

확정한 경로:

```text
rhwp-studio ResizeObserver layout notification
-> window.error
-> RhwpStudioHostBridgeScript.runtimeErrorSource
-> postNative(type: "runtime-error")
-> RhwpStudioWebView.handleRuntimeError
-> fatal runtime fallback
```

`ResizeObserver loop completed with undelivered notifications.`는 unified log가 아니라 WebView page-level event로 들어왔다. viewer 문서 상태는 유지 가능한데 native bridge가 browser notification을 실제 JavaScript/WASM failure와 구분하지 못해 fallback으로 전환한 것이다.

## 변경 파일과 영향 범위

| 파일 | 내용 |
|------|------|
| `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift` | ResizeObserver loop notification 전용 benign filter 추가 |
| `mydocs/plans/task_m018_183.md` | 수행계획서 |
| `mydocs/plans/task_m018_183_impl.md` | 5단계 구현계획서 |
| `mydocs/working/task_m018_183_stage1.md` | 설치본/Debug 재현 진단 |
| `mydocs/working/task_m018_183_stage2.md` | 원인 경로 분리와 수정안 확정 |
| `mydocs/working/task_m018_183_stage3.md` | 최소 수정 구현 보고 |
| `mydocs/working/task_m018_183_stage4.md` | HWP/HWPX 창 확대 smoke 보고 |
| `mydocs/report/task_m018_183_report.md` | 최종 결과 보고 |
| `mydocs/orders/20260509.md` | #183 진행 상태 갱신 |

제품 코드 변경은 `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift` 한 파일이다. `Sources/RhwpCoreBridge`, `project.yml`, `Alhangeul.xcodeproj`, bundled `rhwp-studio` asset은 수정하지 않았다.

## 수정 내용

`isResizeObserverLoopNotification(message, reason, line, column)` helper를 추가하고, 다음 두 browser notification만 benign으로 처리했다.

```text
ResizeObserver loop completed with undelivered notifications.
ResizeObserver loop limit exceeded
```

추가 조건:

- `reason`이 비어 있어야 한다.
- `line == 0`
- `column == 0`

기존 `registerSW.js` benign rule은 유지했다. source line/column이 있는 JavaScript error, stack이 있는 `Error`, promise rejection의 `reason`은 계속 native `runtime-error`로 전달된다.

## 검증 결과

| 수용 기준 | 결과 | 근거 |
|-----------|------|------|
| `KTX.hwp` 창 확대 fallback 미표시 | OK | Debug build에서 window zoom, 원복, bottom-right resize 후 fallback 미표시 |
| `KTX.hwp` 상태 표시 유지 | OK | `KTX.hwp — 1페이지`, `1 / 1 쪽`, toolbar 활성 유지 |
| `hwpx-01.hwpx` 회귀 없음 | OK | window zoom, 원복, bottom-right resize 후 fallback 미표시 |
| source asset verifier | OK | `scripts/verify-rhwp-studio-assets.sh` 통과 |
| bundle asset verifier | OK | Debug app bundle resource verifier 통과 |
| Debug build | OK | `HostApp` signed Debug build 통과 |
| unsigned Debug build | OK | `CODE_SIGNING_ALLOWED=NO` build 통과 |
| whitespace check | OK | `git diff --check` 통과 |

실행한 주요 검증 명령:

```bash
scripts/verify-rhwp-studio-assets.sh
scripts/verify-rhwp-studio-assets.sh build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData build
git diff --check
```

수동 smoke:

```bash
/usr/bin/open -n -a /Users/melee/Documents/projects/rhwp-mac/build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app /Users/melee/Documents/projects/rhwp-mac/samples/basic/KTX.hwp
/usr/bin/open -a /Users/melee/Documents/projects/rhwp-mac/build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app /Users/melee/Documents/projects/rhwp-mac/samples/hwpx/hwpx-01.hwpx
```

## #188 release handoff

[#188](https://github.com/postmelee/alhangeul-macos/issues/188) `v0.1.1 patch release 준비와 public 배포 실행`에서 signed/notarized public DMG 설치본으로 다음 #183 전용 smoke를 반복해야 한다.

1. `v0.1.1` DMG를 설치하고 `/Applications/Alhangeul.app`의 `CFBundleShortVersionString`이 `0.1.1`, `CFBundleVersion`이 `2` 이상인지 확인한다.
2. `/Applications/Alhangeul.app`으로 `samples/basic/KTX.hwp`를 연다.
3. 초기 상태가 `KTX.hwp — 1페이지`, toolbar command 활성 상태인지 확인한다.
4. green zoom button 또는 window zoom secondary action으로 창을 확대한다.
5. 같은 동작으로 원복하고, bottom-right edge drag resize를 수행한다.
6. 모든 resize 후 `웹 viewer 실행 중 오류가 발생했습니다` fallback이 표시되지 않는지 확인한다.
7. `samples/hwpx/hwpx-01.hwpx`도 열어 창 확대/원복/resize 후 `hwpx-01.hwpx — 9페이지` 상태가 유지되는지 확인한다.
8. 만약 fallback이 재발하면 disclosure의 `message`, `sourceURL`, `line`, `column`, `reason`을 기록한다. `ResizeObserver loop completed with undelivered notifications.`가 다시 fatal fallback으로 보이면 #183 수정이 release artifact에 포함되지 않은 것으로 판단한다.

## 잔여 위험

- ResizeObserver loop notification은 WebKit, viewport 크기, 문서 layout, 장치 배율에 따라 발생 민감도가 다를 수 있다.
- 이번 수정은 browser-level notification만 무시한다. 실제 viewer exception이 별도 stack/source line을 가진 오류로 발생하면 기존처럼 fallback이 표시된다.
- 최종 배포 전 설치본 smoke는 Debug build smoke와 별도로 반드시 반복해야 한다.

## PR 게시 전 상태

- `local/task183`에는 Stage 1~5 산출물이 커밋 대상이다.
- GitHub에서 #183과 #188은 2026-05-09 19:19 기준 모두 `OPEN`, milestone `v0.1.1`로 확인했다.
- 최종 보고 승인 후 `publish/task183` 브랜치를 게시하고 `devel-webview` 대상으로 PR을 생성한다.

## 작업지시자 승인 요청

본 보고서 기준으로 Task #183의 구현과 검증을 완료했다. 승인 후 PR 게시 절차로 넘어간다.
