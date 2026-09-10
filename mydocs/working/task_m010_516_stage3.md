# Task #516 Stage 3 완료 보고서

## 단계 목적

새 문서의 첫 HWP/HWPX 저장과 후속 저장을 연결하고, PDF 및 창 닫기·앱 종료 명령이 실제 편집 세션을 기준으로 동작하게 한다.

- 이슈: [#516](https://github.com/postmelee/alhangeul-macos/issues/516)
- 마일스톤: `M010` / `v0.1`
- 작업 브랜치: `local/task516`, 대상 `devel`
- 승인: 같은 스레드의 “진행해줘”, [구현계획서](../plans/task_m010_516_impl.md) Stage 3
- 상태: Stage 3 구현·검증 완료, Stage 4 승인 대기

## 변경 내용

| 파일 | 책임 |
|------|------|
| `RhwpStudioSaveBridgeScript.swift` | 입력 확정, 요청별 export·검증·완료 통지, 저장 중 편집·명령 차단 및 해제 |
| `RhwpStudioEditorSessionScript.swift`, `RhwpStudioHostBridgeScript.swift` | 저장 중 상태 조회 경쟁 방지, 화면이 가려져도 입력 확정 대기를 끝내는 보조 타이머 |
| `RhwpStudioWebView.swift` | 최신 세션 조회 후 destination 결정, 요청·로드·epoch 검증, 최초 저장 등록, PDF 및 명시한 창의 명령 연결 |
| `DocumentViewerStore.swift` | 최초 저장의 bytes·URL 연결, reload 없이 최신 snapshot의 dirty 상태 유지 |
| `RhwpStudioPDFExportController.swift` | PDF 생성 후 실제 쓰기 직전에 세션 검증 |
| `DocumentCloseConfirmationController.swift`, `DocumentTerminationCoordinator.swift` | 모든 창의 최신 편집 상태 확인, 저장 취소·실패·저장 이후 추가 편집 시 종료 취소 |
| `RhwpStudioSaveBridgeScriptTests.swift`, `project.yml` | JavaScriptCore 행동 검증 5개 추가, XcodeGen으로 테스트 target 갱신 |

### 저장 계약

1. bytes가 없더라도 준비 완료된 편집 세션에서 저장한다. 최초 조회가 이전 source를 해제한 뒤 출력 형식과 저장 위치를 결정한다.
2. 패널을 기다리는 동안에는 편집할 수 있다. 패널 종료 후 같은 epoch인지 다시 확인하고, export부터 완료 통지까지 입력과 문서 변경 명령을 잠근다. 60초 타임아웃 및 모든 완료 경로에서 요청별 잠금을 해제한다. 오래 걸려 잠금이 만료되면 저장을 실패 처리한다.
3. UUID·page token·loadID·epoch로 응답을 연결한다. export 이후 changeSeq·문서 SHA를 검증하고 native 보호 정책을 쓰기 직전에 다시 확인한다. 요청과 연결되지 않은 이전 `save-document` 메시지는 저장하지 않는다.
4. 실제 write 성공 후에만 `notifySaved`를 호출한다. 파일 쓰기는 성공했지만 완료 통지가 실패하면 파일을 보존하고 동기화 오류를 보고하며 창을 유지한다. 새로운 편집 상태를 임의로 clean 처리하지 않는다.
5. 첫 저장은 같은 세션에 source와 실제 bytes를 등록한다. `webViewLoadID`는 바꾸지 않으며 후속 저장은 등록된 경로를 사용한다.
6. `editorOnly`는 자동복구 등 출처가 불명확한 문서도 포함한다. 따라서 최초 저장은 `invalidOrUnknown` 평문 복사본 확인과 새 destination 정책을 적용한다. 새 문서처럼 보인다는 이유로 보호 분류를 낮추지 않는다.
7. PDF는 현재 페이지 snapshot을 사용하되 source·dirty·최근 문서·저장 완료 상태를 바꾸지 않는다. PDF 파일 쓰기 직전에도 동일 세션인지 확인한다.
8. 닫기·종료에서는 native에 전달되기 전인 마지막 입력까지 조회한다. 저장 후에도 같은 문서가 clean인지 다시 확인한다. 특정 창에 대한 저장 요청이 다른 창으로 대체 실행되지 않게 한다.

원본 경로 쓰기 실패 시 이전에 export한 bytes를 다른 패널로 넘기는 흐름은 제거했다. 실패를 보고하고 사용자가 다시 저장 명령을 실행하면 최신 세션과 내용으로 시작한다.

## 검증

환경은 macOS `26.5.2` / `arm64`다. 실제 제품 Store·Coordinator·WKWebView·고정 core를 사용한 진단 앱으로 실행했다. 저장/PDF destination 선택은 주입된 callback이며 실제 NSSavePanel의 샌드박스 권한 검증과 구분한다. 입력은 실제 textarea의 `execCommand('insertText')`이고 물리 IME 조합 검증은 아니다.

최종 결과:

```text
HostAppTests: 197 tests, 0 failures / TEST SUCCEEDED
HostApp Debug build, CODE_SIGNING_ALLOWED=NO: BUILD SUCCEEDED
실제 WKWebView 통합: 59개 boolean 검사, 실패 0개, process exit 0
저장 성공 callback: 10회, destination callback: 9회
check-no-appkit.sh: OK
verify-rhwp-studio-assets.sh: source / 최종 Debug app resource 모두 OK
```

Xcode 검증 명령과 DerivedData는 구현계획서의 공통 명령을 사용했다. 추가한 JavaScriptCore 테스트는 저장·완료 통지의 요청 연결, export 이후 변경 거부, 다른 epoch·늦은 완료 거부, PDF dirty 보존, 이전 상태 조회가 저장 완료 상태를 덮어쓰지 않는지 확인한다. 기존 `DocumentSaveContractTests`의 HWP3 변환, 암호/미확정 문서 복사본, 원본 동일 경로·기존 destination 거부, atomic publish 경쟁과 보호 상태 변경 검증도 통과했다.

| 실제 통합 시나리오 | 결과 |
|-------------------|------|
| 앱 시작 → `ㅇㅇ` → 첫 HWP 저장 | source·bytes·clean 등록, WebView reload 없음 |
| HWP/HWPX 첫 저장·후속 저장 | 동일 경로 갱신, core 재열기의 페이지 수·본문 확인 |
| 디스크 HWP/HWPX 재열기 → 재편집 → 저장 | 새 패널 없이 해당 경로 갱신, 재열기 본문에 추가 입력 존재 |
| 기존 HWP → 새 문서 → HWPX 저장 | 이전 HWP bytes 불변 |
| 최초 저장 패널 취소·쓰기 실패 | source 미등록, 입력·dirty 유지 |
| 저장 패널 대기 중 중복 요청 | 두 번째 요청 거부, 첫 요청 취소 정상 처리 |
| 패널 대기 중 새 문서로 교체 | 오래된 destination에 파일 생성하지 않음, source 미등록 |
| 요청 없는 이전 저장 메시지·다른 request ID 응답 | 파일 변경·생성 없음 |
| export 이후 실제 본문 변경 주입 | write 거부, 완료 통지 없음, 잠금 해제 |
| 저장 잠금 중 입력·automation 실행 | 문서 변경 명령 거부, 저장 본문 `요청 검증` 유지, 차단한 문자열 미포함 |
| 저장 완료 통지 실패 및 재시도 | durable file과 dirty 보존, 오류 반환, 이후 저장 성공 |
| 새 문서 PDF | `새 PDF` 본문 포함, source 없음과 dirty 유지 |
| 기존 편집 문서 PDF | `다른 새 문서 이어쓰기 PDF내용` 본문 포함, source·dirty 유지 |
| PDF 취소·쓰기 실패 | 기존 bytes·source·dirty 유지 |
| 다른 창 지정 저장 | 현재 창을 대신 저장하지 않음 |
| 최신 입력 직후 창 닫기 | 저장 확인 표시, 취소 시 창·dirty 유지 |
| native 캐시가 clean인 상태에서 앱 종료 | editor의 실제 dirty를 확인해 저장 확인 표시 |
| 앱 종료의 취소·저장 패널 취소·쓰기 실패 | 종료 reply false, 창·입력 보존 |
| 앱 종료 확인에서 최초 저장 성공 | source·clean 등록을 확인한 뒤 종료 reply true |

종료 검증은 실제 `DocumentTerminationCoordinator`의 reply callback을 주입하여 진단 프로세스가 종료되지 않게 했다. 저장 확인 NSAlert는 실제로 표시하고 테스트에서 선택 결과를 전달했다. Store callback은 제품 View와 같이 MainActor Task로 전달했다.

증거는 worktree의 `build.noindex/task516/stage3/`에 있다.

- `tests-final.log`, `build-final.log`: 최종 자동 테스트·빌드
- `probe-roundtrip-final.jsonl`, `probe-roundtrip-final.stderr.log`: 최종 실제 구성요소 통합 결과
- `verification-summary.json`: 59개 검사, 생성 파일 크기·SHA-256
- `Probe.swift`, `build-probe.py`, `source-files.txt`, `probe-compile.log`: 재현 코드와 컴파일 근거
- `run-B969DCC7-D56B-40B3-8974-C23C42D59291/`: 최종 HWP/HWPX/PDF 합성 산출물

초기 추가 runner의 SVG 문장 문자열 검사는 글자마다 `<text>` 요소를 만드는 core 출력을 고려하지 않아 실패했다. 해당 SVG와 실제 본문을 확인한 후 고정 core의 `rhwp_extract_text_utf8`로 저장 파일의 본문을 검사했다. 수정 전 로그 `probe-final.jsonl`은 실패 기록이며 최종 성공 근거로 사용하지 않는다. 이는 exporter 수정이 아니라 검증 방법 보정이다.

## 본문 변경 정도 / 본문 무손실 여부

HostApp 저장·종료·PDF 연결과 테스트만 변경했다. core pin·Rust/FFI·bundled asset은 그대로다. 저장 검증에는 task516 소유 합성 문서와 매 실행 별도 디렉터리를 사용한다. 기존 사용자 문서와 다른 worktree는 수정하지 않았다.

## 병행 검증 조정

PR #515 Spotlight 검증 요청에 따라 #516의 앱 빌드·실행·등록 검증을 일시 중단한 뒤, 해당 작업의 관찰·정리 완료 안내를 받고 재개했다. 표준 `check-extension-registration-hygiene.sh --cleanup-dev-registrations --no-cache-reset`으로 #516 Debug 앱과 확장 등록만 해제했다. 남은 #516 Sparkle Updater 및 Stage 1~3 진단 앱 등록도 정확한 소유 경로만 해제했다. `mdimport -L`에서 #516 importer 제거, `lsregister -dump`에서 task516 경로 부재를 확인했다. 다른 설치본·기본 연결·전역 인덱스와 캐시는 변경하지 않았다. 이 작업은 Spotlight 기능 검증의 통과를 뜻하지 않는다.

최종 검증 후에도 같은 정리를 수행했다. `registration-final/20260910-123950/`의 표준 검사는 개발 등록 없음으로 확인했지만, 기존 `/Applications/Alhangeul.app`과 `~/Applications/Alhangeul.app` 두 provider root 때문에 exit 1을 반환했다. 기존 설치본은 수정하지 않았다. 추가 진단 앱 해제 후 `registration-final-summary.json`의 task516 LaunchServices/importer 잔류 값은 모두 false다. 전체 시스템 등록 검사가 통과했다고 보고하지 않는다.

## 남은 검증과 범위

- M1 / Tahoe 26.3 및 최소 지원 macOS 12, 물리 한글 IME, 실제 저장 패널 권한, 실제 WebContent process crash는 미검증이다.
- 암호/HWP3 정책은 기존 자동 테스트로 확인한다. 실제 암호 문서·HWP3 fixture를 사용한 UI 저장은 이번 진단에 포함하지 않았다.
- Word·HTML native 내보내기는 Stage 4, 전체 회귀와 architecture 정리는 Stage 5에 남아 있다. PR 게시·릴리스·이슈 close는 수행하지 않았다.

## 다음 단계 승인 요청

Stage 3 구현과 검증을 완료했다. Stage 4 “Word·HTML native 내보내기 연결” 진입 승인을 요청한다. Stage 4에서는 기존 Blob 다운로드를 WKDownload로 연결하고 내보내기 성공·취소·실패가 원본 저장 상태를 바꾸지 않는지 확인한다.
