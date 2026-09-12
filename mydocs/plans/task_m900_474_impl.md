# Task M900 #474 구현계획서

## Stage 1 — 판정과 회귀 fixture

Python stdlib helper와 shell entrypoint를 추가한다. `git merge-tree --write-tree`(Git 2.38+) 결과를 source tree와 비교한다. main-only transport/content 후보 commit, merge 결과 tree와 차이 경로를 요약한다. exit 0은 통과, 1은 content/conflict 차단, 2는 history/ref/tool 환경 오류다. fetch나 branch/index/worktree 변경은 수행하지 않는다.

fixture: tree-equal transport, main-only non-merge, merge-time content change, 실제 back-merge, cherry-pick 동등 반영, devel-only 정상 변경, main reverted net-zero, conflict, missing ref, shallow clone, unrelated histories, configured merge driver가 drift를 숨기지 못함, dirty worktree/index 보존.

## Stage 2 — CI와 운영 규칙

main/devel 대상 PR CI는 `origin/main`과 event의 실제 PR head SHA를 검사한다. GitHub가 만든 merge checkout HEAD를 source로 쓰지 않는다. release rehearsal/publish와 local release source preflight는 fetch된 origin/main/origin/devel branch invariant를 검사한다. public tag 재실행은 tag/branch 역할을 구분한다. native-viewer-editor는 이 invariant의 대상이 아니다.

main hotfix·문서·workflow 변경 owner는 devel 인계 PR과 gate 회복을 맡고 다음 개발/릴리즈 전에 완료한다. tree만 같은 transport 이력 때문에 history-only PR을 만들지 않는다. shell/YAML/fixture/helper interface 검증 후 단계 커밋한다.

## Stage 3 — 실제 이력과 보고

origin/main, origin/devel을 fetch하여 exact SHA를 기록한다. 두 브랜치와 현재 candidate에 gate를 실행하고 git 상태 불변을 확인한다. 기존 #446/#450/#452 merge의 두 번째 parent tree 일치도 기록한다. source/docs/최종보고서/오늘할일을 커밋하고 `publish/task474`에서 devel 대상 PR을 생성한다. 네 PR CI를 확인하고 사용자 리뷰에 인계한다.

## Stage 4 — PR #506 리뷰 보완

최신 branch 인계를 확인하는 release 재실행 조건, 로컬 preflight의 네트워크·remote-tracking ref 갱신을 runbook에 명시한다. native 제외와 기존 classify fetch 정책은 유지하며 근거를 코멘트에 연결한다. built-in merge 속성과 summary 기록 실패의 exit 2 정책을 설명하고 PR CI에 Python compileall을 추가한다. Git fixture·Python helper fixture·workflow syntax와 실제 candidate gate를 검증하고 보완 내용을 공개한다.
