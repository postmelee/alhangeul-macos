# Task M020 #339 Stage 2 완료보고서

## 추출 품질·비용 비교와 계약 확정

## 결과

`spotlight_text_extraction_contract.md`에 파싱 전용 선택, 모델 범위, 32 MiB/1 MiB/200,000 nodes/64 depth 한도와 9개 상태·소유권을 확정했다. 6개 공개 샘플에서 parse/Semantic/DocumentCore 및 page extraction은 모두 성공했다. 상세 ms/bytes는 계약 문서에 기록했다.

## 검증과 제한

- release aarch64-apple-darwin 측정 완료, page error 0.
- 최초 target 미지정 sandbox 실행은 Skia build script 네트워크에서 실패했다. 기존 universal 빌드와 같은 명시 target/환경으로 재실행하여 성공했다.
- 단일 실행 수치는 통계적 성능 보장이 아니다. parser 내부 전체 CPU/RSS 상한도 주장하지 않는다.
- 실제 추출 품질/보호 fixture/한도/ABI는 #340 단계에서 계약에 맞춰 검증한다.
