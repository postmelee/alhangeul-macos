# Task M019 #223 Stage 3 완료 보고서

## 단계 목적

문서 표시가 끝난 뒤 발생하는 `지정된 컨트롤이 표, 글상자 또는 그림이 아닙니다` runtime error만 좁게 recoverable로 분류했다. load/resource/document 계열 failure와 일반 runtime error는 계속 fatal fallback으로 둔다.

## 변경 내용

### post-load 상태 추적

`RhwpStudioWebView.Coordinator`에 `hasCompletedCurrentLoad` 상태를 추가했다.

| 이벤트 | 상태 처리 |
|--------|----------|
| 새 viewer URL load 시작 | `false` |
| `webView(_:didFinish:)` | `true` |
| resource preflight/navigation failure | `false` |
| WebContent process termination | `false` |
| blocked navigation | `false` |
| timeout | `false` |
| document-load-error | `false` |

이 상태는 runtime error가 문서 표시 이후 사용자 입력 중 발생했는지 구분하는 기준으로만 사용한다.

### recoverable runtime error 분류

`handleRuntimeError(_:)`에서 bridge payload를 먼저 추출하고, 다음 조건을 모두 만족할 때만 `isFatal: false`로 전달한다.

1. 현재 문서 payload가 있다.
2. 현재 load가 `didFinish`까지 완료됐다.
3. `message` 또는 `reason`에 `지정된 컨트롤이 표, 글상자 또는 그림이 아닙니다`가 포함된다.
4. source가 bundled viewer runtime 위치로 확인된다.
   - `alhangeul-studio://app/assets/index-*.js`
   - `line == 1`
   - `column == 30942`
5. unhandled rejection처럼 source가 `index.html`인 경우에는 `reason` stack에 `/assets/index-`와 `:1:30942`가 모두 있어야 한다.

위 조건을 만족하지 않는 runtime error는 기존처럼 `isFatal: true`로 전달된다.

### Stage 2 라우팅과 연결

Stage 2에서 추가한 `RhwpStudioWebViewFailure.runtime(..., isFatal:)` 인자를 사용한다. recoverable로 분류된 경우 `DocumentViewerStore`가 `webViewFailure`를 비우고 `webViewErrorMessage` banner만 표시하므로, 전체 fallback view로 전환되지 않는다.

## 변경 파일

| 파일 | 변경 |
|------|------|
| `Sources/HostApp/Views/RhwpStudioWebView.swift` | post-load 상태와 recoverable runtime error 분류 추가 |
| `mydocs/orders/20260511.md` | 오늘할일 상태를 Stage 3 완료보고서 승인 대기로 갱신 |
| `mydocs/working/task_m019_223_stage3.md` | Stage 3 완료 보고서 추가 |

## 유지한 동작

- `resourcePreflight`, `resourceScheme`, `documentScheme`, `documentLoad`, `navigation`, `processTerminated`, `timeout`은 계속 fatal fallback이다.
- load가 끝나기 전 발생한 같은 문구의 runtime error도 fatal이다.
- 같은 문구라도 source URL, line, column이 Stage 1에서 확인한 bundled JS 위치와 맞지 않으면 fatal이다.
- bundled `rhwp-studio` JS/WASM asset은 변경하지 않았다.

## 검증 결과

```bash
git diff --check -- Sources/HostApp/Views/RhwpStudioWebView.swift
```

결과: 출력 없음, exit code 0.

```bash
./scripts/build-rust-macos.sh
```

결과: 성공. 임시 worktree에 `Frameworks/Rhwp.xcframework` 생성.

```bash
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedDataStage3 CODE_SIGNING_ALLOWED=NO build
```

결과: `** BUILD SUCCEEDED **`.

빌드 전 확인 사항:

- 임시 worktree에는 ignored 산출물인 `Frameworks/Rhwp.xcframework`가 없어 최초 빌드가 실패했다.
- 최초 `DerivedData` 경로는 missing framework 상태를 build description에 유지해, `DerivedDataStage3` fresh 경로로 재빌드했다.
- AppIntents metadata extraction warning은 기존과 같은 `No AppIntents.framework dependency found` 경고이며 빌드 성공에는 영향이 없다.

```bash
scripts/verify-rhwp-studio-assets.sh
scripts/verify-rhwp-studio-assets.sh build.noindex/DerivedDataStage3/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
```

결과: 둘 다 성공.

## 수동 smoke 결과

다음 절차를 시도했다.

```bash
/usr/bin/open -n -F -a /private/tmp/rhwp-mac-task223/build.noindex/DerivedDataStage3/Build/Products/Debug/Alhangeul.app /private/tmp/rhwp-mac-task223/samples/exam_science.hwp
```

하지만 Computer Use의 `get_app_state`가 `cgWindowNotFound`를 반환했고, System Events 기준으로도 Alhangeul 프로세스의 window count가 `0`이었다. 같은 bundle identifier의 기존 Alhangeul 프로세스를 종료한 뒤 fresh launch를 반복했지만, Debug 앱 프로세스만 뜨고 조작 가능한 창이 생성되지 않았다.

따라서 Stage 3의 수동 UI smoke는 이 세션에서 완료하지 못했다. 구현 조건은 Stage 1에서 확보한 payload와 source 위치에 맞춰 적용했고, 실제 화면에서 fallback이 banner로 바뀌는지 여부는 Stage 4 또는 작업지시자 로컬 재현으로 다시 확인해야 한다.

## 잔여 위험

- 수동 UI smoke가 완료되지 않았으므로, 실제 사용자 입력 경로에서 `sourceURL=line=column` payload가 동일하게 전달되는지는 Stage 4에서 다시 확인해야 한다.
- 현재 분류는 bundled `index-*.js`의 line 1, column 30942에 고정되어 있다. rhwp-studio asset을 업데이트하면 column이 바뀔 수 있으므로 해당 업데이트 작업에서는 조건을 재검토해야 한다.
- HostApp은 fallback 전환만 완화한다. upstream `rhwp-studio` cursor/input 상태 오류 자체는 이번 단계에서 수정하지 않았다.

## 다음 단계

Stage 3 결과를 승인하면 Stage 4에서 fatal fallback 회귀와 negative smoke를 확인한다. 이때 Debug 앱 창 실행 문제를 먼저 정리하고, Stage 1 재현 동작이 전체 fallback으로 전환되지 않는지도 다시 확인한다.

## 승인 요청

Stage 3 산출물 승인을 요청한다.

승인 후 Stage 4 `fatal fallback 회귀와 negative smoke 확인`으로 진행한다.
