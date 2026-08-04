# Task M040 #453 Stage 4 완료보고서

## 단계 목적

Sparkle 설치 직전에는 예정 전환만 기록하고 다음 실행의 실제 bundle version으로 성공을 확정하며, 사용자가 수집 범위와 한계를 확인하고 익명 이벤트 수집을 즉시 비활성화할 수 있게 한다.

## 구현 결과

### Sparkle pending 전환 기록

로컬에 고정된 Sparkle 2.9.1 `SPUUpdaterDelegate`의 `updater(_:willInstallUpdate:)` API를 확인해 `AppExecutionSparkleUpdaterDelegate`를 추가했다.

- `UpdateController`가 delegate helper를 강한 stored property로 보유
- 같은 helper를 `SPUStandardUpdaterController`의 `updaterDelegate`로 전달
- callback에서 현재 `CFBundleShortVersionString`과 `SUAppcastItem.displayVersionString`만 observer에 전달
- 두 version이 유효하고 서로 다를 때만 pending 저장
- callback에서는 outbox event 생성, HTTP 요청, flush, 종료 대기를 수행하지 않음

`AppExecutionSparkleUpdateObserver`는 기록 시각을 주입 가능하게 하고, 설정이 활성화된 경우에만 pending을 versioned state에 저장한다. preference 확인과 state 저장은 같은 lock 안에서 수행해 opt-out과 callback이 겹쳐도 비활성화 뒤 pending이 다시 생기지 않는다.

다음 실행의 기존 Stage 1 정책은 다음처럼 pending을 확정한다.

- 현재 version이 pending target과 일치하고 이전 version과 다름 → `update`, channel `sparkle`
- 설치 취소·실패로 version 동일 → update 없음, pending 제거
- target mismatch → Sparkle 성공으로 쓰지 않고 실제 version 차이만 `unknown`, pending 제거

기존 appcast URL, EdDSA public key, 자동 확인과 background check 흐름은 변경하지 않았다.

### 즉시 opt-out과 기준선 유지

`AppExecutionAnalyticsStateStore.setEnabled(false)`를 원자적 정리 연산으로 확장했다.

- 설정 값을 false로 저장
- outbox 즉시 제거
- Sparkle pending 즉시 제거
- `lastObservedVersion`과 `lastAcceptedVersion` 유지

비활성화된 상태에서도 이벤트를 만들지 않은 채 현재 bundle version을 `lastObservedVersion`에 기록한다. 따라서 비활성 기간에 앱이 업데이트된 뒤 다시 활성화해도 과거 전환을 소급 생성하지 않는다. 재활성화 이후 다음 실제 version 전환부터 새 이벤트를 만든다.

coordinator는 시작한 flush `Task`를 보관한다. 설정을 끄면 state 정리 뒤 task를 cancel하고, 연결 확인 뒤와 각 outbox 요청 직전에 cancellation·활성 상태를 다시 확인한다. 연결 확인 중 opt-out되는 경우 transport 요청은 0건이다. 이미 completion이 도착한 요청과 state 정리가 겹쳐도 event ID가 outbox에 없으므로 상태를 복원하지 않는다.

### SwiftUI 설정 화면

macOS `Settings` scene과 `AppExecutionAnalyticsSettingsView`를 추가했다. 알한글 메뉴의 `설정…`에서 다음 내용을 확인할 수 있다.

- 익명 사용 추이 공유 토글
- 수집 항목: 발생 날짜, 이전·현재 version, 확인 가능한 업데이트 경로
- 문서 내용·파일명·경로, 계정, 기기·사용자 식별자를 수집하지 않는다는 안내
- 네트워크에 도달한 익명 이벤트이며 전체 설치 수나 고유 사용자 수가 아니라는 한계
- 오프라인 최대 30일 보관, 최초 전송 시도 후 최대 6일 재시도
- 끄면 보관 이벤트가 즉시 삭제되고 이후 전송이 중단된다는 효과

설정은 미지정 시 기본 활성화되고 `UserDefaults`에 지속된다.

## 테스트

Stage 4에서 5개 정책 테스트를 추가하고 기존 Sparkle 전환 테스트를 함께 유지했다.

1. opt-out 즉시 outbox·pending 제거와 관측 version 유지
2. 비활성 기간 version 전진 후 재활성화 시 과거 전환 미생성
3. 유효한 Sparkle 예정 전환은 pending만 저장하고 event는 만들지 않음
4. 동일·잘못된 version 또는 비활성 상태의 Sparkle 전환 무시
5. 연결 확인 중 opt-out 시 flush 취소와 transport 0건

기존 테스트가 다음 실행 target 일치·취소·불일치 처리를 계속 검증한다.

## 검증 결과

| 검증 | 결과 | 비고 |
|------|------|------|
| `xcodegen generate` | 통과 | Settings view project membership 반영 |
| HostAppTests | 통과 | 전체 74개, 실패 0; Stage 4 신규 5개 포함 |
| HostApp Debug build | 통과 | Sparkle 2.9.1 delegate signature와 Settings scene compile/link 성공 |
| Debug 설정 화면 smoke | 통과 | 개인정보 설명과 기본 활성 토글 표시 확인 |
| opt-out 수동 smoke | 통과 | 토글 즉시 꺼짐, 앱 재실행 뒤 꺼짐 지속 |
| Sparkle delegate lifetime 정적 검사 | 통과 | strong property와 updater delegate 주입 확인 |
| Sparkle profile 수집 정적 검사 | 통과 | `SUEnableSystemProfiling`·`SUSendProfileInfo`·`sendsSystemProfile` 없음 |
| callback·설정 network 정적 검사 | 통과 | URLSession·NWPathMonitor·endpoint 참조 없음 |
| `./scripts/check-no-appkit.sh` | 통과 | shared/CoreBridge 경계 변경 없음 |
| `git diff --check` | 통과 | whitespace 오류 없음 |

수동 smoke는 운영 데이터와 기존 사용자 설정을 분리하기 위해 Debug app bundle ID를 `com.postmelee.alhangeul.Stage4Smoke`로 바꾸고 endpoint를 제거한 일회용 산출물에서 수행했다. 확인 후 전용 defaults를 삭제하고 표준 extension registration hygiene helper와 `xcodebuild clean`으로 산출물을 정리했다.

## Stage 4 범위 밖 작업

- 전체 상태 조합과 장기 오프라인 경계의 최종 회귀 검증
- payload·bundle secret·로그·대시보드 해석 문구의 최종 개인정보 감사
- 최종 운영·릴리스 문서 갱신
- Task #453 최종 보고서와 PR 게시

## 승인 요청

Stage 4의 Sparkle 전환 확인·즉시 opt-out·설정 화면과 검증 결과를 승인하고, Stage 5 `오프라인 통합 검증과 개인정보 경계 확정` 진입을 요청한다.
