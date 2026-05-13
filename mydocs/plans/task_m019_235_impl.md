# Task M019 #235 구현계획서

수행계획서: `mydocs/plans/task_m019_235.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #235 Web viewer runtime 오류를 fatal 화면 대신 non-blocking banner로 표시
- 마일스톤: M019 (`v0.1.2`)
- 브랜치: `local/task235`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac`
- 기준 브랜치: `devel-webview`
- 목표: `samples/exam_social.hwp` 성명 필드 입력 중 발생하는 post-load `컨트롤 인덱스 0 범위 초과` runtime error가 전체 fatal fallback 화면으로 전환되지 않고, 문서 화면을 유지한 채 non-blocking banner로 표시되게 한다.

## 현재 전제와 제약

- #223에서 `RhwpStudioWebViewFailure.isFatal == false` 경로는 이미 `webViewErrorMessage` banner로 라우팅된다.
- #223에서 `지정된 컨트롤이 표, 글상자 또는 그림이 아닙니다` runtime error는 post-load bundled viewer source 조건을 만족할 때 recoverable로 분류된다.
- 현재 nonfatal banner는 5초 자동 dismiss와 우측 닫기 버튼을 가진다.
- #235의 제보 payload는 `message/reason=렌더링 오류: 컨트롤 인덱스 0 범위 초과`, `sourceURL=alhangeul-studio://app/assets/index-CRsGAVvx.js`, `line=1`, `column=32679`이다.
- upstream 원인 수정은 `edwardkim/rhwp` #850에서 별도 추적한다. 본 작업은 HostApp UX 완화와 fatal/nonfatal 분류에 한정한다.
- `project.yml`이 Xcode project 원본이며 `Alhangeul.xcodeproj`는 직접 수정하지 않는다.
- `Sources/RhwpCoreBridge`에는 AppKit/UIKit 직접 의존을 추가하지 않는다. 이번 작업의 예상 변경은 HostApp 경계에만 둔다.

## 구현 원칙

- 문서 표시 완료 이후 발생한 known upstream editor/runtime 예외만 nonfatal 후보로 둔다.
- 초기 asset/resource/document load failure, WebContent process termination, timeout, navigation failure는 계속 fatal fallback으로 둔다.
- `sourceURL` 또는 stack이 bundled `rhwp-studio` asset에서 온 경우에만 recoverable로 인정한다.
- 메시지 문자열은 넓게 일반화하지 않고, #223 invalid-control 문구와 #235 control-index 문구처럼 확인된 오류만 allow-list로 둔다.
- 같은 nonfatal runtime diagnostic이 banner 표시 중 반복되면 기존 banner의 dismiss timer를 계속 reset하지 않도록 dedupe한다.
- 사용자 명령 오류, 파일 열기 오류, 공유/PDF 오류 등 일반 `setWebViewError` 경로는 runtime dedupe 대상에 넣지 않는다.

## Stage 1. 재현과 현행 오류 정책 inventory

### 목표

`exam_social.hwp` 성명 필드 입력 오류를 가능한 범위에서 재현하고, #223 이후 현행 HostApp fatal/nonfatal 정책을 단계 보고서에 고정한다.

### 작업

1. `samples/exam_social.hwp` 존재와 sample 접근 경로를 확인한다.
2. 현행 `RhwpStudioWebView.Coordinator.handleRuntimeError(_:)`의 recoverable 조건을 정리한다.
3. 현행 `DocumentViewerStore.setWebViewFailure(_:)`와 `WebViewerErrorBanner` 동작을 정리한다.
4. Debug HostApp build 또는 기존 산출물로 `exam_social.hwp`를 열고 성명 필드 입력 경로를 시도한다.
5. 재현되면 `message`, `sourceURL`, `line`, `column`, `reason`을 기록한다.
6. 재현성이 낮으면 Issue #235의 payload를 기준 진단값으로 사용하되, smoke 한계와 후속 수동 확인 필요성을 보고서에 분리 기록한다.
7. fatal로 유지해야 할 failure category를 `resourcePreflight`, `resourceScheme`, `documentScheme`, `navigation`, `processTerminated`, `timeout`, load 전 runtime으로 목록화한다.
8. Stage 1 완료보고서를 작성한다.

### 예상 변경 파일

- `mydocs/working/task_m019_235_stage1.md`

### 검증

```bash
git status --short --branch
ls -l samples/exam_social.hwp
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask235 \
  CODE_SIGNING_ALLOWED=NO \
  build
scripts/verify-rhwp-studio-assets.sh
scripts/verify-rhwp-studio-assets.sh build.noindex/DerivedDataTask235/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
git diff --check -- mydocs/working/task_m019_235_stage1.md
```

수동 smoke:

```text
1. Debug HostApp으로 samples/exam_social.hwp 열기
2. 성명 필드 위치로 이동
3. 사용자 제보와 같은 입력을 시도
4. fallback 또는 banner 표시 여부와 진단값 기록
```

### 완료 기준

- 현행 #223 기반 nonfatal routing과 #235 추가 필요 지점이 분리되어 기록된다.
- `exam_social.hwp` 재현 결과 또는 재현 한계가 단계 보고서에 남는다.
- 제품 코드는 변경하지 않는다.

### 커밋 메시지

```text
Task #235 Stage 1: runtime 오류 정책과 재현 경로 정리
```

## Stage 2. control-index runtime recoverable 분류 추가

### 목표

문서 표시 이후 bundled viewer runtime에서 발생한 `컨트롤 인덱스 0 범위 초과` 오류를 nonfatal로 분류한다.

### 작업

1. `RhwpStudioWebView.Coordinator`의 recoverable runtime 판별을 invalid-control 전용 helper에서 known post-load runtime error helper로 정리한다.
2. 기존 `지정된 컨트롤이 표, 글상자 또는 그림이 아닙니다` 조건은 유지한다.
3. `컨트롤 인덱스 0 범위 초과` 또는 같은 계열의 제보 메시지를 새 allow-list에 추가한다.
4. current document 존재, `hasCompletedCurrentLoad == true`, bundled `rhwp-studio` asset source 조건을 계속 필수로 둔다.
5. `column` 숫자는 asset build마다 바뀔 수 있으므로 allow-list의 필수 조건으로 쓰지 않는다.
6. `RhwpStudioWebViewFailure.runtime(..., isFatal: false)`의 user-facing 문구가 #235에도 적합한지 확인하고, 필요 시 문구를 유지 또는 좁게 보정한다.
7. Stage 2 완료보고서를 작성한다.

### 예상 변경 파일

- `Sources/HostApp/Views/RhwpStudioWebView.swift`
- `Sources/HostApp/Services/RhwpStudioResourceLocator.swift` (필요 시)
- `mydocs/working/task_m019_235_stage2.md`

### 검증

```bash
git diff --check -- Sources/HostApp/Views/RhwpStudioWebView.swift Sources/HostApp/Services/RhwpStudioResourceLocator.swift mydocs/working/task_m019_235_stage2.md
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask235Stage2 \
  CODE_SIGNING_ALLOWED=NO \
  build
rg -n "컨트롤 인덱스|지정된 컨트롤|recoverable|isFatal|runtime" Sources/HostApp/Views/RhwpStudioWebView.swift Sources/HostApp/Services/RhwpStudioResourceLocator.swift
```

수동 smoke:

```text
1. Debug HostApp으로 samples/exam_social.hwp 열기
2. 성명 필드 입력으로 control-index runtime 오류 유도
3. 전체 fallback 대신 문서 화면과 banner가 유지되는지 확인
4. #223 invalid-control 경로도 전체 fallback으로 회귀하지 않는지 확인
```

### 완료 기준

- post-load `컨트롤 인덱스 0 범위 초과` runtime error가 nonfatal로 전달된다.
- load 전 runtime error와 다른 source의 runtime error는 fatal로 남는다.
- #223 invalid-control recoverable 경로가 유지된다.

### 커밋 메시지

```text
Task #235 Stage 2: control-index runtime 오류 recoverable 분류 추가
```

## Stage 3. nonfatal runtime banner dedupe 구현

### 목표

같은 runtime 오류가 짧은 시간 안에 반복될 때 banner가 계속 reset되거나 사용자 화면을 과도하게 방해하지 않도록 한다.

### 작업

1. `DocumentViewerStore`의 banner 표시 경로를 검토하고, nonfatal runtime failure 전용 dedupe key를 전달할 수 있게 한다.
2. `setWebViewFailure(_:)`에서 `failure.isFatal == false`일 때 category와 `diagnosticDetail` 기반 key를 만든다.
3. 같은 dedupe key의 banner가 이미 표시 중이면 기존 banner와 dismiss task를 유지하고 새 표시 요청을 무시한다.
4. 다른 nonfatal runtime diagnostic이 오면 새 banner로 교체하고 dismiss timer를 새로 시작한다.
5. fatal failure 전환, 새 문서 load, reload/retry, 사용자의 dismiss는 dedupe 상태를 정리한다.
6. `setWebViewError(_:)`로 들어오는 일반 사용자 명령 오류는 dedupe하지 않는다.
7. Stage 3 완료보고서를 작성한다.

### 예상 변경 파일

- `Sources/HostApp/Stores/DocumentViewerStore.swift`
- `Sources/HostApp/Views/DocumentViewerView.swift` (필요 시)
- `mydocs/working/task_m019_235_stage3.md`

### 검증

```bash
git diff --check -- Sources/HostApp/Stores/DocumentViewerStore.swift Sources/HostApp/Views/DocumentViewerView.swift mydocs/working/task_m019_235_stage3.md
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask235Stage3 \
  CODE_SIGNING_ALLOWED=NO \
  build
rg -n "dedupe|dedup|diagnosticDetail|webViewError|dismiss|isFatal" Sources/HostApp/Stores/DocumentViewerStore.swift Sources/HostApp/Views/DocumentViewerView.swift
```

수동 smoke:

```text
1. Debug HostApp으로 samples/exam_social.hwp 열기
2. 같은 성명 필드 입력 오류를 연속으로 유도
3. 같은 banner가 표시 중일 때 dismiss timer가 계속 reset되지 않는지 확인
4. banner 수동 닫기 후 같은 오류가 다시 표시될 수 있는지 확인
5. 공유/PDF 등 일반 WebView error banner는 기존처럼 표시되는지 확인
```

### 완료 기준

- 같은 nonfatal runtime diagnostic 반복은 banner 표시 중 중복 반영되지 않는다.
- 다른 오류는 숨기지 않고 표시된다.
- 사용자가 닫거나 자동 dismiss된 뒤에는 같은 오류를 다시 인지할 수 있다.
- fatal fallback은 dedupe와 무관하게 기존처럼 표시된다.

### 커밋 메시지

```text
Task #235 Stage 3: nonfatal runtime banner 중복 표시 제어
```

## Stage 4. 통합 build와 fatal fallback 회귀 smoke

### 목표

#235 완화가 정상 viewer 사용성과 fatal fallback 기준을 훼손하지 않았는지 확인한다.

### 작업

1. Debug HostApp build를 수행한다.
2. bundled `rhwp-studio` asset verifier를 실행한다.
3. `exam_social.hwp` 성명 필드 입력 smoke를 수행한다.
4. #223 invalid-control Space/Enter 경로가 여전히 nonfatal인지 가능한 범위에서 확인한다.
5. WASM/resource 누락, document load error, WebContent process termination 또는 timeout에 해당하는 fatal 경로 중 재현 가능한 항목을 확인한다.
6. 결과와 재현 불가 항목을 단계 보고서에 분리 기록한다.

### 예상 변경 파일

- `mydocs/working/task_m019_235_stage4.md`

### 검증

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask235 \
  CODE_SIGNING_ALLOWED=NO \
  build
scripts/verify-rhwp-studio-assets.sh
scripts/verify-rhwp-studio-assets.sh build.noindex/DerivedDataTask235/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
test -f build.noindex/DerivedDataTask235/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio/index.html
test "$(find build.noindex/DerivedDataTask235/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio/assets -maxdepth 1 -name 'rhwp_bg-*.wasm' -type f | wc -l | tr -d ' ')" = "1"
git diff --check -- mydocs/working/task_m019_235_stage4.md
```

수동 smoke:

```text
1. Debug HostApp으로 samples/exam_social.hwp 열기
2. 성명 필드 입력 중 runtime 오류 유도
3. 문서 본문 유지, banner 표시, 반복 오류 dedupe 확인
4. Debug app 복사본에서 rhwp_bg-*.wasm을 임시 누락시켜 resource fatal fallback 확인
5. 빈/손상 synthetic 문서로 document load fatal fallback 확인
```

### 완료 기준

- `exam_social.hwp` runtime 오류가 전체 fatal 화면으로 전환되지 않는다.
- nonfatal banner와 dedupe 동작을 확인했거나, 재현 한계가 명확히 기록된다.
- resource/document/load 불가 경로는 fatal fallback을 유지한다.
- build와 asset verifier가 통과한다.

### 커밋 메시지

```text
Task #235 Stage 4: runtime banner 통합 회귀 검증
```

## Stage 5. release 기록과 최종 보고

### 목표

작업 결과를 `v0.1.2` release blocker 처리 기록으로 정리하고 PR 준비 상태를 만든다.

### 작업

1. Stage 1-4 결과를 최종 보고서에 요약한다.
2. `mydocs/orders/20260512.md`에서 #235 상태를 완료로 갱신한다.
3. `mydocs/report/task_m019_235_report.md`를 작성한다.
4. `mydocs/release/v0.1.2.md`가 이미 있거나 release 기록 후보가 필요한지 확인한다.
5. release 기록이 존재하면 #235 처리 결과와 upstream #850 잔여 범위를 짧게 연결한다. 아직 release 기록 파일이 없다면 최종 보고서에 #225/#235 handoff만 남기고 신규 release 파일 생성은 별도 승인 범위로 둔다.
6. 전체 검색, whitespace, git 상태를 확인한다.
7. Stage 5 완료보고서를 작성한다.

### 예상 변경 파일

- `mydocs/orders/20260512.md`
- `mydocs/working/task_m019_235_stage5.md`
- `mydocs/report/task_m019_235_report.md`
- `mydocs/release/v0.1.2.md` (존재하고 범위상 필요할 때만)

### 검증

```bash
rg -n "Task M019 #235|#235|컨트롤 인덱스|runtime-error|recoverable|nonfatal|dedupe|banner|#850" \
  mydocs/orders/20260512.md mydocs/plans/task_m019_235.md mydocs/plans/task_m019_235_impl.md mydocs/working mydocs/report Sources/HostApp
test -f mydocs/report/task_m019_235_report.md
git diff --check
git status --short
```

### 완료 기준

- 최종 보고서에 변경 내용, 검증 결과, 잔여 위험, upstream #850 관계가 기록된다.
- 오늘할일이 완료 상태로 갱신된다.
- PR 생성 전 미커밋 변경이 없다.
- 작업지시자 최종 승인 후 `task-final-report` 절차로 PR 게시를 진행할 수 있다.

### 커밋 메시지

```text
Task #235 Stage 5 + 최종 보고서: runtime 오류 banner 처리 완료
```

## 승인 요청 사항

1. 위 5단계 구현계획 승인
2. Stage 1에서 재현과 현행 오류 정책 inventory부터 진행 승인
