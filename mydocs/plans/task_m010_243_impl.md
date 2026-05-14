# Task M010 #243 구현계획서

수행계획서: `mydocs/plans/task_m010_243.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #243 종료/창 닫기 시 저장 여부 확인 모달 추가
- 마일스톤: M010 (`v0.1`)
- 브랜치: `local/task243`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac`
- 기준 브랜치: `devel-webview`
- 목표: WKWebView 기반 HostApp에서 저장되지 않은 변경사항이 있는 문서 창을 닫거나 앱을 종료하려 할 때 저장 확인 모달을 표시하고, 저장/저장하지 않음/취소 선택에 따라 창 닫기와 앱 종료를 제어한다.

## 현재 전제와 제약

- HostApp은 SwiftUI `WindowGroup` 기본 창과 `DocumentWindowPresenter`가 만드는 수동 `NSWindow` 창을 함께 사용한다.
- `DocumentViewerStore`는 문서 payload, 최근 문서, WebView loading/failure 상태를 소유하지만 현재 저장되지 않은 변경 여부는 소유하지 않는다.
- 저장 명령은 `RhwpStudioWebView.Coordinator`가 `window.__alhangeulHostBridgeExportHwpDocument?.('save-document')`를 실행하고, `save-document` message 수신 후 `DocumentSavePanel` 또는 원본 URL에 bytes를 쓰는 구조다.
- 현재 저장 command는 menu/shortcut command 중심이고, 창 닫기/앱 종료 흐름에서 저장 완료, 저장 취소, 저장 실패를 기다릴 수 있는 completion API가 없다.
- `AppDelegate`에는 `applicationWillTerminate(_:)`만 있고 `applicationShouldTerminate(_:)`는 없다.
- 수동 `DocumentWindowPresenter`는 `NSWindowDelegate.windowWillClose(_:)`에서 controller/toolbar controller만 정리한다.
- SwiftUI `WindowGroup` 기본 창은 현재 별도 close delegate가 연결되어 있지 않다.
- `rhwp-studio` bundled minified asset은 직접 수정하지 않는다. 변경 감지는 HostApp injected script와 native bridge에서 처리한다.
- `project.yml`이 Xcode project 원본이며 `Alhangeul.xcodeproj`는 직접 수정하지 않는다.
- `Sources/RhwpCoreBridge`에는 AppKit/UIKit/WebKit 의존을 추가하지 않는다. 이번 작업은 HostApp 경계에 한정한다.

## 구현 원칙

- 저장되지 않은 변경 상태의 source of truth는 `DocumentViewerStore`에 둔다.
- dirty signal은 bundled asset 직접 수정이 아니라 `RhwpStudioHostBridgeScript`의 injected bridge가 native message로 전달한다.
- dirty signal은 보수적으로 잡는다. false positive prompt는 허용 가능하지만, 명백한 저장/열기/인쇄/공유 같은 non-mutating native command는 dirty로 표시하지 않는다.
- 저장 성공, 새 문서 load, 저장하지 않고 닫기 승인 시 dirty state를 명시적으로 해제한다.
- 창 닫기와 앱 종료는 기존 저장 export/write 경로를 재사용한다. HWP bytes 생성/파일 쓰기 로직을 별도 구현으로 복제하지 않는다.
- 사용자가 저장 panel을 취소하거나 저장에 실패하면 창 닫기와 앱 종료는 중단한다.
- 앱 종료 중 여러 dirty 문서가 있으면 순차적으로 확인하고, 하나라도 취소되면 전체 종료를 중단한다.
- 문서 교체, 드래그 앤 드롭, 최근 문서 열기 전 저장 확인은 이번 범위에서 제외하고 후속 이슈 후보로 남긴다.

## Stage 1. 종료/창 닫기와 dirty signal inventory

### 목표

현재 창 lifecycle, app termination hook, 저장 bridge, `rhwp-studio` 변경 신호 후보를 조사해 구현 경계를 확정한다.

### 작업

1. `HostApp.swift`의 SwiftUI `WindowGroup` 기본 창과 `DocumentWindowPresenter` 수동 창 lifecycle을 정리한다.
2. `DocumentWindowLifecycle`, `WindowAccessor`, `DocumentWindowPresenter.windowWillClose(_:)`가 어떤 책임을 갖는지 확인한다.
3. `RhwpStudioWebView.Coordinator`의 저장 command flow를 `requestSaveDocument`, `requestSaveAsDocument`, `saveDocument`, `recordSavedDocument` 기준으로 정리한다.
4. `RhwpStudioHostBridgeScript`에서 dirty signal로 사용할 수 있는 DOM event, command click, keyboard/paste/drop hook 후보를 확인한다.
5. dirty false positive/false negative 위험과 제외 범위(문서 교체 전 확인 제외)를 단계 보고서에 기록한다.
6. close/terminate guard를 별도 coordinator로 만들지, 기존 `DocumentWindowPresenter`/`WindowAccessor`에 붙일지 최종 결정한다.
7. Stage 1 완료보고서를 작성한다.

### 예상 변경 파일

- `mydocs/working/task_m010_243_stage1.md`

### 검증

```bash
git status --short --branch
rg -n "applicationShouldTerminate|applicationWillTerminate|windowWillClose|WindowAccessor|DocumentWindowLifecycle|DocumentWindowPresenter|requestSaveDocument|saveDocument\\(|recordSavedDocument|document-changed|nativeCommands" \
  Sources/HostApp/HostApp.swift Sources/HostApp/Views/RhwpStudioWebView.swift Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift
git diff --check -- mydocs/working/task_m010_243_stage1.md
```

### 완료 기준

- 기본 창과 수동 창의 close hook 연결 지점이 기록된다.
- 저장 완료/취소/실패를 기다리기 위해 필요한 API 변경이 기록된다.
- dirty signal 후보와 한계가 기록된다.
- 제품 코드는 변경하지 않는다.

### 커밋 메시지

```text
Task #243 Stage 1: 종료 저장 확인 경로 조사
```

## Stage 2. dirty state bridge와 store 상태 구현

### 목표

WKWebView 안에서 발생한 문서 변경 후보를 HostApp으로 전달하고, `DocumentViewerStore`가 현재 문서의 저장되지 않은 변경 여부를 소유하게 한다.

### 작업

1. `DocumentViewerStore`에 저장되지 않은 변경 상태를 추가한다.
   - 예: `@Published private(set) var hasUnsavedChanges = false`
   - 새 문서 load와 `clearCurrentDocument()`에서 false로 초기화한다.
   - 저장 완료 시 false로 해제한다.
2. `RhwpStudioWebView`에 dirty callback을 추가한다.
   - 예: `onDocumentEdited: () -> Void`
   - `DocumentViewerView`에서 store dirty marker로 연결한다.
3. `RhwpStudioHostBridgeScript`에서 변경 후보를 native로 post한다.
   - keyboard editing, paste/cut/drop, input/change/beforeinput, mutating toolbar/menu command click을 우선 후보로 둔다.
   - `file:open`, `file:save`, `file:save-as`, `file:print`, `file:share`, `file:export-pdf`, zoom/view-only command는 dirty marker에서 제외한다.
4. 중복 dirty message가 과도하게 올라오지 않도록 script 또는 store에서 이미 dirty인 상태의 반복 post를 억제한다.
5. native message handler에 `document-edited` case를 추가한다.
6. Stage 2 완료보고서를 작성한다.

### 예상 변경 파일

- `Sources/HostApp/Stores/DocumentViewerStore.swift`
- `Sources/HostApp/Views/DocumentViewerView.swift`
- `Sources/HostApp/Views/RhwpStudioWebView.swift`
- `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift`
- `mydocs/working/task_m010_243_stage2.md`

### 검증

```bash
git diff --check -- Sources/HostApp/Stores/DocumentViewerStore.swift Sources/HostApp/Views/DocumentViewerView.swift Sources/HostApp/Views/RhwpStudioWebView.swift Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift mydocs/working/task_m010_243_stage2.md
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask243Stage2 \
  CODE_SIGNING_ALLOWED=NO \
  build
rg -n "hasUnsavedChanges|mark.*Unsaved|document-edited|onDocumentEdited|dirty|unsaved" Sources/HostApp
```

수동 smoke:

```text
1. Debug HostApp으로 HWP 문서 열기
2. 문서에 텍스트 입력 또는 편집성 command 실행
3. store/log/창 상태 기준 dirty marker가 true가 되는지 확인
4. 저장 후 dirty marker가 false로 해제되는지 확인
5. 인쇄/공유/PDF export 등 non-mutating command가 dirty로 표시되지 않는지 가능한 범위에서 확인
```

### 완료 기준

- HostApp store가 문서별 unsaved state를 갖는다.
- WebView bridge가 편집 후보를 native로 전달한다.
- 새 문서 load와 저장 완료 시 unsaved state가 false로 정리된다.
- 기존 저장/공유/PDF/인쇄 command가 컴파일 회귀 없이 유지된다.

### 커밋 메시지

```text
Task #243 Stage 2: WebView 편집 상태 추적 추가
```

## Stage 3. 저장 completion API와 창 닫기 확인 구현

### 목표

개별 문서 창 닫기 요청을 가로채 저장 확인 모달을 표시하고, 사용자의 선택과 저장 결과에 따라 창 닫기를 이어가거나 중단한다.

### 작업

1. 기존 save flow를 close guard에서 재사용할 수 있도록 completion API를 추가한다.
   - 저장 성공, 사용자 취소, 저장 실패를 구분하는 result type을 둔다.
   - 기존 menu/shortcut 저장 동작은 현재 UX를 유지한다.
2. `RhwpStudioNativeCommandWebView` 또는 dispatcher에 특정 window의 문서를 저장하고 completion을 받을 수 있는 narrow API를 추가한다.
3. 저장 확인 모달을 담당하는 작은 coordinator를 HostApp 영역에 추가한다.
   - `저장`
   - `저장하지 않음`
   - `취소`
4. SwiftUI `WindowGroup` 기본 창에 close delegate 또는 window close guard를 연결한다.
5. `DocumentWindowPresenter` 수동 창에도 같은 close guard를 연결한다.
6. programmatic close 중 재진입을 막기 위한 bypass flag를 창별로 둔다.
7. 저장하지 않고 닫기를 선택하면 store dirty state를 정리한 뒤 닫는다.
8. Stage 3 완료보고서를 작성한다.

### 예상 변경 파일

- `Sources/HostApp/HostApp.swift`
- `Sources/HostApp/Views/RhwpStudioWebView.swift`
- `Sources/HostApp/Stores/DocumentViewerStore.swift`
- 신규 `Sources/HostApp/Services/DocumentCloseConfirmationController.swift` 또는 유사 파일 (필요 시)
- `mydocs/working/task_m010_243_stage3.md`

### 검증

```bash
git diff --check -- Sources/HostApp/HostApp.swift Sources/HostApp/Views/RhwpStudioWebView.swift Sources/HostApp/Stores/DocumentViewerStore.swift Sources/HostApp/Services mydocs/working/task_m010_243_stage3.md
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask243Stage3 \
  CODE_SIGNING_ALLOWED=NO \
  build
rg -n "windowShouldClose|DocumentClose|Unsaved|저장하지 않음|저장되지 않은|save.*completion|bypass" Sources/HostApp
```

수동 smoke:

```text
1. Debug HostApp으로 HWP 문서 열기
2. 편집 후 창 닫기 버튼 클릭
3. 취소 선택 시 창이 유지되는지 확인
4. 저장하지 않음 선택 시 창이 닫히는지 확인
5. 다시 열고 편집 후 저장 선택 시 기존 저장 경로로 저장된 뒤 창이 닫히는지 확인
6. 저장 panel에서 취소하면 창이 유지되는지 확인
```

### 완료 기준

- dirty 문서 창 닫기 요청에서 저장 확인 모달이 표시된다.
- `취소`와 저장 panel 취소는 창 닫기를 중단한다.
- `저장하지 않음`은 창을 닫고 dirty state를 남기지 않는다.
- `저장`은 저장 성공 후 창을 닫고, 저장 실패 시 창을 유지한다.
- 기본 SwiftUI 창과 수동 문서 창 모두 같은 정책을 따른다.

### 커밋 메시지

```text
Task #243 Stage 3: 문서 창 닫기 저장 확인 추가
```

## Stage 4. 앱 종료 저장 확인 구현

### 목표

앱 전체 종료 요청에서 dirty 문서 창들을 순차적으로 확인하고, 저장 결과에 따라 termination을 완료하거나 취소한다.

### 작업

1. `AppDelegate.applicationShouldTerminate(_:)`를 추가한다.
2. dirty 문서가 없으면 `.terminateNow`를 반환한다.
3. dirty 문서가 있으면 `.terminateLater`를 반환하고 async confirmation sequence를 시작한다.
4. dirty 문서 window/store 쌍을 안정적으로 수집할 수 있도록 window close guard registry를 둔다.
5. dirty 문서를 순차적으로 확인한다.
   - 저장 성공 또는 저장하지 않음이면 다음 dirty 문서로 진행한다.
   - 취소 또는 저장 실패면 `reply(toApplicationShouldTerminate: false)`를 호출한다.
6. 모든 dirty 문서가 정리되면 `reply(toApplicationShouldTerminate: true)`를 호출한다.
7. 앱 종료 confirmation 중 일반 window close guard와 재진입이 충돌하지 않도록 guard state를 정리한다.
8. Stage 4 완료보고서를 작성한다.

### 예상 변경 파일

- `Sources/HostApp/HostApp.swift`
- `Sources/HostApp/Stores/DocumentViewerStore.swift`
- `Sources/HostApp/Views/RhwpStudioWebView.swift` (completion API 보정 필요 시)
- 신규 `Sources/HostApp/Services/DocumentTerminationCoordinator.swift` 또는 유사 파일 (필요 시)
- `mydocs/working/task_m010_243_stage4.md`

### 검증

```bash
git diff --check -- Sources/HostApp/HostApp.swift Sources/HostApp/Stores/DocumentViewerStore.swift Sources/HostApp/Views/RhwpStudioWebView.swift Sources/HostApp/Services mydocs/working/task_m010_243_stage4.md
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask243Stage4 \
  CODE_SIGNING_ALLOWED=NO \
  build
rg -n "applicationShouldTerminate|terminateLater|reply\\(toApplicationShouldTerminate|termination|DocumentTermination|unsaved" Sources/HostApp
```

수동 smoke:

```text
1. Debug HostApp에서 dirty 문서 1개를 만든 뒤 Command+Q 실행
2. 취소 선택 시 앱이 종료되지 않는지 확인
3. 저장하지 않음 선택 시 앱이 종료되는지 확인
4. 저장 선택 시 저장 성공 후 앱이 종료되는지 확인
5. dirty 문서 2개를 연 뒤 Command+Q에서 순차 확인이 동작하는지 확인
6. 첫 번째 또는 두 번째 문서에서 취소하면 앱 종료 전체가 중단되는지 확인
```

### 완료 기준

- 앱 종료 시 dirty 문서가 없으면 기존처럼 종료된다.
- dirty 문서가 있으면 저장 확인 흐름이 표시된다.
- 사용자가 어느 문서에서든 취소하면 앱 종료가 중단된다.
- 모든 dirty 문서를 저장하거나 저장하지 않기로 선택하면 앱 종료가 재개된다.
- termination response가 중복 호출되지 않는다.

### 커밋 메시지

```text
Task #243 Stage 4: 앱 종료 저장 확인 추가
```

## Stage 5. 통합 검증과 최종 보고

### 목표

창 닫기와 앱 종료 저장 확인 기능이 기존 저장/공유/PDF/WebView 흐름을 깨지 않는지 확인하고, 결과를 보고서에 정리한다.

### 작업

1. `./scripts/check-no-appkit.sh`로 bridge 경계 회귀를 확인한다.
2. `xcodegen generate` 후 HostApp Debug build를 수행한다.
3. `scripts/verify-rhwp-studio-assets.sh`로 bundled viewer asset을 확인한다.
4. 창 닫기 저장/저장하지 않음/취소 수동 smoke를 수행한다.
5. 앱 종료 저장/저장하지 않음/취소 수동 smoke를 수행한다.
6. 기존 저장, 다른 이름으로 저장, 공유, PDF export, 인쇄 command 회귀를 가능한 범위에서 확인한다.
7. `mydocs/orders/20260514.md`에서 #243 상태를 완료로 갱신한다.
8. `mydocs/report/task_m010_243_report.md`를 작성한다.
9. Stage 5 완료보고서를 작성한다.

### 예상 변경 파일

- `mydocs/orders/20260514.md`
- `mydocs/working/task_m010_243_stage5.md`
- `mydocs/report/task_m010_243_report.md`

### 검증

```bash
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask243 \
  CODE_SIGNING_ALLOWED=NO \
  build
scripts/verify-rhwp-studio-assets.sh
scripts/verify-rhwp-studio-assets.sh build.noindex/DerivedDataTask243/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
rg -n "Task M010 #243|#243|저장되지 않은|저장하지 않음|applicationShouldTerminate|windowShouldClose|hasUnsavedChanges|document-edited" \
  Sources/HostApp mydocs/orders/20260514.md mydocs/plans/task_m010_243.md mydocs/plans/task_m010_243_impl.md mydocs/working mydocs/report
git diff --check
git status --short
```

수동 smoke:

```text
1. HWP 문서 편집 후 창 닫기: 취소, 저장하지 않음, 저장 성공 확인
2. HWP 문서 편집 후 앱 종료: 취소, 저장하지 않음, 저장 성공 확인
3. 저장 panel 취소 시 창 닫기/앱 종료 중단 확인
4. dirty 문서 2개 앱 종료 순차 확인
5. 저장 후 다시 창 닫기/앱 종료 시 불필요한 저장 확인이 표시되지 않는지 확인
6. 기존 Command+S, Command+Shift+S, 공유, PDF export, 인쇄 command 기본 동작 확인
```

### 완료 기준

- build와 정적 검증이 통과한다.
- 창 닫기와 앱 종료에서 저장 확인 모달이 요구대로 동작한다.
- 저장 취소/실패 시 데이터 유실로 이어지는 종료가 진행되지 않는다.
- 기존 저장 command와 WebView asset 검증이 회귀하지 않는다.
- 최종 보고서와 오늘할일 완료 갱신이 준비된다.

### 커밋 메시지

```text
Task #243 Stage 5 + 최종 보고서: 종료 저장 확인 완료
```

## 승인 요청 사항

1. 위 5단계 구현계획 승인
2. Stage 1에서 종료/창 닫기와 dirty signal inventory부터 진행 승인
