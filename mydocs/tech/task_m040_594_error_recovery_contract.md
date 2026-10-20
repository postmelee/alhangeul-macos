# Task M040 #594 오류 복구 계약과 복구본 경계

## 상태와 적용 기준

- 작성일: 2026-10-20
- 타스크: [#594](https://github.com/postmelee/alhangeul-macos/issues/594)
- 구현계획: [task_m040_594_impl.md](../plans/task_m040_594_impl.md)
- 현재 알한글 pin: `v0.8.7`, `1a76570e833917d15817415a53c09ad61ab3203f`
- 조사 시 원격 upstream/devel: `5e2b9bfbf08573a31fa1e11a2445ff63fc0755c0` (`git ls-remote` 확인)
- 로컬 upstream 기본 checkout HEAD: `fe9ffd27e91d8d260fbccde5ff68aa08aadf94ca`. 아래 공개 API 판정은 이 HEAD가 아닌 위 두 commit의 `git show`로 확인했다.
- 상태: Stage 1 조사·설계 결과. HostApp 내부 계약과 다음 단계 범위 승인 대상이며, 새 upstream 공개 API가 합의·배포되었다는 뜻이 아니다.

## 확인한 공개 API와 부재 범위

| 항목 | pinned / 조사한 upstream | HostApp 적용 판단 |
|------|-------------------------|-------------------|
| embed protocol version | 모두 1 | embed protocol version만으로 일반 명령 복구 지원을 판정할 수 없음 |
| `EmbedProtocolError.recovered?: boolean` | 모두 존재. document-agent 오류의 일부 RPC 응답에 포함 | 일반 키보드/메뉴 편집 실패와 history 유효성의 공통 보증이 아님 |
| document-agent two-phase render rollback | 제한된 document-agent 실행 경로에 존재 | 일반 `executeOperation`, undo/redo의 포괄적인 성공 계약으로 확장 해석 금지 |
| legacy `rhwp-request` | 오류를 `errorText(error)` 문자열로 응답. `applyTextCommand`/`revertTextCommand` 거부 | 현재 HostApp은 이 경로로 `requestRhwp`를 호출하며 오류를 새 Error로 변환. 구조화된 recovered 정보가 없음 |
| MessagePort handshake | 별도 version/capabilities 협상. 부모 origin은 HTTP/HTTPS 조건 | top-level custom scheme HostApp에 iframe SDK 연결을 그대로 적용할 수 없음. 안정 공개 same-page 계약 필요 |
| `rhwp-event` | 문서 변경 이벤트, 최신 commit에는 field 변경도 추가 | 일반 UI 편집 명령 실패 구독 이벤트는 확인되지 않음 |
| `window.rhwpStudio.automation` | execute/context/list 등 공개 명령 표면 | 실패 결과는 rollback/history 보증이 아니며 모든 키보드 편집을 포괄하지 않음 |
| Studio autosave | 내부 AutosaveManager/IndexedDB, exportHwp 평문 HWP, 최대 12개 | native 읽기 공개 RPC 없음. sourceFormat이 HWPX라도 bytes는 HWP |
| autosave 보호 | `wasm.requiresPasswordForSave`이면 생성 차단·기존 draft 폐기 | HostApp의 sourceProtection unknown까지 보증하는 동등한 정책이라고 가정하지 않음 |
| `window.__autosaveManager` 등 | DEV 전용 | production 연결에 사용하지 않음 |
| source/session DTO | HostApp load token/loadID, epoch/changeSeq/dirty/pageCount/format | metadata이며 복구 파일 bytes가 아님 |

근거 소스는 아래 SHA 고정 링크와 같다.

- [pinned embed protocol](https://github.com/edwardkim/rhwp/blob/1a76570e833917d15817415a53c09ad61ab3203f/rhwp-studio/src/embed/protocol.ts)
- [upstream embed runtime](https://github.com/edwardkim/rhwp/blob/5e2b9bfbf08573a31fa1e11a2445ff63fc0755c0/rhwp-studio/src/embed/runtime.ts)
- [upstream document-agent error 정규화](https://github.com/edwardkim/rhwp/blob/5e2b9bfbf08573a31fa1e11a2445ff63fc0755c0/rhwp-studio/src/document-agent/controller.ts)
- [pinned autosave producer](https://github.com/edwardkim/rhwp/blob/1a76570e833917d15817415a53c09ad61ab3203f/rhwp-studio/src/main.ts)
- [pinned autosave manager](https://github.com/edwardkim/rhwp/blob/1a76570e833917d15817415a53c09ad61ab3203f/rhwp-studio/src/recovery/autosave-manager.ts)
- [pinned draft store](https://github.com/edwardkim/rhwp/blob/1a76570e833917d15817415a53c09ad61ab3203f/rhwp-studio/src/recovery/autosave-store.ts)

**결론:** 새 일반 명령 복구 API는 두 조사 commit에 없다. 단순 recovered boolean 유무로 기능을 켜지 않는다. 기존 RPC를 파싱해 일반 runtime 오류를 복구 성공으로 승격하거나, 번들 내부 객체/IndexedDB를 직접 읽는 연결은 만들지 않는다.

## 복구 이벤트 요구 계약

### 공개 producer 의존성과 HostApp 수신 모델

upstream이 일반 사용자 입력·메뉴·toolbar·automation·undo/redo를 포함한 명령 경계에서 오류를 포착하고 복구·상태 확인까지 완료한 후, 공개한 same-page 구독 API로 결과를 전달하는 것이 요구사항이다. API/capability 이름은 아직 upstream 계약이 없으므로 여기서 확정하지 않는다.

HostApp 내부 수신 모델의 버전은 1로 제안한다. `command-failure`는 **native bridge 내부 메시지 종류 후보**이며 upstream에 이미 존재하는 이벤트 이름이 아니다. adapter는 실제 공개 계약이 제공되면 그 타입을 이 내부 DTO로 변환한다. 계약 미지원이면 구독하지 않으며 테스트용 producer가 production capability를 흉내 내지 않는다.

| 필드 | 의미·검증 | 책임 |
|------|-----------|------|
| contractVersion | 내부 DTO는 정수 1. embed protocol version과 별개 | adapter/native |
| eventID, eventSequence | 문서 세대별 고유 사건 ID와 단조 증가 순서 | upstream 발행, adapter 범위·native 중복 검사 |
| code, operation | 비어 있지 않은 제한 길이 ID, 본문/경로를 담지 않음 | upstream |
| loadToken, loadID | 해당 WKWebView navigation에서 설치된 값. 사용자 편집 동안 변하지 않음 | HostApp adapter |
| documentEpoch | upstream 문서 교체 세대. native source URL과 독립 | upstream |
| changeSeq | 사건이 확정된 문서 revision. 복구 후 값이며 단조성 정책 공개 필요 | upstream |
| recovery | `restored` / `unchanged` / `failed` / `unknown` | upstream |
| checks | content, cursorSelection, history, dirtyState, readyForNextCommand 각각의 검증 결과 | upstream |
| diagnostic | 선택적인 제한 길이 code 중심 정보. 임의 stack/raw payload 직접 UI 노출 금지 | adapter/native |

`restored`는 실패 전 논리 편집 상태를 복원했고 검증도 완료했음을, `unchanged`는 실패가 변경 전에 거부되어 상태 불변과 후속 명령 유효성을 확인했음을 뜻한다. 성공 분류는 둘 중 하나이면서 checks 5개가 모두 true일 때만 가능하다. ‘선택/커서 복원’의 표현·history index와 resource 유효성·dirty 판정과 부작용 배제는 producer가 실제 테스트로 입증해야 한다. snapshot restore 호출 성공만으로 모두 true를 채우지 않는다.

`failed`, `unknown`, 필수 checks 누락/false는 복구 성공이 아니다. 향후 upstream이 이 보증을 제공할 수 없으면 해당 명령 경로는 계속 suspended 대상이다. HostApp이 선언만 수신했다고 보증의 실측 검증을 완료한 것으로 보고하지 않는다.

### 수신 origin·세대·순서

- native는 등록된 handler, 동일 `commandWebView`, main frame, 정확한 `alhangeul-studio://app` route/port와 실제 frame URL을 확인한다. token은 권한 증명이 아니라 상관 식별자다.
- capability/구독 연결은 현재 navigation과 연결하고 reload/dispose 시 해제한다. source protection·ready·session readiness와 별도 상태로 관리한다.
- 다른 frame/origin/WebView, 다른 loadToken/loadID/epoch 이벤트는 현재 문서에 반영하지 않는다.
- 아직 epoch를 확인하지 못한 loading 상태의 이벤트는 성공으로 적용하지 않는다. 일반 초기화·로드 실패의 기존 진단은 유지한다.
- 같은 세대의 유효 fatal/unknown은 latch한다. 최신 changeSeq가 이미 관측됐다는 이유만으로 그 세대의 무결성 상실을 숨기지 않는다.
- 정상 상태에서 더 오래된 changeSeq의 recovered 이벤트는 최신 선택·dirty를 되돌리지 않는다. eventSequence·eventID·상태별 유효성으로 재처리/알림 정책을 판단한다.
- suspended 이후 새 recovered/session 이벤트는 health를 ready로 바꾸지 않는다. 명시적 restart의 새 navigation 성공만 이를 해제한다.
- 동일 ID로 내용이 달라지는 사건은 protocol 오류다. 현재 신뢰 세대의 invalid contract는 성공 수용하지 않고 suspended로 처리한다. 잘못된 origin/세대의 메시지는 이를 이용해 정상 문서를 중단시키지 못하도록 무시한다.
- 정수는 JavaScript safe integer 범위에서 처리하며 boolean을 정수로 허용하지 않는다. ID/operation/code는 각각 UTF-8 128 bytes 이내, 진단은 2 KiB 이내로 제안한다. producer도 원문 문서 데이터를 보내지 않아야 한다.
- native 중복 기록은 현재 문서당 최근 64개 이벤트로 제한한다. fatal latch와 마지막 sequence는 이 ring의 축출과 무관하게 유지한다. 배너는 한 개, 동일 code/operation 반복은 기존 배너 집계로 처리한다.

### 전역 오류 중복과 legacy 호환

복구 처리가 끝난 같은 오류를 upstream이 window error/unhandledrejection에 재전파하지 않는 공개 보장이 우선이다. HostApp의 명령 함수 wrapping이나 메시지 일치로 중복 fatal을 억제하지 않는다. 공개 correlation이 없는 전역 runtime 오류는 별개 무결성 불명 오류로 취급한다.

기존 #223, #235 이슈의 두 예외는 현재 pin에서 기존 조건 그대로 유지하는 호환 모드로 둔다. 새 문자열을 추가하지 않으며 ‘내용이 유지되었습니다’ 보증은 붙이지 않는다. 구조화된 계약 지원이 실제 bundle에서 확인된 후 그 모드에서는 문구 allowlist를 사용하지 않는다. 기존 allowlist 제거는 실제 지원 bundle 회귀 수용 후 별도 반영한다.

일반 전역 runtime source는 발생 navigation token을 설치 closure에 고정할 수 있지만 editor 내부 epoch까지 확실하게 연결하지는 못한다. 특히 늦은 promise rejection의 원래 문서 epoch를 새로 읽은 epoch로 바꾸어 달지 않는다. navigation mismatch는 무시하고, current navigation의 출처 불명 오류는 안전하게 suspended 처리한다. 완전한 editor epoch 상관은 공개 producer 계약이 필요한 의존성이다.

## 문서·저장 상태 전이

| 사건 | 화면/세션 | 입력·출력 | 자료 보관 |
|------|-----------|-----------|-----------|
| 지원 계약의 검증된 복구 성공 | 같은 WKWebView/session 유지, 비차단 알림 | 유지, 기존 진행 요청은 세션/revision 재검증 | 기존 복구 후보 유지 |
| 복구 실패/unknown/미분류 fatal | suspended, 가능하면 안전한 시각 snapshot | gate 차단·미게시 작업 취소 | 확보된 이전 저장본과 failure 진단 유지 |
| 프로세스 종료 | live WebView를 문서로 보장하지 않음 | 모델 조회/export 금지 | native에 이미 확보된 자료만 사용 |
| recoverable 배너 닫기 | 배너만 해제 | health 변화 없음 | 진단은 bounded 보관 |
| 다시 시작 확인 취소 | suspended 유지 | 재개 안 함 | 자료 유지 |
| 다시 시작 확정/로드 실패 | 명시적 세대 전환/실패 진단 | 새 ready 전까지 차단 | 이전 자료는 교체 성공 전 폐기 안 함 |
| 새 load ready 성공 | 새 session 채택 | 새 세대만 허용 | 이전 자료는 아래 수명 정책 적용 |

fault 상태를 `webViewFailure == nil`이나 editorSession nil 유무만으로 추론하지 않고 명시적 health로 관리한다. 편집 세션의 identity/마지막 dirty를 진단·종료 판단용으로 보존하되 더 이상 live command 허용 근거로 사용하지 않는다.

## 복구 자료 정책 결정

### 공급 후보 판정

| 공급 후보 | 이번 범위 판단 |
|-----------|----------------|
| editor snapshot metadata | bytes 없음. 복구 자료 제외 |
| 원본 입력 Data | 이미 읽은 입력의 복사본. ‘원본 다시 열기’ 대상으로만 표현. 미저장 편집 복구 아님 |
| native 저장 성공 payload | 성공한 평문 HWP/HWPX의 byte snapshot을 제한적으로 보관 가능. ‘이전 저장본’으로 표시 |
| Studio IndexedDB draft | 공개 공급·세대·무결성 검증 API가 없어 native 접근 제외 |
| 주기적 전체 export | 이번 최초 구현에서 하지 않음. 건강한 시점의 lock·보호 판정·성능과 새 API가 선행되어야 함 |
| fatal 이후 현재 모델 export | 무결성 불명 모델이므로 금지 |
| 마지막 화면 | 가능한 시각적 참고. 저장·편집·검색 가능한 문서가 아니며 bytes 대체 아님 |

최초 구현의 native 복구 후보는 **현재 문서 세대에서 정상 저장이 완료된 평문 HWP/HWPX payload**로 제한한다. 새 문서에서 한 번도 저장하지 않은 편집 내용은 native 복구본 없음이 정상 결과다. 저장 결과가 평문이어도 요청 시 원본 sourceProtection이 password/unsupported/unknown이면 자동 보관 대상에서 제외한다. HWP3 변환·명시 평문 변환 복사도 자동 후보 생성에서 제외하여 기존 경고·보호 계약을 우회하지 않는다.

### 이전 저장본 검증과 수명

- producer는 HostApp 저장 요청이다. 요청 id/token/loadID/epoch/changeSeq·원래 sourceProtection·실제 payload format, 저장 성공 시각·byte length와 hash를 기록한다.
- 저장 계약의 base64/byte count/format/signature 검증과 atomic 게시 성공이 필수다. signature만으로 완전한 정상 문서를 보증하지 않는다. native parser의 read-only 재열기·page count 유효성까지 통과한 bytes만 후보로 표시한다. 이는 편집 round-trip 완전 동일성 보증이 아니다.
- 후보 검증 시작/완료가 같은 healthy 문서 세대에 속해야 한다. fatal 이후 늦게 완료된 검증으로 후보를 새로 생성하거나 최신이라고 승격하지 않는다. 파일 쓰기는 성공했지만 notifySaved 동기화가 실패한 경우 자동 후보 승격도 하지 않는다.
- 자동 보관은 메모리만 사용한다. 문서창당 1개, 개별 32 MiB 이하, 프로세스 전체 64 MiB 상한을 제안한다. admission 실패 시 현재 문서 내용을 건드리지 않고 후보 없음/기존 후보 시점을 알린다. 다른 창의 후보를 묵시적으로 삭제하지 않는다.
- 후보 TTL은 검증된 admission부터 monotonic 30분이다. clock 변경으로 수명이 늘지 않게 한다. expiration 뒤 새 내보내기는 제공하지 않으며 원본 파일은 영향받지 않는다.
- 열려 있는 복구/저장 패널 작업은 후보 lease를 잡는다. lease가 끝날 때까지 bytes를 보존하고 내보내기 재검증 후 정리한다. 만료 전에 시작한 작업의 취소/실패는 자동 restart를 유발하지 않는다.
- 같은 문서의 새 저장 후보가 검증 성공하면 이전 후보를 교체한다. 원래 문서와 다른 문서의 load 성공 또는 창의 명시적 닫기/자료 폐기에서 후보를 정리한다. 실패한 restart·취소에서는 보존한다.
- 같은 원본을 재시작한 뒤 이전 세대 자료를 보존할 때에는 원래 저장 시점과 이전 세대라는 표시를 유지하고 새 문서의 최신 복구본으로 재라벨하지 않는다. 새 문서 확인/교체 액션은 자료 소실 가능성을 설명한다.
- 내보내기는 후보 bytes만 읽고 기존 source와 다른 신규 파일을 사용한다. lexical URL뿐 아니라 기존 파일의 동일성/alias·symlink 여부도 검사해 원본 덮어쓰기를 피한다. 기존 파일 덮어쓰기 대신 신규 destination을 기본으로 한다.
- 복구 자료 내보내기는 notifySaved, 원본 metadata 변경, dirty 정리, 최근 문서 바인딩 변경을 수행하지 않는다.
- 후보가 없으면 ‘미저장 편집 내용을 복구할 수 있는 파일이 없습니다. 원본을 다시 열면 미저장 내용이 사라질 수 있습니다.’를 기본 안내로 한다. 이전 저장본이 있으면 시각을 함께 보여주고 그 이후 편집은 포함되지 않는다고 설명한다.

이 정책은 이전 저장본 보존 UX를 제공한다. 임의 시점 미저장 편집 자동 백업 지원은 아니다. 향후 공개 recovery API를 연결할 때 별도 공급 정책·보호·성능 검증과 승인이 필요하다.

## 저장·출력·종료 경합 점검표

| 경로 | 현재 경계 | 후속 구현/검증 |
|------|-----------|----------------|
| HWP/HWPX 저장 | `requireSave` token/epoch와 payload/보호 검증, 동기 atomic write | 요청 시작·await 복귀·publish 직전 health generation 검사. 이미 쓴 파일은 늦은 오류로 삭제하지 않음 |
| notifySaved/session 전달 | 저장 write 뒤 await, Store session 갱신 | fatal 뒤 clean/source binding 갱신 금지. 저장 완료 사실과 sync 실패를 구분 |
| Word/HTML | HTML id/token/epoch, WKDownload staging, `writeHTMLData` | fatal 취소·staging 정리, destination 직전 gate, 완료 콜백 단일성 |
| PDF | 준비 task/controller, job validation, atomic write | `reportFailure`에서 명시 취소·세대 무효화, write 직전 검사와 늦은 완료 상태 갱신 차단 |
| 인쇄 | prepare와 sealed print lifecycle | 준비는 취소. 시스템에 이미 제출한 인쇄를 되돌렸다고 안내하지 않음. 완료 콜백/실제 제출 시점 구분 |
| share | 이전 비상관 payload handler 존재 | 동일 frame/세대/현재 요청 검증 없이 게시 금지. fatal 뒤 share 실행 차단 |
| native command dispatcher | 창별 WebView registry와 fallback 탐색 | suspended인 지정 창의 명령 실패를 다른 창으로 넘기지 않음. 창별 gate·return 의미 검증 |
| drop·keyboard·automation | 별도 진입점 다수, hit-testing만으로 불충분 | fatal latch 이후 editor view 실행 차단. 공개 suspend 미지원이면 snapshot 대체/제거 방식 사용 |
| 닫기·앱 종료 | live refreshSession 후 dirty 확인·저장 선택 | suspended에서 live 상태를 조회하지 않음. 보존한 마지막 dirty/자료 유무와 명시 취소·복사·폐기 선택 사용 |
| 다시 시작·다른 파일 열기 | retry가 failure/session을 즉시 비움 | 사용자 확인→세대 발급→새 ready 순서. 실패·취소는 자료 유지. 편집 재개는 성공한 새 load만 허용 |

각 publish 직전 검사는 native가 fatal을 관측한 시점을 기준으로 한다. JS 오류가 발생했지만 native에 아직 전달되지 않은 시간에 이미 성공한 쓰기를 사후에 취소했다고 주장할 수 없다. 이 한계와 성공/실패·보존 결과를 통합 테스트에서 구분한다.

## 다음 단계 진입 조건과 검증 매트릭스

Stage 2는 위 내부 DTO·validation·health·비차단 알림과 합성 producer 검증을 준비할 수 있다. 현재 bundle에는 공개 구독 adapter를 활성화하지 않는다. 새 upstream API가 제공되면 명칭·payload·성공 보증·전송과 버전을 이 문서에 반영하고, 안정 release 도입 승인 후 실제 bundle에서 수용한다.

Stage 3는 현재 bundle에서도 suspended UI, 명령/출력 차단, 이전 저장본/복구본 없음·명시 restart 경로를 구현할 수 있다. Stage 4의 upstream 일반 명령 복구 성공 통합 수용은 공개 API·지원 release가 제공되어야 완료 가능하다. 이것이 제공되지 않으면 HostApp 준비 완료와 전체 기능 완료를 구분하고 이슈를 완료로 처리하지 않는다.

| 검증 분류 | 필수 사례 |
|-----------|-----------|
| 수신 신뢰 | 다른 origin/frame/WebView, 잘못된 token/load/epoch, initialization 중 success, JSON 타입·safe integer·길이 한도 |
| 무결성 판정 | unchanged/restored + 모든 checks, false/missing, failed/unknown, 기존 recovered boolean만 온 경우 |
| 순서 | 중복 ID, 같은 ID 다른 결과, out-of-order, fatal 뒤 success/session, 문서 교체 뒤 늦은 이벤트 |
| 정상 상태 보존 | WebView/session identity, dirty/history/selection, 오류 뒤 편집·undo/redo·정상 저장 |
| legacy | 기존 두 예외만 기존 조건으로 허용, 새 오류 문자열은 성공 승격 안 함 |
| 복구 후보 | 검증 완료 전 fatal, 보호/unknown/HWP3, 0/초과 bytes, 저장 실패·sync 실패, TTL·상한·lease·다중 창 |
| 내보내기 | 원본 동일성·alias·symlink, 신규 파일·권한 실패·취소, bytes/hash·형식 보존, dirty/source 불변 |
| 출력 경쟁 | save/HTML/PDF publish 전후 fatal, sealed print, share, 늦은 완료가 health를 해제하지 않음 |
| restart·닫기 | 복구본 없음, 이전 저장본 시점, 취소·로드 실패·성공, 다중 창 독립, 종료 저장 선택 차단/대체 |

## Stage 1 검증 범위

두 commit의 공개 protocol/runtime/router·autosave producer/store를 `git show`로 확인하고 HostApp manifest와 대조했다. 조사 결과와 source blob ID는 로컬 `build.noindex/task594-stage1/source-audit.json`에 남겼다. 이 문서의 새 요구 계약과 메모리 정책은 구현 전 설계이며, 런타임 테스트 통과나 upstream 합의로 표시하지 않는다.

## Stage 2 구현 상태

2026-10-20 Stage 2에서 HostApp 내부 `command-failure` 메시지 수신 모델, native-only 지원 의존성(`unavailable` 기본값), frame/origin/문서 세대·sequence·엄격한 JSON 타입 검증을 구현했다. 복구 성공 분류와 fatal latch는 위 요구 조건을 따른다. 구조화 이벤트의 raw diagnostic은 길이만 검증한 뒤 보관하지 않고 안전한 ID·code·operation·recovery·sequence로 native 진단을 구성한다.

공개 producer/adapter가 없어 제품 기본 경로의 지원은 계속 미지원이다. native에서 version 1 지원을 명시한 테스트 진단 앱이 합성 이벤트를 실제 WK message transport로 보내 수신·표시·세션 보존을 검증한다. 이는 upstream의 복구 성공 보증을 검증하는 것이 아니다. 실제 구독 함수·capability handshake·해제 구현은 공개 API 제공 이후 남아 있는 연결 범위다.

복구 알림은 native Store에서 한 건만 보관하고 반복 오류는 최대 99회로 집계한다. 닫은 뒤 최근 진단을 다시 표시할 수 있다. 후속 저장/출력 오류가 오면 새 오류를 우선 표시하고 기존 명령 진단은 보존한다. fatal latch는 일반 비치명적 이벤트·session 갱신으로 해제되지 않는다. 이전 저장본 보관·fatal 입력/출력 전체 차단·명시적 복구/재시작 UX는 Stage 3 작업이다.

상세 구현·검증·제약은 [Stage 2 보고서](../working/task_m040_594_stage2.md)를 따른다.
