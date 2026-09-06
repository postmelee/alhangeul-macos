# Task M020 #394 Stage 4 — PR 리뷰 보완

PR #503의 리뷰 1–6을 반영했다. writer/verifier는 header가 앞선 공통 LOCK_ARTIFACTS를 순회한다. legacy env는 legacy alias와 strict에서만 검사하며 build-only/portable/update는 무시한다. 동일 옵션도 계속 중복으로 거부하되 이유를 명시한다. RustBridge/CONTRIBUTING의 기본 명령과 strict 자동 runner가 없는 현재 정책을 정렬했다.

검증: 격리 CLI 24개, shell syntax, git diff --check 통과. 추가 artifact의 metadata 누락 차단과 명시 writer 기록 후 strict 검증, env 비적용 경로, 반복 옵션 진단을 포함한다. 명시 update fixture 외에는 lock 불변을 단언한다. 실제 portable build와 PR CI 결과는 게시 후 보완 코멘트에 실행 결과를 연결한다. core/Cargo/FFI lock은 변경하지 않았다.

근거: `build.noindex/task394/review-cli.log`, `review-portable.log`. 기존 strict 불일치를 새 lock hash로 수용하지 않았고 scheduled strict job은 기준 환경 재현성을 확보한 뒤 별도 도입한다.
