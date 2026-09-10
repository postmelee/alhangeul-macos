# Task #516 Stage 1 완료 보고서

## 단계 목적

새 문서 저장과 Word·HTML 내보내기 실패를 고정된 rhwp-studio 및 실제 HostApp 코드로 재현하고, Stage 2 이후 구현할 문서 세션·저장·출력 계약을 확정한다.

- 이슈: [#516](https://github.com/postmelee/alhangeul-macos/issues/516)
- 마일스톤: `v0.1` (`M010`), 작업 브랜치: `local/task516`, 통합 대상: `devel`
- 계획: [수행계획서](../plans/task_m010_516.md), [구현계획서](../plans/task_m010_516_impl.md)
- 승인: 2026-09-10 같은 스레드의 “진행해줘”로 구현계획과 Stage 1 진행 승인
- 검증 환경: macOS 26.5.2 (`25F84`), arm64. 사용자 제보 환경인 M1 / Tahoe 26.3의 직접 실행 결과로 해석하지 않는다.

## 산출물

제품 소스 변경 없이 `RhwpStudioWebView.Coordinator`, native dispatcher, HostBridge, resource/document scheme 및 저장 서비스 등 제품 Swift 파일 22개를 그대로 컴파일한 격리 진단 앱을 만들었다. 이 22개 파일은 모두 공개판 `v0.1.11`의 같은 경로와 byte 단위로 일치한다. bundled asset은 `rhwp v0.8.6` / `f1f9c6ae58344ee9368996d3543f76b9345cf227` 고정본이다.

| 산출물 | 내용 |
|--------|------|
| 본 보고서 | 재현 증거, API 한계, 확정 계약, 다음 단계 검증 기준 |
| `task_m010_516_impl.md` | Stage 1 결과에 따른 상태 동기화·WKDownload 구현 경로 확정 |
| `mydocs/orders/20260910.md` | Stage 1 완료·Stage 2 승인 대기로 갱신 |
| `build.noindex/task516/stage1/Probe.swift` | 208행 진단 runner. 실제 Coordinator로 WebView 생성·로드·저장 처리 |
| `source-files.txt`, `compile.log` | 컴파일한 제품 소스 목록과 성공 로그 |
| `probe-expanded.jsonl` | 66행. 저장 실패, HTML 화면 이탈, 세대 변경과 4개 다운로드 결과 |
| `probe-confirmation.jsonl` | custom scheme의 MessageChannel 제약 확인 |
| `probe-overwrite-final.jsonl` | 30행. native dispatcher 저장 완료와 임시 원본 덮어쓰기 확인 |
| `verification-summary.json` | 기대 결과 16개 PASS, 제품 소스·내보내기 파일 SHA-256 |
| `assets.log`, `upstream/` | bundle 검증과 고정 commit에서 추출한 API 소스 근거 |

`build.noindex/`의 runner·앱·로그·출력 파일은 Stage 2 이후 재현에 쓰는 로컬 진단 산출물로 유지하며 Git에 포함하지 않는다. 설치된 사용자 앱에는 기존 문서가 열려 있어 문서 조작에 사용하지 않았다. 진단 앱은 고유 bundle ID `com.postmelee.task516.probe`를 사용하고 Quick Look/Thumbnail extension을 포함하지 않는다.

## 본문 변경 정도 / 본문 무손실 여부

HostApp 제품 코드, 테스트 target, core lock, bundled asset을 변경하지 않았다. 사용자 문서와 저장소 fixture는 변경하지 않았다.

진단 runner가 만든 `probe-new.hwp`에는 `ㅇㅇ`을 넣었다. 별도 `overwrite-fixture.hwp`를 로드한 뒤 새 문서에 `다른 새 문서`를 입력하고 실제 native 저장을 호출했다. **이 임시 원본이 새 문서 내용으로 덮어써지는 것을 확인했다.** 이는 의도한 정상 저장이 아니라 기존 source 잔류 결함의 재현이다.

## 검증 결과

### 재현 결과

| 시나리오 | 관측 결과 | 판정 |
|----------|-----------|------|
| 파일 없이 초기 실행 | editor `pageCount=1`, `documentEpoch=1`, native `currentDocument=nil` | 상태 불일치 재현 |
| 새 문서에 `ㅇㅇ` 입력 | editor `changeSeq=1`, `dirty=true`; native 편집 callback 0회 | dirty 동기화 누락 재현 |
| 저장·다른 이름 저장 | 각각 “저장할 문서가 없습니다.” | 실제 Coordinator의 실패 경로 재현 |
| PDF 내보내기 | “PDF로 내보낼 문서가 없습니다.” | 같은 상태 검사 실패 재현 |
| 새 문서 HWP exporter 직접 호출 | 12,800 bytes 반환 | exporter 자체는 새 문서를 출력할 수 있음 |
| Word 명령 실행 | `ok=true`, `shouldPerformDownload=true` Blob 요청 발생 | 출력 요청은 생성되나 제품에 destination/delegate 연결 없음 |
| HTML 명령 실행 | `.allow` 정책 뒤 main WebView가 Blob URL로 이동, `hasStudio=false`, body text `ㅇㅇ` | 편집기 화면 이탈 재현 |
| 임시 기존 파일 로드 → 새 문서 생성 | editor epoch 1→2, native에는 이전 payload·source URL 유지 | 문서 교체 동기화 누락 재현 |
| 위 새 문서를 native dispatcher로 저장 | 이전 임시 원본 URL에 저장 완료, bytes 변경, callback 1회, pending nil | 이전 원본 덮어쓰기 재현 |
| 진단 delegate에서 Blob 요청을 `.download` 처리 | 새 문서·기존 문서의 DOC/HTML 총 4개 파일 저장 완료 | WKDownload 연결 가능성 확인 |

실제 native 저장 완료 로그의 핵심은 다음과 같다. 경로는 진단 폴더의 임시 원본을 뜻한다.

```text
native-save-handler: true
native-saved: overwrite-fixture.hwp, 12800 bytes
native-save-completion: saved(overwrite-fixture.hwp)
overwrite-result: changed=true, savedCallbacks=1, pending=nil
overwrite-after-save: documentEpoch=2, changeSeq=1, dirty=false
```

진단 앱의 기본 정책은 제품 Coordinator에 위임했다. 다운로드 가능성 실험에서만 별도 delegate가 `shouldPerformDownload=true`인 Blob 요청을 `.download`로 전환하고 task 전용 경로를 제공했다. 이 실험은 제품 수정 완료나 native 저장 패널 검증이 아니다.

| 입력 | 출력 | 크기 | 텍스트 및 editor 상태 |
|------|------|------|-----------------------|
| 새 문서 `테스트` | HTML 기반 `.doc` | 388 bytes | 본문 포함, dirty 유지 |
| 새 문서 `테스트` | `.html` | 276 bytes | 본문 포함, dirty 유지 |
| 기존 임시 파일 `ㅇㅇ` | HTML 기반 `.doc` | 384 bytes | 본문 포함, clean 유지 |
| 기존 임시 파일 `ㅇㅇ` | `.html` | 272 bytes | 본문 포함, clean 유지 |

### 고정 API 확인

| API/표면 | 확인 사항 | 채택 판단 |
|----------|-----------|-----------|
| legacy `getDocumentState` | `schemaVersion`, `format`, `documentEpoch`, `changeSeq`, `dirty`, `pageCount`, `documentSha256` 반환 | 초기 동기화·교체 및 저장 전 검증에 사용 |
| `rhwpStudio.automation.getContext()` | `hasDocument`, `isDirty`, `sourceFormat` 등 조회 | 가벼운 준비·dirty 확인에 사용 |
| `automation.execute('file:new-doc')` | 호출 성공 후 비동기 초기화, epoch 증가 | 반환 `ok`만으로 완료 처리하지 않음 |
| `notifySaved` | 파일명 갱신, dirty 해제, 복구 draft 정리 | HWP/HWPX durable write 이후에만 호출 |
| `exportHtml` RPC | `Unknown method: exportHtml` | 직접 HTML RPC 경로 사용 안 함 |
| `getHmlSaveState` | sourceFormat·HML 저장 가능성과 blocker만 제공 | 암호 상태·새 문서 생성 증명에 사용 안 함 |
| `documentChanged` 이벤트 | document-agent apply/revert의 이벤트. 일반 입력·새 문서 이벤트 전체가 아님 | 문서 수명주기 구독으로 사용 안 함 |
| MessageChannel connect | custom origin에서 응답 없음. runtime은 HTTP(S) parent origin만 허용 | 현재 custom scheme에서는 legacy transport 유지 |

`getDocumentState`는 문서 exporter를 호출하여 SHA-256을 계산한다. 한 페이지 synthetic 문서에서 10회 조회는 7ms였으나, 이 수치를 큰 문서의 비용으로 일반화하지 않는다. 매 키 입력마다 전체 문서를 export하는 주기적 polling은 채택하지 않는다.

upstream 공개 production 전역은 automation·plugin host·notifySaved 등이며, `__wasm`, `__eventBus`, `__documentState`는 개발 모드에서만 노출된다. 제품 bridge가 이 개발 전역이나 minified 내부 식별자에 의존하지 않도록 한다.

### 검증 명령과 결과

```text
swiftc: 제품 Swift 소스 22개 + Probe.swift 컴파일 성공
verify-rhwp-studio-assets.sh: OK
probe-expanded: finished=true
probe-overwrite-final --overwrite-only: finished=true, process exit=0
verification-summary: pass=16, fail=0
제품 Swift 22개와 v0.1.11 소스 비교: 모두 일치
```

기존 코드의 `NSURLErrorFailingURLStringErrorKey` deprecation 경고 3건이 있으며 컴파일 오류는 없다. 기대 실패의 재현과 실험 출력 검증을 통과했다는 뜻이며 제품 버그가 수정되었다는 뜻은 아니다.

진단 앱 컴파일은 `source-files.txt`의 파일과 `Probe.swift`를 `xcrun swiftc`에 전달하고 출력 경로를 `Task516Probe.app/Contents/MacOS/Task516Probe`로 지정했다. 실행 시 cwd는 task516 worktree이며 결과는 위 JSONL 파일에 저장했다. 초기 진단의 HTML 후 RPC 접근 실패는 편집기 문맥이 사라진 결과여서 최종 runner는 URL·DOM을 직접 관측하도록 보정했다. 덮어쓰기 판정은 짧은 대기 결과 대신 native 저장 completion을 확인한 최종 로그를 기준으로 했다.

## 확정한 구현 계약

### 문서 세션과 초기 동기화

`RhwpStudioEditorSession`을 HostApp 전용 상태 모델로 도입한다. 개념 필드는 native `loadID`, editor `documentEpoch`, `changeSeq`, `dirty`, `pageCount`, 저장 형식 및 source 연결이다. source는 native가 요청한 파일 로드, 확인된 새 문서, 원본 정보가 없는 editor 문서를 구분한다.

- `loadID`는 native 파일 열기·retry/reload에서만 증가한다. 파일명·dirty·저장 완료 metadata 변경은 WebView load 요청이 아니다.
- 최초 `ready` 이후 유효한 문서 snapshot을 받아 현재 세션을 등록한다. 처음에는 native bytes가 없어도 editor 문서가 존재할 수 있다.
- 상태 표시 DOM 변화, 입력/편집 이벤트, 문서 수명주기 명령은 snapshot 재확인의 계기로 사용한다. 파일명·상태 문자열을 source identity 또는 평문 판정의 단독 근거로 사용하지 않는다.
- 일반 입력의 dirty 확인은 이벤트 처리 이후 가벼운 automation context로 병합 처리한다. 전체 snapshot은 최초 준비, 문서 교체 후보, 저장/내보내기 시작 등 identity 검증 경계에서 확인한다.
- `file:new-doc`은 native bridge에서 교체 의도를 추적하고 upstream 명령을 실행한다. 기존 epoch와 다른 유효한 snapshot을 얻은 뒤 완료로 처리한다. 취소·실패는 기존 source를 유지한다.
- native 파일 로드에 대응하지 않는 epoch 변경을 발견하면 이전 source를 즉시 분리한다. 원본 정보 없는 editor 문서는 첫 저장에서 항상 destination 선택을 거친다.
- 원본 암호·HWP3 정보는 native가 읽은 bytes의 metadata에만 연결한다. 새로 만들기 완료가 확인된 문서만 새 평문으로 분류하고, 초기 복구 등 출처를 입증하지 못한 문서는 `invalidOrUnknown`과 기존 복사본 정책을 적용한다. metadata가 없는 이유만으로 이전 파일의 보호 상태를 계승하거나 평문으로 단정하지 않는다.
- `rhwpStudioDocument`는 파일 로드/재시도에 필요한 bytes와 저장 결과를 담되, 값이 갱신되었다는 이유로 `update`가 reload하지 않도록 명시적인 load intent를 분리한다.

### 저장과 비동기 응답

- native 저장 경로를 결정하기 전에 `(loadID, documentEpoch)`를 다시 확인한다. UI의 source 갱신 통지가 늦더라도 이 검사를 통과하기 전에는 이전 URL로 쓰지 않는다.
- `PendingSaveRequest`는 request ID와 세션을 묶고, `save-document`/오류 응답도 같은 ID를 사용한다. 패널 선택·export 완료·write 직전의 stale 요청은 무효화한다.
- 저장 패널에서 파일을 선택하는 동안 편집은 유지할 수 있다. 입력을 확정하고 export snapshot을 만드는 시점부터 write·`notifySaved` 완료까지 짧게 편집과 문서 교체를 직렬화한다. 잠금 해제는 성공·실패·WebContent 종료 모두에서 보장한다.
- 파일 write 성공 뒤 Store와 Coordinator에 첫 저장의 URL·bytes·형식·metadata를 등록하되 세션은 유지한다. 재로드나 source 미등록 때문에 입력이 사라지지 않아야 한다.
- `notifySaved` 실패는 파일 저장 성공과 별도 상태이다. Word/HTML/PDF에는 호출하지 않는다.
- 저장 실패·취소 시 원본과 dirty 상태를 보존하고, 종료 확인의 저장 실패는 창을 유지한다.

### Word·HTML 내보내기

WKDownload를 채택한다. [Apple의 다운로드 동작 식별 API](https://developer.apple.com/documentation/webkit/wknavigationaction/shouldperformdownload)와 [WKDownloadDelegate](https://developer.apple.com/documentation/webkit/wkdownloaddelegate)의 계약을 확인했고, 현재 SDK header는 Blob 합성 응답과 destination이 존재하지 않아야 한다는 조건을 명시한다.

1. `file:export-doc`/`file:export-html`을 native command 및 비변경 명령으로 등록한다.
2. destination과 요청 형식을 먼저 정하고, 입력을 확정한 뒤 공개 automation 명령으로 기존 upstream exporter를 실행한다.
3. pending request의 세션·형식·예상 확장자에 맞는 same-editor Blob 다운로드만 `.download`로 처리한다. 무관한 다운로드나 stale 요청을 기존 파일 저장 요청으로 수용하지 않는다.
4. delegate에서 MIME과 파일명을 검증하고 task/request 전용의 존재하지 않는 staging 파일을 제공한다. 사용자가 선택한 기존 destination을 먼저 삭제하지 않는다.
5. 다운로드 완료 후 요청·세션·출력 검증을 거쳐 native 파일 쓰기로 destination에 게시한다. 실패·취소 시 해당 요청의 staging만 정리하고 원본과 기존 destination을 유지한다.
6. 내보내기 결과로 native source·HWP/HWPX 형식·최근 문서·dirty 상태를 변경하지 않는다. HTML Blob 탐색으로 main editor가 교체되는 것도 차단한다.

## 잔여 위험

- 제품에는 아직 수정이 들어가지 않았다. 첫 저장 실패, 기존 파일 경로 잔류, HTML 화면 이탈이 남아 있다.
- `getDocumentState`에는 파일명·암호 원본 metadata가 없다. 자동복구나 미분류 editor 내부 교체에는 위 보수적인 source 정책이 필요하다.
- 실제 Word 앱에서 열기, macOS 12 최소 지원 환경, M1 / Tahoe 26.3, Sandbox NSSavePanel 권한·실패 경로는 이번 diagnostic delegate 실험의 검증 범위가 아니다. Stage 3~5에서 가능한 환경을 구분하여 기록한다.
- 이번 입력은 WKWebView의 실제 textarea에 `execCommand('insertText')`를 적용한 합성 입력이다. 물리 한글 IME 조합과 마지막 조합 확정은 후속 UI smoke에서 확인한다.
- 전체 문서 hash 조회 비용은 대형 문서에서 별도 확인해야 한다. native/editor 이벤트가 비동기라는 이유로 고빈도 full export polling을 도입하지 않는다.

## 다음 단계 영향

Stage 2는 새 문서 등록뿐 아니라 source 분리와 명시적인 load intent 도입을 함께 구현한다. Stage 3의 저장 전 epoch 재확인은 이전 원본 덮어쓰기 방지의 필수 조건이다. Stage 4는 직접 HTML RPC 탐색 대신 WKDownload staging·완료 처리에 집중한다.

우선 변경 파일은 `RhwpStudioEditorSession.swift`(신규), `DocumentViewerStore.swift`, `RhwpStudioWebView.swift`, `DocumentViewerView.swift`, `RhwpStudioHostBridgeScript.swift`, `project.yml` 및 관련 HostAppTests이다. 새 순수 상태 모델의 테스트와 실제 WKWebView 연결 검증을 분리한다.

## 승인 요청

Stage 1 재현과 계약 확정을 완료했다. Stage 2 새 문서 세션·편집 상태 동기화 구현 진입 승인을 요청한다. 이슈 #516 은 계속 OPEN이며 제품 소스 수정은 다음 단계 승인 후 시작한다.
