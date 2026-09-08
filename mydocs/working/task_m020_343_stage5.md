# Task M020 #343 Stage 5 — 리뷰 지원 문구와 검증 근거 정렬

## 변경

릴리스 초안의 결과 표를 2026-09-09 Stage 5 및 post-reboot-results.json에 연결했다. 과거 FAIL/MISS와 최신 재실행 결과를 구분하며, 최초 설치 자동 발견은 #513 후속 이슈의 책임으로 유지한다.

스택 병합 순서 #507 → #508 → #509 → #510 → #511 → #512 및 기본 브랜치 main README 반영 시점을 명시했다. 사용자 안내의 내부 보고서 링크는 maintainer 빌드·실행 절차로 옮기고, 설계의 검증 요약은 최신 실행 기록과 함께 점검하도록 안내했다.

## 검증

- 변경 문서의 상대 파일 링크 33개 및 `git diff --check`: PASS.
- 이 단계의 Sources·project.yml·core/Cargo lock·공개 docs 자산 변경 없음: PASS.
- 선행 변경을 합친 현재 트리에서 bundle checker, bundle 회귀 5 tests, 시스템 smoke 회귀 12 tests, shell syntax 및 cargo fmt: PASS. 시스템 회귀의 FAIL/MISS 출력은 음성 fixture의 예상 진단이며 unittest 전체는 성공했다.
- Rust release 20 tests와 실제 callback 11사례 + NDEBUG 양성/음성 2사례는 이번 리뷰 보완의 선행 단계에서 통과했다. 현재 단계에서는 제품 코드를 변경하지 않아 앱 재빌드·시스템 재등록을 반복하지 않았다.

## 인계

실제 Spotlight 화면은 #342 Stage 5에서 이미 확보한 증거를 유지한다. 이번 문서 변경은 최초 설치 해결·최소 OS 실행·공개 서명/공증·업데이트 검증이나 릴리스 실행을 대신하지 않는다.
