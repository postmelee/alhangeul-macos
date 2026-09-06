# Task M900 #474 Stage 1 완료보고서

## 결과

main/source ref를 commit으로 고정하고 shallow/missing/unrelated history를 거부한다. main-only 이력에서 2-parent merge의 tree가 두 번째 parent와 같으면 transport로 분류한다. `git merge-tree --write-tree --no-messages source main`이 충돌 없이 source tree를 그대로 반환해야 통과한다. 전체 main/source tree가 서로 달라도 devel-only 기능은 정상이다. patch-id 유사성으로 콘텐츠 누락을 숨기지 않는다.

custom external merge driver는 계산 중 `/usr/bin/false`로만 대체하고 Git config를 쓰거나 해당 driver command를 실행하지 않는다. 통과/콘텐츠 차단/환경 오류는 exit 0/1/2로 구분한다. ref/index/worktree는 그대로이며 생성된 tree object만 Git DB에 남을 수 있다.

## 검증

격리 Git fixture 15개 통과: transport, devel-only 변경, main-only non-merge/merge-time content, back-merge, cherry-pick 동등 반영, net-zero main, conflict, missing/shallow/unrelated history, dirty worktree/index, custom driver, binary, 실패 summary.

실제 초기 origin/main `0272172`, origin/devel `ed325b2`는 main-only commit 2개 모두 transport이며 예상 merge tree와 devel tree가 동일해 통과했다. shell syntax/help와 diff check 통과. 상세 로그는 `build.noindex/task474/baseline-gate.log`.
