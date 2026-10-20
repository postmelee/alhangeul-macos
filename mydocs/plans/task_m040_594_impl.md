# Task M040 #594 구현계획서

## 작업 개요와 승인 상태

- 이슈: [#594](https://github.com/postmelee/alhangeul-macos/issues/594)
- 마일스톤: M040 (`v0.4`)
- 작업 브랜치: `local/task594`, 대상 통합 브랜치: `devel`
- 수행계획서: [task_m040_594.md](task_m040_594.md)
- 시작 기준: `f64f6101863777e2bd49c2336e5e4fd967b4da6e`
- 수행계획 작성 커밋: `15c04d60`
- 수행계획 승인: 2026-10-20, 같은 채팅의 작업지시자 ‘진행해줘’
- 구현계획 승인: 2026-10-20, 같은 채팅의 작업지시자 ‘진행해줘’
- Stage 2 승인: 2026-10-20, 같은 채팅의 작업지시자 ‘진행해줘’
- 현재 상태: Stage 2 내부 수용 모델·세션 유지 UI 및 합성 transport 검증 완료, Stage 3 진입 승인 대기. 공개 upstream producer/adapter는 아직 연결하지 않음.
- 구현 단계: 4단계. 단계별 검증·보고·승인 후 다음 단계에 진입한다.

## 현재 구현과 결정할 경계

| 현재 구현 | 이번 변경의 판단 기준 |
|-----------|----------------------|
| HostBridge의 window error/unhandledrejection은 일반 runtime 정보만 전달 | 복구 성공·history 유효성을 추정할 수 없다. 구조화된 명령 실패 계약과 구분 |
| Coordinator의 메시지·asset line allowlist | 기존 두 예외의 호환성을 명시하고 신규 문자열 예외를 추가하지 않음 |
| `reportFailure` fatal 분기는 session/token/저장 요청을 무효화 | 명시적인 실패 세대와 공통 command gate로 모든 입력·출력 경로를 점검 |
| Store의 `webViewFailure` 조건부 뷰가 WKWebView를 제거 | 복구 성공 시 객체 유지. fatal 시 retained view/마지막 화면과 복구 액션을 별도 상태로 표현 |
| `RhwpStudioEditorSnapshot`은 metadata DTO | 복구 가능한 문서 bytes로 취급하지 않음 |
| `requestSave`는 token/epoch 확인 후 동기 파일 쓰기, 이후 notifySaved | 게시 직전 검사가 필요. 이미 완료된 파일 쓰기를 늦은 오류로 취소했다고 주장하지 않음 |
| source protection과 변환/저장 정책 존재 | 자동 사전 복구본·복구 export에도 같은 보호 정책 적용 |

실제 upstream API 명칭과 유효 복구본 공급은 미확정이다. 아래 구조는 HostApp의 요구사항·잠정 모델이다. Stage 1에서 공개 API·협의 결과를 대조한 뒤 계약 문서와 다음 단계 범위를 승인받는다. upstream 구현을 이 저장소에 복제하거나 생성 asset을 직접 수정하지 않는다.

## 공통 구현 원칙

1. 실패 처리 상태는 HostApp이 소유한다. Studio/Rust 편집 알고리즘을 패치하지 않는다.
2. 문서 식별은 현재 WKWebView, load token/loadID, editor 내부 documentEpoch를 모두 연결한다. load 전환과 Studio 내부 새 문서·복구 전환을 같은 사건으로 가정하지 않는다.
3. 복구 성공은 문서·선택/커서·history·dirty·후속 명령의 유효성을 함께 보증해야 한다. 독립 브라우저에 내용이 보였다는 관찰만으로 성공을 발행하지 않는다.
4. unknown integrity와 복구 실패는 현재 세션에서 latch한다. 늦은 success/session callback이나 중복 배너 해제만으로 정상 편집에 복귀하지 않는다.
5. 사용자 메시지는 실패한 작업과 가능한 행동을 설명한다. 내부 schema/rollback 용어는 진단 상세에 둔다.
6. 상세 진단은 오류 코드·작업·복구 분류·지원 버전·시점으로 제한하고 본문·원본 경로·raw payload를 기록하지 않는다. 길이/목록 크기 한도와 bounded dedupe 정책을 둔다.
7. `project.yml`이 원본이다. 신규 파일 target 포함 여부는 기존 folder source 구성을 먼저 확인하고 필요한 때만 수정한다. Xcode project는 직접 편집하지 않는다.
8. 최소 macOS 12를 유지한다. 새 OS에서 테스트한 결과로 최소 OS 실행을 대체하지 않는다.

## 상태 및 수신 정책

잠정 HostApp 상태는 `loading`, `ready`, `recoverableNotice`, `suspended`, `restarting`으로 구분한다. 최종 타입 이름은 Stage 1에서 정하되 recoverable 배너를 닫는 동작과 suspended 상태를 해제하는 동작을 분리한다.

| 입력/이벤트 | 처리 | 세션·명령 |
|-------------|------|-----------|
| 현재 문서의 지원 계약·검증된 복구 성공 | 비차단 알림과 진단 갱신 | 같은 WebView, session, history, dirty 유지 |
| 현재 문서의 지원 계약·복구 실패 또는 integrity unknown | suspended 진입, 복구 UI 표시 | 입력·편집·모델 기반 저장/출력 중지 |
| 현재 문서의 계약 payload 파손/버전 불일치 | 성공으로 수용하지 않음. 상태 불확실성에 따른 suspended 처리 | 보호를 풀지 않음 |
| 다른 origin/frame/WebView, 이전 load/epoch 또는 식별 불가 이벤트 | 신뢰 이벤트로 수용하지 않음. 현재 문서 상태 변경 없음 | 새 문서를 과거 오류 때문에 중단하지 않음 |
| loading 중 초기화/asset/document-load 오류 | 기존 초기화 실패 표현과 진단 유지 | 문서 준비 완료로 승격하지 않음 |
| ready 중 미분류 전역 runtime 오류 | 기존 fatal 경로와 정합되는 suspended 정책 | 성공 추정 금지 |
| 알려진 legacy 예외 | 고정 bundle에서 기존 제한 유지 여부를 Stage 1에서 명시 | 구조화된 복구 보증과 사용자 문구를 구분 |
| fatal 이후 늦은 session·export·notifySaved 결과 | 해당 세대 결과 무시/취소 완료 | suspended 유지, destination 추가 게시 금지 |
| 다시 시작 취소 | 현재 suspended 상태·복구 자료 유지 | 자동 reload 없음 |
| 다시 시작 확정 | 새 실패/로드 세대 발급 후 reload | 성공한 새 load만 편집 재개 |

일반 runtime 이벤트에 현재 token을 단순히 새로 붙이는 것으로 오래된 오류를 현재 문서에 연결하지 않는다. error 출처·발생 시점과 세대의 연결 방법을 Stage 1에서 확정한다. 계약이 없는 기존 error bridge의 한계도 별도 기록한다.

## Stage 1. 오류 계약과 복구본 경계 확정

### 산출물

- `mydocs/tech/task_m040_594_error_recovery_contract.md`: 상태 전이, 지원 capability/버전, 필드 의미·검증·출처·순서·복구 성공 조건
- `mydocs/working/task_m040_594_stage1.md`: 현행 코드 흐름·공개 API 조사, legacy 동작, 복구본 공급 가능성 및 단계 진입 조건
- 필요 시 이 구현계획서의 구체화와 오늘할일 상태 갱신

### 수행

1. pinned bundle의 공개 embed/automation, 현재 upstream의 공개 error/recovery API와 기존 조사 증적을 대조한다. 로컬 upstream checkout의 HEAD와 실제 pin을 별도 기록한다.
2. 구독 시점, readiness/capability handshake, envelope version, event ID/operation/code, document identity/sequence, rollback 결과의 producer 책임과 native 검증 책임을 문서화한다.
3. 구조화된 실패가 동일 예외의 window error/unhandledrejection으로 중복 보고될 때의 규칙을 정한다. 명령 경계에서 해결된 예외는 upstream이 전역 uncaught로 재전파하지 않는 방향을 우선 검토한다. 메시지 일치만으로 전역 fatal을 억제하지 않는다.
4. 복구본 공급 후보를 비교한다. metadata, 원본 입력, 저장 성공 bytes, upstream recovery draft, 사전 export 각각의 시점·형식·보호·접근 가능성과 실제 안전성을 구분한다.
5. 최초 구현의 복구본 생성 trigger/보관 위치·기간·개수·용량 상한·정리 조건과 보호 문서 취급을 결정한다. 매 키입력 full export나 무제한 보관은 채택하지 않는다.
6. 원본 입력만 보유한 경우 ‘원본 다시 열기’로 표현한다. 사전 편집 복구 bytes를 공급할 수 없으면 ‘미저장 편집 복구본 없음’을 정상적인 분기로 확정한다.
7. source protection unknown 또는 password 문서에서 평문 자동 보관·내보내기를 허용하지 않는다. 기존 정책이 허용하지 않는 공급은 별도 후속 범위로 제시한다.
8. save/export/print/share/download/종료·창 닫기와 오류 경합 지점을 목록화하고 차단·취소·완료 callback 단일성 기준을 정한다.

### 검증과 종료 조건

- 요구 필드별 producer·consumer와 지원 버전·현재 부재 여부가 기록되어야 한다.
- 신규 복구 성공을 현재 legacy 번들에 소급 적용하지 않는 정책을 설명할 수 있어야 한다.
- 사전 bytes를 공급할 수 없는 경우에도 동작 가능한 no-recovery UX가 정의되어야 한다.
- 계약 미확정이면 Stage 2의 실제 연결을 확정한 것으로 보고하지 않는다. HostApp 모델/합성 계약 테스트만 가능한 범위와 실제 연결 의존성을 구분해 다음 승인에서 정렬한다.
- `git diff --check`와 문서 링크·pin 대조 검증. 이 단계는 제품 코드 변경이 없어 런타임 테스트를 통과로 기록하지 않는다.

커밋: `Task #594 Stage 1: 오류 복구 계약과 복구본 경계 확정`

### Stage 1 결과에 따른 범위 구체화

[오류 복구 계약](../tech/task_m040_594_error_recovery_contract.md)을 Stage 1 산출물로 작성했다. 두 조사 commit에는 일반 사용자 명령 실패 구독 API가 없다. 기존 document-agent RPC의 recovered 필드는 일반 편집 복구 보증으로 사용하지 않는다.

- Stage 2: 내부 envelope·health 검증·비차단 알림과 합성 이벤트 테스트를 구현한다. 공개 producer가 없는 현재 bundle에서 새 성공 경로를 켜지 않는다. 실제 공개 API가 제공되면 계약/adapter·지원 버전을 갱신한 뒤 제품 연결을 수용한다.
- Stage 3: 자동 full export/내부 IndexedDB 접근은 추가하지 않는다. 정상 저장이 끝나고 read-only parser 검증까지 완료한 평문 HWP/HWPX bytes만 이전 저장본으로 제한 보관한다. 창당 1개·32 MiB, 프로세스 전체 64 MiB, monotonic 30분 TTL·작업 lease와 no-recovery 분기를 적용한다. 이는 미저장 편집 자동 복구 기능이 아니다.
- Stage 4: 실제 upstream 계약 지원 bundle에서 성공 경로를 확인하지 못하면 전체 기능 수용은 미완료다. 현재 bundle의 fatal·no-recovery/이전 저장본 경로와 합성 성공 경로의 결과를 따로 보고한다.

## Stage 2. 명령 실패 수신과 편집 세션 보존

### 변경 범위

- HostApp 전용 오류 envelope/validation/state model 신규 파일(최종 이름은 Stage 1 계약에 맞춤)
- `RhwpStudioHostBridgeScript.swift`, `RhwpStudioWebView.swift`, `RhwpStudioResourceLocator.swift`
- `DocumentViewerStore.swift`, `DocumentViewerView.swift`의 복구 성공 표시 및 진단
- `Tests/HostAppTests/`의 오류 계약·상태 전이·JavaScriptCore 실행 테스트

### 수행

1. native decoder와 script adapter를 계약에 맞추고 실제 공개 API에만 연결한다. public 구독 해제/lifecycle이 있으면 WebView 해제와 reload에서 정리한다.
2. main frame, Studio resource origin, 해당 WebView, load token/loadID, epoch·sequence를 검증한다. 버전/필드/수치/형식 오류를 복구 성공으로 기본값 처리하지 않는다.
3. 복구 성공 이벤트는 ready 상태의 현재 문서에서만 수용하고 WKWebView를 재생성하지 않는다. editorSession/sourceDocument/load token/reloadToken/dirty를 임의로 초기화하지 않는다.
4. 비차단 배너에 실패 명령과 다음 행동을 표시하고 진단 상세·복사를 제공한다. 내용 보존을 검증할 수 없는 legacy 예외에는 해당 보증 문구를 사용하지 않는다.
5. 동일 이벤트 중복 수신은 재처리하지 않고 같은 오류 반복은 제한된 집계/배너 갱신으로 처리한다. dismiss 뒤의 신규 오류·다른 문서 전환도 검증한다.
6. 신규 문자열 allowlist를 추가하지 않는다. 기존 예외의 유지·축소/제거는 Stage 1 승인한 정책과 pinned bundle 회귀 근거에 따른다.

### 검증과 종료 조건

- 지원 성공·실패·unknown, missing/잘못된 형식·범위·버전, spoof origin/frame, stale load/epoch/sequence, 중복·순서 역전 테스트
- 복구 성공 전후 WebView identity, session identity, 실제 본문, undo/redo, dirty 및 후속 입력·저장 가능성의 행동 검증
- 배너 닫기와 반복 오류·진단 표시, 초기화 중 오류·legacy 예외 분류 회귀
- JavaScriptCore mock의 성공 결과는 native contract 검증으로만 기록한다. 실제 Studio 복구 보증의 검증을 대체하지 않는다.
- 지원 upstream bundle이 없으면 실제 복구 성공 수용 결과는 미검증으로 보고하고 임의 pin으로 우회하지 않는다.

커밋: `Task #594 Stage 2: 복구 확인 명령 오류의 세션 유지와 알림 연결`

## Stage 3. 치명적 실패의 복구·재시작 UX

### 변경 범위

- Coordinator 공통 health/command gate와 save/export/print/share/download 연결
- Store의 suspended/restart/recovery 상태와 별도 복구 bytes 보관 모델·내보내기 서비스
- Container와 fallback/복구 UI, 종료·창 닫기 경로의 필요한 연결
- 관련 상태 전이·저장 게시 경쟁·재시작·복구본 테스트

### 수행

1. 첫 치명적 오류에서 실패 세대를 발급·고정하고 입력/명령/파일 drop·새 문서 등 편집 진입을 차단한다. 원본 다시 열기·다른 파일 열기·종료는 명시적 복구 전이로만 허용한다.
2. native 메뉴·키보드·toolbar·스크립트/automation·accessibility 등의 입력 경로를 점검한다. SwiftUI `allowsHitTesting(false)`만으로 전체 차단을 입증하지 않는다. Studio 공개 suspend 계약이 없으면 실제 편집 UI를 제거하고 이용 가능한 snapshot으로 대체하는 등 실행되지 않는 안전한 경계를 선택한다.
3. 진행 중 save/HTML/PDF/print/share/download 작업의 취소와 완료를 정확히 한 번 처리한다. destination 게시 직전 health/세션 세대를 확인하고 fatal 뒤 완료가 dirty를 clean으로 만들거나 state를 재활성화하지 못하게 한다.
4. 파일 쓰기가 이미 성공한 뒤 오류가 관측되었다면 쓰기 완료 사실을 유지한다. 새 저장의 게시 차단과 이미 완료된 저장을 구분하며 기존 파일을 삭제·원복하지 않는다.
5. Stage 1에서 승인된 사전 복구 bytes만 보관한다. revision·세대·형식·protection·생성 시각·검증 결과를 함께 저장하고 새 문서 전환과 reload에도 정책에 따라 보존한다. 늦은 exporter 결과로 안전한 복구본을 덮어쓰지 않는다.
6. 유효 복구본이 있으면 원본과 다른 파일로 내보낸다. 동일 URL/원본 destination을 거부하고 atomic write·취소·쓰기 실패를 기존 저장 정책에 맞게 처리한다. 복구 export는 notifySaved/current source/dirty 정리로 이어지지 않는다.
7. 복구본 없음·보호 정책상 불가·이전 시점 복구본을 구별한다. ‘내용 유지’ 또는 ‘최신 편집 복구’의 무근거 안내를 하지 않는다.
8. 가능하면 마지막 정상 화면을 시각 자료로 보존한다. screenshot은 선택/검색 가능한 문서나 저장 가능한 bytes가 아니며 프로세스 종료 후 취득을 보장하지 않는다.
9. ‘원본 다시 열기’ 또는 ‘다시 시작’에 미저장 편집 손실 가능성을 안내하고 취소를 제공한다. 복구 export 실패·취소가 자동 reload로 이어지지 않게 한다. 새 문서 로드 성공 전 복구 자료를 제거하지 않는다.
10. failed reload, 다른 파일 열기 취소, 다른 문서창, 창 닫기·앱 종료와 #525 이슈의 복구 후보 정책을 회귀 검증한다.

### 검증과 종료 조건

- 입력·저장·모든 출력이 suspended에서 차단되고 늦은 callback이 세션/상태를 되살리지 않는다.
- 원본은 변하지 않으며 복구 export의 내용·형식·시점·보호 정책이 일치한다.
- 내보내기 취소·disk write 실패·복구본 없음·오래된 복구본·프로세스 종료에서도 문구와 행동이 정확하다.
- retry 취소·실패·성공과 재시도 직전의 bytes 보존, 파일 publish 직전/직후 fatal 경합을 검증한다.
- 실제 공급 API가 없으면 사전 편집 복구본 가능 상태는 합성 테스트로만 표시하고 legacy 제품에서는 no-recovery 정책을 검증한다.

커밋: `Task #594 Stage 3: 치명적 오류의 저장 차단과 복구 재시작 UX 구현`

## Stage 4. 실제 WKWebView 통합과 회귀 수용

### 변경 범위

- `Tests/StudioDocumentLifecycleSmoke/main.swift`와 `scripts/smoke-studio-document-lifecycle.py`의 필요한 확장 또는 전용 error recovery harness
- HWP/HWPX 합성·읽기 전용 fixture, HostAppTests의 필요한 보강
- 타스크 Stage 4 보고와 검증 기록. 최종 보고·PR 게시 절차는 별도 승인

### 실행과 검증

1. 실제 SwiftUI container·제품 Store/Coordinator·WKWebView를 포함한 고유 진단 앱을 사용한다. 정상 load·새 문서·편집·저장/취소·닫기·종료가 유지되는지 확인한다.
2. 계약 지원 bundle의 실제 명령 실패 → 복구 성공 → 후속 편집·undo/redo, fatal → 복구본 → 재시작을 시험한다. 아직 미지원이면 실제 bundle에서 일반 오류의 suspended 경로와 초기화/프로세스 경계를 검증한다. 합성 성공 주입은 실제 upstream 복구 검증과 별도 결과로 남긴다.
3. HWP/HWPX 정상 열기·저장과 원본 SHA-256 보존, session/history/dirty, 여러 창 독립성, stale 이벤트·중복·재시도 회귀를 확인한다.
4. pinned manifest/asset 검증을 실행한다. 지원 release 반영이 필요하면 기존 core dependency 절차의 별도 승인 후 반영하며 이번 계획만으로 미출시 commit을 pin하지 않는다.
5. 산출물은 `build.noindex/task594-*` 또는 기존 표준 harness의 고유 `build.noindex/studio-lifecycle-*` 아래에 둔다. 설치본/기본 연결을 변경하지 않고 실행 후 소유 개발 앱 등록만 해제한다.
6. 지원 OS/architecture, 실제 계약 지원 버전과 실행한 케이스·실패·미검증을 기록한다. 최소 macOS 12 실제 실행을 못 하면 제약으로 남긴다.

커밋: `Task #594 Stage 4: 오류 복구 WKWebView 통합과 문서 생명주기 회귀 검증`

## 검증 명령과 적용 범위

아래는 확인한 기존 진입점이다. 본 문서 작성에서는 실행하지 않으며 각 구현 단계의 변경에 맞춰 실행한다.

```bash
# 문서/코드 형식과 계층 경계
git diff --check
scripts/check-no-appkit.sh

# 프로젝트 source discovery 갱신: project.yml이 원본
xcodegen generate

# HostApp compile/link. 개발 산출물은 build.noindex 아래에 둔다.
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp \
  -configuration Debug -derivedDataPath build.noindex/task594-build \
  CODE_SIGNING_ALLOWED=NO build

# 기존 HostAppTests 구성으로 build-for-testing 후 xctest 실행
xcodebuild -project Alhangeul.xcodeproj -scheme HostAppTests \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath build.noindex/task594-tests \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build-for-testing
```

XCTest 실행은 `scripts/test-studio-output.sh`의 실행 방식을 참고하되 새 오류 계약·복구 상태 테스트와 기존 `RhwpStudioHostBridgeScriptTests`, `RhwpStudioEditorSessionTests`, `RhwpStudioEditorSessionScriptTests`, `DocumentOpenRecoveryTests`를 선택한다. 정확한 신규 클래스명과 실행 목록은 추가한 테스트를 기준으로 단계 보고에 기록한다. 단순 source 문자열 검사만으로 세션 보존·저장 차단을 입증하지 않는다. PDF/인쇄 경로를 수정하면 해당 출력 테스트도 실행한다.

```bash
scripts/verify-rhwp-studio-assets.sh
python3 scripts/smoke-studio-document-lifecycle.py --fixture samples/re-font-dotum-empty-hancom.hwp
python3 scripts/smoke-studio-document-lifecycle.py --fixture samples/hwpx/hwpx-01.hwpx
```

Frameworks 산출물이 없으면 `build_run_guide.md`의 pinned core 준비 절차를 따른다. renderer/FFI 변경은 범위 밖이므로 해당 renderer 검사를 불필요하게 반복하지 않는다. 실패 시 통과로 보고하거나 실패 상태로 단계 커밋하지 않고 원인·수정 방향을 보고한다.

## 증적과 완료 판정

- 단계 보고서: `mydocs/working/task_m040_594_stage{N}.md`. 해당 단계 소스·계약 문서와 묶어 커밋한다.
- 로그·대형 진단 산출물: `build.noindex/` 아래 실행별 보관. 재현 절차·핵심 결과·SHA와 제약은 단계 보고서에 장기 기록한다.
- 알한글 호스트 지원, 실제 upstream 계약 연결, 안정 버전 번들 수용, 공개 배포는 각각 다른 완료 상태다.
- Stage 4 종료 시 미지원 계약·복구본 공급·최소 OS 확인 등 필수 미완료가 있으면 기능 전체 완료로 처리하지 않는다. 잔여 범위와 다음 승인 지점을 명시한다.
- 모든 필수 작업과 검증 이후에만 최종 보고·오늘할일 완료·PR 게시 절차로 넘어간다.

## 이번 승인 요청

1. 위 4단계 구현계획을 승인하고 Stage 1 오류 계약·복구본 경계 조사/문서화에 진입한다.
2. Stage 1 결과로 아직 없는 upstream API·보호 문서·복구 bytes 공급 한계를 명시하며, 후속 단계 전에 실제 지원 범위를 다시 확인한다.
3. 단계별 보고와 승인을 유지하고, 원격 게시·배포·메일 발송은 별도 지시 범위로 둔다.
