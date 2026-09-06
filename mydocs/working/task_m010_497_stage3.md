# Task M010 #497 Stage 3 보고서

## 단계 목적

HWP3 sandbox 저장 수정의 최종 차이와 검증 증거를 검토하고 devel 대상 Open PR 후보를 준비한다.

## 산출물

[최종 보고서](../report/task_m010_497_report.md), 수행·구현계획 상태, 2026-09-07 오늘할일, 검토한 PR 본문. 게시 branch는 `publish/task497`, base는 `devel`이다.

## 변경 검토

제품 변경은 `DocumentSaveContract.swift`의 임시 디렉터리 선택·정리와 테스트용 publisher 기본값에 한정된다. 완성본만 배타적으로 rename하는 계약, 일반 저장 경로, 보호·변환 경고와 기존 entitlement를 유지했다. core·Studio·FFI·버전·배포 workflow 변경은 없다. 저장 경쟁의 실제 RENAME_EXCL 결과와 실패 정리·원본 보존을 테스트에서 확인했다.

## 검증

[Stage 1](task_m010_497_stage1.md)의 XCTest 184개와 [Stage 2](task_m010_497_stage2.md)의 실제 sandbox 저장·재열기 6조합, Debug·Release build와 정적 검증이 통과했다. 제품 source는 이 검증 후 바뀌지 않았다. 최종 문서 상대 링크, GitHub body, `git diff --check`를 확인한 뒤 게시한다. 원격 PR CI 결과는 게시 후 해당 PR의 최신 head checks를 기준으로 확인한다.

## 잔여 위험

수정 코드의 Developer ID 서명·공증 draft smoke는 아직 실행하지 않았다. 등록 위생의 기존 중복 설치·잔여 기록, 외부 volume·Intel·macOS 12 미실행 범위는 Stage 2와 최종 보고서에 명시했다. 로컬 통과를 official release 승인이나 전체 환경 위생 통과로 해석하지 않는다.

## 다음 단계

Open PR과 최신 head CI를 검토한 뒤 수정 후보의 통합 및 release task 복귀를 결정한다. 기존 v0.1.11 tag/draft는 `f3bb7bc73510593c35c2e423323bbb01d62c3aad` 기준으로 남아 있으므로 수정 후보를 포함하지 않는다. 후보 교체 시 tag 재지정과 새 draft 생성 입력을 명시하고, 새 공증 산출물로 저장·Finder·DMG smoke를 다시 수행해야 한다.

## 승인 범위

이번 단계는 2026-09-06 승인한 별도 이슈 등록·수정·회귀 검증 및 검토 가능한 PR 준비 범위다. PR merge, tag 재지정, draft 교체와 official publish는 실행하지 않았다. Issue #497 및 release Issue #494는 열어 둔다.
