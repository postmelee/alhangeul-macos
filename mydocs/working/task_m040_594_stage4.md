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
