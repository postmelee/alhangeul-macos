# Issue #5 구현 계획서

## 1단계: 기준 확인

- `origin/devel` 기준에서 `local/task5`를 분기한다.
- `Vendor/rhwp`의 실제 submodule HEAD를 확인한다.

## 2단계: 보정

- `rhwp-core.lock`의 `rhwp_commit`을 실제 submodule HEAD로 변경한다.
- Issue #3 최종 보고서의 commit SHA를 동일하게 변경한다.
- 오늘 할일 문서와 Issue #5 보고 문서를 추가한다.

## 3단계: 검증 및 PR

- 잘못된 SHA 잔존 여부를 검색한다.
- `git diff --check`를 실행한다.
- 변경분을 커밋하고 `local/task5 -> devel` PR을 생성한다.
