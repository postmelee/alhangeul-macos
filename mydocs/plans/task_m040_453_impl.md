# Issue #453 구현 계획서

수행계획서: `mydocs/plans/task_m040_453.md`

## 작업 개요

- 이슈: #453 최초 실행·버전 전환 이벤트 생성 및 전송
- 마일스톤: M040 (`v0.4`)
- 브랜치: `local/task453`
- 기준 브랜치: `devel`
- 목표: 알한글의 오프라인 우선 동작을 유지하면서 최초 실행·기존 설치 기준선·실제 버전 전환을 영구 식별자 없는 익명 이벤트로 기록하고, 공개 수집기에 비차단 전송한다.

## 구현 원칙

- 문서명·경로·내용, 계정, 사용자·기기·설치 식별자, 하드웨어·시스템 프로파일을 수집하지 않는다.
- `event_id`는 이벤트별 UUID v4이며 설치를 연결하는 식별자로 재사용하지 않는다.
- 분석 실패·지연·비활성화는 앱 실행, 문서 열기, 종료, Sparkle 업데이트를 막지 않는다.
- 분석 네트워크 요청을 앱 생명주기 완료 조건으로 사용하지 않는다.
- 앱 실행마다 outbox flush pass는 프로세스 기준 최대 한 번만 시작하고 백그라운드 상주 작업을 만들지 않는다.
- Sparkle 설치 직전에는 pending 전환만 저장하고, 다음 실행에서 실제 bundle version이 일치할 때만 `update`를 만든다.
- `direct_dmg`와 `homebrew`를 로컬 상태만으로 확정할 수 없으면 추정하지 않고 `unknown`을 사용한다.
- 분석은 기본 활성화하되 설정에서 비활성화할 수 있게 하고, 비활성화 시 대기 이벤트를 즉시 제거한다.
- 공개 수집 URL만 app bundle에 포함하며 집계 조회 token이나 운영 secret은 포함하지 않는다.
- `Sources/RhwpCoreBridge`와 문서 렌더링 경계는 변경하지 않는다.
- `project.yml`을 Xcode project 원본으로 유지하고 `Alhangeul.xcodeproj`는 직접 수정하지 않는다.

## 공개 수집 계약

### Endpoint

- URL: `https://alhangeul-install-events.postmelee.workers.dev/v1/install-events`
- Method: `POST`
- Content-Type: `application/json`
- 인증: 없음
- 본문 상한: 2 KiB
- 앱 설정: HostApp `Info.plist`의 공개 endpoint key에서 읽는다.
- endpoint가 없거나 유효한 HTTPS URL이 아니면 이벤트 생성 상태는 유지하되 해당 실행의 전송은 조용히 생략한다.

### Payload

전송 JSON은 다음 여섯 key만 허용한다.

| key | 규칙 |
|---|---|
| `event_id` | 이벤트마다 새로 생성한 UUID v4 문자열 |
| `event_type` | `first_launch`, `existing_baseline`, `update` 중 하나 |
| `occurred_date` | 이벤트가 실제 발생한 UTC 날짜, `YYYY-MM-DD` |
| `from_version` | `update`에서만 이전 semantic version, 나머지는 `null` |
| `to_version` | 현재 또는 대상 semantic version |
| `update_channel` | `direct_dmg`, `homebrew`, `sparkle`, `unknown` 중 하나 |

- `update`는 `from_version`과 `to_version`이 모두 유효하고 서로 달라야 한다.
- `first_launch`와 `existing_baseline`은 `from_version`을 `null`로 보낸다.
- `occurred_date`는 이벤트 생성 시 확정하고 재시도 때 수신일로 바꾸지 않는다.
- `CFBundleShortVersionString`을 정규화한 semantic version을 사용하며 파싱할 수 없으면 이벤트를 생성하지 않는다.

### 응답 처리

- `202`: 서버 수락으로 처리하고 outbox에서 제거한다.
- `429`, `500...599`, 네트워크 오류, timeout: 재시도 대상으로 유지한다.
- 그 외 `400...499`: 잘못된 이벤트로 간주하고 제거한다.
- 예상하지 못한 상태 코드와 transport 내부 오류는 앱 기능에 전파하지 않고 재시도 대상으로 보수적으로 유지한다.

## 로컬 상태 모델

### 저장 경계

Foundation 기반 `Codable` 상태를 전용 `UserDefaults` key의 `Data`로 저장한다. 최대 64건의 작은 이벤트만 보유하므로 별도 데이터베이스나 파일 잠금 계층은 도입하지 않는다. 테스트에서는 격리 suite 또는 메모리 저장소를 주입한다.

제안 key:

- `alhangeul.analytics.enabled.v1`: opt-out 설정, 미설정 시 `true`
- `alhangeul.analytics.state.v1`: 아래 상태 blob

상태 blob은 다음 값을 소유한다.

- schema version
- 마지막 관측 app version (`lastObservedVersion`)
- 서버가 마지막으로 수락한 app version (`lastAcceptedVersion`)
- Sparkle pending 전환
  - 이전 version
  - 대상 version
  - 기록 시각
- outbox event 목록
  - 공개 payload
  - 생성 시각
  - 최초 요청 시작 시각 또는 `nil`

손상되거나 알 수 없는 schema는 crash 없이 빈 상태로 격리 복구한다. payload에 포함되지 않는 생성·시도 시각은 로컬 보존 정책 계산에만 사용한다.

### 관측 버전과 수락 버전 분리

- `lastObservedVersion`은 이벤트 enqueue와 같은 저장 연산에서 현재 version으로 갱신한다.
- 동일 version 재실행에서는 새 이벤트를 만들지 않는다.
- 이벤트가 만료·폐기되거나 opt-out으로 제거돼도 같은 전환을 다음 실행에서 다시 만들지 않는다.
- `lastAcceptedVersion`은 해당 version 이벤트가 `202`로 제거될 때만 갱신한다.
- 두 값을 분리해 “생성 중복 방지”와 “실제 서버 수락 기록”을 동시에 만족한다.

### 최초 계측 분류

분석 상태가 아직 없을 때, 분석 key를 쓰기 전에 다음 기존 app 소유 상태를 allowlist로 검사한다.

- launch maintenance 완료 build 상태
- 최근 문서 목록 상태
- Quick Look 충돌 안내 dismissal 상태

하나라도 존재하면 `existing_baseline`, 없으면 `first_launch`를 생성한다. Sparkle와 macOS가 소유하는 defaults, 파일 경로, 최근 문서 내용은 분류 근거로 읽지 않는다. 이 휴리스틱은 기존 설치를 완벽히 구분하지 못하므로 결과를 전체 신규 사용자 수로 해석하지 않는다.

### 이후 버전 전환 분류

- 현재 version이 `lastObservedVersion`과 같으면 생성하지 않는다.
- Sparkle pending 대상 version이 현재 version과 같고 이전 version과 다르면 `update(..., channel=sparkle)`를 생성한다.
- Sparkle pending 대상과 현재 version이 다르면 Sparkle 성공으로 분류하지 않고 stale pending을 제거한다.
- 실제 현재 version이 `lastObservedVersion`과 다르지만 확인된 Sparkle 전환이 아니면 `update(..., channel=unknown)`을 생성한다.
- 하향 설치도 서로 다른 실제 version 전환으로 관측하되 channel은 확인 가능한 값 또는 `unknown`으로 기록한다.

## Outbox 보존과 실행 계약

### 보존 경계

- 최대 64건 FIFO로 유지한다.
- 먼저 만료 이벤트를 제거한 다음에도 64건을 초과하면 가장 오래된 이벤트부터 제거한다.
- 최초 요청 전에는 생성일을 day 0으로 보아 day 30까지 보관하고 day 31 시작에 폐기한다.
- 최초 요청을 실제 시작한 날을 day 0으로 보아 day 6까지 재시도하고 day 7 시작에 폐기한다.
- 경계 계산은 UTC calendar day로 수행해 payload의 `occurred_date`와 일치시키고 로컬 시간대·DST 영향을 받지 않는다.
- 최초 요청 시작 시각은 URLSession 요청을 시작하기 직전에 먼저 저장한다. 앱 종료나 crash가 발생해도 6일 재시도 창이 초기화되지 않는다.

### Flush pass

- AppDelegate가 프로세스 실행당 한 번 coordinator를 호출한다.
- 분석 비활성화, endpoint 부재, outbox 비어 있음에서는 즉시 종료한다.
- `NWPathMonitor`를 일회성 연결 확인기로 사용하고 첫 path 결과 후 즉시 cancel한다.
- path가 `.satisfied`가 아니면 HTTP 요청을 만들지 않는다.
- pass 시작 시점의 eligible snapshot만 FIFO 순서로 최대 한 번씩 처리하고 같은 pass에서 같은 이벤트를 재시도하지 않는다.
- 요청은 한 번에 하나씩 처리하되 앱 생명주기나 UI는 완료를 기다리지 않는다.
- request/resource timeout을 모두 5초 이하로 고정한 ephemeral `URLSession`을 사용한다.
- cache, cookie, credential persistence를 사용하지 않는다.
- event ID, payload, outbox 내용, 문서 정보를 로그에 남기지 않는다.

## Sparkle 연결 계약

Sparkle 2.9.1의 공식 `SPUUpdaterDelegate` API를 사용한다.

- updater delegate는 별도 `NSObject` helper로 만들고 `UpdateController`가 강하게 보유한다. Sparkle updater가 delegate를 weak 참조하므로 lifetime을 명시한다.
- `updater(_:willInstallUpdate:)`에서 현재 bundle version과 `SUAppcastItem.displayVersionString`을 검증해 pending 전환만 저장한다.
- callback 안에서는 HTTP 요청, flush, 앱 종료 대기를 수행하지 않는다.
- 다음 실행의 초기 분류에서 bundle version이 pending target과 일치할 때만 Sparkle update를 확정한다.
- 설치 취소·실패로 재실행 version이 바뀌지 않으면 update 이벤트를 생성하지 않는다.
- target mismatch에서는 stale pending을 Sparkle 성공으로 쓰지 않고 실제 version 차이만 `unknown` 전환으로 처리한다.
- 기존 appcast URL, EdDSA public key, 자동 확인 설정을 변경하지 않는다.
- `SUEnableSystemProfiling`, `SUSendProfileInfo`, feed parameter 기반 profile 수집을 추가하지 않는다.

## 앱 통합과 opt-out 계약

- 순수 모델·저장소·transport를 감싸는 process-wide production runtime을 한 번만 구성한다.
- `applicationDidFinishLaunching`의 가장 앞에서 기존 app 상태 증거를 읽고 현재 version 이벤트를 enqueue한다.
- 그 다음 기존 `LaunchMaintenanceService.runIfNeeded()`를 실행해 이번 실행이 기존 설치 증거로 오인되지 않게 한다.
- enqueue 후 flush pass만 비동기로 시작하고 AppDelegate method 반환을 기다리지 않는다.
- SwiftUI `Settings` scene에 익명 사용 추이 설정을 추가한다.
- 설정 설명에는 네트워크에 도달한 익명 최초 실행·버전 전환 이벤트이며 전체 설치 수나 고유 사용자 수가 아니라는 점을 표시한다.
- 문서·계정·기기 식별자를 수집하지 않고, 오프라인에서는 로컬 outbox에 제한적으로 보관한다는 점을 표시한다.
- 비활성화하면 신규 이벤트 생성과 전송을 중단하고 outbox와 Sparkle pending을 즉시 제거한다.
- 비활성화 시 `lastObservedVersion`은 유지해 다시 활성화했을 때 과거 실행이나 이미 관측한 전환을 소급 생성하지 않는다.
- 다시 활성화한 뒤 발생하는 다음 실제 version 전환부터 기록한다.

## Stage 1. 이벤트·버전 전환 상태 모델 구현

### 목표

네트워크와 UI 없이 최초 계측 분류, 실제 version 전환, 중복 방지, Sparkle pending 확인을 결정론적으로 검증한다.

### 작업

- `AppExecutionEvent` payload 모델과 event type·channel enum을 추가한다.
- UUID v4, UTC 날짜, semantic version 정규화·검증 로직을 분리한다.
- `AppExecutionAnalyticsState`와 versioned `UserDefaults` 저장소를 추가한다.
- clock, UUID generator, bundle version provider, legacy evidence resolver를 주입 가능하게 만든다.
- 기존 app-owned defaults allowlist 기반 `first_launch`·`existing_baseline` 분류를 구현한다.
- `lastObservedVersion`과 `lastAcceptedVersion`을 분리하고 enqueue 원자성을 보장한다.
- 동일 version, 외부 version 전환, Sparkle pending 일치·불일치 정책을 구현한다.
- `project.yml`의 `HostAppTests` source 포함 규칙에 새 Foundation 서비스와 테스트를 추가한다.

### 검증 시나리오

- 상태·기존 실행 증거 없음 → `first_launch`
- 기존 app-owned defaults 증거 있음 → `existing_baseline`
- 동일 version 재실행 → 새 이벤트 없음
- 다른 version + Sparkle pending 일치 → `update`, channel `sparkle`
- 다른 version + pending 없음·불일치 → `update`, channel `unknown`
- pending 존재 + 현재 version 변화 없음 → update 없음
- enqueue 후 재실행과 outbox 제거 후 재실행 → 같은 이벤트 재생성 없음
- 잘못된 version, 손상된 state, 알 수 없는 schema → crash 없이 보수적 처리
- opt-out 상태 → 신규 이벤트 없음

### 완료 기준

- 공개 payload에 허용된 여섯 key 외 정보가 없다.
- 영구 설치·사용자·기기 ID가 없다.
- 최초 분류와 version 전환이 UI·네트워크 없이 테스트된다.
- 동일 전환을 재실행에서 중복 생성하지 않는다.
- Stage 1 테스트와 HostApp compile이 통과한다.

### 검증

- `xcodegen generate`
- `xcodebuild -project Alhangeul.xcodeproj -scheme HostAppTests -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO test`
- `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build`
- `./scripts/check-no-appkit.sh`
- `git diff --check`

### 커밋 메시지

- `Task #453 Stage 1: 익명 실행 이벤트와 버전 상태 모델 추가`

## Stage 2. 비차단 outbox와 재시도 정책 구현

### 목표

64건 FIFO, 30일 미시도 보관, 최초 요청 후 6일 재시도, 응답별 제거·보존을 순수 정책과 fake transport로 검증한다.

### 작업

- 생성 시각과 최초 요청 시작 시각을 포함한 outbox entry를 구현한다.
- UTC day 기준 미시도 day 30·시도 후 day 6 보존과 다음 날 폐기를 구현한다.
- 만료 우선 제거와 64건 FIFO 상한을 구현한다.
- transport protocol과 응답 분류 정책을 추가한다.
- 첫 요청 직전 `firstAttemptedAt`을 저장하는 dequeue/attempt 상태 전이를 구현한다.
- `202`, 재시도 응답, 폐기 4xx에 따른 outbox 및 `lastAcceptedVersion` 갱신을 구현한다.
- 손상 state, 저장 실패, completion 중복 호출을 앱 기능에 전파하지 않는 방어 로직을 추가한다.

### 검증 시나리오

- 미시도 day 30 보존, day 31 폐기
- 첫 요청 day 6 재시도, day 7 폐기
- 로컬 시간대 변경과 DST에 영향 없는 UTC 경계
- 65번째 enqueue에서 만료 제거 후 가장 오래된 eligible 이벤트 폐기
- `202` 제거와 수락 version 기록
- `429`, `5xx`, network error, timeout 보존
- 그 외 `4xx` 제거
- 요청 시작 전에 최초 시도 시각 저장
- 같은 pass에서 같은 이벤트를 두 번 처리하지 않음

### 완료 기준

- outbox 상한·순서·만료 정책이 fake clock으로 재현 가능하다.
- 모든 HTTP·transport 결과가 제거 또는 재시도로 명확히 분류된다.
- 앱 종료 전에 completion이 오지 않아도 재시도 창이 초기화되지 않는다.
- 실제 공개 Worker 호출 없이 Stage 2 테스트가 통과한다.

### 검증

- HostAppTests outbox·응답 정책 테스트
- 경계 날짜 parameterized test
- `xcodebuild -project Alhangeul.xcodeproj -scheme HostAppTests -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO test`
- `git diff --check`

### 커밋 메시지

- `Task #453 Stage 2: 비차단 outbox와 재시도 정책 구현`

## Stage 3. 앱 실행 1회 전송 경로 연결

### 목표

공개 endpoint, 일회성 네트워크 경로 확인, 5초 이하 URLSession을 coordinator와 AppDelegate에 연결하면서 앱 실행을 차단하지 않는다.

### 작업

- `Info.plist`에 공개 수집 endpoint를 추가하고 HTTPS URL 검증 경계를 만든다.
- `NWPathMonitor` 기반 one-shot connectivity resolver를 구현하고 첫 결과 후 cancel한다.
- ephemeral URLSession 기반 JSON transport를 구현한다.
- request/resource timeout, cache·cookie·credential 비보존 정책을 적용한다.
- process-wide coordinator에 실행당 한 번 guard와 snapshot 단위 FIFO flush를 구현한다.
- AppDelegate 초기 흐름에서 legacy evidence capture·enqueue를 maintenance보다 먼저 수행한다.
- enqueue 후 flush를 비동기로 시작하고 앱 시작·종료가 기다리지 않게 한다.
- production endpoint 대신 fake protocol handler를 사용하는 통합 테스트 경계를 제공한다.

### 검증 시나리오

- path unsatisfied → HTTP 요청 0건
- path satisfied → 실행당 flush pass 1회
- coordinator 중복 호출 → 두 번째 pass 시작 없음
- endpoint 없음·HTTP URL·잘못된 URL → 요청 없음
- 첫 요청 시작 전에 outbox attempt 상태 저장
- snapshot에 있던 각 이벤트를 최대 한 번만 처리
- timeout 5초 이하와 앱 launch 반환 비차단
- 앱 재실행에서 남은 이벤트만 새 pass에서 재시도

### 완료 기준

- 네트워크가 없어도 앱 실행·문서 열기·종료가 정상이다.
- 장기 실행 monitor나 resident retry timer가 없다.
- app bundle에 공개 URL 외 secret이 없다.
- 실제 운영 지표를 만들지 않는 테스트로 runtime 경로가 검증된다.

### 검증

- HostAppTests coordinator·connectivity·transport 테스트
- `xcodebuild -project Alhangeul.xcodeproj -scheme HostAppTests -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO test`
- `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build`
- offline Debug launch smoke
- built app `Info.plist` endpoint·secret 정적 검사
- `git diff --check`

### 커밋 메시지

- `Task #453 Stage 3: 앱 실행 비차단 전송 경로 연결`

## Stage 4. Sparkle 전환 확인과 분석 설정 연결

### 목표

Sparkle 설치 예정 상태를 다음 실행의 실제 version과 대조해 update를 확정하고, 사용자가 수집을 이해하고 즉시 비활성화할 수 있게 한다.

### 작업

- 강하게 보유되는 `SPUUpdaterDelegate` helper를 `UpdateController`에 연결한다.
- `updater(_:willInstallUpdate:)`에서 이전·대상 version과 기록 시각을 pending으로만 저장한다.
- `SUAppcastItem.displayVersionString`을 semantic version으로 검증한다.
- 다음 실행의 pending 일치·취소·실패·대상 불일치 처리를 runtime에 연결한다.
- SwiftUI `Settings` scene과 익명 사용 추이 opt-out UI를 추가한다.
- 수집 항목, 관측 지표 한계, 오프라인 보관, 비활성화 효과를 한국어로 표시한다.
- 비활성화 시 outbox·pending 제거와 신규 생성·전송 중단을 즉시 적용한다.
- 재활성화 시 과거 이벤트를 소급 생성하지 않고 이후 실제 version 전환부터 기록한다.

### 검증 시나리오

- `willInstallUpdate` → pending 저장만 수행, 요청 없음
- 다음 실행 target 일치 → Sparkle update 한 건
- 설치 취소·실패로 version 동일 → update 없음
- target mismatch → Sparkle 이벤트 없음, 실제 version 차이는 `unknown`
- delegate lifetime 유지
- 기본 활성화와 opt-out persistence
- 비활성화 즉시 outbox·pending 제거, 전송 0건
- 재활성화 뒤 과거 이벤트 소급 생성 없음

### 완료 기준

- Sparkle 성공은 다음 실행의 실제 bundle version으로만 확정된다.
- Sparkle callback이 네트워크를 호출하거나 앱 종료를 기다리지 않는다.
- 사용자가 설정에서 수집 범위와 한계를 확인하고 비활성화할 수 있다.
- 기존 Sparkle appcast·서명·자동 업데이트 동작이 유지된다.

### 검증

- HostAppTests Sparkle observer·opt-out 정책 테스트
- HostApp build
- Debug 설정 화면과 opt-out 수동 smoke
- `rg -n 'SUEnableSystemProfiling|SUSendProfileInfo|sendsSystemProfile' Sources project.yml`
- `git diff --check`

### 커밋 메시지

- `Task #453 Stage 4: Sparkle 전환 확인과 분석 설정 추가`

## Stage 5. 오프라인 통합 검증과 개인정보 경계 확정

### 목표

전체 단위 테스트·빌드·오프라인 smoke·정적 검사를 수행해 로컬 앱 장점, 데이터 최소화, 공개 수집 계약을 최종 확인하고 문서화한다.

### 작업

- 모든 HostAppTests와 HostApp Debug build를 clean derived data에서 검증한다.
- 네트워크 연결 없음, 연결 복구, retry 응답, opt-out 시나리오를 fake endpoint 또는 protocol handler로 통합 검증한다.
- 실제 Worker를 호출하지 않는 smoke를 기본으로 유지해 운영 집계를 오염시키지 않는다.
- app bundle과 source에서 secret, System Profiling, 금지 payload field, 이벤트 payload logging이 없는지 검사한다.
- 앱 실행·문서 열기·종료와 Sparkle check가 분석 transport와 독립적인지 확인한다.
- `Sources/RhwpCoreBridge` 경계를 검사한다.
- 단계 완료보고서와 최종 결과보고서에 관측 지표 한계와 검증 결과를 기록한다.

### 완료 기준

- 전체 테스트와 HostApp build가 통과한다.
- 오프라인에서 분석 요청 없이 핵심 앱 기능이 정상이다.
- 보존·재시도·응답 계약과 opt-out이 통합 경로에서 재현된다.
- 문서·계정·기기 식별 정보와 운영 secret이 app bundle·payload·로그에 없다.
- 공개 수집기를 호출하는 운영 smoke가 필요하면 별도 승인과 테스트 이벤트 처리 정책을 먼저 받는다.

### 검증

- `xcodegen generate`
- `xcodebuild -project Alhangeul.xcodeproj -scheme HostAppTests -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO test`
- `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build`
- `./scripts/check-no-appkit.sh`
- analytics payload·secret·System Profiling·logging 정적 검사
- offline/restore/opt-out Debug smoke
- `git diff --check`

### 커밋 메시지

- `Task #453 Stage 5: 오프라인 통합 검증과 개인정보 경계 확정`

## 단계 승인 게이트

- Stage 1 완료 후 이벤트·상태 모델과 분류 테스트 결과를 보고하고 Stage 2 승인을 요청한다.
- Stage 2 완료 후 outbox 보존·재시도·응답 정책 결과를 보고하고 Stage 3 승인을 요청한다.
- Stage 3 완료 후 비차단 앱 실행 전송 경로와 오프라인 결과를 보고하고 Stage 4 승인을 요청한다.
- Stage 4 완료 후 Sparkle 전환·opt-out UI 결과를 보고하고 Stage 5 승인을 요청한다.
- Stage 5 완료 후 통합 검증 결과를 보고하고 최종 결과보고서·PR 게시 단계를 별도로 승인 요청한다.

## 승인 요청 사항

이 구현 계획 기준으로 Stage 1 구현 진행 승인을 요청한다.
