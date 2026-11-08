# Task M040 #594 Stage 2 완료 보고서

## 단계 목적

오류 복구 계약을 native에서 엄격하게 검증하고, 복구가 확인된 명령 실패는 동일 WKWebView·세션을 유지하며 비차단 알림과 진단으로 표시하는 호스트 수신부를 준비한다. 현재 bundle에 없는 공개 upstream producer를 연결한 것으로 표현하지 않는다.

- 이슈: [#594](https://github.com/postmelee/alhangeul-macos/issues/594)
- 브랜치: `local/task594`, 마일스톤: M040 (`v0.4`)
- 선행: [Stage 1](task_m040_594_stage1.md), [오류 계약](../tech/task_m040_594_error_recovery_contract.md), [구현계획](../plans/task_m040_594_impl.md)
- 단계 진입 승인: 2026-10-20 같은 채팅의 ‘진행해줘’

## 산출물

| 파일 | 변경 요약 |
|------|-----------|
| `Sources/HostApp/Services/RhwpStudioCommandFailure.swift` | 177줄. 계약 지원·출처·이벤트 타입 검증, 복구 checks 5개, 세대/순서/64개 dedupe, fatal latch, 알림 상태 |
| `Sources/HostApp/Views/RhwpStudioWebView.swift` | native 초기화 의존성·현재 세션 연결, WK 메시지 수신, 실패 세션 정리 공통화·해제 시 수신 중지 |
| `Sources/HostApp/Stores/DocumentViewerStore.swift` | 복구 성공 알림 보관·재표시, 문서 교체/실패 정리, fatal 뒤 늦은 비치명적 상태 해제 방지, 후속 저장 오류 우선 표시 |
| `Sources/HostApp/Views/DocumentViewerView.swift` | 비차단 배너·반복 횟수·접근 가능한 닫기·진단 표시/복사·최근 진단 재표시 |
| `project.yml`, 생성 Xcode project | 독립 HostAppTests에 모델 추가. project 파일은 xcodegen으로 생성 |
| `Tests/HostAppTests/RhwpStudioCommandFailureTests.swift` | 184줄. 신뢰/엄격 타입/불완전 복구/순서·중복·fatal 상태·범위/JavaScriptCore·표시 정책 검사 |
| `Tests/StudioCommandFailureSmoke/main.swift` | 193줄. 실제 SwiftUI/Store/Coordinator/WK transport 합성 이벤트와 문서·선택·undo/redo·후속 저장 검사 |
| `scripts/smoke-studio-document-lifecycle.py` | `--command-failures` 선택 추가. 고유 bundle/출력 및 기존 등록 정리 절차 사용 |
| 계획·계약·오늘할일·이 보고서 | 승인/구현 범위·검증과 잔여 의존성 기록 |
| [배너 시각 증적](assets/task_m040_594_stage2/command-failure-banner.png) | 시험 문서만 포함한 실제 native 화면 캡처. 문서·선택 유지 확인 |

## 본문 변경 정도 / 본문 무손실 여부

복구 성공 분류 시 기존 WebView 객체와 editor session/source binding/loadID/dirty를 초기화하지 않는다. 논리적 선택과 `getDocumentState`의 내용을 비교하고 undo/redo 및 후속 편집·저장 후 native core 재열기를 검증했다. 입력 fixture bytes는 시험 전후 일치했다.

이 결과는 **실제로 삭제 오류를 일으켜 rollback을 검증한 결과가 아니다.** 정상 시험 문서 상태에서 합성한 지원 계약 이벤트를 전달해 native 상태 보존과 후속 동작을 확인한 결과다. pinned bundle·core lock·원본 사용자 문서·설치본은 변경하지 않았다.

## 구현 핵심

1. 제품 기본값은 native 초기화의 `unavailable`이다. 페이지가 보내는 capability/recovered 값으로 지원을 켤 수 없다. 실제 공개 구독 API를 추측해 호출하는 adapter나 번들 패치를 추가하지 않았다.
2. 복구 성공은 `restored`/`unchanged`와 content/cursorSelection/history/dirtyState/readyForNextCommand checks 전체 true를 요구한다. false·누락·타입 파손·미지원 버전은 성공으로 처리하지 않는다.
3. 동일 WebView/main frame/정확한 Studio origin·frame URL과 token/loadID/epoch를 검증한다. 잘못된 출처나 옛 세대는 현재 문서를 변경하지 않는다.
4. Boolean을 정수로, 숫자 1을 Boolean으로 허용하지 않고 safe integer·ID 문자/길이·진단 한도를 검사한다. raw 외부 stack/message는 새 진단에 보관하지 않는다.
5. 이벤트 중복은 문서당 최근 64개와 sequence로 제한한다. 같은 ID의 상충 결과는 protocol fatal이며 낮은 revision/sequence라도 현재 문서의 무결성 실패를 숨기지 않는다. fatal 뒤 success/session/nonfatal은 상태를 풀지 않는다.
6. 정상 복구 분류에서는 문서 표시를 유지하고 진단을 가진 배너를 한 개만 표시한다. 동일 작업 반복은 최대 99회로 집계하고 닫은 뒤 다시 볼 수 있다. 새 저장/출력 오류를 이전 배너가 가리지 않도록 우선순위를 처리한다.
7. 현재 pin의 기존 두 문자열 예외는 기존 조건을 유지한다. native가 구조화 계약을 지원하도록 초기화된 모드에서는 문자열 allowlist로 복구 성공을 추정하지 않는다.

## 검증 결과

환경: macOS 26.5.2 / Apple Silicon arm64 / Xcode 26.6 (`17F113`). macOS 12 대상 typecheck와 Debug compile/link를 확인했다. 실제 macOS 12 OS에서 실행한 결과는 아니다.

| 검증 | 결과 | 증적 |
|------|------|------|
| pinned Rust framework 표준 `--verify-portable` | PASS, 두 architecture staticlib/xcframework·source/Cargo/header/symbol 검증 | `build.noindex/task594-stage2/rust-build-sparse.log` |
| 전체 HostApp + 새 진단 앱 macOS 12 대상 typecheck | PASS | `typecheck.log` |
| HostApp Debug build | PASS | `host-build.log` |
| HostAppTests build-for-testing 및 선택 XCTest | 40 tests, 0 failures | `test-build.log`, `unit-tests.log` |
| 실제 SwiftUI/WK 합성 명령 실패 transport | 55 checks PASS | `build.noindex/studio-command-failure-raq47_5a/run.log` |
| 기존 HWPX 입력 생명주기·저장·닫기·종료·font transport | 43 checks PASS | `build.noindex/studio-lifecycle-72vshjzf/run.log` |
| source 및 실제 build bundle Studio asset provenance | PASS | `assets.log`, `built-assets.log` |
| 공통 Swift AppKit 의존 금지 | PASS | `scripts/check-no-appkit.sh` |
| 변경 공백·문서 링크·Python smoke 구문 | PASS | `git diff --check`, 문서 검사, `python3 -m py_compile` |
| 진단 앱·Debug build 앱의 소유 등록 해제 | PASS, 각 실행 exit 0·cleanup 오류 출력 없음 | 각 `cleanup.log`, `debug-app-cleanup.log` |

XCTest는 새 오류 모델과 기존 HostBridgeScript/EditorSession/EditorSessionScript/DocumentOpenRecovery 검사를 선택했다. mock 문자열 비교만으로 세션 보존을 판정하지 않았다. 실제 WK 검사에서는 지원/미지원 두 모드 각각 HWP/HWPX 출력 4조합을 실행했다.

```text
Executed 40 tests, with 0 failures
PASS 55 command failure checks (synthetic producer; upstream recovery not verified)
PASS TOTAL 43
BUILD SUCCEEDED
Verified (portable): rhwp-core.lock
```

재현 명령:

```bash
scripts/build-rust-macos.sh --verify-portable
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug \
  -derivedDataPath build.noindex/task594-build CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme HostAppTests -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath build.noindex/task594-tests \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build-for-testing
LLVM_PROFILE_FILE="$PWD/build.noindex/task594-stage2/unit-%p.profraw" xcrun xctest \
  -XCTest HostAppTests.RhwpStudioCommandFailureTests,HostAppTests.RhwpStudioHostBridgeScriptTests,HostAppTests.RhwpStudioEditorSessionTests,HostAppTests.RhwpStudioEditorSessionScriptTests,HostAppTests.DocumentOpenRecoveryTests \
  build.noindex/task594-tests/Build/Products/Debug/HostAppTests.xctest
python3 scripts/smoke-studio-document-lifecycle.py --command-failures \
  --fixture samples/re-font-dotum-empty-hancom.hwp
python3 scripts/smoke-studio-document-lifecycle.py --fixture samples/hwpx/hwpx-01.hwpx
```

### 검증 중 회복 사항

- 최초 Rust 준비에서 디스크 공간이 부족했다. 이번 실행이 만든 미완성 Cargo checkout만 정리하고, 이후 Cargo가 완료한 동일 pin의 cache에 Git sparse checkout을 적용해 대형 문서·샘플을 제외했다. 완료 marker나 lock을 조작하지 않고 표준 locked/portable 검증을 통과했다. 기존 작업 자료는 삭제하지 않았다.
- XCTest 최초 시도는 sandbox의 네트워크/SwiftPM cache 권한으로 의존성 해석에 실패했고 권한을 부여한 표준 명령으로 회복했다.
- 새 native smoke 최초 시도는 내부 새 문서의 비동기 layout 완료 전 입력해 dirty 대기에서 실패했다. 기존 lifecycle smoke와 같은 안정 대기를 적용한 후 최종 55개 검사를 통과했다. 최초 실패 로그는 `build.noindex/studio-command-failure-7sawxrag/run.log`에 보존해 최종 결과와 구분했다.

## 잔여 위험

- 실제 일반 명령 복구 producer/capability와 공개 same-page 구독 API는 아직 없다. native version 1 모드는 테스트에서만 주입했고 제품 기본 경로는 계속 미지원이다. 이 단계는 원래 제보 해결이나 실제 rollback 검증을 뜻하지 않는다.
- fatal의 새 latch와 세션 차단은 수용 준비 경계다. 입력·출력 전체 차단, 이전 저장본 보관, 복구본 없음·명시 restart UX는 아직 Stage 3 작업이다. 현재 fatal fallback 자체는 남아 있다.
- 실제 macOS 12 실행·Intel runtime, 서명된 배포 후보의 UI smoke는 미실행이다.
- 초기 등록·자산·현재 bundle provenance를 보존했으며 새 upstream release 반영과 배포·메일 발송은 수행하지 않았다.

## 다음 단계 영향

Stage 3에서 fatal 상태의 마지막 dirty/시각 자료·검증된 이전 저장본 보존, 모든 입력/출력과 늦은 callback 차단, 복구본 내보내기·명시적 재시작/취소를 구현한다. 현재 latch와 수신 검증을 재사용하고 일반 nonfatal 알림으로 fatal을 해제하지 않는다. 실제 upstream producer 연결은 API 제공과 안정 release 반영 승인 뒤 별도 수용한다.

## 승인 요청

Stage 2 호스트 수신 준비와 위 검증·잔여 의존성을 수용하고 Stage 3 치명적 실패 복구 UX 구현에 진입한다. 현재 제품 번들에서 새 복구 성공 경로는 미지원으로 유지한다.
