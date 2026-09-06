# Task M020 #340 최종 결과보고서

## 작업 요약

문서 handle과 layout 없이 검색용 UTF-8 본문을 추출하는 C ABI를 추가했다. 평문 HWP3/HWP5/HWPX, 모델 포함/제외, 보호 거부, 32 MiB 입력과 파싱 후 출력/순회 한도, 명시 길이와 bytes 해제 계약을 구현했다.

## 변경 파일과 영향

| 영역 | 영향 |
|---|---|
| RustBridge/src/{lib,text,text_tests}.rs | 신규 상태·FFI, 파싱/모델 순회, 회귀 테스트 |
| RustBridge/cbindgen.toml, rhwp-ffi-symbols.txt | 신규 API/상수/상태의 공개 C 계약 |
| rhwp-core.lock | 의도적 ABI 변경의 산출물 reference 갱신, core pin 유지 |
| .github/workflows/pr-ci.yml | Rust 변경 시 전체 bridge 테스트 실행 |
| RustBridge/README.md, mydocs/tech/spotlight_text_extraction_contract.md | 사용법·보호 헤더 사전 검사 설명 |
| mydocs/plans/working/orders | 단계 계획·보고·완료 기록 |

## 전후 비교

기존 ABI는 문서 handle과 렌더 중심이었다. 신규 API는 본문 파싱과 검색 정책을 독립 실행하며 빈 결과와 부분/오류를 구분한다. HWP5 보호 헤더는 본문 해석 전에 거부한다. 기존 viewer/Swift API와 core pin은 유지한다.

## 검증 결과

| 수용 기준 | 결과 |
|---|---|
| Rust 전체 회귀 | OK — 19 passed, 0 failed |
| 한글/emoji/중첩/메모 제외/한도/소유권 | OK — 합성 모델 및 실제 직렬화 bytes |
| HWP3/HWP5/HWPX, 보호·DRM·손상 | OK — 성공 및 본문 없는 실패 상태 구분 |
| arm64/x86_64 및 portable ABI/reference | OK |
| 실제 C caller 추출/해제 | OK — arm64, 두 target header syntax |
| pinned render tree golden | OK — producer/decoder 일치 |
| 기존 native 렌더링 | OK — KTX/request/exam_kor 3/3 |
| no-AppKit/format/YAML/diff | OK |
| macOS 12 runtime | MISS — 환경 없음 |

## 잔여 위험과 후속 작업

파싱 후 출력/노드/깊이 제한은 parser 내부 CPU/RSS 상한이나 OOM 복구를 보장하지 않는다. 일반 text의 화면 가시성을 판단하지 않으며 OCR/동적 field 계산은 제공하지 않는다. #341 CFPlugIn 통합, #342 실제 검색과 보호 변경 시 재색인 제거를 검증한다.

## 리뷰 인계

사용자 지시에 따라 단계 승인 없이 구현·검증하고 devel 대상 PR로 제출한다. PR에 계획/Stage/commit/최종 보고서를 SHA로 연결한다. 이번 API 변경은 독립 UI가 없어 공개 screenshot을 만들지 않았으며 #342 실제 검색 화면을 수집한다. 병합과 공개 배포는 사용자 리뷰 후 별도로 결정한다.
