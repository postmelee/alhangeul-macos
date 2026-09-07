# Task M020 #339 최종 결과보고서

## 작업 요약

검색용 파싱 전용 IR 순회, 포함/제외 정책, 문자 정규화, 자원 한도, 9개 C ABI 상태와 소유권을 확정했다. core v0.8.6 pin과 제품 ABI는 유지했다.

## 변경 파일과 영향

| 파일 | 영향 |
|---|---|
| mydocs/tech/spotlight_text_extraction_contract.md | #340 구현의 검색·실패·한도·수명 계약 |
| RustBridge/examples/spotlight_extraction_probe.rs | 공개 샘플의 기존 추출 경로 측정, 제품에 포함되지 않음 |
| mydocs/plans/task_m020_339*.md | 수행/구현 계획 |
| mydocs/working/task_m020_339_stage*.md | 3개 단계 근거 |
| mydocs/orders/20260907.md | #339 완료 기록 |

## 전후 비교

추출 후보만 나열했던 상태에서 parser 기반 경로와 구체적인 수용 사례를 확정했다. 표시 순서·가시성 필터·OCR·암호 해제를 지원한다고 확대하지 않는다.

## 검증 결과

| 기준 | 결과 |
|---|---|
| 6개 공개 HWP/HWPX의 후보 측정 | OK — 6/6 parse/Semantic/layout, page error 0 |
| 계약의 상태·한도·해제/보호 정책 | OK — 문서 교차 검증 |
| Rust format / git diff | OK — cargo fmt --check, git diff --check |
| 실제 신규 ABI 동작 | MISS — #340 구현/검증 대상 |
| macOS 12 runtime | MISS — 사용 가능한 환경 없음 |

## 잔여 위험과 후속 작업

측정은 단일 실행 관찰이며 cold/warm 통제 또는 속도 보장이 아니다. parser 전체 CPU/RSS/abort는 후처리 한도나 unwind로 제한할 수 없다. #340 구현, #341 통합, #342 실제 색인·삭제 검증으로 이어진다.

## 리뷰 인계

추가 단계 승인은 사용자 지시에 따라 생략했다. .github/pull_request_template.md의 모든 필수 섹션과 SHA 문서/Stage/commit 링크를 사용한다. 문서·CLI 비교 작업이라 UI 스크린샷 대상은 없고 실제 검색 화면은 #342 작업에서 수집한다.
