# Task M019 #235 Stage 2 완료 보고서

## 단계 목적

문서 표시 이후 bundled `rhwp-studio` runtime에서 발생하는 `렌더링 오류: 컨트롤 인덱스 0 범위 초과` 오류를 fatal fallback이 아닌 non-blocking banner로 분류한다.

이번 단계는 HostApp의 recoverable runtime 판별만 좁게 확장했다. upstream `rhwp` #850 원인 수정은 범위에 포함하지 않았다.

## 산출물

| 파일 | 요약 |
|------|------|
| `Sources/HostApp/Views/RhwpStudioWebView.swift` | recoverable runtime 메시지를 allow-list로 정리하고 `컨트롤 인덱스 0 범위 초과`를 추가 |
| `mydocs/orders/20260513.md` | Stage 2 완료 후 Stage 3 승인 대기 상태 반영 |
| `mydocs/working/task_m019_235_stage2.md` | 본 Stage 2 구현/검증 보고서 |

참조했으나 변경하지 않은 파일:

| 파일 | 확인 내용 |
|------|----------|
| `Sources/HostApp/Services/RhwpStudioResourceLocator.swift` | nonfatal runtime 사용자 문구 `입력을 처리하지 못했습니다. 문서는 계속 볼 수 있습니다.`를 그대로 재사용 |

## 구현 내용

`RhwpStudioWebView.Coordinator`의 invalid-control 전용 recoverable helper를 post-load runtime helper로 일반화했다.

유지한 조건:

1. 현재 문서가 존재한다.
2. WebView load가 완료된 뒤 발생했다.
3. `sourceURL` 또는 `index.html` stack이 bundled `/assets/index-*.js` line `1`을 가리킨다.
4. 메시지가 확인된 recoverable runtime allow-list에 포함된다.

allow-list에는 기존 #223 문구와 #235 문구만 포함했다.

```text
지정된 컨트롤이 표, 글상자 또는 그림이 아닙니다
컨트롤 인덱스 0 범위 초과
```

Stage 1 재현에서 asset hash와 column이 Issue 본문과 달랐으므로, `column` 값은 recoverable 판정 조건으로 사용하지 않았다.

## 본문 변경 정도 / 본문 무손실 여부

- 제품 소스 변경은 `Sources/HostApp/Views/RhwpStudioWebView.swift` 한 파일에 한정했다.
- `RhwpStudioResourceLocator.swift`의 사용자-facing 문구와 failure factory는 변경하지 않았다.
- `project.yml`, `Alhangeul.xcodeproj`, 샘플 문서, bundled viewer asset은 변경하지 않았다.
- 기존 #223 invalid-control recoverable 문구와 bundled source 조건은 유지했다.

## 검증 결과

### Debug build

첫 실행:

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask235Stage2 \
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
** BUILD SUCCEEDED ** [11.229 sec]
```

### Recoverable 정책 확인

```bash
rg -n "컨트롤 인덱스|지정된 컨트롤|recoverable|isFatal|runtime" \
  Sources/HostApp/Views/RhwpStudioWebView.swift \
  Sources/HostApp/Services/RhwpStudioResourceLocator.swift
```

확인 결과:

- `recoverableRuntimeMessages`에 기존 #223 문구와 새 #235 문구가 함께 존재한다.
- `handleRuntimeError(_:)`는 `isRecoverablePostLoadRuntimeError(...)` 결과를 기준으로 `isFatal`을 결정한다.
- `RhwpStudioResourceLocator.swift`의 nonfatal runtime banner 문구는 유지됐다.

### 수동 smoke

실행 앱:

```text
build.noindex/DerivedDataTask235Stage2/Build/Products/Debug/Alhangeul.app
```

절차:

1. Stage 2 Debug app을 새로 실행했다.
2. 실행 중인 앱으로 `samples/exam_social.hwp` open event를 전달했다.
3. `exam_social.hwp — 4페이지`, `1 / 4 쪽` 표시를 확인했다.
4. 상단 `성명` 입력칸 내부를 선택했다.
5. `abc` 입력으로 Stage 1과 같은 control-index runtime 경로를 유도했다.

결과:

```text
입력을 처리하지 못했습니다. 문서는 계속 볼 수 있습니다.
```

위 banner가 상단에 표시됐고, 문서 화면은 `exam_social.hwp — 4페이지` 상태로 유지됐다. banner 자동 dismiss 이후에도 fatal fallback 화면으로 전환되지 않았다.

### #223 회귀 확인

수동으로 #223의 별도 입력 경로를 다시 재현하지는 않았다. 대신 이번 변경의 정적 범위를 확인했다.

- 기존 `지정된 컨트롤이 표, 글상자 또는 그림이 아닙니다` allow-list 문구는 삭제하지 않았다.
- 기존 bundled `/assets/index-*.js` line `1` source gate는 유지했다.
- fatal/nonfatal routing factory는 변경하지 않았다.

## Fatal 유지 대상

Stage 2 이후에도 다음은 fatal fallback으로 유지된다.

- `resourcePreflight`
- `resourceScheme`
- `documentScheme`
- `navigation`
- `processTerminated`
- `timeout`
- current document가 없거나 WebView load 완료 전 발생한 runtime error
- bundled `rhwp-studio` asset source가 아닌 runtime error
- allow-list에 없는 runtime error 메시지

## 잔여 위험

- upstream `rhwp` #850 원인은 그대로 남아 있으며, 본 단계는 HostApp UX 완화에 한정한다.
- recoverable 메시지는 확인된 두 문자열만 allow-list에 둔다. 같은 upstream 결함의 다른 문구가 나오면 별도 이슈로 추가 판단이 필요하다.
- 반복 입력 시 banner dismiss timer가 계속 reset되는 문제는 Stage 3 범위로 남겼다.
- #223 invalid-control 경로는 정적으로 유지 확인했지만, 별도 수동 smoke는 Stage 4 통합 회귀에서 다시 확인한다.

## 다음 단계 영향

Stage 3에서는 nonfatal runtime banner dedupe를 구현한다. 같은 runtime diagnostic이 짧은 시간 안에 반복될 때 banner가 계속 reset되지 않도록 `DocumentViewerStore`의 nonfatal failure 처리 경로를 조정한다.

## 승인 요청

Stage 2 결과를 승인하면 Stage 3 `nonfatal runtime banner dedupe 구현`으로 진행한다.
