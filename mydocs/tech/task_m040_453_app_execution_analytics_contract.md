# 알한글 익명 실행 이벤트 계약

## 목적

이 문서는 HostApp이 수집하는 익명 최초 실행·버전 전환 이벤트의 데이터 경계, 오프라인 동작, 해석 한계와 검증 기준을 정의한다. 구현 진실 원천은 `Sources/HostApp/Services/AppExecutionEvent.swift`, `AppExecutionAnalyticsState.swift`, `AppExecutionOutbox.swift`, `AppExecutionAnalyticsRuntime.swift`다.

## 지표의 의미와 한계

수집 결과는 **네트워크 연결 환경에서 공개 수집 서버에 도달한 익명 앱 실행 이벤트**다. 다음 값으로 해석하면 안 된다.

- 전체 설치 수
- 고유 사용자 수
- 고유 기기 수
- 현재 활성 사용자 수
- 영구 폐쇄망을 포함한 전체 실행 수

영구 사용자·기기·설치 식별자를 만들지 않으므로 서로 다른 이벤트가 같은 설치에서 발생했는지 연결할 수 없다. 기능 도입 이전 설치본은 앱 소유 로컬 상태가 남아 있을 때만 `existing_baseline`으로 분류한다. 이전 상태가 없거나 삭제됐다면 기존 설치도 `first_launch`로 관측될 수 있다.

## 공개 payload

전송 JSON은 다음 여섯 key만 허용한다.

| key | 값 |
|---|---|
| `event_id` | 이벤트마다 새로 생성하고 재전송 중복 제거에만 쓰는 UUID v4 |
| `event_type` | `first_launch`, `existing_baseline`, `update` |
| `occurred_date` | 실제 이벤트 발생 UTC 날짜 `YYYY-MM-DD` |
| `from_version` | update의 이전 semantic version, 그 외 `null` |
| `to_version` | 현재 또는 대상 semantic version |
| `update_channel` | `sparkle` 또는 확인할 수 없는 경우 `unknown`; 계약상 `direct_dmg`, `homebrew` 허용 |

다음 정보는 payload, endpoint query, header, 로그에 넣지 않는다.

- 문서 내용, 파일명, 파일 경로, 최근 문서 목록
- 계정, 이메일, 사용자·기기·설치 식별자
- IP 주소를 앱이 별도 필드로 수집한 값
- 하드웨어, macOS 또는 Sparkle System Profile
- 집계 조회 token, API key, 운영 secret

`event_id`는 설치 간 연결에 재사용하지 않는다. 공개 endpoint는 인증 없는 HTTPS URL이며 앱 bundle에 포함돼도 되는 비밀이 아닌 값이다.

HTTP 요청 header는 `Content-Type: application/json`, `User-Agent: Alhangeul`, `Accept-Language: en`의 고정값만 사용한다. 앱·build·CFNetwork·Darwin version이나 사용자의 선호 언어가 기본 header로 노출되지 않도록 ephemeral session configuration에서 명시적으로 덮어쓴다. 수집 endpoint는 고정 URL이므로 HTTP redirect는 같은 host 여부와 관계없이 따르지 않는다.

## 빌드 구성과 endpoint

Production endpoint의 단일 편집 원본은 `project.yml`의 HostApp `ALHANGEUL_APP_EXECUTION_ENDPOINT` 설정이다. 공통 `Sources/HostApp/Info.plist`는 URL literal 대신 `$(ALHANGEUL_APP_EXECUTION_ENDPOINT)` placeholder만 참조한다.

- HostApp base 값은 빈 문자열이며 Debug와 별도로 승인되지 않은 개발 configuration은 production endpoint를 얻지 않는다.
- 표준 Release configuration만 공개 production HTTPS endpoint를 주입한다.
- 빈 값이나 유효하지 않은 endpoint는 `AppExecutionAnalyticsEndpoint.resolve()`가 `nil`로 거부한다. Coordinator는 connectivity 확인과 transport 생성을 시작하지 않고 outbox와 앱·문서 기능을 비차단 상태로 유지한다.
- Endpoint가 없는 실행은 event를 전송하지 않을 뿐 아니라 **생성·적재하지도 않는다**. `AppExecutionAnalyticsRuntime.prepareForLaunch()`는 delivery가 구성되지 않았으면 observer를 호출하지 않고 반환하므로 `lastObservedVersion`·`pendingSparkleUpdate`·outbox가 모두 그대로 유지된다.
- 이 gate가 필요한 이유는 Debug와 Release가 같은 `PRODUCT_BUNDLE_IDENTIFIER`를 쓰고 따라서 같은 sandbox container의 `UserDefaults`와 outbox를 공유하기 때문이다. 전송만 막고 적재를 허용하면 Debug 실행이 남긴 event를 같은 머신의 이후 Release 실행이 production으로 flush한다. 미시도 항목 보존 기간이 30일이므로 차단이 아니라 지연에 그친다.
- 이 구분은 Xcode build configuration 기준이지 서명·공증 상태 기준이 아니다. 로컬 unsigned Release build도 production endpoint를 포함하므로 실행·전송 smoke에 사용하지 않는다.
- 실제 전송 검증이 필요하면 production과 분리된 staging endpoint, 데이터 제거 정책과 작업지시자 승인을 먼저 마련한다. 별도 승인 없이 production 합성 이벤트를 전송하지 않는다.

Task #479의 설정 분리 이전에는 공통 plist URL이 Debug·Release에 모두 들어갈 수 있었다. 공개 `v0.1.9`에는 수집 코드가 없었지만 운영 집계에는 2026-08-04와 2026-08-12의 `0.1.9 existing_baseline` 행이 각각 1건 존재한다. 기능 병합 뒤 실행한 개발 build에서 발생한 것으로 추정되지만 현재 payload에는 build configuration이나 영구 식별자가 없으므로 사후에 이를 증명하거나 같은 version의 공개 Release 이벤트와 구분할 수 없다.

따라서 설정 분리 전 수집 행을 공개 설치·사용자 수로 단정하지 않으며 기존 행을 삭제·재분류·보정하지 않는다. 설정 분리 이후 Debug는 production 전송 경로가 비활성화되지만, 이 변경이 과거 집계의 의미를 소급해 바꾸지는 않는다.

이 gate는 적용 시점 이후의 실행에만 작용한다. 적용 전 Debug build가 이미 개발 머신의 outbox에 넣어 둔 항목은 남아 있고 보존 기간 안에 같은 머신에서 Release 실행이 일어나면 전송될 수 있다. 이 잔여분도 payload만으로는 구분할 수 없으므로 위와 같은 원칙으로 다룬다.

## 로컬 상태와 오프라인 동작

분석 전용 `UserDefaults` state에는 공개 payload와 다음 bookkeeping만 저장한다.

- 마지막 관측 version과 마지막 서버 수락 version
- Sparkle 설치 예정 이전·대상 version과 기록 시각
- outbox entry 생성 시각과 최초 전송 시도 시각

오프라인에서는 문서 기능과 앱 실행을 계속하고 HTTP 요청을 만들지 않는다. outbox 정책은 다음과 같다.

- 최대 64건 FIFO
- 최초 요청 전: UTC 발생일 day 0부터 day 30까지 보관, day 31 폐기
- 최초 요청 후: UTC 최초 시도일 day 0부터 day 6까지 재시도, day 7 폐기
- 연결 복구 뒤에도 `occurred_date`를 수신일로 바꾸지 않음
- 영구 폐쇄망에서 만료된 이벤트는 조용히 폐기하며 강제 반출하지 않음

요청은 앱 실행당 최대 한 pass에서 snapshot의 각 이벤트를 FIFO로 한 번씩만 처리한다. 연결 확인은 일회성이고 상주 monitor나 retry timer를 만들지 않는다. request와 resource timeout은 5초다. 네트워크 오류·timeout·HTTP `429`·`500...599`가 발생하면 해당 pass를 즉시 끝내며, 아직 시도하지 않은 snapshot 항목은 다음 앱 실행까지 최초 시도 시각을 기록하지 않은 채 보관한다.

## 응답과 업데이트 분류

| 결과 | outbox 처리 |
|---|---|
| HTTP `202` | 제거하고 수락 version 기록 |
| HTTP `429`, `500...599` | 재시도 기간 안에서 유지 |
| 네트워크 오류·timeout | 재시도 기간 안에서 유지 |
| 그 외 `400...499` | 잘못된 payload로 보고 제거 |
| 예상하지 못한 상태·내부 오류 | 보수적으로 유지 |

Sparkle은 `willInstallUpdate`에서 pending만 저장한다. 다음 실행의 실제 bundle version이 pending target과 일치할 때만 `sparkle` update로 확정한다. 취소·실패·target mismatch는 Sparkle 성공으로 기록하지 않는다.

## 사용자 선택

분석은 미설정 시 활성화되며 macOS `설정… > 개인정보`에서 끌 수 있다.

비활성화하면 다음 동작을 원자적으로 수행한다.

- outbox와 Sparkle pending 즉시 제거
- 마지막 서버 수락 version 제거
- 시작된 flush task 취소
- 신규 이벤트 생성과 전송 중단
- 현재 version 기준선만 유지해 재활성화 시 과거 전환을 소급 생성하지 않음

## 운영·검증 원칙

- 기본 단위·통합·smoke 검증은 fake connectivity와 URLProtocol stub 또는 endpoint가 제거된 일회용 Debug app을 사용한다.
- 공개 Worker를 직접 호출하는 smoke는 운영 집계를 오염시키므로 별도 승인과 테스트 이벤트 제거 정책 없이 실행하지 않는다.
- app bundle에는 공개 endpoint 외 분석 credential을 넣지 않는다.
- event ID, payload, outbox와 문서 정보를 production log에 남기지 않는다.
- 대시보드와 운영 문서는 지표를 항상 “관측된 익명 이벤트”로 표현한다.

공개 수집기는 Cloudflare Worker에서 요청을 처리하므로 전송 계층의 client IP와 Cloudflare 요청 metadata는 공급자 인프라를 통과한다. 배포된 Worker는 `request.cf`, IP, User-Agent, Accept-Language와 원문 body를 D1에 저장하거나 application log로 남기지 않고, Workers observability를 비활성화하며 Logpush를 사용하지 않는다. D1에는 7일 중복 제거용 `event_id` SHA-256 hash와 허용된 집계 차원만 저장한다. 사용자 안내는 앱 payload의 비식별성과 수집기 저장 정책을 구분해 표현한다.
