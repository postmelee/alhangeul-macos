# Task M020 #338 최종 결과보고서

## 작업 요약

- 이슈: [#338 Spotlight/mdimporter 구조와 검증 기준](https://github.com/postmelee/alhangeul-macos/issues/338)
- 상위 #337, M020 / v0.2 Mac 통합, 3단계 완료.
- 앱과 독립 실행하는 CFPlugIn importer 및 설치본 검증·복원 계약을 확정했다. 승인된 #337–#343 이슈 최신화도 GitHub에서 완료했다.

## 변경 파일과 영향

| 파일 | 내용 |
|---|---|
| mydocs/tech/spotlight_importer_design.md | bundle·UTI·metadata·서명·검증/복원 설계 |
| mydocs/plans/task_m020_338*.md | 수행/구현 계획과 승인 범위 |
| mydocs/working/task_m020_338_stage*.md | 조사·설계·검증의 3단계 근거 |
| mydocs/orders/20260907.md | 6개 순차 작업 등록, #338 완료 |

## 전후 비교

추상적인 importer 계획을 CFPlugIn callback·UTI 9종·bundle 위치·시험/색인/검색 분리·등록 복원 계약으로 구체화했다. 제품 소스와 core pin 변경은 0개다.

## 검증 결과

| 수용 기준 | 결과 |
|---|---|
| 현재 SDK의 CFPlugIn interface | OK — clang arm64/x86_64 macOS 12 target syntax |
| 앱 UTI 9종과 설계 일치 | OK — plist Python 대조 |
| 실제 검증 환경 상태 | OK — root indexing enabled, mds running, 기존 HWP importer 없음 |
| mdimport 시험과 실제 색인의 구분 | OK — 현재 도움말 대조 |
| 파일 diff 형식 | OK — git diff --check |
| macOS 12 runtime | MISS — 사용자 확인: 사용 가능한 기기/VM 없음 |

## 잔여 위험과 후속 작업

본문 품질·비용과 ABI 계약은 #339, 실제 구현·설치본 색인 성공은 #340–#342에서 확인한다. SDK compile을 최소 OS runtime 성공으로 확대하지 않는다. Xcode의 CSImportExtension 템플릿 존재만으로 macOS 동작을 가정하지 않는다.

## 리뷰 인계

단계별 추가 승인은 사용자 지시에 따라 생략했고 구현 전 계획과 단계 보고서를 남겼다. PR은 .github/pull_request_template.md 기준으로 제출하고 사용자 리뷰를 기다린다. 이 PR은 UI 변경이 없어 스크린샷 대상이 아니다.
