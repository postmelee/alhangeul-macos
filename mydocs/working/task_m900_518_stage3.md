# Task M900 #518 Stage 3 — 검증과 릴리스 인계

## 변경

33개 lifecycle 필수 증거와 최초/종료 후 검색, cleanup 완료 여부를 release verdict에 요구했다. 후보 출처·입력·archive 경로/크기·도움받은 실행·재실행·불완전 증거·환경 조사 오판에 대한 회귀를 PR CI에 연결했다. 재사용 실행 입력과 SHA256 동일성, 기존 공개 workflow와 자동 차단이 아직 연결되지 않은 경계를 운영 매뉴얼에 명시했다.

## 실제 검증

- 새 VM 환경 조사 실행 34452311307: arm64 51.34초 / Intel 34.12초 ENVIRONMENT_READY. 기존 importer 부재·GUI 세션·TXT 자동 검색·파일 정리 확인. 시스템 설정 변경 없음.
- 최초 조사 34451904493은 하위 폴더 mdutil unknown으로 조기 종료한 도구 오류였다. 볼륨 조회와 TXT 검색으로 보정했으며 이 첫 관찰은 러너 비활성의 증거가 아니다.
- Python 판정 회귀 11개, 기존 Spotlight smoke 회귀 31개 PASS. Python 구문·workflow actionlint·diff 검사 PASS.
- 최종 PR CI는 PR #519 checks 및 PR 본문에 현재 head 결과를 연결한다.

## 미실행과 후속

서명·공증된 Spotlight 포함 배포 후보 전체 설치 workflow는 아직 실행하지 않았다. 실제 앱 첫 실행과 HWP/HWPX 자동 검색은 위 환경 조사 결과에 포함되지 않는다. 실제 후보 실행은 별도 승인된 릴리스 준비 단계다. macOS 12, Spotlight GUI, 공개 Sparkle 업데이트는 미실행이며 #513 / #337 을 닫지 않는다.

## Stage 3.1 — 실제 artifact 파일명 계약

release-publish의 notes_path는 `release-notes-<version>.md`다. ZIP 허용 목록을 실제 DMG/checksum/notes 세 파일명에 맞추고 세 파일을 함께 추출하는 회귀를 통과했다. 임의 경로와 symlink는 계속 거부한다.
