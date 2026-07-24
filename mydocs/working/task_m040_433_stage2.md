# Task M040 #433 Stage 2 완료보고서

## 단계 목적

Stage 1의 HOP Quick Look 감지 결과를 기존 About 화면에 연결하고, 사용자가 충돌 가능성·설치된 버전·알한글 권장 근거를 확인한 뒤 공개 시스템 설정 화면으로 이동할 수 있게 한다.

## 구현 결과

### About 충돌 안내

`ExtensionStatusModel`의 기존 확장 상태 새로고침에 HOP 충돌 감지를 함께 연결했다. 각 새로고침에는 UUID를 부여해 먼저 시작한 비동기 작업이 늦게 끝나더라도 최신 결과를 덮어쓰지 못하게 했다.

About 화면에는 감지 결과가 있을 때만 `Quick Look 미리보기 충돌 가능성` 카드를 표시한다. 카드 문구는 실제 활성 상태나 현재 선택된 provider를 확인했다고 주장하지 않고, HOP과 알한글이 같은 HWP/HWPX 형식을 지원한다는 사실과 macOS가 예상과 다른 미리보기를 선택할 수 있다는 가능성만 설명한다.

검증된 HOP Preview `0.2.0`과 알한글의 더 높은 `rhwp` 버전이 확인되면 다음 권장 문구를 표시한다.

> 알한글은 HOP Preview보다 최신인 rhwp 렌더러를 포함합니다. HOP Quick Look Preview를 끄고 알한글 미리보기를 켜는 것을 권장합니다.

HOP Preview 버전이 catalog에 없거나 metadata를 확인할 수 없으면 HOP `rhwp`를 `확인 불가`로 표시하고 위 최신 버전 권장 문구를 만들지 않는다.

### 버전 비교

UI용 값 변환을 `QuickLookConflictPresentation`으로 분리했다. 카드에서 앱, 미리보기, `rhwp`를 서로 다른 행으로 표시하며 실제 설치 환경에서는 다음 값이 확인됐다.

| 구분 | 알한글 | HOP |
|------|--------|-----|
| 앱 | `0.1.8 (14)` | `0.3.1 (0.3.1)` |
| 미리보기 | `0.1.8 (14)` | `0.2.0 (1)` |
| rhwp | `v0.7.18 (93862a4)` | `v0.7.13` |

HOP `rhwp`는 binary scan 결과가 아니라 Stage 1의 검증된 Preview 버전 catalog를 기준으로 표시한다는 설명을 카드에 함께 넣었다.

### 시스템 설정 진입

`QuickLookSettingsOpener`를 추가해 운영체제 버전에 따라 다음 공개 설정 경로를 연다.

| 운영체제 | 우선 경로 | 실패 시 fallback | 수동 안내 |
|----------|-----------|------------------|-----------|
| macOS 13 이상 | `x-apple.systempreferences:com.apple.LoginItems-Settings.extension` | System Settings 앱 | 시스템 설정 > 일반 > 로그인 항목 및 확장 프로그램 > 확장 프로그램 > Quick Look |
| macOS 12 | Extensions preference pane | System Preferences 앱 | 시스템 환경설정 > 확장 프로그램 > Quick Look |

우선 경로, fallback, 전체 실패를 구분해 사용자에게 후속 문구를 표시한다. 설정 앱을 여는 것 외에 HOP 또는 알한글의 확장 활성 상태는 읽거나 변경하지 않는다.

### 화면 구성과 접근성

- About 창을 `640 × 680` 기본 크기와 `540 × 430` 최소 크기의 resizable 창으로 변경했다.
- 전체 내용을 ScrollView로 감싸 작은 창에서도 카드와 버튼에 접근할 수 있게 했다.
- `다시 확인` 버튼이 extension registration 상태와 HOP metadata 감지를 함께 재실행한다.
- 버전 비교 각 행에 `항목, 알한글 값, HOP 값` 형식의 VoiceOver label을 제공한다.
- 경고 아이콘과 제목, 권장 설명, 결과 문구를 함께 제공해 색상만으로 상태를 전달하지 않는다.
- 버전과 수동 설정 경로는 텍스트로 선택할 수 있다.

## 검증 결과

| 검증 | 결과 | 비고 |
|------|------|------|
| `xcodegen generate` | 통과 | 새 production/test source membership 반영 |
| `HostAppTests` | 통과 | 총 17개 테스트, 실패 0 |
| HostApp Debug build | 통과 | app, Preview, Thumbnail과 Stage 2 소스 compile/link 성공 |
| About 실제 UI | 통과 | 현재 설치된 HOP/알한글 버전 표와 권장 문구, 스크롤 레이아웃 확인 |
| `다시 확인` | 통과 | 카드가 같은 설치 정보로 다시 생성됨 |
| 시스템 설정 진입 | 통과 | macOS 26에서 `로그인 항목 및 확장 프로그램` 화면과 HOP/알한글 항목 노출 확인 |
| 설정 상태 비변경 | 통과 | UI 검증 중 어떤 확장 토글도 변경하지 않음 |
| `./scripts/check-no-appkit.sh` | 통과 | shared/CoreBridge 경계에 AppKit/UIKit 추가 없음 |
| 금지 런타임 경로 검색 | 통과 | 새 Stage 2 코드에 `pluginkit`, 비공개 PlugInKit, `qlmanage`, `Process(`, binary `strings` 실행 없음 |
| `git diff --check` | 통과 | whitespace 오류 없음 |

추가한 단위 테스트는 다음을 검증한다.

1. 알려진 HOP 버전에서 네 가지 version 축과 정확한 권장 문구 생성
2. 알려지지 않은 HOP 버전에서 `rhwp 확인 불가`와 최신 주장 생략
3. HOP Preview metadata 누락 시 제한된 표시
4. 충돌 없음에서 presentation 미생성
5. macOS 13 이상과 macOS 12 설정 경로
6. 우선 경로 성공 시 fallback 미호출
7. 우선 경로 실패 시 fallback 호출
8. 두 경로 실패 시 실패 결과 반환

실제 UI 검증은 Computer Use 접근성 트리와 화면 캡처를 함께 사용했다. 접근성 트리에서 제목, 설명, 버전 비교 세 행, 수동 경로, 두 버튼이 모두 읽히는 것을 확인했고, 화면 캡처에서는 다크 모드의 줄바꿈·간격·스크롤 하단 버튼 노출을 확인했다.

## 개발 산출물 등록 정리

HostApp Debug 실행 뒤 표준 hygiene helper를 두 번 실행하고 Task #433 전용 Stage 2 DerivedData를 삭제했다.

- `scripts/check-extension-registration-hygiene.sh --cleanup-dev-registrations`
- `build.noindex/DerivedDataTask433Stage2` 삭제
- `build.noindex/DerivedDataTask433Stage2Host` 삭제
- 최종 PlugInKit Preview provider: `/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulPreview.appex`
- 최종 PlugInKit Thumbnail provider: `/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulThumbnail.appex`

활성 PlugInKit provider는 설치본 하나씩만 남았다. 다만 LaunchServices app 목록에는 삭제된 Task #433 Stage 1/2 경로와 기존 `build.noindex/DerivedData` 경로가 stale record로 계속 출력됐다. 해당 Stage 1/2 파일과 PlugInKit provider는 남아 있지 않으며, 다른 앱 등록에 영향을 줄 수 있는 전역 LaunchServices reset은 수행하지 않았다.

## 남은 위험과 다음 단계 경계

- 공개 API로 HOP Preview의 실제 활성 상태나 macOS가 현재 선택한 provider를 확인할 수 없으므로 About 문구는 계속 `충돌 가능성`으로 유지한다.
- 시스템 설정 deep link는 공개적으로 안정성이 보장된 세부 Quick Look 토글 URL이 아니므로, 상위 화면 진입과 수동 경로를 함께 제공한다.
- macOS 26의 설정 화면은 확장 프로그램을 앱별 또는 카테고리별로 표시할 수 있어 사용자가 HOP 세부사항을 한 번 더 열어야 할 수 있다.
- Stage 2에는 실행 시 자동 안내, `나중에` dismissal 저장, fingerprint 기반 재표시 정책이 포함되지 않았다.
- 삭제된 Debug app의 LaunchServices stale record는 전역 초기화 없이 남아 있으나 실제 Quick Look provider 선택에는 참여하지 않는다.

## 승인 요청

Stage 2의 About 충돌 안내, 버전 비교, 다시 확인과 시스템 설정 진입 결과를 승인하고, Stage 3 `실행 시 충돌 안내와 재표시 정책 연결` 진입을 요청한다.
