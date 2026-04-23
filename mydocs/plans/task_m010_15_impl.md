# Issue #15 구현 계획서

## 구현 목표

문서 변경만으로 Issue #15 범위를 마무리한다.

- `AGENTS.md`의 `Claude` 관련 표현을 `Codex` 기준으로 정리한다.
- `mydocs/orders/20260423.md`를 현재 표 기반 오늘 할 일 형식으로 정리한다.
- 변경 결과를 문서 검증 기준에 맞춰 확인한다.

## 단계 계획

### 1단계. 오늘 할 일 문서 범위 고정

- `mydocs/orders/20260423.md`에서 이번 타스크와 직접 관련 없는 후속 예정 작업을 제거한다.
- Issue #15 진행 상태를 오늘 할 일 문서에 반영한다.
- 오늘 할 일 문서가 현재 타스크 기준으로만 읽히도록 정리한다.

### 2단계. `AGENTS.md` Codex 표기 정리

- `Claude / Codex`, `Claude와 Codex`처럼 남아 있는 혼용 표현을 `Codex` 기준으로 통일한다.
- 문서 의미를 바꾸지 않고 표현만 정리한다.

### 3단계. 문서 검증 및 완료 보고 준비

- `git diff --check`로 문서 형식 오류가 없는지 확인한다.
- 다음 단계 보고에 필요한 변경 범위와 검증 결과를 정리한다.

## 단계별 검증

- 1단계 후: `git diff --check -- mydocs/orders/20260423.md`
- 2단계 후: `git diff --check -- AGENTS.md`
- 3단계 후: `git diff --check -- AGENTS.md mydocs/orders/20260423.md mydocs/plans/task_m010_15.md mydocs/plans/task_m010_15_impl.md`

## 승인 요청 사항

- 이 구현 계획서 내용으로 1단계 진행 승인 요청
