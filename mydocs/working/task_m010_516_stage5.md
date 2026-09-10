# Task #516 Stage 5 완료 보고서

## 단계 목적과 결과

새 문서 저장·내보내기의 이슈 완료 기준을 최종 제품 소스의 검증 결과와 연결하고, 실제 native 저장 패널 및 종료 버리기 검증을 보완했다. 문서 상태·저장·출력 책임과 반복 가능한 smoke 절차를 갱신했다.

- 이슈: [#516](https://github.com/postmelee/alhangeul-macos/issues/516), `M010` / `v0.1`
- 브랜치: `local/task516`, 통합 대상 `devel`
- 승인: 같은 스레드의 “진행해줘”, [구현계획서](../plans/task_m010_516_impl.md) Stage 5
- 상태: Stage 5 검증·문서 정리 완료, 최종 보고·PR 게시 승인 대기
- 실행 환경: macOS 26.5.2 / arm64. 제보의 M1 / Tahoe 26.3과 구분한다.

Stage 5에서는 제품 소스·테스트·project 설정·core pin을 변경하지 않았다. 최종 제품 소스는 Stage 4 커밋 `b33c9c2`와 동일하다. 따라서 해당 소스의 HostAppTests 201개(실패 0), HostApp Debug build 성공, Word/HTML 통합 50개와 조합 이벤트 2개, 기존 저장/PDF/종료 회귀 59개 결과를 재사용했다. 새로 확인한 실제 패널과 종료 경계를 아래에 구분한다.

## 이슈 완료 기준별 증거

| 완료 기준 | 실행 결과와 근거 |
|-----------|------------------|
| 파일 없는 시작 → 한글 입력 → 첫 HWP/HWPX 저장 → 재열기 | Stage 3/4 회귀에서 두 형식 첫 저장 통과. Stage 5 실제 HWP 패널에서 `ㅇㅇ` 저장 후 core 본문 확인, 이어 HWPX 패널로 변환 저장·재열기 통과 |
| 후속 Command+S 경로·형식 유지 | Stage 5 native key equivalent 경로에서 같은 HWP 파일에 `후속 입력` 반영, 추가 패널 없음. Stage 4 회귀에서 HWPX 포함 확인 |
| 패널 취소·쓰기 실패 시 내용과 dirty 보존 | Stage 5 실제 NSSavePanel의 cancel 동작 확인. 쓰기 실패·오래된 응답·문서 교체·중복 요청은 Stage 4 최종 회귀에서 검증 |
| 새 dirty 문서의 닫기·앱 종료 저장/취소/버리기 | Stage 3/4 회귀에서 저장·취소·실패·최신 dirty 조회 확인. Stage 5에서 실제 확인 sheet의 버리기 응답 후 창 닫힘 및 앱 종료 허용, 원본 bytes 불변 확인 |
| 새 문서 PDF와 도구 활성화 | Stage 3/4 새 문서 PDF 회귀 통과. Stage 5 PDF 패널로 저장한 PDF의 최신 한글 text layer 확인. 공유/PDF 도구는 Store의 `canRunWebViewCommands`와 연결됨을 코드로 대조했으며 전체 HostApp toolbar 버튼의 UI 클릭 검증과는 구분 |
| 기존 파일 → 새 문서의 source·보호 상태 분리 | Stage 2 상태 테스트 및 Stage 3/4 통합 회귀에서 이전 URL/bytes 분리, 이전 원본 bytes 보존 확인 |
| 새/기존 Word·HTML 내용 및 취소·실패 상태 보존 | Stage 4 실제 WKDownload와 DOM 메뉴, 기존 HWP/HWPX 네 조합·실패 주입 통과. Stage 5 실제 DOC/HTML 패널로 출력하고 최신 본문·원본 bytes·URL·dirty 보존 확인 |
| 기존 HWP/HWPX·암호 평문 복사본·HWP3 정책 회귀 | 기존 두 형식 저장/열기와 보호·변환 정책 테스트 통과. 실제 암호 문서/HWP3 fixture의 UI 복호화·변환 전 과정은 미검증이며 정책 테스트를 실기 검증으로 일반화하지 않음 |

## 실제 NSSavePanel과 종료 검증

제품 Store·Coordinator·bridge·WKDownload·PDF renderer·저장/종료 controller를 그대로 컴파일한 task516 전용 진단 앱을 사용했다. 제품의 destination callback을 대체하지 않고 HWP, HWPX, PDF, DOC, HTML의 실제 NSSavePanel을 표시했다. Computer Use로 각 파일명과 검증 폴더를 확인하고 Save 버튼을 클릭했다. 저장 취소는 표시된 NSSavePanel의 `cancel`을 호출했다. 첫 출처 미확정 확인과 종료 확인은 실제 NSAlert sheet에 응답을 전달했다. 파일 열기/입력과 일부 명령은 진단 코드에서 호출했으므로 물리 키보드 입력이나 전체 HostApp UI 전 과정의 검증이라고 보고하지 않는다.

| 산출물 | 검증 내용 |
|--------|-----------|
| `native-first.hwp` | CFB signature, core 재열기 1페이지, `ㅇㅇ 후속 입력` |
| `native-copy.hwpx` | ZIP 무결성, `application/hwp+zip`, Contents/META-INF, core 재열기 1페이지, `ㅇㅇ 후속 입력 취소 후 유지` |
| `native.pdf` | PDFKit text layer에 `내보내기 입력` 포함 |
| `native.doc`, `native.html` | UTF-8 HTML 본문에 `내보내기 입력` 포함, 출력 이후 HWPX 원본 bytes·URL 및 dirty 유지 |
| 0-byte `empty.hwp` | 열기 실패 후 기존 loadID·epoch·dirty 유지 |

실제 패널 실행 로그에는 성공한 boolean 검사 21개가 있으나, 이 실행 전체는 종료 확인을 추가하려고 닫힌 창에 같은 controller를 재부착한 뒤 exit 139로 끝났다. 따라서 전체 실행 성공으로 집계하지 않는다. 파일 생성·본문·상태 보존 등 종료 전 완료된 관측만 증거로 사용한다.

종료 버리기는 별도 runner에서 검증용 HWPX를 읽고 새 내용을 입력한 뒤 앱 종료 확인 → 창 닫기 확인 순서로 실행했다. 실제 종료 대신 주입한 reply callback이 true인지 확인하고, 두 경우 모두 원본 bytes가 동일함을 확인했다. 6개 검사 통과, 오류 0, exit 0이다. 이 runner의 `native-close-prompts-after-export` 이름은 이전 runner에서 이어진 명칭이며, 별도 실행에서 내보내기를 다시 수행했다는 뜻은 아니다.

### 진단 실패의 구분

- 초기 두 실행은 표시된 NSSavePanel의 directory/name을 직접 설정하고 `ok(nil)`을 호출하는 과정에서 WebKit 렌더링 stack의 SIGSEGV로 종료됐다. 패널 URL이 설정한 task 폴더를 반영하지 않은 상태였다. 직접 호출 원인이 확정된 것은 아니며 제품 저장 성공의 근거로 사용하지 않는다.
- URL 일치를 확인하도록 보완한 실행에서는 task 경로로 전환되지 않아 쓰기 전에 취소했다. 이후 실제 UI로 경로와 이름을 설정한 실행에서는 다섯 형식의 파일 저장이 모두 완료됐다. 초기 실패 로그는 보존한다.
- UI 실행 마지막 종료는 `DocumentCloseConfirmationController.responds(to:)` 재귀 stack이었다. 닫힘 처리에서 controller의 window 참조가 해제되지만 window.delegate는 남은 상태에서, 진단 코드가 동일 창/controller를 다시 attach하여 previousDelegate가 자신을 가리킨 경로다. 관련 attach/detach/forwarding 코드는 기준 커밋 `56fe1ca6`에도 동일하다. 최종 진단은 닫힌 창을 재사용하지 않고 종료 확인을 먼저 수행했다. 이 인위적인 재부착 경계는 기존 코드의 별도 보완 후보로 남기며, 본 이슈의 일반 창 닫기 회귀로 혼동하지 않는다.
- 초기 UI 상태 조회 1회 timeout 및 진단 앱의 이전 복구 안내가 있었다. 실제 패널 실행에서는 복구 안내의 ‘나중에’를 선택한 후 진행했다. 사용자 설치본이나 문서 복구 데이터를 삭제하지 않았다.

## 문서 변경

- [project_architecture.md](../tech/project_architecture.md): 파일 bytes와 편집 세션 분리, token/loadID/epoch 동기화, 첫 저장과 dirty 처리, 최신 상태를 조회하는 종료 확인, Word/HTML native 다운로드와 원본 보호 계약을 반영했다. 오래된 저장 메시지·쓰기 실패 fallback·PDF 응답 설명을 현재 구현에 맞게 수정했다.
- [build_run_guide.md](../manual/build_run_guide.md): 첫 저장부터 취소·다른 형식·내보내기·종료·열기 실패까지 반복할 smoke 표와 본문 확인 방법을 추가했다. 실제 패널/주입, HTML DOC/Word 호환성, 조합 API/물리 IME를 구분했다.
- 수행계획·구현계획·오늘할일은 진행 상태만 갱신했다. 오늘할일 완료 처리는 최종 보고 단계에 남긴다.

## 증거와 재실행 범위

worktree의 `build.noindex/task516/`에 보존한다.

- `stage4/tests-final.log`, `stage4/build-final.log`: 201개 테스트와 최종 제품 빌드
- `stage4/verification-summary.json`, `stage4/regression/verification-summary.json`: 통합/회귀 결과, [Stage 4 보고서](task_m010_516_stage4.md)에 상세 시나리오·실행 명령 기록
- `stage5/probe-panel-ui.jsonl`: 실제 패널 6회(저장 5회·취소 1회), 최초/후속 저장과 내보내기 관측. 종료 전 성공 21개, 프로세스 exit 139
- `stage5/probe-discard-final.jsonl`: 종료·닫기 버리기 보완 6개, exit 0
- `stage5/probe-native-panels.jsonl`, `probe-panel-diagnostic.jsonl`, `probe-panel-ready.jsonl`: 초기 실패/취소 기록
- `stage5/run-02D62BD3-0FD3-4163-9E6A-D50097E42DF7/`: 실제 패널로 만든 합성 파일 및 core SVG
- `stage5/core-roundtrip.log`, `verification-summary.json`: 페이지·본문·컨테이너 확인 및 파일 크기/SHA-256
- `stage5/Probe.swift`, `build-probe.py`, `source-files.txt`: 최종 버리기 검증 runner와 컴파일 설정. 실제 패널 조작은 이 스레드의 Computer Use 기록을 따른다.

컴파일은 `python3 build.noindex/task516/stage5/build-probe.py`, 실행은 `build.noindex/task516/stage5/Task516Probe.app/Contents/MacOS/Task516Probe`를 사용했다. 파일 경로 인수를 전달하면 core 재열기·본문 및 SVG 확인을 수행한다. WKWebView/AppKit 실행은 제한된 실행 환경 밖에서 수행했다. 문서 변경은 `git diff --check`와 상대 링크 검사를 수행한다.

## 제한과 산출물 정리

M1/Tahoe 26.3, 최소 지원 macOS 12, 서명된 sandbox 앱의 실제 권한, 물리 한글 IME, 실제 WebContent process crash 복구, 대형 문서 성능은 미검증이다. Word 실기 열기·레이아웃·편집 호환성도 미검증이며, Stage 4의 macOS HTML importer 성공과 구분한다. DOC는 고정 upstream의 HTML 기반 .doc이다.

표준 등록 검사에서 개발 Alhangeul 등록은 없었다. 기존 설치본 `/Applications/Alhangeul.app`과 `~/Applications/Alhangeul.app`의 두 provider root 때문에 전체 검사 exit 1이므로 시스템 전체 통과로 표시하지 않는다. task516 진단 앱 등록만 정확한 경로로 해제했다. `stage5/registration-final-summary.json`에서 task516 LaunchServices/importer 잔류는 모두 false이고 내보내기 staging 잔류도 없다. 기존 설치본·다른 worktree·기본 연결·전역 캐시/색인은 유지한다. 검증 앱·합성 문서·실패 로그는 최종 보고 검토에 필요하므로 task 폴더에 보존한다.

제품 소스 변경과 사용자 원본 문서 변경은 없다. 원본/출력 보존은 bytes 및 SHA로 확인했으며 문서는 관련 책임 설명과 진행 상태만 갱신했다. 이슈 close·push·PR 게시·릴리스는 수행하지 않았다.

## 다음 단계

Stage 5를 완료했다. 최종 결과보고서 작성, 오늘할일 완료 처리, 최종 커밋과 `publish/task516` 게시 및 `devel` 대상 PR 생성 단계의 승인을 요청한다.
