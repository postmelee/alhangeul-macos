# Task M900 #549 Stage 1 — Homebrew 기준 설치와 정리 범위

공개 v0.2.2 DMG의 실파일 SHA256 `8d8b8cbd24376fcd2c7ebd48343be44edc1f0f154a1e75282714798806ed4b90`과 192864948 bytes를 재확인했다. tap main은 `6f4abf8ff3fa8db64a0dfa27c0c22f50b86e2153`, Cask 0.1.11이며 미커밋 변경은 없다.

현재 수동 설치 0.2.2(20)의 서명과 종료 상태를 확인하고 표준 smoke의 소유 앱 등록 해제 뒤 전용 `.noindex` 위치에 백업했다. 사용자 문서·설정·기본 연결은 유지했다. 기존 공식 tap에서 전용 캐시를 사용한 `brew install --cask postmelee/tap/alhangeul`이 성공했고, 실제 앱 및 brew receipt 모두 0.1.11, strict 서명 검증 PASS다. 이 설치는 이후 실제 brew upgrade의 출발점이다.

정리 후보는 현재 저장소 `build.noindex`의 릴리즈·검색·저장 시험/빌드 캐시와 완료된 #513 detached worktree다. #523의 `local/task523` worktree는 미병합 PR #527 용도로 보존한다. Downloads의 Linux/Windows 패키지는 이번 macOS 릴리즈 대상이 아니다. 삭제는 Homebrew·공개 기록·runbook 완료와 필수 증거 보존을 확인한 뒤 실행한다.

원본 설치 로그·버전 기록과 앱 백업은 `build.noindex/task549/`에 두며 최종 보고서로 필요한 근거를 옮긴다. 일반 시스템 상태는 기존 설치 이력이 있는 실제 Mac이고 깨끗한 OS 검증으로 확대하지 않는다.
