# Issue #11 구현 계획서

## 1단계: 문서 분리

- 릴리스/배포 상세 절차를 `mydocs/manual/release_distribution_guide.md`로 작성한다.
- 권한 원칙, 사전 검증, 패키징, 서명/공증, GitHub Release, Homebrew Cask, rollback, checklist를 포함한다.

## 2단계: AGENTS.md 축소

- `AGENTS.md`에서 직접적인 릴리스 패키징 설명을 제거한다.
- 릴리스/배포 작업 전 manual 문서를 반드시 읽는다는 짧은 규칙만 남긴다.

## 3단계: 검증 및 보고

- `git diff --check`를 실행한다.
- 단계 보고서와 최종 보고서를 작성한다.
- `local/task11 -> devel` PR을 생성한다.
