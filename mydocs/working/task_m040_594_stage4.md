# Task M040 #594 Stage 4 통합 검증 보고서

## 목적과 승인

실제 SwiftUI·Store·Coordinator·WKWebView에서 오류 중단, 진단 펼치기·복사, 재시작, 여러 창 독립성과 기존 문서 생명주기를 검증한다.

- 이슈: [#594](https://github.com/postmelee/alhangeul-macos/issues/594), M040 (`v0.4`), 브랜치 `local/task594`
- 진입 승인: 2026-10-21 같은 채팅의 ‘좋아. Stage 4 통합 검증을 진행해줘.’
- 선행: [구현계획](../plans/task_m040_594_impl.md), [Stage 3·3.1](task_m040_594_stage3.md), [오류 복구 계약](../tech/task_m040_594_error_recovery_contract.md)
- 범위 보완 승인: 실제 검증 중 발견한 Promise 원인 문구 누락의 4줄 제품 수정안과 회귀 검사를 제시했고 ‘수정하고 재검증 진행’ 답변을 받았다.

## 변경

| 산출물 | 내용 |
|------|------|
| `Tests/StudioErrorRecoveryIntegrationSmoke/main.swift` | 실제 비동기 uncaught exception·unhandled Promise rejection, 실제 자산 preflight 실패, 오류 UI 펼치기·복사, 창 독립성, 반복 재시작과 오래된 coordinator 무효화 |
| `scripts/smoke-studio-document-lifecycle.py` | `--integration` 모드, 제품 Info.plist의 버전/build를 진단 앱에 반영, 입력 SHA-256 전후 및 소유 앱 등록 정리 결과 기록 |
| `RhwpStudioHostBridgeScript.runtimeErrorSource` | WebKit 스택에 빠진 오류 이름·메시지를 함께 보존. 기존 스택에 이름·메시지가 있으면 중복 추가하지 않음 |
| `RhwpStudioHostBridgeScriptTests` | 메시지가 없는 WebKit 형식 스택, 이미 메시지가 있는 스택, 문자열·객체 rejection의 실제 JavaScript 실행 회귀 2개 |

제품 core pin, bundled Studio 자산, FFI/renderer 및 Xcode 설정은 변경하지 않았다. 진단 앱은 실행별 고유 bundle ID와 `build.noindex/` 경로를 사용한다.

## 실제 오류·UI 수용 방법

네이티브 `runtime-error` 메시지를 만들어 보내지 않고, 실제 pinned bundle 페이지에서 `setTimeout`의 uncaught `Error`와 unhandled `Promise.reject(Error(...))`를 발생시켰다. 제품의 document-start listener부터 실제 Coordinator·Store·SwiftUI fallback까지 연결한다. 오류 시 WebView가 숨겨지고 제거되며 마지막 세션 metadata가 남는지 확인한다.

오류 화면의 기본 접힘, 접근성 press로 펼치기, 표시 보고서와 Store 보고서의 일치, 실제 ‘복사’ 버튼과 일반 클립보드 문자열의 정확한 일치, 성공 표시, 다시 접기를 확인한다. 일반 클립보드의 기존 즉시 읽기 가능한 형식은 메모리에만 보관하고 검사 후 복원한다. 사용자가 도중에 새로 복사한 내용은 덮어쓰지 않으며 내용을 로그에 기록하지 않는다.

오류 ID·시각·제품 버전/build·OS/architecture·rhwp release/전체 commit·세션과 오류 원인 문구가 포함되고, fixture 이름·원본 경로가 제외되는지 검사한다. 펼치기·복사 전후의 보고서 ID·시각은 같다. 실제 HWPX 입력의 [기본 접힘 화면](assets/task_m040_594_stage4/fatal-collapsed.png)과 [펼침·복사 성공 화면](assets/task_m040_594_stage4/fatal-expanded.png)을 native capture로 보관했다.

두 번째 실제 문서창은 첫 창의 중단에도 WebView·세션·dirty를 유지하며 undo/redo·추가 편집·정상 저장과 native parser 재열기가 가능하다. 첫 창은 중단 상태를 유지한다. 재시작 3회마다 loadID/reload token 증가, 이전 진단 초기화, 새로운 Promise 오류의 원인 문구 전달을 확인한다. 이미 중단된 이전 coordinator의 늦은 종료 callback이 새 문서를 다시 중단시키지 않는다.

초기화 실패는 소유 진단 앱의 `index.html`만 일시 이동해 실제 resource preflight를 실패시킨다. `resourcePreflight` 분류와 파일 식별·경로 생략을 확인하고 자산을 원래 bytes로 복원한 뒤 명시적 재시도로 정상 편집기를 확인한다. 사용자 설치본이나 저장소 자산은 변경하지 않는다.

## 발견·회복한 사항

1. 새 harness의 접근성 `accessibilityValue()` 반환 형식이 모호해 최초 컴파일에 실패했다. String 반환 형식을 명시해 회복했다. 제품 결함이 아니다.
2. 실제 Promise rejection 검사가 원인 문구 보존에서 실패했다. 별도 작은 WK probe에서도 `Error.message=TASK594_REJECTION_REASON`인데 `Error.stack=global code@about:blank:1:16`임을 확인했다. 기존 `reason.stack || reason.message`가 위치만 선택했다. 회귀 XCTest 1개가 수정 전 실제 실패하는 것을 확인한 뒤, 별도 승인받은 보완을 적용했다. 최종 회귀는 오류 이름·메시지와 원래 위치를 함께 검사한다.
3. 두 번째 창에서 이전 빈 문서의 ready를 요청 파일의 ready로 오인해 새 harness가 nil session을 강제 해제했다. 비동기 `loadDocument` 호출 뒤 native load 세대 증가·원본 URL commit을 먼저 기다리고, ready의 native binding과 형식까지 확인하도록 수정했다. 제품 코드를 수정해 숨긴 문제가 아니다. 실패 실행의 원본 해시와 등록 정리도 보존했다.
4. 형식 비교에서 기존 `samples/hwpx/hwpx-01.hwpx`의 실제 bytes가 HWP5 OLE (`d0cf11e0a1b11ae1`)임을 발견했다. 이 파일을 쓴 이전 보고서의 ‘HWPX 입력’ 표현은 실제 HWPX 입력 수용 근거가 아니다. HWPX 출력·저장본 검증은 별개다. 이번 입력은 ZIP 및 `mimetype=application/hwp+zip`을 확인한 `samples/hwpx/ref/ref_text.hwpx`로 교체했다. runner도 .hwpx 입력의 ZIP/mimetype를 먼저 검사해 잘못된 fixture를 종료 코드 2로 거절한다. 원래 샘플 자체는 변경하지 않았다.
5. Stage 3의 초기 ready 시간 초과는 원인을 확정하지 못한 별도 기록이다. 이번 harness 대기 결함이나 잘못된 확장자와 같은 원인이라고 단정하지 않는다.

회복 전 증적은 `task594-integration-6xlczu_u`(컴파일), `task594-integration-dxj1ctwe`(Promise 원인 누락), `task594-integration-39bwlgni`(빈 문서 ready 경합), `task594-integration-b9jwwa_8`(잘못된 HWPX fixture)다. 모두 `build.noindex/` 아래다. 원인 probe와 수정 전 실패 테스트는 `task594-stage4/error-stack-probe.log`, `rejection-red.log`에 보관한다. 이 실패들을 최종 통과 실행과 섞지 않는다.

## 최종 검증 결과

환경은 macOS 26.5.2 (`25F84`) arm64, Xcode 26.6 (`17F113`)이다. 제품 버전/build는 실제 Info.plist의 `0.2.3` / `21`로 진단에 표시한다. macOS 12 deployment target의 compile/link를 확인했으며 실제 macOS 12 또는 Intel runtime 결과가 아니다. SDK XCTest의 macOS 14 링크 경고 및 검사 전용 접근성 API deprecation 경고는 남아 있다.

| 검사 | 최종 결과 | 증적 (`build.noindex/` 기준) |
|------|------|------|
| HostApp Debug / HostAppTests build-for-testing | PASS | `task594-stage4/build-final.log`, `test-build-final.log` |
| 오류 보고서·UI·복구본·명령/세션·open·PDF/인쇄 XCTest | **74 tests, 0 failures** | `task594-stage4/unit-final.log` |
| 실제 오류·진단 UI·창 독립성·반복 재시작·preflight, HWP | **40 checks PASS** | `task594-integration-lt7enyzq/run.log` |
| 같은 실제 통합, ZIP/HWPX 입력 | **40 checks PASS** | `task594-integration-8tv9benu/run.log` |
| 이전 저장본·출력 경쟁·닫기·종료·보호 분류·만료 | **85 checks PASS** | `studio-fatal-recovery-xtwf5m1l/run.log` |
| version 1 합성 producer / 제품 기본 미지원 계약 | **55 checks PASS** | `studio-command-failure-gmzk4d6n/run.log` |
| 정상 HWP 입력 생명주기·HWP/HWPX 저장·font transport | **43 checks PASS** | `studio-lifecycle-83l5yumv/run.log` |
| 정상 ZIP/HWPX 입력 생명주기·HWP/HWPX 저장·font transport | **43 checks PASS** | `studio-lifecycle-s0wbxnyo/run.log` |
| source 및 최종 build bundle Studio 자산 / core build-info | PASS | `task594-stage4/source-assets.log`, `built-assets-final.log`, `core-build-info.log` |
| 공통 Swift AppKit 경계 / Python 구문 / 공백 | PASS | `task594-stage4/shared-boundary-final.log`, `py_compile`, `git diff --check` |

선택 XCTest 목록은 RhwpStudioErrorReport / ErrorReportDisclosure / DocumentRecoveryCopies / RhwpStudioCommandFailure / RhwpStudioHostBridgeScript / RhwpStudioEditorSession / RhwpStudioEditorSessionScript / DocumentOpenRecovery / RhwpStudioPDFExportController / RhwpStudioPrintController / RhwpStudioPrintLifecycle / RhwpStudioPDFExportState다. 실제 UI를 여는 harness는 동시에 실행하지 않았다.

native process 종료 검사는 **실제 WebView에 대한 delegate callback 주입**이다. 실제 OS process kill이 아니다. 보호 분기는 native 분류 의존성 주입이며 실제 암호 문서 검사가 아니다. 게시 후 fatal 경합은 기본 HWP 저장, HWPX는 정상 저장·이전 저장본·동일 bytes 복사를 확인한다. 최종 소스의 일반 JavaScript 오류와 Promise rejection은 별도 실제 WK 이벤트 검사로 보강했다.

### 재현

```bash
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug \
  -derivedDataPath build.noindex/task594-build CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme HostAppTests -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath build.noindex/task594-tests \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build-for-testing
python3 scripts/smoke-studio-document-lifecycle.py --integration \
  --fixture samples/re-font-dotum-empty-hancom.hwp
python3 scripts/smoke-studio-document-lifecycle.py --integration \
  --fixture samples/hwpx/ref/ref_text.hwpx
python3 scripts/smoke-studio-document-lifecycle.py --fatal-recovery \
  --fixture samples/re-font-dotum-empty-hancom.hwp
python3 scripts/smoke-studio-document-lifecycle.py --command-failures \
  --fixture samples/re-font-dotum-empty-hancom.hwp
python3 scripts/smoke-studio-document-lifecycle.py --fixture samples/re-font-dotum-empty-hancom.hwp
python3 scripts/smoke-studio-document-lifecycle.py --fixture samples/hwpx/ref/ref_text.hwpx
scripts/verify-rhwp-studio-assets.sh
scripts/verify-rhwp-core-build-info.sh
scripts/check-no-appkit.sh
```

XCTest는 위 선택 목록을 `xcrun xctest -XCTest`로 실행한 결과다. 이전 Stage 3.1의 72개 결과와 이번 보완 후 74개 최종 결과를 구분한다.

### 입력 원본 보존

정상 HWP와 실제 HWPX를 읽기 전용 입력으로 사용하고 저장 목적지는 실행별 `build.noindex/`로 제한했다. 각 실행의 `fixture-integrity.json`에 전후 SHA-256 및 cleanupStatus를 남긴다.

| fixture | 실제 컨테이너 | SHA-256 |
|------|------|------|
| `samples/re-font-dotum-empty-hancom.hwp` | HWP5 OLE, 8,704 bytes | `1ee8871f37bec2e97d0928709dc411c0eacad656f35aa3d92c5cf89f61c5761b` |
| `samples/hwpx/ref/ref_text.hwpx` | ZIP/HWPX (`application/hwp+zip`), 13,340 bytes | `6e47ca7d7c1149dd1ee6db8c6f5932461c82f13cf6f9648d5c70c197f6c70e6d` |

회복 과정의 잘못된 fixture `hwpx-01.hwpx`도 원본을 변경하지 않았다. SHA-256은 `e17464a1514e3d83391d32a5db30f662f3d0db4b7c61bbaacf4450a729f70f20`이다. 형식 조사 원문은 `build.noindex/task594-stage4/fixture-types.json`에 보관했다.

최종 순차 실행은 모두 종료 코드 0이다. 각 fixture 전후 해시가 같고 runner의 소유 앱 등록 해제도 모두 성공했다. 이번 Debug 앱 및 helper 등록은 `debug-app-cleanup.json`, 전체 소유 진단 경로의 최종 확인은 `final-integrity-cleanup.json`에 남겼다. 전역 등록 reset·설치본 교체·기본 연결 변경은 수행하지 않았다.

## 업스트림 지원 재확인

2026-10-21 확인한 `edwardkim/rhwp`의 `devel` HEAD는 `2e3b4f880bd11d35398e6ea0100846611f13a72d`다. Stage 1 조사 commit `5e2b9bfbf08573a31fa1e11a2445ff63fc0755c0`과 비교한 144개 후속 commit의 최종 파일 차이는 Native/Qt 예제·clipboard 관련 7개 파일이며 Studio 파일 차이는 없다. 비교의 핵심 결과와 직접 조회한 protocol 원문은 `build.noindex/task594-stage4/upstream-audit.json`, `upstream-protocol.ts`에 보관했다.

- [해당 HEAD의 공개 protocol](https://github.com/edwardkim/rhwp/blob/2e3b4f880bd11d35398e6ea0100846611f13a72d/rhwp-studio/src/embed/protocol.ts)의 blob SHA는 `5fc82fcf3622a9ec24c84ca4e0a4db2d4346b183`이다. capability 목록에 일반 편집 명령의 복구 결과 producer는 없다. 기존 RPC의 `recovered?: boolean`은 이 타스크의 일반 명령 복구 보증이 아니다.
- [표 셀 위치 오류 #8102](https://github.com/edwardkim/rhwp/issues/8102), [undo 후 선택 overlay #8103](https://github.com/edwardkim/rhwp/issues/8103), [호스트 오류 계약 #8104](https://github.com/edwardkim/rhwp/issues/8104)는 모두 open이다. 이슈 상태만으로 수정 여부를 판단하지 않고 위 코드 차이·공개 protocol과 함께 확인했다.
- 제품은 기존 `v0.8.7` / `1a76570e833917d15817415a53c09ad61ab3203f`를 유지한다. 제품의 구조화 복구 지원 기본값은 여전히 `unavailable`이다.

이번 실제 오류 검사는 upstream 편집 알고리즘의 rollback이나 내용·선택·history·dirty 복원 성공 검사가 아니다. `--command-failures`의 성공 통지는 합성 version 1 transport 검증으로 별도 기록한다.

## 수용 한계와 다음 승인 지점

승인된 Stage 4의 호스트 통합·회귀 검증과 단계 산출물은 완료했다. 호스트의 중단·이전 저장본·제보·재시작 경로와, 실제 upstream 복구 성공은 별도 수용 대상이다. 공개 producer/adapter를 제공하는 지원 bundle이 없으므로 **실제 upstream 실패→복구 성공→후속 편집의 전체 기능 수용은 미완료**다. #594와 오늘할일을 완료로 처리하지 않는다.

실제 OS WebContent process kill은 검증하지 않았다. 이 환경에서 해당 WebView의 프로세스만 안전하게 종료할 공개 소유 식별 경로를 확보하지 못했으며 광범위 kill이나 private API를 사용하지 않았다. 기존 native 종료 delegate 주입 결과와 실제 JS 오류·preflight 결과를 분리한다. 실제 보호 문서 암호 해제, macOS 12·Intel 실행, 원래 사용자 문서의 upstream 편집 버그 수정도 이번 결과로 주장하지 않는다.

지원 upstream 계약 구현·안정 bundle 반영·그 버전에서의 실제 복구 성공 검증이 남는다. pin 변경, 최종 보고·PR 게시·배포·메일 발송·이슈 close는 이번 단계 승인에 포함되지 않는다. 다음 단계는 저장소의 [단계별 승인 규칙](../manual/agent_code_hyperfall_rule_conflict.md)에 따라 별도 지시를 받는다.


## 2026-11-05 추가 통합: 실제 command-error-v1

작업지시자가 메일 발송과 실제 API 연동을 승인했고, T7 재연결 뒤 구현·WKWebView 검증을 계속 지시했다. 위 2026-10-21의 API 부재·합성 검증 판정은 당시 기록이다.

### 구현

- `RhwpStudioCommandRecoveryScript`가 공개 capability/getState/isHandledError/inspect와 `rhwp-command-error`를 소비한다. 실제 오류 객체만 전역 fatal 처리를 유예하고 일반 오류는 기존 보호 경로로 전달한다.
- native가 schema/code/recovery와 다섯 checks를 다시 검증한다. opaque 문서 세션·이벤트 ID와 native load/epoch를 연결한다. legacy DTO의 순번/revision 저장 필드는 실제 계약 경로에서 사용하지 않으며 진단에도 표시하지 않는다.
- 복구 대기 중 입력과 native 편집·저장·출력을 막고, JS 저장 lock 검증에서도 공개 상태를 직접 확인한다. 같은 오류의 반복 throw는 대기 시간을 연장하지 않는다. 보고 누락·거부는 12초 제한 및 보호 처리 대상이다.
- 문서 교체 뒤 늦은 보고·타이머를 무시한다. 동일 ID의 다른 내용은 중단한다. opaque ID에는 순서가 없으므로 한 문서에서 검증한 ID 256개를 보존하고 한도를 초과하면 재처리 대신 중단한다.
- 기존 v0.8.7에는 capability가 없으므로 기존 오류 정책을 유지한다. 실제 지원이 관측되기 전 legacy 예외 정책을 끄지 않는다.

### 검증 출처

upstream checkout `1cb3a6dae1094f6ed552a8fdbffea8b89868d555`에서 locked wrapper의 최적화 web WASM을 새로 빌드했다. WASM SHA-256은 `b0143a2c2ad3397a4285b0d22e0fb8146c626e3b85ba5160fa1041cdc3acef92`다. upstream 추적 소스·lockfile은 변경하지 않았다. native parser/core와 제품 Studio pin은 여전히 v0.8.7이다. 검증 앱에만 후보 Studio와 기존 앱 전용 CSS를 넣었다. 따라서 정식 엔진·Studio 동시 갱신의 전체 수용 결과는 아니다.

환경: macOS 26.5.2 arm64, Xcode 26.6. 명시 산출물은 rhwp의 라우팅된 `output/task594-api/`에 보관했으며 .app은 그 아래 `build.noindex/`에 생성했다. 사용자 설치본과 fixture 원본을 보존하고 실행 소유 앱의 등록을 해제했다.

| 검증 | 결과/증적 |
| --- | --- |
| 실제 계약 decoder·기존 상태 모델 XCTest | 12 PASS, 0 failures. `xctest-final.log` |
| 실제 계약·JS 설치·보고 누락·중복 오류 timeout·이전 문서 timer·미준비 native 보고 차단 | 33 PASS. `contract-smoke-final.log` |
| fresh WASM 기본 옵션 WKWebView | 39 PASS인 회차 확인. `upstream-final-recheck.log`. 별도 초기화 실패 회차가 있으므로 항상 성공이라고 판단하지 않음 |
| 공식 로컬 글꼴 옵션 WKWebView | 39 PASS. 실제 throw와 Promise rejection 포함. `upstream-local-fonts-integration.log`. 초기화 약 1.05초·1.68초 |
| pinned v0.8.7 실제 JS/Promise 오류·UI·재시작·독립 창 | 재실행 40 PASS. `legacy-integration-recheck.log` |
| 계층·Python 구문·diff 공백 | PASS |

실제 복구 harness는 공개 확장 명령으로 실제 InputHandler의 snapshot 작업을 실패시킨다. payload 성공 값을 만들어 보내지 않는다. 내용·선택·dirty·WebView 유지, 실제 undo/redo, 후속 HWP/HWPX 저장 및 pinned native parser 재열기, 지연 복구 중 저장 거부, 실제 문서 교체 뒤 이전 보고 무시, RuntimeError 주입의 unknown 중단을 확인한다. 최종 HWPX 입력은 실제 ZIP/HWPX fixture다. 실제 엔진 panic이나 원 제보 문서를 재현했다는 주장은 하지 않는다.

WKWebView 실행 후 native 미준비 상태의 복구 완료 보고가 무기한 대기를 남기지 않도록 `COMMAND_REPORT_NOT_READY`로 중단하는 분기를 추가했다. 이 최종 분기는 독립 계약 검사 33개에 포함해 검증했으며, 이후 WKWebView 전체 검사를 다시 실행하지는 않았다.

### 발견과 한계

- 최초 후보 검사에는 앱 필수 CSS가 빠져 있었다. runner가 기존 앱 CSS를 후보 앱에 함께 복사하도록 보완했다.
- 기존 node_modules에 SDK가 누락돼 최초 Vite 빌드가 실패했다. 고정 lockfile의 npm ci 후 빌드가 통과했다. 출처 미확인 기존 WASM 실행은 최종 증거와 구분했다.
- XCTest 독립 runner의 SDK Swift 모듈 경로 누락을 보완한 뒤 실제 12개 검사가 통과했다.
- 기본 옵션 후보와 구버전에서 문서 준비 시간 초과 회차가 있었다. 후보 실패에서는 navigation 뒤 bridge가 설치됐지만 API getState가 null이고 native session도 없었다. 초기화 대기를 60초로 분리해도 실패한 회차가 있어 단순 대기 시간 문제로 종결하지 않는다. 동일 WASM에 공식 `RHWP_DISABLE_EXTERNAL_WEBFONTS=1` 옵션을 적용한 대조 실행은 초기화 약 1.05초·1.68초와 39개 검사를 통과했다. 외부 폰트 대기의 영향을 의심할 근거이지만 원인 확정이나 기본 옵션 수정 완료를 뜻하지 않는다.
- PDF·인쇄·공유에는 공통 gate와 lock 검증을 적용했지만 이번 추가 실행에서 실제 출력 장치/공유 UI까지 수용하지 않았다. 기존 출력 검증과 신규 복구 중 저장 검증을 구분한다.
- 정식 지원 release pin·bundled Studio 갱신, 실제 제보 파일, 최소 macOS 12·Intel, 실제 OS WebContent 종료는 남은 범위다. 외부 폰트 기본 옵션의 초기화 실패도 출시 전 재확인이 필요하다.

#594는 진행중을 유지한다. 실제 API 소비 구현·검증과 정식 번들 반영·배포는 별도다. PR 게시·release·이슈 종료는 수행하지 않았다.

## 2026-11-05 후속: 기본 웹폰트 초기화 대기 제한

### 원인과 수정 범위

작업지시자가 기본 옵션의 초기화 중단 해결과 마지막 보호 분기의 WKWebView 재검증을 승인했다. `main.ts`의 초기화는 `await loadWebFonts()` 이후에 WASM/InputHandler를 만든다. 기존 `font-loader.ts`는 `FontFace.load()`를 제한 없이 기다렸다. 함초롬 CDN face 응답을 미정산 상태로 주입하면 60초 뒤에도 `웹폰트 로딩 중...`, 공개 API state=null, native session=nil로 남았다. 로컬 Old Hangul face는 정상 완료했다. 이전 간헐 실패와 같은 중단 경로를 재현했지만, 당시 CDN/네트워크 자체가 왜 응답하지 않았는지까지 확정한 것은 아니다.

`scripts/studio-font-load-adapter.mjs`는 후보 빌드 시 공통 로더에 5초 제한을 적용한다. 실패 파일은 현재 페이지의 요청 후보 및 CSS 등록에서 제외한다. 제한 후 늦게 성공한 face는 `document.fonts`에 추가하지 않아 이미 진행 중인 문서의 글꼴을 뒤늦게 바꾸지 않는다. 정상 응답과 외부 글꼴 비활성 옵션은 유지한다. 소스 구조가 달라지면 변환을 중단한다.

이는 #594 후보 빌드용 보완이며 정식 `build-rhwp-studio.mjs`, 제품 자산·pin, upstream checkout의 추적 파일은 변경하지 않았다. upstream 공통 로더에 반영하거나 정식 번들 빌드 절차에 이 변환을 포함하는 작업이 정식 버전 반영 시 필요하다. 현재 결과를 upstream merge나 설치 앱 수정 완료로 해석하지 않는다. 글꼴 실패 시 fallback 표시가 가능해진 것이며 원래 글꼴과의 조판 동일성을 보증하지 않는다.

### 재현 절차

Node 24 환경에서 다음 순서로 실행한다. 산출물은 연결된 T7의 기존 `output/task594-api/`를 사용한다.

```bash
node scripts/ci/test-studio-font-load-deadline.mjs /Users/melee/Documents/projects/forks/rhwp
node scripts/studio-font-load-adapter.mjs \
  --upstream-dir /Users/melee/Documents/projects/forks/rhwp \
  --out-dir /Volumes/T7/DeveloperArtifacts/rhwp/verification/main/task594-api/studio-font-deadline
python3 scripts/smoke-studio-document-lifecycle.py \
  --fixture samples/hwpx/ref/ref_text.hwpx --upstream-recovery \
  --studio-resources /Volumes/T7/DeveloperArtifacts/rhwp/verification/main/task594-api/studio-font-deadline \
  --output-root /Volumes/T7/DeveloperArtifacts/rhwp/verification/main/task594-api/build.noindex
# 동일 명령에 --stall-web-fonts를 더하면 모든 외부 URL FontFace 응답을 지연시킨다.
```

`--stall-web-fonts`는 검증 앱 HTML에만 테스트 스크립트를 넣는다. 실제 네트워크 전체를 끄거나 제품 옵션을 바꾸지 않는다. 마지막 보호 분기는 HWPX 회차에서 실제 page의 busy 상태를 설정한 뒤 upstream의 실제 복구 보고를 전달해 `COMMAND_REPORT_NOT_READY` fatal 진입을 확인한다. 이는 미준비 상태 주입 검사이며 자연 발생한 편집 오류라고 주장하지 않는다. HWP 회차는 기존 unknown/trap 분류 검사를 유지한다.

### 결과

- 로더 회귀: 정상·실패·무응답, 늦은 성공 무시, CSS 공급 제거, 타이머 정리, 외부 비활성 옵션, 소스 변경 감지 통과 (`font-loader-contract-final.log`).
- 수정 전 지연: 60초 초기화 실패를 기대대로 재현 (`font-stalled-before.log`).
- 기본 옵션 최종 소스: 40개 통과, 초기화 5.20초·1.15초 (`font-default-final.log`). 마지막 native 보호 분기도 실제 WK transport로 통과했다.
- 함초롬 지연 대조: 40개 통과, 초기화 7.53초·7.34초 (`font-stalled-after.log`).
- 전체 외부 URL 지연 최종 재현 옵션: 44개 통과, 초기화 7.22초·7.15초 (`font-stalled-final.log`). 지연 face가 CSS에서 제외되고 15초 이내 준비되는지, 마지막 native 보호 분기를 함께 확인했다.
- 최종 두 실행 모두 입력 fixture 전후 SHA 일치 및 소유 앱 등록 해제 성공. Python 구문·공통 계층·diff 공백 검사 통과.

기준 upstream SHA와 WASM SHA는 직전 추가 통합과 동일하다. 변환 전 로더 SHA-256은 `f8c64ea2ec77217e2449cfbe2a132a641bd2accd3f1cf5674c7a282682c4ea5e`, 변환 후는 `ffb631ef96c6a18a1afbb22d11c05b94c76118cba43d30d7a550e18d71068f39`이며 후보 번들의 `alhangeul-font-load-deadline.json`에 기록했다. 최소 OS/Intel, 실제 사용자 문서, 실제 OS process kill 및 정식 bundle/core 동시 갱신 수용은 여전히 별도다.

### upstream 후속 작업 분리 — 2026-11-05

사용자 지시로 웹폰트 초기화 결함을 별도 [rhwp #8614](https://github.com/edwardkim/rhwp/issues/8614)에 등록했다. 새 전담 채팅 `01a1a906-ced4-7fe3-af4f-45ced7698803`에서 기존 `codex/studio-web-font-deadline` 브랜치와 계획 커밋 `9a54d8ac280645dc83bd984dd612ef4a999ae824`, 미커밋 구현·테스트를 인계받아 검증을 시작했다.

기존 #8104 채팅은 추가 작업 중단 및 idle 상태를 확인했다. 작성된 변경은 삭제·되돌리지 않았으며 #8104의 완료 상태도 유지한다. #8614의 수정·검증은 새 채팅 한 곳에서 진행하고, 이 기록은 upstream 병합 완료를 의미하지 않는다. 정식 번들 갱신 시 #8104와 #8614의 포함 commit을 각각 확인한다.

### 2026-11-08 공식 v0.9.0 반영 및 #600 인계

[공식 릴리스 v0.9.0](https://github.com/edwardkim/rhwp/releases/tag/v0.9.0)의 태그 커밋은 `c9095c5f67632e6721e800ccc7fb43ea49d26682`이다. 이 태그의 조상에 #8104 (`9418ed0c7c`), #8614 (`ece9c3383b`), HFT PR #8397 (`99a176b7cb`)이 모두 있다. 태그의 Studio 소스에서 공개 복구 API와 AbortController를 사용하는 5초 웹폰트 제한을 확인했다. 태그 소스를 추출해 실제 복구 계약 18개 및 글꼴 대기 제한·오프라인 회귀 16개를 실행해 모두 통과했다.

공식 core·WASM·Studio·native matcher 동기화와 #598의 글꼴 수용은 [알한글 #600](https://github.com/postmelee/alhangeul-macos/issues/600)이 담당한다. #594는 #600이 만든 번들과 native core를 함께 사용하는 통합 후보에서 복구를 검증한다. 배포 후보 커밋과 실행 증거를 두 작업에 동일하게 기록한 뒤 알한글 릴리스 운영으로 인계한다.

#594 선행 실행은 SHA-256을 검증한 공식 Chrome ZIP에서 WASM 및 바인딩을 추출하고 같은 태그의 웹 Studio를 기본 옵션으로 빌드했다. WASM SHA-256은 `33bc8f9d3a3fe892ed3b73e3102fb6cadc37f7a5b640f4af677c357df253cbbc`이다. 이 조합에서 native 파서는 기존 v0.8.7이며 제품 동기화용 어댑터는 #600 후보에서 검증한다. 증적은 T7의 기존 `output/task594-api/v090/`에 보관했다.

첫 실행에서 글꼴 선택 대화상자 입력을 기다리다 60초 제한에 도달했다. 공개 API는 ready, native 문서 snapshot은 ready=false였고 화면에 ‘대체 글꼴로 보기’가 표시됐다. 검사에서 이 선택을 수행하고, v0.9.0이 실제 사용하는 CDN fetch 지연/abort 경로를 확인하도록 무응답 검사를 조정했다.

재실행 결과 정상 40개(`wk-choice-normal.log`), CDN fetch 무응답 44개(`wk-choice-stalled.log`)가 통과했다. 무응답 회차의 요청 취소와 준비 완료, 두 실행의 HWP/HWPX 저장·재열기 및 `COMMAND_REPORT_NOT_READY` 보호 분기를 확인했다. 입력 해시와 실행 앱 등록 해제도 두 회차 모두 확인했다. #600 공식 제품 후보가 나오면 동일 검사를 병합된 앱 소스·번들·native core로 재실행한다.
