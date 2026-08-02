# Task M040 #453 Stage 1 완료보고서

## 단계 목적

네트워크와 UI 없이 최초 계측 분류, 실제 앱 버전 전환, 동일 전환 중복 방지, Sparkle pending 일치 여부를 결정론적으로 판단하는 익명 이벤트·로컬 상태 기반을 구현한다.

## 구현 결과

### 공개 이벤트 모델

`Sources/HostApp/Services/AppExecutionEvent.swift`에 공개 수집기 계약과 같은 이벤트 모델을 추가했다.

| 구성 | 역할 |
|------|------|
| `AppExecutionEventType` | `first_launch`, `existing_baseline`, `update` 구분 |
| `AppExecutionUpdateChannel` | `direct_dmg`, `homebrew`, `sparkle`, `unknown` 구분 |
| `AppExecutionVersion` | 서버와 같은 semantic version 형식 정규화·검증 |
| `AppExecutionUTCDate` | 실제 발생 시각을 UTC `YYYY-MM-DD`로 변환·검증 |
| `AppExecutionEvent` | 허용된 여섯 payload key의 생성·인코딩·디코딩 검증 |

`AppExecutionEvent`는 다음 조건을 생성 시점과 저장 상태 복원 시점에 모두 검증한다.

- UUID v4 event ID
- `v` 또는 `V` prefix 제거 후 서버 정규식에 맞는 32 byte 이하 version
- `update`에서만 서로 다른 `from_version`과 `to_version` 허용
- 최초 실행·기존 기준선의 `from_version`은 JSON `null`
- Gregorian UTC 실제 날짜
- snake_case 여섯 key만 인코딩

event ID는 이벤트마다 생성하며 사용자·기기·설치 ID로 재사용하는 필드가 없다.

### 버전 상태와 저장소

`Sources/HostApp/Services/AppExecutionAnalyticsState.swift`에 다음 상태를 추가했다.

- schema version
- 마지막 관측 버전 `lastObservedVersion`
- 서버가 마지막으로 수락한 버전 `lastAcceptedVersion`
- Sparkle pending 이전·대상 버전과 기록 시각
- 공개 이벤트, 생성 시각, 최초 요청 시각을 담는 outbox entry

상태는 `alhangeul.analytics.state.v1` key의 Codable `Data`로 저장한다. opt-out은 별도 `alhangeul.analytics.enabled.v1` key를 사용하고 미설정 시 활성화한다. 저장소는 같은 인스턴스의 read-modify-write를 `NSLock`으로 직렬화한다.

`lastObservedVersion`은 이벤트 enqueue와 같은 저장 연산에서 갱신한다. 따라서 outbox가 나중에 전송·만료·폐기돼도 같은 실행이나 버전 전환이 재생성되지 않는다. `lastAcceptedVersion`은 Stage 2에서 `202` 응답을 처리할 때만 갱신할 수 있도록 별도 필드로 유지했다.

현재 schema가 아니거나 JSON이 손상됐거나 version 필드가 정규화되지 않았거나 outbox event ID가 중복된 상태는 crash 없이 빈 현재 schema 상태로 격리 복구한다.

### 최초 실행과 버전 전환 정책

분석 전용 상태를 쓰기 전에 다음 기존 app-owned `UserDefaults` key만 allowlist 증거로 확인한다.

- `alhangeul.launchMaintenance.completedBuild`
- `alhangeul.recentDocuments`
- `alhangeul.quickLookConflict.dismissedFingerprint.v1`

최초 관측에서 allowlist 증거가 있으면 `existing_baseline`, 없으면 `first_launch`를 생성한다. Sparkle 또는 macOS 소유 defaults와 문서 경로·내용은 증거로 사용하지 않는다.

이후 실행 정책은 다음과 같다.

| 조건 | 결과 |
|------|------|
| 현재 버전과 마지막 관측 버전이 같음 | 이벤트 없음, stale pending 제거 |
| 현재 버전이 다르고 pending의 이전·대상 버전이 모두 일치 | `update`, channel `sparkle` |
| 현재 버전이 다르지만 pending 없음·불일치 | `update`, channel `unknown` |
| 현재 버전 형식 또는 event ID가 잘못됨 | 상태 변경과 이벤트 생성 없음 |
| opt-out | 기존 상태를 읽거나 바꾸지 않고 이벤트 생성 없음 |

`direct_dmg`와 `homebrew`는 Stage 1에서 추정하지 않는다. Sparkle도 callback만으로 성공 처리하지 않고 이후 Stage 4에서 다음 실행의 실제 bundle version과 대조한다.

### 테스트 구조

`project.yml`의 기존 `HostAppTests`에 실제 production source 두 파일을 직접 포함하고 다음 테스트를 추가했다.

- `Tests/HostAppTests/AppExecutionEventTests.swift`: 6개
- `Tests/HostAppTests/AppExecutionAnalyticsStateTests.swift`: 13개

fake UTC 시각, UUID, 격리 `UserDefaults` suite를 사용해 운영 Worker 또는 실제 사용자 defaults를 변경하지 않는다.

## 검증 결과

| 검증 | 결과 | 비고 |
|------|------|------|
| `xcodegen generate` | 통과 | `project.yml` 기준 source membership 생성 |
| `HostAppTests` | 통과 | 전체 44개, 실패 0; 신규 분석 테스트 19개 포함 |
| HostApp Debug build | 통과 | app·Preview·Thumbnail과 새 Foundation source compile/link 성공 |
| `./scripts/check-no-appkit.sh` | 통과 | shared/CoreBridge 경계에 AppKit/UIKit 추가 없음 |
| 개인정보 경계 검색 | 통과 | 분석 source에 문서·계정·기기·설치 ID, payload logger 없음 |
| `git diff --check` | 통과 | whitespace 오류 없음 |

신규 테스트는 다음 경계를 포함한다.

1. 신규 상태의 `first_launch`
2. 세 allowlist key 각각의 `existing_baseline`
3. Sparkle 소유로 가정한 비allowlist defaults 제외
4. 동일 버전 재실행과 outbox 제거 후 재실행 중복 방지
5. `unknown` 버전 전환
6. Sparkle pending 일치·불일치·미설치
7. opt-out 기본값과 생성 중단
8. 잘못된 version·UUID·payload·UTC 날짜 거부
9. 손상 JSON·미지원 schema·비정규 version 상태 복구
10. payload 여섯 key와 `null` 이전 버전 인코딩

## 개발 산출물 등록 정리

HostApp Debug build가 `build.noindex` 산출물을 LaunchServices에 등록해 다음 정리를 수행했다.

- 표준 `--cleanup-dev-registrations` helper 실행
- `xcodebuild ... clean`으로 생성된 Debug app 제거
- LaunchServices garbage collection 실행
- 최종 PlugInKit provider root 확인: `/Applications/Alhangeul.app`

최종 hygiene helper는 개발 app bundle이 없고 PlugInKit 개발 provider도 없는데 개발 등록 한 건을 계속 보고했다. 진단 원문을 확인한 결과 실제 항목은 HostApp registration이 아니라 삭제된 Debug app 내부 Sparkle `Updater.app` 경로였고, helper의 경로 추출이 중간의 `Alhangeul.app`까지만 잘라 host app으로 오인한 false positive였다. 전역 LaunchServices database reset은 수행하지 않았다.

## Stage 1 범위 밖 작업

- outbox 64건 상한과 30일·6일 만료 계산
- HTTP 응답별 제거·재시도와 `lastAcceptedVersion` 갱신
- 공개 endpoint와 URLSession transport
- AppDelegate·앱 실행당 1회 flush 연결
- Sparkle delegate callback 연결
- 설정 UI와 opt-out 시 outbox 제거

위 항목은 승인된 구현계획의 Stage 2 이후에서 순서대로 진행한다. 현재 앱은 새 모델을 production launch 흐름에 아직 호출하지 않으므로 실제 이벤트를 만들거나 전송하지 않는다.

## 승인 요청

Stage 1의 익명 이벤트·버전 상태 모델과 단위 검증 결과를 승인하고, Stage 2 `비차단 outbox와 재시도 정책 구현` 진입을 요청한다.
