# Task M900 #532 구현계획서

## Stage 1 — 기준·버전 고정

최신 공개 v0.2.0과 upstream v0.8.6, main/devel 콘텐츠를 확인한다. 포함 PR 본문·보고서를 대조하고 HostApp/Quick Look/Thumbnail/Spotlight의 버전을 0.2.1(19)로 맞춘다. rehearsal/publish 기본값을 0.2.1, previous v0.2.0으로 정렬한다. bundle 계약과 diff를 검증한다.

## Stage 2 — 릴리즈 문구와 배포 후보 기록

v0.2.0 이후 포함 PR 분석, 변경 요약·rhwp 유지·사용자 앱 개선·미완료 이슈를 구분한 v0.2.1 기록과 Pages 후보를 작성한다. 설치 후 색인 대기, 동일 버전 재설치 보완과 알려진 한계를 명시한다. 새 버전 다운로드 링크의 public asset gate로 공개 전 자동 배포를 차단한다. 사용자 문구는 공개 시점 기준의 후보로 작성하며 현재 공개 사이트는 실제 승격 전까지 유지한다. 릴리즈 본문 생성·템플릿·Pages/HTML·workflow 검사를 실행한다.

## Stage 3 — 준비 보고와 PR

최종 보고서·오늘할일을 갱신하고 템플릿을 준수한 devel 대상 준비 PR을 생성한다. CI를 확인한다. 앱 소스는 재설치 구현 외에 바꾸지 않으며 새 signed DMG 실행 전 단계임을 표시한다.

## Stage 4 — 고정된 서명·공증 후보 수용

준비 PR과 main 릴리즈 PR 병합 후 정확한 source SHA/tag로 draft DMG를 만든다. 양 VM에서 schema 2 최초 설치·재설치·종료 후 검색·33 lifecycle·cleanup을 실행한다. 같은 DMG hash로 실제 Mac 설치·Spotlight/Finder/문서 기능을 확인한다. 실패·진단·재시험은 분리 기록한다.

## Stage 5 — 동일 DMG 공개 및 실제 업데이트

최종 검증과 공개 부작용을 제시한 뒤 승인된 동일 DMG를 승격한다. 공개 URL hash·Pages/appcast와 실제 0.2.0 → 0.2.1 Sparkle 업데이트·자동 재실행·검색·확장을 확인한다. 그 결과로 #513 / #337 / #520 종료를 판단한다. 새 후보 오류가 있으면 공개 파일 교체로 숨기지 않는다.
