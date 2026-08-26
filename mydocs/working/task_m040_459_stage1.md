# Task M040 #459 Stage 1 완료 보고서

## 단계 목적

실제 `NSPrintOperation`을 단위 테스트에서 실행하지 않고도 일반 인쇄의 단일 controller ownership을 검증할 lifecycle 경계를 만든다. 진행 중 두 번째 인쇄 요청은 기존 controller를 유지한 채 명시적으로 거부하고, 현재 controller identity와 일치하는 completion만 슬롯을 해제하게 한다. 함께 Host bridge의 native PDF 메뉴 observer가 `aria-label` 단독 변경도 감지하도록 보완한다.

## 산출물

| 파일 | 변경 내용 |
|------|-----------|
| `Sources/HostApp/Services/RhwpStudioPrintLifecycle.swift` | controller protocol·factory, 중복 거부와 identity 기반 completion 해제를 담당하는 신규 lifecycle |
| `Sources/HostApp/Services/RhwpStudioPrintController.swift` | 실제 인쇄 controller를 lifecycle protocol에 연결 |
| `Sources/HostApp/Views/RhwpStudioWebView.swift` | 직접 controller 슬롯을 제거하고 lifecycle 위임·기존 `onError` 오류 표시 연결 |
| `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift` | native PDF 메뉴 observer의 `attributeFilter`에 `aria-label` 추가 |
| `Tests/HostAppTests/RhwpStudioPrintLifecycleTests.swift` | 중복 거부, identity 해제, 재진입과 retain cycle 회귀 4개 추가 |
| `Tests/HostAppTests/RhwpStudioHostBridgeScriptTests.swift` | `aria-label` filter·canonical 복원·refresh coalescing source 계약 보강 |
| `project.yml` | 신규 lifecycle을 HostAppTests production source 목록에 추가 |
| `Alhangeul.xcodeproj/project.pbxproj` | XcodeGen 생성 결과로 HostApp·HostAppTests source membership 반영 |
| `mydocs/orders/20260826.md` | Stage 1 완료와 Stage 2 승인 대기 상태 반영 |

## 구현 결과

### 인쇄 controller ownership

`RhwpStudioPrintLifecycle`은 `@MainActor`에서 다음 전이를 단독으로 소유한다.

| 현재 상태 | 입력 | 결과 |
|-----------|------|------|
| idle | 첫 `start` | factory 1회 호출, controller를 active로 보관한 뒤 인쇄 시작 |
| active | 두 번째 `start` | factory 호출·controller 교체 없이 `.printingInProgress` 반환 |
| active | 현재 controller completion | identity 확인 뒤 active 슬롯 해제 |
| active | 이전 controller의 늦거나 중복된 completion | 현재 controller와 identity가 달라 무시 |
| idle | 완료 뒤 새 `start` | 새 controller 생성과 다음 인쇄 진입 허용 |

Lifecycle protocol은 `print(payload:completion:)` 한 메서드만 요구한다. Production의 `RhwpStudioPrintController`가 이를 채택하고, 테스트는 같은 lifecycle 전이에 fake controller factory를 주입한다. `NSPrintOperation`, renderer 또는 modal print panel을 mock하지 않으며 제품 전이를 테스트 코드에 복제하지 않는다.

Completion closure는 lifecycle과 캡처 controller를 모두 약하게 보유한다. Lifecycle이 active controller를 강하게 보유해 인쇄 중 lifetime을 보장하고, lifecycle이 해제되면 controller와 completion도 함께 해제된다. Controller completion이 정상·renderer 실패·print operation 생성 실패·사용자 취소 뒤 어느 경로에서 호출되더라도 lifecycle 관점에서는 같은 idle 전이로 수렴한다. 기존 `RhwpStudioPrintController.finish`의 exactly-once cleanup은 변경하지 않았다.

### Coordinator 연결과 사용자 오류

`RhwpStudioWebView.Coordinator`의 `printController` 슬롯과 무조건 `nil`로 만드는 completion을 제거했다. Validated page payload는 장기 보유되는 `printLifecycle`에 전달한다. 진행 중 요청이 있으면 lifecycle은 새 controller를 만들지 않고 `인쇄가 이미 진행 중입니다.` 오류를 반환하며, coordinator는 기존 `onError` presentation 경로에 그 문구를 전달한다.

PDF export의 `pdfExportController`, request identity와 renderer 코드는 변경하지 않았다. Stage 2 범위인 `RhwpStudioPagePDFRenderer` generation/navigation 상태도 이번 단계에서는 수정하지 않았다.

### Host bridge `aria-label` observer

Native PDF menu override는 기존부터 다음 exact-value guard를 사용했다.

- `title`이 canonical 문구와 다를 때만 다시 설정
- `aria-label`이 `PDF로 저장`과 다를 때만 다시 설정
- 연속 mutation은 `pendingHostOverridesRefresh`와 `requestAnimationFrame`으로 한 번에 합침

Observer filter에 `aria-label`을 추가해 upstream 또는 다른 script가 해당 속성만 변경해도 canonical label 복원이 예약된다. Exact-value guard와 frame 단위 coalescing은 그대로 유지해 override 자체가 무한 mutation loop를 만들지 않게 했다.

### Xcode target 정합성

HostApp은 `Sources/HostApp` 디렉터리를 제품 source로 포함하므로 신규 lifecycle을 자동으로 컴파일한다. Standalone `HostAppTests`는 production service를 개별 열거하므로 `project.yml`에 lifecycle source를 추가했다. `Alhangeul.xcodeproj`는 직접 편집하지 않고 `xcodegen generate` 결과만 반영했다.

연속 두 번째 XcodeGen 실행 전후 `project.pbxproj` SHA-1은 모두 `192e1cd7c42b3a80213fbdf7f3b8ab396a738ef0`으로 같았다. 생성 project에는 다음 변경만 있다.

- `RhwpStudioPrintLifecycle.swift`: HostApp·HostAppTests Sources
- `RhwpStudioPrintLifecycleTests.swift`: HostAppTests Sources

## 자동 회귀 결과

### 선택 테스트

신규 lifecycle과 Host bridge test class만 먼저 실행했다.

| 테스트 묶음 | 결과 |
|-------------|------|
| `RhwpStudioPrintLifecycleTests` | 4/4 통과 |
| `RhwpStudioHostBridgeScriptTests` | 6/6 통과 |
| 합계 | 10/10 통과, 실패 0 |

Lifecycle test가 확인한 항목:

- 중복 요청에서 factory 추가 호출 0회, 첫 controller start 1회, 두 번째 controller start 0회
- 중복 오류 1회와 사용자 문구 exact match
- 첫 controller 완료 뒤 두 번째 요청 수락
- 첫 controller의 중복 completion이 현재 두 번째 controller를 해제하지 않음
- 현재 두 번째 controller completion 뒤 세 번째 요청 수락
- 연속 completion 뒤 재진입 3회 성공
- Lifecycle과 controller 상호 retain cycle 없음

### 전체 검증

| 검증 | 결과 |
|------|------|
| `xcodegen generate` | 성공 |
| XcodeGen 연속 재생성 | 추가 diff 없음, project hash 동일 |
| 선택 `HostAppTests` | 10/10 통과 |
| 전체 `HostAppTests` | 167/167 통과, 실패·skip 0 |
| HostApp Debug unsigned build | 성공 |
| `./scripts/check-no-appkit.sh` | 통과 |
| `git diff --check` | 통과 |

전체 테스트 결과 bundle:

`build.noindex/task459-stage1-full-tests/Logs/Test/Test-HostAppTests-2026.08.26_17-33-25-+0900.xcresult`

최초 sandbox 선택 테스트는 Sparkle package clone 단계에서 GitHub DNS 접근 제한으로 종료됐다. 외부 package 접근이 허용된 동일 명령을 다시 실행해 exact pinned `Sparkle 2.9.1`을 해석한 뒤 모든 선택·전체 테스트와 제품 build가 성공했다. 이는 제품 코드나 test failure가 아니다.

전체 test link에는 macOS 12 deployment target과 Xcode의 XCTest 14 minimum version 차이에 대한 기존 warning이 출력됐지만 test 실행과 결과에는 영향이 없었다.

## 본문 변경 정도 / 본문 무손실 여부

- HWP/HWPX 문서 bytes, page SVG payload, PDF page 생성과 print output 내용은 변경하지 않았다.
- Bundled `rhwp-studio`, Rust core, Quick Look·Thumbnail과 PDF export source는 변경하지 않았다.
- 실제 print panel, printer spool과 사용자 문서를 사용하지 않았다.
- Build와 test 산출물은 ignored `build.noindex/task459-stage1-*` 아래에만 생성했다.
- `Sources/RhwpCoreBridge`에 AppKit/UIKit 의존이 추가되지 않았다.

## 잔여 위험

- Coordinator는 중복 여부를 page payload validation 뒤 lifecycle에서 판단한다. 중복 요청의 controller 생성과 교체는 완전히 차단하지만 Web bridge가 이미 수집한 page payload 비용은 발생할 수 있다. Host command protocol에 별도 request ID 또는 사전 busy 응답을 추가하는 변경은 이번 범위가 아니다.
- `NSPrintOperation.run()`의 실제 취소·완료 UI는 deterministic unit test에 포함하지 않았다. Controller의 모든 종료가 동일 completion으로 수렴하는 현재 API와 lifecycle fake controller로 ownership을 검증했다.
- `RhwpStudioPrintController.finish`가 exactly-once completion을 보장하지만 lifecycle도 이전 completion 재호출을 방어한다. 향후 controller API가 completion 전달 방식을 바꾸면 protocol과 테스트를 함께 갱신해야 한다.
- Renderer의 navigation, preparation JavaScript, `createPDF`와 timeout stale callback 위험은 그대로 남아 있으며 Stage 2의 generation token 작업이 필요하다.
- `aria-label` 테스트는 bundled script source 계약을 확인한다. 실제 upstream DOM mutation smoke는 Host bridge asset을 변경하는 작업이 아니므로 Stage 1 blocking gate에 포함하지 않았다.

## 다음 단계 영향

Stage 2에서는 이번 lifecycle과 Host bridge 변경을 유지한 채 `RhwpStudioPagePDFRenderer`에만 generation/page/navigation identity를 도입한다.

- Render마다 단조 증가 generation 발급
- Page index와 `WKNavigation` identity를 current token에 연결
- `didFinish`, `didFail`, provisional failure와 WebContent 종료의 current 판정
- Preparation JavaScript, `createPDF`와 timeout closure의 generation/page 검증
- 이전 세대 callback이 현재 page·watchdog·completion을 변경하지 않는 자동 회귀

Stage 2는 인쇄 controller protocol, 중복 오류 문구, PDF export request state와 Host bridge command protocol을 재설계하지 않는다.

## 승인 요청

Stage 1의 인쇄 lifecycle 분리, 중복 요청 거부, controller identity 해제, `aria-label` observer 보완과 검증 결과를 검토하고 Stage 2 renderer generation·stale callback 차단 진입 승인을 요청한다.
