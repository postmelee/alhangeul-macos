# Task M900 #474 Stage 3 완료보고서

## 실제 이력 검증

latest fetch 후 origin/main `0272172e543d59fd87eebb11d98904ee344a4487`, origin/devel `ed325b2cd16c213a9a95867863fff8709e1cfe7f`를 비교했다. main-only `abdf88f`/`0272172` 두 merge 모두 두 번째 parent와 tree가 같고 merge 결과 tree가 devel tree `2acd2c8f6e81af5947357fa0aa8ca4603a47a03d`와 같아 통과했다. 현재 candidate `2f59503`도 같은 조건으로 통과했다.

과거 release transport 사례도 실제 Git object로 확인했다.

| PR | merge commit | 두 번째 parent tree와 동일 |
|---|---|---|
| #446 | 1e7f5df59684713745cb9d59c0a0e9dfdaaf0272 | 예 |
| #450 | ab7a74b5fc35dcdb56b121a8b74d00460a967e7b | 예 |
| #452 | 26f3104469135c5e80b3a19dddb9d0baebfbfb0a | 예 |

## 검증과 상태

Git fixture 17개, Actions env를 포함한 golden unit 16개, shell/YAML/actionlint, helper help와 diff check 통과. main/devel 실제 gate는 branch/index/worktree를 바꾸지 않았다. core/Cargo/FFI lock도 origin/devel 대비 불변이다. #474 단독 경로 분류는 release checks만 추가하며 상속한 작업의 macOS 검증은 누적 PR CI가 수행한다.

로그: `build.noindex/task474/{final-branches.log,final-candidate.log,historical-transport.txt,classification.txt}`. 실제 merge/release는 실행하지 않았다. PR #503/#504 CI는 모두 통과했다. #505 CI fixture 환경 보완 `89a7f18`을 merge로 인계했고 남은 CI는 게시 후 확인한다.
