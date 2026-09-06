# Task M020 #469 최종 결과보고서

## 결과

request sample의 0번 page를 실제 pinned core producer로 생성하여 metadata와 전체 render tree를 단일 golden JSON에 저장한다. 현재 golden은 TextRun 103개, Table 4개, TextLine 65개를 포함하며 기존 FFI 출력과 같은 JSON 값임을 확인했다.

명시 writer는 producer와 Swift decode 성공 후 atomic 교체한다. verifier는 source/Cargo/ref/features, sample/page/recipe/tree hash, 실제 producer output과 Swift decode를 검사하고 파일을 수정하지 않는다. native Cargo build를 사용하여 stale Frameworks에 의존하지 않는다. key/공백만 정규화하고 큰 unsigned 정수·배열·필드는 보존한다.

full sync는 complete core build 뒤 writer/검증/stage/summary를 수행한다. PR CI는 native 계약 gate를 universal build 전에 실행하고 release/local package는 verifier만 실행한다. Python 3.11+가 필요하며 CI는 3.12를 명시한다.

## 검증

반복 실제 writer byte 동일, 실제 verifier 통과, CLI negative 3종 nonzero와 파일 불변, helper unittest 16개(7종 path subcase), minimal decoder 18개, native HWP 기본 3종 통과. core/Cargo/FFI lock 불변. 현재 native architecture에서 결정성을 확인했으며 모든 node/pixel/플랫폼 변형을 보증하는 golden은 아니다.

상세: [Stage 1](../working/task_m020_469_stage1.md), [Stage 2](../working/task_m020_469_stage2.md), [Stage 3](../working/task_m020_469_stage3.md).

## PR 관계

선행 #394 PR #503, #470 PR #504를 상속한다. 자신의 commit 범위는 `d527be8..HEAD`, base는 devel이다. 앞 PR 병합 전 누적 diff가 보이며 생성된 JSON diff는 기본적으로 접히도록 표시했다. 다음 #474 완료 후 사용자 리뷰를 기다리며 merge하지 않는다.
