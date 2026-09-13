# Task M900 #535 Stage 3 완료보고서

고정 후보 tag와 별도 검증 도구 SHA를 Git 이력에서 검증한다. tag 실행은 같은 SHA, main 실행은 후보 descendant 및 origin/main 포함을 요구한다. 허용 파일은 두 release workflow, 설치/승격/Spotlight 검증 도구와 해당 회귀 파일, mydocs로 한정한다. 제품·의존성·fixture 생성기·공개 문구·임의 스크립트 변경을 거절한다.

fixture job은 고정 후보를 추가 checkout해 원본 Rust 예제를 사용한다. 각 설치 job의 result는 source proof를 보존하며 승격 시 API run·artifact의 head SHA와 result의 harness SHA, Git에서 재계산한 proof를 대조한다. 공개 직전 재검사도 동일 proof를 요구한다. 로컬 CLI 회귀는 실제 임시 Git 저장소·JSON/ZIP·가짜 GitHub 응답으로 실행하고 실제 배포 명령은 실행하지 않는다.

최종 검증: 운영 smoke 40개, 설치 25개, 승격 16개 총 81개 PASS. 실제 Git 이력으로 미병합 도구·tag 이동·제품/fixture/의존성 변경·dirty checkout 거절, 별도 main 도구 수용 및 artifact/result 출처 바꿔치기 거절을 포함한다. `actionlint` 대상 workflow 2개, `git diff --check` PASS. 최초 오류와 상태 저장 동시 실패 보존 및 CLI 회귀의 bytecode 부산물 방지도 보완했다.

runbook의 schema 3/검색 유지·복구/도구 출처 기준과 v0.2.1 장기 기록을 최신화했다. 사용자 UI 변경은 없어 새로운 앱 화면 스크린샷을 만들지 않았다. 실제 signed DMG의 새 VM 실행·Mac UI·Sparkle 결과는 이번 로컬 회귀와 구분하며 #532 에서 후속 수용한다.
