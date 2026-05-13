# Task M019 #223 구현계획서

수행계획서: `mydocs/plans/task_m019_223.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #223 그림 선택 후 Space 입력 시 WKWebView viewer runtime error 발생
- 마일스톤: M019 (`v0.1.2`)
- 브랜치: `local/task223`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac`
- 기준 브랜치: `devel-webview`
- 목표: 그림/개체 선택 상태에서 Space 입력으로 발생하는 post-load viewer runtime error가 전체 fallback 화면으로 전환되지 않게 하고, 문서 load/asset/WASM 초기화 실패의 fatal fallback은 유지한다.

## 현재 전제와 제약

- `#223` 이슈의 milestone은 `v0.1.2`로 변경되어 있다.
- 요청 파일은 `samples/exam_social.hwp`지만, 첨부 스크린샷 상태바에는 `exam_science.hwp - 4페이지`가 표시되어 있다.
- 현재 앱 번들 viewer는 `rhwp` `v0.7.10`, resolved commit `62a458aa317e962cd3d0eec6096728c172d57110` 기준이다.
- 오류 진단의 `sourceURL`은 `alhangeul-studio://app/assets/index-BN69C-Lp.js`이고, column 위치는 `insertTextInCell` / `insertTextInCellByPath` WASM glue 주변이다.
- upstream core의 해당 오류는 지정된 control index가 표, 글상자, 그림이 아닐 때 발생한다.
- `RhwpStudioWebViewFailure`에는 이미 `isFatal` 필드가 있지만, 현재 `DocumentViewerStore.setWebViewFailure(_:)`는 fatal 여부와 무관하게 전체 fallback을 표시한다.
- `project.yml`이 Xcode project 원본이며 `Alhangeul.xcodeproj`는 직접 수정하지 않는다.
- bundled `rhwp-studio` minified asset 직접 수정은 provenance와 재생성 가능성을 흐리므로 최후 수단으로 둔다.

## 구현 원칙

- 사용자 입력 중 발생한 특정 recoverable runtime error와 문서/asset/load failure를 분리한다.
- 문서가 아직 표시되지 않은 load 중 runtime error, resource scheme error, document scheme error, navigation failure, WebKit process termination, timeout은 계속 fatal fallback으로 둔다.
- 이미 문서가 표시된 뒤 발생하고, 진단 문구가 `지정된 컨트롤이 표, 글상자 또는 그림이 아닙니다` 계열인 경우에만 recoverable 후보로 분류한다.
- recoverable 후보는 기존 문서 화면을 유지하고 상단 banner 또는 status error로만 알린다.
- 정확한 재현과 회귀 확인 없이 더 넓은 runtime error를 무시하지 않는다.
- viewer 입력 처리 자체가 계속 손상되는 것으로 확인되면 HostApp 분류 완화만으로 완료하지 않고, bundled viewer 입력 처리 또는 upstream update 경로를 별도 기록한다.

## Stage 1. 재현 확정과 진단 경로 기록

### 목표

요청 파일명과 스크린샷 파일명 불일치를 해소하고, 오류가 발생하는 샘플/페이지/입력 순서를 단계 보고서에 고정한다.

### 작업

1. `samples/exam_social.hwp`와 `samples/exam_science.hwp` 존재 여부, 페이지 수, fixture 위치를 확인한다.
2. Debug HostApp을 빌드 또는 기존 Debug 산출물로 실행해 두 샘플을 각각 연다.
3. 스크린샷 기준 `exam_science.hwp` 4페이지의 그림/개체 선택 후 Space 입력을 우선 재현한다.
4. `exam_social.hwp`에서도 같은 동작을 확인해 실제 사용자 보고 파일과 스크린샷 파일 중 어느 쪽이 재현 원본인지 기록한다.
5. fallback이 표시되면 진단 disclosure의 `message`, `sourceURL`, `line`, `column`, `reason`을 기록한다.
6. `Sources/HostApp/Resources/rhwp-studio/assets/index-BN69C-Lp.js`의 column 주변과 upstream source의 입력 경로를 다시 매핑한다.
7. Stage 1 완료보고서를 작성한다.

### 예상 변경 파일

- `mydocs/working/task_m019_223_stage1.md`

### 검증

```bash
git status --short --branch
ls -l samples/exam_social.hwp samples/exam_science.hwp
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
scripts/verify-rhwp-studio-assets.sh
scripts/verify-rhwp-studio-assets.sh build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
git diff --check -- mydocs/working/task_m019_223_stage1.md
```

수동 smoke:

```text
1. Debug HostApp으로 samples/exam_science.hwp 열기
2. 4페이지로 이동
3. 스크린샷 기준 그림/개체 선택 후 Space 입력
4. fallback 표시 여부와 진단 값 기록
5. samples/exam_social.hwp에서도 같은 유형의 그림/개체 선택 후 Space 입력 확인
```

### 완료 기준

- 실제 재현 샘플과 페이지가 기록된다.
- HostApp fallback 진단 값이 단계 보고서에 남는다.
- `insertTextInCell` 라우팅과 core 오류 문구의 연결이 확인된다.
- 제품 코드 변경은 하지 않는다.

### 커밋 메시지

```text
Task #223 Stage 1: 그림 선택 Space 오류 재현 경로 확정
```

## Stage 2. nonfatal runtime failure 라우팅 구현

### 목표

이미 존재하는 `RhwpStudioWebViewFailure.isFatal` 값을 실제 UI 라우팅에 반영해, recoverable failure가 전체 fallback 화면을 띄우지 않게 한다.

### 작업

1. `DocumentViewerStore.setWebViewFailure(_:)`에서 `failure.isFatal`을 확인한다.
2. fatal failure는 기존처럼 `webViewFailure`에 저장하고 `webViewErrorMessage`를 비운다.
3. nonfatal failure는 `webViewFailure`를 유지하지 않고 `webViewErrorMessage`에 짧은 사용자 문구를 표시한다.
4. nonfatal 처리 시 `isWebViewLoading`을 false로 정리하되, 현재 문서와 WebView는 유지한다.
5. `RhwpStudioWebViewFailure.runtime(...)`에 `isFatal` 인자를 받을 수 있도록 factory를 확장한다.
6. Stage 2 완료보고서를 작성한다.

### 예상 변경 파일

- `Sources/HostApp/Stores/DocumentViewerStore.swift`
- `Sources/HostApp/Services/RhwpStudioResourceLocator.swift`
- `mydocs/working/task_m019_223_stage2.md`

### 검증

```bash
git diff --check -- Sources/HostApp/Stores/DocumentViewerStore.swift Sources/HostApp/Services/RhwpStudioResourceLocator.swift mydocs/working/task_m019_223_stage2.md
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

### 완료 기준

- fatal failure는 기존 fallback 화면 경로를 유지한다.
- nonfatal failure는 문서 화면을 유지하고 banner만 표시한다.
- `canRunWebViewCommands`는 nonfatal failure 뒤에도 `webViewFailure == nil` 기준으로 동작 가능 상태를 유지한다.
- fallback view 자체의 레이아웃 변경은 없다.

### 커밋 메시지

```text
Task #223 Stage 2: nonfatal WebView runtime failure 라우팅 추가
```

## Stage 3. post-load 입력 예외 분류 보강

### 목표

문서 표시가 끝난 뒤 발생하는 그림/개체 Space 입력 계열 WASM runtime error만 좁게 nonfatal로 분류한다.

### 작업

1. `RhwpStudioWebView.Coordinator`에서 현재 WebView load가 완료된 상태인지 판단할 수 있는 상태를 정리한다.
   - `didFinish` 이후 load timeout task가 없는 상태를 post-load 기준으로 사용한다.
   - 새 문서 load 시작 시 post-load 상태를 초기화한다.
2. `handleRuntimeError(_:)`에 runtime error 분류 helper를 추가한다.
3. 다음 조건을 모두 만족할 때만 nonfatal로 처리한다.
   - 현재 문서 payload가 있다.
   - load 중이 아니라 문서 표시 이후다.
   - `message` 또는 `reason`에 `지정된 컨트롤이 표, 글상자 또는 그림이 아닙니다`가 포함된다.
   - `sourceURL`이 bundled `rhwp-studio` asset 또는 현재 viewer URL에서 온다.
4. nonfatal로 분류된 경우 `RhwpStudioWebViewFailure.runtime(..., isFatal: false)`를 전달한다.
5. load 중 발생한 같은 문구, 다른 source line/stack을 가진 오류, unhandled promise rejection 일반 오류는 기존 fatal 처리로 둔다.
6. Stage 3 완료보고서를 작성한다.

### 예상 변경 파일

- `Sources/HostApp/Views/RhwpStudioWebView.swift`
- `Sources/HostApp/Services/RhwpStudioResourceLocator.swift`
- `mydocs/working/task_m019_223_stage3.md`

### 검증

```bash
git diff --check -- Sources/HostApp/Views/RhwpStudioWebView.swift Sources/HostApp/Services/RhwpStudioResourceLocator.swift mydocs/working/task_m019_223_stage3.md
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
scripts/verify-rhwp-studio-assets.sh
scripts/verify-rhwp-studio-assets.sh build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
```

수동 smoke:

```text
1. Debug HostApp으로 Stage 1 재현 샘플 열기
2. 문제 페이지에서 그림/개체 선택 후 Space 입력
3. 전체 fallback 화면이 표시되지 않는지 확인
4. 문서 화면과 toolbar가 유지되는지 확인
5. 가능하면 같은 동작을 여러 번 반복해 viewer process가 유지되는지 확인
```

### 완료 기준

- Stage 1 재현 동작에서 전체 runtime fallback이 표시되지 않는다.
- 사용자에게 짧은 nonfatal 오류 banner가 표시되거나 상태 표시가 유지된다.
- 문서 reload 없이 계속 보기 동작이 가능하다.
- 기존 asset verifier가 통과한다.

### 커밋 메시지

```text
Task #223 Stage 3: 그림 선택 입력 예외를 recoverable로 분류
```

## Stage 4. fatal fallback 회귀와 negative smoke 확인

### 목표

이번 완화가 실제 load/resource failure를 숨기지 않는지 확인한다.

### 작업

1. Debug app bundle의 `rhwp-studio` asset 포함 상태를 검증한다.
2. 정상 HWP/HWPX 샘플 열기 smoke를 수행한다.
3. Debug app 복사본에서 WASM asset을 임시로 누락시켜 resource fallback이 기존처럼 표시되는지 확인한다.
4. 손상 문서 또는 빈 문서 synthetic 입력으로 document load fallback이 기존처럼 표시되는지 확인한다.
5. `#183`에서 다룬 ResizeObserver notification filter가 유지되는지 창 resize smoke를 반복한다.
6. Stage 4 완료보고서를 작성한다.

### 예상 변경 파일

- `mydocs/working/task_m019_223_stage4.md`

### 검증

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
scripts/verify-rhwp-studio-assets.sh
scripts/verify-rhwp-studio-assets.sh build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
test -f build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio/index.html
test "$(find build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio/assets -maxdepth 1 -name 'rhwp_bg-*.wasm' -type f | wc -l | tr -d ' ')" = "1"
git diff --check -- mydocs/working/task_m019_223_stage4.md
```

수동 negative smoke:

```text
1. Debug app 복사본에서 rhwp_bg-*.wasm 파일명만 .missing으로 변경
2. 복사본 앱으로 HWP/HWPX 열기
3. `웹 viewer 자산을 찾을 수 없습니다` 계열 fatal fallback 확인
4. 원본 Debug app으로 빈/손상 synthetic HWP 열기
5. document load fallback 확인
6. KTX.hwp 창 resize 후 #183 회귀 없음 확인
```

### 완료 기준

- 정상 샘플은 열리고 문제 입력은 전체 fallback으로 전환되지 않는다.
- asset 누락은 fatal fallback으로 남는다.
- document load failure는 fatal fallback으로 남는다.
- ResizeObserver benign filter 회귀가 없다.

### 커밋 메시지

```text
Task #223 Stage 4: WebView fallback 회귀 smoke 확인
```

## Stage 5. nonfatal banner 자동 dismiss와 수동 닫기

### 목표

nonfatal runtime error banner가 문서 화면 위에 계속 남지 않도록 일정 시간 뒤 자동으로 사라지게 하고, 사용자가 즉시 닫을 수 있는 우측 닫기 버튼을 제공한다.

### 작업

1. `DocumentViewerStore`가 `webViewErrorMessage` 표시와 dismiss 예약 task를 소유하게 한다.
2. 새 banner message가 들어오면 기존 dismiss 예약을 취소하고 새 타이머를 시작한다.
3. fatal fallback으로 전환되거나 문서 reload/retry가 발생하면 dismiss 예약과 banner를 함께 정리한다.
4. `WebViewerErrorBanner` 우측에 `xmark` 닫기 버튼을 추가한다.
5. Stage 5 완료보고서를 작성한다.

### 예상 변경 파일

- `Sources/HostApp/Stores/DocumentViewerStore.swift`
- `Sources/HostApp/Views/DocumentViewerView.swift`
- `mydocs/orders/20260511.md`
- `mydocs/plans/task_m019_223_impl.md`
- `mydocs/working/task_m019_223_stage5.md`

### 검증

```bash
git diff --check -- Sources/HostApp/Stores/DocumentViewerStore.swift Sources/HostApp/Views/DocumentViewerView.swift mydocs/plans/task_m019_223_impl.md mydocs/working/task_m019_223_stage5.md
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataStage5 \
  CODE_SIGNING_ALLOWED=NO \
  build
```

수동 smoke:

```text
1. Debug HostApp으로 samples/exam_science.hwp 열기
2. Stage 1 재현 동작으로 nonfatal banner 표시
3. 우측 x 버튼으로 즉시 사라지는지 확인
4. 다시 같은 동작으로 banner 표시 후 일정 시간 뒤 자동으로 사라지는지 확인
5. WASM 누락 또는 빈 문서 fatal fallback에는 닫기 버튼/자동 dismiss가 적용되지 않는지 확인
```

### 완료 기준

- nonfatal banner는 5초 뒤 자동으로 사라진다.
- 같은 banner가 다시 표시되면 dismiss 타이머가 reset된다.
- 닫기 버튼을 누르면 즉시 banner가 사라진다.
- fatal fallback 화면은 자동 dismiss되지 않는다.

### 커밋 메시지

```text
Task #223 Stage 5: nonfatal banner dismiss UX 추가
```

## Stage 6. Enter 입력 invalid-control runtime 분류 보강

### 목표

Space 입력 외에 Enter 입력에서도 같은 `지정된 컨트롤이 표, 글상자 또는 그림이 아닙니다` runtime error가 발생해 전체 fallback으로 전환되는 문제를 보강한다.

### 작업

1. Enter 입력 fallback 진단값을 Stage 6 보고서에 기록한다.
   - `message=렌더링 오류: 지정된 컨트롤이 표, 글상자 또는 그림이 아닙니다`
   - `sourceURL=alhangeul-studio://app/assets/index-BN69C-Lp.js`
   - `line=1`
   - `column=45271`
2. 기존 Space 경로의 `column=30942` 고정 allow-list를 제거한다.
3. post-load 상태, 정확한 오류 문구, bundled `rhwp-studio` `index-*.js` source 조건은 유지한다.
4. `index.html` unhandled rejection fallback도 stack이 bundled `index-*.js` line 1을 가리킬 때만 recoverable로 둔다.
5. Stage 6 완료보고서를 작성한다.

### 예상 변경 파일

- `Sources/HostApp/Views/RhwpStudioWebView.swift`
- `mydocs/orders/20260511.md`
- `mydocs/plans/task_m019_223_impl.md`
- `mydocs/working/task_m019_223_stage6.md`

### 검증

```bash
git diff --check -- Sources/HostApp/Views/RhwpStudioWebView.swift mydocs/plans/task_m019_223_impl.md mydocs/working/task_m019_223_stage6.md
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataStage6 \
  CODE_SIGNING_ALLOWED=NO \
  build
scripts/verify-rhwp-studio-assets.sh
scripts/verify-rhwp-studio-assets.sh build.noindex/DerivedDataStage6/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
```

수동 smoke:

```text
1. Debug HostApp으로 samples/exam_science.hwp 열기
2. Stage 1 재현 위치에서 작은 object 선택 후 Space 입력
3. 같은 선택 상태 계열에서 Enter 입력
4. 두 입력 모두 전체 fallback이 아니라 nonfatal banner로 남는지 확인
5. 빈 문서 또는 WASM 누락 fatal fallback은 계속 전체 fallback으로 남는지 확인
```

### 완료 기준

- Space 경로의 `column=30942`뿐 아니라 Enter 경로의 `column=45271`도 recoverable로 분류된다.
- recoverable 분류는 문서 표시 완료 이후 bundled viewer runtime에서 발생한 정확한 invalid-control 오류에만 적용된다.
- load/resource/document fatal failure 경로는 기존처럼 유지된다.

### 커밋 메시지

```text
Task #223 Stage 6: Enter 입력 invalid-control 오류 recoverable 처리
```

## Stage 7. 최종 정리와 PR 준비

### 목표

변경 내용을 통합 검증하고 최종 결과 보고서와 오늘할일을 정리한다.

### 작업

1. Stage 1-6 결과를 최종 보고서에 요약한다.
2. `mydocs/orders/20260511.md`에서 #223 상태를 완료로 갱신한다.
3. 최종 결과 보고서 `mydocs/report/task_m019_223_report.md`를 작성한다.
4. 전체 whitespace와 git 상태를 확인한다.
5. Stage 7 완료보고서를 작성한다.

### 예상 변경 파일

- `mydocs/orders/20260511.md`
- `mydocs/working/task_m019_223_stage7.md`
- `mydocs/report/task_m019_223_report.md`

### 검증

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
scripts/verify-rhwp-studio-assets.sh
scripts/verify-rhwp-studio-assets.sh build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
rg -n "Task M019 #223|#223|runtime error|Space|지정된 컨트롤|isFatal|nonfatal|recoverable" \
  mydocs/orders/20260511.md mydocs/plans/task_m019_223.md mydocs/plans/task_m019_223_impl.md mydocs/working mydocs/report Sources/HostApp
git diff --check
git status --short
```

### 완료 기준

- 최종 보고서에 원인, 수정 파일, 검증 결과, 잔여 위험이 기록된다.
- 오늘할일이 완료 상태로 갱신된다.
- PR 생성 전 미커밋 변경이 없다.
- 작업지시자 최종 승인 후 `task-final-report` 절차로 PR 게시를 진행할 수 있다.

### 커밋 메시지

```text
Task #223 Stage 7 + 최종 보고서: 그림 선택 Space runtime fallback 보강 완료
```

## 승인 요청 사항

1. 위 7단계 구현계획 승인
2. Stage 1에서 재현 확정과 진단 경로 기록부터 진행 승인
