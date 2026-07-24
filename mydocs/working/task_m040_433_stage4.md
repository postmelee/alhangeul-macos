# Task M040 #433 Stage 4 완료보고서

## 단계 목적

Stage 1~3에서 구현한 HOP Quick Look 충돌 감지, 버전 비교, About 안내, 실행 팝업과 fingerprint 재표시 정책을 생성 프로젝트·정책 테스트·Debug 앱 실행 환경에서 통합 검증한다. 검증 뒤에는 Task #433 전용 개발 앱 등록, DerivedData와 dismissal 값을 정리해 사용자 환경에 검증 부산물을 남기지 않는다.

## 검증 환경

| 항목 | 확인값 |
|------|--------|
| HOP 앱 | `/Applications/HOP.app`, `0.3.1 (0.3.1)` |
| HOP Preview | `0.2.0 (1)` |
| HOP `rhwp` | 검증 catalog 기준 `v0.7.13` |
| 알한글 앱/Preview | `0.1.8 (14)` |
| 알한글 `rhwp` | `v0.7.18 (93862a4)` |
| Stage 4 앱 | `build.noindex/DerivedDataTask433Stage4/Build/Products/Debug/Alhangeul.app` |

HOP 앱과 Preview 값은 실제 설치 bundle metadata로 다시 확인했다. 알한글 `rhwp`는 `rhwp-core.lock`과 bundled provenance를 기준으로 표시했다. Debug 앱은 compile/link와 HostApp 사용자 시나리오 검증에만 사용했으며 Finder Quick Look provider 판정 기준으로 사용하지 않았다.

## 통합 빌드와 정책 검증

| 검증 | 결과 | 비고 |
|------|------|------|
| `xcodegen generate` | 통과 | `project.yml` 기준 재생성 뒤 tracked diff 없음 |
| `HostAppTests` | 통과 | 총 25개, 실패 0 |
| HostApp Debug build | 통과 | HostApp, Preview, Thumbnail compile/link 및 embed 성공 |
| bundled studio asset | 통과 | `verify-rhwp-studio-assets.sh` 성공 |
| embedded extension | 통과 | `AlhangeulPreview.appex`, `AlhangeulThumbnail.appex` 확인 |
| `./scripts/check-no-appkit.sh` | 통과 | `RhwpCoreBridge` AppKit/UIKit 경계 유지 |
| 금지 런타임 경로 정밀 검색 | 통과 | `Process(`, `NSTask`, `/usr/bin/qlmanage`, `pluginkit -a/-e/-r` 실행 경로 없음 |
| `git diff --check` | 통과 | whitespace 오류 없음 |

구현계획서의 넓은 `pluginkit|PlugInKit|qlmanage|Process\(` 검색에서는 `ExtensionStatusModel`의 sandbox 제약 설명 주석 두 줄만 발견됐다. 실행 코드는 LaunchServices·`NSWorkspace` 공개 API만 사용한다. 통합 실행 로그에는 macOS가 자동으로 `com.apple.pluginkit.pkd` XPC 연결을 활성화한 기록이 있었으나, 앱이 CLI나 비공개 election API를 호출한 흔적은 없었다.

## 실제 사용자 시나리오

Computer Use 접근성 트리와 실제 앱 상태를 함께 사용해 다음 흐름을 검증했다.

| 시나리오 | 결과 |
|----------|------|
| 미확인 fingerprint 첫 실행 | `Quick Look 미리보기 안내` 팝업 1개 표시 |
| 실제 버전 표시 | 알한글 `v0.7.18 (93862a4)`, HOP `v0.7.13` 표시 |
| 행동 안내 | 확장 프로그램에서 HOP 훑어보기를 끄고 알한글 훑어보기를 켜도록 표시 |
| 설정 진입 | `로그인 항목 및 확장 프로그램` 화면 열림 |
| 설정 진입 중 팝업 유지 | 시스템 설정이 열린 뒤에도 안내 팝업 유지 |
| 설정 진입의 dismissal 처리 | 설정 버튼만 누른 상태에서는 dismissal key 미생성 |
| `자세히 보기` | About의 `Quick Look` 탭을 선택해 열고 앱/Preview/`rhwp` 비교 표시 |
| 종료 action의 dismissal 처리 | `자세히 보기`에서 현재 전체 metadata fingerprint 저장 |
| 동일 fingerprint 재실행 | 안내 팝업 생략, 기본 앱 창 표시 |
| HOP 미설치·알 수 없는 버전 | fixture 테스트에서 자동 notice 생략 또는 제한 안내 |
| version/provenance 변화 | synthetic fingerprint 변화 테스트에서 재표시 대상 |

설정 화면에서는 확장 토글을 누르지 않았다. 알한글은 설정 화면을 여는 것 외에 HOP 또는 알한글의 활성 상태와 현재 provider를 읽거나 변경하지 않는다.

## 개발 환경 정리

통합 검증 뒤 다음 정리를 수행했다.

- Stage 4 Debug 앱과 시스템 설정 종료
- `alhangeul.quickLookConflict.dismissedFingerprint.v1` 삭제 및 미설정 확인
- `check-extension-registration-hygiene.sh --cleanup-dev-registrations` 실행
- `build.noindex/DerivedDataTask433Stage4` 삭제
- `build.noindex/DerivedDataTask433UserReview` 삭제
- 최종 hygiene check에서 development registration과 issue가 없음을 확인

최종 PlugInKit provider path는 현재 시스템에서 보고되지 않았다. 이는 사용자가 시스템 설정에서 선택하는 활성 상태 영역이며 Task #433은 이를 강제로 보정하지 않는다. 저장소에 이미 존재하던 다른 타스크의 `build.noindex` 앱 bundle은 등록되지 않은 상태라 건드리지 않았다.

## 완료 판단

Stage 4 완료 기준을 모두 충족했다.

- 전체 정책 테스트와 HostApp build 통과
- 실제 HOP `0.3.1` / Preview `0.2.0` / `rhwp v0.7.13`과 알한글 `rhwp v0.7.18` 표시 확인
- 행동 중심 안내와 설정 진입 중 팝업 유지 확인
- 다른 확장 상태를 자동 변경하지 않음
- Debug 등록, Task #433 DerivedData와 dismissal 값 정리 완료

## 알려진 제한

- 공개 API로 HOP Preview의 실제 활성 상태나 macOS가 선택한 provider를 확인할 수 없다.
- HOP Preview `0.2.0` 이외의 `rhwp`는 검증 catalog에 추가되기 전까지 `확인 불가`로 처리한다.
- 사용자가 시스템 설정에서 HOP을 끈 뒤에도 About에는 설치 metadata 기준의 충돌 가능성이 남을 수 있다.
- 설정 화면의 앱별/카테고리별 표시 방식에 따라 HOP 또는 알한글 상세 항목을 한 번 더 열어야 할 수 있다.

## 승인 요청

Task #433 Stage 4 통합 검증과 최종 결과를 승인하고, `publish/task433` 게시 및 `devel` 대상 PR 생성을 진행할지 확인을 요청한다.
