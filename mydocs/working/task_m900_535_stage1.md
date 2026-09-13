# Task M900 #535 Stage 1 완료보고서

앱이 삭제된 재설치 준비 실패에도 정확한 소유 경로를 확인한 뒤 등록 해제를 요청한다. 관찰 기한에 맞춰 단축한 mdfind timeout은 관찰 기한 소진으로 분류하고, 독립적인 30초 명령 timeout은 조회 오류로 남긴다. 최초 검증 오류, cleanup 오류, 상태 저장 오류, DMG detach 오류는 독립 필드로 보존한다.

`python3 -B scripts/ci/test-spotlight-system-smoke.py` 39개, `python3 -B scripts/ci/test-release-install-smoke.py` 21개 PASS. 삭제된 소유 앱의 등록 해제, 소유권 불일치 거절, 짧은 잔여 기한과 명령 장애 구분, 검증/정리/detach 동시 실패 보존을 포함한다. 실제 VM의 stale importer 제거 성공을 의미하지 않으며 새 VM 실행에서 별도 확인한다.
