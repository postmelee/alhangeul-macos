# Task M019 #223 Stage 2 완료 보고서

## 단계 목적

이미 존재하는 `RhwpStudioWebViewFailure.isFatal` 값을 HostApp UI 라우팅에 반영해, nonfatal WebView failure가 전체 fallback 화면으로 전환되지 않도록 했다. 이번 단계는 라우팅 기반만 마련했고, 실제 Space 입력 예외를 nonfatal로 분류하는 작업은 Stage 3 범위로 남겼다.

## 변경 내용

### Store failure 라우팅

`DocumentViewerStore.setWebViewFailure(_:)`에서 `failure.isFatal`을 분기한다.

| 케이스 | 처리 |
|--------|------|
| `failure == nil` | `webViewFailure`만 비움 |
| `failure.isFatal == true` | 기존처럼 `webViewFailure`에 저장하고 `webViewErrorMessage`를 비워 fallback 화면 표시 |
| `failure.isFatal == false` | `webViewFailure`를 비우고 `webViewErrorMessage`에 짧은 문구를 저장해 문서 화면과 banner 유지 |

fatal/nonfatal 공통으로 `isWebViewLoading`은 `false`로 정리한다. 따라서 nonfatal failure 이후에도 `canRunWebViewCommands`는 `webViewFailure == nil` 조건을 만족한다.

### Runtime failure factory 확장

`RhwpStudioWebViewFailure.runtime(...)`에 `isFatal: Bool = true` 인자를 추가했다.

- 기존 호출부는 기본값 `true`를 사용하므로 현재 runtime error의 fallback 동작은 유지된다.
- Stage 3에서 좁게 분류한 post-load 입력 예외는 같은 factory에 `isFatal: false`를 넘길 수 있다.
- nonfatal runtime failure의 banner 문구는 `입력을 처리하지 못했습니다. 문서는 계속 볼 수 있습니다.`로 둔다.
- diagnostic detail은 기존처럼 `message`, `sourceURL`, `line`, `column`, `reason`을 보존한다.

## 변경 파일

| 파일 | 변경 |
|------|------|
| `Sources/HostApp/Stores/DocumentViewerStore.swift` | fatal/nonfatal failure 라우팅 분기 |
| `Sources/HostApp/Services/RhwpStudioResourceLocator.swift` | `runtime(...)` factory의 `isFatal` 인자와 nonfatal 문구 추가 |
| `mydocs/orders/20260511.md` | 오늘할일 상태를 Stage 2 완료보고서 승인 대기로 갱신 |
| `mydocs/working/task_m019_223_stage2.md` | Stage 2 완료 보고서 추가 |

## 유지한 동작

- resource preflight, resource scheme, document scheme, document load, navigation, process termination, timeout failure는 여전히 fatal fallback으로 간다.
- 기존 `handleRuntimeError(_:)` 호출은 아직 `isFatal` 인자를 넘기지 않으므로 Stage 2만으로는 사용자 제보 runtime error가 완화되지 않는다.
- fallback view 레이아웃과 버튼 동작은 변경하지 않았다.
- bundled `rhwp-studio` JS/WASM asset은 변경하지 않았다.

## 검증 결과

```bash
git diff --check -- Sources/HostApp/Stores/DocumentViewerStore.swift Sources/HostApp/Services/RhwpStudioResourceLocator.swift
```

결과: 출력 없음, exit code 0.

```bash
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
```

결과: `** BUILD SUCCEEDED **`.

빌드 중 AppIntents metadata extraction warning이 출력되었지만, `No AppIntents.framework dependency found` 경고로 이번 변경과 무관하며 빌드 결과는 성공이다.

## 잔여 위험

- Stage 2는 nonfatal failure를 표시할 통로만 만든다. 실제 제보 오류는 Stage 3에서 post-load 입력 예외 조건을 좁게 판별해 `isFatal: false`로 전달해야 완화된다.
- nonfatal banner 문구는 짧게 유지했지만, Stage 3 수동 smoke에서 실제 화면 위계와 중복 표시 여부를 확인해야 한다.
- `setWebViewFailure(nil)`은 기존 호출 흐름에서 거의 쓰이지 않지만, 이번 변경은 명시적으로 `webViewFailure`만 비우고 기존 banner 메시지는 건드리지 않게 했다.

## 다음 단계

Stage 2 결과를 승인하면 Stage 3에서 `handleRuntimeError(_:)`에 post-load 입력 예외 분류를 추가한다. 조건은 Stage 1에서 확인한 오류 문구와 bundled viewer source URL을 기준으로 좁게 제한한다.

## 승인 요청

Stage 2 산출물 승인을 요청한다.

승인 후 Stage 3 `post-load 입력 예외 분류 보강`으로 진행한다.
