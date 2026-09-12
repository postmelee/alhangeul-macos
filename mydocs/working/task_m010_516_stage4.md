# Task #516 Stage 4 완료 보고서

## 단계 목적

Word(.doc)·HTML 내보내기의 Blob 다운로드를 native 파일 저장으로 연결하고, HTML 다운로드가 편집기 화면을 교체하는 문제를 해결한다. 출력 성공·취소·실패에서 원본 경로·형식·dirty 상태를 보존한다.

- 이슈: [#516](https://github.com/postmelee/alhangeul-macos/issues/516)
- 마일스톤: `M010` / `v0.1`
- 브랜치: `local/task516`, 통합 대상 `devel`
- 승인: 같은 스레드의 “진행해줘”, [구현계획서](../plans/task_m010_516_impl.md) Stage 4
- 상태: Stage 4 구현·검증 완료, Stage 5 승인 대기

## 산출물과 계약

| 파일 | 변경 내용 |
|------|-----------|
| `DocumentHTMLExportFormat.swift` | DOC/HTML 명령·MIME·확장자·기본 파일명, UTF-8 HTML 출력 검사, 원본 동일 경로와 파일 링크 방어 |
| `DocumentHTMLExportPanel.swift` | 형식별 NSSavePanel과 확장자 정규화 |
| `RhwpStudioHTMLExportScript.swift` | 공개 exporter의 Blob 포착, native 요청 전용 Blob URL 생성, 요청별 다운로드 시작 |
| `RhwpStudioHTMLDownload.swift` | 정확한 Blob URL에 대응하는 WKDownload만 수용, MIME·확장자 확인, 전용 staging·완료·취소·30초 timeout·정리 |
| `RhwpStudioSaveBridgeScript.swift` | 기존 세션 잠금 안에서 HTML exporter 실행, 전용 anchor만 다운로드 허용, 종료 시 Blob URL 폐기 |
| `RhwpStudioHostBridgeScript.swift` | Word/HTML을 native 및 비변경 명령으로 연결 |
| `RhwpStudioWebView.swift` | 패널·export·다운로드·게시의 세션/요청 검증, 문서 교체·실패 시 취소, 저장/PDF와 중복 실행 차단 |
| `DocumentHTMLExportFormatTests.swift`, `RhwpStudioHTMLExportScriptTests.swift` | 형식·MIME·출력·원본 링크 검사와 다운로드 지연·요청 연결 행동 테스트 4개 |
| `project.yml`, `Alhangeul.xcodeproj/project.pbxproj` | 신규 제품·테스트 소스를 XcodeGen으로 반영 |

### 다운로드 연결

Stage 1에서 확인한 고정 exporter는 `anchor.click()` 직후 1초 타이머로 Blob URL을 폐기한다. 그대로 클릭하고 나중에 native에서 요청과 연결하면 탐색/메시지 순서와 URL 수명에 의존한다. 따라서 입력을 확정하고 잠근 상태에서 공개 `automation.execute('file:export-doc'/'file:export-html')`를 실행하며, 이 호출 동안만 anchor의 click을 포착해 탐색을 보류한다. Blob을 읽고 요청 전용 URL을 만든 뒤 원래 click 함수를 `finally`에서 복구한다. core/bundle 내부 exporter를 재구현하거나 minified 식별자를 사용하지 않는다.

native가 request ID·page token·epoch·MIME·파일명을 검증하고 정확한 Blob URL을 등록한 다음 전용 anchor를 클릭한다. main frame에서 해당 URL의 첫 다운로드 요청만 `.download`로 처리한다. 관련 없는 Blob 탐색은 취소하여 편집기 main page가 교체되지 않게 한다.

`WKDownloadDelegate`는 응답 URL·MIME·확장자를 다시 검사하고, 요청별 임시 디렉터리 안의 존재하지 않는 파일을 destination으로 제공한다. 완료 후 bytes를 읽고 staging을 정리한다. 마지막 문서 SHA/세대 검증과 출력·destination 검증을 거친 뒤 기존 atomic write 정책으로 사용자가 고른 위치에 게시한다. 기존 destination을 먼저 삭제하지 않는다. 문서 교체·WebContent 실패는 진행 중 다운로드를 취소하고, 30초 동안 시작/완료되지 않은 다운로드도 취소한다.

원본과 동일한 경로, 심볼릭 링크, 같은 device/inode의 하드 링크는 내보내기 대상으로 거부한다. 성공 시에도 `notifySaved`, source 등록, 최근 문서 갱신, dirty 해제를 호출하지 않는다. 저장/PDF와 HTML 기반 내보내기는 동시에 진행하지 않는다.

## 검증 결과

실행 환경은 macOS `26.5.2` / arm64다. 구현계획서의 Xcode 명령과 task516 전용 DerivedData를 사용했다.

```text
xcodegen generate: 성공
HostAppTests: 201 tests, 0 failures / TEST SUCCEEDED
HostApp Debug build, CODE_SIGNING_ALLOWED=NO: BUILD SUCCEEDED
Word/HTML 실제 통합: boolean 검사 50개 + 조합 이벤트 검사 2개 통과
기존 저장/PDF/종료 실제 회귀: 59개 통과
두 진단 프로세스: exit 0
check-no-appkit.sh: OK
verify-rhwp-studio-assets.sh: source / 최종 Debug app 모두 OK
내보내기 staging 잔류: 없음
```

실제 Store·Coordinator·WKWebView와 제품 bridge/delegate를 그대로 컴파일한 진단 앱을 사용했다. 저장 위치는 callback으로 주입하고, 새 문서 Word/HTML은 실제 DOM 메뉴 클릭으로 실행했다. 기존 파일 출력과 오류 검증은 같은 native dispatcher를 호출했다. Core/renderer 회귀는 기존 Stage 3 runner를 최종 제품 소스로 다시 컴파일해 확인했다.

| 시나리오 | 결과 |
|----------|------|
| 새 문서 → Word/HTML 메뉴 | 두 파일 모두 한글 본문·굵게 서식 포함, editor marker 유지, source 없음·dirty 유지 |
| 디스크 HWP/HWPX 재열기 → DOC/HTML | 네 조합 모두 본문 포함, 원본 bytes·URL 및 clean 상태 유지 |
| 마지막 입력 직후 내보내기 | `마지막 입력` 포함 |
| native 조합 문자열 설정 후 내보내기 | 출력 전 compositionstart/update, 출력 후 compositionend 확인, `조합` 포함 |
| 저장 위치 취소 | 출력 callback 없음, 원본 dirty 유지 |
| 쓰기 실패 | 오류 반환, 입력·dirty 유지 |
| 패널 대기 중 중복 내보내기·저장 | 두 번째 내보내기/저장 거부, 첫 패널 취소로 정상 해제 |
| 패널 대기 중 새 문서로 교체 | 기존 destination과 이전 원본 bytes 불변 |
| 다운로드 후 마지막 검증 오류 주입 | 기존 destination·dirty 유지 |
| 잘못된 MIME 응답 | 파일 게시 거부, 기존 destination 유지 |
| Blob URL을 폐기해 실제 다운로드 실패 | `WebKitBlobResource error 1`, 편집기·dirty·기존 destination 유지 |
| 오류 후 재시도 및 기존 출력 파일 교체 | 정상 출력, 선택한 기존 출력만 새 본문으로 교체 |
| 요청 없는 HTML Blob 클릭 | 편집기 유지, 원본 저장으로 처리하지 않음 |
| 내보내기 후 창 닫기 | 저장되지 않은 변경 확인 유지 |

조합 검증은 `NSTextInputClient.setMarkedText`로 실제 WKWebView에 문자열을 전달했다. native `hasMarkedText()`는 false로 관측됐지만 DOM에서는 내보내기 전 compositionstart/update만 있고, 입력 확정 뒤 compositionend가 발생했다. 최종 HTML에 조합 문자열이 포함됐음을 함께 검증했다. 이는 물리 한글 키보드 및 특정 IME 입력기의 전 과정 검증을 뜻하지 않는다.

의도적으로 유발한 오류 6개는 실패 동작 검증의 근거다. 최종 assertion 실패는 0개다. 초기 runner는 파일 보호 분류를 기다리기 전에 WebView를 갱신해 기존 파일 검증에 실패했다. 제품은 그 시점의 내보내기를 거부했으며, runner를 로드 완료 → 갱신 → 준비 완료 순서로 보정했다. 초기 로그를 최종 성공 근거로 사용하지 않는다.

### 호환성 확인

DOC는 upstream이 만드는 **HTML 기반 .doc**다. binary DOC나 DOCX로 변경하지 않았다. macOS `textutil -format html -convert txt -stdout`으로 DOC/HTML 및 마지막 입력 출력의 한글 본문을 읽었고 stderr 없이 성공했다. 처음 확장자 자동 판정 및 제한된 환경에서 실행한 결과는 HTML 해석 성공 근거로 사용하지 않았다.

Word·Pages·LibreOffice는 확인한 설치 경로에 없었다. 따라서 실제 Word 앱에서의 열기·레이아웃 일치·편집 호환성은 미검증이며, HTML 구조/본문/대표 서식과 macOS HTML importer 확인 범위를 구분한다.

### 증거 위치

worktree의 `build.noindex/task516/stage4/` 아래에 보존한다.

- `tests-final.log`, `build-final.log`: 최종 자동 테스트와 빌드
- `probe-final.jsonl`, `probe-final.stderr.log`: Word/HTML 통합 실행
- `verification-summary.json`: 검사 수, 조합 이벤트, 생성 파일 크기·SHA-256, staging 잔류
- `run-03E73062-C91B-494C-9EC1-73AD517C24E1/`: 최종 DOC/HTML/HWP/HWPX 합성 산출물
- `*.textutil-html.txt`: HTML importer 본문 결과
- `Probe.swift`, `build-probe.py`, `source-files.txt`, `probe-compile.log`: 진단 코드·컴파일 근거
- `regression/probe-final.jsonl`, `regression/verification-summary.json`: 최종 소스의 Stage 3 회귀 59개

## 본문 변경 정도 / 본문 무손실 여부

HostApp의 Word/HTML 출력 연결과 관련 테스트를 추가했다. 저장 잠금은 출력 형식과 허용 anchor에 필요한 부분만 확장했다. 고정 core·Rust/FFI·bundled asset은 수정하지 않았다. 모든 출력과 오류 주입은 task516 소유 합성 문서/디렉터리로 한정했다. 사용자 문서와 다른 worktree를 변경하지 않았다.

원본 파일 보존은 HWP/HWPX export 전후 bytes 비교, 기존 destination 보존은 sentinel bytes 비교로 확인했다. 기존 출력 교체 성공은 별도 시나리오로 확인했다. 가독성 개선이나 재서술을 이유로 기존 보고서를 덮어쓰지 않았고, 수행·구현계획과 오늘할일의 진행 상태만 갱신한다.

표준 `check-extension-registration-hygiene.sh --check-only --no-cache-reset` 결과 개발 Alhangeul 등록은 없었다. 기존 `/Applications/Alhangeul.app`과 `~/Applications/Alhangeul.app`의 두 provider root 때문에 전체 검사는 exit 1이므로 시스템 등록 검사 통과로 보고하지 않는다. 실행한 Stage 4 진단 앱 두 개만 정확한 경로로 등록 해제했다. `registration-final-summary.json`에서 task516 LaunchServices/importer 잔류는 모두 false다. 기존 설치본·기본 연결·전역 캐시/색인은 변경하지 않았다.

## 남은 범위

- Stage 5에서 이슈 완료 기준별 증거를 통합하고 architecture·필요한 smoke 문서를 정리한다.
- M1/Tahoe 26.3 및 최소 지원 macOS 12, 실제 NSSavePanel sandbox 권한, 물리 한글 IME, 실제 WebContent process crash, 대형 문서 출력 성능은 미검증이다.
- Word 실기 호환성을 HTML importer 결과로 대신해 완료 표시하지 않는다.
- PR 게시·이슈 close·릴리스는 수행하지 않았다.

## 다음 단계 승인 요청

Stage 4 구현과 검증을 완료했다. Stage 5 “통합 회귀와 문서 정리” 진입 승인을 요청한다. 이미 최종 소스로 통과한 검증은 재사용하고, 새 변경·미확인 흐름에 필요한 검증을 보완한다.
