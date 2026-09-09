# Task #516 Stage 2 완료 보고서

## 단계 목적

파일 bytes 유무와 편집기 문서의 존재를 분리하여 자동 새 문서·내부 문서 교체·dirty 상태를 HostApp에 등록한다. 명시적인 파일 열기·재시도와 metadata 갱신을 구분하여 SwiftUI 갱신이 편집기를 재로드하거나 이전 원본을 다시 연결하지 않게 한다.

- 이슈: [#516](https://github.com/postmelee/alhangeul-macos/issues/516)
- 마일스톤: `M010` / `v0.1`
- 작업 브랜치: `local/task516`, 대상 `devel`
- 기준: [구현계획서](../plans/task_m010_516_impl.md)의 Stage 2, 같은 스레드의 “진행해줘” 승인

## 산출물

| 파일 | 변경 내용 |
|------|-----------|
| `Sources/HostApp/Services/RhwpStudioEditorSession.swift` | 51줄 신규. loadID·메시지 순서·editor epoch·changeSeq·dirty·ready·pageCount·format 및 native 원본 연결 상태, 오래된 상태 거부 |
| `Sources/HostApp/Services/RhwpStudioEditorSessionScript.swift` | 84줄 신규. 초기 조회, 이벤트 병합, 공개 API를 통한 상태 조회, 비동기 경계 검증, 준비 상태 통지 |
| `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift` | 입력·명령·상태 표시 변경을 상태 재조회 계기로 연결. 이벤트가 발생했다는 이유만으로 dirty 통지를 보내던 경로 교체 |
| `Sources/HostApp/Stores/DocumentViewerStore.swift` | 세션·명시적 loadID 소유, 준비된 세션 기준 문서 명령 활성화, 원본 해제와 실제 dirty 반영, 실패·재시도 상태 처리 |
| `Sources/HostApp/Views/RhwpStudioWebView.swift` | loadID 변경에서만 reload, 로드별 token과 메시지 검증, 내부 교체 시 source·payload 해제, 지연 SwiftUI metadata 복원 방지 |
| `Sources/HostApp/Views/DocumentViewerView.swift` | Store의 loadID와 세션 callback 연결 |
| `Tests/HostAppTests/RhwpStudioEditorSessionTests.swift` | 81줄 신규. 준비·편집·교체·취소·지연 응답 및 로드 전이 4개 테스트 |
| `Tests/HostAppTests/RhwpStudioEditorSessionScriptTests.swift` | 96줄 신규. JavaScriptCore에서 초기 생성 전후·dirty·중복·비동기 교체·렌더 준비 동작 4개 테스트 |
| `project.yml`, `Alhangeul.xcodeproj/project.pbxproj` | 테스트에 신규 서비스 추가 후 XcodeGen으로 프로젝트 생성 |

### 구현 계약

1. Store의 `webViewLoadID`는 유효한 native 파일 열기와 명시적인 재시도에서만 증가한다. 파일명·저장 결과·dirty·source 해제는 reload 의도가 아니다.
2. Coordinator는 WebView 로드마다 token을 주입한다. main frame에서 현재 token·loadID에 대응하는 상태만 받는다. Store와 Coordinator는 같은 순수 상태 전이 함수를 사용하여 이전 epoch·낮은 변경 순서·중복 메시지를 거부한다.
3. 초기 bytes가 없어도 세션을 등록한다. 내부 epoch가 바뀌면 준비 중이라도 이전 source URL·payload를 해제하며, 늦게 도착한 같은 loadID의 SwiftUI 갱신으로 복구하지 않는다.
4. `nativeLoad`는 native가 검증한 bytes·보호 정보와 연결된 상태다. native 로드에 대응하지 않는 문서는 `editorOnly`로 두어 이전 보호 상태를 계승하지 않는다. 화면 파일명이나 상태 문구로 새 평문 문서라고 단정하지 않는다.
5. 문서 준비와 문서 세대는 별개다. 고정 bundle의 `rhwp-busy` 표시를 준비 여부에만 사용한다. 새 epoch의 원본 해제는 즉시 반영하고, 화면 구성 중에는 native 문서 명령을 활성화하지 않는다.
6. 입력 이벤트는 실제 handler가 실행된 뒤 40ms 단위로 합쳐 조회한다. 1초 간격의 가벼운 재확인으로 구독 전 생성과 DOM 이벤트가 없는 automation 변경도 확인한다. 내보내기·선택·취소 이벤트 자체를 편집으로 취급하지 않는다.

Stage 1 이후 추가 확인한 공개 `getSelectionContext`는 `documentEpoch`와 `changeSeq`를 반환한다. 고정 bundle의 구현과 실제 응답을 확인했다. 일반 상태 갱신에는 이 API, `pageCount`, `automation.getContext()`를 사용하고, 전체 exporter/SHA를 만드는 `getDocumentState`는 첫 등록과 epoch 교체에만 사용한다. 조회 전후 세대·변경 순서가 다르면 혼합된 snapshot을 버리고 재확인한다. 선택 context는 현재 문단·선택의 검사를 포함하므로 비용이 전혀 없다는 뜻은 아니다.

## 본문 변경 정도 / 본문 무손실 여부

HostApp의 문서 상태 연결과 테스트를 변경했다. core pin·Rust/FFI·bundled asset·문서 exporter는 바꾸지 않았다. 수행·구현계획과 오늘할일은 진행 상태 및 이번 검증에서 구체화한 계약만 갱신했다.

검증에는 task516 아래 합성 문서만 사용했다. HWP fixture의 SHA-256은 생성 당시와 이전 파일 → 새 문서 → 저장 시도 후 동일한 `01aa8c00057692115171f5dcaecc2f5bb3032dd84745d298379e787f6b660333`이었다. HWPX 합성 출력의 section XML에서 `다른 새 문서`를 확인했다. 이는 상태 유지 검증이며 Stage 3의 native 최초 저장 완료 검증을 대신하지 않는다.

## 검증 결과

환경은 macOS `26.5.2` / `arm64`다. 실제 제보 환경인 M1 / Tahoe 26.3과 macOS 12에서는 실행하지 않았다.

```text
xcodegen generate: 성공
HostAppTests: Executed 192 tests, with 0 failures / TEST SUCCEEDED
HostApp Debug build, CODE_SIGNING_ALLOWED=NO: BUILD SUCCEEDED
check-no-appkit.sh: OK
verify-rhwp-studio-assets.sh: source 및 Debug app resource 모두 OK
실제 Store + Coordinator + WKWebView: boolean checks=23, failures=0, snapshots=13
최종 진단 앱: process exit=0
HWPX section XML: 다른 새 문서 확인
```

HostAppTests와 HostApp은 구현계획의 명령을 그대로 사용했고, DerivedData는 `build.noindex/task516/DerivedDataTests`, `build.noindex/task516/DerivedData`에 기록했다. 생성 framework 재사용 전 `rhwp-core.lock` 일치 및 고정 header·library의 크기/SHA-256을 대조했다.

진단 앱은 제품 Store·Coordinator·bridge와 필요한 Shared/Core 소스를 직접 컴파일했다. bundle ID는 `com.postmelee.task516.stage2`이며 확장을 포함하지 않는다. 제품 문서 상태 로직을 mock으로 대체하지 않았다. UI 테스트 입력은 WKWebView의 실제 textarea에 `execCommand('insertText')`를 적용했다.

| 실제 통합 시나리오 | 결과 |
|-------------------|------|
| 앱 시작 후 빈 문서 | 준비 중 → 준비 완료 등록, clean 및 native 문서 도구 활성화 |
| `ㅇㅇ` 입력 | 같은 epoch의 changeSeq 증가, Store dirty 반영 |
| 파일명 갱신·반복 update 20회 | page의 marker와 입력 문서 유지, reload 없음 |
| 기존 HWP 로드 후 저장 metadata 갱신 | source 유지, reload 없음 |
| 편집된 기존 문서에서 새로 만들기 → 취소 | 기존 source·epoch·dirty 유지 |
| 새로 만들기 → 저장 안 함 | epoch 교체, 준비 중부터 이전 source·payload 해제, 완료 후 clean |
| 교체 후 이전 SwiftUI payload 전달 | 이전 source 복원 및 reload 없음 |
| 이전 epoch의 높은 sequence 통지·이전 Store callback | 새 문서 상태를 덮어쓰지 않음 |
| 교체된 새 문서에 입력 후 native 저장 시도 | Stage 3 이전의 저장 미연결 오류 유지, 이전 HWP는 변경되지 않음 |
| 0-byte 파일 열기 실패 | recoverable 오류, 현재 세션·dirty 보존 |
| HWPX 로드 | 형식·source·준비 완료 연결 |
| WebContent 종료 callback와 재시도 | 준비 상태 해제 후 새 loadID로 복구, source 유지 |
| 이전 로드의 Store callback·page token | 현재 세션 변경 없음 |

최종 증거는 worktree의 `build.noindex/task516/stage2/` 아래에 있다.

- `tests-final.log`, `build-final.log`: 최종 Xcode 검증
- `probe-ready-final.jsonl`, `probe-ready-final.stderr.log`: 실제 구성요소 통합 결과
- `verification-summary.json`: 23개 boolean 검사와 fixture 확인 요약
- `Probe.swift`, `build-probe.py`, `source-files.txt`, `probe-compile.log`: 재현 runner·컴파일 근거
- `Task516Probe.app`, `fixture.hwp`, `fixture.hwpx`: 후속 단계에서 재사용할 격리 산출물

초기 runner는 화면 구성 중 입력을 시도하여 본문 자체가 입력되지 않았다. 이후 실제 입력 반환값과 editor 상태를 대조했다. dirty 문서 교체에서는 epoch 변경 직후 이전 dirty 값이 잠깐 남는 것도 확인하여 `ready`를 분리했다. 최종 검증은 준비 완료 후 입력하며 이전 실패 로그를 성공 근거로 사용하지 않는다. WebContent 종료 검증은 실제 프로세스를 강제 종료한 것이 아니라 제품 delegate callback을 호출한 상태 전이 검증이다.

## 잔여 위험

- 최초 저장, 새 문서 PDF, 저장 요청의 세션 fence와 request ID는 Stage 3 범위로 아직 연결하지 않았다. 현재 새 문서 저장에는 “저장할 문서가 없습니다.”가 표시된다.
- 상태 재조회는 비동기다. 교체 통지가 도착하기 전에 저장 명령이 들어오는 경계는 Stage 3에서 fresh snapshot을 확인하여 방어해야 한다. 이번 원본 보존 성공만으로 모든 저장 경쟁 조건이 해소됐다고 판단하지 않는다.
- `editorOnly`는 자동복구·내부 파일 열기도 포함한다. 최초 저장에서는 이전 source를 사용하지 않고, 출처 미확정 문서의 `invalidOrUnknown` 복사본 정책을 적용해야 한다. 확인된 새 문서의 평문 분류는 명시적 생성 의도와 완료 증거가 있어야 한다.
- Word·HTML native 다운로드 연결은 Stage 4에 남아 있다. HTML이 main page를 교체하는 기존 동작도 아직 수정하지 않았다.
- 물리 한글 IME, 저장 패널 권한·취소·쓰기 실패, 실제 WebContent process crash, 제보 OS와 최소 지원 OS는 이번 검증의 범위가 아니다.

## 다음 단계 영향

Stage 3은 `editorSession.snapshot`의 loadID·epoch·ready를 사용해 native 저장 명령을 검증한다. `currentDocument` nil은 더 이상 editor 문서 부재를 뜻하지 않는다. 첫 저장 성공은 같은 세션에 bytes·source metadata를 명시적으로 연결하되 `webViewLoadID`를 증가시키지 않아야 한다.

`recordSavedDocument`의 최초 payload 생성, 저장 완료 후 dirty 동기화 경쟁 방어, PDF 및 닫기·앱 종료 저장 경로를 후속 구현 대상으로 유지한다. 정상 파일 → 새 문서의 source 해제와 취소·retry 검증 runner는 그대로 재사용할 수 있다.

## 승인 요청

Stage 2 구현과 검증을 완료했다. Stage 3 “첫 저장·후속 저장과 native 문서 명령 연결” 진입 승인을 요청한다. 이슈 close·PR 게시·릴리스는 수행하지 않았다.
