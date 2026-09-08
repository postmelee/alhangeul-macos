# Task M020 #339 Stage 4 — 깊이 계약과 실물 필드 검증 인계

루트 section을 0으로 시작하고 64 초과에서 TRUNCATED가 되는 경계를 명시했다. 깊이를 포함한 어느 한도든 초과하면 전역 truncated로 이후 본문 순회를 멈추는 현재 동작을 문서화했다. 해당 가지만 건너뛰는 구현 변경은 prefix 반환 계약을 바꾸므로 적용하지 않았다.

local/task340의 Walker::visit/character와 stops_inside_deep_groups_and_preserves_only_visited_prefix 테스트를 대조했다. 해당 동작은 PR #509 보완 후 Rust 전체 20개 테스트에서 통과했다. git diff --check도 통과했다.

field-01-memo.hwp는 실제 모델에서 Field HelpState 도움말을 확인한 뒤 본문 제외를 검사하도록 PR #509에서 보완했다. 메모 전용 payload와 실물 도움말 검증을 혼동하지 않는다. 후보 측정 example의 CI 분류 및 parser 보호 판정은 이번 계약 정정에서 변경하지 않는다.
