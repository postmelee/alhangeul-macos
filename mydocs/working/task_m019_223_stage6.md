# Task M019 #223 Stage 6 완료 보고서

## 단계 목적

Stage 5 변경본에서 Space 입력은 정상적으로 nonfatal banner로 처리됐지만, 같은 선택 상태에서 Enter 입력 시 전체 fallback 화면이 다시 표시됐다. 이번 단계에서는 같은 invalid-control runtime 오류가 입력 키마다 다른 WASM glue column에서 발생하더라도 HostApp이 전체 fallback으로 전환하지 않도록 recoverable 분류 조건을 보강했다.

## 추가 진단

작업지시자 직접 테스트에서 Enter 입력 후 다음 fallback 진단을 확인했다.

| 항목 | 값 |
|------|-----|
| message | `렌더링 오류: 지정된 컨트롤이 표, 글상자 또는 그림이 아닙니다` |
| sourceURL | `alhangeul-studio://app/assets/index-BN69C-Lp.js` |
| line | `1` |
| column | `45271` |
| reason | `렌더링 오류: 지정된 컨트롤이 표, 글상자 또는 그림이 아닙니다` |

Stage 3의 Space 입력 진단은 같은 문구와 같은 bundled JS였지만 `column=30942`였다. bundled JS 위치를 확인하면 `30942`는 `insertTextInCell` 계열, `45271`은 `splitParagraphInCell` 계열 WASM glue 주변이다. 둘 다 문서 표시 이후 stale control 상태에서 같은 core 오류가 올라온 입력 처리 예외로 볼 수 있다.

## 변경 내용

### column 고정 allow-list 제거

기존 조건은 다음처럼 Space 입력에서 확인한 column만 recoverable로 허용했다.

```text
sourceURL=alhangeul-studio://app/assets/index-*.js
line=1
column=30942
```

이번 단계에서는 column 숫자 의존성을 제거하고, 다음 조건을 유지했다.

1. 현재 문서 payload가 있다.
2. WebView load가 `didFinish`까지 완료된 post-load 상태다.
3. `message` 또는 `reason`에 `지정된 컨트롤이 표, 글상자 또는 그림이 아닙니다`가 포함된다.
4. source가 bundled viewer runtime이다.
   - `alhangeul-studio://app/assets/index-*.js`
   - `line == 1`
5. `index.html` unhandled rejection 형태는 `reason` stack이 bundled `index-*.js` line 1을 가리킬 때만 recoverable이다.

### 유지한 방어 조건

- 문서 표시 전 load 중 오류는 recoverable로 처리하지 않는다.
- source가 bundled `rhwp-studio` runtime이 아니면 recoverable로 처리하지 않는다.
- 오류 문구가 정확히 invalid-control 문구가 아니면 recoverable로 처리하지 않는다.
- resource, document load, navigation, process termination, timeout failure는 기존 fatal fallback 경로를 유지한다.

## 변경 파일

| 파일 | 변경 |
|------|------|
| `Sources/HostApp/Views/RhwpStudioWebView.swift` | invalid-control recoverable source 조건에서 column 고정값 제거 |
| `mydocs/plans/task_m019_223_impl.md` | Stage 6 Enter 보강 단계를 추가하고 최종 정리를 Stage 7로 조정 |
| `mydocs/orders/20260511.md` | 오늘할일 상태를 Stage 6 완료보고서 승인 대기로 갱신 |
| `mydocs/working/task_m019_223_stage6.md` | Stage 6 완료 보고서 추가 |

## 검증 결과

```bash
git diff --check -- Sources/HostApp/Views/RhwpStudioWebView.swift mydocs/plans/task_m019_223_impl.md
```

결과: 출력 없음, exit code 0.

```bash
scripts/verify-rhwp-studio-assets.sh
```

결과: 성공.

```bash
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedDataStage6 CODE_SIGNING_ALLOWED=NO build
```

결과: `** BUILD SUCCEEDED **`.

```bash
scripts/verify-rhwp-studio-assets.sh build.noindex/DerivedDataStage6/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
```

결과: 성공.

## 잔여 위험

- 이번 변경은 invalid-control 문구 전체를 무시하는 것이 아니라, post-load 상태의 bundled viewer runtime source로 제한한다. 그래도 같은 문구가 실제로 편집 불능 상태를 의미하는 다른 입력에서 발생하면 전체 fallback 대신 banner로 남는다.
- root cause는 upstream `rhwp-studio` 입력 상태와 core control routing 문제다. HostApp은 문서 보기 상태를 유지하도록 분류만 완화한다.
- Enter 경로의 최종 수동 smoke는 작업지시자 로컬 확인이 필요하다.

## 다음 단계

Stage 6 결과를 승인하면 Stage 7에서 최종 보고서와 PR 게시 준비를 진행한다.

## 승인 요청

Stage 6 산출물 승인을 요청한다.

승인 후 Stage 7 `최종 정리와 PR 준비`로 진행한다.
