# Task M019 #235 Stage 3 완료 보고서

## 단계 목적

같은 nonfatal runtime 오류가 짧은 시간 안에 반복될 때 banner가 계속 새로 표시되거나 자동 dismiss timer가 reset되는 문제를 줄인다.

이번 단계는 `DocumentViewerStore`의 nonfatal runtime failure 처리에만 dedupe key를 적용했다. 일반 사용자 명령 오류와 fatal fallback 경로는 dedupe하지 않는다.

## 산출물

| 파일 | 요약 |
|------|------|
| `Sources/HostApp/Stores/DocumentViewerStore.swift` | nonfatal runtime failure 전용 dedupe key와 중복 표시 skip 처리 추가 |
| `mydocs/orders/20260513.md` | Stage 3 완료 후 Stage 4 승인 대기 상태 반영 |
| `mydocs/working/task_m019_235_stage3.md` | 본 Stage 3 구현/검증 보고서 |

참조했으나 변경하지 않은 파일:

| 파일 | 확인 내용 |
|------|----------|
| `Sources/HostApp/Views/DocumentViewerView.swift` | banner dismiss 호출은 기존 `dismissWebViewError()` 경로를 그대로 사용 |

## 구현 내용

`DocumentViewerStore`에 현재 표시 중인 runtime banner의 dedupe key를 저장하는 `webViewErrorDedupeKey`를 추가했다.

nonfatal runtime failure는 다음 값으로 key를 만든다.

```text
{category.rawValue}
{diagnosticDetail}
```

동작 규칙:

1. `failure.isFatal == false`이고 `failure.category == .runtime`일 때만 dedupe key를 만든다.
2. 같은 key의 banner가 이미 표시 중이면 `presentWebViewError`가 즉시 return한다.
3. 이 경우 기존 banner와 기존 자동 dismiss task를 유지한다.
4. 다른 key이거나 일반 `setWebViewError` 경로이면 기존처럼 새 banner를 표시하고 dismiss timer를 새로 시작한다.
5. 자동 dismiss와 사용자 dismiss는 `webViewErrorDedupeKey`를 함께 지운다.
6. fatal failure 전환, 새 문서 load, reload/retry는 기존 `dismissWebViewError()` 호출을 통해 dedupe 상태도 함께 지운다.

## 본문 변경 정도 / 본문 무손실 여부

- 제품 소스 변경은 `Sources/HostApp/Stores/DocumentViewerStore.swift` 한 파일에 한정했다.
- SwiftUI view 구조, banner UI, fallback UI는 변경하지 않았다.
- `RhwpStudioWebView.swift`의 Stage 2 recoverable 분류는 변경하지 않았다.
- `project.yml`, `Alhangeul.xcodeproj`, 샘플 문서, bundled viewer asset은 변경하지 않았다.

## 검증 결과

### Diff check

```bash
git diff --check -- \
  Sources/HostApp/Stores/DocumentViewerStore.swift \
  Sources/HostApp/Views/DocumentViewerView.swift
```

결과: 통과.

### Debug build

첫 실행:

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask235Stage3 \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과: sandbox network 제한으로 Sparkle dependency resolve가 실패했다.

```text
Failed to clone repository https://github.com/sparkle-project/Sparkle
fatal: unable to access 'https://github.com/sparkle-project/Sparkle/': Could not resolve host: github.com
```

승인된 network 재실행 결과:

```text
** BUILD SUCCEEDED ** [10.486 sec]
```

### 정적 확인

```bash
rg -n "dedupe|Dedupe|diagnosticDetail|webViewError|dismiss|isFatal" \
  Sources/HostApp/Stores/DocumentViewerStore.swift \
  Sources/HostApp/Views/DocumentViewerView.swift
```

확인 결과:

- `webViewErrorDedupeKey`가 `DocumentViewerStore` 내부 상태로 추가됐다.
- nonfatal runtime failure만 `nonfatalRuntimeDedupeKey(for:)`를 통해 key를 전달한다.
- `setWebViewError(_:)` 일반 경로는 dedupe key 없이 `presentWebViewError`를 호출한다.
- `dismissWebViewError()`와 자동 dismiss completion은 dedupe key를 함께 정리한다.

### 수동 smoke

실행 앱:

```text
build.noindex/DerivedDataTask235Stage3/Build/Products/Debug/Alhangeul.app
```

절차와 결과:

1. Stage 3 Debug app을 새로 실행했다.
2. 실행 중인 앱으로 `samples/exam_social.hwp` open event를 전달했다.
3. `exam_social.hwp — 4페이지`, `1 / 4 쪽` 표시를 확인했다.
4. 상단 `성명` 입력칸 내부를 선택했다.
5. `a` 입력으로 nonfatal runtime banner를 표시했다.
6. banner 표시 약 3초 뒤 `b`를 입력해 같은 runtime 오류를 다시 유도했다.
7. 첫 표시 기준 약 5초 뒤 banner가 사라지는 것을 확인했다. 두 번째 동일 오류가 dismiss timer를 reset하지 않았다.
8. 자동 dismiss 이후 `c` 입력으로 같은 오류 banner가 다시 표시되는 것을 확인했다.
9. banner의 닫기 버튼을 눌러 수동 dismiss했다.
10. 입력칸을 다시 선택하고 `f` 입력으로 같은 오류 banner가 다시 표시되는 것을 확인했다.

모든 과정에서 문서 화면은 유지됐고 fatal fallback 화면으로 전환되지 않았다.

### 일반 WebView error 경로

공유/PDF 버튼의 외부 UI를 열지는 않았다. 대신 코드 경로를 확인했다.

- `setWebViewError(_:)`는 `presentWebViewError(message)`를 dedupe key 없이 호출한다.
- 따라서 사용자 명령 오류, 파일 동작 오류 같은 일반 banner는 이번 dedupe 대상이 아니다.

## Fatal 유지 대상

Stage 3 이후에도 다음은 dedupe와 무관하게 기존 fatal fallback으로 유지된다.

- `resourcePreflight`
- `resourceScheme`
- `documentScheme`
- `documentLoad`
- `navigation`
- `processTerminated`
- `timeout`
- fatal runtime failure

## 잔여 위험

- dedupe key는 현재 `category + diagnosticDetail` 전체 문자열이다. 같은 원인이라도 asset hash나 column이 달라진 별도 diagnostic은 다른 오류로 취급된다.
- 일반 WebView error 경로는 정적으로만 확인했다. 실제 공유/PDF UI 경로는 Stage 4 통합 회귀에서 필요 시 확인한다.
- upstream `rhwp` #850 원인은 그대로 남아 있다.

## 다음 단계 영향

Stage 4에서는 통합 build와 fatal fallback 회귀 smoke를 수행한다. 특히 resource/document/load 계열 fatal fallback이 Stage 2/3 변경으로 완화되지 않았는지 확인한다.

## 승인 요청

Stage 3 결과를 승인하면 Stage 4 `통합 build와 fatal fallback 회귀 smoke`로 진행한다.
