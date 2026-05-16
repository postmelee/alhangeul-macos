# Task M018 #183 구현계획서

수행계획서: `mydocs/plans/task_m018_183.md`

각 단계 완료 후 `task-stage-report` 절차로 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #183 v0.1.0 설치본에서 창 확대 시 WebView runtime error 발생
- 마일스톤: M018 (`v0.1.1`)
- 브랜치: `local/task183`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac`
- 기준 브랜치: `devel-webview`
- 주 대상: HostApp WKWebView viewer의 window zoom/resize runtime failure 경로
- 목표: HWP/HWPX 문서가 열린 상태에서 창 확대, 원복, 수동 resize를 반복해도 viewer 상태가 유지되고 runtime fallback이 표시되지 않는다.

## 구현 원칙

- 수행 순서는 `재현/진단 -> 원인 분리 -> 최소 수정 -> smoke 검증 -> v0.1.1 handoff`로 고정한다.
- `/Applications/Alhangeul.app` 또는 `v0.1.0` DMG 설치본 재현은 Stage 1 진단 입력으로만 다루고, 설치본 자체를 수정하지 않는다.
- 제품 코드는 `Sources/HostApp` 또는 저장소 소유 `rhwp-studio` override 범위에서만 수정한다.
- `Sources/RhwpCoreBridge`에는 AppKit/WebKit 의존을 추가하지 않는다.
- runtime error 필터를 보강할 경우 source/reason/message 조건을 좁게 둔다. 실제 JS/WASM failure를 숨기는 broad ignore는 금지한다.
- bundled `rhwp-studio` minified asset 직접 수정은 마지막 수단으로만 사용하고, 필요하면 provenance와 asset verifier 영향을 단계 보고서에 기록한다.
- `project.yml`이 Xcode project 원본이다. `Alhangeul.xcodeproj` 직접 수정은 하지 않는다.
- #188 범위인 signed/notarized public DMG 생성과 release 게시, Homebrew Cask 갱신은 수행하지 않는다.

## Stage 1. 설치본 재현과 진단 정보 수집

### 목표

- `v0.1.0` 설치본에서 창 확대 runtime fallback을 실제로 확인하고, fallback 진단 정보를 확보한다.
- 같은 smoke를 현재 `devel-webview` 기반 Debug/Release candidate에서 비교해 문제가 release artifact 고유인지 현재 코드에도 남아 있는지 분리한다.

### 작업

- 이슈 본문과 #150 최종 보고서의 runtime fallback taxonomy를 대조한다.
- 현재 `/Applications/Alhangeul.app` 버전과 bundle resource 상태를 확인한다.
- 필요 시 `v0.1.0` GitHub Release DMG 설치본을 기준으로 재현한다.
- HWP/HWPX 샘플을 열고 다음 동작을 확인한다.
  - title bar 더블 클릭 window zoom
  - green zoom button
  - 수동 창 resize
  - zoom 원복 후 재반복
- fallback이 표시되면 진단 정보의 `message`, `sourceURL`, `line`, `column`, `reason`, document revision, filename을 기록한다.
- 현재 브랜치 Debug build 또는 기존 build 산출물에서 같은 smoke를 수행한다.
- Stage 1 보고서에 재현 여부, 환경, 로그/진단, current build와 설치본 차이를 남긴다.

### 예상 변경 파일

- `mydocs/working/task_m018_183_stage1.md`

### 검증

```bash
git status --short --branch
gh issue view 183 --repo postmelee/alhangeul-macos --json number,title,state,milestone,body
scripts/verify-rhwp-studio-assets.sh
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
git diff --check
```

수동 smoke 후보:

```bash
/usr/bin/open -n -a "$PWD/build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app" "$PWD/samples/basic/KTX.hwp"
/usr/bin/open -a "$PWD/build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app" "$PWD/samples/hwpx/hwpx-01.hwpx"
```

### 완료 기준

- 설치본 또는 current build에서 창 확대 runtime fallback 재현 여부가 명확히 기록된다.
- fallback이 재현되면 native 진단 정보와 사용자 동작 순서가 Stage 2 원인 분석에 충분한 수준으로 남는다.
- 재현되지 않으면 재현 불가 조건과 #188 설치본 smoke에서 다시 확인할 항목이 정리된다.

### 커밋 메시지

```text
Task #183 Stage 1: 설치본 WebView runtime error 재현 진단
```

## Stage 2. 원인 경로 분리와 수정안 확정

### 목표

- 창 확대 동작이 runtime fallback으로 이어지는 경로를 `benign runtime issue`, `rhwp-studio resize/layout 오류`, `WKWebView lifecycle`, `HostApp fallback 처리 오류` 중 하나 이상으로 분리한다.
- Stage 3에서 수정할 파일과 수용 기준을 확정한다.

### 작업

- `RhwpStudioHostBridgeScript.runtimeErrorSource`의 `error`, `unhandledrejection`, `isBenignRuntimeIssue` 조건을 분석한다.
- `RhwpStudioWebView.Coordinator`의 runtime failure, navigation failure, timeout, process termination 처리를 창 확대 상황과 대조한다.
- bundled `rhwp-studio` resource에서 resize, zoom, layout, viewport 관련 코드를 검색한다.
- `alhangeul-wkwebview-overrides.css`와 `index.html` override 주입 경로가 창 확대에 영향을 줄 수 있는지 확인한다.
- 실제 오류가 문서 표시를 깨뜨리는지, 문서는 정상인데 fatal bridge만 과잉 반응하는지 구분한다.
- 수정 후보를 하나로 좁힌다.
  - known benign issue 필터 보강
  - resize/layout 안정화 host injection
  - fallback 상태 처리 보정
  - smoke 문서 보강만 필요한 경우
- Stage 2 보고서에 후보별 기각 이유와 선택한 수정안을 남긴다.

### 예상 변경 파일

- `mydocs/working/task_m018_183_stage2.md`

### 검증

```bash
git status --short --branch
rg -n "runtime-error|unhandledrejection|isBenignRuntimeIssue|resize|ResizeObserver|zoom|viewport|setZoom|window\\.addEventListener" \
  Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift \
  Sources/HostApp/Views/RhwpStudioWebView.swift \
  Sources/HostApp/Resources/rhwp-studio
git diff --check
```

### 완료 기준

- 재현된 runtime failure의 원인 범주가 정리된다.
- Stage 3에서 수정할 파일과 수정하지 않을 파일이 명확해진다.
- 실제 runtime failure를 숨기지 않는 guard 조건 또는 resize 안정화 방식이 확정된다.

### 커밋 메시지

```text
Task #183 Stage 2: 창 확대 runtime error 원인 경로 분리
```

## Stage 3. 최소 수정 구현

### 목표

- Stage 2에서 확정한 방식으로 창 확대/resize 중 정상 viewer 상태가 fatal fallback으로 바뀌지 않도록 수정한다.

### 작업

- benign runtime issue로 확정된 경우 `RhwpStudioHostBridgeScript.runtimeErrorSource`의 필터를 좁게 보강한다.
- resize/layout 오류로 확정된 경우 HostApp 주입 script 또는 `alhangeul-wkwebview-overrides.css` 범위에서 viewer resize 안정화 patch를 적용한다.
- fallback 처리 오류로 확정된 경우 `RhwpStudioWebView` 또는 `DocumentViewerStore`의 state transition을 보정한다.
- 변경 파일이 bundled asset이면 `scripts/verify-rhwp-studio-assets.sh`와 manifest/provenance 영향 여부를 확인한다.
- Stage 3 보고서에 변경 내용, 사용자 영향, 의도적으로 제외한 대안을 기록한다.

### 예상 변경 파일

- `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift` (필요 시)
- `Sources/HostApp/Views/RhwpStudioWebView.swift` (필요 시)
- `Sources/HostApp/Stores/DocumentViewerStore.swift` (필요 시)
- `Sources/HostApp/Resources/rhwp-studio/alhangeul-wkwebview-overrides.css` (필요 시)
- `Sources/HostApp/Resources/rhwp-studio/index.html` 또는 `assets/**` (불가피할 때만)
- `scripts/verify-rhwp-studio-assets.sh` (필요 시)
- `mydocs/working/task_m018_183_stage3.md`

### 검증

```bash
git status --short --branch
scripts/verify-rhwp-studio-assets.sh
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
git diff --check
```

### 완료 기준

- Debug build가 성공한다.
- source `rhwp-studio` asset verifier가 통과한다.
- runtime error 처리 변경이 narrow condition으로 구현되어 Stage 4에서 정상/negative smoke로 검증 가능하다.

### 커밋 메시지

```text
Task #183 Stage 3: WKWebView resize runtime 안정화
```

## Stage 4. 창 확대/resize smoke와 회귀 검증

### 목표

- 수정 후 HWP/HWPX 문서에서 창 확대, 원복, 수동 resize를 반복해도 viewer 상태가 유지되는지 확인한다.
- #150에서 도입한 asset/runtime fallback의 의미가 깨지지 않았는지 필요한 범위에서 회귀 확인한다.

### 작업

- Debug build 산출물에서 HWP/HWPX 정상 smoke를 수행한다.
- `samples/basic/KTX.hwp`와 `samples/hwpx/hwpx-01.hwpx`를 각각 열고 다음을 확인한다.
  - title bar 더블 클릭 확대/원복 반복
  - green zoom button
  - 창 가장자리 drag resize
  - 문서 상태 표시 유지
  - fallback 미표시
  - toolbar command 활성 상태 유지
- 필요하면 Release unsigned build에서도 같은 smoke를 반복한다.
- `scripts/verify-rhwp-studio-assets.sh`를 source resource와 app bundle resource 양쪽에서 실행한다.
- runtime filter를 바꾼 경우 실제 unknown runtime error가 무조건 무시되지 않는지 코드 조건과 negative smoke 후보로 확인한다.
- Stage 4 보고서에 명령, 수동 조작, 결과, 미수행 한계를 기록한다.

### 예상 변경 파일

- `mydocs/manual/build_run_guide.md` (window zoom smoke 항목 보강이 필요할 때)
- `mydocs/manual/release_distribution_guide.md` (설치본 smoke gate 보강이 필요할 때)
- `mydocs/working/task_m018_183_stage4.md`

### 검증

```bash
git status --short --branch
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
scripts/verify-rhwp-studio-assets.sh
scripts/verify-rhwp-studio-assets.sh build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
git diff --check
```

수동 smoke 후보:

```bash
/usr/bin/open -n -a "$PWD/build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app" "$PWD/samples/basic/KTX.hwp"
/usr/bin/open -a "$PWD/build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app" "$PWD/samples/hwpx/hwpx-01.hwpx"
```

### 완료 기준

- HWP/HWPX 샘플 모두에서 창 확대/resize 후 fallback이 표시되지 않는다.
- 상태 표시와 toolbar command가 현재 문서 기준으로 유지된다.
- asset verifier와 Debug build가 통과한다.
- 설치본 smoke에서 반복해야 할 window zoom 절차가 문서 또는 단계 보고서에 남는다.

### 커밋 메시지

```text
Task #183 Stage 4: 창 확대 smoke 검증
```

## Stage 5. v0.1.1 patch candidate handoff

### 목표

- #183 수정 결과를 최종 보고서로 정리하고 #188 `v0.1.1` release 실행에서 반복할 설치본 smoke 항목을 명확히 넘긴다.

### 작업

- 최종 보고서에 다음을 정리한다.
  - 설치본 재현 여부와 환경
  - 원인 범주
  - 수정 파일과 변경 요지
  - HWP/HWPX 창 확대/resize smoke 결과
  - #150 runtime fallback 회귀 여부
  - #188에서 signed/notarized DMG로 재검증할 항목
- `mydocs/orders/20260509.md`의 #183 상태를 완료로 갱신한다.
- PR 게시 전 `git status`와 diff 검증 상태를 정리한다.

### 예상 변경 파일

- `mydocs/report/task_m018_183_report.md`
- `mydocs/orders/20260509.md`

### 검증

```bash
git status --short --branch
git diff --check
rg -n "#183|창 확대|resize|runtime|v0\\.1\\.1|완료" \
  mydocs/report/task_m018_183_report.md \
  mydocs/orders/20260509.md
```

### 완료 기준

- 최종 보고서가 #183의 재현, 원인, 수정, 검증, release handoff를 포함한다.
- 오늘할일이 완료 상태로 갱신된다.
- PR 게시 전 작업 트리와 검증 결과가 정리된다.

### 커밋 메시지

```text
Task #183 Stage 5 + 최종 보고서: 창 확대 runtime error 수정 완료
```

## 승인 요청

위 5단계 구현계획 승인을 요청한다. 승인 후 Stage 1 `설치본 재현과 진단 정보 수집`을 시작한다.
