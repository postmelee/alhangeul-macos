# Task M040 #453 Stage 5 완료보고서

## 단계 목적

전체 단위·통합 테스트, clean build, 오프라인 UI smoke와 정적 감사를 수행해 알한글의 로컬 문서 기능이 분석 네트워크와 독립적이고, 공개 수집 계약이 익명 이벤트의 최소 정보만 다루는지 최종 확인한다.

## 구현 결과

### 오프라인에서 연결 복구까지의 실제 발생일 보존

`AppExecutionAnalyticsRuntimeTests`에 오프라인 실행 뒤 다음 실행에서 연결이 복구되는 통합 시나리오를 추가했다.

1. `occurred_date`가 `2026-08-04`인 이벤트를 outbox에 저장
2. 연결 불가 상태에서 transport 요청 0건, `firstAttemptedAt` 미기록, outbox 유지 확인
3. 다음 process coordinator에서 연결 가능 상태와 HTTP `202` 응답 재현
4. 최초 이벤트 ID와 `occurred_date`가 변경되지 않은 채 전송되고 outbox에서 제거되는지 확인

테스트 transport가 전송한 전체 `AppExecutionEvent`를 기록하도록 확장해 이벤트 ID뿐 아니라 실제 전송 날짜도 검증한다. 기존 테스트는 retry 응답, 최초 시도 전 30일 보관, 최초 시도 뒤 6일 재시도, 4xx 폐기, 429·5xx·네트워크 오류 유지, 최대 64건 FIFO, opt-out 즉시 정리를 계속 검증한다.

### 수집·개인정보 계약 문서화

`mydocs/tech/task_m040_453_app_execution_analytics_contract.md`를 추가하고 다음 항목을 영구 기술 계약으로 확정했다.

- 지표는 전체 설치·고유 사용자·고유 기기가 아닌 수집 서버에 도달한 익명 실행 이벤트
- 공개 payload는 `event_id`, `event_type`, `occurred_date`, `from_version`, `to_version`, `update_channel` 여섯 key만 허용
- 문서 내용·파일명·경로, 계정, 사용자·기기·설치 식별자, System Profile, 운영 secret 금지
- 최초 요청 전 최대 30일, 최초 시도 뒤 최대 6일, 최대 64건 FIFO outbox
- 연결 복구 뒤에도 실제 발생일 `occurred_date` 유지
- Sparkle callback은 pending만 기록하고 다음 실행의 실제 bundle version으로 성공 확정
- opt-out 시 outbox·pending 제거, flush 취소, 과거 전환 비소급
- 공개 Worker 직접 smoke는 별도 승인과 테스트 이벤트 처리 정책 없이는 금지

프로젝트 아키텍처의 런타임 데이터 흐름에서 이 계약 문서와 `AppExecution*` 소유 경계를 연결했다.

## 통합·정적 검증 결과

검증은 새 경로 `build.noindex/Task453Stage5DerivedData`에서 수행했다.

| 검증 | 결과 | 비고 |
|------|------|------|
| `xcodegen generate` | 통과 | project 생성 정상 |
| 전체 HostAppTests | 통과 | 75개 통과, 실패·건너뜀 0 |
| HostApp Debug build | 통과 | clean DerivedData에서 compile·link 성공 |
| 오프라인 → 연결 복구 통합 테스트 | 통과 | 요청 전 outbox 유지, 복구 뒤 원래 ID·`occurred_date`로 `202` 처리 |
| payload allowlist 검사 | 통과 | CodingKeys 여섯 개와 transport JSON key 일치 |
| built app 공개 endpoint 검사 | 통과 | 공개 HTTPS endpoint만 존재 |
| built app secret 검사 | 통과 | Authorization·Bearer·API key·account ID·secret·token 없음 |
| Sparkle 설정 검사 | 통과 | 기존 appcast URL·EdDSA public key 유지, System Profiling key 없음 |
| production analytics logging 검사 | 통과 | `Logger`·`os_log`·`print`로 payload·ID·outbox를 기록하지 않음 |
| Sparkle/분석 결합도 검사 | 통과 | updater delegate는 pending observer만 호출하고 transport·endpoint·연결 확인을 참조하지 않음 |
| `./scripts/check-no-appkit.sh` | 통과 | `Sources/RhwpCoreBridge` 경계 유지 |
| `git diff --check` | 통과 | whitespace 오류 없음 |

테스트 결과 bundle은 다음 xcresult에 기록됐다.

`build.noindex/Task453Stage5DerivedData/Logs/Test/Test-HostAppTests-2026.08.04_13-20-16-+0900.xcresult`

## 운영 수집기를 호출하지 않은 UI smoke

실제 운영 집계를 오염시키지 않도록 일회용 Debug app 산출물에서만 수집 endpoint를 제거하고 bundle ID를 `com.postmelee.alhangeul.Stage5Smoke`로 분리했다. 소스 `Info.plist`는 변경하지 않았다.

격리된 앱에서 다음을 확인했다.

1. 분석 endpoint 없이 앱 실행과 기존 Sparkle 초기화가 완료됨
2. `samples/basic/KTX.hwp`를 열어 1페이지 렌더링과 문서 상태 표시 확인
3. 설정의 개인정보 설명과 기본 활성 상태 확인
4. `익명 사용 추이 공유`를 끄면 토글 값이 즉시 비활성 상태로 변경됨
5. 설정을 닫은 뒤 문서가 계속 표시되고 앱이 정상 종료됨

샘플 문서는 저장하지 않았고 원본을 수정하지 않았다. smoke 뒤 테스트 전용 defaults를 삭제하고 extension registration hygiene helper를 실행했으며, `xcodebuild clean`으로 Debug app 산출물을 제거했다. 공개 Worker에는 요청하지 않았다.

## 해석 한계

- 영구 사용자·기기·설치 식별자가 없으므로 이벤트 사이의 동일 설치 여부를 연결할 수 없다.
- 영구 폐쇄망과 보관기간 내 재연결되지 않은 실행은 관측되지 않는다.
- 기능 도입 전 설치본은 기존 로컬 증거가 없으면 `first_launch`로 관측될 수 있다.
- 따라서 대시보드 값은 설치 수, 고유 사용자 수, 활성 사용자 수가 아니라 관측된 익명 이벤트 건수로만 해석한다.

## Stage 5 이후 남은 절차

- Task #453 최종 결과보고서 작성
- 오늘할일 완료 처리
- 최종 보고서 커밋
- `publish/task453` 게시 브랜치 준비와 원격 push
- `devel` 대상 PR 생성

## 승인 요청

Stage 5의 오프라인 통합 검증·개인정보 경계 확정과 결과를 승인하고, Task #453 최종 결과보고서 작성 및 PR 게시 단계 진행을 요청한다.
