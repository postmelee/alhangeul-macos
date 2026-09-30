# Task #573 Stage 1 — 포함 rhwp 배지와 동기화 갱신

## 결과

README의 기존 배지 사이에 `bundled rhwp v0.8.6` 배지를 추가했다. 해당 `edwardkim/rhwp` 릴리스로 연결하며 title에 resolved commit을 표시한다. native와 Studio의 provenance가 같을 때만 하나로 표시하고, 다르면 native/Studio로 분리한다. commit pin은 짧은 SHA 표시와 전체 commit 링크를 사용한다.

full sync workflow는 core·Studio 갱신·검증 후 helper를 실행하고 README도 stage한다. PR CI의 `--check`가 오래된 표시·링크를 검출한다. 운영 매뉴얼에는 수동 pin 변경 시 같은 갱신 방법과 checkout 기준임을 기록했다. 공개 릴리스 안내 본문은 수정하지 않았다.

## 검증

- `python3 scripts/ci/update-rhwp-readme-badge.py --check`: 통과.
- `PYTHONDONTWRITEBYTECODE=1 python3 scripts/ci/test-rhwp-readme-badge.py`: 10개 통과. 다음 가상 pin `v9.8.7`의 표시·링크 동시 갱신, 반복 실행 무변경, 별도 버전·commit·ref kind 분리, stale 링크의 비수정 실패, malformed 입력, workflow 갱신 순서와 README stage 확인.
- `scripts/verify-rhwp-core-build-info.sh`, `scripts/verify-rhwp-studio-assets.sh`, `git diff --check`: 통과.
- 실제 `rhwp-core.lock`, RustBridge Cargo tag/lock, Studio manifest는 모두 `v0.8.6`, commit `f1f9c6ae58344ee9368996d3543f76b9345cf227`. pin 자체 변경 없음.

2026-09-30 사용자 지시의 구현·검증·PR 생성 범위에 따라 Stage 2를 진행한다.
