# Task M900 #539 구현계획서

## Stage 1 — 새 후보 기준

이슈·브랜치·오늘할일·계획서를 먼저 기록하고 네 bundle 버전을 0.2.2(20)로 맞춘다. rehearsal/publish 및 promotion 기본값을 정렬한다. previous v0.2.0, core/Studio v0.8.6 및 content gate를 확인한다. 기존 v0.2.1 tag/자산은 유지한다.

## Stage 2 — 사용자 문구와 검증

v0.2.0 이후 PR 본문·보고서·이슈로 포함 변경을 대조한다. v0.2.2 장기 기록과 Pages 후보를 작성하며 설치 색인 지연 안내를 유지한다. 미공개 v0.2.1 페이지는 후보 보존 안내로 바꾸고 작동하지 않는 DMG 링크를 제거한다. 새 public asset gate로 공개 전 사이트 전환을 차단한다. 릴리즈 본문·페이지·bundle·workflow 검증 및 Browser 화면 검토를 수행한다.

## Stage 3 — 준비 보고·PR

최종 준비 보고서와 하이퍼-워터폴 PR 본문·스크린샷을 작성한다. devel 대상 PR을 검토·CI 통과 후 병합한다. 준비 완료와 실제 DMG 수용 완료를 구분한다.

## Stage 4 — 새 불변 DMG 수용

main 릴리즈 PR을 검토·검증·병합하고 source SHA를 고정한 새 v0.2.2 tag로 draft=true/prerelease=false 서명·공증 DMG를 만든다. 양 VM schema 3 최초 설치·동일 버전 재설치·종료 후 검색·lifecycle·cleanup을 실행한다. 같은 hash로 실제 Mac HWP/HWPX 저장·닫기·앱 종료·실패·취소, Spotlight/Finder를 확인한다. 실패·진단·재시험 결과는 별도 보존한다.

2026-09-14 재개: Stage 4.1은 draft 파일·양 VM·실제 Mac에서 완료한 문서/Finder/명령 검색 증거를 기록한다. Spotlight GUI는 창 접근 후 별도로 판정하며, 미완료 항목을 PASS로 합산하지 않는다. 읽기 전용 승격 검증과 실제 공개를 구분한다. 21:33 후속 Stage 4.2에서 사용자가 연 Spotlight의 영문/한글 검색·결과 열기를 확인했으며 화면과 최종 공개 전 판정을 기록한다.

## Stage 5 — 공개와 이전 버전 업데이트

최종 검증 결과·한계·hash를 제시한 뒤 승인된 같은 DMG를 승격한다. 공개 URL에서 다시 받은 hash·Pages/appcast 및 실제 0.2.0 → 0.2.2 Sparkle 다운로드·설치·자동 재실행·검색·확장을 확인한다. 그 전에는 상위 검색 이슈를 닫지 않는다.
