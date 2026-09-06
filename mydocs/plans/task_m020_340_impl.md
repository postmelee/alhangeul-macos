# Task M020 #340 구현계획서

## Stage 1: IR 순회·UTF-8 본문 추출 구현

#339 계약에 따라 RustBridge 내부에 독립 text 모듈을 만든다. parse_document 1회, bytes 기반 형식 판별과 보호 정책, 순회/출력 한도를 적용한다. 문단과 하위 컨트롤을 한정된 재귀 깊이로 순회하고 whitespace를 streaming 정규화하여 중간 거대 문자열을 만들지 않는다. 순회 제한과 모델 포함/제외를 synthetic unit test로 검증한다.

## Stage 2: C ABI·한도·실패·수명 검증

RhwpTextStatus, 입력 상한 constant, rhwp_extract_text_utf8를 C ABI에 추가한다. output slot 초기화, panic 경계, 명시 길이 bytes 소유권과 기존 해제를 검증한다. HWP5/HWPX 직렬화 fixture와 HWP3 합성 bytes, 보호/DRM/손상/빈/초과 fixture를 사용한다. cbindgen export와 ABI symbol lock을 갱신한다.

## Stage 3: universal artifact·기존 회귀 검증 및 보고

Rust 전체 tests, 두 architecture staticlib와 portable ABI/artifact 확인, no-AppKit 및 기존 render tree golden/native smoke를 실행한다. 의도적 ABI 변화에 한해 reference artifact metadata를 갱신하며 core pin은 유지한다. 실제 결과/제한을 보고서에 남겨 devel 대상 PR을 만든다.

## 수용 기준

계약의 본문 포함·제외와 9개 상태, null/길이/UTF-8/한도/해제 조건을 실증한다. 앱/renderer API와 core pin 변화는 없어야 한다. macOS 12 runtime은 미실행으로 남긴다.
