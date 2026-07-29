# Task M040 #433 Stage 3 완료보고서

## 단계 목적

사용자가 About 화면을 찾아 스크롤하지 않아도 검증된 HOP Quick Look 충돌 가능성을 앱 실행 시 확인하게 하고, 같은 설치·버전 조합에서는 안내를 반복하지 않는다. 후속 작업지시를 반영해 About을 `정보`와 `Quick Look` 탭으로 분리하고 팝업의 상세 경로를 Quick Look 탭에 직접 연결한다.

## 구현 결과

### 실행 시 충돌 안내

`AppDelegate.applicationDidFinishLaunching`에서 `QuickLookConflictNoticeCoordinator`를 한 번 시작한다. coordinator는 HOP과 알한글 bundle metadata를 백그라운드에서 읽고 다음 조건을 모두 만족할 때만 실행 안내를 표시한다.

- HOP app과 Preview가 감지됨
- HOP Preview version이 검증 catalog에 있음
- HOP과 알한글의 `rhwp` version을 숫자 version으로 비교할 수 있음
- 알한글 `rhwp`가 HOP `rhwp`보다 높음
- 현재 fingerprint가 이전에 dismissal한 fingerprint와 다름

현재 실제 설치 환경에서는 HOP Preview `0.2.0` / `rhwp v0.7.13`과 알한글 `rhwp v0.7.18 (93862a4)`가 확인돼 팝업 대상이 된다. 알 수 없는 HOP version이나 단순 중복 provider 가능성만 있는 경우에는 자동 팝업을 표시하지 않고 About에서만 정보를 제공한다.

### 팝업 구성과 동작

`QuickLookConflictNoticePresenter`와 `QuickLookConflictNoticeView`를 추가했다. 팝업은 다음 정보를 첫 화면에 스크롤 없이 표시한다.

- `Quick Look 미리보기 충돌 가능성` 제목
- 같은 HWP/HWPX 형식을 지원하는 두 확장 간 선택 가능성
- 알한글의 더 최신 `rhwp` 사용 권장 문구
- `확장 프로그램` 섹션에서 HOP 훑어보기를 끄고 알한글 훑어보기를 켜는 구체적 행동
- 알한글 `rhwp v0.7.18 (93862a4)`와 HOP `rhwp v0.7.13` 비교
- 알한글은 설정 화면만 열고 확장 활성 상태는 사용자가 직접 변경해야 한다는 제한

버튼 동작은 다음과 같다.

| 동작 | 결과 |
|------|------|
| `확장 프로그램 설정 열기` | dismissal을 기록하거나 팝업을 닫지 않고 시스템 설정의 확장 프로그램 화면을 연다. |
| `자세히 보기` | 현재 fingerprint를 기록하고 About의 `Quick Look` 탭을 연다. |
| `나중에` | 현재 fingerprint를 기록하고 팝업을 닫는다. |
| 창 닫기 | `나중에`와 같은 dismissal로 처리한다. |

presenter는 동시에 하나의 notice window만 소유하며 coordinator도 앱 수명주기 동안 한 번만 시작한다. `확장 프로그램 설정 열기`는 비종료 action으로 전달해 설정 화면이 앞에 열린 뒤에도 기존 팝업과 callback을 유지한다. 문서 창이 추가되거나 앱이 다시 활성화돼도 안내 창을 중복 생성하지 않는다.

### fingerprint 재표시 정책

`QuickLookConflictNoticePolicy`와 `QuickLookConflictDismissalStore`를 추가했다.

- UserDefaults key: `alhangeul.quickLookConflict.dismissedFingerprint.v1`
- 같은 fingerprint를 dismissal한 경우 다음 실행에서 자동 안내 생략
- HOP app/Preview version, 검증된 HOP `rhwp`, 알한글 app/Preview version 또는 `rhwp` provenance가 바뀌면 Stage 1 fingerprint가 달라져 다시 안내
- HOP 미설치, 알 수 없는 비교 결과, fingerprint 없음에서는 자동 안내 생략

테스트는 UUID 기반 격리 suite를 사용해 사용자의 실제 기본값을 변경하지 않는다.

### About 탭 분리

기존 About의 긴 단일 ScrollView를 상단 segmented tab 구조로 바꿨다.

| 탭 | 내용 |
|----|------|
| `정보` | 앱 아이콘, 앱 version/build, bundled `rhwp` version |
| `Quick Look` | Preview·Thumbnail 등록 상태, 충돌 안내와 버전 비교, 설정/다시 확인 |

탭 선택 control은 창 상단에 고정돼 내용 스크롤과 관계없이 항상 보인다. 작업지시자의 실제 화면 검토를 반영해 Quick Look 탭에서는 높이가 작은 알한글 확장 등록 상태를 먼저 표시하고 충돌 안내를 바로 아래에 배치했다. 초기 화면에서 확장 상태와 경고 카드 시작을 함께 발견할 수 있고, 상세 경고는 이어서 스크롤해 확인한다.

About 메뉴로 직접 열면 `정보` 탭을 기본으로 한다. 팝업의 `자세히 보기`는 동일한 About 창을 재사용하면서 `Quick Look` 탭을 직접 선택한다. dismissal 이후에도 About의 Quick Look 탭은 항상 현재 설치 상태를 다시 감지해 보여준다.

## 검증 결과

| 검증 | 결과 | 비고 |
|------|------|------|
| `xcodegen generate` | 통과 | 새 production/test source membership 반영 |
| `HostAppTests` | 통과 | 총 25개 테스트, 실패 0 |
| HostApp Debug build | 통과 | app, Preview, Thumbnail과 Stage 3 source compile/link 성공 |
| 첫 실행 팝업 | 통과 | 실제 HOP `0.3.1` / Preview `0.2.0` 환경에서 전면 노출 |
| 팝업 화면 구성 | 통과 | 확장 프로그램 섹션의 조작 단계, 양쪽 `rhwp`, 세 버튼이 스크롤 없이 표시됨 |
| 설정 진입 중 팝업 유지 | 통과 | 시스템 설정이 앞에 열린 뒤에도 안내 팝업이 닫히지 않고 남음 |
| `자세히 보기` | 통과 | About의 `Quick Look` 탭이 선택된 상태로 열림 |
| Quick Look 섹션 순서 | 통과 | 확장 상태 뒤에 경고 카드를 배치해 초기 화면에서 두 섹션의 시작이 함께 보임 |
| 같은 fingerprint 재실행 | 통과 | dismissal 저장 뒤 팝업이 다시 표시되지 않음 |
| 수동 About 진입 | 통과 | `정보` 탭 기본 선택 및 `Quick Look` 탭 수동 전환 확인 |
| dismissal 테스트 값 정리 | 통과 | 실제 UserDefaults key를 검증 후 삭제해 미설정 상태 복구 |
| `./scripts/check-no-appkit.sh` | 통과 | shared/CoreBridge 경계에 AppKit/UIKit 추가 없음 |
| 금지 런타임 경로 검색 | 통과 | 새 Stage 3 코드에 `pluginkit`, 비공개 PlugInKit, `qlmanage`, process/binary scan 없음 |
| `git diff --check` | 통과 | whitespace 오류 없음 |

정책 단위 테스트 8개를 추가해 다음을 검증했다.

1. 알려진 알한글 우위에서 최초 표시
2. 같은 dismissal fingerprint 재표시 방지
3. 변경된 fingerprint 재표시
4. 알 수 없는 비교 결과 자동 안내 생략
5. 충돌 없음 자동 안내 생략
6. 격리된 UserDefaults fingerprint 저장·조회
7. 설정 열기 action은 팝업을 완료하지 않음
8. 나중에·자세히 보기 action은 팝업을 완료함

실제 UI 검증에는 Computer Use 접근성 트리와 화면 캡처를 함께 사용했다. 팝업의 제목, 설명, 두 `rhwp` 값, 세 버튼이 VoiceOver tree에 포함되고 다크 모드에서 잘림 없이 보이는 것을 확인했다. 후속 화면 검토에서는 `확장 프로그램 설정 열기` 버튼을 누른 뒤 HOP 훑어보기를 끄고 알한글 훑어보기를 켜라는 행동 안내와 수동 변경 책임 문구가 모두 잘림 없이 노출되는 것을 확인했다. 시스템 설정의 `로그인 항목 및 확장 프로그램` 화면이 앞에 열린 뒤에도 안내 팝업이 유지되고 dismissal key가 생성되지 않는 것을 확인했다. `자세히 보기` 이후 `Quick Look` tab value가 선택되고, 확장 상태와 충돌 카드 제목이 초기 화면에 함께 노출되는 것도 확인했다.

## 개발 산출물 등록 정리

실제 UI 검증 후 Debug 앱을 종료하고 표준 hygiene helper를 두 번 실행했으며 Task #433 Stage 3 DerivedData를 삭제했다.

- `scripts/check-extension-registration-hygiene.sh --cleanup-dev-registrations`
- `build.noindex/DerivedDataTask433Stage3` 삭제
- `build.noindex/DerivedDataTask433Stage3Host` 삭제
- 최종 PlugInKit Preview provider: `/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulPreview.appex`
- 최종 PlugInKit Thumbnail provider: `/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulThumbnail.appex`

활성 PlugInKit provider는 설치본 하나씩만 남았다. LaunchServices app 목록에는 삭제된 Stage 1~3와 화면 캡처용 Debug app 경로가 stale record로 계속 출력됐다. 해당 파일과 PlugInKit provider는 남아 있지 않으며 다른 앱 등록에 영향을 줄 수 있는 전역 LaunchServices reset은 수행하지 않았다.

## 남은 위험과 다음 단계 경계

- dismissal은 설치된 확장의 실제 활성 상태가 아니라 감지 가능한 metadata fingerprint를 기준으로 한다.
- 사용자가 시스템 설정에서 HOP을 꺼도 공개 API로 활성 상태를 확인할 수 없으므로 About의 충돌 가능성 정보는 계속 보일 수 있다.
- 알 수 없는 HOP version은 자동 팝업 대상이 아니므로 About Quick Look 탭에서만 일반 중복 안내를 확인할 수 있다.
- Stage 3 검증은 현재 실제 설치 조합과 synthetic policy fixture를 사용했다. Stage 4에서 생성 프로젝트, 전체 정책 테스트, 실행 UI, 설정 진입과 금지 런타임 경로를 한 번 더 통합 검증한다.
- LaunchServices stale app record는 전역 초기화 없이 남아 있으나 실제 Quick Look provider 선택에는 참여하지 않는다.

## 승인 요청

Stage 3의 실행 팝업, fingerprint 재표시 정책, About 탭 분리와 `자세히 보기` 연결 결과를 승인하고, Stage 4 `통합 빌드와 사용자 시나리오 검증` 진입을 요청한다.
