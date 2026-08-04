# Task M040 #453 Stage 3 완료보고서

## 단계 목적

공개 수집 endpoint, 일회성 연결 확인, 5초 이하 ephemeral HTTP transport를 앱 실행 흐름에 연결하되 네트워크 상태와 분석 요청이 앱 실행·종료를 막지 않도록 한다.

## 구현 결과

### 공개 endpoint 검증

HostApp `Info.plist`에 다음 공개 URL만 추가했다.

`https://alhangeul-install-events.postmelee.workers.dev/v1/install-events`

`AppExecutionAnalyticsEndpoint`는 다음 조건을 모두 만족할 때만 URL을 반환한다.

- `https` scheme
- 비어 있지 않은 host
- user·password 없음
- query·fragment 없음

endpoint가 없거나 조건을 만족하지 않으면 이벤트는 outbox에 유지하고 해당 프로세스의 전송을 조용히 생략한다. 앱 bundle에는 수집 조회 token, API key, 계정 ID, Authorization 값이 없다.

### 일회성 연결 확인

`AppExecutionOneShotConnectivityResolver`가 `NWPathMonitor`의 첫 path 결과만 사용한다.

- `.satisfied`에서만 HTTP 처리로 이동
- 첫 결과 직후 handler 해제와 monitor cancel
- path 결과가 오지 않을 때 1초 안전 timeout 후 false 반환
- timeout 값은 생성자에서도 최대 5초로 제한
- 장기 monitor, resident retry timer, 백그라운드 상주 작업 없음

연결되지 않은 경우 outbox entry의 `firstAttemptedAt`도 기록하지 않는다. 실제 HTTP 요청을 시작할 수 있을 때만 Stage 2 processor가 최초 요청 시각을 먼저 저장한다.

### Ephemeral JSON transport

`AppExecutionURLSessionTransport`를 추가했다.

- `URLSessionConfiguration.ephemeral`
- request·resource timeout 각 5초
- cache 무시 및 URL cache 없음
- cookie·credential storage 없음
- `waitsForConnectivity` 비활성화
- `POST application/json`
- payload 2 KiB 상한
- 허용된 여섯 payload key만 기존 `AppExecutionEvent` encoder로 전송

HTTP status는 Stage 2의 delivery policy로 전달한다. URL timeout은 `.timeout`, 그 외 `URLError`는 `.network`, 기타 내부 오류는 `.other`로 변환해 앱 기능에 throw하지 않는다.

### 프로세스 실행당 한 번 coordinator

`AppExecutionAnalyticsCoordinator`는 lock으로 process instance의 첫 호출만 claim한다. 다음 조건에서는 연결 확인과 transport를 만들지 않고 즉시 종료한다.

- 분석 비활성화
- outbox 비어 있음
- endpoint 부재·무효

eligible event가 있으면 비동기 `Task`에서 연결 상태를 한 번 확인하고 Stage 2 snapshot processor를 실행한다. 같은 coordinator를 여러 번 호출해도 flush pass는 하나만 시작된다. 다음 앱 실행은 새 process coordinator로 남은 이벤트만 다시 처리한다.

### AppDelegate 연결 순서

`applicationDidFinishLaunching`의 시작 순서를 다음으로 변경했다.

1. 현재 bundle version 관측·outbox enqueue
2. 비차단 flush pass 시작
3. 기존 `LaunchMaintenanceService.runIfNeeded()`
4. 기존 Quick Look 안내와 창 복구 흐름

legacy evidence 판별이 launch maintenance key를 이번 실행에 쓰기 전에 끝나므로 신규 실행이 기존 설치 기준선으로 오분류되지 않는다. AppDelegate는 연결 확인이나 URLSession completion을 기다리지 않는다.

## 테스트

`Tests/HostAppTests/AppExecutionAnalyticsRuntimeTests.swift`에 9개 테스트를 추가했다.

1. credential 없는 HTTPS endpoint만 허용
2. ephemeral session의 timeout·cache·cookie·credential 비보존
3. URLProtocol stub을 통한 POST·Content-Type·여섯 key·2 KiB 상한 확인
4. timeout 결과의 비throw 변환
5. 연결 불가에서 요청 0건·attempt 미기록
6. 중복 coordinator 호출에서 flush pass 1회
7. endpoint 부재에서 연결 확인·요청 0건
8. 연결 확인이 중단된 동안에도 `startIfNeeded()` 즉시 반환
9. 다음 process coordinator가 남은 이벤트만 재시도하고 `202`에서 제거

URLProtocol stub과 fake connectivity만 사용했으며 실제 Worker에는 요청하지 않았다.

## 검증 결과

| 검증 | 결과 | 비고 |
|------|------|------|
| `xcodegen generate` | 통과 | Network.framework와 runtime test source 반영 |
| HostAppTests | 통과 | 전체 69개, 실패 0; Stage 3 신규 9개 포함 |
| HostApp Debug build | 통과 | AppDelegate·Network.framework·runtime compile/link 성공 |
| endpoint 제거·opt-out Debug launch smoke | 통과 | 3초 이상 앱 유지, 분석 completion 대기 없이 종료 |
| built Info.plist endpoint 검사 | 통과 | 공개 HTTPS URL과 network-client entitlement 확인 |
| secret 정적 검사 | 통과 | 분석 runtime·Info.plist에 token·secret·Authorization 없음 |
| AppDelegate 순서 검사 | 통과 | 분석 관측이 launch maintenance보다 앞섬 |
| `./scripts/check-no-appkit.sh` | 통과 | shared/CoreBridge 경계 변경 없음 |
| `git diff --check` | 통과 | whitespace 오류 없음 |

Debug launch smoke 전 빌드 산출물의 endpoint를 확인한 뒤, 실제 운영 지표를 만들지 않도록 일회용 산출물에서 endpoint를 제거하고 분석 opt-out argument를 적용했다. smoke 뒤 표준 extension registration hygiene helper를 실행하고 `xcodebuild clean`으로 Debug app bundle을 제거했다. smoke 준비 과정에서는 소스 `Info.plist`를 추가 변경하지 않았다.

## Stage 3 범위 밖 작업

- Sparkle 설치 직전 pending 전환 기록
- 다음 실행 bundle version과 Sparkle target 대조
- 익명 사용 추이 설정 UI와 즉시 opt-out 정리
- 전체 오프라인·개인정보 최종 검증 문서

## 승인 요청

Stage 3의 공개 endpoint·비차단 실행 1회 전송 경로와 통합 검증 결과를 승인하고, Stage 4 `Sparkle 전환 확인과 분석 설정 연결` 진입을 요청한다.
