# Task M900 #549 구현계획서

## Stage 1 — 입력·설치 상태와 정리 소유권

이슈·브랜치·오늘할일·계획서를 준비한다. 공개 DMG/hash, tap 원격/로컬·Homebrew 설치 receipt·현재 앱 및 실행 상태를 확인한다. 전용 캐시/증거 위치를 만들고 현재 앱 백업 후 기존 공식 tap 버전으로 Homebrew 설치를 확인한다. 정리 후보의 경로·용량·소유권과 다른 진행 작업을 조사한다.

## Stage 2 — Cask 공개와 실제 검증

표준 checksum helper로 저장소 Cask를 갱신하고 tap에도 동일 내용을 반영한다. style·일반 audit 및 참고 new audit, tap PR 검토·병합을 거쳐 공개 tap의 0.2.2를 확인한다. 0.1.11 → 0.2.2 실제 brew upgrade, 제거·신규 설치와 설치본 버전·서명/실제 제공자를 검증한다. 문서·설정은 초기화하지 않는다.

## Stage 3 — 공개 안내·runbook 종료 기록

실제 tap 결과에 맞춰 README/Pages/Release와 릴리즈 기록을 갱신한다. 기존 DMG/새 VM/Sparkle/GUI 증거 및 미검증 예외를 gate별로 연결한다. 문서·Cask·화면·Pages/appcast 보존 검증 후 main 종료 정리 PR을 검토·CI·병합하고 devel에 인계한다.

## Stage 4 — 소유 산출물 정리

runbook 배포 완료를 확인한 뒤 중요한 결과를 추적 보고서·GitHub 코멘트로 보존한다. 소유권이 확인된 임시 앱/확장 등록을 표준 절차로 해제하고 임시 빌드·DMG·전용 캐시·완료된 worktree/branch를 정리한다. 다른 진행 작업·사용자 문서와 공개 실패 증거를 보존하고 실제 삭제 경로/용량 및 최종 설치·브랜치 상태를 기록한다.
