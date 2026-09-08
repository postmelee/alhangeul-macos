# Task M020 #340 Stage 4 — 공개 샘플 회귀 단언 보완

## 변경과 근거

PR #509 리뷰의 빈 needle 4개를 제거했다. 실제 pinned parser의 구조를 확인해 중첩 표 셀의 `SFR-SAAS-009`, 글상자 안 표의 `잔류염소, pH, 탁도, 철, 동, 온도`, Equation script의 `{최저입찰가격} over {해당입찰가격}`, HWPX의 `안녕 Hello 123`을 단언한다. 빈 needle 자체도 거부한다.

PR #508의 field-01-memo.hwp 지적은 실제 모델에 맞춰 반영했다. 이 샘플에서 확인된 숨은 문자열은 Field.command의 HelpState 도움말이다. 모델에 해당 문자열이 존재함을 먼저 단언한 뒤 FFI 출력에서 도움말·명령을 제외하고 회사명/목차 표시 본문은 보존함을 확인한다. 이 시험을 실제 메모 payload 회귀로 부풀리지 않는다. 메모 전용 payload 제외는 기존 합성 모델 테스트가 담당한다.

## 검증

- `MACOSX_DEPLOYMENT_TARGET=12.0 cargo test --manifest-path RustBridge/Cargo.toml --locked --offline --release --target aarch64-apple-darwin`: PASS — 20 tests.
- `cargo fmt --manifest-path RustBridge/Cargo.toml --check`, `git diff --check`: PASS.
- 제품 구현·ABI·core pin·공개 앱 자산 변경 없음. 기존 core는 이 단계 전후 모두 v0.8.6이다.

## 인계

깊이 한도 초과의 전체 순회 중단은 기존 구현·합성 회귀를 유지하고 계약 문구에서 정확히 설명한다. 공개 샘플 추가와 숨은 도움말 제외는 이 PR에서 해결했으며 메모리/수명 계약은 바꾸지 않았다.
