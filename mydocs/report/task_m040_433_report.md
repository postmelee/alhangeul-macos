# Task M040 #433 최종 결과보고서

## 작업 결론

`issue1949_giant_cell_nested_tables_perf.hwpx`의 2페이지에서 보인 큰 공백은 알한글에 포함된 최신 `rhwp` 자체의 재설치나 preview cache 갱신만으로 설명되는 문제가 아니었다. 시스템에 HOP과 알한글 Quick Look Preview가 함께 설치돼 있고, macOS가 HOP Preview를 선택하면 HOP `rhwp v0.7.13` 기준 결과가 표시될 수 있다. 현재 알한글은 `rhwp v0.7.18 (93862a4)`를 포함하므로, 검증된 설치 조합에서는 HOP 훑어보기를 끄고 알한글 훑어보기를 켜도록 안내하는 것이 맞다.

Task #433은 macOS의 provider 우선순위를 강제하지 않고, 공개 API와 bundle metadata로 이 가능성을 감지해 사용자에게 근거와 해결 경로를 제공하도록 구현했다.

## 단계별 결과

| 단계 | 결과 |
|------|------|
| Stage 1 | HOP 설치·Preview metadata 감지, 검증된 `rhwp` catalog, semantic version 비교와 fingerprint 모델 |
| Stage 2 | About의 충돌 가능성·버전 비교 UI, 시스템 설정 진입과 fallback |
| Stage 3 | 실행 시 안내 팝업, dismissal·재표시 정책, About 탭 분리와 행동 중심 문구 |
| Stage 3.1~3.3 | Quick Look 섹션 순서, 구체적 설정 안내, 설정 진입 중 팝업 유지 |
| Stage 4 | 생성 프로젝트, 25개 정책 테스트, 통합 build, 실제 사용자 시나리오와 환경 정리 |

## 최종 사용자 경험

알한글 실행 시 다음 조건이 모두 맞으면 안내 팝업을 표시한다.

1. HOP 앱과 Quick Look Preview가 감지된다.
2. HOP Preview version이 검증 catalog에 있다.
3. 양쪽 `rhwp`를 숫자 version으로 비교할 수 있다.
4. 알한글 `rhwp`가 HOP보다 높다.
5. 현재 전체 metadata fingerprint가 아직 dismissal되지 않았다.

팝업은 다음 정보를 제공한다.

- HOP과 알한글이 같은 HWP/HWPX 형식을 지원해 예상과 다른 provider가 선택될 수 있다는 설명
- 알한글 `rhwp v0.7.18 (93862a4)`와 HOP `rhwp v0.7.13` 비교
- `확장 프로그램 설정 열기` 뒤 HOP 훑어보기를 끄고 알한글 훑어보기를 켜라는 행동 안내
- 알한글은 설정 화면만 열며 사용자가 직접 활성 상태를 바꿔야 한다는 책임 경계

`확장 프로그램 설정 열기`는 팝업을 닫거나 dismissal을 저장하지 않는다. 사용자는 안내를 유지한 채 시스템 설정을 확인할 수 있다. `나중에`, `자세히 보기`, 창 닫기에서만 현재 fingerprint를 저장하며 같은 환경에서는 다음 실행 안내를 생략한다. HOP/알한글 app·Preview·`rhwp` provenance가 바뀌면 fingerprint가 달라져 다시 안내한다.

## 감지와 비교 근거

| 데이터 | 출처 |
|--------|------|
| HOP 설치 후보 | `NSWorkspace.shared.urlsForApplications(withBundleIdentifier:)` |
| HOP 앱·Preview version | `/Applications/HOP.app`과 bundled appex metadata |
| HOP `rhwp` | 검증된 Preview version catalog |
| 알한글 앱·Preview version | 실행 bundle metadata |
| 알한글 `rhwp` | bundled `RhwpProvenance`, `rhwp-core.lock` |

현재 검증 catalog는 HOP Preview `0.2.0 -> rhwp v0.7.13`만 포함한다. 알 수 없는 HOP version이나 metadata 누락에서는 더 최신이라는 주장을 하지 않고 제한된 중복 가능성만 About에 표시한다.

## 실제 설치 환경 확인값

| 구분 | 알한글 | HOP |
|------|--------|-----|
| 앱 | `0.1.8 (14)` | `0.3.1 (0.3.1)` |
| Preview | `0.1.8 (14)` | `0.2.0 (1)` |
| `rhwp` | `v0.7.18 (93862a4)` | `v0.7.13` |

## 검증 결과

| 검증 | 결과 |
|------|------|
| `xcodegen generate` 정합성 | 통과 |
| HostAppTests | 25개 통과, 실패 0 |
| HostApp·Preview·Thumbnail Debug build | 통과 |
| bundled studio asset | 통과 |
| `RhwpCoreBridge` AppKit/UIKit 경계 | 통과 |
| 금지 CLI·비공개 election 실행 경로 | 없음 |
| 첫 실행·설정 진입·About·재실행 시나리오 | 통과 |
| 다른 확장 토글 자동 변경 | 수행하지 않음 |
| Task #433 개발 등록·DerivedData·dismissal 정리 | 완료 |

통합 로그에는 macOS의 `com.apple.pluginkit.pkd` 시스템 XPC 연결만 관찰됐다. 제품 코드에는 `Process`, `NSTask`, `pluginkit` CLI, `qlmanage` 실행 또는 비공개 PlugInKit election API가 없다.

## 주요 변경 파일

- `Sources/HostApp/Services/QuickLookConflictDetector.swift`
- `Sources/HostApp/Services/QuickLookConflictPresentation.swift`
- `Sources/HostApp/Services/QuickLookConflictNoticePolicy.swift`
- `Sources/HostApp/Services/QuickLookConflictNoticeCoordinator.swift`
- `Sources/HostApp/Services/QuickLookConflictNoticePresenter.swift`
- `Sources/HostApp/Services/QuickLookSettingsOpener.swift`
- `Sources/HostApp/Views/AboutView.swift`
- `Sources/HostApp/Views/QuickLookConflictNoticeView.swift`
- `Tests/HostAppTests/`

## 단계 커밋

| 커밋 | 내용 |
|------|------|
| `4b6ecbe` | Stage 1 충돌 감지와 버전 비교 모델 |
| `b44a1b6` | Stage 2 About 안내와 설정 진입 |
| `0da0a84` | Stage 3 실행 안내와 재표시 정책 |
| `54b9657` | About Quick Look 섹션 순서 |
| `2909c7f` | 행동 중심 안내 문구 |
| `e36edd1` | 설정 진입 중 팝업 유지 |

## 범위 밖과 알려진 제한

- HOP 또는 알한글 확장의 실제 활성 상태 확인
- 현재 선택된 Quick Look provider 판정
- HOP 확장 자동 비활성화 또는 알한글 provider 강제 선택
- 알 수 없는 HOP Preview version의 `rhwp` 추정
- HOP 또는 알한글 업데이트·삭제
- `rhwp` core dependency 변경

이 제한은 macOS 공개 API와 사용자 선택권을 지키기 위한 의도된 경계다. HOP 새 Preview version이 배포되면 provenance를 별도로 검증한 뒤 catalog를 추가해야 한다.

## 최종 상태

Task #433의 계획된 Stage 1~4 구현과 통합 검증은 완료됐다. 로컬 브랜치는 `local/task433`이며 public 배포, 원격 push와 PR 생성은 아직 수행하지 않았다. 작업지시자 승인 후 `publish/task433` 게시와 `devel` 대상 PR 생성 단계로 진행한다.
