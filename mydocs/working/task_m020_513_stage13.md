# Task M020 #513 Stage 13 — 릴리즈 재설치 검증 문서와 PR

VM workflow 표시와 결과 schema를 맞추고 최초 설치 가이드/runbook에 동일 버전 재설치를 필수 수용 경로로 추가했다. 최초 설치·동일 버전 재설치·실제 Sparkle 업데이트를 구분하고 같은 DMG hash를 공개 결과와 연결한다. 실제 Mac GUI/최소 OS 검증 공백을 자동화 성공으로 대체하지 않는다.

최종 코드 검토에서 재설치 실행 이후의 본문 검색/실제 importer 결과와 재설치 종료 이후의 검색을 각각 요구하도록 보강했다. 최초 설치의 검색 기록을 재사용하거나 재설치 검색 이후 요청 기록·설치 객체가 바뀌는 경우도 차단한다.

## 검증

| 실행 | 결과 |
|---|---|
| `PYTHONDONTWRITEBYTECODE=1 python3 scripts/ci/test-release-install-smoke.py` | 20개 PASS |
| `PYTHONDONTWRITEBYTECODE=1 python3 scripts/ci/test-release-promotion.py` | 15개 PASS, 실제 ZIP/모의 API CLI 포함 |
| `PYTHONDONTWRITEBYTECODE=1 python3 scripts/ci/test-spotlight-system-smoke.py` | 36개 PASS |
| `actionlint` | 전체 workflow PASS |
| `git diff --check` | PASS |

최종 PR은 저장소 템플릿의 단계/커밋/문서/검증과 잔여 리스크를 포함한다. 새 UI가 없어 스크린샷은 첨부하지 않는다. 실제 signed DMG VM 실행이 아니라 도구 회귀이며 공개 릴리즈·사용자 앱/설정/색인을 변경하지 않았다. PR CI는 정확한 최종 head의 Checks와 완료 코멘트로 기록한다.

## 후속 인계

새 버전 후보는 본 PR 병합 후 준비한다. 현재 공개 v0.2.0(18)을 기준으로 v0.2.1(19)을 제안하지만 후보 identity는 아직 확정하지 않았다. 새 릴리즈 실행 이슈에서 버전·source SHA·포함 변경을 검토하고 동일 서명·공증 DMG의 양 VM/실제 Mac 수용 후 공개를 판단한다. 실제 0.2.0 → 새 버전 Sparkle 업데이트는 공개 appcast 배포 후 별도로 검증한다. #513 / #337 종료를 앞당기지 않는다.
