# Task M020 #470 최종 결과보고서

## 결과

Known RenderNodeType payload가 손상되면 variant/schema path/cause를 가진 오류로 실패하며, future 단일 variant는 `.unknown`으로 수용한다. 기존 optional `renderPageTree`는 유지하고 `renderPageTreeThrowing`을 추가했다. wrapper는 로그를 출력하지 않고 문서 값이나 underlying debugDescription을 오류에 저장하지 않는다. native smoke/CI가 진단을 명시적으로 소비한다.

실제 current core의 usize marker가 Swift Int 범위를 넘는 문제도 수정했다. section/para/control/char_start metadata를 UInt로 보존하여 KTX/request의 머리말·꼬리말 텍스트가 더 이상 unknown으로 사라지지 않는다. 필수 필드를 optional로 완화하거나 core/renderer layout을 바꾸지 않았다.

## 검증과 한계

- decoder 성공/실패/forward compatibility/privacy/UInt marker 18개 계약 통과.
- HWP 3종/HWPX 1종, 실제 FFI page 경계와 null-output, HostApp Debug compile/link, no-AppKit 통과.
- KTX/request의 core/native 비교 이미지와 이전 decoder 비교를 확인했다. TextRun은 각각 410→415, 102→103으로 복원됐다. core/native pixel parity는 보증하지 않는다.
- 표준 개발 앱/appex unregister 실행. PlugInKit에는 기존 설치본만 확인했지만 전역 hygiene는 기존 LS 경로와 두 설치본 때문에 통과하지 않았고 설치본을 임의 삭제하지 않았다.

상세: [Stage 1](../working/task_m020_470_stage1.md), [Stage 2](../working/task_m020_470_stage2.md), [Stage 3](../working/task_m020_470_stage3.md).

## PR 관계

선행 #394 PR #503 head `de4d374`를 상속한다. 자신의 변경은 `de4d374..HEAD`, base는 devel이다. 앞 PR 병합 전 누적 diff가 보인다. 다음 #469가 producer golden을 추가하며, #337과 public release는 이번 범위가 아니다. 사용자 리뷰를 위해 merge하지 않는다.
