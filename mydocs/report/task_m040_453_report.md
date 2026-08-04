# Task M040 #453 최종 결과보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | [#453 `최초 실행·버전 전환 이벤트 생성 및 전송`](https://github.com/postmelee/alhangeul-macos/issues/453) |
| 마일스톤 | M040 — v0.4 |
| 기준 브랜치 | `devel` |
| 작업 브랜치 | `local/task453` |
| 선행 수집기 | `postmelee/alhangeul-analytics` Issue #10 / PR #12 |
| 단계 | 수행계획, 구현계획, Stage 1~5 |

알한글 HostApp에 영구 사용자·기기·설치 식별자 없이 최초 실행, 기능 도입 전 기존 설치 기준선과 실제 버전 전환을 구분하는 익명 이벤트 경로를 추가했다. Sparkle 설치 예정 상태는 로컬에만 기록하고 다음 실행에서 실제 bundle version이 대상과 일치할 때만 업데이트 성공으로 확정한다.

분석은 앱 실행과 문서 기능을 막지 않는 비차단 경로다. 네트워크가 없으면 HTTP 요청을 시작하지 않고 제한된 로컬 outbox에 보관하며, 연결이 복구돼도 실제 발생일 `occurred_date`를 유지한다. 영구 폐쇄망이나 보관기간 내 재연결되지 않은 실행은 관측하지 않는 것을 의도된 경계로 둔다.

## 단계별 결과

| 단계 | 커밋 | 결과 |
|------|------|------|
| 수행·구현계획 | `58f42e4`, `3e093b1` | 수집기 계약, 5단계 구현 범위, 승인·검증 경계 확정 |
| Stage 1 | `456b586` | 여섯 필드 익명 이벤트, 버전 상태, 최초 실행·기존 기준선·업데이트 분류 |
| Stage 2 | `1453a65` | 최대 64건 FIFO outbox, UTC 30일·6일 보존과 응답별 처리 |
| Stage 3 | `05dd017` | 공개 HTTPS endpoint, 일회성 연결 확인, 5초 ephemeral transport와 앱 실행당 한 번의 비차단 flush |
| Stage 4 | `de5bec8` | Sparkle pending 전환 확인, 즉시 opt-out, 개인정보 설정 화면 |
| Stage 5 | `12e816a` | 오프라인→연결 복구 통합 테스트, 개인정보 계약, clean 통합 검증과 격리 UI smoke |

## 수집 이벤트와 분류

공개 JSON payload는 다음 여섯 key만 사용한다.

| key | 의미 |
|-----|------|
| `event_id` | 이벤트별 UUID v4. 재전송 중복 제거에만 사용하고 다른 이벤트에 재사용하지 않음 |
| `event_type` | `first_launch`, `existing_baseline`, `update` |
| `occurred_date` | 이벤트가 실제 발생한 UTC 날짜 `YYYY-MM-DD` |
| `from_version` | 업데이트 이전 semantic version, 그 외 `null` |
| `to_version` | 현재 또는 대상 semantic version |
| `update_channel` | 확인된 `sparkle` 또는 `unknown`; 계약상 `direct_dmg`, `homebrew` 허용 |

최초 관측은 분석 상태를 쓰기 전에 앱 소유 allowlist 증거만 확인한다. 기존 launch maintenance, 최근 문서 또는 Quick Look 안내 상태가 있으면 `existing_baseline`, 없으면 `first_launch`로 분류한다. 문서 경로·내용과 Sparkle 또는 macOS 소유 defaults는 판별 증거로 사용하지 않는다.

동일 version 재실행은 새 이벤트를 만들지 않는다. version이 바뀌고 Sparkle pending의 이전·대상 version이 실제 전환과 모두 일치하면 `update(..., channel=sparkle)`, 그렇지 않으면 `update(..., channel=unknown)`으로 기록한다. Sparkle 설치 취소·실패 또는 target mismatch를 Sparkle 성공으로 기록하지 않는다.

## 오프라인·전송 계약

| 상태 | 동작 |
|------|------|
| 연결 불가 | 요청 0건, 최초 전송 시각 미기록, 앱과 문서 기능 계속 실행 |
| 최초 요청 전 | 발생일 day 0~30 보관, day 31 시작에 폐기 |
| 최초 요청 후 | 최초 시도일 day 0~6 재시도, day 7 시작에 폐기 |
| HTTP `202` | outbox 제거와 마지막 수락 version 기록 |
| HTTP `429`, `500...599` | 재시도 기간 안에서 보관 |
| 네트워크 오류·timeout | 재시도 기간 안에서 보관 |
| 그 외 `400...499` | 잘못된 payload로 보고 제거 |
| 예상하지 못한 결과 | 보수적으로 보관 |

outbox는 최대 64건 FIFO이며 만료 항목을 먼저 제거한다. 앱 실행마다 snapshot을 한 번만 처리하고 같은 pass에서 같은 이벤트를 반복 요청하지 않는다. 연결 확인은 첫 결과 뒤 종료하며 상주 monitor, retry timer, background daemon을 만들지 않는다. URLSession은 ephemeral이고 request·resource timeout은 각각 5초다.

오프라인 이벤트가 연결 복구 뒤 전송돼도 `occurred_date`와 `event_id`는 원래 값을 유지한다. 따라서 서버 수신일이 아니라 실제 발생일 기준 집계가 가능하다.

## Sparkle과 사용자 선택

`SPUUpdaterDelegate.updater(_:willInstallUpdate:)`는 이전·대상 version과 `sparkle` 예정 상태만 로컬에 기록한다. callback에서 분석 HTTP 요청, outbox flush 또는 앱 종료 대기를 수행하지 않는다. 다음 실행의 실제 version이 target과 일치해야만 업데이트 이벤트를 확정한다.

기존 appcast URL, EdDSA public key, 자동 업데이트 확인 흐름은 유지했다. `SUEnableSystemProfiling`, `SUSendProfileInfo` 또는 별도 분석 feed parameter는 추가하지 않았다.

macOS 설정의 개인정보 화면에서 사용자는 수집 범위와 한계를 확인하고 `익명 사용 추이 공유`를 끌 수 있다. 비활성화하면 outbox와 Sparkle pending을 즉시 지우고 진행 중인 flush를 취소한다. 비활성 기간의 현재 version 기준선만 유지하므로 재활성화 뒤 과거 전환을 소급 생성하지 않는다.

## 개인정보 경계

다음 정보는 payload, endpoint query·header, 분석 로그와 로컬 분석 상태에 저장하지 않는다.

- 문서 내용, 파일명, 파일 경로, 최근 문서 목록
- 계정, 이메일, 영구 사용자·기기·설치 식별자
- 앱이 별도 필드로 수집한 IP 주소
- 하드웨어, macOS 또는 Sparkle System Profile
- 집계 조회 token, API key, account ID, 운영 secret

로컬에는 공개 payload 외에 마지막 관측·수락 version, Sparkle pending version·시각, outbox 생성·최초 시도 시각만 저장한다. production 분석 경로에는 event ID, payload 또는 outbox 내용을 남기는 logger가 없다.

상세 계약은 `mydocs/tech/task_m040_453_app_execution_analytics_contract.md`를 진실 원천으로 사용한다.

## 검증 결과

최종 검증은 새 `build.noindex/Task453Stage5DerivedData`에서 수행했다.

| 검증 | 결과 |
|------|------|
| `xcodegen generate` | 통과 |
| 전체 HostAppTests | 75개 통과, 실패·건너뜀 0 |
| HostApp Debug clean build | 통과 |
| 오프라인 → 연결 복구 통합 테스트 | 원래 event ID와 `occurred_date` 유지, `202` 뒤 제거 확인 |
| 보존·retry·응답·64건 FIFO·opt-out 정책 | 전체 단위·통합 테스트 통과 |
| payload allowlist | CodingKeys와 실제 JSON 모두 여섯 key만 확인 |
| app bundle 분석 credential | 공개 endpoint 외 secret 없음 |
| Sparkle System Profiling | 관련 source·bundle key 없음 |
| production payload logging | `Logger`·`os_log`·`print` 없음 |
| Sparkle/분석 결합도 | updater delegate에 transport·endpoint·연결 확인 의존 없음 |
| `./scripts/check-no-appkit.sh` | 통과 |
| `git diff --check` | 통과 |

실제 운영 집계를 오염시키지 않도록 공개 Worker를 호출하지 않았다. 일회용 Debug app의 endpoint를 제거하고 bundle ID를 `com.postmelee.alhangeul.Stage5Smoke`로 분리한 뒤 다음 UI smoke를 수행했다.

- 앱과 기존 Sparkle 초기화 완료
- `samples/basic/KTX.hwp` 1페이지 로드
- 개인정보 설명과 기본 활성 상태 표시
- 익명 사용 추이 opt-out 즉시 반영
- 설정을 닫은 뒤 문서 유지와 정상 종료

샘플 문서는 저장하지 않았고 원본을 수정하지 않았다. 테스트 전용 defaults, extension 등록 흔적과 Debug app 산출물은 검증 뒤 정리했다.

## 주요 변경 파일

| 경로 | 역할 |
|------|------|
| `Sources/HostApp/Services/AppExecutionEvent.swift` | 공개 이벤트·version·UTC 날짜 모델 |
| `Sources/HostApp/Services/AppExecutionAnalyticsState.swift` | versioned 상태, 실행 분류, Sparkle pending과 opt-out |
| `Sources/HostApp/Services/AppExecutionOutbox.swift` | FIFO·보존·재시도·응답 정책 |
| `Sources/HostApp/Services/AppExecutionAnalyticsRuntime.swift` | endpoint, 연결 확인, ephemeral transport와 coordinator |
| `Sources/HostApp/Services/UpdateController.swift` | Sparkle 예정 전환 delegate 연결 |
| `Sources/HostApp/Views/AppExecutionAnalyticsSettingsView.swift` | 개인정보 안내와 opt-out UI |
| `Tests/HostAppTests/AppExecution*Tests.swift` | 이벤트·상태·outbox·runtime 정책 검증 |
| `mydocs/tech/task_m040_453_app_execution_analytics_contract.md` | 지표 해석과 개인정보·오프라인 운영 계약 |

## 지표 해석과 알려진 제한

- 결과는 네트워크 연결 환경에서 수집 서버에 도달한 익명 실행 이벤트다.
- 전체 설치 수, 고유 사용자 수, 고유 기기 수 또는 활성 사용자 수가 아니다.
- 영구 식별자가 없으므로 서로 다른 이벤트가 같은 설치에서 발생했는지 연결할 수 없다.
- 영구 폐쇄망과 보관기간 내 재연결되지 않은 실행은 관측되지 않는다.
- 기능 도입 이전 설치본은 앱 소유 로컬 증거가 없거나 삭제됐다면 `first_launch`로 관측될 수 있다.
- `direct_dmg`와 `homebrew`는 현재 앱에서 확정적으로 판별하지 않으므로 Sparkle 밖 전환은 `unknown`이다.
- 실제 Worker 운영 smoke와 public release는 이 타스크에서 수행하지 않았다.

이 제한은 알한글의 로컬·오프라인 동작과 개인정보 최소화 원칙을 지키기 위한 의도된 경계다. 대시보드와 운영 문서는 항상 값을 `관측된 익명 이벤트`로 표현해야 한다.

## 최종 결론

Task #453의 계획된 Stage 1~5 구현과 검증을 완료했다. 알한글은 앱 기능과 Sparkle 업데이트를 분석 I/O의 성공 조건으로 사용하지 않으며, 오프라인에서는 요청 없이 동작하고 제한된 outbox 계약 안에서만 익명 이벤트를 재시도한다.

신규 실행·기존 설치 기준선·실제 version 전환을 구분할 수 있고, Sparkle 성공은 다음 실행의 bundle version으로 확인한다. payload는 여섯 개의 최소 필드로 제한되며 문서·계정·영구 식별자·System Profile·운영 secret을 포함하지 않는다.

PR merge 시 Issue #453의 구현 목표가 완료된다. merge 전에는 이슈를 열린 상태로 유지하고, merge 확인 뒤 `pr-merge-cleanup` 절차로 이슈·게시 브랜치·로컬 작업 브랜치를 정리한다.
