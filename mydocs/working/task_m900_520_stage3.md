# Task M900 #520 Stage 3 — 버전·문구·준비 PR

## 변경 결과

HostApp/Quick Look/Thumbnail/Spotlight 4개 bundle을 0.2.0/18로 정렬했다. core/Studio는 v0.8.6 유지, rehearsal/draft 기본값은 0.2.0과 직전 공개 v0.1.11이다. 15개 포함 PR을 분류하고 Spotlight·새 문서 저장·Word/HTML 내보내기·일부 native 표시 보정을 사용자 문구에 반영했다. 현재 공개 README/Cask는 0.1.11을 유지한다.

Pages 홈/업데이트/버전 문구를 준비했으며 표준 helper로 이전 버전 banner를 갱신했다. 인증된 draft API가 보여도 docs deploy는 기다린다. 실제 공개는 준비 PR 병합 이후 후보 검증과 승격 단계다.

## 검증

- 4개 bundle contract/version 검사 PASS, actionlint 전체 workflow PASS, git diff --check PASS.
- release notes 0.2.0 writer → template/body 검사 PASS. 첫 실행에서 `보정합니다`가 템플릿의 미확정 문구 검사에 걸려 확정된 변경 설명으로 수정했다.
- Pages artifact helper, appcast XML, 이전 버전 banner --check PASS. 이때 사용한 저장소 appcast는 helper 검증용이며 v0.2.0 공개 feed가 아니다.
- Browser로 새 페이지 DOM과 실제 viewport를 확인했다. full-page 캡처의 중복 stitching을 피하고 실제 viewport 화면을 첨부했다. [페이지 캡처](../report/assets/task_m900_520/release-notes-preview.png).
- GitHub PR CI의 macOS build/release helper 결과는 준비 PR 생성 후 확인한다. 실제 signed v0.2.0 설치, Finder/Spotlight GUI, Sparkle 업데이트는 이 단계에 포함하지 않았다.

## 다음 단계

준비 PR 리뷰·병합 후 최종 main/tag → draft DMG → 같은 tag에서 양 macOS 15 최초 설치 검증 → maintainer GUI/Finder → 공개 승인 → 동일 DMG 승격 → 실제 업데이트/검색 및 종료 판단 순서다.
