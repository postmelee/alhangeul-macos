# Task M020 #513 Stage 11 — 릴리즈 VM 재설치 실행 연결

PR #530 병합 기준 `010b01b`에서 계속 진행 승인을 받아 재사용 릴리즈 검증을 보완했다. 최초 설치·종료 후 검색 snapshot을 고정한 뒤 같은 후보의 요청 기록을 유지한 재설치·종료 후 검색을 실행하고 기존 lifecycle·cleanup으로 이어간다.

후보 컨테이너는 bundle ID 또는 metadata로 찾고 요청 기록의 importerPath를 대조한다. UUID 경로와 별칭은 실제 경로로 중복 제거한다. 누락/다른 앱/여러 후보 기록은 거부하며 preferences 쓰기나 전체 설정 복사는 하지 않는다. 기록의 디스크 반영은 최대 30초 관찰한다. 실패한 실행 state도 외부 표준 cleanup에 전달되도록 finally에서 보존한다.

`PYTHONDONTWRITEBYTECODE=1 python3 scripts/ci/test-release-install-smoke.py` 14개와 `git diff --check`를 통과했다. 실제 임시 plist/컨테이너 별칭·모의 실행 순서·최초 snapshot 보존·재설치 실패 상태를 확인했다. 현재 Mac의 설치본이나 시스템 색인을 변경하지 않았다. 새 서명 후보의 VM 실행은 아직 수행하지 않았으며 다음 단계에서 승격 증거 판정을 연결한다.
