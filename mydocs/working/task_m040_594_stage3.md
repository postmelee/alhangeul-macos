# Task M040 #594 Stage 3 완료 보고서

## 단계 목적

치명적 오류가 발생한 편집기를 중단하고 모델 기반 저장·출력을 차단한다. 정상 저장·동기화·읽기 전용 재검증까지 완료한 이전 저장본만 제한 보관하며, 별도 파일 복사와 명시적 재시작·닫기를 제공한다.

- 이슈: [#594](https://github.com/postmelee/alhangeul-macos/issues/594), M040 (`v0.4`)
- 브랜치: `local/task594`, 대상: `devel`
- 선행: [구현계획](../plans/task_m040_594_impl.md), [오류 복구 계약](../tech/task_m040_594_error_recovery_contract.md), [Stage 2](task_m040_594_stage2.md)
- 진입 승인: 2026-10-20 같은 채팅의 ‘알겠어. 다음 작업을 진행해줘.’
- UI 보완 지시: 같은 채팅의 ‘안내 ui가 사용자 입장에서는 너무 정신없고 필요없는 정보가 많지 않아?’를 반영했다.

## 산출물

| 파일 | 변경 요약 |
|------|-----------|
| `Sources/HostApp/Services/DocumentRecoveryCopies.swift` | 101줄. 창별 이전 저장본, 전체 메모리 상한, monotonic 만료·정리, 작업 lease, SHA-256 확인·새 파일 배타적 게시 |
| `Sources/HostApp/Views/RhwpStudioWebView.swift` | fatal gate, 세대 무효화·출력 취소, inert 페이지 전환, 저장 완료 callback 단일성, 동기 session/failure/saved 통지, parser 재검증, 요청과 연결된 공유 |
| `Sources/HostApp/Stores/DocumentViewerStore.swift` | 마지막 dirty/세션 metadata·참고 화면 보존, 이전 저장본 수용·복사, 재시작 확인·새 ready 이후 정리 |
| `Sources/HostApp/Views/DocumentViewerView.swift` | 간소화한 안내, 저장본 복사·다시 열기, 기타 작업 메뉴와 별도 세부정보 화면 |
| `DocumentCloseConfirmationController.swift` | 중단된 세션을 조회하거나 저장하지 않고 취소·복사·명시 폐기 처리. 활성 창/sheet의 명령이 다른 문서로 넘어가지 않게 registry 연결 |
| `RhwpStudioPDFExportController.swift`, `RhwpStudioPrintController.swift` | 마지막 await 뒤의 동기 게시·seal gate. 이미 확정된 출력과 취소 가능한 준비 구분 |
| `RhwpStudioHostBridgeScript.swift` | 공유를 native 요청/세션 검증 경로로 전달. 비상관 legacy 공유 payload 수용 중지 |
| `project.yml`, 생성 Xcode project | 복구 저장소와 테스트 포함. Xcode project는 `xcodegen generate`로 갱신 |
| `Tests/HostAppTests/DocumentRecoveryCopiesTests.swift` | 98줄. 보호·변환·늦은 검증, 만료·timer·lease, 상한·교체·다중 창, 원본·링크·기존 파일·쓰기 실패 검사 |
| PDF/인쇄 XCTest | 게시 직전 fatal gate가 기존 파일·시스템 인쇄를 보호하는 검사 추가 |
| `Tests/StudioFatalRecoverySmoke/main.swift` | 352줄. 실제 SwiftUI/Store/Coordinator/WKWebView의 오류 중단·복사·재시작·출력 경쟁·닫기·종료 검사 |
| `Tests/StudioDocumentLifecycleSmoke/main.swift` | 초기 ready 실패 시 상태·읽기 전용 JavaScript 진단 추가 |
| `scripts/smoke-studio-document-lifecycle.py` | `--fatal-recovery` 모드 추가. 고유 bundle ID·실행별 산출물·소유 앱 등록 정리 유지 |
| [이전 저장본 화면](assets/task_m040_594_stage3/previous-save.png), [복구본 없는 화면](assets/task_m040_594_stage3/no-copy.png) | 사용자 피드백을 반영한 실제 native 화면. 시험 문서만 사용 |

## 본문 변경 정도 / 본문 무손실 여부

입력 fixture는 읽기 전용으로 사용하고 전후 bytes가 동일함을 확인했다. 복사한 복구 파일은 이전 정상 저장 파일과 bytes가 정확히 일치하며 native parser로 다시 열렸다. 복사·취소·쓰기 실패는 원본 연결, dirty, 최근 문서 또는 editor notifySaved를 변경하지 않는다.

치명적 오류가 난 시점의 미저장 편집을 복구했다고 주장하지 않는다. 이전 저장본 이후 변경은 포함되지 않으며, 저장 이력이 없는 문서·보호 문서·검증 실패·용량 초과·만료는 사용 가능한 복구본이 없는 정상 분기다. 이미 게시된 파일은 중단 뒤에도 보존하고 저장 완료 사실을 반환한다. 동기화가 끝나지 않은 세션을 clean으로 바꾸거나 복구본으로 수용하지 않는다.

## 구현 내용과 검증 결과

### 입력·출력 경계

- 첫 fatal에서 기존 실패 상태를 latch하고 저장 token/요청을 무효화한다. 실제 WebView를 숨기고 user script를 제거한 빈 페이지로 전환한 뒤 SwiftUI가 편집기를 제거한다. hit testing만으로 차단하지 않는다.
- native 명령·파일 drop·WK 메시지·저장·HTML/PDF·공유·인쇄 준비가 같은 health/문서 세대를 확인한다. 뒤늦은 session/notifySaved 결과가 suspended를 해제하지 않는다.
- 진행 중 저장의 완료 통지는 한 번만 전달한다. 게시 전 중단은 취소, 이미 완료한 atomic write는 저장 완료로 구분한다. HTML/PDF/미확정 인쇄 준비는 취소하며, 이미 seal한 PDF로 시작한 인쇄는 취소했다고 표시하지 않는다.
- 공유는 요청 ID/token/epoch/revision 및 공개 직전 검증을 거친다. 과거의 비상관 `share-document` payload로 파일을 공유하지 않는다.
- 활성 문서창의 편집기가 제거되었거나 그 창의 sheet가 활성 상태여도 다른 창으로 저장·출력 명령을 보내지 않는다.

### 보관·복사·재시작

- 정상 저장과 notifySaved 동기화가 완료된 평문 HWP/HWPX payload를 native read-only parser로 다시 열고 pageCount를 확인한다. HWP3 변환·평문 복사 및 원래 보호 상태가 평문이 아닌 동일 editor epoch에서는 자동 복구본을 생성하지 않는다.
- 창당 1개·32 MiB, 전체 64 MiB, system uptime 기준 30분 TTL이다. timer가 만료 bytes를 정리하며 다른 창의 유효 복구본을 밀어내지 않는다. 이미 시작한 복사 작업은 lease로 완료·취소까지 bytes를 유지한다.
- 같은 원본 재시작·실패 시 후보의 실제 저장 시각·원래 세대를 유지한다. 다른 문서의 새 ready, 명시 폐기·닫기·Store 해제에서 정리한다.
- 복사는 원본/현재 source와 다른 새 파일에만 `RENAME_EXCL`로 게시한다. 기존 파일·alias/symlink·게시 경쟁에서도 덮어쓰지 않는다.
- 재시작과 다른 파일 열기에 손실 확인·취소를 제공한다. 복사 실패·취소는 자동 재시작으로 이어지지 않는다. 닫기·앱 종료는 suspended 세션에 live refresh/save를 요청하지 않는다.

### 사용자 피드백에 따른 UI 정리

초안은 내부 프로세스 설명, 중복 경고, 여러 동등한 버튼, dirty 문구와 진단 항목을 한 화면에 배치했다. 이를 제목·저장 시점/복구 범위·핵심 동작으로 줄였다. 복구본이 있으면 ‘저장본 복사…’를 강조하고 ‘다시 열기’를 보조 동작으로 둔다. 다른 파일·Finder·세부정보는 ‘다른 작업’ 메뉴에 모았다. 진단과 참고 화면은 별도 세부정보에서만 볼 수 있다. 복사 결과는 한 문장만 표시한다.

### 최종 검증

환경: macOS 26.5.2, Apple Silicon arm64, Xcode 26.6 (`17F113`). macOS 12 deployment target의 compile/link를 확인했으며 macOS 12 실제 실행이나 Intel 실행 결과는 아니다.

| 검사 | 결과 | 증적 |
|------|------|------|
| HostApp Debug build | PASS | `build.noindex/task594-stage3/build.log` |
| HostAppTests build-for-testing | PASS | `test-build.log` |
| 복구 저장소·오류 계약·기존 bridge/session/open·PDF/인쇄 XCTest | 66 tests, 0 failures | `unit.log` |
| 실제 WK fatal·복구·재시작 통합 | 85 checks PASS, HWP/HWPX 저장본 | `build.noindex/studio-fatal-recovery-dmkhc85t/run.log` |
| HWP 입력 정상 생명주기·저장·닫기·종료·font transport | 43 checks PASS | `build.noindex/studio-lifecycle-t1l_dfgj/run.log` |
| HWPX 입력 정상 생명주기·저장·닫기·종료·font transport | 43 checks PASS | `build.noindex/studio-lifecycle-azs7t_9m/run.log` |
| source 및 실제 build bundle Studio provenance | PASS | `source-assets.log`, `built-assets.log` |
| 공통 Swift AppKit 의존 금지·Python 구문·공백 검사 | PASS | `shared-boundary.log`, `py_compile`, `git diff --check` |
| native UI 시각 검토 | PASS, 기본 화면의 중복 경고·내부 정보 제거 | 위 두 화면 캡처 |
| 실행 앱 및 Debug 앱의 소유 LaunchServices 등록 해제 | PASS | 각 `cleanup.log`, `debug-app-cleanup.log` |

로그 이름만 기재한 항목은 `build.noindex/task594-stage3/` 아래에 있다. XCTest는 DocumentRecoveryCopies/CommandFailure/HostBridgeScript/EditorSession/EditorSessionScript/DocumentOpenRecovery/PDFExportController/PrintController/PrintLifecycle/PDFExportState를 선택했다.

```text
Executed 66 tests, with 0 failures
PASS 85 fatal recovery checks (native process failure callback injection)
PASS TOTAL 43  # HWP 입력
PASS TOTAL 43  # HWPX 입력
BUILD SUCCEEDED
```

오류 주입은 실제 WKWebView에 대한 **native process 종료/로드 실패 delegate callback 주입**이다. 실제 OS 프로세스를 죽이거나 upstream 삭제 오류를 재현하여 rollback을 검증한 것은 아니다. 보호 분기는 native 보호 분류 의존성을 주입한 정상 fixture로 검사했으며 실제 암호 문서 암호 해제 시험으로 표시하지 않는다. 게시 후 오류 경합은 새 문서의 기본 HWP 저장으로 검사했고 HWPX는 정상 저장·검증·중단·동일 bytes 복사를 검사했다.

재현:

```bash
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug \
  -derivedDataPath build.noindex/task594-build CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme HostAppTests -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath build.noindex/task594-tests \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build-for-testing
LLVM_PROFILE_FILE="$PWD/build.noindex/task594-stage3/unit-%p.profraw" xcrun xctest \
  -XCTest HostAppTests.DocumentRecoveryCopiesTests,HostAppTests.RhwpStudioCommandFailureTests,HostAppTests.RhwpStudioHostBridgeScriptTests,HostAppTests.RhwpStudioEditorSessionTests,HostAppTests.RhwpStudioEditorSessionScriptTests,HostAppTests.DocumentOpenRecoveryTests,HostAppTests.RhwpStudioPDFExportControllerTests,HostAppTests.RhwpStudioPrintControllerTests,HostAppTests.RhwpStudioPrintLifecycleTests,HostAppTests.RhwpStudioPDFExportStateTests \
  build.noindex/task594-tests/Build/Products/Debug/HostAppTests.xctest
python3 scripts/smoke-studio-document-lifecycle.py --fatal-recovery \
  --fixture samples/re-font-dotum-empty-hancom.hwp
python3 scripts/smoke-studio-document-lifecycle.py --fixture samples/re-font-dotum-empty-hancom.hwp
python3 scripts/smoke-studio-document-lifecycle.py --fixture samples/hwpx/hwpx-01.hwpx
scripts/check-no-appkit.sh
scripts/verify-rhwp-studio-assets.sh
```

### 검증 중 회복 사항

- 최초 빌드는 sandbox의 SwiftPM cache 쓰기 제한으로 실패했고, 빌드 서비스 접근 권한으로 회복했다.
- Debug 앱 본체는 이미 등록이 없어 해제 명령이 `-10814`를 반환했다. 정확히 이 빌드 안의 Sparkle Updater 등록만 추가 해제하고, LaunchServices dump에 소유 경로가 남지 않음을 확인했다.
- 새 harness의 초기 private WebView helper 접근·새 문서 기본 형식과 목적지 확장자 불일치를 수정했다. 다중 창 검사는 실제 key window가 된 뒤 실행하도록 정렬했다.
- 저장 metadata 통지는 lock 해제보다 먼저 온다. 정상 공유 검사에서 후속 요청을 너무 일찍 보낸 하네스 경합을 발견해 실제 저장 요청 종료를 기다리도록 수정했다. 최종 85개 검사를 통과했다.
- 정상 HWPX 첫 실행은 15초 ready 대기에서 한 번 시간 초과했다 (`studio-lifecycle-8df59udt`). 제품 코드를 변경하지 않은 재실행에서 43개 모두 통과했고 진단을 추가했다. 최초 실패 원인은 확정하지 못했으며 Stage 4의 반복 로드 수용에서 다시 확인한다.

## 잔여 위험

- 고정 bundle v0.8.7 / `1a76570e833917d15817415a53c09ad61ab3203f`는 그대로다. 공개 일반 명령 recovery producer/adapter는 연결하지 않았고 제품 지원 기본값은 계속 `unavailable`이다. 이번 변경은 upstream 편집 알고리즘 오류 수정 또는 미저장 편집 자동 복구 완료가 아니다.
- 실제 upstream 명령 실패·복구 보증, 실제 process kill, 실제 암호 문서, macOS 12 및 Intel 실행은 이 단계에서 확인하지 않았다.
- 이전 저장본은 메모리에만 존재한다. 프로세스/앱 종료 뒤 복구를 보장하지 않으며 screenshot은 편집 가능한 문서가 아니다.
- 정상 다중 창 종료의 기존 #525 draft 폐기 정책은 별도 범위다. 이 단계는 suspended 세션에 위험한 live 저장/상태 조회를 하지 않는 경계를 추가했다.

## 다음 단계 영향

Stage 4는 실제 pinned bundle의 오류·반복 로드·여러 창 생명주기 수용을 보강하고 upstream 지원 유무를 별도로 판정한다. 공개 recovery 계약 지원 bundle이 없으면 실제 복구 성공 통합 수용은 미완료로 보고한다. pin 변경·원격 게시·배포·메일 발송은 수행하지 않았다.

## 승인 요청

이 단계 소스·검증·간소화한 UI를 검토하고 Stage 4 통합 회귀 수용 단계 진입을 승인받는다. 저장소의 단계별 승인 규칙에 따라 승인 전 Stage 4로 넘어가지 않는다.


## Stage 3.1 — 제보용 오류 세부정보·복사 보완

### 요청과 변경

같은 채팅의 ‘상세 오류 내용은 드롭다운으로 볼 수 있어야 하지 않을까? 그래야 버그 제보때 복사해서 그대로 제보해야 내가 추적할 수 있지 않을까?’를 소스 변경 승인으로 받아 반영했다. Stage 4에 진입한 변경이 아니다.

- 기본 화면 아래에 접힌 ‘오류 세부정보’를 표시한다. 별도 창이나 메뉴를 거치지 않고 펼칠 수 있다. 펼친 영역의 전체 보고서를 ‘복사’로 클립보드에 넣으며 실제 쓰기 성공 후 ‘복사됨’을 표시한다.
- 오류 ID·최초 발생 시각·앱 버전/build·OS/architecture·rhwp release/전체 commit·오류 분류와 상세·마지막 세션의 loadID/epoch/sequence/changeSeq/dirty/pageCount/format을 한 텍스트로 구성한다. 화면과 복사는 같은 report 값을 사용한다.
- 파일 이름·로컬 경로·URL query/fragment/인증 정보를 생략한다. 문서 bytes나 본문을 수집하지 않는다. 오류 메시지·오류 코드·asset 발생 위치는 유지하고 과도한 상세는 항목당 16 KiB에서 생략 표시한다.
- 구조화 명령 실패에서 code만 남던 fatal 진단에 검증된 operation/event/recovery/checks도 보존했다. 새 load에서 진단을 초기화하며 raw payload는 보관하지 않는다.
- 참고 화면은 기존 ‘다른 작업’ 메뉴에 남긴다. [접힌 영역을 펼친 실제 컴포넌트 화면](assets/task_m040_594_stage3/error-details-disclosure.png)은 합성 오류 문구를 표시한 NSHostingView 캡처다.

### 산출물

`RhwpStudioErrorReport.swift`, `ErrorReportDisclosure.swift`, Store/fatal 진단 연결, `RhwpStudioErrorReportTests.swift`, `ErrorReportDisclosureTests.swift`와 기존 CommandFailure 테스트를 보완했다. `project.yml`을 갱신하고 Xcode project는 xcodegen으로 생성했다.

### 검증

- HostApp Debug build 및 HostAppTests build-for-testing PASS.
- 새 보고서 4개·실제 UI 1개·fatal 진단 보존 1개를 포함한 선택 XCTest **72 tests, 0 failures**.
- 실제 접근성 press로 초기 접힘 → 펼치기 → 복사 → 접기를 확인했다. 사용자 일반 클립보드 대신 고유 명명 클립보드에 실제 쓰기를 수행하고 report 문자열과 정확한 일치를 검증했다.
- 버전/전체 commit·오류 ID/시각·세션 metadata, 오류 메시지/asset 위치 보존, 파일 이름·경로·URL 매개변수 생략, 누락 metadata·긴 상세를 검증했다.
- source/build bundle asset provenance, 공통 Swift AppKit 의존 경계, `git diff --check` PASS. 이번 Debug 경로의 등록만 정리하고 설치본은 변경하지 않았다.
- 증적: `build.noindex/task594-stage3-details/{test-build,build,unit,built-assets,cleanup}.log`.
- 초기 UI 검사는 SwiftUI 접근성 노드의 정적 protocol cast와 부모 식별자 전파 때문에 버튼을 찾지 못했다. 접근성 트리를 활성화하고 실제 Objective-C 접근성 메서드와 각 컨트롤의 식별자로 연결한 최종 검사에서 통과했다. 제품 OS 지원 범위는 위 Stage 3와 같고 macOS 12 실제 실행으로 표시하지 않는다.

이번 변경은 표시·제보 텍스트·복사와 진단 보존 보완이다. 기존 native fatal 85개 및 생명주기 43+43개 전체 harness는 재실행하지 않았으며, 앞선 Stage 3 결과와 이번 72개 XCTest 결과를 구분한다. Stage 4 승인은 계속 대기한다.
