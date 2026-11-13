# Task #612 — 구현계획서

## 승인 및 기준
2026-11-14 PR 생성까지의 포괄 단계 승인을 적용한다. base=devel cd78530b, core=v0.9.0 c9095c5. 개체 단위 resvg 함수는 core 비공개 API이며 공개 FFI는 페이지 단위다. 이번 수정은 공개 API를 사용하는 선택적 Skia 페이지 경로로 진행한다. 일반 페이지와 실패 시 CoreGraphics를 유지하며 전역 기본 전환은 하지 않는다.

## Stage 1 — 자산·재현·정책 확정
- HWP/PDF 원본을 samples/issue7406에 복사하고 출처·해시를 기록한다.
- 기존 CoreGraphics/Skia 결과와 render tree를 수집한다.
- 검증: 원본 해시, smoke-quicklook-skia-policy.sh, render-debug-compare.sh.
- 커밋: Task #612 Stage 1: OLE 차트 회귀 자산과 기준 고정.

## Stage 2 — 선택적 Quick Look 경로
- 페이지별 RawSvg를 검사하는 제한된 XML 정책을 구현한다. 일반 문서 및 단일 래스터 RawSvg 경로는 보존한다.
- 허용된 벡터 조각이 있고 다른 미지원 조각이 없는 경우만 Skia를 선택한다. malformed/외부 참조/과대/과도한 구조는 전환하지 않는다.
- 단일 페이지 PNG와 다중 페이지 PDF에 같은 선택기를 연결한다.
- forceDefaultFonts, stale/취소, Skia 실패의 기존 fallback을 보존한다. 요청 모드와 실제 backend를 진단으로 구분한다.
- 검증: XML 정책·중첩 노드·페이지별 선택·PNG 출력·fallback runner, 기존 Quick Look policy smoke.
- 커밋: Task #612 Stage 2: 제한된 RawSvg 페이지의 Skia 선택과 fallback.

## Stage 3 — 통합 검증·보고·PR
- 차트·축·범례·캡션 영역의 before/after/reference 이미지를 생성하고 직접 비교한다.
- check-no-appkit, validate-stage3-render, render-debug-compare, HostApp/Preview build를 수행한다.
- 실제 설치 후보 Finder smoke의 실행 여부를 별도 기록한다. 설치본 교체/등록 변경은 이번 작업에서 하지 않는다.
- 소스·자산 hash, 통과한 회귀, 한계·후속 작업을 보고한다.
- 커밋: Task #612 Stage 3 + 최종 보고서: 회귀 검증과 PR 준비.

## 수용 기준
- 샘플에서 SVG 자리표시자 대신 차트·축·범례가 표시되고 캡션이 보존된다.
- 일반 문서는 CoreGraphics, 허용된 RawSvg 페이지만 Skia를 사용한다.
- 위험/미지원 입력과 글꼴 공급 실패의 기존 fallback, 요청 현재성 검사는 유지된다.
- raw 문서/경로를 로그에 노출하지 않는다. 원본 hash를 보존한다.
- 실제 Finder 설치 smoke 및 최소 OS/Intel runtime 미실행은 통과로 표기하지 않는다.
