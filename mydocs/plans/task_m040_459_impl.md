# Task M040 #459 구현계획서

수행계획서: `mydocs/plans/task_m040_459.md`

## 1. 작업 개요

- 이슈: [#459 PDF·인쇄 lifecycle에서 중복 요청과 stale navigation callback 방어](https://github.com/postmelee/alhangeul-macos/issues/459)
- 마일스톤: `M040` (`v0.4`)
- 대상 통합 브랜치: `devel`
- 작업 브랜치: `local/task459`
- 게시 브랜치: `publish/task459`
- 기준 커밋: `cb3ee87cd7d14bcd0da26fbedecd8939a9fc73f8`
- 단계 수: 4

현재 일반 인쇄 진입점은 요청마다 `RhwpStudioPrintController`를 새로 만들어 coordinator의 단일 슬롯을 교체하고, completion은 controller identity를 확인하지 않은 채 슬롯을 비운다. 공용 `RhwpStudioPagePDFRenderer`는 navigation delegate와 비동기 JavaScript·`createPDF`·timeout callback이 현재 render/page 세대인지 구분하지 않는다. 이 작업은 인쇄 controller 소유권을 명시적인 lifecycle 객체로 고정하고, renderer의 모든 비동기 경계에 generation/page/navigation token을 적용해 이전 작업의 늦은 callback이 새 작업을 변경하지 못하게 한다.

구현계획 승인 전에는 Stage 1을 시작하지 않는다. 각 Stage 종료 뒤에는 `task-stage-report` 절차로 소스·테스트·단계 보고서를 함께 커밋하고 다음 단계 승인을 받는다. Bundled `rhwp-studio`, Rust core, Quick Look·Thumbnail, 공개 릴리스·서명·공증은 어느 Stage에서도 변경하거나 실행하지 않는다.

## 2. 구현 전 확인 결과

| 항목 | 현재 상태 | 구현 영향 |
|------|-----------|-----------|
| 인쇄 요청 소유 | `RhwpStudioWebView.Coordinator`가 `private var printController` 한 개를 보유하고 요청마다 새 controller로 교체한다. | controller 생성 전에 중복을 거부하고, 현재 identity와 일치하는 completion만 슬롯을 해제해야 한다. |
| 인쇄 completion | completion은 항상 `self?.printController = nil`을 실행한다. | 첫 controller의 늦거나 중복된 completion이 후속 controller를 지우는 회귀를 재현할 test seam이 필요하다. |
| 인쇄 UI | `RhwpStudioPrintController`는 `NSPrintOperation.run()`으로 modal print panel을 실행한다. | 실제 panel을 단위 테스트에 사용하지 않고 controller factory와 lifecycle state로 ownership을 검증한다. |
| renderer 재진입 | `completion != nil`이면 `.renderingInProgress`를 반환하며 진행 중 중복 render는 이미 거부한다. | 기존 동작은 유지하고 종료 뒤 재사용 세대만 새로 식별한다. |
| navigation tracking | `loadHTMLString`이 반환한 `WKNavigation`을 보관하지 않으며 `didFinish`·`didFail`은 전달된 navigation을 확인하지 않는다. | page load마다 active navigation identity를 기록하고 delegate callback을 current token과 대조한다. |
| async page work | preparation JavaScript와 `createPDF` closure는 `!didFinish`만 확인하고 현재 page/generation은 확인하지 않는다. | closure 시작 시 generation/page token을 캡처하고 결과 적용 직전에 current 여부를 재검증한다. |
| timeout | timeout은 page index만 캡처한다. | 같은 page index로 재사용된 다음 render와 충돌하지 않도록 generation도 포함한다. |
| 종료 cleanup | `finish`는 `didFinish` 설정 뒤 timeout 취소와 `stopLoading()`을 수행하지만 navigation/delegate 세대는 없다. | generation을 먼저 무효화하고 delegate·navigation·pending-main-frame 상태를 정리한 뒤 load를 중단한다. |
| WebContent 종료 | callback이 어느 web view/render에 속하는지 확인하지 않고 현재 render를 실패시킨다. | owned web view와 active generation일 때만 current render를 종료하도록 한다. |
| Host bridge observer | native PDF menu override는 `aria-label`을 복원하지만 observer filter는 `class`, `aria-disabled`, `title`만 감시한다. | `aria-label`을 filter에 추가하고 기존 coalescing/exact-value guard를 유지한다. |
| 테스트 타깃 | `HostAppTests`는 `Tests/HostAppTests` 외 production service 파일을 `project.yml`에 개별 열거한다. | 신규 print lifecycle service를 테스트하려면 `project.yml`과 XcodeGen 생성 project에 source를 추가해야 한다. |
| 기존 회귀 | renderer test는 timeout, retry, selectable text, font, navigation allowlist와 WebContent 종료를 포함한다. | 기존 보안·품질 계약을 유지하면서 lifecycle identity test를 추가한다. |

## 3. 공통 설계·안전 계약

### 3.1 인쇄 lifecycle의 단일 소유권

- `RhwpStudioWebView.Coordinator`에서 직접 controller 슬롯과 completion identity를 관리하지 않고, HostApp 내부 `@MainActor` lifecycle 객체로 해당 책임을 모은다.
- lifecycle은 `RhwpStudioPrintControlling: AnyObject` 같은 최소 protocol과 controller factory를 사용한다. Production factory의 기본 구현만 실제 `RhwpStudioPrintController`를 만든다.
- `start(payload:onError:)`는 active controller 유무를 controller 생성보다 먼저 검사한다. 이미 진행 중이면 factory를 호출하지 않고 기존 controller를 유지하며, 기존 HostApp 오류 표시 경로에 사용자가 이해할 수 있는 `인쇄가 이미 진행 중입니다.` 계열 오류를 정확히 한 번 전달한다.
- 새 controller를 active 슬롯에 저장한 뒤 인쇄를 시작한다. Completion은 캡처한 controller와 active controller가 동일한 경우에만 슬롯을 해제한다.
- 첫 completion으로 슬롯을 해제한 뒤 새 controller가 시작된 상태에서 이전 completion이 다시 도착해도 새 슬롯은 유지한다. 실제 controller가 exactly-once completion을 보장하더라도 coordinator 경계는 해당 가정에 의존하지 않는다.
- 정상·실패·사용자 취소는 controller completion의 동일 경로로 수렴하고 다음 요청을 허용한다. Controller나 lifecycle이 error closure·payload·PDF document를 완료 이후 계속 보유하지 않는다.
- Test-only 분기나 실제 print panel 자동화 없이 fake controller와 factory 호출 수로 중복 거부, identity 해제와 재진입을 검증한다.

### 3.2 Renderer generation/page/navigation token

- Renderer instance는 재사용 중에도 되돌아가지 않는 단조 증가 generation을 발급한다. Generation 값은 외부 API나 문서 payload에 노출하지 않는 HostApp 내부 식별자다.
- Render 시작 시 `generation + page index`로 page token을 만들고 `loadHTMLString`이 반환한 `WKNavigation`의 `ObjectIdentifier`를 active navigation identity로 연결한다.
- `didFinish`, `didFail`, provisional failure는 callback의 web view와 navigation identity가 현재 active token과 일치할 때만 처리한다. Nil이거나 이전 navigation이면 current document, page index, timeout과 completion을 변경하지 않는다.
- `decidePolicyFor`는 현재 active generation의 initial main-frame pending 상태만 소비한다. 기존 `about:blank` initial load 1회 허용과 그 밖의 navigation 차단 정책을 넓히지 않는다.
- Preparation JavaScript, `createPDF`, page append와 timeout closure는 시작 시 page token을 캡처하고 결과 적용 직전에 다시 current 여부를 확인한다. 같은 page index를 사용하는 다음 render라도 generation이 다르면 stale로 간주한다.
- `webViewWebContentProcessDidTerminate`는 renderer가 소유한 web view이고 active generation이 있을 때만 그 세대를 실패시킨다.
- `WKNavigation`을 직접 생성하기 어려운 단위 테스트는 production renderer가 사용하는 작은 내부 state/token seam에 `ObjectIdentifier`를 주입해 검증한다. 별도 mock renderer나 public API는 만들지 않는다.

### 3.3 종료와 재사용 순서

- `finish`는 generation별 exactly-once gate를 먼저 통과한 뒤 active token과 initial pending state를 무효화한다.
- Navigation delegate를 해제하거나 current token을 지운 다음 watchdog을 취소하고 `stopLoading()`을 호출해 cleanup에서 발생한 늦은 delegate callback이 무해하도록 한다.
- Completion, payload, rendered document와 page index는 기존처럼 종료 뒤 해제한다. 사용자 completion은 내부 상태가 idle로 복귀한 뒤 한 번만 호출한다.
- 다음 `render` 시작 시 delegate, generation, empty document, page index와 main-frame pending 상태를 새 세대에 맞게 다시 설정한다.
- Stale callback 무시는 현재 timeout을 취소하거나 재시작하지 않으며, stale error를 사용자에게 전달하지 않는다.
- 진행 중 두 번째 `render`의 `.renderingInProgress` 동작과 기존 timeout error 문구는 변경하지 않는다.

### 3.4 보안·품질·UI 경계

- Content JavaScript 비활성, non-persistent data store, custom font scheme, page preparation, navigation allowlist와 external resource 차단 정책을 유지한다.
- PDF page geometry, orientation, page count, embedded font와 selectable text 계약을 변경하지 않는다.
- 중복 인쇄 오류는 기존 coordinator `onError` presentation을 사용하고 별도 modal 계층이나 취소 UI를 추가하지 않는다.
- `aria-label` observer 보완은 native PDF menu item 하나에만 적용하며 exact-value guard와 frame 단위 refresh coalescing을 유지한다.
- `Sources/RhwpCoreBridge`에 AppKit/UIKit 의존을 추가하지 않는다.
- Xcode target의 유일한 편집 원본은 `project.yml`이다. `Alhangeul.xcodeproj/project.pbxproj`는 직접 수정하지 않고 XcodeGen 결과만 반영한다.

## 4. Stage 1 — 인쇄 재진입·identity 방어와 메뉴 observer 보완

### 4.1 목적

실제 print panel을 띄우지 않는 작은 lifecycle 경계에서 두 번째 인쇄 요청을 거부하고 controller identity가 일치하는 completion만 active 슬롯을 해제하도록 한다. 함께 남은 독립적인 Host bridge `aria-label` observer 누락을 보완한다.

### 4.2 예상 변경 파일

- `Sources/HostApp/Services/RhwpStudioPrintLifecycle.swift` (신규 예상)
- `Sources/HostApp/Services/RhwpStudioPrintController.swift`
- `Sources/HostApp/Views/RhwpStudioWebView.swift`
- `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift`
- `Tests/HostAppTests/RhwpStudioPrintLifecycleTests.swift` (신규 예상)
- `Tests/HostAppTests/RhwpStudioHostBridgeScriptTests.swift`
- `project.yml`
- `Alhangeul.xcodeproj/project.pbxproj` (`xcodegen generate` 결과)
- `mydocs/working/task_m040_459_stage1.md`
- `mydocs/orders/20260826.md`

구현 중 기존 파일 안의 작은 internal state로 충분하다고 확인되면 신규 lifecycle 파일은 만들지 않을 수 있다. 다만 실제 coordinator와 다른 전이를 테스트하는 test-only 복제는 허용하지 않는다.

### 4.3 구현 항목

1. `RhwpStudioPrintControlling` 최소 protocol과 factory를 정의하고 `RhwpStudioPrintController`를 연결한다.
2. Active controller를 보유하는 `@MainActor` lifecycle 객체에 중복 검사, 생성, 시작과 identity 기반 completion 해제를 모은다.
3. Coordinator는 payload validation 뒤 lifecycle에 요청을 위임하고 기존 `onError`로 중복 오류를 전달한다.
4. 중복 요청에서는 active controller, factory 호출 수와 첫 completion을 변경하지 않는다.
5. 이전 controller completion이 두 번 도착하는 fixture를 사용해 후속 controller 슬롯이 유지되는지 검증한다.
6. 정상·실패·취소를 나타내는 completion 뒤 다음 요청이 수락되는지 검증한다.
7. Host bridge observer filter에 `aria-label`을 추가하고 canonical title/label 복원과 mutation loop 방지 source 계약을 보강한다.
8. `project.yml`에 lifecycle production source를 HostAppTests source로 추가하고 XcodeGen으로 project를 재생성한다.

### 4.4 필수 자동 회귀

- 첫 요청: factory 1회, controller start 1회, active 유지
- 진행 중 두 번째 요청: factory 추가 0회, 첫 controller 교체 0회, 사용자 오류 1회
- 첫 controller 완료: active 해제, 다음 요청 수락
- 이전 controller의 중복·늦은 완료: 현재 두 번째 controller 해제 0회
- 두 번째 controller 완료: active 해제, 세 번째 요청 수락
- Lifecycle deallocation/completion closure: retain cycle 없음
- Host bridge: observer filter가 `class`, `aria-disabled`, `title`, `aria-label`을 포함
- Host bridge: canonical value guard와 scheduled refresh coalescing 유지

### 4.5 검증

```bash
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostAppTests \
  -configuration Debug \
  -derivedDataPath build.noindex/task459-stage1-tests \
  CODE_SIGNING_ALLOWED=NO \
  test
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/task459-stage1-build \
  CODE_SIGNING_ALLOWED=NO \
  build
./scripts/check-no-appkit.sh
git diff --check
```

### 4.6 완료 기준

- 진행 중 인쇄를 두 번째 요청이 교체하지 않는다.
- 중복 요청은 명시적 오류를 한 번 전달하고 새 controller를 만들지 않는다.
- Controller identity가 일치하는 completion만 슬롯을 해제한다.
- 완료 뒤 재진입이 자동 테스트로 고정된다.
- `aria-label` 단독 변경도 observer refresh 대상이 된다.
- XcodeGen 두 번째 실행에서 추가 diff가 없다.

### 4.7 커밋

`Task #459 Stage 1: 인쇄 lifecycle 재진입과 identity 방어`

## 5. Stage 2 — Renderer generation과 stale callback 차단

### 5.1 목적

Renderer의 render/page/navigation 세대를 명시적으로 식별하고, navigation delegate부터 preparation·`createPDF`·timeout까지 모든 비동기 결과가 현재 token일 때만 상태를 변경하도록 한다.

### 5.2 예상 변경 파일

- `Sources/HostApp/Services/RhwpStudioPagePDFRenderer.swift`
- `Tests/HostAppTests/RhwpStudioPagePDFRendererTests.swift`
- 필요 시 `Sources/HostApp/Services/RhwpStudioPagePDFRenderLifecycle.swift` (state seam 분리가 더 명확한 경우만)
- 필요 시 `project.yml`
- `Alhangeul.xcodeproj/project.pbxproj` (`project.yml` 변경 시 XcodeGen 결과)
- `mydocs/working/task_m040_459_stage2.md`
- `mydocs/orders/20260826.md`

### 5.3 구현 항목

1. 단조 증가 generation과 `generation + page index` page token을 도입한다.
2. `loadHTMLString` 반환 navigation을 active page token에 연결한다.
3. `didFinish`, `didFail`, provisional failure에서 owned web view와 active navigation identity를 확인한다.
4. Preparation JavaScript와 `createPDF` closure가 캡처 token을 다시 확인한 뒤에만 page size, PDF append 또는 failure를 적용하게 한다.
5. Timeout closure가 generation/page token을 검사하고 current page만 종료하게 한다.
6. WebContent process 종료는 owned web view와 active generation일 때만 current render를 실패시킨다.
7. Stale callback은 무시만 하고 current watchdog, page index, rendered document와 completion을 변경하지 않게 한다.
8. 기존 진행 중 중복 render 거부, navigation allowlist, font preparation과 PDF 검증 오류를 유지한다.

### 5.4 필수 자동 회귀

- 새 render마다 generation 증가, page 이동 시 같은 generation의 page index 증가
- 이전 navigation의 finish/failure가 current page render 시작·종료 0회
- Current navigation finish만 preparation 진행
- 이전 generation preparation 성공/실패가 current renderer 상태 변경 0회
- 이전 generation `createPDF` 성공/실패가 page append/completion 0회
- 이전 generation timeout이 current render 종료 0회
- 다른 web view의 process termination이 current render 종료 0회
- Current process termination은 completion 1회와 기존 error 반환
- 진행 중 두 번째 render는 `.renderingInProgress` 유지

### 5.5 검증

```bash
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostAppTests \
  -configuration Debug \
  -derivedDataPath build.noindex/task459-stage2-tests \
  CODE_SIGNING_ALLOWED=NO \
  test
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/task459-stage2-build \
  CODE_SIGNING_ALLOWED=NO \
  build
./scripts/check-no-appkit.sh
git diff --check
```

### 5.6 완료 기준

- Navigation delegate와 모든 async closure가 current token을 검사한다.
- 이전 generation의 callback이 새 render의 page, timeout과 completion을 변경하지 않는다.
- Current failure와 success는 generation별 exactly once completion을 유지한다.
- 기존 renderer 보안·font·geometry·text 선택성 테스트가 통과한다.

### 5.7 커밋

`Task #459 Stage 2: renderer generation과 stale callback 차단`

## 6. Stage 3 — 종료 cleanup·재사용 통합 회귀

### 6.1 목적

정상·오류·timeout·process 종료의 cleanup 순서를 하나의 계약으로 고정하고, 동일 renderer와 print lifecycle을 연속 요청에서 재사용해도 이전 세대가 새 작업을 방해하지 않는지 통합 검증한다.

### 6.2 예상 변경 파일

- `Sources/HostApp/Services/RhwpStudioPagePDFRenderer.swift` (cleanup 보정이 필요한 경우)
- `Sources/HostApp/Services/RhwpStudioPrintLifecycle.swift` (통합 회귀에서 보정이 필요한 경우)
- `Tests/HostAppTests/RhwpStudioPagePDFRendererTests.swift`
- `Tests/HostAppTests/RhwpStudioPrintLifecycleTests.swift`
- `mydocs/working/task_m040_459_stage3.md`
- `mydocs/orders/20260826.md`

Stage 3는 새로운 기능 범위를 추가하지 않는다. Stage 1·2의 실제 연속 lifecycle에서 확인된 cleanup·재사용 결함만 보정한다.

### 6.3 구현·검증 항목

1. `finish`가 active generation 무효화, delegate/navigation 정리, timeout 취소, load 중단, payload/document 해제, completion 호출 순서를 지키는지 확인한다.
2. 정상 1-page/다중-page 완료 뒤 같은 renderer의 다음 render가 새 generation으로 성공하는지 검증한다.
3. Navigation failure, preparation failure, PDF encoding failure, timeout과 process 종료 각각 뒤 다음 render가 진입하는지 검증한다.
4. 첫 render 종료와 두 번째 render 시작 사이에 첫 navigation/async/timeout callback을 다시 전달해 두 번째 completion이 유지되는지 검증한다.
5. Completion 안에서 즉시 새 render를 시작해도 내부 상태가 idle이고 delegate가 새 generation에 연결되는지 검증한다.
6. Print lifecycle도 completion 안 또는 직후 다음 요청을 시작하는 fixture에서 active controller identity가 유지되는지 재확인한다.
7. Existing CSP, external resource 차단, font readiness, selectable text, geometry, orientation와 page count 회귀 전체를 실행한다.
8. 필요하면 합성 1~2 page payload로 print panel 취소 후 재진입 smoke를 수행하되 production 문서·printer spool은 사용하지 않는다.

### 6.4 검증

```bash
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostAppTests \
  -configuration Debug \
  -derivedDataPath build.noindex/task459-stage3-tests \
  CODE_SIGNING_ALLOWED=NO \
  test
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/task459-stage3-build \
  CODE_SIGNING_ALLOWED=NO \
  build
./scripts/check-no-appkit.sh
./scripts/verify-rhwp-studio-assets.sh
git diff --check
```

### 6.5 완료 기준

- 모든 종료 유형에서 내부 상태가 completion 전에 idle로 복귀한다.
- 종료 뒤 동일 renderer와 print lifecycle의 다음 요청이 정상 수락된다.
- 이전 callback과 새 render가 겹쳐도 generation별 completion은 각각 최대 1회다.
- 기존 PDF 출력 품질·보안과 HostApp 전체 test/build가 통과한다.
- 수동 print panel smoke를 수행한 경우 개발 산출물이나 등록 상태를 남기지 않는다.

### 6.6 커밋

`Task #459 Stage 3: PDF·인쇄 lifecycle cleanup과 재사용 회귀 보강`

## 7. Stage 4 — Architecture 계약과 최종 수용 검증

### 7.1 목적

인쇄 controller 소유권, renderer generation과 종료 cleanup을 장기 architecture 계약으로 기록하고 Issue #459 완료 조건을 전체 산출물에서 최종 확인한다.

### 7.2 예상 변경 파일

- `mydocs/tech/project_architecture.md`
- `mydocs/working/task_m040_459_stage4.md`
- `mydocs/orders/20260826.md`

필요한 architecture 절만 최소 수정한다. Stage 4에서 제품 source나 test 동작 변경이 필요해지면 문서 단계에 섞지 않고 Stage 3 보정으로 되돌아가 승인 경계를 유지한다.

### 7.3 문서화 항목

- Coordinator가 print lifecycle에 요청을 위임하고 active controller identity가 단일 ownership 기준이라는 계약
- 중복 인쇄는 기존 작업을 유지하면서 명시적으로 거부하고 controller factory를 호출하지 않는 계약
- Renderer가 generation/page/navigation token을 소유하고 navigation delegate·JavaScript·`createPDF`·timeout 결과를 current token에만 적용하는 계약
- `finish`의 generation 무효화, delegate/navigation/watchdog/load/payload 정리 순서와 completion exactly-once 계약
- 동일 renderer의 정상·실패·timeout 뒤 재사용 계약
- `WKNavigation`과 actual `NSPrintOperation`을 deterministic하게 직접 합성하지 못하는 자동 검증 한계와 state seam·최소 smoke의 역할

### 7.4 최종 검증

```bash
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostAppTests \
  -configuration Debug \
  -derivedDataPath build.noindex/task459-stage4-tests \
  CODE_SIGNING_ALLOWED=NO \
  test
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/task459-stage4-build \
  CODE_SIGNING_ALLOWED=NO \
  build
./scripts/check-no-appkit.sh
./scripts/verify-rhwp-studio-assets.sh
./scripts/check-extension-registration-hygiene.sh
git diff --check
```

추가 확인:

- `xcodegen generate`를 두 번 실행해 두 번째 실행의 추가 diff가 없는지 확인
- `project.yml`과 generated project의 신규 source membership 일치 확인
- Task #459 변경이 HostApp과 HostAppTests에 한정되고 core, bundled asset, Quick Look·Thumbnail diff가 없는지 확인
- Issue 완료 조건별 test 이름·build 결과·문서 근거를 Stage 4 보고서에 연결

### 7.5 완료 기준

- Architecture 문서가 실제 production ownership과 generation 전이를 정확히 설명한다.
- 중복 인쇄 거부, controller identity, stale navigation/async callback 차단과 재진입 완료 조건이 자동 검증된다.
- HostAppTests 전체와 HostApp Debug build, AppKit 경계와 asset 검증이 통과한다.
- XcodeGen 재생성 정합성이 유지되고 예상 밖 source·asset·extension 변경이 없다.

### 7.6 커밋

`Task #459 Stage 4: PDF·인쇄 lifecycle architecture와 최종 검증`

## 8. 중단·보정 기준

1. `NSPrintOperation`을 직접 띄우지 않고는 controller ownership을 검증할 수 없다면 불안정한 UI test를 즉시 추가하지 않는다. Protocol/factory seam의 production 연결 근거를 먼저 보고하고 범위 변경 승인을 요청한다.
2. Lifecycle 분리가 인쇄 외 coordinator command routing이나 PDF export state를 함께 바꾸게 되면 구현을 중단한다. PDF export request identity 재설계는 이번 범위가 아니다.
3. WebKit이 전달하는 nil navigation 또는 callback 순서 때문에 identity만으로 current 판정이 불가능하면 모든 callback을 허용하는 fallback을 만들지 않는다. Delegate 재설정, load token seam 또는 web view 재생성 중 최소 위험 대안을 Stage 보고에서 비교하고 승인받는다.
4. `stopLoading()` 뒤 callback을 차단하려고 renderer 전체를 매 요청 새로 만드는 구조가 필요해지면 font scheme handler·resource lifetime·성능 영향이 커지므로 별도 보정 승인을 받는다.
5. Stale callback 회귀를 위해 production API를 public으로 노출하거나 test-only 조건 분기를 넣어야 한다면 진행하지 않는다. 같은 전이를 사용하는 internal state seam으로 다시 설계한다.
6. 기존 CSP, navigation allowlist, selectable text, font 또는 page geometry test가 실패하면 lifecycle 변경과 무관하다고 단정하지 않고 해당 Stage에서 원인을 해결한다.
7. 실제 printer, production 문서, upstream asset 수정, Quick Look·Thumbnail 변경이나 공개 배포가 필요해지면 이번 이슈 범위를 확대하지 않는다.

## 9. 단계 승인·보고 경계

- Stage별 작업은 직전 단계 또는 구현계획 승인 후에만 시작한다.
- 각 Stage 완료 시 `task-stage-report`를 명시 적용해 `mydocs/working/task_m040_459_stage{N}.md`를 작성하고 관련 변경과 하나의 Stage 커밋으로 묶는다.
- 단계 검증이 실패하면 보고서·커밋을 만들지 않고 같은 Stage 안에서 원인을 해결한다. 설계나 범위가 달라지면 구현계획 보정 승인을 요청한다.
- Stage 4까지 승인된 뒤에만 `task-final-report` 절차로 최종 보고서, 오늘할일 완료 처리, 최종 커밋, `publish/task459` push와 `devel` 대상 PR을 진행한다.
- Issue #459는 PR merge 전까지 열린 상태로 유지한다.

## 10. 구현계획 승인 요청

1. Stage 1에서 protocol/factory 기반 print lifecycle로 중복 생성 0회와 controller identity 해제를 검증하는 방향 승인
2. 중복 인쇄는 진행 중 작업을 유지하고 기존 `onError` 경로로 명시적으로 거부하는 방향 승인
3. Stage 2에서 generation/page/navigation token을 navigation delegate, preparation, `createPDF`, timeout과 process 종료에 일관되게 적용하는 방향 승인
4. `WKNavigation` 직접 합성 대신 production renderer가 사용하는 internal state/token seam으로 stale callback을 단위 검증하는 방향 승인
5. Stage 3에서 모든 종료 유형 뒤 동일 객체 재사용과 completion 내부 즉시 재진입까지 통합 검증하는 방향 승인
6. Stage 4에서 architecture와 검증 한계를 문서화하고 전체 test/build·XcodeGen 정합성을 최종 확인하는 방향 승인
7. 위 4개 Stage, 중단 기준과 단계별 승인·보고 경계 승인 후 Stage 1 진행 승인
