# Task M900 #549 Stage 3 — 공개 안내·종료 기록

README, Pages 홈/업데이트 목록/0.2.2 노트, 릴리즈 기록을 실제 Homebrew 0.2.2 결과에 맞췄다. GitHub Release 본문은 설치·업데이트 명령으로 실제 갱신하고 다시 읽어 byte 일치를 확인했다. 불변 DMG/tag/appcast는 변경하지 않았다. runbook Gate 9에 기존 tap 버전 업그레이드와 최종 설치본 복원·사용자 설정 보존을 명시했다.

릴리즈 노트 template/body 검사, 최신 버전 배너 검사, HTML 파싱·설치/업데이트 명령 확인, Pages artifact 준비와 공개 appcast byte 보존, diff check가 통과했다. Cask는 Stage 2에서 Homebrew 도구로 검증했다. 앱 제품 코드 변경은 없으며 기존 동일 DMG의 VM/Sparkle/GUI 수용 증거를 재사용한다.

runbook gate 대조표와 미검증 예외를 [릴리즈 기록](../release/v0.2.2.md)에 반영했다. 이 main 종료 정리 PR의 CI·검토·병합 후 실제 Pages 문구와 공개 appcast 보존을 확인하고 devel에 인계한다. 공개 반영 결과는 #549 완료 코멘트로 기록한다.
