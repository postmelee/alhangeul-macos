# Task M010 #497 구현계획서

[수행계획서](task_m010_497.md)의 승인된 등록·수정·회귀 검증을 세 단계로 수행한다. 사용자 승인은 2026-09-06 같은 스레드의 구체적 HWP3 저장 수정안에 대한 “진행해줘”다.

## Stage 1. 임시 저장 경로와 원본 보존

- destination 옆 임의 파일 생성을 OS의 itemReplacementDirectory로 변경한다.
- 임시 디렉터리는 이 저장 요청만 소유하고 defer로 정리한다. 새 destination 게시에는 RENAME_EXCL을 유지한다.
- 일반 overwrite 허용 경로·저장 정책·보호 경고는 유지한다.
- 실제 게시 직전 destination 생성 경쟁, 기존 destination 보존, 쓰기·게시 실패 정리와 성공 후 정리 테스트를 확인한다.
- HostAppTests와 AppKit 경계 검사를 통과한 뒤 `task_m010_497_stage1.md`와 함께 커밋한다.

## Stage 2. Sandbox와 앱 저장 검증

- 제품과 같은 app-sandbox / user-selected.read-write 조건에서 NSSavePanel로 선택한 sandbox 밖 파일을 저장한다. 자체 temporaryDirectory만 이용한 unit test와 구분한다.
- 평문/보호 HWP3 → HWP5/HWPX 네 조합, 경고 취소·새 파일·재열기·후속 저장, 기존 HWP5/HWPX 저장을 확인한다.
- 원본 fixture SHA256을 보존하고 테스트 출력은 task 경로의 새 파일에만 둔다. 앱 sandbox를 해제하거나 폴더 전체 권한으로 우회하지 않는다.
- Debug endpoint 비활성 및 sandbox entitlement를 확인한다. 앱/확장 산출물은 build.noindex 아래에 두고 등록·기존 설치 상태를 정리한다.
- `task_m010_497_stage2.md`에 실제 관찰 범위와 통과·미실행 항목을 기록한다.

## Stage 3. 보고와 PR 준비

- source diff, tests, sandbox 검증 증거를 재검토하고 `task_m010_497_report.md` 및 Stage 3 보고서를 작성한다.
- 기존 실패 draft의 결과와 수정 로컬 앱 결과를 구분한다. signed/notarized 새 draft는 release task #494에 인계한다.
- 최종 문서 링크·GitHub body·diff 검사를 통과한 후보를 publish/task497로 게시하고 devel 대상 Open PR을 만든다.
- 공개 후보 main/tag/Publish 변경과 official 배포는 이 단계에서 실행하지 않는다.

## 검증 실패 처리

실패한 검사는 같은 단계 안에서 수정·재검증하고 성공 전에 단계 완료로 표시하지 않는다. 외부 volume이나 파일 단위 권한에서 보존 계약을 만족하지 못하면 덮어쓰기 허용으로 우회하지 않는다.

## 단계 결과 — 2026-09-07

- [Stage 1](../working/task_m010_497_stage1.md): 수정과 XCTest 184개 통과.
- [Stage 2](../working/task_m010_497_stage2.md): 실제 sandbox 저장·재열기 6조합 통과, 기존 설치 보존. 전체 등록 위생의 기존 중복·잔여 기록은 한계로 기록.
- [Stage 3](../working/task_m010_497_stage3.md): 최종 변경 검토·보고·Open PR 후보 준비. 원격 CI와 release 후보 반영은 게시 후 확인.
