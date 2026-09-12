# Task M020 #339 Stage 1 완료보고서

## core 추출 후보·모델과 샘플 조사

## 확인 결과

고정 core의 `parser::parse_document()`는 HWP3/HWP5/HWPX/HML을 공통 Document로 읽는다. `DocumentCore::from_bytes()`는 shaping/compose/pagination을 수행한다. Unicode JSON은 CP949 수치 참조 없이 텍스트를 반환하지만 표·글상자 중심의 scanner를 사용한다. 페이지 텍스트는 render tree를 만들며 display text를 복구한다. Semantic IR은 위치 옵션을 꺼도 수식 변환을 수행하며 HWP3와 배포용 문서를 거부한다.

## 샘플과 후속 검증

저장소의 한글/영문 혼합, 중첩 표, 표를 가진 글상자, 수식, 메모 및 HWPX 본문 샘플로 후보 경로의 실제 비용을 비교한다. 정책 결정은 소스상 지원 범위와 실행 결과를 함께 사용한다. HWP3·보호 파일·한도는 #340 ABI 회귀 fixture로 확인한다.

## 검증

- core checkout HEAD와 rhwp-core.lock의 v0.8.6 resolved commit 일치 확인.
- 공개 API와 model 컨트롤의 직접 소스 확인 완료.
- 구현계획을 구체화했으며 제품 ABI/동작 변경은 아직 없다.
