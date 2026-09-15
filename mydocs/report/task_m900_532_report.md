# Task M900 #532 릴리즈 준비 결과보고서

## 최종 후속 판정 — 2026-09-15

v0.2.1(19)은 실제 서명 후보를 생성했지만 양 VM 전체 실패와 실제 Mac 저장 후 종료 실패로 공개하지 않았다. tag/source/DMG·실패 기록을 보존하고 #538 수정이 포함된 v0.2.2의 #539 로 대체했다. 원래 v0.2.1의 미완료 항목을 새 후보 성공으로 체크하지 않고 대체됨으로 종료한다. [v0.2.2 공개·실제 Sparkle/GUI 수용](../working/task_m900_539_stage5.md)에 최종 근거를 연결하며 기록 PR 병합 뒤 이슈를 정리한다. 아래 미실행·OPEN 표시는 당시 단계의 기록이다.

## 현재 결과

v0.2.1(19) 준비 변경을 완료했다. **새 서명·공증 DMG 생성, 실제 설치/재설치/Sparkle와 공개 배포는 미실행이다.** PR #531 병합 devel 08fa297 기준이며 직전 공개 v0.2.0(18), core/Studio v0.8.6을 유지한다.

- HostApp/Quick Look/Thumbnail/Spotlight 네 bundle과 rehearsal/publish 입력을 정렬했다.
- [v0.2.1 기록](../release/v0.2.1.md)에 포함 merge 5개를 분석했다. 사용자 앱 변화는 #530 재설치 검색 준비 보완이며 운영 검증 #531 과 기존 공개 기록은 새 기능으로 나열하지 않았다.
- Pages 후보에는 새 버전·재설치 보완·설치 후 색인 대기를 안내하고 기존 버전 배너를 정렬했다. public asset gate가 새 DMG 공개 전 자동 배포를 막는다. 원격 Pages/appcast/Cask는 변경하지 않았다.
- #513 / #337 / #520 / #532 는 실제 수용 종료 전까지 OPEN이다. PR #527 / #462 는 미병합으로 제외했고 #525 와 macOS 12 실행 공백은 새 후보 판단에 남겼다.

## 검증

네 plist 버전 대조, Spotlight bundle contract, main/devel content gate, 릴리즈 본문 생성/template/body, version notice check, Pages artifact 준비, actionlint 및 diff 검사 PASS. 릴리즈 본문의 hash는 검증용 가상 값이며 실제 후보 hash가 아니다.

Browser DOM과 실제 viewport에서 새 릴리즈 제목·본문·다운로드 경로·색인 대기 안내를 확인했다. 화면은 [Stage 2](../working/task_m900_532_stage2.md)에 첨부했다. 준비 PR 최종 head의 앱 빌드/전체 CI는 PR Checks와 완료 코멘트로 추적한다. 이 준비 과정에서 현재 Mac의 앱을 빌드·등록·교체하지 않았다.

## 후속 실행

준비 PR 리뷰·병합 → devel → main 릴리즈 PR → 정확한 후보 SHA/tag → signed/notarized draft DMG → 같은 hash의 양 VM schema 2 최초 설치/재설치와 실제 Mac → 공개 판단 → 동일 DMG 승격 → 실제 0.2.0 → 0.2.1 Sparkle 수용 순서다. 최종 후보가 바뀌면 새 DMG로 검증하며 이전 v0.2.0/개발 후보 성공을 재사용하지 않는다.
