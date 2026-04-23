# Issue #5 수행 계획서

## 목표

PR #4 머지 후 `devel`에 반영된 `rhwp-core.lock`의 `rhwp_commit` 값과 Issue #3 최종 보고서의 core commit SHA를 실제 `Vendor/rhwp` submodule HEAD와 일치시킨다.

## 범위

- `rhwp-core.lock`의 commit SHA 보정
- `mydocs/report/task_3_report.md`의 commit SHA 보정
- Issue #5 진행 문서 추가

## 제외 범위

- core submodule 변경
- Rust bridge 또는 Swift 코드 변경
- 추가 빌드 산출물 재생성

## 검증

- `git submodule status Vendor/rhwp`로 실제 submodule HEAD 확인
- `rg`로 잘못된 SHA가 남아 있지 않은지 확인
- `git diff --check` 통과
