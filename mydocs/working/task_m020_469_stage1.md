# Task M020 #469 Stage 1 완료보고서

## 구현

`render_tree_golden` Rust example은 현재 Cargo.lock의 pinned core를 native architecture로 빌드하고 기존 FFI와 같은 root serialization을 출력한다. writer/verifier는 Python 3.11+ TOML parser로 source/Cargo/ref/features를 확인한다. source·sample SHA256·page·recipe·tree SHA256와 전체 tree를 한 JSON 파일에 담아 atomic replace한다. build/consumer 실패 시 기존 golden을 보존한다.

JSON key/공백만 canonical 정리하고 필드·배열 순서·큰 unsigned 정수는 보존한다. duplicate key와 비유한 수치는 실패한다. 일반 verifier는 tracked 파일을 자동 수정하지 않는다. 별도 Swift runner는 실제 TextRun/Table/TextLine이 decode되는지도 검사한다.

## 검증

- 실제 producer JSON과 #470 FFI dump를 JSON 값으로 비교: 동일.
- 실제 writer와 verifier 성공, TextRun=103/Table=4/TextLine=65.
- producer 1차 native cached build 2.33초, 후속 0.34초. standalone producer가 universal archive에 의존하지 않음을 확인.
- isolated helper fixture 15개 통과: 반복 동일성, UInt64 보존, array 순서, duplicate/nonfinite 거부, source/features/pin/sample/hash/output drift, verifier 쓰기 금지, 실패 writer 보존, commit pin 지원.
- Rustfmt, shell syntax, diff check 통과.

산출물: `scripts/ci/fixtures/render-tree/request-page0.json`; 로그 `build.noindex/task469/`. golden은 request 0번 page의 계약 gate이며 모든 node나 pixel parity를 보증하지 않는다.
