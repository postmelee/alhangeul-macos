# Task M020 #340 Stage 1 완료보고서

## IR 순회·UTF-8 본문 추출 구현

## 구현

제품과 독립적인 `text` 모듈에 공통 모델 순회와 streaming whitespace 정규화를 구현했다. 표·중첩·그룹 글상자·머리말/꼬리말·각주/미주·수식·양식/Ruby 본문을 결정적 순서로 수집한다. 숨은 설명과 field payload는 순회하지 않는다. 출력 bytes, 방문 단위, 깊이 한도에서 UTF-8을 깨지 않고 중단한다.

## 검증

`MACOSX_DEPLOYMENT_TARGET=12.0 cargo test --manifest-path RustBridge/Cargo.toml --locked --offline --release --target aarch64-apple-darwin text::tests` — 3 passed. Unicode/제어문자/구분자, 복합 모델 기대 문자열, UTF-8 exact fit와 bytes/node/depth 제한을 확인했다. 초기 테스트의 Ruby 모델 타입 오류를 수정하고 재실행했다.

## 다음 단계

파싱과 형식/보호 판정, C ABI 상태와 소유권을 연결하고 실제 직렬화 bytes 및 FFI 경계로 검증한다. 현재 모듈은 아직 외부 ABI로 노출하지 않았다.
