# Task M020 #340 Stage 2 완료보고서

## C ABI·한도·실패·수명 검증

## 구현과 계약

`rhwp_extract_text_utf8`와 9개 `RhwpTextStatus`, 공유 입력 상한을 추가했다. 각 유효 output slot 초기화, slice 이전 길이 검사, unwind 경계, 명시 길이 bytes와 기존 해제를 적용했다. HWP5는 strict/lenient container에서 최대 256-byte FileHeader를 먼저 검사해 보호 본문 해석을 피한다. 전체 본문은 한 번 파싱한다.

cbindgen export와 FFI symbol lock, RustBridge 안내 및 #339 계약 설명을 맞췄다. PR CI의 Rust 변경 검사에 전체 Rust bridge tests를 연결했다.

## 검증

- 전체 Rust release tests: **19 passed, 0 failed** (기존 image/보호 계약 포함).
- 합성 HWP5/HWPX/HWP3 본문, 반복 20회 allocation/free, 1 MiB 한글 scalar 절단, 빈 본문, NULL slot/입력 한도, unwind 상태를 확인했다.
- 암호 HWPX, HWP3 암호 헤더, HWP5 암호/배포용 헤더, DRM, 손상 HWP/HWPX는 본문을 반환하지 않는다.
- 중첩 80단 그룹의 깊이 중단과 노드 한도, field command/memo payload 제외를 확인했다.
- cbindgen 생성 header에 상태 0–8, 입력 상한 macro와 새 함수 signature를 확인했다.

## 구현 중 확인한 사실

합성 HWP5의 raw stream/provenance를 무효화해야 수정 text가 직렬화되며 평문 exporter는 보호 flag를 제거한다. fixture가 이 계약을 따르도록 수정했다. HWPX로 식별되지 않는 손상 ZIP은 UNSUPPORTED, 유효 package 엔트리가 있는 손상 HWPX는 PARSE_ERROR다.
