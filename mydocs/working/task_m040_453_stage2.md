# Task M040 #453 Stage 2 완료보고서

## 단계 목적

익명 실행 이벤트를 오프라인에서 제한적으로 보관하고, UTC 날짜 기준 30일·6일 계약과 HTTP·transport 결과별 제거·재시도를 실제 네트워크 없이 결정론적으로 처리하는 outbox 기반을 구현한다.

## 구현 결과

### UTC 보존과 64건 FIFO

`Sources/HostApp/Services/AppExecutionOutbox.swift`에 `AppExecutionOutboxPolicy`를 추가했다.

| 상태 | 보존 기준 |
|------|-----------|
| 최초 요청 전 | 생성일 day 0부터 day 30까지 보관, day 31 시작에 폐기 |
| 최초 요청 후 | 최초 요청일 day 0부터 day 6까지 재시도, day 7 시작에 폐기 |

경계는 경과 시간 24시간 단위가 아니라 Gregorian UTC calendar day 차이로 계산한다. 따라서 로컬 시간대와 DST에 영향을 받지 않고 payload `occurred_date`와 같은 날짜 축을 사용한다.

미시도 이벤트를 day 30에 처음 요청한 경우 실제 발생일 day 36까지 재시도할 수 있고 day 37 시작에 폐기한다. 이는 공개 수집기의 발생일 최대 36일 허용 범위와 일치한다.

enqueue는 다음 순서로 동작한다.

1. 만료 이벤트 제거
2. 기존 초과분이 있으면 오래된 항목부터 제거
3. 같은 event ID 중복 추가 방지
4. 새 항목을 FIFO 끝에 추가
5. 64건을 초과하면 가장 오래된 항목 제거

Stage 1의 이벤트 생성도 직접 배열에 append하지 않고 이 정책을 사용하도록 연결했다. 이벤트가 용량 제한으로 폐기돼도 `lastObservedVersion`은 유지되므로 같은 버전 전환을 다시 생성하지 않는다.

### 최초 요청 상태 전이

`AppExecutionOutbox`가 versioned state store 위에서 다음 원자적 연산을 제공한다.

- 만료 제거 후 현재 eligible snapshot 준비
- 요청 직전 event ID의 `firstAttemptedAt` 저장
- 기존 최초 요청 시각을 재시도에서 유지
- transport 결과를 event ID 기준으로 적용

processor는 `firstAttemptedAt` 저장이 성공한 뒤에만 transport를 호출한다. 요청 completion이 오기 전에 앱이 종료되더라도 다음 실행에서 6일 재시도 창이 새로 시작되지 않는다.

### 응답 분류

`AppExecutionDeliveryPolicy`는 결과를 다음처럼 분류한다.

| 결과 | 처리 |
|------|------|
| HTTP `202` | accepted, outbox 제거, `lastAcceptedVersion` 갱신 |
| HTTP `429` | retry, 보존 |
| HTTP `500...599` | retry, 보존 |
| network·timeout·기타 transport failure | retry, 보존 |
| 그 외 HTTP `400...499` | discard, 제거 |
| 예상하지 못한 HTTP 상태 | retry, 보수적 보존 |

이미 accepted 또는 discard로 제거된 event ID에 completion이 다시 들어오면 상태를 바꾸지 않고 `false`를 반환한다. client error 폐기는 `lastAcceptedVersion`을 변경하지 않는다.

### Snapshot processor

`AppExecutionEventTransport` async protocol과 `AppExecutionOutboxProcessor`를 추가했다. processor는 pass 시작 시점 snapshot을 FIFO 순서로 한 번씩만 처리하고, 처리 도중 새로 추가된 이벤트는 다음 pass에 남긴다. 같은 이벤트를 같은 pass 안에서 재시도하지 않는다.

Stage 2 production source에는 `URLSession`, `NWPathMonitor`, endpoint, timer가 없다. 테스트는 fake transport만 사용하며 실제 Worker를 호출하지 않는다. 프로세스 실행당 한 번 guard와 연결 상태 gate는 Stage 3 runtime coordinator에서 추가한다.

## 테스트

`Tests/HostAppTests/AppExecutionOutboxTests.swift`에 16개 테스트를 추가했다.

1. 미시도 day 30 보존·day 31 폐기
2. 최초 요청 후 day 6 보존·day 7 폐기
3. 미시도 day 30 최초 요청 후 발생일 day 36까지 재시도
4. UTC 자정 경계와 역방향 시각
5. 65번째 enqueue의 가장 오래된 이벤트 제거
6. 만료 우선 제거 후 용량 적용
7. 같은 event ID 중복 방지
8. 최초 요청 시각의 요청 전 저장과 재시도 유지
9. 응답·실패별 disposition matrix
10. `202` 제거와 수락 버전 기록
11. client error 제거와 수락 버전 보존
12. 중복 completion 무해성
13. retry 결과별 entry·최초 시도 시각 보존
14. FIFO 전송 순서와 transport 호출 전 attempt 저장
15. snapshot 생성 뒤 추가 이벤트를 같은 pass에서 보내지 않음
16. retry completion 시점에 기간이 지난 이벤트 폐기

## 검증 결과

| 검증 | 결과 | 비고 |
|------|------|------|
| `xcodegen generate` | 통과 | outbox production source를 HostAppTests에 포함 |
| `HostAppTests` | 통과 | 전체 60개, 실패 0; Stage 2 신규 16개 포함 |
| HostApp Debug build | 통과 | app·Preview·Thumbnail과 outbox source compile/link 성공 |
| `./scripts/check-no-appkit.sh` | 통과 | shared/CoreBridge 경계 변경 없음 |
| production network·logging 검색 | 통과 | Stage 2 source에 URLSession·NWPathMonitor·endpoint·payload logger 없음 |
| `git diff --check` | 통과 | whitespace 오류 없음 |

HostApp build 뒤 표준 registration cleanup helper를 실행하고 `xcodebuild clean`으로 Debug app bundle을 제거했다. PlugInKit provider root는 `/Applications/Alhangeul.app`이며, Stage 1에 기록한 nested Sparkle `Updater.app` 경로 추출 false positive는 LaunchServices 진단에 계속 남을 수 있다.

## Stage 2 범위 밖 작업

- 공개 endpoint `Info.plist` 설정과 HTTPS 검증
- ephemeral URLSession JSON transport와 5초 timeout
- `NWPathMonitor` one-shot 연결 gate
- AppDelegate의 legacy evidence capture·enqueue 연결
- 프로세스 실행당 한 번 flush guard
- Sparkle delegate callback과 설정 UI

현재 앱 실행 경로에는 observer와 processor를 아직 연결하지 않았으므로 실제 이벤트 생성·전송은 발생하지 않는다.

## 승인 요청

Stage 2의 비차단 outbox·보존·재시도·응답 정책과 fake transport 검증 결과를 승인하고, Stage 3 `앱 실행 1회 전송 경로 연결` 진입을 요청한다.
