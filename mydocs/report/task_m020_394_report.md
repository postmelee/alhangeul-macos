# Task M020 #394 최종 결과보고서

## 결과

일반 로컬·CI·release 검증은 `--verify-portable`, 기준 환경 byte 검증은 `--verify-strict`로 명시한다. 기존 `--verify-lock`과 skip env의 조합은 호환 경고와 함께 유지한다. strict는 skip env로 약화할 수 없다. 검증 중 lock을 수정하지 않는다.

portable은 staticlib byte hash/size 비교만 제외한다. source/Cargo 계약, generated header hash/size, FFI symbols, archive 존재와 lock metadata는 계속 차단 기준이다. header 검증을 먼저 수행하여 strict artifact 실패와 source/ABI 오류를 구분한다. CI/release summary와 운영 문서를 동일하게 정렬했다.

## 검증

격리 fake toolchain의 전체 CLI 회귀 18개, 모든 shell syntax와 workflow YAML parse, 실제 arm64/x86_64 portable build 및 XCFramework 생성 통과. strict는 기존 reference와 다른 로컬 archive를 예상된 오류로 차단했다. core pin/Cargo.lock/FFI symbol lock 불변, no-AppKit와 core build-info 검증 통과. CI 실행은 PR 게시 후 별도 확인한다.

상세: [Stage 1](../working/task_m020_394_stage1.md), [Stage 2](../working/task_m020_394_stage2.md), [Stage 3](../working/task_m020_394_stage3.md).

## 선행 PR #462 판정과 후속

PR #462는 현재 초안 병합 보류다. 합성 중첩 트리에서 depth 12 방문 수가 12,286 → 169로 감소했지만 채워진 픽셀이 10,000 → 6,000으로 달라졌다. 깊이 1은 동등하고 깊이 2부터 내부 clipping 결과가 바뀐다. 실제 문서의 정답을 이 fixture만으로 결정하지 않으며 중첩 overflow 의미·기대 출력 회귀가 필요하다. [Stage 1](../working/task_m020_394_stage1.md)에 재현 조건을 기록했다. PR code/state/public comment는 변경하지 않았다.

#470 → #469 → #474는 선행 작업을 상속한 별도 PR로 진행한다. 네 PR은 devel 대상으로 생성하며 선행 PR 병합 전에는 누적 diff가 보인다. 작업지시자가 리뷰·병합을 결정한다. #337과 release 실행은 이번 배치에 포함하지 않는다.
