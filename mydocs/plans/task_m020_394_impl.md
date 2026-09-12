# Task M020 #394 구현계획서

## Stage 1 — 모드와 실패 계약

`build-rust-macos.sh`에 portable/strict/legacy 모드를 추가한다. portable에서도 누락·손상 lock metadata를 실패시키고 header를 staticlib보다 먼저 검사하여 staticlib byte 차이가 ABI 실패를 가리지 않도록 한다. fixture는 독립 임시 root와 fake build tools를 사용해 전체 CLI의 성공·실패·lock 불변을 검사한다.

검증: CLI help/옵션 충돌, portable archive 차이 허용, strict/legacy archive 차이 차단, legacy skip 호환, env 오류, source commit/header/FFI/metadata 손상 차단. 단계 보고서와 코드를 함께 커밋한다.

## Stage 2 — 호출부와 운영 안내

PR CI/release rehearsal/publish와 로컬 package/release script가 `--verify-portable`을 명시한다. 기존 skip env를 workflow에서 제거하고 summary에 모드를 표시한다. 관련 매뉴얼은 동일 계약을 안내하고 historical report는 수정하지 않는다.

검증: 모든 shell syntax, YAML parse, fixture, classification helper 결과. 단계 보고서와 함께 커밋한다.

## Stage 3 — 실제 검증과 PR

로컬 core build에서 portable 통과를 확인한다. strict 실행 결과는 일치 또는 reference byte mismatch로 기록하고 source/header/ABI 실패와 구분한다. `rhwp-core.lock`, Cargo pin, symbol lock 불변과 git diff를 확인한다. 최종 보고서·오늘할일을 커밋하고 `publish/task394`를 push하여 devel 대상 PR을 생성한다. merge하지 않는다.

## Stage 4 — PR #503 리뷰 보완

작업지시자가 리뷰 검토서의 권고 순서와 공개 보완 코멘트 게시를 승인했다. writer/verifier의 artifact 목록을 공유하고 header 우선순위를 유지한다. legacy env 검사는 legacy alias/strict에 한정하며 중복 모드는 계속 거부하되 오류를 명확히 한다. 공개 README/CONTRIBUTING과 strict 자동 job 부재를 문서화한다. 격리 CLI는 세 번째 artifact의 기록·검증과 env 비적용 경로까지 검증한다. 검증 후 보고서·오늘할일·기존 PR을 갱신하고 후속 브랜치에 전달한다.
