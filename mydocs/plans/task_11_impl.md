# Issue #11 구현 계획서

## 1단계: 문서 분리

- 릴리스/배포 상세 절차를 `mydocs/manual/release_distribution_guide.md`로 작성한다.
- 권한 원칙, 사전 검증, 패키징, 서명/공증, GitHub Release, Homebrew Cask, rollback, checklist를 포함한다.

## 2단계: AGENTS.md 축소

- `AGENTS.md`에서 직접적인 릴리스 패키징 설명을 제거한다.
- `AGENTS.md`의 `PR 처리 규칙`, `빌드 및 실행`, `rhwp Core Submodule 운영`, `Swift 및 macOS 코드 규칙`도 상세 설명을 manual로 분리한다.
- 각 항목에는 강제 규칙만 남기고 상세 절차는 `mydocs/manual/*.md` 참조로 통일한다.
- `Git 워크플로우`는 `AGENTS.md`에 유지한다.

## 3단계: 검증 및 보고

- `git diff --check`를 실행한다.
- 단계 보고서와 최종 보고서를 작성한다.
- `local/task11 -> devel` PR을 생성한다.
