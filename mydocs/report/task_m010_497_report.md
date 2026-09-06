# Task M010 #497 최종 보고서

## 작업 요약

Sandbox 앱에서 HWP3 문서를 새 HWP5/HWPX 복사본으로 저장할 때 destination 옆 임의 임시 파일을 만들던 경로를 OS의 `itemReplacementDirectory`로 변경했다. 실제 NSSavePanel로 선택한 새 파일에 저장할 수 있고 기존 파일을 덮어쓰지 않는 배타적 게시 계약을 유지한다.

| 항목 | 내용 |
|------|------|
| Issue | [#497 Sandbox HWP3 변환 복사본 저장 권한 오류](https://github.com/postmelee/alhangeul-macos/issues/497) |
| 관련 작업 | [#494 v0.1.11 release](https://github.com/postmelee/alhangeul-macos/issues/494), 선행 저장 보호 #482 / PR #483 |
| milestone / branch | M010 / `local/task497` → `publish/task497` → `devel` |
| 기준 commit | `fe1efcf898613886fbdb6353f847ff3478c2aa0b` |
| 제품 수정 commit | `a9758e20cbb480b5338bc3f08696386027d113d1` |
| 검증 환경 | macOS 26.5.2, Xcode 26.6, Apple Silicon, 로컬 APFS |
| 완료 범위 | 구현·로컬 회귀 검증·PR 후보 문서 준비. 원격 PR checks는 게시 후 최신 head에서 확인 |

## 원인과 최종 변경

기존 signed draft에서 평문·보호 HWP3 → HWP5 저장이 권한 오류로 실패했다. NSSavePanel은 선택한 파일에 대한 권한을 부여하지만 기존 코드는 부모 폴더에 별도 이름의 sibling 임시 파일을 만들었다. Unit test의 자체 임시 디렉터리에서는 이 조건이 드러나지 않았다.

`DocumentSaveContract.swift`는 destination에 적합한 OS 임시 디렉터리에서 완성본을 준비하고 기존 `renameatx_np(..., RENAME_EXCL)`로 새 파일만 게시한다. 성공·실패 뒤 해당 임시 디렉터리를 정리한다. 게시 시 다른 writer가 destination을 선점하면 EEXIST를 반환하고 상대 파일을 보존한다. 일반 overwrite 허용 저장, 보호 경고, 변환 정책, sandbox entitlement, core·Studio·FFI는 변경하지 않았다.

`DocumentSaveContractTests.swift`는 기존 부분 쓰기 실패의 디렉터리 정리 검사를 강화하고, 실제 게시 경쟁·게시 실패 정리·성공 후 정리 테스트 3개를 추가했다. 계획·단계·오늘할일·이 보고서 외 추가 제품 파일 변경은 없다.

## 검증 결과

| 항목 | 결과 |
|------|------|
| HostAppTests | 184개 통과, 0 failures |
| Sandbox Debug 앱 | build·서명 무결성·sandbox/user-selected.read-write 확인 |
| 평문 HWP3 → HWP5 / HWPX | 각각 새 저장·Cmd+S·재열기 성공, 16쪽 |
| 보호 HWP3 → 평문 HWP5 / HWPX | 각각 경고 확인·새 저장·Cmd+S·암호 없이 재열기 성공, 24쪽 |
| 일반 HWP5 / HWPX | 새 저장·Cmd+S·재열기 성공, 각각 1쪽 / 9쪽 |
| 경고 취소 | 평문·보호 HWP3의 HWP5 출력 경고 취소 후 재진입 성공 |
| 무결성 | 원본 fixture 4개 SHA256 유지, 저장본 6개 signature/ZIP 검사 통과 |
| Release universal | 앱·Preview·Thumbnail 모두 arm64 + x86_64 |
| 정적 검사 | AppKit 경계, Debug/Release endpoint, core build-info, bundled Studio 통과 |
| 기존 설치 앱 | 사용자 설치 app manifest 146개 일치, 두 설치 위치의 앱 유지 |

실제 실행 앱은 `build.noindex/task497/gui/Alhangeul.app`의 **ad hoc 서명 Debug 0.1.11 (17)** 이다. app sandbox와 파일 선택 권한은 활성화돼 있고 Debug `get-task-allow`도 활성화돼 있다. NSSavePanel에서 컨테이너 밖의 새 파일을 선택했다. Release universal 산출물은 서명 없이 빌드했으며 실행하지 않았다.

상세 증거와 결과 범위는 [Stage 1](../working/task_m010_497_stage1.md), [Stage 2](../working/task_m010_497_stage2.md), [Stage 3](../working/task_m010_497_stage3.md)에 기록했다. 로컬 로그·AX·PNG·저장본은 `build.noindex/task497/`에 있다. 제품 수정 이후 문서만 바뀌어 같은 검사를 반복 실행하지 않았다.

## 환경 정리와 한계

앱을 native 메뉴로 종료하고 표준 개발 등록 정리 helper를 실행했다. 최종 PlugInKit 개발 provider와 Task 497 HostApp의 LaunchServices 등록은 없다. 기존 설치된 0.1.10·0.1.8 provider와 LaunchServices 잔여 기록이 있어 전체 위생 helper는 exit 1이다. Task 497 Release bundle 내부 Sparkle Updater 기록도 남아 있다. 전체 등록 위생을 통과했다고 보고하지 않는다.

Intel 실기기, macOS 12, 외부 volume과 수정된 Developer ID 서명·공증 draft는 미실행이다. GUI 검증은 저장·재열기와 페이지 수 확인 범위이며 문서 전체의 편집·렌더링 동일성이나 기존 파일 교체 UI를 검사한 것은 아니다. destination 경쟁·실패 정리는 unit test에서 검증했다.

## 릴리스 인계

기존 v0.1.11 tag는 `f3bb7bc73510593c35c2e423323bbb01d62c3aad`를 가리키며 수정 전 draft release id는 `383597735`, workflow run은 `34035992953`이다. 이 작업은 해당 tag/draft와 공개 release, Pages, Sparkle, Homebrew를 변경하지 않았다.

Task #494에서 수정 PR 통합 후 release candidate를 확정하고, 기존 미공개 tag/draft 교체에 대한 명시 승인을 받은 뒤 새 서명·공증 draft를 생성해야 한다. 새 산출물에서 이번 저장 matrix와 DMG·Finder provider smoke를 확인해야 pre-public 검증이 완료된다. 공식 공개는 그 결과를 근거로 별도 결정한다.

## 작업지시자 승인 상태

2026-09-06 같은 스레드의 “진행해줘”로 별도 이슈 등록·수정·회귀 검증이 승인됐고 검토 가능한 PR 준비까지 수행했다. PR merge·issue close·release 후보 교체는 아직 수행하지 않았다.
