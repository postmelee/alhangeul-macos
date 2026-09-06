# Task M900 #474 최종 결과보고서

## 결과

main-only merge의 second-parent tree 일치 여부로 transport를 분류하고, main을 source에 병합할 예상 tree가 source tree와 같은지로 실제 콘텐츠 인계를 검증한다. devel-only 기능과 transport-only history는 허용하고 미반영 main content/conflict는 차단한다. shallow/missing/unrelated history와 Git 환경 오류를 별도 실패로 보고한다. ref/index/worktree와 기존 Git config는 수정하지 않는다.

main/devel 대상 PR CI는 GitHub merge checkout 대신 event의 실제 source head를 검사한다. release workflow/local release preflight는 최신 main/devel branch 인계를 검사한다. main 변경 owner는 hotfix·문서·workflow의 devel 인계와 gate 회복을 다음 개발/release 전에 완료해야 한다. history-only back-merge와 history rewrite는 요구하지 않는다.

## 검증

Git fixture 17개, CI env golden fixture 16개, shell/YAML/actionlint 통과. 실제 origin/main `0272172`와 origin/devel `ed325b2`는 transport 2개·미반영 content 0개로 통과했고 candidate도 통과했다. 과거 PR #446/#450/#452의 merge tree도 source parent와 동일함을 확인했다. 검사 전후 branch/index/worktree 불변, core/Cargo/FFI lock 불변이다.

상세: [Stage 1](../working/task_m900_474_stage1.md), [Stage 2](../working/task_m900_474_stage2.md), [Stage 3](../working/task_m900_474_stage3.md).

## 리뷰 인계

리뷰·병합 순서는 #394 PR #503 → #470 PR #504 → #469 PR #505 → 이 PR이다. 선행 #469 리뷰 보완을 포함한 기준은 `c642d92`이고 자신의 diff는 `c642d92..HEAD`다. 모두 devel 대상이므로 선행 PR 병합 전 누적 diff가 보인다. 초기 게시 때는 사용자 리뷰를 위해 병합을 보류했다. 2026-09-07 네 PR의 병합·정리를 명시 승인받았고 선행 PR #503, PR #504, PR #505의 병합과 관련 이슈 close를 확인했다. 이 PR에 오늘할일 완료 기록과 잔여 검증에 대한 병합 승인 경위를 포함한다. PR #462는 중첩 clipping 회귀 검증이 필요하여 현재 초안 병합 보류이며 #337은 이번 작업에서 착수하지 않았다.

[Stage 4](../working/task_m900_474_stage4.md)에서 release 재실행/네트워크 조건, built-in merge와 summary 정책 설명, Python 구문 검사를 보완했다. Git 17개·golden helper 21개와 실제 candidate content gate가 통과했다. 선행 #470의 macOS 12 runtime 검증은 환경이 없어 미실행이며, 작업지시자가 이 한계를 안내받은 뒤 병합을 승인했다. 후속 확인 사항으로 유지한다.
