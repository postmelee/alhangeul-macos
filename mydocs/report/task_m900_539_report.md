# Task M900 #539 릴리즈 준비·후보 수용 보고서

## 현재 결과

v0.2.2(20)의 버전·문구·검증 계획을 준비했다. #536/#538 이 반영된 devel d3376fc 기준이며 직전 공개는 v0.2.0(18), core/Studio는 v0.8.6이다. **서명 draft DMG·양 VM 재시험과 실제 Mac 저장 종료/Finder/명령 검색은 PASS다. Spotlight GUI 확인·공개·실제 Sparkle 업데이트는 남아 있다.**

네 bundle 및 rehearsal/publish/promotion 입력을 맞췄다. [릴리즈 기록](../release/v0.2.2.md)에 포함 PR, 저장 후 종료/재설치 검색 변화, 설치 색인 지연, 알려진 한계와 경로별 수용 표를 작성했다. #537 개발용 회귀 PASS와 새 signed DMG 수용을 구분했다.

미공개 v0.2.1은 tag/source/DMG를 보존하고 페이지는 후보 안내로 변경했다. 작동하지 않는 v0.2.1 DMG 링크는 제거했다. v0.2.2 Pages 후보는 public asset gate로 공개 전에 배포되지 않는다. 현재 공개 앱/사이트/appcast와 Homebrew는 기존 상태다.

## 검증

- 네 plist 파싱·0.2.2/20 대조, bundle 계약 회귀 5개 PASS.
- main/devel content gate와 대상 workflow actionlint PASS.
- 릴리즈 본문 생성/template/body, version notices check, Pages artifact 준비, diff 검사 PASS. 본문 생성 hash는 검증용 가상 값이다.
- Browser DOM과 1280×720 화면에서 제목·저장 종료 설명·색인 대기·다운로드 경로를 확인했다. [Stage 2 화면](../working/task_m900_539_stage2.md)은 로컬 문서 후보다.
- 최종 head의 앱 빌드/필수 PR CI는 PR Checks와 검토 코멘트로 추적한다.

## 후속 수용

준비 PR #540/#541 및 도구 PR #542/#543 병합 후 고정 source `64ed89f881438efdbaec8bb33a6b52d66b83746d` 의 v0.2.2(20) DMG를 생성했다. 첫 VM의 ARM 실패를 보존하고 같은 DMG의 새 실행 34780410801 양쪽 PASS를 확인했다. 상세 식별자·hash·실제 Mac 관찰·화면·검증 공백은 [Stage 4.1](../working/task_m900_539_stage4.md)에 기록했다. 공개 전 읽기 전용 승격 검증도 PASS다.

실제 Mac은 시스템 색인을 작업지시자가 활성화한 기존 환경이며, 재설치 실행 전부터 검색됐으므로 결과는 검색 유지다. Spotlight GUI 확인 → 최종 공개 판단 → 동일 DMG 공개 → public hash·Pages/appcast·실제 0.2.0 → 0.2.2 Sparkle 순서가 남아 있다.

#513 / #337 / #535 / #532 / #520 / #539 는 실제 수용 및 각 종료 조건 판단까지 열린 상태다. macOS 12 미검증·#525·Homebrew 범위는 기존과 같다. 이전 후보의 실패·부분 수용을 새 후보 성공으로 바꾸지 않는다.
