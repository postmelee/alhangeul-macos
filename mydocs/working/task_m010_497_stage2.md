# Task M010 #497 Stage 2 보고서

## 단계 목적

수정된 저장 경로가 실제 NSSavePanel의 파일 단위 sandbox 권한으로 동작하는지 확인한다. [Stage 1](task_m010_497_stage1.md)의 unit 검증과 별도로 평문·보호 HWP3의 두 출력 형식 및 일반 저장을 검증했다.

## 산출물과 환경

2026-09-06 macOS 26.5.2 (25F84), Xcode 26.6 (17F113), Apple Silicon의 로컬 APFS에서 제품 source commit `a9758e20cbb480b5338bc3f08696386027d113d1`을 검증했다. 보고서 정리는 2026-09-07에 이어 수행했다.

- 실행 앱: `build.noindex/task497/gui/Alhangeul.app`, 0.1.11 (17), ad hoc 서명 Debug.
- `com.apple.security.app-sandbox`, `com.apple.security.files.user-selected.read-write`가 true이며 Debug의 `get-task-allow`도 true다. 광범위한 폴더 entitlement를 추가하지 않았다.
- Release 정적 검증 앱: `build.noindex/task497/release/Build/Products/Release/Alhangeul.app`. 이 산출물은 서명 없이 빌드했으며 실행하지 않았다.
- 증거: `build.noindex/task497/`의 `gui-summary.json`, `all-saved-files-audit.json`, `build-artifacts.json`, 각 시나리오의 AX 기록·PNG, 빌드·정적 검사 로그.

## 실제 앱 검증

NSSavePanel에서 앱 컨테이너 밖의 `build.noindex/task497/fixtures/` 아래 새 파일을 직접 선택했다. 각 저장 후 Cmd+S와 재열기를 수행했다.

| 원본 → 저장 형식 | 새 파일 | 재열기 결과 |
|------------------|---------|-------------|
| 평문 HWP3 → HWP5 | `plain-to-hwp5.hwp` | 16쪽, 성공 |
| 평문 HWP3 → HWPX | `plain-to-hwpx.hwpx` | 16쪽, 성공 |
| 보호 HWP3 → 평문 HWP5 | `protected-to-hwp5.hwp` | 암호 요청 없이 24쪽, 성공 |
| 보호 HWP3 → 평문 HWPX | `protected-to-hwpx.hwpx` | 암호 요청 없이 24쪽, 성공 |
| 일반 HWP5 → HWP5 | `regular-saved.hwp` | 1쪽, 성공 |
| 일반 HWPX → HWPX | `regular-saved.hwpx` | 9쪽, 성공 |

평문 HWP3의 변환 경고 및 보호 HWP3의 보호 해제·변환 경고를 확인했다. HWP5 출력 경고는 취소 후 다시 진입해 저장했고, 보호 문서의 후속 저장에는 보호 해제 경고가 반복되지 않았다. 원본 fixture 4개의 SHA256은 모두 유지됐으며 저장본 6개의 HWP5 signature 또는 HWPX ZIP 무결성을 확인했다. 실제 화면 재열기와 페이지 수를 확인한 범위이며 문서 전체의 편집·렌더링 동일성을 보증하는 검사는 아니다.

Mac 잠금으로 중단된 UI 검사는 작업지시자가 잠금을 해제한 뒤 재개했다. 잠긴 화면에서의 미진행 항목을 제품 실패나 통과로 계산하지 않았다.

## 빌드와 정적 검증

- Sandbox Debug build 및 `codesign --verify --deep --strict` 통과.
- Release universal build 통과. 앱·Preview·Thumbnail 실행 파일의 `arm64 + x86_64` slice 확인.
- Debug endpoint 비활성, Release endpoint 설정 검사 통과.
- core build-info와 rhwp-core.lock 일치, bundled Studio 검증 통과.
- HostAppTests 184개와 AppKit 경계 검사는 Stage 1에서 통과했다. 이후 제품 source가 바뀌지 않아 재실행하지 않았다.

## 종료와 기존 환경 보존

저장본을 다시 연 상태에서 native 메뉴로 앱을 종료했다. 검증 앱 프로세스는 남지 않았다. 사용자 설치 앱의 기존 파일·symlink manifest 146개는 모두 일치하며 `/Applications`와 사용자 Applications의 설치 앱을 변경하지 않았다.

표준 `check-extension-registration-hygiene.sh --cleanup-dev-registrations`를 실행했다. 최종 PlugInKit에는 기존 설치된 0.1.10과 0.1.8 provider만 있고 개발 provider는 없다. 최종 LaunchServices 원본 dump에는 Task 497의 HostApp 등록이 없고 Release bundle 내부 Sparkle Updater 기록이 남아 있다. 전체 위생 검사는 기존 중복 설치와 LaunchServices 잔여 기록 때문에 exit 1이며, 전체 통과로 기록하지 않는다. 기존 설치·다른 작업의 파일 삭제나 전역 등록 초기화는 수행하지 않았다.

근거는 `registration/20260906-235732/`, `registration-exit.json`, `final-preview-providers.log`, `final-thumbnail-providers.log`, `final-app-processes.log`, `final-lsregister.txt`다.

## 잔여 위험

Developer ID 서명·공증을 거친 수정 draft, 실제 Intel Mac, 최소 지원 macOS 12, 외부 volume은 이번 단계에서 실행하지 않았다. 기존 destination 경쟁과 실패 정리는 unit test로 검증했으며 GUI에서 기존 파일 교체를 실행한 것은 아니다. Finder에서 새 release provider가 선택되는지 확인하는 검증은 release task에 남는다.

## 판정과 다음 단계

실제 sandbox 저장 수용 기준 여섯 조합을 통과했다. 같은 승인 범위의 Stage 3에서 최종 보고와 devel 대상 PR을 준비한다. [Task #494](https://github.com/postmelee/alhangeul-macos/issues/494)의 공증 draft 검증 gate는 수정 후보로 다시 수행해야 한다. 기존 v0.1.11 tag와 draft는 이 단계에서 바꾸지 않았다.
