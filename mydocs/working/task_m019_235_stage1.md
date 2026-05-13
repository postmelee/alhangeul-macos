# Task M019 #235 Stage 1 완료 보고서

## 단계 목적

`samples/exam_social.hwp` 성명 필드 입력 중 발생하는 Web viewer runtime fatal fallback을 재현하고, #223 이후 HostApp의 현행 fatal/nonfatal 오류 정책을 Stage 2 구현 입력으로 고정한다.

이번 단계는 조사와 보고 단계이며 제품 소스는 변경하지 않았다.

## 산출물

| 파일 | 요약 |
|------|------|
| `mydocs/orders/20260513.md` | 2026-05-13 작업 이어받기와 Stage 2 승인 대기 상태 기록 |
| `mydocs/working/task_m019_235_stage1.md` | 본 Stage 1 재현/inventory 보고서 |

참조한 기존 파일:

| 파일 | 확인 내용 |
|------|----------|
| `Sources/HostApp/Views/RhwpStudioWebView.swift` | `handleRuntimeError(_:)`가 현재 invalid-control 문구만 recoverable로 분류 |
| `Sources/HostApp/Stores/DocumentViewerStore.swift` | `failure.isFatal == false`이면 전체 fallback 대신 banner 표시 |
| `Sources/HostApp/Views/DocumentViewerView.swift` | `WebViewerErrorBanner`가 상단 표시, 수동 닫기, 5초 자동 dismiss 경로 사용 |
| `Sources/HostApp/Resources/rhwp-studio/assets/index-BN69C-Lp.js` | 현재 bundled viewer main asset |

## 본문 변경 정도 / 본문 무손실 여부

- 제품 소스 변경 없음.
- 샘플 문서 파일 변경 없음.
- `mydocs/orders/20260512.md`의 과거 작업 기록은 변경하지 않고, 새 작업일인 `20260513.md`를 추가했다.
- 본 단계 보고서는 신규 문서이며 기존 계획서 본문을 변경하지 않았다.

## 현행 정책 Inventory

현행 `RhwpStudioWebView.Coordinator`의 recoverable runtime 분류는 다음 조건이다.

1. current document가 존재한다.
2. WebView load가 완료된 상태다.
3. `message` 또는 `reason`에 `지정된 컨트롤이 표, 글상자 또는 그림이 아닙니다`가 포함된다.
4. `sourceURL`이 bundled `rhwp-studio` `/assets/index-*.js`이고 line이 `1`이거나, `index.html` unhandled rejection stack이 같은 asset line을 가리킨다.

따라서 #235의 `렌더링 오류: 컨트롤 인덱스 0 범위 초과`는 current document와 bundled asset 조건을 만족해도 메시지 allow-list에 없어서 현재 fatal fallback으로 남는다.

`DocumentViewerStore.setWebViewFailure(_:)`는 이미 fatal/nonfatal 라우팅을 분리한다.

- fatal: `webViewFailure` 저장, banner dismiss, 전체 fallback 표시
- nonfatal: `webViewFailure = nil`, `webViewErrorMessage` banner 표시

Stage 2에서는 새로운 UI 통로를 만들기보다 `RhwpStudioWebView`의 recoverable 메시지 정책을 확장하는 것이 최소 수정이다.

## 재현 결과

### 실행 환경

- App: Debug `Alhangeul.app`
- Build output: `build.noindex/DerivedDataTask235/Build/Products/Debug/Alhangeul.app`
- Sample: `samples/exam_social.hwp`
- Viewer URL: `alhangeul-studio://app/index.html?url=alhangeul-document://current?revision%3D1&filename=exam_social.hwp`
- 표시 상태: `exam_social.hwp — 4페이지`, `1 / 4 쪽`
- Current asset: `Sources/HostApp/Resources/rhwp-studio/assets/index-BN69C-Lp.js`

### 수동 smoke 순서

1. Debug app을 실행했다.
2. `open /Users/melee/Documents/projects/rhwp-mac/samples/exam_social.hwp`로 실행 중인 앱에 문서 open event를 전달했다.
3. 첫 화면에 `exam_social.hwp — 4페이지`가 표시되는 것을 확인했다.
4. 상단 `성명` 입력칸 내부를 더블 클릭해 caret이 보이는 상태를 만들었다.
5. `abc` 입력으로 runtime fallback을 재현했다.
6. fallback 화면에서 진단 disclosure를 열어 payload를 확인했다.

참고: 처음 `open -n -a ... Alhangeul.app samples/exam_social.hwp` 형태로 앱을 띄웠을 때는 빈 viewer가 먼저 표시됐다. 이후 실행 중 앱에 sample file open event를 별도로 전달하자 문서가 정상 로드됐다.

### 재현 payload

```text
message=렌더링 오류: 컨트롤 인덱스 0 범위 초과
sourceURL=alhangeul-studio://app/assets/index-BN69C-Lp.js
line=1
column=30942
reason=렌더링 오류: 컨트롤 인덱스 0 범위 초과
```

Issue #235 본문에는 `index-CRsGAVvx.js`, `column=32679`가 기록되어 있으나, 현재 `devel-webview` bundled asset은 `index-BN69C-Lp.js`이고 재현 column은 `30942`였다. 같은 메시지와 같은 post-load bundled viewer runtime 오류이므로 Stage 2에서는 column 고정값을 조건으로 쓰지 않는다.

## 검증 결과

### Git 상태

```bash
git status --short --branch
```

결과: Stage 1 시작 전 `## local/task235`, 미커밋 변경 없음.

### Sample 존재 확인

```bash
ls -l samples/exam_social.hwp
```

결과:

```text
-rwxr-xr-x@ 1 melee  staff  536064 May  6 13:31 samples/exam_social.hwp
```

### Debug build

첫 실행:

```bash
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedDataTask235 CODE_SIGNING_ALLOWED=NO build
```

결과: sandbox network 제한으로 SwiftPM Sparkle dependency resolve 실패.

```text
Failed to clone repository https://github.com/sparkle-project/Sparkle
fatal: unable to access 'https://github.com/sparkle-project/Sparkle/': Could not resolve host: github.com
```

승인된 network 재실행 결과:

```text
** BUILD SUCCEEDED ** [11.217 sec]
```

### Asset verifier

```bash
scripts/verify-rhwp-studio-assets.sh
scripts/verify-rhwp-studio-assets.sh build.noindex/DerivedDataTask235/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
```

결과:

```text
OK: rhwp-studio assets verified at /Users/melee/Documents/projects/rhwp-mac/Sources/HostApp/Resources/rhwp-studio
OK: rhwp-studio assets verified at build.noindex/DerivedDataTask235/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
```

번들 asset 확인:

```text
rhwp_bg-BZNodj2e.wasm
index-ro3nVBB2.css
index-BN69C-Lp.js
```

### Runtime source 주변 확인

`index-BN69C-Lp.js`의 `column=30942` 주변은 `insertTextInCell` / `insertTextInCellByPath` WASM glue 계열이었다.

```text
hwpdocument_insertTextInCell(...)
insertTextInCellByPath(...)
```

이는 #223에서 본 Space 입력 계열과 같은 post-load editor input/WASM runtime 경로에 가깝다.

## Fatal 유지 대상

Stage 2 이후에도 다음은 fatal fallback으로 유지한다.

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

- 이번 smoke는 `abc` 입력으로 재현했다. 작업지시자 제보의 실제 입력 문자는 한글 성명 입력이지만, Computer Use의 한글 입력은 화면에 명확히 커밋되지 않아 ASCII 입력으로 같은 payload를 확인했다.
- 현재 재현 column은 `30942`이고 Issue 본문 column은 `32679`다. asset version 차이로 판단되며, Stage 2에서는 column을 allow-list 조건으로 쓰지 않는 것이 맞다.
- Stage 1은 재현과 정책 조사만 수행했으므로 fatal fallback 문제는 아직 수정되지 않았다.
- upstream `rhwp` #850 원인은 그대로 남는다.

## 다음 단계 영향

Stage 2의 최소 구현 방향은 다음과 같다.

1. `recoverableInvalidControlMessage` 단일 문자열을 known recoverable runtime message allow-list로 확장한다.
2. `컨트롤 인덱스 0 범위 초과`를 allow-list에 추가한다.
3. current document, post-load, bundled `index-*.js` source 조건은 유지한다.
4. `column`은 조건에서 제외한다.
5. `RhwpStudioWebViewFailure.runtime(..., isFatal: false)` 기존 라우팅을 재사용한다.

## 승인 요청

Stage 1 결과를 승인하면 Stage 2 `control-index runtime recoverable 분류 추가`로 진행한다.
