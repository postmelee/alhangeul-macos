# Task M040 #594 Stage 1 완료 보고서

## 단계 목적

현재 bundle과 upstream의 공개 오류·복구 API를 조사해 명령 복구 성공의 수용 조건, 기존 예외 호환, 안전한 이전 저장본 공급과 fatal 처리 경계를 정의한다. 이번 단계는 조사·설계 문서 단계이며 제품 코드 구현·런타임 검증 단계가 아니다.

- 이슈: [#594](https://github.com/postmelee/alhangeul-macos/issues/594)
- 마일스톤: M040 (`v0.4`)
- 브랜치: `local/task594`
- 수행계획/구현계획: 작업지시자가 같은 채팅에서 순차적으로 ‘진행해줘’ 승인
- 조사일: 2026-10-20

## 산출물

| 파일 | 변경 요약 |
|------|-----------|
| [오류 복구 계약](../tech/task_m040_594_error_recovery_contract.md) | 168줄. API 대조, 내부 요구 DTO·수용/실패 정책, 이전 저장본/TTL/보호·수명, 출력 경합·검증 매트릭스 |
| [수행계획서](../plans/task_m040_594.md) | 승인 상태와 Stage 1 결과 반영 |
| [구현계획서](../plans/task_m040_594_impl.md) | 구현계획 승인과 Stage 1 결과에 따른 Stage 2~4 구체화 |
| [오늘할일](../orders/20261020.md) | Stage 1 조사 완료·Stage 2 승인 대기 표시 |
| 이 보고서 | 조사 근거·완료 범위·제약·다음 승인 요청 |

로컬 보조 증적 `build.noindex/task594-stage1/source-audit.json`은 두 commit의 공개 API 관련 source blob ID와 구조 판정 결과를 보관한다. 대형 source/log를 저장소에 복제하지 않고 핵심 결론과 SHA 고정 source 링크를 계약 문서에 남겼다.

## 본문 변경 정도 / 본문 무손실 여부

제품 코드, bundled asset, core pin, 원본·사용자 문서와 설치 앱을 변경하지 않았다. 본문 편집·자동 export·IndexedDB 접근·복구본 생성도 수행하지 않았다. 이번 결과는 복구 기능 구현 또는 제보 전체 해결을 의미하지 않는다.

## 조사 결과

### 공개 오류 계약

- pinned `1a76570e833917d15817415a53c09ad61ab3203f`와 조사 시 원격 upstream/devel `5e2b9bfbf08573a31fa1e11a2445ff63fc0755c0`을 대조했다. 로컬 upstream 기본 checkout HEAD `fe9ffd27e91d8d260fbccde5ff68aa08aadf94ca`는 별도로 식별했다.
- 두 commit의 embed error에는 `recovered?: boolean`이 존재한다. 따라서 ‘복구 관련 필드 자체가 없다’고 표현하는 것은 부정확하다.
- 이 필드는 제한된 document-agent RPC/transaction/render 복구 경로에 쓰인다. 일반 키보드·메뉴·undo/redo 실패에 대한 세션·history·dirty 통합 보증이나 공개 구독 API는 아니다.
- 현재 HostApp은 legacy same-window RPC를 사용하고 오류를 문자열/new Error로 바꾸므로 기존 구조화된 필드를 일반 실패 수용에 사용할 수 없다.
- 새 일반 명령 복구 capability/공개 same-page API는 두 조사 commit에서 확인되지 않았다. 신규 upstream 메서드 이름을 추측해 제품에서 호출하지 않는다.

### 복구 자료

- Studio autosave는 내부 IndexedDB의 별도 저장소이며 평문 HWP bytes를 보관한다. HWPX source metadata가 있어도 자동 복구 bytes는 HWP다. 보호 문서 차단과 최대 draft 12개 정책이 있다.
- HostApp이 이를 공급받고 세대·무결성을 검증할 공개 RPC가 없다. DEV 전용 `__autosaveManager`나 DB 내부 구조에 연결하지 않는다.
- 최초 HostApp 구현은 새 주기 export를 추가하지 않는다. 정상 저장이 완료되고 read-only parser 검증까지 끝난 평문 HWP/HWPX payload만 ‘이전 저장본’으로 제한 보관하는 설계다.
- 창당 1개·개별 32 MiB·프로세스 전체 64 MiB·monotonic 30분 TTL, 작업 lease·보호 문서 제외·취소/실패 보존 정책을 정의했다. 이는 다음 단계 구현 승인 대상인 설계값이며 성능 실측 결과가 아니다.
- 새 문서 미저장 편집, 보호 상태 불명, 검증 중 fatal, 저장 동기화 실패 등은 native 복구본 없음으로 처리한다. 원본 입력·화면 snapshot·이전 저장본을 최신 미저장 편집 복구본과 구분한다.

### fatal/저장 경합

- 현재 Coordinator fatal 처리에서 token/session 무효화, Store에서 session 제거와 fallback 전환이 일어난다. 이 상태와 마지막 dirty/복구 자료를 명시적인 health와 분리할 필요가 있다.
- save/HTML/PDF write 직전 gate, 이미 제출된 print, 비상관 share handler, native command dispatcher의 다른 창 fallback, 종료의 live session refresh를 점검표로 남겼다.
- native가 오류를 관측하기 전 이미 성공한 atomic write나 시스템 제출 인쇄를 사후 취소했다고 보고하지 않는다. 늦은 callback이 clean/ready로 되돌리지 못하도록 후속 검증한다.

## 검증 결과

조사 명령과 체크를 수행하고 다음을 확인했다.

```text
git ls-remote upstream refs/heads/devel
5e2b9bfbf08573a31fa1e11a2445ff63fc0755c0 refs/heads/devel

PASS: 두 commit 공개 RPC/recovered·legacy 손실·자동복구 보호/저장소·manifest 대조
PASS: manifest·core lock·조사 commit 식별 일치
PASS: 수행계획·구현계획·계약·오늘할일 상대 링크와 trailing whitespace 검사
PASS: git diff --check
```

대조 방법은 각 commit에서 protocol/runtime/rpc-router/main/autosave-manager/autosave-store/recovery-format을 `git show`로 읽고 원본 blob ID를 보존하는 방식이다. 코드 동작을 실행한 것이 아니라 API·분류·버전의 소스 검사다. 문서 변경만 있으므로 XCTest, build, 실제 UI smoke와 복구/성능 테스트는 이 단계에서 실행하지 않았고 통과로 기록하지 않는다.

## 잔여 위험

- producer가 checks 전체를 보증하는 새 일반 명령 복구 API는 없다. HostApp 내부 DTO가 곧 upstream 합의나 구현을 뜻하지 않는다.
- full body snapshot restore 성공이 history·cursor·dirty·후속 명령 안전성 전체를 보증하지 않는다. 실제 producer 구현과 UI 회귀가 필요하다.
- 이전 저장본은 그 뒤의 미저장 변경을 포함하지 않는다. 후보 TTL·용량·보호 정책은 구현과 실제 검증이 남아 있다.
- raw global runtime 오류는 원래 editor epoch를 확실히 알 수 없는 경우가 있다. 그런 오류를 복구 성공으로 낮추지 않는다.
- Stage 1 범위는 source/API 분석으로 충족했으나 기능 전체와 실제 upstream 성공 경로 수용은 미완료다.

## 다음 단계 영향

- Stage 2는 내부 오류 수용 모델·세대/순서 검증·health·비차단 알림과 합성 producer 테스트를 구현할 수 있다. 현재 bundle에서 새 복구 성공 수신 adapter는 활성화하지 않는다.
- Stage 3는 현재 bundle의 suspended/입출력 차단·시점 표시 이전 저장본·복구본 없음·명시 restart 경로를 진행할 수 있다.
- Stage 4의 일반 명령 복구 성공 실제 수용은 지원 공개 API·안정 release 반영이 선행되어야 한다. 미출시 commit pin이나 합성 테스트로 이를 대체하지 않는다.
- 공개 API가 제공되면 capability/메서드/보증/버전을 계약 문서에 반영하고 실제 adapter 활성화 및 의존성 반영의 승인 범위를 정렬한다.

## 승인 요청

1. 이 Stage 1 계약과 초기 복구 자료 정책을 수용한다.
2. Stage 2를 내부 수용 모델·검증·비차단 UI 준비 범위로 시작한다. 현재 bundle은 새 capability 미지원 상태로 유지한다.
3. 실제 upstream 성공 경로 수용과 안정 bundle 반영이 남아 있다는 조건을 유지하며, 단계별 검증 후 다음 승인을 받는다.
